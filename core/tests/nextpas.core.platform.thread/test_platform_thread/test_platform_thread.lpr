program test_platform_thread;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.testing,
  {$IFDEF NEXTPAS_LINUX}nextpas.core.platform.linux.ffi,{$ENDIF}
  nextpas.core.platform.thread;

var
  T: TTestRunner;

var
  GThreadResult: PtrUInt = 0;
  GDetachedThreadResult: PtrUInt = 0;

function SimpleThread(AArg: Pointer): Pointer; cdecl;
begin
  GThreadResult := PtrUInt(AArg) * 2;
  Result := Pointer(PtrUInt(42));
end;

procedure TestThreadCreateJoin;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LRet: Int32;
begin
  GThreadResult := 0;
  LRet := platform_thread_create(LHandle, @SimpleThread, Pointer(PtrUInt(21)));
  CheckEqual(Int64(0), Int64(LRet), 'create');
  Check(LHandle <> nil, 'handle not nil');

  LRet := platform_thread_join(LHandle, LRetVal);
  CheckEqual(Int64(0), Int64(LRet), 'join');
  CheckEqual(Int64(42), Int64(PtrUInt(LRetVal)), 'return value');
  CheckEqual(Int64(42), Int64(GThreadResult), 'thread executed');
end;

function DetachedThread(AArg: Pointer): Pointer; cdecl;
begin
  platform_thread_sleep_ns(1000000);
  GDetachedThreadResult := PtrUInt(AArg);
  Result := nil;
end;

procedure TestThreadDetach;
var
  LHandle: TPlatformThreadHandle;
  LRet: Int32;
  LWait: Integer;
begin
  GDetachedThreadResult := 0;

  LRet := platform_thread_create(LHandle, @DetachedThread, Pointer(PtrUInt(77)));
  CheckEqual(Int64(0), Int64(LRet), 'create detached candidate');
  Check(LHandle <> nil, 'detach handle not nil');

  LRet := platform_thread_detach(LHandle);
  CheckEqual(Int64(0), Int64(LRet), 'detach');

  for LWait := 1 to 100 do
  begin
    if GDetachedThreadResult = 77 then
      Break;
    platform_thread_sleep_ns(1000000);
  end;

  CheckEqual(Int64(77), Int64(GDetachedThreadResult), 'detached thread executed');
end;

var
  GTlsTestValue: Pointer = nil;

function TlsThread(AArg: Pointer): Pointer; cdecl;
var
  LKey: TPlatformTLSKey;
  LVal: Pointer;
begin
  LKey := TPlatformTLSKey(PtrUInt(AArg));
  platform_tls_set(LKey, Pointer(PtrUInt($BEEF)));
  LVal := platform_tls_get(LKey);
  GTlsTestValue := LVal;
  Result := nil;
end;

procedure TestTlsSetGet;
var
  LKey: TPlatformTLSKey;
  LRet: Int32;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
begin
  LRet := platform_tls_create(LKey);
  CheckEqual(Int64(0), Int64(LRet), 'tls create');

  LRet := platform_tls_set(LKey, Pointer(PtrUInt($DEAD)));
  CheckEqual(Int64(0), Int64(LRet), 'tls set');
  Check(platform_tls_get(LKey) = Pointer(PtrUInt($DEAD)), 'tls get main');

  GTlsTestValue := nil;
  platform_thread_create(LHandle, @TlsThread, Pointer(PtrUInt(LKey)));
  platform_thread_join(LHandle, LRetVal);
  Check(GTlsTestValue = Pointer(PtrUInt($BEEF)), 'tls get child');

  Check(platform_tls_get(LKey) = Pointer(PtrUInt($DEAD)), 'tls main unchanged');

  platform_tls_destroy(LKey);
end;

procedure TestThreadId;
var
  LId: UInt64;
begin
  LId := platform_thread_id;
  Check(LId <> 0, 'thread_id must be non-zero');
  CheckEqual(LId, platform_thread_id, 'thread_id must be stable');
  {$IFDEF NEXTPAS_LINUX}
  CheckEqual(UInt64(UInt32(gettid)), LId, 'thread_id matches Linux native tid');
  {$ENDIF}
end;

procedure TestThreadSelfToken;
var
  LSelf: TPlatformThreadToken;
begin
  LSelf := platform_thread_self;
  Check(LSelf <> 0, 'thread self token must be non-zero');
  CheckEqual(UInt64(LSelf), UInt64(platform_thread_self), 'self token is stable for current thread');
end;

procedure TestCpuCount;
var
  LCount: Int32;
begin
  LCount := platform_cpu_count;
  Check(LCount >= 1, 'cpu_count >= 1');
end;

procedure TestThreadYield;
begin
  platform_thread_yield;
  Check(True, 'yield did not crash');
end;

procedure TestThreadSleep;
begin
  platform_thread_sleep_ns(1000000);
  Check(True, 'sleep did not crash');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.thread');
  T.Run('Thread create and join', @TestThreadCreateJoin);
  T.Run('Thread detach', @TestThreadDetach);
  T.Run('TLS set/get', @TestTlsSetGet);
  T.Run('Thread self token', @TestThreadSelfToken);
  T.Run('Thread ID non-zero', @TestThreadId);
  T.Run('CPU count >= 1', @TestCpuCount);
  T.Run('Thread yield', @TestThreadYield);
  T.Run('Thread sleep', @TestThreadSleep);
  T.Summary;
end.
