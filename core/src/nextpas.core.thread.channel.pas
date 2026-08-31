unit nextpas.core.thread.channel;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.intf,
  nextpas.core.platform.sync;

type
  generic TChannel<T> = class(TInterfacedObject, specialize IChannel<T>)
  private
    type
      TItemArray = array of T;
  private
    FBuffer: TItemArray;
    FCapacity: Integer;
    FHead: Integer;
    FTail: Integer;
    FCount: Integer;
    FClosed: Boolean;
    FUnbuffered: Boolean;
    FSendWaiting: Integer;
    FRecvWaiting: Integer;
    FMutex: TPlatformMutex;
    FSendCond: TPlatformCondVar;
    FRecvCond: TPlatformCondVar;
    FHandshakeItem: T;
    FHandshakeReady: Boolean;
    FSendTicket: Int64;
    FConsumedTicket: Int64;
  public
    constructor Create(const ACapacity: Integer);
    destructor Destroy; override;
    procedure Send(const AValue: T);
    function Receive(out AValue: T): Boolean;
    function TrySend(const AValue: T): Boolean;
    function TryReceive(out AValue: T): Boolean;
    function SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    function ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

constructor TChannel.Create(const ACapacity: Integer);
begin
  inherited Create;
  FUnbuffered := ACapacity <= 0;
  if FUnbuffered then
    FCapacity := 0
  else
  begin
    FCapacity := ACapacity;
    SetLength(FBuffer, ACapacity);
  end;
  FHead := 0;
  FTail := 0;
  FCount := 0;
  FClosed := False;
  FSendWaiting := 0;
  FRecvWaiting := 0;
  FHandshakeReady := False;
  FSendTicket := 0;
  FConsumedTicket := 0;

  platform_mutex_init(FMutex);
  platform_condvar_init(FSendCond);
  platform_condvar_init(FRecvCond);
end;

destructor TChannel.Destroy;
begin
  platform_condvar_destroy(FRecvCond);
  platform_condvar_destroy(FSendCond);
  platform_mutex_destroy(FMutex);
  inherited Destroy;
end;

procedure TChannel.Send(const AValue: T);
var
  LMyTicket: Int64;
begin
  platform_mutex_lock(FMutex);

  if FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Exit;
  end;

  if FUnbuffered then
  begin
    { Wait until handshake slot is free (previous value consumed). }
    while FHandshakeReady and (not FClosed) do
      platform_condvar_wait(FSendCond, FMutex);
    if FClosed then
    begin
      platform_mutex_unlock(FMutex);
      Exit;
    end;
    LMyTicket := FSendTicket;
    Inc(FSendTicket);
    FHandshakeItem := AValue;
    FHandshakeReady := True;
    platform_condvar_signal(FRecvCond);
    { Wait until MY value is consumed (ticket matched). }
    while (FConsumedTicket <= LMyTicket) and (not FClosed) do
      platform_condvar_wait(FSendCond, FMutex);
    platform_mutex_unlock(FMutex);
    Exit;
  end;

  while (FCount >= FCapacity) and (not FClosed) do
  begin
    Inc(FSendWaiting);
    platform_condvar_wait(FSendCond, FMutex);
    Dec(FSendWaiting);
  end;

  if FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Exit;
  end;

  FBuffer[FTail] := AValue;
  FTail := (FTail + 1) mod FCapacity;
  Inc(FCount);

  platform_mutex_unlock(FMutex);
  { 等待计数驱动：仅在确有 receiver 等待时 signal。等待者（FRecvWaiting>0）
    只在 FCount=0 时 wait（谓词检查与 wait 同在锁内配对），故此刻入队必是
    它们等的那次 wake；receiver 未等待时（连续消费）不 signal，消灭逐事件
    调度乒乓。不能用「空→非空跃迁」替代：多等待者场景下 count 从满跌到 0
    只有一次跃迁、只 signal 一次会让其余等待者饿死（2026-08-17 教训）。 }
  if FRecvWaiting > 0 then
    platform_condvar_signal(FRecvCond);
end;

function TChannel.Receive(out AValue: T): Boolean;
begin
  platform_mutex_lock(FMutex);

  if FUnbuffered then
  begin
    Inc(FRecvWaiting);
    while (not FHandshakeReady) and (not FClosed) do
      platform_condvar_wait(FRecvCond, FMutex);
    Dec(FRecvWaiting);
    if (not FHandshakeReady) and FClosed then
    begin
      platform_mutex_unlock(FMutex);
      Result := False;
      Exit;
    end;
    AValue := FHandshakeItem;
    FHandshakeItem := Default(T);
    FHandshakeReady := False;
    Inc(FConsumedTicket);
    platform_condvar_broadcast(FSendCond);
    platform_mutex_unlock(FMutex);
    Result := True;
    Exit;
  end;

  while (FCount = 0) and (not FClosed) do
  begin
    Inc(FRecvWaiting);
    platform_condvar_wait(FRecvCond, FMutex);
    Dec(FRecvWaiting);
  end;

  if (FCount = 0) and FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Result := False;
    Exit;
  end;

  AValue := FBuffer[FHead];
  FBuffer[FHead] := Default(T);
  FHead := (FHead + 1) mod FCapacity;
  Dec(FCount);
  Result := True;

  platform_mutex_unlock(FMutex);
  { 与 Send 对称：仅在确有 sender 等待时 signal。 }
  if FSendWaiting > 0 then
    platform_condvar_signal(FSendCond);
end;

function TChannel.TrySend(const AValue: T): Boolean;
var
  LMyTicket: Int64;
begin
  platform_mutex_lock(FMutex);
  if FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Exit(False);
  end;
  if FUnbuffered then
  begin
    if (FRecvWaiting = 0) or FHandshakeReady then
    begin
      platform_mutex_unlock(FMutex);
      Exit(False);
    end;
    LMyTicket := FSendTicket;
    Inc(FSendTicket);
    FHandshakeItem := AValue;
    FHandshakeReady := True;
    platform_condvar_signal(FRecvCond);
    while (FConsumedTicket <= LMyTicket) and (not FClosed) do
      platform_condvar_wait(FSendCond, FMutex);
    platform_mutex_unlock(FMutex);
    Result := True;
    Exit;
  end;
  if FCount >= FCapacity then
  begin
    platform_mutex_unlock(FMutex);
    Exit(False);
  end;
  FBuffer[FTail] := AValue;
  FTail := (FTail + 1) mod FCapacity;
  Inc(FCount);
  platform_mutex_unlock(FMutex);
  if FRecvWaiting > 0 then
    platform_condvar_signal(FRecvCond);
  Result := True;
end;

function TChannel.TryReceive(out AValue: T): Boolean;
begin
  platform_mutex_lock(FMutex);
  if FUnbuffered then
  begin
    if not FHandshakeReady then
    begin
      platform_mutex_unlock(FMutex);
      Exit(False);
    end;
    AValue := FHandshakeItem;
    FHandshakeItem := Default(T);
    FHandshakeReady := False;
    Inc(FConsumedTicket);
    platform_condvar_broadcast(FSendCond);
    platform_mutex_unlock(FMutex);
    Result := True;
    Exit;
  end;
  if FCount = 0 then
  begin
    platform_mutex_unlock(FMutex);
    Exit(False);
  end;
  AValue := FBuffer[FHead];
  FBuffer[FHead] := Default(T);
  FHead := (FHead + 1) mod FCapacity;
  Dec(FCount);
  platform_mutex_unlock(FMutex);
  if FSendWaiting > 0 then
    platform_condvar_signal(FSendCond);
  Result := True;
end;

function TChannel.SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LMyTicket: Int64;
begin
  platform_mutex_lock(FMutex);
  if FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Exit(False);
  end;
  if FUnbuffered then
  begin
    while FHandshakeReady and (not FClosed) do
      if platform_condvar_timedwait(FSendCond, FMutex, ATimeoutNs) <> 0 then
      begin
        platform_mutex_unlock(FMutex);
        Exit(False);
      end;
    if FClosed then
    begin
      platform_mutex_unlock(FMutex);
      Exit(False);
    end;
    LMyTicket := FSendTicket;
    Inc(FSendTicket);
    FHandshakeItem := AValue;
    FHandshakeReady := True;
    platform_condvar_signal(FRecvCond);
    while (FConsumedTicket <= LMyTicket) and (not FClosed) do
      platform_condvar_wait(FSendCond, FMutex);
    platform_mutex_unlock(FMutex);
    Result := True;
    Exit;
  end;
  while (FCount >= FCapacity) and (not FClosed) do
  begin
    Inc(FSendWaiting);
    if platform_condvar_timedwait(FSendCond, FMutex, ATimeoutNs) <> 0 then
    begin
      Dec(FSendWaiting);
      platform_mutex_unlock(FMutex);
      Exit(False);
    end;
    Dec(FSendWaiting);
  end;
  if FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Exit(False);
  end;
  FBuffer[FTail] := AValue;
  FTail := (FTail + 1) mod FCapacity;
  Inc(FCount);
  platform_mutex_unlock(FMutex);
  if FRecvWaiting > 0 then
    platform_condvar_signal(FRecvCond);
  Result := True;
end;

function TChannel.ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
begin
  platform_mutex_lock(FMutex);
  if FUnbuffered then
  begin
    Inc(FRecvWaiting);
    while (not FHandshakeReady) and (not FClosed) do
      if platform_condvar_timedwait(FRecvCond, FMutex, ATimeoutNs) <> 0 then
      begin
        Dec(FRecvWaiting);
        platform_mutex_unlock(FMutex);
        Exit(False);
      end;
    Dec(FRecvWaiting);
    if (not FHandshakeReady) and FClosed then
    begin
      platform_mutex_unlock(FMutex);
      Exit(False);
    end;
    AValue := FHandshakeItem;
    FHandshakeItem := Default(T);
    FHandshakeReady := False;
    Inc(FConsumedTicket);
    platform_condvar_broadcast(FSendCond);
    platform_mutex_unlock(FMutex);
    Result := True;
    Exit;
  end;
  while (FCount = 0) and (not FClosed) do
  begin
    Inc(FRecvWaiting);
    if platform_condvar_timedwait(FRecvCond, FMutex, ATimeoutNs) <> 0 then
    begin
      Dec(FRecvWaiting);
      platform_mutex_unlock(FMutex);
      Exit(False);
    end;
    Dec(FRecvWaiting);
  end;
  if (FCount = 0) and FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Exit(False);
  end;
  AValue := FBuffer[FHead];
  FBuffer[FHead] := Default(T);
  FHead := (FHead + 1) mod FCapacity;
  Dec(FCount);
  platform_mutex_unlock(FMutex);
  if FSendWaiting > 0 then
    platform_condvar_signal(FSendCond);
  Result := True;
end;

procedure TChannel.Close;
begin
  platform_mutex_lock(FMutex);
  FClosed := True;
  platform_mutex_unlock(FMutex);
  platform_condvar_broadcast(FSendCond);
  platform_condvar_broadcast(FRecvCond);
end;

function TChannel.IsClosed: Boolean;
begin
  platform_mutex_lock(FMutex);
  Result := FClosed;
  platform_mutex_unlock(FMutex);
end;

end.
