unit nextpas.core.platform.linux.ffi;

{$I nextpas.core.settings.inc}

interface

const
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(1);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(84);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_MONOTONIC_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;

  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 0;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 2;

  PLATFORM_POSIX_EAGAIN = 11;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINTR = 4;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 95;
  PLATFORM_POSIX_ETIMEDOUT = 110;

  FUTEX_WAIT         = 0;
  FUTEX_WAKE         = 1;
  FUTEX_PRIVATE_FLAG = 128;

  {$IFDEF NEXTPAS_X86_64}
  LINUX_SYSCALL_FUTEX = 202;
  {$ELSEIF defined(NEXTPAS_AARCH64)}
  LINUX_SYSCALL_FUTEX = 98;
  {$ELSE}
    {$FATAL 'nextpas.core.platform.linux.ffi: unsupported Linux CPU for futex syscall'}
  {$ENDIF}

function linux_syscall(ANumber: PtrInt; A1: PtrUInt; A2: PtrUInt; A3: PtrUInt; A4: PtrUInt; A5: PtrUInt; A6: PtrUInt): PtrInt; cdecl; external 'c' name 'syscall';
function gettid: Int32; cdecl; external 'c' name 'gettid';
function platform_errno_location: PInt32; cdecl; external 'c' name '__errno_location';
function platform_posix_errno_value: Int32; inline;
function linux_futex_wait_i32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
function linux_futex_wake_one_i32(AAddr: PInt32): Int32;
function linux_futex_wake_all_i32(AAddr: PInt32): Int32;
function platform_thread_self_token_u64: UInt64; inline;
function platform_native_thread_id_u64: UInt64; inline;
function platform_cpu_count_i32: Int32; inline;
function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

implementation

uses
  nextpas.core.platform.posix.ffi;

function platform_posix_errno_value: Int32; inline;
begin
  Result := platform_errno_location^;
end;

function linux_futex_wait_i32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
var
  LRet: PtrInt;
  LTs: timespec;
begin
  if ATimeoutNs < 0 then
    LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
      PtrUInt(FUTEX_WAIT or FUTEX_PRIVATE_FLAG), PtrUInt(UInt32(AExpected)),
      PtrUInt(0), PtrUInt(0), PtrUInt(0))
  else
  begin
    LTs.tv_sec := ATimeoutNs div 1000000000;
    LTs.tv_nsec := ATimeoutNs mod 1000000000;
    LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
      PtrUInt(FUTEX_WAIT or FUTEX_PRIVATE_FLAG), PtrUInt(UInt32(AExpected)),
      PtrUInt(@LTs), PtrUInt(0), PtrUInt(0));
  end;

  if LRet >= 0 then
    Result := 0
  else
    Result := platform_posix_errno_value;
end;

function linux_futex_wake_one_i32(AAddr: PInt32): Int32;
var
  LRet: PtrInt;
begin
  LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
    PtrUInt(FUTEX_WAKE or FUTEX_PRIVATE_FLAG), PtrUInt(1),
    PtrUInt(0), PtrUInt(0), PtrUInt(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := platform_posix_errno_value;
end;

function linux_futex_wake_all_i32(AAddr: PInt32): Int32;
var
  LRet: PtrInt;
begin
  LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
    PtrUInt(FUTEX_WAKE or FUTEX_PRIVATE_FLAG), PtrUInt(High(Int32)),
    PtrUInt(0), PtrUInt(0), PtrUInt(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := platform_posix_errno_value;
end;

function platform_thread_self_token_u64: UInt64; inline;
begin
  Result := UInt64(PtrUInt(pthread_self));
end;

function platform_native_thread_id_u64: UInt64; inline;
begin
  Result := UInt64(UInt32(gettid));
end;

function platform_cpu_count_i32: Int32; inline;
var
  LResult: PtrInt;
begin
  LResult := sysconf(PLATFORM_SYSCONF_NPROCESSORS_ONLN);
  if LResult < 1 then
    Result := 1
  else
    Result := Int32(LResult);
end;

end.
