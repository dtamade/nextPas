unit nextpas.core.http.middleware.session;

{**
 * @desc Server-side session middleware: cookie-bound, store-agnostic.
 *
 *       The middleware resolves the session cookie on every request, loads
 *       the session bag from an injected ISessionStore and publishes it in
 *       the request context under SESSION_KEY (read with SessionOf(AReq)).
 *       A bag is always attached (empty when the request carries no valid
 *       session), so handlers mutate the context-owned bag and call
 *       PersistSession — they never allocate or free session data.
 *       The owning session manager is published under SESSION_MANAGER_KEY
 *       (read with SessionManagerOf(AReq)), so handlers can persist mutated
 *       bags (PersistSession) or destroy sessions (ClearSession) without
 *       any module-global state — the manager instance lives with the
 *       middleware.
 *
 *       Token handling:
 *         - The cookie carries the raw session token (UuidV7 on issue).
 *         - HashTokens (default on) stores only SHA-256(token) as the store
 *           key, so a store leak does not enable session hijacking.
 *         - A fresh bag (no token yet) is materialized on first
 *           PersistSession: token + Set-Cookie are issued and the store is
 *           written. PersistSession is a no-op when the bag is not dirty.
 *
 *       Store contract (see ISessionStore):
 *         - Load returns a fresh bag owned by the caller; the middleware
 *           attaches it to the context as an owned value.
 *         - Save must not retain AData (the caller keeps ownership).
 *         - Expired entries must be treated as absent by Load, and
 *           CleanupExpired reaps them for periodic maintenance.
 *
 *       Session cookies are HttpOnly + Path=/ and carry configurable
 *       Secure / SameSite attributes (see TSessionOptions). Expiry is
 *       enforced server-side by the store TTL, not by the cookie Max-Age
 *       (session cookies).
 *
 *       Usage:
 *         LOpts := TSessionOptions.Default;
 *         LOpts.Store := NewMemorySessionStore(30 * 60 * 1000); (TTL ms)
 *         LOpts.CookieName := 'sid';
 *         router.Use(SessionMiddleware(LOpts));
 *
 *       Handler side:
 *         LData := SessionOf(AReq);
 *         if LData <> nil then
 *           LData.Put('user_id', LUid);
 *         PersistSession(AReq, AW, LData);
 *       Logout:
 *         ClearSession(AReq, AW);
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.http.cookie,
  nextpas.core.http.intf;

const
  { Context key for the session bag of the current request. Owned by the
    context; read with SessionOf(AReq), never freed by the caller. }
  SESSION_KEY = 'session';
  { Context key for the session manager of the current request (not owned
    by the context; lives with the middleware). Read with SessionManagerOf. }
  SESSION_MANAGER_KEY = 'session_manager';

type
  { Key/value session bag with dirty tracking. A bag without a token hash
    is a fresh session; the first PersistSession materializes it. }
  TSessionData = class
  private
    FKeys: TStringArray;
    FValues: TStringArray;
    FTokenHash: string;
    FDirty: Boolean;
  public
    constructor Create(const ATokenHash: string = '');
    function Get(const AKey: string): string;
    procedure Put(const AKey, AValue: string);
    (* Persisted wire format '{k=v\n...}'. Keys and values must not contain
      newline or '=' — the documented constraint of this format. *)
    function Serialize: string;
    class function Deserialize(const AData, ATokenHash: string): TSessionData;
      static;
    { Store key: the (possibly hashed) session token. '' = fresh session. }
    property TokenHash: string read FTokenHash;
    property Dirty: Boolean read FDirty;
  private
    { Restore a persisted value without marking the bag dirty: a loaded bag
      is the clean baseline; only handler mutations trigger persistence. }
    procedure LoadValue(const AKey, AValue: string);
  end;

  { Pluggable session persistence. Implementations decide the backing
    storage (memory, sqlite, ...) and the TTL semantics. }
  ISessionStore = interface
    { Load the bag stored under AToken (the store key, usually the hashed
      token). Returns nil when absent or expired. Caller owns the result. }
    function Load(const AToken: string): TSessionData;
    { Upsert AData under AToken. Must not retain AData. }
    procedure Save(const AToken: string; AData: TSessionData);
    procedure Delete(const AToken: string);
    { Remove expired entries. Called by application maintenance loops. }
    procedure CleanupExpired;
  end;

  TSessionOptions = record
    { Session store. Required; nil raises at construction. }
    Store: ISessionStore;
    { Cookie name. Default 'session'. }
    CookieName: string;
    { Store key = SHA-256(token) when True. Default True. }
    HashTokens: Boolean;
    { Set-Cookie Secure attribute. Enable when serving over TLS.
      Default False. }
    CookieSecure: Boolean;
    { Set-Cookie SameSite attribute. Default ssLax. }
    CookieSameSite: TSameSite;
    class function Default: TSessionOptions; static;
  end;

  { Session manager: cookie <-> store mapping. Owned by the middleware as a
    plain object (never refcounted through an interface) and handed out
    non-owning via SessionManagerOf(AReq). }
  TSessionManager = class
  private
    FStore: ISessionStore;
    FCookieName: string;
    FHashTokens: Boolean;
    FCookieSecure: Boolean;
    FCookieSameSite: TSameSite;
  public
    constructor Create(const AOptions: TSessionOptions);
    function HashToken(const AToken: string): string;
    function CookieTokenFrom(const AReq: IHttpRequest): string;
    function LoadFromRequest(const AReq: IHttpRequest): TSessionData;
    procedure Persist(const AW: IHttpResponseWriter; AData: TSessionData);
    procedure Clear(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

{** @desc Session middleware. Rejects options without a store. }
function SessionMiddleware(const AOptions: TSessionOptions): IHttpMiddleware;

{** @desc Thread-safe in-memory session store with TTL (MaxAgeMs). }
function NewMemorySessionStore(const AMaxAgeMs: Int64): ISessionStore;

{ Session bag of the current request. The middleware always attaches a bag
  (empty when the request carries no valid session cookie), so inside a
  session middleware chain SessionOf is non-nil whenever the request
  supports a context. Nil only outside a session chain or on context-less
  requests. The result is owned by the context — never free it. }
function SessionOf(const AReq: IHttpRequest): TSessionData;

{ Session manager behind the current request; nil outside a session
  middleware chain. Non-owning: the middleware owns the instance. }
function SessionManagerOf(const AReq: IHttpRequest): TSessionManager;

{ Persist a (mutated) session bag and, for fresh sessions, issue the cookie.
  Must be called before the response is written. Raises when no session
  manager is in the request context (wiring error). }
procedure PersistSession(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; AData: TSessionData);

{ Destroy the current session: delete from the store, expire the cookie and
  drop the bag from the context. Raises when no session manager is in the
  request context (wiring error). }
procedure ClearSession(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter);

implementation

uses
  nextpas.core.errors,
  nextpas.core.hash,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.context,
  nextpas.core.id,
  nextpas.core.sync,
  nextpas.core.system,
  nextpas.core.text.utils,
  nextpas.core.time;

const
  DEFAULT_COOKIE_NAME = 'session';

function Sha256Hex(const AData: string): string;
var
  H: IHasher;
  Digest: TSHA256Digest;
begin
  H := NewSHA256;
  if Length(AData) > 0 then
    H.Write(AData[1], Length(AData));
  H.Sum(Digest, SHA256_DIGEST_SIZE);
  Result := DigestToHex(Digest, SHA256_DIGEST_SIZE);
end;

{ TSessionData }

constructor TSessionData.Create(const ATokenHash: string = '');
begin
  inherited Create;
  FTokenHash := ATokenHash;
  FDirty := False;
end;

function TSessionData.Get(const AKey: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FKeys) do
    if FKeys[I] = AKey then
      Exit(FValues[I]);
end;

procedure TSessionData.Put(const AKey, AValue: string);
var
  I: Integer;
begin
  for I := 0 to High(FKeys) do
    if FKeys[I] = AKey then
    begin
      if FValues[I] <> AValue then
      begin
        FValues[I] := AValue;
        FDirty := True;
      end;
      Exit;
    end;
  SetLength(FKeys, Length(FKeys) + 1);
  SetLength(FValues, Length(FValues) + 1);
  FKeys[High(FKeys)] := AKey;
  FValues[High(FValues)] := AValue;
  FDirty := True;
end;

function TSessionData.Serialize: string;
var
  I: Integer;
begin
  Result := '{';
  for I := 0 to High(FKeys) do
  begin
    if I > 0 then
      Result := Result + #10;
    Result := Result + FKeys[I] + '=' + FValues[I];
  end;
  Result := Result + '}';
end;

procedure TSessionData.LoadValue(const AKey, AValue: string);
begin
  SetLength(FKeys, Length(FKeys) + 1);
  SetLength(FValues, Length(FValues) + 1);
  FKeys[High(FKeys)] := AKey;
  FValues[High(FValues)] := AValue;
end;

class function TSessionData.Deserialize(const AData, ATokenHash: string):
  TSessionData;
var
  L: TStringArray;
  I, EqPos: Integer;
  Line: string;
begin
  Result := TSessionData.Create(ATokenHash);
  L := SplitString(AData, #10);
  for I := 0 to High(L) do
  begin
    Line := Trim(L[I]);
    if (Line = '') or (Line = '{') or (Line = '}') then
      Continue;
    if Line[1] = '{' then
      Delete(Line, 1, 1);
    if (Length(Line) > 0) and (Line[Length(Line)] = '}') then
      Delete(Line, Length(Line), 1);
    EqPos := Pos('=', Line);
    if EqPos > 0 then
      Result.LoadValue(Copy(Line, 1, EqPos - 1), Copy(Line, EqPos + 1, MaxInt));
  end;
end;

{ TMemorySessionStore }

type
  TMemorySessionEntry = record
    Key: string;
    DataText: string;
    ExpiresAtUnix: Int64;
  end;

  TMemorySessionStore = class(TInterfacedObject, ISessionStore)
  private
    FEntries: array of TMemorySessionEntry;
    FMaxAgeMs: Int64;
    FMutex: INativeMutex;
    function FindEntry(const AKey: string): Integer;
  public
    constructor Create(const AMaxAgeMs: Int64);
    function Load(const AToken: string): TSessionData;
    procedure Save(const AToken: string; AData: TSessionData);
    procedure Delete(const AToken: string);
    procedure CleanupExpired;
  end;

constructor TMemorySessionStore.Create(const AMaxAgeMs: Int64);
begin
  inherited Create;
  FMaxAgeMs := AMaxAgeMs;
  FMutex := Mutex;
end;

function TMemorySessionStore.FindEntry(const AKey: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    if FEntries[I].Key = AKey then
      Exit(I);
  Result := -1;
end;

function TMemorySessionStore.Load(const AToken: string): TSessionData;
var
  I: Integer;
  NowUnix: Int64;
begin
  Result := nil;
  if AToken = '' then
    Exit;
  NowUnix := DateTimeToUnix(DateTimeUtcNow);
  FMutex.Acquire;
  try
    I := FindEntry(AToken);
    if I < 0 then
      Exit;
    if NowUnix >= FEntries[I].ExpiresAtUnix then
    begin
      FEntries[I] := FEntries[High(FEntries)];
      SetLength(FEntries, Length(FEntries) - 1);
      Exit;
    end;
    Result := TSessionData.Deserialize(FEntries[I].DataText, AToken);
  finally
    FMutex.Release;
  end;
end;

procedure TMemorySessionStore.Save(const AToken: string; AData: TSessionData);
var
  I: Integer;
  Entry: TMemorySessionEntry;
begin
  if AToken = '' then
    Exit;
  Entry.Key := AToken;
  Entry.DataText := AData.Serialize;
  Entry.ExpiresAtUnix := DateTimeToUnix(DateTimeUtcNow) + (FMaxAgeMs div 1000);
  FMutex.Acquire;
  try
    I := FindEntry(AToken);
    if I >= 0 then
      FEntries[I] := Entry
    else
    begin
      SetLength(FEntries, Length(FEntries) + 1);
      FEntries[High(FEntries)] := Entry;
    end;
  finally
    FMutex.Release;
  end;
end;

procedure TMemorySessionStore.Delete(const AToken: string);
var
  I: Integer;
begin
  if AToken = '' then
    Exit;
  FMutex.Acquire;
  try
    I := FindEntry(AToken);
    if I >= 0 then
    begin
      FEntries[I] := FEntries[High(FEntries)];
      SetLength(FEntries, Length(FEntries) - 1);
    end;
  finally
    FMutex.Release;
  end;
end;

procedure TMemorySessionStore.CleanupExpired;
var
  I: Integer;
  NowUnix: Int64;
begin
  NowUnix := DateTimeToUnix(DateTimeUtcNow);
  FMutex.Acquire;
  try
    I := 0;
    while I <= High(FEntries) do
    begin
      if FEntries[I].ExpiresAtUnix < NowUnix then
      begin
        FEntries[I] := FEntries[High(FEntries)];
        SetLength(FEntries, Length(FEntries) - 1);
      end
      else
        Inc(I);
    end;
  finally
    FMutex.Release;
  end;
end;

{ TSessionManager }

constructor TSessionManager.Create(const AOptions: TSessionOptions);
begin
  inherited Create;
  FStore := AOptions.Store;
  FCookieName := AOptions.CookieName;
  if FCookieName = '' then
    FCookieName := DEFAULT_COOKIE_NAME;
  FHashTokens := AOptions.HashTokens;
  FCookieSecure := AOptions.CookieSecure;
  FCookieSameSite := AOptions.CookieSameSite;
end;

function TSessionManager.HashToken(const AToken: string): string;
begin
  if FHashTokens then
    Result := Sha256Hex(AToken)
  else
    Result := AToken;
end;

function TSessionManager.CookieTokenFrom(const AReq: IHttpRequest): string;
begin
  Result := ParseCookies(AReq.Headers.Get('Cookie')).Get(FCookieName);
end;

function TSessionManager.LoadFromRequest(const AReq: IHttpRequest): TSessionData;
var
  Token: string;
begin
  Result := nil;
  Token := CookieTokenFrom(AReq);
  if Token = '' then
    Exit;
  Result := FStore.Load(HashToken(Token));
end;

procedure TSessionManager.Persist(const AW: IHttpResponseWriter;
  AData: TSessionData);
var
  Token: string;
  Cookie: TSetCookie;
begin
  if AData = nil then
    Exit;
  if not AData.Dirty then
    Exit;
  if AData.FTokenHash = '' then
  begin
    Token := UuidV7;
    AData.FTokenHash := HashToken(Token);
    Cookie := MakeCookie(FCookieName, Token)
      .WithPath('/')
      .WithHttpOnly(True)
      .WithSecure(FCookieSecure)
      .WithSameSite(FCookieSameSite);
    AW.Headers.Add('Set-Cookie', BuildSetCookie(Cookie));
  end;
  FStore.Save(AData.FTokenHash, AData);
end;

procedure TSessionManager.Clear(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter);
var
  Token: string;
  Cookie: TSetCookie;
  Ctx: IHttpContext;
  Data: TSessionData;
begin
  Token := CookieTokenFrom(AReq);
  if Token <> '' then
    FStore.Delete(HashToken(Token));
  Cookie := MakeCookie(FCookieName, '')
    .WithPath('/')
    .WithMaxAge(0)
    .WithHttpOnly(True)
    .WithSecure(FCookieSecure)
    .WithSameSite(FCookieSameSite);
  AW.Headers.Add('Set-Cookie', BuildSetCookie(Cookie));
  Ctx := HttpContextOf(AReq);
  if Ctx <> nil then
  begin
    Data := TSessionData(Ctx.GetValue(SESSION_KEY));
    if Data <> nil then
      Ctx.Remove(SESSION_KEY);
  end;
end;

{ TSessionMiddleware }

type
  TSessionMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FManager: TSessionManager;
  public
    constructor Create(const AOptions: TSessionOptions);
    destructor Destroy; override;
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

constructor TSessionMiddleware.Create(const AOptions: TSessionOptions);
begin
  inherited Create;
  FManager := TSessionManager.Create(AOptions);
end;

destructor TSessionMiddleware.Destroy;
begin
  FManager.Free;
  inherited Destroy;
end;

function TSessionMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    Ctx: IHttpContext;
    LWithCtx: IHttpRequestWithContext;
    LCreated: Boolean;
    Data: TSessionData;
  begin
    { Attach a fresh context bag when none exists (auth middleware pattern);
      an existing bag (ContextMiddleware) is reused, not replaced. }
    LCreated := False;
    LWithCtx := nil;
    Ctx := HttpContextOf(AReq);
    if Ctx = nil then
    begin
      if Supports(AReq, IHttpRequestWithContext, LWithCtx) then
      begin
        Ctx := NewHttpContext;
        LWithCtx.SetContext(Ctx);
        LCreated := True;
      end;
    end;
    if Ctx <> nil then
    begin
      Ctx.SetValue(SESSION_MANAGER_KEY, FManager);
      Data := FManager.LoadFromRequest(AReq);
      { Always attach a bag (empty when no/expired cookie): handlers mutate
        and PersistSession; Persist is a no-op for non-dirty bags, so
        anonymous requests that never mutate produce no cookie/store write.
        The context owns the bag — handlers never allocate or free it. }
      if Data = nil then
        Data := TSessionData.Create;
      Ctx.SetOwnedValue(SESSION_KEY, Data);
    end;
    try
      ANext.ServeHTTP(AReq, AW);
    finally
      if LCreated then
        LWithCtx.SetContext(nil);
    end;
  end);
end;

function SessionMiddleware(const AOptions: TSessionOptions): IHttpMiddleware;
begin
  if AOptions.Store = nil then
    raise EHttpError.Create(hekArgument,
      'session middleware requires a store');
  Result := TSessionMiddleware.Create(AOptions);
end;

function NewMemorySessionStore(const AMaxAgeMs: Int64): ISessionStore;
begin
  if AMaxAgeMs <= 0 then
    raise EHttpError.Create(hekArgument,
      'memory session store requires MaxAgeMs > 0');
  Result := TMemorySessionStore.Create(AMaxAgeMs);
end;

class function TSessionOptions.Default: TSessionOptions;
begin
  Result.Store := nil;
  Result.CookieName := DEFAULT_COOKIE_NAME;
  Result.HashTokens := True;
  Result.CookieSecure := False;
  Result.CookieSameSite := ssLax;
end;

function SessionOf(const AReq: IHttpRequest): TSessionData;
var
  Ctx: IHttpContext;
begin
  Result := nil;
  Ctx := HttpContextOf(AReq);
  if Ctx <> nil then
    Result := TSessionData(Ctx.GetValue(SESSION_KEY));
end;

function SessionManagerOf(const AReq: IHttpRequest): TSessionManager;
var
  Ctx: IHttpContext;
begin
  Result := nil;
  Ctx := HttpContextOf(AReq);
  if Ctx <> nil then
    Result := TSessionManager(Ctx.GetValue(SESSION_MANAGER_KEY));
end;
procedure PersistSession(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; AData: TSessionData);
var
  M: TSessionManager;
begin
  M := SessionManagerOf(AReq);
  if M = nil then
    raise EHttpError.Create(hekArgument,
      'session manager not in request context (session middleware missing?)');
  M.Persist(AW, AData);
end;

procedure ClearSession(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter);
var
  M: TSessionManager;
begin
  M := SessionManagerOf(AReq);
  if M = nil then
    raise EHttpError.Create(hekArgument,
      'session manager not in request context (session middleware missing?)');
  M.Clear(AReq, AW);
end;

end.
