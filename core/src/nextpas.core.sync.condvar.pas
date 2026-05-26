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
    FHandle: TPlatformCondVar;
    FMutexHandle: TPlatformMutex;
    FHasInternalMutex: Boolean;
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
  SysUtils, nextpas.core.errors, nextpas.core.sync.mutex;

{ TCondVar }

constructor TCondVar.Create;
var
  LRet: Int32;
begin
  inherited Create;
  LRet := platform_condvar_init(FHandle);
  if LRet <> 0 then
    raise ENextPasError.CreateFmt('TCondVar.Create failed: %d', [LRet]);
  platform_mutex_init(FMutexHandle, PLATFORM_MUTEX_NORMAL);
  FHasInternalMutex := True;
end;

destructor TCondVar.Destroy;
begin
  platform_condvar_destroy(FHandle);
  if FHasInternalMutex then
    platform_mutex_destroy(FMutexHandle);
  inherited;
end;

procedure TCondVar.Wait(const AMutex: IMutex);
begin
  platform_mutex_lock(FMutexHandle);
  AMutex.Release;
  platform_condvar_wait(FHandle, FMutexHandle);
  platform_mutex_unlock(FMutexHandle);
  AMutex.Acquire;
end;

function TCondVar.WaitTimeout(const AMutex: IMutex; const ATimeoutNs: Int64): Boolean;
var
  LRet: Int32;
begin
  platform_mutex_lock(FMutexHandle);
  AMutex.Release;
  LRet := platform_condvar_timedwait(FHandle, FMutexHandle, ATimeoutNs);
  platform_mutex_unlock(FMutexHandle);
  AMutex.Acquire;
  Result := LRet = 0;
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
