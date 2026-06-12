unit nextpas.core.platform.thread;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.platform.thread.base;

type
  TPlatformThreadHandle = nextpas.core.platform.thread.base.TPlatformThreadHandle;
  TPlatformThreadToken = nextpas.core.platform.thread.base.TPlatformThreadToken;
  TPlatformThreadProc = nextpas.core.platform.thread.base.TPlatformThreadProc;
  TPlatformTLSKey = nextpas.core.platform.thread.base.TPlatformTLSKey;

procedure TestThreadReset;
function TestThreadYieldCount: SizeUInt;

function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
function platform_thread_self: TPlatformThreadToken;
function platform_thread_id: UInt64;
procedure platform_thread_yield;
procedure platform_thread_sleep_ns(const ANanoseconds: UInt64);
function platform_tls_create(out AKey: TPlatformTLSKey): Int32;
function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;
function platform_cpu_count: Int32;

implementation

const
  MAX_TEST_YIELDS = 4;

var
  GYieldCount: SizeUInt = 0;

procedure TestThreadReset;
begin
  GYieldCount := 0;
end;

function TestThreadYieldCount: SizeUInt;
begin
  Result := GYieldCount;
end;

function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
begin
  FillChar(AHandle, SizeOf(AHandle), 0);
  Result := -1;
end;

function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
begin
  ARetVal := nil;
  Result := -1;
end;

function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
begin
  Result := -1;
end;

function platform_thread_self: TPlatformThreadToken;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function platform_thread_id: UInt64;
begin
  Result := 1;
end;

procedure platform_thread_yield;
begin
  Inc(GYieldCount);
  if GYieldCount > MAX_TEST_YIELDS then
    raise EInvalidOperationError.Create('uuidv7 monotonic clock wait did not make progress');
end;

procedure platform_thread_sleep_ns(const ANanoseconds: UInt64);
begin
end;

function platform_tls_create(out AKey: TPlatformTLSKey): Int32;
begin
  FillChar(AKey, SizeOf(AKey), 0);
  Result := -1;
end;

function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
begin
  Result := -1;
end;

function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
begin
  Result := -1;
end;

function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;
begin
  Result := nil;
end;

function platform_cpu_count: Int32;
begin
  Result := 1;
end;

end.
