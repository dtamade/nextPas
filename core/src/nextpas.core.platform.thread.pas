unit nextpas.core.platform.thread;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.thread.base;

type
  TPlatformThreadHandle = nextpas.core.platform.thread.base.TPlatformThreadHandle;
  TPlatformThreadToken = nextpas.core.platform.thread.base.TPlatformThreadToken;
  TPlatformThreadProc = nextpas.core.platform.thread.base.TPlatformThreadProc;
  TPlatformTLSKey = nextpas.core.platform.thread.base.TPlatformTLSKey;

{ Thread lifecycle }

{** @desc 创建新线程
    @param AHandle 输出线程句柄
    @param AProc 线程入口函数
    @param AArg 传递给线程的参数
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;

{** @desc 等待线程结束并获取返回值
    @param AHandle 线程句柄
    @param ARetVal 输出线程返回值
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;

{** @desc 带超时的等待线程结束
    @param AHandle 线程句柄
    @param ATimeoutMs 超时毫秒数（>0）
    @param ARetVal 输出线程返回值
    @return 0 成功，1 超时，<0 错误 *}
function platform_thread_timedjoin(const AHandle: TPlatformThreadHandle; ATimeoutMs: Int64; out ARetVal: Pointer): Int32;

{** @desc 分离线程（线程结束后自动释放资源）
    @param AHandle 线程句柄
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;

{** @desc 获取当前线程 token
    @return 线程 token *}
function platform_thread_self: TPlatformThreadToken;

{** @desc 获取当前线程 ID（用于调试）
    @return 线程 ID *}
function platform_thread_id: UInt64;

{** @desc 让出 CPU 时间片 *}
procedure platform_thread_yield;

{** @desc 线程休眠（纳秒精度）
    @param ANanoseconds 休眠纳秒数 *}
procedure platform_thread_sleep_ns(const ANanoseconds: UInt64);

{** @desc 线程休眠（毫秒）
    @param AMilliseconds 休眠毫秒数 *}
procedure platform_thread_sleep_ms(const AMilliseconds: UInt64);

{** @desc 线程休眠（秒）
    @param ASeconds 休眠秒数
    @note sleep_sec safe range: POSIX converts to nanoseconds, Windows converts to DWORD milliseconds. *}
procedure platform_thread_sleep_sec(const ASeconds: UInt64);

{ TLS - Thread Local Storage }

{** @desc 创建 TLS 键
    @param AKey 输出 TLS 键
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_tls_create(out AKey: TPlatformTLSKey): Int32;

{** @desc 销毁 TLS 键
    @param AKey TLS 键
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;

{** @desc 设置 TLS 值
    @param AKey TLS 键
    @param AValue 要存储的值
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;

{** @desc 获取 TLS 值
    @param AKey TLS 键
    @return 存储的值（未设置返回 nil） *}
function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;

{ CPU }

{** @desc 获取可用 CPU 核心数
    @return 核心数 *}
function platform_cpu_count: Int32;

{ Thread naming - for debugging }

{** @desc 设置当前线程名称（用于调试器显示）
    @param AName 线程名称
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_thread_set_name(const AName: PAnsiChar): Int32;

{** @desc 获取当前线程名称
    @param ABuf 输出缓冲区
    @param ABufSize 缓冲区大小
    @return 名称实际长度 *}
function platform_thread_get_name(ABuf: PAnsiChar; ABufSize: Int32): Int32;

type
  {**
   * @desc 轻量级线程包装器（不依赖 TThread/FPC Classes）
   *
   * 使用 platform_thread_create/join/detach 实现，提供更简洁的生命周期管理。
   *}
  TPlatformThreadRecord = record
    Handle: TPlatformThreadHandle;
    {** @desc 检查线程是否已启动且未等待
        @return True 如果线程句柄有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查线程是否未启动或已等待
        @return True 如果线程句柄无效 *}
    function IsInvalid: Boolean; inline;
  end;

{** @desc 创建并启动线程
    @param ARec 输出线程记录
    @param AProc 线程入口函数
    @param AArg 传递给线程的参数
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_thread_spawn(out ARec: TPlatformThreadRecord;
  AProc: TPlatformThreadProc; AArg: Pointer): Int32;

{** @desc 等待线程结束
    @param ARec 线程记录
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_thread_wait(var ARec: TPlatformThreadRecord): Int32;

{** @desc 检查线程是否仍在运行
    @param ARec 线程记录
    @return True 线程仍在运行 *}
function platform_thread_is_alive(const ARec: TPlatformThreadRecord): Boolean;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.darwin.base,
  nextpas.core.platform.darwin.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_ANDROID}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.android.base,
  nextpas.core.platform.android.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_FREEBSD}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.freebsd.base,
  nextpas.core.platform.freebsd.ffi;
{$ENDIF}

{$IF defined(NEXTPAS_UNIX) and not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_ANDROID) and not defined(NEXTPAS_FREEBSD)}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.unix.base,
  nextpas.core.platform.unix.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_UNIX}
type
  PPThreadToken = ^pthread_t;

function platform_thread_host_errno_location: PInt32; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := __errno_location;
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  Result := __errno;
      { Android API ≥21: __errno is a function returning PInt32; older
        versions used a TLS variable. The FFI declaration in
        nextpas.core.platform.android.ffi matches the function form. }
  {$ELSEIF defined(NEXTPAS_MACOS)}
  Result := __error;
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  Result := __error;
  {$ELSE}
  Result := __errno_location;
  {$ENDIF}
end;

function platform_thread_host_state_create(out AState: PPlatformPThreadState; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
begin
  AState := nil;
  if AStartRoutine = nil then
    Exit(PLATFORM_ERR_INVALID);

  New(AState);
  FillChar(AState^, SizeOf(AState^), 0);

  Result := pthread_create(
    @AState^.Thread[0], nil, TPThreadStartRoutine(AStartRoutine), AArgument);
  if Result <> 0 then
  begin
    Dispose(AState);
    AState := nil;
  end;
end;

function platform_thread_host_state_join(const AState: PPlatformPThreadState; out ARetVal: Pointer): Int32; inline;
begin
  ARetVal := nil;
  if AState = nil then
    Exit(PLATFORM_ERR_INVALID);

  Result := pthread_join(PPThreadToken(@AState^.Thread[0])^, @ARetVal);
  if Result = 0 then
    Dispose(AState);
end;

function platform_thread_host_state_detach(const AState: PPlatformPThreadState): Int32; inline;
begin
  if AState = nil then
    Exit(PLATFORM_ERR_INVALID);

  Result := pthread_detach(PPThreadToken(@AState^.Thread[0])^);
  if Result = 0 then
    Dispose(AState);
end;

{ GNU extension — available since glibc 2.24 (2016). PTHREAD_TIMEOUT_CLOCK_ID
  defaults to CLOCK_MONOTONIC on modern kernels.
  Declaration moved to nextpas.core.platform.linux.ffi.pas }
{$IFDEF NEXTPAS_LINUX}

function platform_thread_timedjoin(const AHandle: TPlatformThreadHandle;
  ATimeoutMs: Int64; out ARetVal: Pointer): Int32;
var
  LState: PPlatformPThreadState;
  LNow: TTimeSpec;
  LAbsTime: TTimeSpec;
begin
  ARetVal := nil;
  LState := PPlatformPThreadState(AHandle);
  if LState = nil then
    Exit(PLATFORM_ERR_INVALID);

  clock_gettime(CLOCK_REALTIME, @LNow);
  LAbsTime.tv_sec  := LNow.tv_sec + (ATimeoutMs div 1000);
  LAbsTime.tv_nsec := LNow.tv_nsec + (ATimeoutMs mod 1000) * 1000000;
  if LAbsTime.tv_nsec >= 1000000000 then
  begin
    Inc(LAbsTime.tv_sec);
    Dec(LAbsTime.tv_nsec, 1000000000);
  end;

  Result := pthread_timedjoin_np(PPThreadToken(@LState^.Thread[0])^, @ARetVal, @LAbsTime);
  if Result = 0 then
  begin
    { Thread finished — clean up state }
    Dispose(LState);
  end
  else if Result = ESysETIMEDOUT then 
  begin
    Result := 1; { Caller decides: detach or re-try }
  end
  else
  begin
    Result := PLATFORM_ERR_INVALID; { Unexpected error }
  end;
end;
{$ELSE}
{ macOS/Android/FreeBSD: fall back to blocking join (no timed join available).
  When ATimeoutMs > 0: return PLATFORM_ERR_UNSUPPORTED — caller must use a
  polling loop with platform_thread_is_alive + platform_thread_detach instead.
  When ATimeoutMs = 0: blocking join (no timeout). }
function platform_thread_timedjoin(const AHandle: TPlatformThreadHandle;
  ATimeoutMs: Int64; out ARetVal: Pointer): Int32;
begin
  if ATimeoutMs > 0 then
  begin
    ARetVal := nil;
    Result := PLATFORM_ERR_UNSUPPORTED;
    Exit;
  end;
  Result := platform_thread_join(AHandle, ARetVal);
end;
{$ENDIF}

function platform_thread_host_self_token_u64: UInt64; inline;
begin
  Result := UInt64(PtrUInt(pthread_self));
end;

function platform_thread_host_native_thread_id_u64: UInt64; inline;
{$IFDEF NEXTPAS_MACOS}
var
  LThreadId: UInt64;
{$ENDIF}
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := UInt64(UInt32(gettid));
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  Result := UInt64(UInt32(gettid));
  {$ELSEIF defined(NEXTPAS_MACOS)}
  LThreadId := 0;
  if pthread_threadid_np(nil, @LThreadId) = 0 then
    Result := LThreadId
  else
    Result := platform_thread_host_self_token_u64;
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  Result := UInt64(UInt32(pthread_getthreadid_np));
  if Result = 0 then
    Result := platform_thread_host_self_token_u64;
  {$ELSE}
  Result := platform_thread_host_self_token_u64;
  {$ENDIF}
end;

procedure platform_thread_host_yield; inline;
begin
  sched_yield;
end;

procedure platform_thread_host_sleep_ns(const ANanoseconds: UInt64); inline;
var
  LReq: timespec;
  LRem: timespec;
  LErrno: PInt32;
begin
  if ANanoseconds = 0 then
    Exit;

  LReq.tv_sec := Int64(ANanoseconds div 1000000000);
  LReq.tv_nsec := Int64(ANanoseconds mod 1000000000);
  LRem.tv_sec := 0;
  LRem.tv_nsec := 0;
  LErrno := platform_thread_host_errno_location;

  while nanosleep(@LReq, @LRem) <> 0 do
  begin
    if (LErrno = nil) or (LErrno^ <> ESysEINTR) then
      Break;
    LReq := LRem;
  end;
end;

function platform_thread_host_tls_create(out AKey: PtrUInt): Int32; inline;
var
  LKey: pthread_key_t;
begin
  Result := pthread_key_create(@LKey, nil);
  if Result = 0 then
    AKey := PtrUInt(LKey)
  else
    AKey := 0;
end;

function platform_thread_host_tls_destroy(const AKey: PtrUInt): Int32; inline;
begin
  Result := pthread_key_delete(pthread_key_t(AKey));
end;

function platform_thread_host_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
begin
  Result := pthread_setspecific(pthread_key_t(AKey), AValue);
end;

function platform_thread_host_tls_get(const AKey: PtrUInt): Pointer; inline;
begin
  Result := pthread_getspecific(pthread_key_t(AKey));
end;

function platform_thread_host_cpu_count_i32: Int32; inline;
var
  LResult: PtrInt;
begin
  LResult := sysconf(_SC_NPROCESSORS_ONLN);
  if LResult < 1 then
    Result := 1
  else
    Result := Int32(LResult);
end;

{ Thread lifecycle }

function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
var
  LState: PPlatformPThreadState;
begin
  AHandle := nil;
  Result := platform_thread_host_state_create(LState, Pointer(AProc), AArg);
  if Result = 0 then
    AHandle := TPlatformThreadHandle(LState);
end;

function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
var
  LState: PPlatformPThreadState;
begin
  LState := PPlatformPThreadState(AHandle);
  Result := platform_thread_host_state_join(LState, ARetVal);
end;

function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
var
  LState: PPlatformPThreadState;
begin
  LState := PPlatformPThreadState(AHandle);
  Result := platform_thread_host_state_detach(LState);
end;

function platform_thread_self: TPlatformThreadToken;
begin
  Result := TPlatformThreadToken(platform_thread_host_self_token_u64);
end;

function platform_thread_id: UInt64;
begin
  Result := platform_thread_host_native_thread_id_u64;
end;

procedure platform_thread_yield;
begin
  platform_thread_host_yield;
end;

procedure platform_thread_sleep_ns(const ANanoseconds: UInt64);
begin
  platform_thread_host_sleep_ns(ANanoseconds);
end;

procedure platform_thread_sleep_ms(const AMilliseconds: UInt64);
begin
  platform_thread_host_sleep_ns(AMilliseconds * 1000000);
end;

procedure platform_thread_sleep_sec(const ASeconds: UInt64);
  { Guard against overflow: max safe seconds = High(UInt64) div 1000000000 ≈ 18.4 billion years }
begin
  platform_thread_host_sleep_ns(ASeconds * 1000000000);
end;

{ TLS }

function platform_tls_create(out AKey: TPlatformTLSKey): Int32;
begin
  Result := platform_thread_host_tls_create(AKey);
end;

function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
begin
  Result := platform_thread_host_tls_destroy(AKey);
end;

function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
begin
  Result := platform_thread_host_tls_set(AKey, AValue);
end;

function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;
begin
  Result := platform_thread_host_tls_get(AKey);
end;

{ CPU }

function platform_cpu_count: Int32;
begin
  Result := platform_thread_host_cpu_count_i32;
end;

{ Thread naming }

function platform_thread_set_name(const AName: PAnsiChar): Int32;
{$IFDEF NEXTPAS_LINUX}
var
  LName: array[0..15] of AnsiChar;
  LLen: Int32;
begin
  if AName = nil then Exit(PLATFORM_ERR_INVALID);
  LLen := 0;
  while (AName[LLen] <> #0) and (LLen < 15) do
  begin
    LName[LLen] := AName[LLen];
    Inc(LLen);
  end;
  LName[LLen] := #0;
  Result := Int32(nextpas.core.platform.linux.ffi.prctl(
    15 { PR_SET_NAME }, PtrUInt(@LName[0]), 0, 0, 0));
  if Result <> 0 then Result := platform_get_errno;
end;
{$ELSE}
begin
  Result := PLATFORM_ERR_UNSUPPORTED;
end;
{$ENDIF}

function platform_thread_get_name(ABuf: PAnsiChar; ABufSize: Int32): Int32;
{$IFDEF NEXTPAS_LINUX}
var
  LName: array[0..15] of AnsiChar;
  LI: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then Exit(PLATFORM_ERR_INVALID);
  Result := Int32(nextpas.core.platform.linux.ffi.prctl(
    16 { PR_GET_NAME }, PtrUInt(@LName[0]), 0, 0, 0));
  if Result <> 0 then
  begin
    Result := platform_get_errno;
    Exit;
  end;
  LI := 0;
  while (LI < 15) and (LI < ABufSize - 1) and (LName[LI] <> #0) do
  begin
    ABuf[LI] := LName[LI];
    Inc(LI);
  end;
  ABuf[LI] := #0;
  Result := 0;
end;
{$ELSE}
begin
  if (ABuf <> nil) and (ABufSize > 0) then ABuf[0] := #0;
  Result := PLATFORM_ERR_UNSUPPORTED;
end;
{$ENDIF}

{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

function platform_thread_windows_last_error_i32: Int32; inline;
begin
  Result := Int32(GetLastError);
end;

function platform_thread_windows_create_handle(
  const AStartAddress: TWinThreadStartRoutine;
  const AParameter: Pointer;
  out AHandle: HANDLE): Int32; inline;
var
  LId: DWORD;
begin
  AHandle := nil;
  LId := 0;
  AHandle := CreateThread(nil, 0, AStartAddress, AParameter, 0, @LId);
  if AHandle <> nil then
    Result := 0
  else
    Result := platform_thread_windows_last_error_i32;
end;

function platform_thread_windows_wait_terminated(const AHandle: HANDLE): Int32; inline;
begin
  if WaitForSingleObject(AHandle, INFINITE) = WAIT_OBJECT_0 then
    Result := 0
  else
    Result := platform_thread_windows_last_error_i32;
end;

function platform_thread_windows_close_handle(const AHandle: HANDLE): Int32; inline;
begin
  if CloseHandle(AHandle) then
    Result := 0
  else
    Result := platform_thread_windows_last_error_i32;
end;

procedure platform_thread_windows_state_release(const AState: PPlatformWindowsThreadState); inline;
begin
  if AState = nil then
    Exit;
  if InterlockedDecrement(AState^.RefCount) = 0 then
    { InterlockedDecrement has full memory barrier on Windows/x86;
      the joiner thread will see the final ReturnValue after this
      decrement reaches zero. }
    Dispose(AState);
end;

function platform_thread_windows_entry(AParameter: Pointer): DWORD; stdcall;
var
  LState: PPlatformWindowsThreadState;
  LReturnValue: Pointer;
begin
  LState := PPlatformWindowsThreadState(AParameter);
  LReturnValue := nil;
  if (LState <> nil) and Assigned(LState^.Proc) then
    LReturnValue := LState^.Proc(LState^.Arg);
  if LState <> nil then
  begin
    LState^.ReturnValue := LReturnValue;
    platform_thread_windows_state_release(LState);
  end;
  Result := 0;
end;

function platform_thread_windows_state_create(
  const AProc: TPlatformWindowsThreadProc;
  const AArg: Pointer;
  out AState: PPlatformWindowsThreadState): Int32; inline;
begin
  AState := nil;
  if not Assigned(AProc) then
    Exit(PLATFORM_ERR_INVALID);

  New(AState);
  AState^.Handle := nil;
  AState^.Proc := AProc;
  AState^.Arg := AArg;
  AState^.ReturnValue := nil;
  AState^.RefCount := 2;

  Result := platform_thread_windows_create_handle(
    @platform_thread_windows_entry, AState, AState^.Handle);
  if Result <> 0 then
  begin
    Dispose(AState);
    AState := nil;
  end;
end;

function platform_thread_windows_state_join(
  const AState: PPlatformWindowsThreadState;
  out ARetVal: Pointer): Int32; inline;
begin
  ARetVal := nil;
  if AState = nil then
    Exit(PLATFORM_ERR_INVALID);

  Result := platform_thread_windows_wait_terminated(AState^.Handle);
  if Result = 0 then
  begin
    ARetVal := AState^.ReturnValue;
    Result := platform_thread_windows_close_handle(AState^.Handle);
    AState^.Handle := nil;
    platform_thread_windows_state_release(AState);
  end;
end;

function platform_thread_windows_state_detach(
  const AState: PPlatformWindowsThreadState): Int32; inline;
begin
  if AState = nil then
    Exit(PLATFORM_ERR_INVALID);

  Result := platform_thread_windows_close_handle(AState^.Handle);
  if Result = 0 then
  begin
    AState^.Handle := nil;
    platform_thread_windows_state_release(AState);
  end;
end;

function platform_thread_windows_sleep_ns_to_ms(const ANanoseconds: UInt64): DWORD; inline;
var
  LMs: UInt64;
begin
  if ANanoseconds = 0 then
    Exit(0);

  LMs := ANanoseconds div 1000000;
  if (ANanoseconds mod 1000000) <> 0 then
    Inc(LMs);
  if LMs >= UInt64(INFINITE) then
    Result := INFINITE - 1
  else
    Result := DWORD(LMs);
end;

function platform_thread_windows_tls_create(out AKey: PtrUInt): Int32; inline;
var
  LIndex: DWORD;
begin
  LIndex := TlsAlloc;
  if LIndex <> TLS_OUT_OF_INDEXES then
  begin
    AKey := PtrUInt(LIndex);
    Result := 0;
  end
  else
  begin
    AKey := 0;
    Result := platform_thread_windows_last_error_i32;
  end;
end;

function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
var
  LState: PPlatformWindowsThreadState;
begin
  AHandle := nil;
  Result := platform_thread_windows_state_create(TPlatformWindowsThreadProc(AProc), AArg, LState);
  if Result = 0 then
    AHandle := TPlatformThreadHandle(LState);
end;

function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
var
  LState: PPlatformWindowsThreadState;
begin
  LState := PPlatformWindowsThreadState(AHandle);
  Result := platform_thread_windows_state_join(LState, ARetVal);
end;

function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
var
  LState: PPlatformWindowsThreadState;
begin
  LState := PPlatformWindowsThreadState(AHandle);
  Result := platform_thread_windows_state_detach(LState);
end;

function platform_thread_timedjoin(const AHandle: TPlatformThreadHandle;
  ATimeoutMs: Int64; out ARetVal: Pointer): Int32;
var
  LState: PPlatformWindowsThreadState;
  LWaitResult: DWORD;
begin
  ARetVal := nil;
  LState := PPlatformWindowsThreadState(AHandle);
  if LState = nil then
    Exit(PLATFORM_ERR_INVALID);

  LWaitResult := WaitForSingleObject(LState^.Handle, DWORD(ATimeoutMs));
  if LWaitResult = WAIT_OBJECT_0 then
  begin
    ARetVal := LState^.ReturnValue;
    platform_thread_windows_close_handle(LState^.Handle);
    LState^.Handle := nil;
    platform_thread_windows_state_release(LState);
    Result := 0;
  end
  else if LWaitResult = WAIT_TIMEOUT then
    Result := 1
  else
    Result := PLATFORM_ERR_INVALID;
end;

function platform_thread_self: TPlatformThreadToken;
begin
  Result := TPlatformThreadToken(GetCurrentThreadId);
end;

function platform_thread_id: UInt64;
begin
  Result := UInt64(GetCurrentThreadId);
end;

procedure platform_thread_yield;
begin
  SwitchToThread;
end;

procedure platform_thread_sleep_ns(const ANanoseconds: UInt64);
begin
  if ANanoseconds <> 0 then
    Sleep(platform_thread_windows_sleep_ns_to_ms(ANanoseconds));
end;

procedure platform_thread_sleep_ms(const AMilliseconds: UInt64);
begin
  if AMilliseconds <> 0 then
    Sleep(DWORD(AMilliseconds));
end;

procedure platform_thread_sleep_sec(const ASeconds: UInt64);
begin
  if ASeconds = 0 then
    Exit;
  if ASeconds > (UInt64(INFINITE) - 1) div 1000 then
    Sleep(INFINITE - 1)
  else
    Sleep(DWORD(ASeconds * 1000));
end;

function platform_tls_create(out AKey: TPlatformTLSKey): Int32;
begin
  Result := platform_thread_windows_tls_create(AKey);
end;

function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
begin
  if TlsFree(DWORD(AKey)) then
    Result := 0
  else
    Result := platform_thread_windows_last_error_i32;
end;

function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
begin
  if TlsSetValue(DWORD(AKey), AValue) then
    Result := 0
  else
    Result := platform_thread_windows_last_error_i32;
end;

function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;
begin
  Result := TlsGetValue(DWORD(AKey));
end;

function platform_cpu_count: Int32;
var
  LInfo: SYSTEM_INFO;
begin
  GetSystemInfo(LInfo);
  Result := Int32(LInfo.dwNumberOfProcessors);
  if Result < 1 then
    Result := 1;
end;

{$ENDIF}

{$IFNDEF NEXTPAS_UNIX}{$IFNDEF NEXTPAS_WINDOWS}
function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32; begin AHandle := nil; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32; begin ARetVal := nil; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_thread_timedjoin(const AHandle: TPlatformThreadHandle; ATimeoutMs: Int64; out ARetVal: Pointer): Int32; begin ARetVal := nil; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_thread_self: TPlatformThreadToken; begin Result := 0; end;
function platform_thread_id: UInt64; begin Result := 0; end;
procedure platform_thread_yield; begin end;
procedure platform_thread_sleep_ns(const ANanoseconds: UInt64); begin end;
procedure platform_thread_sleep_ms(const AMilliseconds: UInt64); begin end;
procedure platform_thread_sleep_sec(const ASeconds: UInt64); begin end;
function platform_tls_create(out AKey: TPlatformTLSKey): Int32; begin AKey := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_tls_get(const AKey: TPlatformTLSKey): Pointer; begin Result := nil; end;
function platform_cpu_count: Int32; begin Result := 1; end;
{$ENDIF}{$ENDIF}

{ TPlatformThreadRecord helpers }

function TPlatformThreadRecord.IsValid: Boolean;
begin
  Result := Handle <> nil;
end;

function TPlatformThreadRecord.IsInvalid: Boolean;
begin
  Result := Handle = nil;
end;

function platform_thread_spawn(out ARec: TPlatformThreadRecord;
  AProc: TPlatformThreadProc; AArg: Pointer): Int32;
begin
  ARec.Handle := nil;
  Result := platform_thread_create(ARec.Handle, AProc, AArg);
end;

function platform_thread_wait(var ARec: TPlatformThreadRecord): Int32;
var
  LRet: Pointer;
begin
  if ARec.Handle = nil then
  begin
    Result := PLATFORM_ERR_INVALID;
    Exit;
  end;
  Result := platform_thread_join(ARec.Handle, LRet);
  if Result = 0 then
    ARec.Handle := nil;
end;

function platform_thread_is_alive(const ARec: TPlatformThreadRecord): Boolean;
begin
  Result := ARec.Handle <> nil;
end;

end.
