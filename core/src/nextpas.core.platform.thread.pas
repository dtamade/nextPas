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
  {$IFDEF NEXTPAS_LINUX}nextpas.core.platform.linux.ffi
  {$ELSEIF defined(NEXTPAS_MACOS)}, nextpas.core.platform.darwin.ffi
  {$ELSEIF defined(NEXTPAS_ANDROID)}, nextpas.core.platform.android.ffi
  {$ELSEIF defined(NEXTPAS_FREEBSD)}, nextpas.core.platform.freebsd.ffi
  {$ELSE}, nextpas.core.platform.unix.ffi{$ENDIF};

type
  PPosixThreadState = ^TPosixThreadState;
  TPosixThreadState = record
    case Integer of
      0: (FAlign: PtrUInt);
      1: (Thread: array[0..PLATFORM_PTHREAD_TOKEN_SIZE - 1] of Byte);
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

  Result := platform_pthread_create_handle(@LState^.Thread[0], Pointer(AProc), AArg);
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
  Result := platform_pthread_join_handle(@LState^.Thread[0], @ARetVal);
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
  Result := platform_pthread_detach_handle(@LState^.Thread[0]);
  if Result = 0 then
    Dispose(LState);
end;

function platform_thread_self: TPlatformThreadToken;
begin
  Result := TPlatformThreadToken(platform_thread_self_token_u64);
end;

function platform_thread_id: UInt64;
begin
  Result := platform_native_thread_id_u64;
end;

procedure platform_thread_yield;
begin
  platform_pthread_yield;
end;

procedure platform_thread_sleep_ns(const ANanoseconds: UInt64);
begin
  platform_pthread_sleep_ns(ANanoseconds);
end;

{ TLS }

function platform_tls_create(out AKey: TPlatformTLSKey): Int32;
begin
  Result := platform_pthread_tls_create(AKey);
end;

function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
begin
  Result := platform_pthread_tls_destroy(AKey);
end;

function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
begin
  Result := platform_pthread_tls_set(AKey, AValue);
end;

function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;
begin
  Result := platform_pthread_tls_get(AKey);
end;

{ CPU }

function platform_cpu_count: Int32;
begin
  Result := platform_cpu_count_i32;
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

  if windows_atomic_decrement_i32(AState^.RefCount) = 0 then
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

  Result := windows_thread_create_handle(@WindowsThreadEntry, LState, LState^.Handle);
  if Result = 0 then
  begin
    AHandle := TPlatformThreadHandle(LState);
  end
  else
  begin
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
  Result := windows_thread_wait_terminated(LState^.Handle);
  if Result = 0 then
  begin
    ARetVal := LState^.ReturnValue;
    Result := windows_thread_close_handle(LState^.Handle);
    LState^.Handle := nil;
    WindowsReleaseThreadState(LState);
  end
end;

function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
var
  LState: PWindowsThreadState;
begin
  if AHandle = nil then
    Exit(-1);

  LState := PWindowsThreadState(AHandle);
  Result := windows_thread_close_handle(LState^.Handle);
  if Result = 0 then
  begin
    LState^.Handle := nil;
    WindowsReleaseThreadState(LState);
  end;
end;

function platform_thread_self: TPlatformThreadToken;
begin
  Result := TPlatformThreadToken(windows_current_thread_id_u64);
end;

function platform_thread_id: UInt64;
begin
  Result := windows_current_thread_id_u64;
end;

procedure platform_thread_yield;
begin
  windows_thread_yield;
end;

procedure platform_thread_sleep_ns(const ANanoseconds: UInt64);
begin
  windows_thread_sleep_ns(ANanoseconds);
end;

function platform_tls_create(out AKey: TPlatformTLSKey): Int32;
var
  LIdx: DWORD;
begin
  Result := windows_tls_alloc_key(LIdx);
  if Result = 0 then
  begin
    AKey := TPlatformTLSKey(LIdx);
  end
  else
    AKey := 0;
end;

function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
begin
  Result := windows_tls_free_key(DWORD(AKey));
end;

function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
begin
  Result := windows_tls_set_value(DWORD(AKey), AValue);
end;

function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;
begin
  Result := windows_tls_get_value(DWORD(AKey));
end;

function platform_cpu_count: Int32;
begin
  Result := windows_cpu_count_i32;
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
