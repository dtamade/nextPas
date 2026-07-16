unit nextpas.core.http.middleware.context;
{**
 * @desc Per-request context middleware. Provides IHttpContext for
 *       middleware-to-handler data propagation (auth user, request ID,
 *       trace ID, session, etc.).
 *
 *       Usage:
 *         router.Use(ContextMiddleware);
 *         // In auth middleware:
 *         HttpContextOf(AReq).SetOwnedValue('auth_user', LUserObj);
 *         // In handler:
 *         LUser := HttpContextOf(AReq).GetValue('auth_user');
 *
 *       Context is attached on the request via IHttpRequestWithContext.
 *       SetValue is non-owning; SetOwnedValue frees on overwrite/Remove/Destroy.
 *       Has reports key existence (value may be nil).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{** @desc Context middleware — wraps requests with IHttpContext.
   Place before any middleware that needs context propagation. }
function ContextMiddleware: IHttpMiddleware;

{** @desc Get the IHttpContext attached to a request.
   Returns nil if context middleware is not active or request has no bag. }
function HttpContextOf(const AReq: IHttpRequest): IHttpContext;

{** Typed string helper: stores as owned TObject box; missing key → ''. }
function HttpContextGetString(const ACtx: IHttpContext;
  const AKey: string): string;
procedure HttpContextSetString(const ACtx: IHttpContext;
  const AKey, AValue: string);
{** Typed Int64 helper: stores as owned box; missing key → 0. }
function HttpContextGetInt64(const ACtx: IHttpContext;
  const AKey: string): Int64;
procedure HttpContextSetInt64(const ACtx: IHttpContext;
  const AKey: string; const AValue: Int64);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.sync,
  nextpas.core.text.conv;

type
  THttpContext = class(TInterfacedObject, IHttpContext)
  private
    type
      TEntry = record
        Key: string;
        Value: TObject;
        Owned: Boolean;
      end;
    var
      FEntries: array of TEntry;
      FLock: IMutex;
    procedure FreeOwnedAt(const AIndex: Int32);
    procedure Put(const AKey: string; const AValue: TObject;
      const AOwned: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetValue(const AKey: string; const AValue: TObject);
    procedure SetOwnedValue(const AKey: string; const AValue: TObject);
    function GetValue(const AKey: string): TObject;
    function Has(const AKey: string): Boolean;
    procedure Remove(const AKey: string);
  end;

{ THttpContext }

constructor THttpContext.Create;
begin
  inherited Create;
  FLock := Mutex;
end;

destructor THttpContext.Destroy;
var
  LI: Int32;
begin
  FLock.Acquire;
  try
    for LI := 0 to High(FEntries) do
      FreeOwnedAt(LI);
    FEntries := nil;
  finally
    FLock.Release;
  end;
  FLock := nil;
  inherited;
end;

procedure THttpContext.FreeOwnedAt(const AIndex: Int32);
begin
  if (AIndex < 0) or (AIndex > High(FEntries)) then
    Exit;
  if FEntries[AIndex].Owned and (FEntries[AIndex].Value <> nil) then
  begin
    FEntries[AIndex].Value.Free;
    FEntries[AIndex].Value := nil;
  end;
  FEntries[AIndex].Owned := False;
end;

procedure THttpContext.Put(const AKey: string; const AValue: TObject;
  const AOwned: Boolean);
var
  LI, LLen: Int32;
begin
  FLock.Acquire;
  try
    LLen := Length(FEntries);
    for LI := 0 to LLen - 1 do
    begin
      if FEntries[LI].Key = AKey then
      begin
        FreeOwnedAt(LI);
        FEntries[LI].Value := AValue;
        FEntries[LI].Owned := AOwned and (AValue <> nil);
        Exit;
      end;
    end;
    SetLength(FEntries, LLen + 1);
    FEntries[LLen].Key := AKey;
    FEntries[LLen].Value := AValue;
    FEntries[LLen].Owned := AOwned and (AValue <> nil);
  finally
    FLock.Release;
  end;
end;

procedure THttpContext.SetValue(const AKey: string; const AValue: TObject);
begin
  Put(AKey, AValue, False);
end;

procedure THttpContext.SetOwnedValue(const AKey: string; const AValue: TObject);
begin
  Put(AKey, AValue, True);
end;

function THttpContext.GetValue(const AKey: string): TObject;
var
  LI: Int32;
begin
  FLock.Acquire;
  try
    for LI := 0 to High(FEntries) do
      if FEntries[LI].Key = AKey then
        Exit(FEntries[LI].Value);
    Result := nil;
  finally
    FLock.Release;
  end;
end;

function THttpContext.Has(const AKey: string): Boolean;
var
  LI: Int32;
begin
  FLock.Acquire;
  try
    for LI := 0 to High(FEntries) do
      if FEntries[LI].Key = AKey then
        Exit(True);
    Result := False;
  finally
    FLock.Release;
  end;
end;

procedure THttpContext.Remove(const AKey: string);
var
  LI, LWrite, LLen: Int32;
begin
  FLock.Acquire;
  try
    LLen := Length(FEntries);
    LWrite := 0;
    for LI := 0 to LLen - 1 do
    begin
      if FEntries[LI].Key = AKey then
        FreeOwnedAt(LI)
      else
      begin
        if LWrite <> LI then
          FEntries[LWrite] := FEntries[LI];
        Inc(LWrite);
      end;
    end;
    if LWrite < LLen then
      SetLength(FEntries, LWrite);
  finally
    FLock.Release;
  end;
end;

{ Public API }

function ContextMiddleware: IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LWithCtx: IHttpRequestWithContext;
      LCtx: IHttpContext;
      LAttached: Boolean;
    begin
      LAttached := False;
      LCtx := nil;
      if Supports(AReq, IHttpRequestWithContext, LWithCtx) then
      begin
        LCtx := THttpContext.Create;
        LWithCtx.SetContext(LCtx);
        LAttached := True;
      end;
      try
        ANext.ServeHTTP(AReq, AW);
      finally
        if LAttached then
          LWithCtx.SetContext(nil);
      end;
    end);
  end);
end;

function HttpContextOf(const AReq: IHttpRequest): IHttpContext;
var
  LWithCtx: IHttpRequestWithContext;
begin
  if Supports(AReq, IHttpRequestWithContext, LWithCtx) then
    Exit(LWithCtx.GetContext);
  Result := nil;
end;

type
  THttpContextStringBox = class
  public
    Value: string;
    constructor Create(const AValue: string);
  end;

  THttpContextInt64Box = class
  public
    Value: Int64;
    constructor Create(const AValue: Int64);
  end;

constructor THttpContextStringBox.Create(const AValue: string);
begin
  inherited Create;
  Value := AValue;
end;

constructor THttpContextInt64Box.Create(const AValue: Int64);
begin
  inherited Create;
  Value := AValue;
end;

function HttpContextGetString(const ACtx: IHttpContext;
  const AKey: string): string;
var
  LObj: TObject;
begin
  Result := '';
  if (ACtx = nil) or (AKey = '') then
    Exit;
  LObj := ACtx.GetValue(AKey);
  if LObj is THttpContextStringBox then
    Result := THttpContextStringBox(LObj).Value;
end;

procedure HttpContextSetString(const ACtx: IHttpContext;
  const AKey, AValue: string);
begin
  if (ACtx = nil) or (AKey = '') then
    Exit;
  ACtx.SetOwnedValue(AKey, THttpContextStringBox.Create(AValue));
end;

function HttpContextGetInt64(const ACtx: IHttpContext;
  const AKey: string): Int64;
var
  LObj: TObject;
begin
  Result := 0;
  if (ACtx = nil) or (AKey = '') then
    Exit;
  LObj := ACtx.GetValue(AKey);
  if LObj is THttpContextInt64Box then
    Result := THttpContextInt64Box(LObj).Value;
end;

procedure HttpContextSetInt64(const ACtx: IHttpContext;
  const AKey: string; const AValue: Int64);
begin
  if (ACtx = nil) or (AKey = '') then
    Exit;
  ACtx.SetOwnedValue(AKey, THttpContextInt64Box.Create(AValue));
end;

end.
