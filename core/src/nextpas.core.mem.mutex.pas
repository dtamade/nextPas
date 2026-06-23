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
    FState: LongInt;
  public
    procedure Init;
    procedure Done;
    procedure Acquire;
    procedure Release;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.platform.thread;

const
  MEM_MUTEX_STATE_UNINITIALIZED = 0;
  MEM_MUTEX_STATE_INITIALIZING = 1;
  MEM_MUTEX_STATE_INITIALIZED = 2;
  MEM_MUTEX_STATE_DESTROYING = 3;

procedure RaiseMutexError(const AOperation: string; const AError: Int32); inline;
begin
  raise ENextPasError.CreateFmt('TMemMutex.%s failed: %d', [AOperation, AError]);
end;

procedure TMemMutex.Init;
var
  LState: LongInt;
  LResult: Int32;
begin
  while True do
  begin
    LState := InterlockedCompareExchange(FState,
      MEM_MUTEX_STATE_UNINITIALIZED,
      MEM_MUTEX_STATE_UNINITIALIZED);
    case LState of
      MEM_MUTEX_STATE_UNINITIALIZED:
        begin
          if InterlockedCompareExchange(FState,
            MEM_MUTEX_STATE_INITIALIZING,
            MEM_MUTEX_STATE_UNINITIALIZED) <> MEM_MUTEX_STATE_UNINITIALIZED then
            Continue;
          ZeroMem(@FHandle, SizeOf(FHandle));
          LResult := platform_mutex_init(FHandle, PLATFORM_MUTEX_ERRORCHECK);
          if LResult <> 0 then
          begin
            ZeroMem(@FHandle, SizeOf(FHandle));
            InterlockedExchange(FState, MEM_MUTEX_STATE_UNINITIALIZED);
            RaiseMutexError('Init', LResult);
          end;
          InterlockedExchange(FState, MEM_MUTEX_STATE_INITIALIZED);
          Exit;
        end;
      MEM_MUTEX_STATE_INITIALIZED:
        Exit;
    else
      platform_thread_yield;
    end;
  end;
end;

procedure TMemMutex.Done;
var
  LState: LongInt;
  LResult: Int32;
begin
  while True do
  begin
    LState := InterlockedCompareExchange(FState,
      MEM_MUTEX_STATE_UNINITIALIZED,
      MEM_MUTEX_STATE_UNINITIALIZED);
    case LState of
      MEM_MUTEX_STATE_UNINITIALIZED:
        Exit;
      MEM_MUTEX_STATE_INITIALIZED:
        begin
          if InterlockedCompareExchange(FState,
            MEM_MUTEX_STATE_DESTROYING,
            MEM_MUTEX_STATE_INITIALIZED) <> MEM_MUTEX_STATE_INITIALIZED then
            Continue;
          LResult := platform_mutex_destroy(FHandle);
          if LResult <> 0 then
          begin
            InterlockedExchange(FState, MEM_MUTEX_STATE_INITIALIZED);
            RaiseMutexError('Done', LResult);
          end;
          ZeroMem(@FHandle, SizeOf(FHandle));
          InterlockedExchange(FState, MEM_MUTEX_STATE_UNINITIALIZED);
          Exit;
        end;
    else
      platform_thread_yield;
    end;
  end;
end;

procedure TMemMutex.Acquire;
var
  LResult: Int32;
begin
  if InterlockedCompareExchange(FState,
    MEM_MUTEX_STATE_UNINITIALIZED,
    MEM_MUTEX_STATE_UNINITIALIZED) <> MEM_MUTEX_STATE_INITIALIZED then
    RaiseMutexError('Acquire', PLATFORM_ERR_INVALID);
  LResult := platform_mutex_lock(FHandle);
  if LResult <> 0 then
    RaiseMutexError('Acquire', LResult);
end;

procedure TMemMutex.Release;
var
  LResult: Int32;
begin
  if InterlockedCompareExchange(FState,
    MEM_MUTEX_STATE_UNINITIALIZED,
    MEM_MUTEX_STATE_UNINITIALIZED) <> MEM_MUTEX_STATE_INITIALIZED then
    RaiseMutexError('Release', PLATFORM_ERR_INVALID);
  LResult := platform_mutex_unlock(FHandle);
  if LResult <> 0 then
    RaiseMutexError('Release', LResult);
end;

end.
