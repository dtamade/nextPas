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
function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
function platform_thread_self: TPlatformThreadToken;
function platform_thread_id: UInt64;
procedure platform_thread_yield;
procedure platform_thread_sleep_ns(const ANanoseconds: UInt64);

{ TLS }
function platform_tls_create(out AKey: TPlatformTLSKey): Int32;
function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;

{ CPU }
function platform_cpu_count: Int32;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.darwin.base,
  nextpas.core.platform.darwin.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_ANDROID}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.android.base,
  nextpas.core.platform.android.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_FREEBSD}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.freebsd.base,
  nextpas.core.platform.freebsd.ffi;
{$ENDIF}

{$IF defined(NEXTPAS_UNIX) and not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_ANDROID) and not defined(NEXTPAS_FREEBSD)}
uses
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
  Result := linux_errno_location;
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  Result := android_errno_location;
  {$ELSEIF defined(NEXTPAS_MACOS)}
  Result := darwin_errno_location;
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  Result := freebsd_errno_location;
  {$ELSE}
  Result := unix_errno_location;
  {$ENDIF}
end;

function platform_thread_host_state_create(out AState: PPlatformPThreadState; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
begin
  AState := nil;
  if AStartRoutine = nil then
    Exit(-1);

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
    Exit(-1);

  Result := pthread_join(PPThreadToken(@AState^.Thread[0])^, @ARetVal);
  if Result = 0 then
    Dispose(AState);
end;

function platform_thread_host_state_detach(const AState: PPlatformPThreadState): Int32; inline;
begin
  if AState = nil then
    Exit(-1);

  Result := pthread_detach(PPThreadToken(@AState^.Thread[0])^);
  if Result = 0 then
    Dispose(AState);
end;

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
    if (LErrno = nil) or (LErrno^ <> PLATFORM_POSIX_EINTR) then
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
  LResult := sysconf(PLATFORM_SYSCONF_NPROCESSORS_ONLN);
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

{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
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
    Exit(-1);

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
    Exit(-1);

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
    Exit(-1);

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
function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32; begin AHandle := nil; Result := -1; end;
function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32; begin ARetVal := nil; Result := -1; end;
function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32; begin Result := -1; end;
function platform_thread_self: TPlatformThreadToken; begin Result := 0; end;
function platform_thread_id: UInt64; begin Result := 0; end;
procedure platform_thread_yield; begin end;
procedure platform_thread_sleep_ns(const ANanoseconds: UInt64); begin end;
function platform_tls_create(out AKey: TPlatformTLSKey): Int32; begin AKey := 0; Result := -1; end;
function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32; begin Result := -1; end;
function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32; begin Result := -1; end;
function platform_tls_get(const AKey: TPlatformTLSKey): Pointer; begin Result := nil; end;
function platform_cpu_count: Int32; begin Result := 1; end;
{$ENDIF}{$ENDIF}

end.
