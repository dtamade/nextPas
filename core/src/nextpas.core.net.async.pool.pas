unit nextpas.core.net.async.pool;
{**
 * @desc 异步 TCP 连接池：管理可复用的 TCP 连接。
 *       支持连接限制、空闲连接回收。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.net.base, nextpas.core.net.intf;

type
  { 连接池配置 }
  TConnectionPoolConfig = record
    MaxConnections: UInt32;       // 最大连接数
    MaxIdleTime: TDuration;       // 空闲连接最大存活时间
    ConnectTimeout: TDuration;    // 连接超时
    class function Default: TConnectionPoolConfig; static;
  end;

  { 获取连接回调 }
  TAcquireCallback = procedure(AStream: ITcpStream; AContext: Pointer);

  { 连接池接口 }
  IConnectionPool = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-500000000001}']
    { 获取连接（同步，从空闲池或创建新连接） }
    function Acquire(const AHost: string; APort: UInt16): ITcpStream;

    { 释放连接（归还到池） }
    procedure Release(AStream: ITcpStream);

    { 关闭连接（不归还） }
    procedure Discard(AStream: ITcpStream);

    { 池状态 }
    function ActiveCount: UInt32;
    function IdleCount: UInt32;

    { 关闭池 }
    procedure Close;
  end;

{ 创建连接池 }
function CreateConnectionPool(
  const AConfig: TConnectionPoolConfig): IConnectionPool;
overload;

function CreateConnectionPool: IConnectionPool;
overload;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.sync,
  nextpas.core.net.tcp;

type
  PIdleConnection = ^TIdleConnection;
  TIdleConnection = record
    Stream: ITcpStream;
    LastUsed: TInstant;
    Next: PIdleConnection;
  end;

  TConnectionPool = class(TInterfacedObject, IConnectionPool)
  private
    FConfig: TConnectionPoolConfig;
    FActiveCount: UInt32;
    FIdleHead: PIdleConnection;
    FIdleCount: UInt32;
    FLock: TPlatformMutex;
    FClosed: Boolean;

    procedure CleanupExpiredIdle;
    function TryGetIdle(const AHost: string; APort: UInt16): ITcpStream;
    procedure AddToIdle(AStream: ITcpStream);
    procedure RemoveFromIdle(AStream: ITcpStream);
  public
    constructor Create(const AConfig: TConnectionPoolConfig);
    destructor Destroy; override;

    { IConnectionPool }
    function Acquire(const AHost: string; APort: UInt16): ITcpStream;
    procedure Release(AStream: ITcpStream);
    procedure Discard(AStream: ITcpStream);
    function ActiveCount: UInt32;
    function IdleCount: UInt32;
    procedure Close;
  end;

{ TConnectionPoolConfig }

class function TConnectionPoolConfig.Default: TConnectionPoolConfig;
begin
  Result.MaxConnections := 100;
  Result.MaxIdleTime := TDuration.FromSeconds(60);
  Result.ConnectTimeout := TDuration.FromSeconds(10);
end;

{ TConnectionPool }

constructor TConnectionPool.Create(const AConfig: TConnectionPoolConfig);
begin
  inherited Create;
  FConfig := AConfig;
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
      { 过期，移除 }
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
  LAddr: TNetAddress;
begin
  Result := nil;
  LPrev := nil;
  LCurr := FIdleHead;
  while LCurr <> nil do
  begin
    LAddr := LCurr^.Stream.RemoteAddr;
    { 匹配端口 + IP 或主机名 }
    if (LAddr.Port = APort) and
       ((LAddr.IP = AHost) or (LCurr^.Stream.RemoteAddr.IP = AHost)) then
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

procedure TConnectionPool.AddToIdle(AStream: ITcpStream);
var
  LNode: PIdleConnection;
begin
  New(LNode);
  LNode^.Stream := AStream;
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
    { 清理过期空闲连接 }
    CleanupExpiredIdle;

    { 尝试从空闲池获取 }
    Result := TryGetIdle(AHost, APort);
    if Result <> nil then
    begin
      Inc(FActiveCount);
      Exit;
    end;

    { 没有空闲连接，创建新连接 }
    if FActiveCount >= FConfig.MaxConnections then
      raise EInvalidOperationError.Create('connection pool: max connections reached');

    Inc(FActiveCount);
  finally
    platform_mutex_unlock(FLock);
  end;

  { 创建新连接 }
  try
    Result := NetTcpConnect(AHost, APort);
  except
    platform_mutex_lock(FLock);
    Dec(FActiveCount);
    platform_mutex_unlock(FLock);
    raise;
  end;
end;

procedure TConnectionPool.Release(AStream: ITcpStream);
begin
  if AStream = nil then Exit;

  platform_mutex_lock(FLock);
  try
    Dec(FActiveCount);
    AddToIdle(AStream);
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TConnectionPool.Discard(AStream: ITcpStream);
begin
  if AStream = nil then Exit;

  platform_mutex_lock(FLock);
  try
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

{ 工厂函数 }

function CreateConnectionPool(
  const AConfig: TConnectionPoolConfig): IConnectionPool;
begin
  Result := TConnectionPool.Create(AConfig);
end;

function CreateConnectionPool: IConnectionPool;
begin
  Result := TConnectionPool.Create(TConnectionPoolConfig.Default);
end;

end.
