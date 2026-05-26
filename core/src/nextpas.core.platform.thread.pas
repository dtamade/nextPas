unit nextpas.core.platform.thread;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformThreadHandle = Pointer;
  TPlatformThreadToken = UInt64;
  TPlatformThreadProc = function(AArg: Pointer): Pointer; cdecl;
  TPlatformTLSKey = PtrUInt;

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

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_LINUX}, nextpas.core.platform.linux.ffi
  {$ELSEIF defined(NEXTPAS_MACOS)}, nextpas.core.platform.darwin.ffi
  {$ELSEIF defined(NEXTPAS_ANDROID)}, nextpas.core.platform.android.ffi
  {$ELSEIF defined(NEXTPAS_FREEBSD)}, nextpas.core.platform.freebsd.ffi
  {$ELSE}, nextpas.core.platform.unix.ffi{$ENDIF};

type
  PPosixThreadState = ^TPosixThreadState;
  TPosixThreadState = record
    Thread: pthread_t;
  end;

function platform_posix_errno: Int32; inline;
begin
  Result := platform_errno_location^;
end;

{ Thread lifecycle }

function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
var
  LState: PPosixThreadState;
begin
  AHandle := nil;
  if not Assigned(AProc) then
    Exit(-1);

  New(LState);
  FillChar(LState^, SizeOf(LState^), 0);

  Result := pthread_create(@LState^.Thread, nil, TPThreadStartRoutine(AProc), AArg);
  if Result = 0 then
    AHandle := TPlatformThreadHandle(LState)
  else
  begin
    Dispose(LState);
    AHandle := nil;
  end;
end;

function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
var
  LState: PPosixThreadState;
begin
  ARetVal := nil;
  if AHandle = nil then
    Exit(-1);

  LState := PPosixThreadState(AHandle);
  Result := pthread_join(LState^.Thread, @ARetVal);
  if Result = 0 then
    Dispose(LState);
end;

function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
var
  LState: PPosixThreadState;
begin
  if AHandle = nil then
    Exit(-1);

  LState := PPosixThreadState(AHandle);
  Result := pthread_detach(LState^.Thread);
  if Result = 0 then
    Dispose(LState);
end;

function platform_thread_self: TPlatformThreadToken;
begin
  Result := TPlatformThreadToken(PtrUInt(pthread_self));
end;

function platform_thread_id: UInt64;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := UInt64(UInt32(gettid));
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  Result := UInt64(UInt32(gettid));
  {$ELSEIF defined(NEXTPAS_MACOS)}
  Result := 0;
  if pthread_threadid_np(nil, @Result) <> 0 then
    Result := UInt64(platform_thread_self);
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  Result := UInt64(UInt32(pthread_getthreadid_np));
  if Result = 0 then
    Result := UInt64(platform_thread_self);
  {$ELSE}
  Result := UInt64(PtrUInt(pthread_self));
  {$ENDIF}
end;

procedure platform_thread_yield;
begin
  sched_yield;
end;

procedure platform_thread_sleep_ns(const ANanoseconds: UInt64);
var
  LReq, LRem: timespec;
begin
  if ANanoseconds = 0 then
    Exit;

  LReq.tv_sec := ANanoseconds div 1000000000;
  LReq.tv_nsec := ANanoseconds mod 1000000000;
  LRem.tv_sec := 0;
  LRem.tv_nsec := 0;

  while nanosleep(@LReq, @LRem) <> 0 do
  begin
    if platform_posix_errno <> PLATFORM_POSIX_EINTR then
      Break;
    LReq := LRem;
  end;
end;

{ TLS }

function platform_tls_create(out AKey: TPlatformTLSKey): Int32;
var
  LKey: pthread_key_t;
begin
  Result := pthread_key_create(@LKey, nil);
  if Result = 0 then
    AKey := TPlatformTLSKey(LKey)
  else
    AKey := 0;
end;

function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
begin
  Result := pthread_key_delete(pthread_key_t(AKey));
end;

function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
begin
  Result := pthread_setspecific(pthread_key_t(AKey), AValue);
end;

function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;
begin
  Result := pthread_getspecific(pthread_key_t(AKey));
end;

{ CPU }

function platform_cpu_count: Int32;
var
  LResult: PtrInt;
begin
  LResult := sysconf(PLATFORM_SYSCONF_NPROCESSORS_ONLN);
  if LResult < 1 then
    Result := 1
  else
    Result := Int32(LResult);
end;

{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.ffi;

type
  PWindowsThreadState = ^TWindowsThreadState;
  TWindowsThreadState = record
    Handle: HANDLE;
    Proc: TPlatformThreadProc;
    Arg: Pointer;
    ReturnValue: Pointer;
    RefCount: Int32;
  end;

procedure WindowsReleaseThreadState(const AState: PWindowsThreadState);
begin
  if AState = nil then
    Exit;

  if InterlockedDecrement(AState^.RefCount) = 0 then
    Dispose(AState);
end;

function WindowsThreadEntry(AParameter: Pointer): DWORD; stdcall;
var
  LState: PWindowsThreadState;
  LReturnValue: Pointer;
begin
  LState := PWindowsThreadState(AParameter);
  LReturnValue := nil;

  if (LState <> nil) and Assigned(LState^.Proc) then
    LReturnValue := LState^.Proc(LState^.Arg);

  if LState <> nil then
  begin
    LState^.ReturnValue := LReturnValue;
    WindowsReleaseThreadState(LState);
  end;

  Result := 0;
end;

function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
var
  LId: DWORD;
  LState: PWindowsThreadState;
begin
  AHandle := nil;
  if not Assigned(AProc) then
    Exit(-1);

  New(LState);
  LState^.Handle := nil;
  LState^.Proc := AProc;
  LState^.Arg := AArg;
  LState^.ReturnValue := nil;
  LState^.RefCount := 2;

  LState^.Handle := CreateThread(nil, 0, @WindowsThreadEntry, LState, 0, @LId);
  if LState^.Handle <> nil then
  begin
    AHandle := TPlatformThreadHandle(LState);
    Result := 0
  end
  else
  begin
    Result := windows_last_error_i32;
    Dispose(LState);
  end;
end;

function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
var
  LState: PWindowsThreadState;
begin
  ARetVal := nil;
  if AHandle = nil then
    Exit(-1);

  LState := PWindowsThreadState(AHandle);
  if windows_wait_for_single_object_is_signaled(
    WaitForSingleObject(LState^.Handle, INFINITE)) then
  begin
    ARetVal := LState^.ReturnValue;
    if CloseHandle(LState^.Handle) then
      Result := 0
    else
      Result := windows_last_error_i32;
    LState^.Handle := nil;
    WindowsReleaseThreadState(LState);
  end
  else
    Result := windows_last_error_i32;
end;

function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
var
  LState: PWindowsThreadState;
begin
  if AHandle = nil then
    Exit(-1);

  LState := PWindowsThreadState(AHandle);
  if CloseHandle(LState^.Handle) then
  begin
    LState^.Handle := nil;
    WindowsReleaseThreadState(LState);
    Result := 0
  end
  else
    Result := windows_last_error_i32;
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
var
  LMs: DWORD;
begin
  if ANanoseconds = 0 then
    Exit;

  LMs := windows_sleep_ns_to_ms(ANanoseconds);
  Sleep(LMs);
end;

function platform_tls_create(out AKey: TPlatformTLSKey): Int32;
var
  LIdx: DWORD;
begin
  LIdx := TlsAlloc;
  if LIdx <> TLS_OUT_OF_INDEXES then
  begin
    AKey := TPlatformTLSKey(LIdx);
    Result := 0;
  end
  else
  begin
    AKey := 0;
    Result := windows_last_error_i32;
  end;
end;

function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
begin
  if TlsFree(DWORD(AKey)) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
begin
  if TlsSetValue(DWORD(AKey), AValue) then
    Result := 0
  else
    Result := windows_last_error_i32;
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
