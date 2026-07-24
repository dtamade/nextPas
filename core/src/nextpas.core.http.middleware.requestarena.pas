unit nextpas.core.http.middleware.requestarena;
{**
 * @desc Per-request Arena middleware. Creates a LocalArena at request entry
 *       and releases it when the handler chain returns. Handlers obtain the
 *       arena via HttpRequestArenaOf(AReq).
 *
 *       Arena is attached on the request via IHttpRequestWithArena (O(1)
 *       Supports lookup; no process-global map).
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

{** @desc Arena attached to the request by RequestArenaMiddleware / attach.
 *  Returns nil if middleware / kernel wire is not active for this request. }
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
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.mem,
  nextpas.core.mem.allocator.arena;

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
      LWith: IHttpRequestWithArena;
      LAttached: Boolean;
    begin
      LAttached := False;
      LArena := nil;
      if Supports(AReq, IHttpRequestWithArena, LWith) then
      begin
        LArena := HttpCreateRequestArena(LCap);
        LWith.SetArena(LArena);
        LAttached := True;
      end;
      try
        ANext.ServeHTTP(AReq, AW);
      finally
        if LAttached then
        begin
          LWith.SetArena(nil);
          LArena := nil; { bulk release when last ref drops }
        end;
      end;
    end);
  end);
end;

function HttpRequestArenaOf(const AReq: IHttpRequest): IArena;
var
  LWith: IHttpRequestWithArena;
begin
  if Supports(AReq, IHttpRequestWithArena, LWith) then
    Exit(LWith.GetArena);
  Result := nil;
end;

function HttpWithRequestArena(const AHandler: IHttpHandler;
  ACapacity: SizeUInt): IHttpHandler;
begin
  if AHandler = nil then
    raise EHttpError.Create(hekArgument, 'HttpWithRequestArena: handler must not be nil');
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
var
  LWith: IHttpRequestWithArena;
begin
  if (AReq = nil) or (AArena = nil) then
    Exit;
  if Supports(AReq, IHttpRequestWithArena, LWith) then
    LWith.SetArena(AArena);
end;

procedure HttpDetachRequestArena(const AReq: IHttpRequest);
var
  LWith: IHttpRequestWithArena;
begin
  if AReq = nil then
    Exit;
  if Supports(AReq, IHttpRequestWithArena, LWith) then
    LWith.SetArena(nil);
end;

end.