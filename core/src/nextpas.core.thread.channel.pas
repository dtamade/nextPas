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
    FHandshakeDone: Boolean;
  public
    constructor Create(const ACapacity: Integer);
    destructor Destroy; override;
    procedure Send(const AValue: T);
    function Receive(out AValue: T): Boolean;
    function TrySend(const AValue: T): Boolean;
    function TryReceive(out AValue: T): Boolean;
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
  FHandshakeDone := False;

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
begin
  platform_mutex_lock(FMutex);

  if FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Exit;
  end;

  if FUnbuffered then
  begin
    FHandshakeItem := AValue;
    FHandshakeDone := True;
    Inc(FSendWaiting);
    platform_condvar_signal(FRecvCond);
    while FHandshakeDone and (not FClosed) do
      platform_condvar_wait(FSendCond, FMutex);
    Dec(FSendWaiting);
    platform_mutex_unlock(FMutex);
    Exit;
  end;

  while (FCount >= FCapacity) and (not FClosed) do
    platform_condvar_wait(FSendCond, FMutex);

  if FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Exit;
  end;

  FBuffer[FTail] := AValue;
  FTail := (FTail + 1) mod FCapacity;
  Inc(FCount);

  platform_mutex_unlock(FMutex);
  platform_condvar_signal(FRecvCond);
end;

function TChannel.Receive(out AValue: T): Boolean;
begin
  platform_mutex_lock(FMutex);

  if FUnbuffered then
  begin
    Inc(FRecvWaiting);
    while (not FHandshakeDone) and (not FClosed) do
      platform_condvar_wait(FRecvCond, FMutex);
    Dec(FRecvWaiting);
    if (not FHandshakeDone) and FClosed then
    begin
      platform_mutex_unlock(FMutex);
      Result := False;
      Exit;
    end;
    AValue := FHandshakeItem;
    FHandshakeDone := False;
    platform_condvar_signal(FSendCond);
    platform_mutex_unlock(FMutex);
    Result := True;
    Exit;
  end;

  while (FCount = 0) and (not FClosed) do
    platform_condvar_wait(FRecvCond, FMutex);

  if (FCount = 0) and FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Result := False;
    Exit;
  end;

  AValue := FBuffer[FHead];
  FHead := (FHead + 1) mod FCapacity;
  Dec(FCount);
  Result := True;

  platform_mutex_unlock(FMutex);
  platform_condvar_signal(FSendCond);
end;

function TChannel.TrySend(const AValue: T): Boolean;
begin
  platform_mutex_lock(FMutex);
  if FClosed then
  begin
    platform_mutex_unlock(FMutex);
    Exit(False);
  end;
  if FUnbuffered then
  begin
    if FRecvWaiting = 0 then
    begin
      platform_mutex_unlock(FMutex);
      Exit(False);
    end;
    FHandshakeItem := AValue;
    FHandshakeDone := True;
    platform_condvar_signal(FRecvCond);
    while FHandshakeDone and (not FClosed) do
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
  platform_condvar_signal(FRecvCond);
  Result := True;
end;

function TChannel.TryReceive(out AValue: T): Boolean;
begin
  platform_mutex_lock(FMutex);
  if FUnbuffered then
  begin
    if not FHandshakeDone then
    begin
      platform_mutex_unlock(FMutex);
      Exit(False);
    end;
    AValue := FHandshakeItem;
    FHandshakeDone := False;
    platform_condvar_signal(FSendCond);
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
  FHead := (FHead + 1) mod FCapacity;
  Dec(FCount);
  platform_mutex_unlock(FMutex);
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
