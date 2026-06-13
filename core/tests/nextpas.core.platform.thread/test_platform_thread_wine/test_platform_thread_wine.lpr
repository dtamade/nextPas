program test_platform_thread_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.thread,
  nextpas.core.platform.sync;

var
  T: TTestRunner;

{$IFDEF NEXTPAS_WINDOWS}

{ --- shared context types for multithread tests --- }

type
  PThreadCreateJoinCtx = ^TThreadCreateJoinCtx;
  TThreadCreateJoinCtx = record
    ThreadArg: Int32;
    ThreadResult: Int32;
  end;

  PTLSRoundtripCtx = ^TTLSRoundtripCtx;
  TTLSRoundtripCtx = record
    Key: TPlatformTLSKey;
    SetValue: Pointer;
    GetValue: Pointer;
  end;

  PCondvarSignalCtx = ^TCondvarSignalCtx;
  TCondvarSignalCtx = record
    Mutex: TPlatformMutex;
    CondVar: TPlatformCondVar;
    Ready: Int32;
    Received: Int32;
  end;

  PCondvarBroadcastCtx = ^TCondvarBroadcastCtx;
  TCondvarBroadcastCtx = record
    Mutex: TPlatformMutex;
    CondVar: TPlatformCondVar;
    ReadyCount: Int32;
    ReceivedCount: Int32;
  end;

  PAddressWaitCtx = ^TAddressWaitCtx;
  TAddressWaitCtx = record
    Value: Int32;
    WokeUp: Int32;
  end;

  PAddressWaitAllCtx = ^TAddressWaitAllCtx;
  TAddressWaitAllCtx = record
    Value: Int32;
    WokeUpCount: Int32;
  end;

{ --- thread functions (cdecl per TPlatformThreadProc signature) --- }

function ThreadDetachFunc(AArg: Pointer): Pointer; cdecl;
begin
  platform_thread_sleep_ns(10000000); { 10ms }
  Result := Pointer(1);
end;

function ThreadCreateJoinFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PThreadCreateJoinCtx;
begin
  LCtx := PThreadCreateJoinCtx(AArg);
  LCtx^.ThreadResult := LCtx^.ThreadArg * 2;
  Result := Pointer(PtrInt(LCtx^.ThreadResult));
end;

function TLSRoundtripThread(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PTLSRoundtripCtx;
begin
  LCtx := PTLSRoundtripCtx(AArg);
  platform_tls_set(LCtx^.Key, LCtx^.SetValue);
  LCtx^.GetValue := platform_tls_get(LCtx^.Key);
  Result := Pointer(1);
end;

function CondvarWaiter(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PCondvarSignalCtx;
begin
  LCtx := PCondvarSignalCtx(AArg);
  platform_mutex_lock(LCtx^.Mutex);
  LCtx^.Ready := 1;
  platform_condvar_wait(LCtx^.CondVar, LCtx^.Mutex);
  LCtx^.Received := 1;
  platform_mutex_unlock(LCtx^.Mutex);
  Result := Pointer(1);
end;

function CondvarSignaler(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PCondvarSignalCtx;
begin
  LCtx := PCondvarSignalCtx(AArg);
  while LCtx^.Ready = 0 do
    platform_thread_yield;
  platform_mutex_lock(LCtx^.Mutex);
  platform_condvar_signal(LCtx^.CondVar);
  platform_mutex_unlock(LCtx^.Mutex);
  Result := Pointer(1);
end;

function CondvarBroadcastWaiter(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PCondvarBroadcastCtx;
begin
  LCtx := PCondvarBroadcastCtx(AArg);
  platform_mutex_lock(LCtx^.Mutex);
  Inc(LCtx^.ReadyCount);
  platform_condvar_wait(LCtx^.CondVar, LCtx^.Mutex);
  Inc(LCtx^.ReceivedCount);
  platform_mutex_unlock(LCtx^.Mutex);
  Result := Pointer(1);
end;

function CondvarBroadcastSignaler(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PCondvarBroadcastCtx;
begin
  LCtx := PCondvarBroadcastCtx(AArg);
  while LCtx^.ReadyCount < 2 do
    platform_thread_yield;
  platform_mutex_lock(LCtx^.Mutex);
  platform_condvar_broadcast(LCtx^.CondVar);
  platform_mutex_unlock(LCtx^.Mutex);
  Result := Pointer(1);
end;

function AddressWaitWaiter(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PAddressWaitCtx;
begin
  LCtx := PAddressWaitCtx(AArg);
  platform_wait_address32(@LCtx^.Value, 0, -1);
  LCtx^.WokeUp := 1;
  Result := Pointer(1);
end;

function AddressWaitWaker(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PAddressWaitCtx;
begin
  LCtx := PAddressWaitCtx(AArg);
  platform_thread_sleep_ns(10000000); { 10ms }
  LCtx^.Value := 1;
  platform_wake_address_one(@LCtx^.Value);
  Result := Pointer(1);
end;

function AddressWaitAllWaiter(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PAddressWaitAllCtx;
begin
  LCtx := PAddressWaitAllCtx(AArg);
  platform_wait_address32(@LCtx^.Value, 0, -1);
  InterlockedIncrement(LCtx^.WokeUpCount);
  Result := Pointer(1);
end;

function AddressWaitAllWaker(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PAddressWaitAllCtx;
begin
  LCtx := PAddressWaitAllCtx(AArg);
  platform_thread_sleep_ns(20000000); { 20ms }
  LCtx^.Value := 1;
  platform_wake_address_all(@LCtx^.Value);
  Result := Pointer(1);
end;

{ --- test procedures --- }

{ 1. platform_thread_create + platform_thread_join }
procedure TestThreadCreateJoin;
var
  LHandle: TPlatformThreadHandle;
  LRet: Int32;
  LRetVal: Pointer;
  LCtx: TThreadCreateJoinCtx;
begin
  FillChar(LCtx, SizeOf(LCtx), 0);
  LCtx.ThreadArg := 42;
  LRet := platform_thread_create(LHandle, @ThreadCreateJoinFunc, @LCtx);
  CheckEqual(Int64(0), Int64(LRet), 'platform_thread_create');
  LRet := platform_thread_join(LHandle, LRetVal);
  CheckEqual(Int64(0), Int64(LRet), 'platform_thread_join');
  CheckEqual(Int64(84), Int64(LCtx.ThreadResult), 'thread result (42*2)');
  CheckEqual(Int64(84), Int64(PtrInt(LRetVal)), 'thread join return value');
end;

{ 2. platform_thread_detach }
procedure TestThreadDetach;
var
  LHandle: TPlatformThreadHandle;
  LRet: Int32;
begin
  LRet := platform_thread_create(LHandle, @ThreadDetachFunc, nil);
  CheckEqual(Int64(0), Int64(LRet), 'platform_thread_create for detach');
  LRet := platform_thread_detach(LHandle);
  CheckEqual(Int64(0), Int64(LRet), 'platform_thread_detach');
  platform_thread_sleep_ns(20000000); { let detached thread finish }
end;

{ 3. platform_thread_self / platform_thread_id }
procedure TestThreadSelfAndId;
var
  LToken: TPlatformThreadToken;
  LTid: UInt64;
begin
  LToken := platform_thread_self;
  LTid := platform_thread_id;
  Check(LToken <> 0, 'platform_thread_self should be non-zero');
  Check(LTid <> 0, 'platform_thread_id should be non-zero');
end;

{ 4. platform_thread_yield }
procedure TestThreadYield;
begin
  platform_thread_yield;
  Check(True, 'platform_thread_yield did not crash');
end;

{ 5. platform_thread_sleep_ns }
procedure TestThreadSleepNs;
begin
  platform_thread_sleep_ns(1000000); { 1ms }
  Check(True, 'platform_thread_sleep_ns did not crash');
end;

{ 6. TLS roundtrip: set in thread, get in same thread, verify in main }
procedure TestTLSRoundtrip;
var
  LKey: TPlatformTLSKey;
  LRet: Int32;
  LCtx: TTLSRoundtripCtx;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
begin
  FillChar(LCtx, SizeOf(LCtx), 0);
  LRet := platform_tls_create(LKey);
  CheckEqual(Int64(0), Int64(LRet), 'platform_tls_create');

  LCtx.Key := LKey;
  LCtx.SetValue := Pointer(12345);

  LRet := platform_thread_create(LHandle, @TLSRoundtripThread, @LCtx);
  CheckEqual(Int64(0), Int64(LRet), 'create TLS thread');
  platform_thread_join(LHandle, LRetVal);

  CheckEqual(Int64(12345), Int64(PtrInt(LCtx.GetValue)), 'TLS roundtrip value');

  LRet := platform_tls_destroy(LKey);
  CheckEqual(Int64(0), Int64(LRet), 'platform_tls_destroy');
end;

{ 7. platform_cpu_count >= 1 }
procedure TestCpuCount;
var
  LCount: Int32;
begin
  LCount := platform_cpu_count;
  Check(LCount >= 1, 'platform_cpu_count should be at least 1');
end;

{ 8. condvar signal wakes one waiter }
procedure TestCondvarSignal;
var
  LCtx: TCondvarSignalCtx;
  LWaiter, LSignaler: TPlatformThreadHandle;
  LRet: Int32;
  LRetVal: Pointer;
begin
  FillChar(LCtx, SizeOf(LCtx), 0);
  CheckEqual(Int64(0), Int64(platform_mutex_init(LCtx.Mutex, PLATFORM_MUTEX_NORMAL)), 'mutex init');
  CheckEqual(Int64(0), Int64(platform_condvar_init(LCtx.CondVar)), 'condvar init');

  LRet := platform_thread_create(LWaiter, @CondvarWaiter, @LCtx);
  CheckEqual(Int64(0), Int64(LRet), 'create waiter');

  LRet := platform_thread_create(LSignaler, @CondvarSignaler, @LCtx);
  CheckEqual(Int64(0), Int64(LRet), 'create signaler');

  platform_thread_join(LWaiter, LRetVal);
  platform_thread_join(LSignaler, LRetVal);

  CheckEqual(Int64(1), Int64(LCtx.Received), 'waiter received signal');

  platform_condvar_destroy(LCtx.CondVar);
  platform_mutex_destroy(LCtx.Mutex);
end;

{ 9. condvar broadcast wakes 2 waiters }
procedure TestCondvarBroadcast;
var
  LCtx: TCondvarBroadcastCtx;
  LWaiter1, LWaiter2, LSignaler: TPlatformThreadHandle;
  LRet: Int32;
  LRetVal: Pointer;
begin
  FillChar(LCtx, SizeOf(LCtx), 0);
  CheckEqual(Int64(0), Int64(platform_mutex_init(LCtx.Mutex, PLATFORM_MUTEX_NORMAL)), 'mutex init');
  CheckEqual(Int64(0), Int64(platform_condvar_init(LCtx.CondVar)), 'condvar init');

  LRet := platform_thread_create(LWaiter1, @CondvarBroadcastWaiter, @LCtx);
  CheckEqual(Int64(0), Int64(LRet), 'create waiter1');
  LRet := platform_thread_create(LWaiter2, @CondvarBroadcastWaiter, @LCtx);
  CheckEqual(Int64(0), Int64(LRet), 'create waiter2');

  LRet := platform_thread_create(LSignaler, @CondvarBroadcastSignaler, @LCtx);
  CheckEqual(Int64(0), Int64(LRet), 'create signaler');

  platform_thread_join(LWaiter1, LRetVal);
  platform_thread_join(LWaiter2, LRetVal);
  platform_thread_join(LSignaler, LRetVal);

  CheckEqual(Int64(2), Int64(LCtx.ReceivedCount), 'both waiters received broadcast');

  platform_condvar_destroy(LCtx.CondVar);
  platform_mutex_destroy(LCtx.Mutex);
end;

{ 10. wait_address32 + wake_address_one
      SKIPPED under Wine: Wine 10.0 lacks kernel32.WaitOnAddress / WakeByAddressSingle
      See: unimplemented function kernel32.dll.WaitOnAddress }

{ 11. wait_address32 + wake_address_all
     SKIPPED under Wine: Wine 10.0 lacks kernel32.WaitOnAddress / WakeByAddressAll
     See: unimplemented function kernel32.dll.WakeByAddressAll }

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.thread.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Run('platform_thread_create + platform_thread_join', @TestThreadCreateJoin);
  T.Run('platform_thread_detach', @TestThreadDetach);
  T.Run('platform_thread_self / platform_thread_id', @TestThreadSelfAndId);
  T.Run('platform_thread_yield', @TestThreadYield);
  T.Run('platform_thread_sleep_ns', @TestThreadSleepNs);
  T.Run('platform_tls_create/set/get/destroy roundtrip', @TestTLSRoundtrip);
  T.Run('platform_cpu_count >= 1', @TestCpuCount);
  T.Run('condvar signal wakes one waiter', @TestCondvarSignal);
  T.Run('condvar broadcast wakes multiple waiters', @TestCondvarBroadcast);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.