unit nextpas.core.sync.condvar;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.platform.sync;

type
  {**
   * @desc 条件变量，配合 IMutex 使用
   * @note Wait 会原子释放 mutex 并阻塞，被唤醒后重新获取 mutex
   *}
  TCondVar = class(TInterfacedObject, ICondVar)
  private
    FSequence: Int32;
  public
    constructor Create;
    procedure Wait(const AMutex: IMutex);
    function WaitTimeout(const AMutex: IMutex; const ATimeoutNs: Int64): Boolean;
    procedure Signal;
    procedure Broadcast;
  end;

implementation

{ TCondVar }

constructor TCondVar.Create;
begin
  inherited Create;
  FSequence := 0;
end;

procedure TCondVar.Wait(const AMutex: IMutex);
var
  LSequence: Int32;
begin
  LSequence := InterlockedCompareExchange(FSequence, 0, 0);
  AMutex.Release;
  try
    platform_wait_address32(@FSequence, LSequence, -1);
  finally
    AMutex.Acquire;
  end;
end;

function TCondVar.WaitTimeout(const AMutex: IMutex; const ATimeoutNs: Int64): Boolean;
var
  LSequence: Int32;
  LRet: Int32;
begin
  LSequence := InterlockedCompareExchange(FSequence, 0, 0);
  AMutex.Release;
  try
    LRet := platform_wait_address32(@FSequence, LSequence, ATimeoutNs);
  finally
    AMutex.Acquire;
  end;
  Result := (LRet = 0) or (LRet = PLATFORM_ERR_AGAIN);
end;

procedure TCondVar.Signal;
begin
  InterlockedIncrement(FSequence);
  platform_wake_address_one(@FSequence);
end;

procedure TCondVar.Broadcast;
begin
  InterlockedIncrement(FSequence);
  platform_wake_address_all(@FSequence);
end;

end.
