unit nextpas.core.platform.thread;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformThreadHandle = Pointer;
  TPlatformThreadProc = function(AArg: Pointer): Pointer; cdecl;
  TPlatformTLSKey = PtrUInt;

{ Thread lifecycle }
function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
function platform_thread_self: TPlatformThreadHandle;
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

{$IFDEF UNIX}
uses
  BaseUnix, PThreads, UnixType;

function sysconf(AName: cint): clong; cdecl; external 'c';
function c_sched_yield: cint; cdecl; external 'c' name 'sched_yield';

const
  _SC_NPROCESSORS_ONLN = 84;

{ Thread lifecycle }

function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
var
  LThread: TThreadID;
begin
  Result := pthread_create(@LThread, nil, AProc, AArg);
  if Result = 0 then
    AHandle := Pointer(LThread)
  else
    AHandle := nil;
end;

function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
begin
  Result := pthread_join(TThreadID(AHandle), @ARetVal);
end;

function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
begin
  Result := pthread_detach(TThreadID(AHandle));
end;

function platform_thread_self: TPlatformThreadHandle;
begin
  Result := Pointer(pthread_self);
end;

function platform_thread_id: UInt64;
begin
  Result := UInt64(pthread_self);
end;

procedure platform_thread_yield;
begin
  c_sched_yield;
end;

procedure platform_thread_sleep_ns(const ANanoseconds: UInt64);
var
  LReq, LRem: TimeSpec;
begin
  LReq.tv_sec := ANanoseconds div 1000000000;
  LReq.tv_nsec := ANanoseconds mod 1000000000;
  while FpNanoSleep(@LReq, @LRem) <> 0 do
    LReq := LRem;
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
  LResult: clong;
begin
  LResult := sysconf(_SC_NPROCESSORS_ONLN);
  if LResult < 1 then
    Result := 1
  else
    Result := Int32(LResult);
end;

{$ENDIF}

{$IFDEF WINDOWS}
uses
  Windows;

function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32;
var
  LId: DWORD;
begin
  AHandle := Pointer(CreateThread(nil, 0, @AProc, AArg, 0, @LId));
  if AHandle <> nil then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32;
var
  LCode: DWORD;
begin
  if WaitForSingleObject(THandle(AHandle), INFINITE) = WAIT_OBJECT_0 then
  begin
    GetExitCodeThread(THandle(AHandle), @LCode);
    ARetVal := Pointer(PtrUInt(LCode));
    CloseHandle(THandle(AHandle));
    Result := 0;
  end
  else
    Result := Int32(GetLastError);
end;

function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32;
begin
  if CloseHandle(THandle(AHandle)) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_thread_self: TPlatformThreadHandle;
begin
  Result := Pointer(PtrUInt(GetCurrentThread));
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
  LMs := DWORD(ANanoseconds div 1000000);
  if (ANanoseconds mod 1000000 > 0) and (LMs < $FFFFFFFF) then
    Inc(LMs);
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
    Result := Int32(GetLastError);
  end;
end;

function platform_tls_destroy(const AKey: TPlatformTLSKey): Int32;
begin
  if TlsFree(DWORD(AKey)) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_tls_set(const AKey: TPlatformTLSKey; const AValue: Pointer): Int32;
begin
  if TlsSetValue(DWORD(AKey), AValue) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_tls_get(const AKey: TPlatformTLSKey): Pointer;
begin
  Result := TlsGetValue(DWORD(AKey));
end;

function platform_cpu_count: Int32;
var
  LInfo: TSystemInfo;
begin
  GetSystemInfo(@LInfo);
  Result := Int32(LInfo.dwNumberOfProcessors);
  if Result < 1 then
    Result := 1;
end;

{$ENDIF}

{$IFNDEF UNIX}{$IFNDEF WINDOWS}
function platform_thread_create(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer): Int32; begin AHandle := nil; Result := -1; end;
function platform_thread_join(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer): Int32; begin ARetVal := nil; Result := -1; end;
function platform_thread_detach(const AHandle: TPlatformThreadHandle): Int32; begin Result := -1; end;
function platform_thread_self: TPlatformThreadHandle; begin Result := nil; end;
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
