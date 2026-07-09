unit nextpas.core.http.middleware.context;
{**
 * @desc Per-request context middleware. Provides IHttpContext for
 *       middleware-to-handler data propagation (auth user, request ID,
 *       trace ID, session, etc.).
 *
 *       Usage:
 *         router.Use(ContextMiddleware);
 *         // In auth middleware:
 *         HttpContextOf(AReq).SetValue('auth_user', LUserObj);
 *         // In handler:
 *         LUser := HttpContextOf(AReq).GetValue('auth_user');
 *
 *       IHttpContext is attached via a thread-safe global map keyed by
 *       IHttpRequest pointer. The context is automatically released when
 *       the middleware returns (after the handler completes).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{** @desc Context middleware — wraps requests with IHttpContext.
   Place before any middleware that needs context propagation. }
function ContextMiddleware: IHttpMiddleware;

{** @desc Get the IHttpContext attached to a request.
   Returns nil if context middleware is not active. }
function HttpContextOf(const AReq: IHttpRequest): IHttpContext;

implementation

uses
  nextpas.core.http.base,
  nextpas.core.http.middleware;

type
  THttpContext = class(TInterfacedObject, IHttpContext)
  private
    type
      TEntry = record
        Key: string;
        Value: TObject;
      end;
    var
      FEntries: array of TEntry;
      FLock: TRTLCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetValue(const AKey: string; const AValue: TObject);
    function GetValue(const AKey: string): TObject;
    function Has(const AKey: string): Boolean;
    procedure Remove(const AKey: string);
  end;

{ Global map: IHttpRequest pointer → IHttpContext }
var
  GContextMap: array of record
    Req: Pointer;
    Ctx: IHttpContext;
  end;
  GContextMapLock: TRTLCriticalSection;

procedure MapPut(const AReq: IHttpRequest; const ACtx: IHttpContext);
var
  LI, LLen: Int32;
  LPtr: Pointer;
begin
  LPtr := Pointer(AReq);
  LLen := Length(GContextMap);
  for LI := 0 to LLen - 1 do
  begin
    if GContextMap[LI].Req = LPtr then
    begin
      GContextMap[LI].Ctx := ACtx;
      Exit;
    end;
  end;
  SetLength(GContextMap, LLen + 1);
  GContextMap[LLen].Req := LPtr;
  GContextMap[LLen].Ctx := ACtx;
end;

function MapGet(const AReq: IHttpRequest): IHttpContext;
var
  LI, LLen: Int32;
  LPtr: Pointer;
begin
  LPtr := Pointer(AReq);
  LLen := Length(GContextMap);
  for LI := 0 to LLen - 1 do
  begin
    if GContextMap[LI].Req = LPtr then
      Exit(GContextMap[LI].Ctx);
  end;
  Result := nil;
end;

procedure MapRemove(const AReq: IHttpRequest);
var
  LI, LWrite, LLen: Int32;
  LPtr: Pointer;
begin
  LPtr := Pointer(AReq);
  LLen := Length(GContextMap);
  LWrite := 0;
  for LI := 0 to LLen - 1 do
  begin
    if GContextMap[LI].Req <> LPtr then
    begin
      if LWrite <> LI then
        GContextMap[LWrite] := GContextMap[LI];
      Inc(LWrite);
    end;
  end;
  if LWrite < LLen then
    SetLength(GContextMap, LWrite);
end;

{ THttpContext }

constructor THttpContext.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
end;

destructor THttpContext.Destroy;
begin
  FEntries := nil;
  DoneCriticalSection(FLock);
  inherited;
end;

procedure THttpContext.SetValue(const AKey: string; const AValue: TObject);
var
  LI, LLen: Int32;
begin
  EnterCriticalSection(FLock);
  try
    LLen := Length(FEntries);
    for LI := 0 to LLen - 1 do
    begin
      if FEntries[LI].Key = AKey then
      begin
        FEntries[LI].Value := AValue;
        Exit;
      end;
    end;
    SetLength(FEntries, LLen + 1);
    FEntries[LLen].Key := AKey;
    FEntries[LLen].Value := AValue;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function THttpContext.GetValue(const AKey: string): TObject;
var
  LI: Int32;
begin
  EnterCriticalSection(FLock);
  try
    for LI := 0 to High(FEntries) do
      if FEntries[LI].Key = AKey then
        Exit(FEntries[LI].Value);
    Result := nil;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function THttpContext.Has(const AKey: string): Boolean;
begin
  Result := GetValue(AKey) <> nil;
end;

procedure THttpContext.Remove(const AKey: string);
var
  LI, LWrite, LLen: Int32;
begin
  EnterCriticalSection(FLock);
  try
    LLen := Length(FEntries);
    LWrite := 0;
    for LI := 0 to LLen - 1 do
    begin
      if FEntries[LI].Key <> AKey then
      begin
        if LWrite <> LI then
          FEntries[LWrite] := FEntries[LI];
        Inc(LWrite);
      end;
    end;
    if LWrite < LLen then
      SetLength(FEntries, LWrite);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

{ Public API }

function ContextMiddleware: IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LCtx: IHttpContext;
    begin
      LCtx := THttpContext.Create;
      EnterCriticalSection(GContextMapLock);
      try
        MapPut(AReq, LCtx);
      finally
        LeaveCriticalSection(GContextMapLock);
      end;
      try
        ANext.ServeHTTP(AReq, AW);
      finally
        EnterCriticalSection(GContextMapLock);
        try
          MapRemove(AReq);
        finally
          LeaveCriticalSection(GContextMapLock);
        end;
      end;
    end);
  end);
end;

function HttpContextOf(const AReq: IHttpRequest): IHttpContext;
begin
  if AReq = nil then
    Exit(nil);
  EnterCriticalSection(GContextMapLock);
  try
    Result := MapGet(AReq);
  finally
    LeaveCriticalSection(GContextMapLock);
  end;
end;

initialization
  InitCriticalSection(GContextMapLock);

finalization
  DoneCriticalSection(GContextMapLock);

end.
