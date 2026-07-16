unit nextpas.core.http.middleware.requestarena;
{**
 * @desc Per-request Arena middleware. Creates a LocalArena at request entry
 *       and releases it when the handler chain returns. Handlers obtain the
 *       arena via HttpRequestArenaOf(AReq).
 *
 *       Usage:
 *         router.Use(RequestArenaMiddleware);
 *         // In handler:
 *         LArena := HttpRequestArenaOf(AReq);
 *         LScratch := LArena.Alloc(256);
 *         // do not FreeMem arena blocks — drop at request end
 *
 *       Capacity defaults to HTTP_DEFAULT_REQUEST_ARENA (256 KiB).
 *       Prefer RequestArenaMiddlewareWith for larger request bodies.
 *
 *       Product wire over nextpas.core.http.mem (fine-grained mem units).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.http.intf,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.intf;

{** @desc Request-scoped Arena middleware (default capacity). }
function RequestArenaMiddleware: IHttpMiddleware;

{** @desc Request-scoped Arena middleware with custom capacity (0 = default). }
function RequestArenaMiddlewareWith(ACapacity: SizeUInt): IHttpMiddleware;

{** @desc Arena attached to the request by RequestArenaMiddleware.
 *  Returns nil if middleware is not active for this request. }
function HttpRequestArenaOf(const AReq: IHttpRequest): IArena;

{** @desc Wrap any IHttpHandler with RequestArenaMiddleware (server-level wire).
 *  Prefer this when the root is not an IHttpRouter, or when constructing
 *  NewHttpServerWithRequestArena. 0 capacity = HTTP_DEFAULT_REQUEST_ARENA. }
function HttpWithRequestArena(const AHandler: IHttpHandler;
  ACapacity: SizeUInt = 0): IHttpHandler;

{** @desc IAllocator over the request LocalArena (FreeMem no-op).
 *  Returns nil if RequestArena middleware / options wire is inactive. }
function HttpRequestAllocatorOf(const AReq: IHttpRequest): IAllocator;

{** @desc Kernel attach: bind arena to request (H1 connection-scoped reuse).
 *  Overwrites any previous attachment for this request. }
procedure HttpAttachRequestArena(const AReq: IHttpRequest; const AArena: IArena);

{** @desc Kernel detach: unbind arena after ServeHTTP (bulk release is caller's). }
procedure HttpDetachRequestArena(const AReq: IHttpRequest);

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.middleware,
  nextpas.core.http.mem,
  nextpas.core.mem.allocator.arena;

{ Global map: IHttpRequest pointer → IArena (released after handler). }
var
  GArenaMap: array of record
    Req: Pointer;
    Arena: IArena;
  end;
  GArenaMapLock: TRTLCriticalSection;

procedure MapPut(const AReq: IHttpRequest; const AArena: IArena);
var
  LI, LLen: Int32;
  LPtr: Pointer;
begin
  LPtr := Pointer(AReq);
  LLen := Length(GArenaMap);
  for LI := 0 to LLen - 1 do
  begin
    if GArenaMap[LI].Req = LPtr then
    begin
      GArenaMap[LI].Arena := AArena;
      Exit;
    end;
  end;
  SetLength(GArenaMap, LLen + 1);
  GArenaMap[LLen].Req := LPtr;
  GArenaMap[LLen].Arena := AArena;
end;

function MapGet(const AReq: IHttpRequest): IArena;
var
  LI, LLen: Int32;
  LPtr: Pointer;
begin
  LPtr := Pointer(AReq);
  LLen := Length(GArenaMap);
  for LI := 0 to LLen - 1 do
  begin
    if GArenaMap[LI].Req = LPtr then
      Exit(GArenaMap[LI].Arena);
  end;
  Result := nil;
end;

procedure MapRemove(const AReq: IHttpRequest);
var
  LI, LWrite, LLen: Int32;
  LPtr: Pointer;
begin
  LPtr := Pointer(AReq);
  LLen := Length(GArenaMap);
  LWrite := 0;
  for LI := 0 to LLen - 1 do
  begin
    if GArenaMap[LI].Req <> LPtr then
    begin
      if LWrite <> LI then
        GArenaMap[LWrite] := GArenaMap[LI];
      Inc(LWrite);
    end;
  end;
  if LWrite < LLen then
    SetLength(GArenaMap, LWrite);
end;

function RequestArenaMiddleware: IHttpMiddleware;
begin
  Result := RequestArenaMiddlewareWith(0);
end;

function RequestArenaMiddlewareWith(ACapacity: SizeUInt): IHttpMiddleware;
var
  LCap: SizeUInt;
begin
  LCap := ACapacity;
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LArena: IArena;
    begin
      LArena := HttpCreateRequestArena(LCap);
      EnterCriticalSection(GArenaMapLock);
      try
        MapPut(AReq, LArena);
      finally
        LeaveCriticalSection(GArenaMapLock);
      end;
      try
        ANext.ServeHTTP(AReq, AW);
      finally
        EnterCriticalSection(GArenaMapLock);
        try
          MapRemove(AReq);
        finally
          LeaveCriticalSection(GArenaMapLock);
        end;
        LArena := nil; { bulk release }
      end;
    end);
  end);
end;

function HttpRequestArenaOf(const AReq: IHttpRequest): IArena;
begin
  if AReq = nil then
    Exit(nil);
  EnterCriticalSection(GArenaMapLock);
  try
    Result := MapGet(AReq);
  finally
    LeaveCriticalSection(GArenaMapLock);
  end;
end;

function HttpWithRequestArena(const AHandler: IHttpHandler;
  ACapacity: SizeUInt): IHttpHandler;
begin
  if AHandler = nil then
    raise EArgumentError.Create('HttpWithRequestArena: handler must not be nil');
  if ACapacity = 0 then
    Result := Chain(AHandler, [RequestArenaMiddleware])
  else
    Result := Chain(AHandler, [RequestArenaMiddlewareWith(ACapacity)]);
end;

function HttpRequestAllocatorOf(const AReq: IHttpRequest): IAllocator;
var
  LArena: IArena;
begin
  LArena := HttpRequestArenaOf(AReq);
  if LArena = nil then
    Exit(nil);
  Result := TLocalArenaAllocator.Create(LArena);
end;

procedure HttpAttachRequestArena(const AReq: IHttpRequest; const AArena: IArena);
begin
  if (AReq = nil) or (AArena = nil) then
    Exit;
  EnterCriticalSection(GArenaMapLock);
  try
    MapPut(AReq, AArena);
  finally
    LeaveCriticalSection(GArenaMapLock);
  end;
end;

procedure HttpDetachRequestArena(const AReq: IHttpRequest);
begin
  if AReq = nil then
    Exit;
  EnterCriticalSection(GArenaMapLock);
  try
    MapRemove(AReq);
  finally
    LeaveCriticalSection(GArenaMapLock);
  end;
end;

initialization
  InitCriticalSection(GArenaMapLock);

finalization
  DoneCriticalSection(GArenaMapLock);

end.
