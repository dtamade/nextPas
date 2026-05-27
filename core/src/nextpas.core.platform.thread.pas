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
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
uses
  nextpas.core.platform.darwin.base,
  nextpas.core.platform.darwin.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_ANDROID}
uses
  nextpas.core.platform.android.base,
  nextpas.core.platform.android.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_FREEBSD}
uses
  nextpas.core.platform.freebsd.base,
  nextpas.core.platform.freebsd.ffi;
{$ENDIF}

{$IF defined(NEXTPAS_UNIX) and not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_ANDROID) and not defined(NEXTPAS_FREEBSD)}
uses
  nextpas.core.platform.unix.base,
  nextpas.core.platform.unix.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_UNIX}
function platform_thread_host_state_create(out AState: PPlatformPThreadState; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_pthread_state_create(AState, AStartRoutine, AArgument);
  {$ELSE}
  Result := platform_pthread_state_create(AState, AStartRoutine, AArgument);
  {$ENDIF}
end;

function platform_thread_host_state_join(const AState: PPlatformPThreadState; out ARetVal: Pointer): Int32; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_pthread_state_join(AState, ARetVal);
  {$ELSE}
  Result := platform_pthread_state_join(AState, ARetVal);
  {$ENDIF}
end;

function platform_thread_host_state_detach(const AState: PPlatformPThreadState): Int32; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_pthread_state_detach(AState);
  {$ELSE}
  Result := platform_pthread_state_detach(AState);
  {$ENDIF}
end;

function platform_thread_host_self_token_u64: UInt64; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_thread_self_token_u64;
  {$ELSE}
  Result := platform_thread_self_token_u64;
  {$ENDIF}
end;

function platform_thread_host_native_thread_id_u64: UInt64; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_native_thread_id_u64;
  {$ELSE}
  Result := platform_native_thread_id_u64;
  {$ENDIF}
end;

procedure platform_thread_host_yield; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  linux_pthread_yield;
  {$ELSE}
  platform_pthread_yield;
  {$ENDIF}
end;

procedure platform_thread_host_sleep_ns(const ANanoseconds: UInt64); inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  linux_pthread_sleep_ns(ANanoseconds);
  {$ELSE}
  platform_pthread_sleep_ns(ANanoseconds);
  {$ENDIF}
end;

function platform_thread_host_tls_create(out AKey: PtrUInt): Int32; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_pthread_tls_create(AKey);
  {$ELSE}
  Result := platform_pthread_tls_create(AKey);
  {$ENDIF}
end;

function platform_thread_host_tls_destroy(const AKey: PtrUInt): Int32; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_pthread_tls_destroy(AKey);
  {$ELSE}
  Result := platform_pthread_tls_destroy(AKey);
  {$ENDIF}
end;

function platform_thread_host_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_pthread_tls_set(AKey, AValue);
  {$ELSE}
  Result := platform_pthread_tls_set(AKey, AValue);
  {$ENDIF}
end;

function platform_thread_host_tls_get(const AKey: PtrUInt): Pointer; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_pthread_tls_get(AKey);
  {$ELSE}
  Result := platform_pthread_tls_get(AKey);
  {$ENDIF}
end;

function platform_thread_host_cpu_count_i32: Int32; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_cpu_count_i32;
  {$ELSE}
  Result := platform_cpu_count_i32;
  {$ENDIF}
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

function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
var
  LState: PPlatformWindowsThreadState;
begin
  AHandle := nil;
  Result := windows_thread_state_create(TPlatformWindowsThreadProc(AProc), AArg, LState);
  if Result = 0 then
    AHandle := TPlatformThreadHandle(LState);
end;

function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
var
  LState: PPlatformWindowsThreadState;
begin
  LState := PPlatformWindowsThreadState(AHandle);
  Result := windows_thread_state_join(LState, ARetVal);
end;

function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
var
  LState: PPlatformWindowsThreadState;
begin
  LState := PPlatformWindowsThreadState(AHandle);
  Result := windows_thread_state_detach(LState);
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
begin
  Result := windows_tls_create_platform_key(AKey);
end;

function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
begin
  Result := windows_tls_destroy_platform_key(AKey);
end;

function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
begin
  Result := windows_tls_set_platform_key(AKey, AValue);
end;

function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;
begin
  Result := windows_tls_get_platform_key(AKey);
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
