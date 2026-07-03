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
   *       基于 platform_condvar（pthread_cond / Windows CONDITION_VARIABLE）
   *}
  TCondVar = class(TInterfacedObject, ICondVar)
  private
    FHandle: TPlatformCondVar;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Wait(const AMutex: IMutex);
    function WaitTimeout(const AMutex: IMutex; const ATimeoutNs: Int64): Boolean;
    procedure Signal;
    procedure Broadcast;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.sync.mutex;

{ TCondVar }

{** TFutexMutex.NativeHandle 指向 4 字节 futex state，
    platform_condvar_wait 需要完整 TPlatformMutex，配对使用会导致 buffer overread }
procedure CheckNotFutexMutex(const AMutex: IMutex);
begin
  if AMutex is TFutexMutex then
    raise ENextPasError.Create(
      'TCondVar 不能与 TFutexMutex 配对使用：NativeHandle 指向 4 字节 futex state，' +
      'platform_condvar_wait 需要完整 TPlatformMutex。请使用 TMutex。');
end;

constructor TCondVar.Create;
var
  LRet: Int32;
begin
  inherited Create;
  LRet := platform_condvar_init(FHandle);
  if LRet <> 0 then
    raise ENextPasError.CreateFmt('TCondVar.Create failed: %d', [LRet]);
end;

destructor TCondVar.Destroy;
begin
  platform_condvar_destroy(FHandle);
  inherited;
end;

procedure TCondVar.Wait(const AMutex: IMutex);
var
  LRet: Int32;
begin
  CheckNotFutexMutex(AMutex);
  LRet := platform_condvar_wait(FHandle, TPlatformMutex(AMutex.NativeHandle^));
  if LRet <> 0 then
    raise ENextPasError.CreateFmt('TCondVar.Wait failed: %d', [LRet]);
end;

function TCondVar.WaitTimeout(const AMutex: IMutex; const ATimeoutNs: Int64): Boolean;
var
  LRet: Int32;
begin
  CheckNotFutexMutex(AMutex);
  LRet := platform_condvar_timedwait(FHandle, TPlatformMutex(AMutex.NativeHandle^), ATimeoutNs);
  Result := (LRet = 0);
end;

procedure TCondVar.Signal;
begin
  platform_condvar_signal(FHandle);
end;

procedure TCondVar.Broadcast;
begin
  platform_condvar_broadcast(FHandle);
end;

end.
