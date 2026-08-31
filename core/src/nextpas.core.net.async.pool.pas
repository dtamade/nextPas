unit nextpas.core.net.async.pool;
{**
 * Async-capable TCP connection pool.
 * Sync Acquire uses NetTcpConnect; AcquireAsync uses AsyncTcpDial (HE) on a loop.
 * AcquireAsyncEx forwards TAsyncTcpDialOptions (LocalAddr/NoDelay/KeepAlive/Control/…).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.net.base, nextpas.core.net.intf,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation,
  nextpas.core.net.async.dial;

type
  TConnectionPoolConfig = record
    MaxConnections: UInt32;
    MaxIdleTime: TDuration;
    ConnectTimeout: TDuration;
    class function Default: TConnectionPoolConfig; static;
  end;

  TAcquireAsyncCallback = procedure(AStream: ITcpStream; AError: Int32;
    AContext: Pointer);

  IConnectionPool = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-500000000001}']
    function Acquire(const AHost: string; APort: UInt16): ITcpStream;
    { Prefer idle; else AsyncTcpDial. Requires pool created with a loop. }
    function AcquireAsync(const AHost: string; APort: UInt16;
      ACallback: TAcquireAsyncCallback; AContext: Pointer = nil;
      AToken: IAsyncCancellationToken = nil): Boolean;
    { Same as AcquireAsync but passes full dial options (Token inside opts). }
    function AcquireAsyncEx(const AHost: string; APort: UInt16;
      const ADialOpts: TAsyncTcpDialOptions;
      ACallback: TAcquireAsyncCallback; AContext: Pointer = nil): Boolean;
    procedure Release(AStream: ITcpStream);
    procedure Discard(AStream: ITcpStream);
    function ActiveCount: UInt32;
    function IdleCount: UInt32;
    procedure Close;
  end;

function CreateConnectionPool(
  const AConfig: TConnectionPoolConfig): IConnectionPool; overload;
function CreateConnectionPool: IConnectionPool; overload;
function CreateConnectionPool(const ALoop: TAsyncLoop;
  const AConfig: TConnectionPoolConfig): IConnectionPool; overload;
function CreateConnectionPool(const ALoop: TAsyncLoop): IConnectionPool; overload;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.sync,
  nextpas.core.net.tcp,
  nextpas.core.net.async.tcp;

const
  ECONNREFUSED_LINUX = 111;

type
  TConnectionPool = class; { forward for ctx records }

  PIdleConnection = ^TIdleConnection;
  TIdleConnection = record
    Stream: ITcpStream;
    Host: string;
    Port: UInt16;
    LastUsed: TInstant;
    Next: PIdleConnection;
  end;

  PIdleDeliverCtx = ^TIdleDeliverCtx;
  TIdleDeliverCtx = record
    PoolObj: TConnectionPool;
    PoolRef: IConnectionPool;
    Cb: TAcquireAsyncCallback;
    Ctx: Pointer;
    Stream: ITcpStream;
  end;

  PAcquireAsyncCtx = ^TAcquireAsyncCtx;
  TAcquireAsyncCtx = record
    PoolObj: TConnectionPool;
    PoolRef: IConnectionPool;
    UserCb: TAcquireAsyncCallback;
    UserCtx: Pointer;
    Host: string;
    Port: UInt16;
  end;

  TConnectionPool = class(TInterfacedObject, IConnectionPool)
  private
    FConfig: TConnectionPoolConfig;
    FLoop: TAsyncLoop;
    FActiveCount: UInt32;
    FIdleHead: PIdleConnection;
    FIdleCount: UInt32;
    FLock: TPlatformMutex;
    FClosed: Boolean;
    procedure CleanupExpiredIdle;
    function TryGetIdle(const AHost: string; APort: UInt16): ITcpStream;
    procedure AddToIdle(AStream: ITcpStream; const AHost: string; APort: UInt16);
    procedure RemoveFromIdle(AStream: ITcpStream);
  public
    constructor Create(const AConfig: TConnectionPoolConfig; const ALoop: TAsyncLoop);
    destructor Destroy; override;
    function Acquire(const AHost: string; APort: UInt16): ITcpStream;
    function AcquireAsync(const AHost: string; APort: UInt16;
      ACallback: TAcquireAsyncCallback; AContext: Pointer;
      AToken: IAsyncCancellationToken): Boolean;
    function AcquireAsyncEx(const AHost: string; APort: UInt16;
      const ADialOpts: TAsyncTcpDialOptions;
      ACallback: TAcquireAsyncCallback; AContext: Pointer): Boolean;
    procedure Release(AStream: ITcpStream);
    procedure Discard(AStream: ITcpStream);
    function ActiveCount: UInt32;
    function IdleCount: UInt32;
    procedure Close;
  end;

procedure PoolIdlePostCb(AContext: Pointer); forward;
procedure PoolIdlePostDiscard(AContext: Pointer); forward;
procedure PoolDialDone(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer); forward;

class function TConnectionPoolConfig.Default: TConnectionPoolConfig;
begin
  Result.MaxConnections := 100;
  Result.MaxIdleTime := TDuration.FromSeconds(60);
  Result.ConnectTimeout := TDuration.FromSeconds(10);
end;

constructor TConnectionPool.Create(const AConfig: TConnectionPoolConfig;
  const ALoop: TAsyncLoop);
begin
  inherited Create;
  FConfig := AConfig;
  FLoop := ALoop;
  FActiveCount := 0;
  FIdleHead := nil;
  FIdleCount := 0;
  FClosed := False;
  if platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL) <> 0 then
    raise EInvalidOperationError.Create('connection pool: mutex init failed');
end;

destructor TConnectionPool.Destroy;
begin
  Close;
  platform_mutex_destroy(FLock);
  inherited;
end;

procedure TConnectionPool.CleanupExpiredIdle;
var
  LNow: TInstant;
  LPrev, LCurr, LNext: PIdleConnection;
begin
  LNow := TInstant.Now;
  LPrev := nil;
  LCurr := FIdleHead;
  while LCurr <> nil do
  begin
    LNext := LCurr^.Next;
    if LNow.DurationSince(LCurr^.LastUsed) > FConfig.MaxIdleTime then
    begin
      if LPrev = nil then
        FIdleHead := LNext
      else
        LPrev^.Next := LNext;
      LCurr^.Stream := nil;
      Dispose(LCurr);
      Dec(FIdleCount);
    end
    else
      LPrev := LCurr;
    LCurr := LNext;
  end;
end;

function TConnectionPool.TryGetIdle(const AHost: string; APort: UInt16): ITcpStream;
var
  LCurr, LPrev: PIdleConnection;
begin
  Result := nil;
  LPrev := nil;
  LCurr := FIdleHead;
  while LCurr <> nil do
  begin
    if (LCurr^.Port = APort) and
       ((LCurr^.Host = AHost) or (LCurr^.Stream.RemoteAddr.IP = AHost)) then
    begin
      Result := LCurr^.Stream;
      if LPrev = nil then
        FIdleHead := LCurr^.Next
      else
        LPrev^.Next := LCurr^.Next;
      Dispose(LCurr);
      Dec(FIdleCount);
      Exit;
    end;
    LPrev := LCurr;
    LCurr := LCurr^.Next;
  end;
end;

procedure TConnectionPool.AddToIdle(AStream: ITcpStream; const AHost: string;
  APort: UInt16);
var
  LNode: PIdleConnection;
begin
  New(LNode);
  LNode^.Stream := AStream;
  LNode^.Host := AHost;
  LNode^.Port := APort;
  LNode^.LastUsed := TInstant.Now;
  LNode^.Next := FIdleHead;
  FIdleHead := LNode;
  Inc(FIdleCount);
end;

procedure TConnectionPool.RemoveFromIdle(AStream: ITcpStream);
var
  LCurr, LPrev: PIdleConnection;
begin
  LPrev := nil;
  LCurr := FIdleHead;
  while LCurr <> nil do
  begin
    if LCurr^.Stream = AStream then
    begin
      if LPrev = nil then
        FIdleHead := LCurr^.Next
      else
        LPrev^.Next := LCurr^.Next;
      LCurr^.Stream := nil;
      Dispose(LCurr);
      Dec(FIdleCount);
      Exit;
    end;
    LPrev := LCurr;
    LCurr := LCurr^.Next;
  end;
end;

function TConnectionPool.Acquire(const AHost: string; APort: UInt16): ITcpStream;
begin
  if FClosed then
    raise EInvalidOperationError.Create('connection pool: pool is closed');

  platform_mutex_lock(FLock);
  try
    CleanupExpiredIdle;
    Result := TryGetIdle(AHost, APort);
    if Result <> nil then
    begin
      Inc(FActiveCount);
      Exit;
    end;
    if FActiveCount >= FConfig.MaxConnections then
      raise EInvalidOperationError.Create('connection pool: max connections reached');
    Inc(FActiveCount);
  finally
    platform_mutex_unlock(FLock);
  end;

  try
    Result := NetTcpConnect(AHost, APort);
  except
    platform_mutex_lock(FLock);
    if FActiveCount > 0 then
      Dec(FActiveCount);
    platform_mutex_unlock(FLock);
    raise;
  end;
end;

procedure PoolIdlePostCb(AContext: Pointer);
var
  L: PIdleDeliverCtx;
  LCb: TAcquireAsyncCallback;
  LCtx: Pointer;
  LStream: ITcpStream;
begin
  L := PIdleDeliverCtx(AContext);
  if L = nil then
    Exit;
  LCb := L^.Cb;
  LCtx := L^.Ctx;
  LStream := L^.Stream;
  L^.Stream := nil;
  L^.PoolRef := nil;
  Dispose(L);
  if Assigned(LCb) then
    LCb(LStream, 0, LCtx);
end;

procedure PoolIdlePostDiscard(AContext: Pointer);
var
  L: PIdleDeliverCtx;
  LPoolObj: TConnectionPool;
  LPoolRef: IConnectionPool;
  LCb: TAcquireAsyncCallback;
  LCtx: Pointer;
begin
  L := PIdleDeliverCtx(AContext);
  if L = nil then
    Exit;
  LCb := L^.Cb;
  LCtx := L^.Ctx;
  LPoolObj := L^.PoolObj;
  LPoolRef := L^.PoolRef; { keep alive during dispatch }
  if LPoolObj <> nil then
  begin
    platform_mutex_lock(LPoolObj.FLock);
    try
      if LPoolObj.FActiveCount > 0 then
        Dec(LPoolObj.FActiveCount);
    finally
      platform_mutex_unlock(LPoolObj.FLock);
    end;
  end;
  if L^.Stream <> nil then
  begin
    try
      L^.Stream.Close;
    except
    end;
    L^.Stream := nil;
  end;
  L^.PoolRef := nil;
  Dispose(L);
  if Assigned(LCb) then
    LCb(nil, -ECONNREFUSED_LINUX, LCtx);
end;

procedure PoolDialDone(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
var
  LCtx: PAcquireAsyncCtx;
  LPoolObj: TConnectionPool;
  LPoolRef: IConnectionPool;
  LCb: TAcquireAsyncCallback;
  LUser: Pointer;
begin
  LCtx := PAcquireAsyncCtx(AContext);
  if LCtx = nil then
    Exit;
  LPoolObj := LCtx^.PoolObj;
  LPoolRef := LCtx^.PoolRef;
  LCb := LCtx^.UserCb;
  LUser := LCtx^.UserCtx;
  LCtx^.PoolRef := nil;
  Dispose(LCtx);

  if (AError <> 0) or (AStream = nil) then
  begin
    if LPoolObj <> nil then
    begin
      platform_mutex_lock(LPoolObj.FLock);
      try
        if LPoolObj.FActiveCount > 0 then
          Dec(LPoolObj.FActiveCount);
      finally
        platform_mutex_unlock(LPoolObj.FLock);
      end;
    end;
    if Assigned(LCb) then
      LCb(nil, AError, LUser);
    Exit;
  end;

  if Assigned(LCb) then
    LCb(AStream, 0, LUser);
end;

function TConnectionPool.AcquireAsync(const AHost: string; APort: UInt16;
  ACallback: TAcquireAsyncCallback; AContext: Pointer;
  AToken: IAsyncCancellationToken): Boolean;
var
  LOpts: TAsyncTcpDialOptions;
begin
  LOpts := DefaultAsyncTcpDialOptions;
  LOpts.Token := AToken;
  LOpts.ConnectionAttemptDelayMs := 50;
  LOpts.MaxInFlight := 2;
  Result := AcquireAsyncEx(AHost, APort, LOpts, ACallback, AContext);
end;

function TConnectionPool.AcquireAsyncEx(const AHost: string; APort: UInt16;
  const ADialOpts: TAsyncTcpDialOptions;
  ACallback: TAcquireAsyncCallback; AContext: Pointer): Boolean;
var
  LIdle: ITcpStream;
  LDeliver: PIdleDeliverCtx;
  LDialCtx: PAcquireAsyncCtx;
  LOpts: TAsyncTcpDialOptions;
  LMs: Int64;
  LNeedDial: Boolean;
begin
  Result := False;
  if not Assigned(ACallback) then
    Exit;
  if FClosed then
  begin
    ACallback(nil, -ECONNREFUSED_LINUX, AContext);
    Exit(True);
  end;

  LNeedDial := False;
  LIdle := nil;
  platform_mutex_lock(FLock);
  try
    CleanupExpiredIdle;
    LIdle := TryGetIdle(AHost, APort);
    if LIdle <> nil then
      Inc(FActiveCount)
    else if FActiveCount >= FConfig.MaxConnections then
    begin
      platform_mutex_unlock(FLock);
      ACallback(nil, -ECONNREFUSED_LINUX, AContext);
      Exit(True);
    end
    else
    begin
      Inc(FActiveCount);
      LNeedDial := True;
    end;
  finally
    platform_mutex_unlock(FLock);
  end;

  if not LNeedDial then
  begin
    if FLoop <> nil then
    begin
      New(LDeliver);
      LDeliver^.PoolObj := Self;
      LDeliver^.PoolRef := Self as IConnectionPool;
      LDeliver^.Cb := ACallback;
      LDeliver^.Ctx := AContext;
      LDeliver^.Stream := LIdle;
      try
        FLoop.PostEx(@PoolIdlePostCb, LDeliver, @PoolIdlePostDiscard);
      except
        LDeliver^.Stream := nil;
        LDeliver^.PoolRef := nil;
        Dispose(LDeliver);
        platform_mutex_lock(FLock);
        try
          if FActiveCount > 0 then
            Dec(FActiveCount);
        finally
          platform_mutex_unlock(FLock);
        end;
        raise;
      end;
    end
    else
      ACallback(LIdle, 0, AContext);
    Exit(True);
  end;

  if (FLoop = nil) or (not FLoop.IsValid) then
  begin
    platform_mutex_lock(FLock);
    if FActiveCount > 0 then
      Dec(FActiveCount);
    platform_mutex_unlock(FLock);
    Exit(False);
  end;

  New(LDialCtx);
  LDialCtx^.PoolObj := Self;
  LDialCtx^.PoolRef := Self as IConnectionPool;
  LDialCtx^.UserCb := ACallback;
  LDialCtx^.UserCtx := AContext;
  LDialCtx^.Host := AHost;
  LDialCtx^.Port := APort;

  LOpts := ADialOpts;
  { Pool ConnectTimeout applies only when dial opts leave overall deadline open. }
  LMs := FConfig.ConnectTimeout.AsMilliseconds;
  if (LMs > 0) and LOpts.OverallDeadline.IsInfinite then
    LOpts.OverallDeadline := TDeadline.After(FConfig.ConnectTimeout);

  if not AsyncTcpDial(FLoop, AHost, APort, LOpts, @PoolDialDone, LDialCtx) then
  begin
    LDialCtx^.PoolRef := nil;
    Dispose(LDialCtx);
    platform_mutex_lock(FLock);
    try
      if FActiveCount > 0 then
        Dec(FActiveCount);
    finally
      platform_mutex_unlock(FLock);
    end;
    Exit(False);
  end;
  Result := True;
end;

procedure TConnectionPool.Release(AStream: ITcpStream);
var
  LHost: string;
  LPort: UInt16;
begin
  if AStream = nil then
    Exit;
  LHost := AStream.RemoteAddr.IP;
  LPort := AStream.RemoteAddr.Port;
  platform_mutex_lock(FLock);
  try
    if FActiveCount > 0 then
      Dec(FActiveCount);
    if not FClosed then
      AddToIdle(AStream, LHost, LPort)
    else
      AStream.Close;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TConnectionPool.Discard(AStream: ITcpStream);
begin
  if AStream = nil then
    Exit;
  platform_mutex_lock(FLock);
  try
    if FActiveCount > 0 then
      Dec(FActiveCount);
    RemoveFromIdle(AStream);
  finally
    platform_mutex_unlock(FLock);
  end;
  AStream.Close;
end;

function TConnectionPool.ActiveCount: UInt32;
begin
  platform_mutex_lock(FLock);
  try
    Result := FActiveCount;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TConnectionPool.IdleCount: UInt32;
begin
  platform_mutex_lock(FLock);
  try
    Result := FIdleCount;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TConnectionPool.Close;
var
  LCurr, LNext: PIdleConnection;
begin
  platform_mutex_lock(FLock);
  try
    FClosed := True;
    LCurr := FIdleHead;
    while LCurr <> nil do
    begin
      LNext := LCurr^.Next;
      if LCurr^.Stream <> nil then
        LCurr^.Stream.Close;
      LCurr^.Stream := nil;
      Dispose(LCurr);
      LCurr := LNext;
    end;
    FIdleHead := nil;
    FIdleCount := 0;
    FActiveCount := 0;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function CreateConnectionPool(
  const AConfig: TConnectionPoolConfig): IConnectionPool;
begin
  Result := TConnectionPool.Create(AConfig, nil);
end;

function CreateConnectionPool: IConnectionPool;
begin
  Result := TConnectionPool.Create(TConnectionPoolConfig.Default, nil);
end;

function CreateConnectionPool(const ALoop: TAsyncLoop;
  const AConfig: TConnectionPoolConfig): IConnectionPool;
begin
  Result := TConnectionPool.Create(AConfig, ALoop);
end;

function CreateConnectionPool(const ALoop: TAsyncLoop): IConnectionPool;
begin
  Result := TConnectionPool.Create(TConnectionPoolConfig.Default, ALoop);
end;

end.
