program test_session;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.http.base,
  nextpas.core.http.cookie,
  nextpas.core.http.headers,
  nextpas.core.http.intf,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.context,
  nextpas.core.http.middleware.session,
  nextpas.core.hash,
  nextpas.core.io.intf;

var
  GHandlerCalled: Boolean;

type
  TSessionHandlerAction = reference to procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter);
  TMockResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FStatus: THttpStatus;
    FBody: string;
    FHeaders: IHttpHeaders;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Status: THttpStatus read FStatus;
    property Body: string read FBody;
    property Headers: IHttpHeaders read FHeaders;
  end;

  TMockRequest = class(TInterfacedObject, IHttpRequest, IHttpRequestWithContext)
  private
    FMethod: THttpMethod;
    FUrl: TUrl;
    FHeaders: IHttpHeaders;
    FContext: IHttpContext;
  public
    constructor Create(const AMethod: THttpMethod; const APath: string);
    procedure SetHeader(const AName, AValue: string);
    procedure SetContext(const ACtx: IHttpContext);
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetPath: string;
    function GetRawQuery: string;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function GetTrailers: IHttpHeaders;
    function GetRemoteAddr: string;
    function GetRemoteIp: string;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
    function GetContext: IHttpContext;
  end;

{ TMockResponseWriter }

constructor TMockResponseWriter.Create;
begin
  inherited Create;
  FStatus := 0;
  FBody := '';
  FHeaders := NewHttpHeaders;
end;

procedure TMockResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
end;

function TMockResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TMockResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TMockResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LStr: string;
begin
  SetLength(LStr, ACount);
  if ACount > 0 then
    Move(ABuf, LStr[1], ACount);
  FBody := FBody + LStr;
  Result := ACount;
end;

procedure TMockResponseWriter.Flush;
begin
end;

{ TMockRequest }

constructor TMockRequest.Create(const AMethod: THttpMethod; const APath: string);
begin
  inherited Create;
  FMethod := AMethod;
  FUrl := Default(TUrl);
  FUrl.Path := APath;
  FHeaders := NewHttpHeaders;
  FContext := nil;
end;

procedure TMockRequest.SetHeader(const AName, AValue: string);
begin
  FHeaders.SetHeader(AName, AValue);
end;

procedure TMockRequest.SetContext(const ACtx: IHttpContext);
begin
  FContext := ACtx;
end;

function TMockRequest.GetMethod: THttpMethod;
begin
  Result := FMethod;
end;

function TMockRequest.GetUrl: TUrl;
begin
  Result := FUrl;
end;

function TMockRequest.GetPath: string;
begin
  Result := FUrl.Path;
end;

function TMockRequest.GetRawQuery: string;
begin
  Result := FUrl.RawQuery;
end;

function TMockRequest.GetVersion: THttpVersion;
begin
  Result := hvHttp11;
end;

function TMockRequest.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TMockRequest.GetBody: IReader;
begin
  Result := nil;
end;

function TMockRequest.GetContentLength: Int64;
begin
  Result := 0;
end;

function TMockRequest.GetTrailers: IHttpHeaders;
begin
  Result := nil;
end;

function TMockRequest.GetRemoteIp: string;
begin
  Result := GetRemoteAddr;
end;

function TMockRequest.GetRemoteAddr: string;
begin
  Result := '127.0.0.1';
end;

function TMockRequest.PathParam(const AName: string): string;
begin
  Result := '';
end;

function TMockRequest.QueryParam(const AName: string): string;
begin
  Result := '';
end;

function TMockRequest.GetContext: IHttpContext;
begin
  Result := FContext;
end;

{ Session test scaffolding }

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

function FirstCookiePair(const AHeaderValue: string; out AName, AValue: string): Boolean;
var
  P: SizeInt;
  FirstPart: string;
begin
  Result := False;
  AName := '';
  AValue := '';
  if AHeaderValue = '' then
    Exit;
  P := Pos(';', AHeaderValue);
  if P > 0 then
    FirstPart := Copy(AHeaderValue, 1, P - 1)
  else
    FirstPart := AHeaderValue;
  Result := ParseSingleCookie(FirstPart, AName, AValue);
end;

function NewSessionHandler(
  AProc: TSessionHandlerAction): IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    GHandlerCalled := True;
    if Assigned(AProc) then
      AProc(AReq, AW);
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
end;

function BuildSessionMiddleware(
  const AStore: ISessionStore): IHttpMiddleware;
var
  LOpts: TSessionOptions;
begin
  LOpts := TSessionOptions.Default;
  LOpts.Store := AStore;
  Result := SessionMiddleware(LOpts);
end;

procedure ResetCapture;
begin
  GHandlerCalled := False;
end;

{ ==== tests ==== }

procedure TestNoCookieEmptyBagNoCookieEmitted;
var
  LStore: ISessionStore;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
begin
  ResetCapture;
  LStore := NewMemorySessionStore(60000);
  LReqObj := TMockRequest.Create(hmGet, '/login');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      D: TSessionData;
    begin
      D := SessionOf(AReq);
      CheckNotNil(D, 'session bag always attached inside the chain');
      CheckEqual('', D.Get('user_id'), 'empty bag without cookie');
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  Check(True, 'handler ran');
  CheckFalse(LWObj.Headers.Has('Set-Cookie'),
    'no Set-Cookie when the bag is never mutated');
end;

procedure TestPersistFreshSessionIssuesCookieAndStoresHash;
var
  LStore: ISessionStore;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LSetCookie, LToken, LKey: string;
  LCookieName, LCookieValue: string;
  D: TSessionData;
begin
  ResetCapture;
  LStore := NewMemorySessionStore(60000);
  LReqObj := TMockRequest.Create(hmGet, '/login');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      SessionOf(AReq).Put('user_id', 'u-1');
      PersistSession(AReq, AW, SessionOf(AReq));
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  Check(True, 'handler ran');
  LSetCookie := LWObj.Headers.Get('Set-Cookie');
  Check(LSetCookie <> '', 'Set-Cookie emitted for fresh session');
  Check(FirstCookiePair(LSetCookie, LCookieName, LCookieValue),
    'Set-Cookie parses as name=value');
  CheckEqual('session', LCookieName, 'default cookie name');
  CheckEqual(36, Length(LCookieValue), 'session token is a UUID (36 chars)');
  LToken := LCookieValue;
  LKey := Sha256Hex(LToken);
  D := LStore.Load(LKey);
  CheckNotNil(D, 'store has entry under hashed token');
  CheckEqual('u-1', D.Get('user_id'), 'persisted value readable');
  D.Free;
  Check(LStore.Load(LToken) = nil,
    'raw token is not the store key (tokens hashed)');
end;

procedure TestSecondRequestLoadsPersistedSession;
var
  LStore: ISessionStore;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LSetCookie, LToken: string;
  LCookieName, LCookieValue: string;
begin
  LStore := NewMemorySessionStore(60000);
  { Seed a session via a first request. }
  LReqObj := TMockRequest.Create(hmGet, '/login');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      SessionOf(AReq).Put('user_id', 'u-42');
      PersistSession(AReq, AW, SessionOf(AReq));
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  LSetCookie := LWObj.Headers.Get('Set-Cookie');
  Check(FirstCookiePair(LSetCookie, LCookieName, LCookieValue),
    'seed request issues cookie');
  LToken := LCookieValue;

  { Second request with the cookie loads the session. }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/me');
  LReqObj.SetHeader('Cookie', 'session=' + LToken);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      CheckEqual('u-42', SessionOf(AReq).Get('user_id'),
        'session survives the round trip');
      CheckFalse(SessionOf(AReq).Dirty,
        'loaded bag is not dirty');
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  Check(True, 'handler ran');
  CheckFalse(LWObj.Headers.Has('Set-Cookie'),
    'unchanged session emits no Set-Cookie');
end;

procedure TestNonDirtyPersistIsNoOp;
var
  LStore: ISessionStore;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LSetCookie, LToken: string;
  LCookieName, LCookieValue: string;
begin
  LStore := NewMemorySessionStore(60000);
  { Seed. }
  LReqObj := TMockRequest.Create(hmGet, '/login');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      SessionOf(AReq).Put('user_id', 'u-7');
      PersistSession(AReq, AW, SessionOf(AReq));
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  Check(FirstCookiePair(LWObj.Headers.Get('Set-Cookie'),
    LCookieName, LCookieValue), 'seed issues cookie');
  LToken := LCookieValue;

  { Persist without mutation: no write, no cookie. }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/me');
  LReqObj.SetHeader('Cookie', 'session=' + LToken);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      PersistSession(AReq, AW, SessionOf(AReq));
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  CheckFalse(LWObj.Headers.Has('Set-Cookie'),
    'non-dirty persist emits no cookie');
end;

procedure TestClearSessionDeletesStoreAndExpiresCookie;
var
  LStore: ISessionStore;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LSetCookie, LToken, LKey: string;
  LCookieName, LCookieValue: string;
begin
  LStore := NewMemorySessionStore(60000);
  { Seed. }
  LReqObj := TMockRequest.Create(hmGet, '/login');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      SessionOf(AReq).Put('user_id', 'u-9');
      PersistSession(AReq, AW, SessionOf(AReq));
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  Check(FirstCookiePair(LWObj.Headers.Get('Set-Cookie'),
    LCookieName, LCookieValue), 'seed issues cookie');
  LToken := LCookieValue;
  LKey := Sha256Hex(LToken);

  { Logout: clear destroys the session. }
  ResetCapture;
  LReqObj := TMockRequest.Create(hmPost, '/logout');
  LReqObj.SetHeader('Cookie', 'session=' + LToken);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      ClearSession(AReq, AW);
      Check(SessionOf(AReq) = nil,
        'bag removed from context after clear');
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  LSetCookie := LWObj.Headers.Get('Set-Cookie');
  Check(Pos('Max-Age=0', LSetCookie) > 0,
    'clear expires the cookie (Max-Age=0)');
  Check(LStore.Load(LKey) = nil, 'store entry deleted');
end;

procedure TestExpiredSessionTreatedAsAbsent;
var
  LStore: ISessionStore;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LToken: string;
  LCookieName, LCookieValue: string;
begin
  { MaxAgeMs = 1 → server-side expiry is the current second: the store must
    treat the entry as absent immediately. }
  LStore := NewMemorySessionStore(1);
  LReqObj := TMockRequest.Create(hmGet, '/login');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      SessionOf(AReq).Put('user_id', 'u-x');
      PersistSession(AReq, AW, SessionOf(AReq));
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  Check(FirstCookiePair(LWObj.Headers.Get('Set-Cookie'),
    LCookieName, LCookieValue), 'issues cookie');
  LToken := LCookieValue;

  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/me');
  LReqObj.SetHeader('Cookie', 'session=' + LToken);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      CheckEqual('', SessionOf(AReq).Get('user_id'),
        'expired session loads as empty bag');
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  Check(True, 'handler ran');
end;

procedure TestCleanupExpiredKeepsValidEntries;
var
  LStore: ISessionStore;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LToken, LKey: string;
  LCookieName, LCookieValue: string;
  D: TSessionData;
begin
  LStore := NewMemorySessionStore(60000);
  LReqObj := TMockRequest.Create(hmGet, '/login');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      SessionOf(AReq).Put('user_id', 'u-k');
      PersistSession(AReq, AW, SessionOf(AReq));
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  Check(FirstCookiePair(LWObj.Headers.Get('Set-Cookie'),
    LCookieName, LCookieValue), 'issues cookie');
  LToken := LCookieValue;
  LKey := Sha256Hex(LToken);

  LStore.CleanupExpired;
  D := LStore.Load(LKey);
  CheckNotNil(D, 'valid entry survives CleanupExpired');
  CheckEqual('u-k', D.Get('user_id'), 'value intact after cleanup');
  D.Free;
end;

procedure TestHashTokensDisabledStoresRawToken;
var
  LStore: ISessionStore;
  LOpts: TSessionOptions;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LToken: string;
  LCookieName, LCookieValue: string;
  D: TSessionData;
begin
  LStore := NewMemorySessionStore(60000);
  LOpts := TSessionOptions.Default;
  LOpts.Store := LStore;
  LOpts.HashTokens := False;
  LReqObj := TMockRequest.Create(hmGet, '/login');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      SessionOf(AReq).Put('user_id', 'u-raw');
      PersistSession(AReq, AW, SessionOf(AReq));
    end),
    [IHttpMiddleware(SessionMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  Check(FirstCookiePair(LWObj.Headers.Get('Set-Cookie'),
    LCookieName, LCookieValue), 'issues cookie');
  LToken := LCookieValue;
  D := LStore.Load(LToken);
  CheckNotNil(D, 'raw token is the store key when hashing disabled');
  CheckEqual('u-raw', D.Get('user_id'), 'value readable under raw token');
  D.Free;
end;

procedure TestCookieAttributes;
var
  LStore: ISessionStore;
  LOpts: TSessionOptions;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LSetCookie: string;
begin
  LStore := NewMemorySessionStore(60000);
  LOpts := TSessionOptions.Default;
  LOpts.Store := LStore;
  LOpts.CookieSecure := True;
  LOpts.CookieSameSite := ssStrict;
  LReqObj := TMockRequest.Create(hmGet, '/login');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      SessionOf(AReq).Put('user_id', 'u-s');
      PersistSession(AReq, AW, SessionOf(AReq));
    end),
    [IHttpMiddleware(SessionMiddleware(LOpts))]);
  LResult.ServeHTTP(LReq, LW);
  LSetCookie := LWObj.Headers.Get('Set-Cookie');
  Check(Pos('Secure', LSetCookie) > 0, 'Secure attribute emitted');
  Check(Pos('SameSite=Strict', LSetCookie) > 0, 'SameSite=Strict emitted');
  Check(Pos('HttpOnly', LSetCookie) > 0, 'HttpOnly emitted');
  Check(Pos('Path=/', LSetCookie) > 0, 'Path=/ emitted');
end;

procedure TestConstructionValidation;
var
  LOpts: TSessionOptions;
  LRaised: Boolean;
begin
  LOpts := TSessionOptions.Default;
  LRaised := False;
  try
    SessionMiddleware(LOpts);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil store raises at construction');

  LRaised := False;
  try
    NewMemorySessionStore(0);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'non-positive TTL raises');
end;

procedure TestPersistWithoutMiddlewareRaises;
var
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LRaised: Boolean;
begin
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/login');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      PersistSession(AReq, AW, SessionOf(AReq));
    end),
    []);
  LRaised := False;
  try
    LResult.ServeHTTP(LReq, LW);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'persist without session middleware raises');
end;

procedure TestContextLifecycle;
var
  LStore: ISessionStore;
  LReq: IHttpRequest;
  LReqObj: TMockRequest;
  LW: IHttpResponseWriter;
  LWObj: TMockResponseWriter;
  LResult: IHttpHandler;
  LExisting: IHttpContext;
begin
  { Fresh context: middleware attaches a bag and detaches after the handler. }
  LStore := NewMemorySessionStore(60000);
  ResetCapture;
  LReqObj := TMockRequest.Create(hmGet, '/me');
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      CheckNotNil(SessionOf(AReq), 'bag attached on fresh context');
      CheckNotNil(SessionManagerOf(AReq), 'manager reachable in handler');
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  Check(LReqObj.GetContext = nil,
    'middleware-created context detached after handler');

  { Existing context (ContextMiddleware-style) is reused, not detached. }
  LExisting := NewHttpContext;
  LReqObj := TMockRequest.Create(hmGet, '/me');
  LReqObj.SetContext(LExisting);
  LReq := LReqObj;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult := Chain(NewSessionHandler(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      CheckNotNil(SessionOf(AReq), 'bag attached on existing context');
    end),
    [IHttpMiddleware(BuildSessionMiddleware(LStore))]);
  LResult.ServeHTTP(LReq, LW);
  CheckNotNil(LReqObj.GetContext, 'existing context left attached');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.http.middleware.session');
  T.Test('no cookie → empty bag, no Set-Cookie', @TestNoCookieEmptyBagNoCookieEmitted);
  T.Test('persist fresh session issues cookie + hashed store key', @TestPersistFreshSessionIssuesCookieAndStoresHash);
  T.Test('second request loads persisted session', @TestSecondRequestLoadsPersistedSession);
  T.Test('non-dirty persist is a no-op', @TestNonDirtyPersistIsNoOp);
  T.Test('clear deletes store + expires cookie', @TestClearSessionDeletesStoreAndExpiresCookie);
  T.Test('expired session treated as absent', @TestExpiredSessionTreatedAsAbsent);
  T.Test('CleanupExpired keeps valid entries', @TestCleanupExpiredKeepsValidEntries);
  T.Test('HashTokens disabled stores raw token', @TestHashTokensDisabledStoresRawToken);
  T.Test('cookie Secure/SameSite/HttpOnly attributes', @TestCookieAttributes);
  T.Test('construction validation', @TestConstructionValidation);
  T.Test('persist without middleware raises', @TestPersistWithoutMiddlewareRaises);
  T.Test('context lifecycle', @TestContextLifecycle);
  if not T.Run then
    Halt(1);
end.
