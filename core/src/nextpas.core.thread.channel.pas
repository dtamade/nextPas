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
    FMutex: TPlatformMutex;
    FSendCond: TPlatformCondVar;
    FRecvCond: TPlatformCondVar;
  public
    constructor Create(const ACapacity: Integer);
    destructor Destroy; override;
    procedure Send(const AValue: T);
    function Receive(out AValue: T): Boolean;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

{ TChannel }

constructor TChannel.Create(const ACapacity: Integer);
begin
  inherited Create;
  FCapacity := ACapacity;
  SetLength(FBuffer, ACapacity);
  FHead := 0;
  FTail := 0;
  FCount := 0;
  FClosed := False;

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
