unit nextpas.core.mem.mutex;
{
  注意: TMemMutex 的方法调用在 FPC -O2 下存在已知问题，指针调用可能死锁。
  开发时使用 -O1 或无优化。
}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.sync;

type
  PMemMutex = ^TMemMutex;

  {** TMemMutex — 平台互斥锁 record 封装
   *
   *  @warning 不可拷贝/传值 — TPlatformMutex 是 opaque record (64 字节)，
   *  传值会导致每个线程拿到独立 mutex 副本，互斥锁完全失效。
   *  多线程共享时必须通过指针 (PMemMutex) 传递。
   *
   *  @design 约束说明：
   *    此类型有意不添加 copy-prevention sentinel。
   *    理由：(1) 附加 sentinel 字段会改变 record 大小，影响与平台 mutex 的 ABI 对齐；
   *    (2) 静态分析工具和代码审查足以捕获隐式拷贝；
   *    (3) FPC record 不支持 copy constructor。
   *    调用方应遵循 @warning，始终通过指针共享。
   *}
  TMemMutex = record
  private
    FHandle: TPlatformMutex;
    FInitialized: Boolean;
  public
    procedure Init;
    procedure Done;
    procedure Acquire;
    procedure Release;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors;

procedure RaiseMutexError(const AOperation: string; const AError: Int32); inline;
begin
  raise ENextPasError.CreateFmt('TMemMutex.%s failed: %d', [AOperation, AError]);
end;

procedure TMemMutex.Init;
var
  LResult: Int32;
begin
  if FInitialized then
    Exit;
  ZeroMem(@FHandle, SizeOf(FHandle));
  LResult := platform_mutex_init(FHandle, PLATFORM_MUTEX_ERRORCHECK);
  if LResult <> 0 then
    RaiseMutexError('Init', LResult);
  FInitialized := True;
end;

procedure TMemMutex.Done;
begin
  if not FInitialized then
    Exit;
  platform_mutex_destroy(FHandle);
  ZeroMem(@FHandle, SizeOf(FHandle));
  FInitialized := False;
end;

procedure TMemMutex.Acquire;
var
  LResult: Int32;
begin
  if not FInitialized then
    RaiseMutexError('Acquire', PLATFORM_ERR_INVALID);
  LResult := platform_mutex_lock(FHandle);
  if LResult <> 0 then
    RaiseMutexError('Acquire', LResult);
end;

procedure TMemMutex.Release;
var
  LResult: Int32;
begin
  if not FInitialized then
    RaiseMutexError('Release', PLATFORM_ERR_INVALID);
  LResult := platform_mutex_unlock(FHandle);
  if LResult <> 0 then
    RaiseMutexError('Release', LResult);
end;

end.
