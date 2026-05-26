program platform_thread_lifecycle;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.thread;

var
  GThreadValue: PtrUInt = 0;
  GTlsValue: Pointer = nil;

function WorkerThread(AArg: Pointer): Pointer; cdecl;
begin
  GThreadValue := PtrUInt(AArg) + 1;
  Result := Pointer(PtrUInt($1234));
end;

function TlsThread(AArg: Pointer): Pointer; cdecl;
var
  LKey: TPlatformTLSKey;
begin
  LKey := TPlatformTLSKey(PtrUInt(AArg));
  if platform_tls_set(LKey, Pointer(PtrUInt($BEEF))) <> 0 then
    Halt(1);
  GTlsValue := platform_tls_get(LKey);
  Result := nil;
end;

procedure RequireOk(const AName: string; const ACode: Int32);
begin
  if ACode <> 0 then
  begin
    WriteLn(AName, '-status=error');
    WriteLn(AName, '-code=', ACode);
    Halt(1);
  end;
end;

procedure RequireTrue(const AName: string; const AValue: Boolean);
begin
  if not AValue then
  begin
    WriteLn(AName, '-status=failed');
    Halt(1);
  end;
end;

var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LKey: TPlatformTLSKey;
  LSelf: TPlatformThreadToken;
  LCpuCount: Int32;

begin
  WriteLn('platform-thread-lifecycle=ready');

  GThreadValue := 0;
  RequireOk('platform-thread-create', platform_thread_create(LHandle, @WorkerThread, Pointer(PtrUInt(41))));
  RequireTrue('platform-thread-handle', LHandle <> nil);
  RequireOk('platform-thread-join', platform_thread_join(LHandle, LRetVal));
  RequireTrue('platform-thread-return', LRetVal = Pointer(PtrUInt($1234)));
  RequireTrue('platform-thread-worker', GThreadValue = 42);

  RequireOk('platform-thread-tls-create', platform_tls_create(LKey));
  RequireOk('platform-thread-tls-set-main', platform_tls_set(LKey, Pointer(PtrUInt($DEAD))));
  RequireTrue('platform-thread-tls-main', platform_tls_get(LKey) = Pointer(PtrUInt($DEAD)));
  RequireOk('platform-thread-tls-create-thread', platform_thread_create(LHandle, @TlsThread, Pointer(PtrUInt(LKey))));
  RequireOk('platform-thread-tls-join-thread', platform_thread_join(LHandle, LRetVal));
  RequireTrue('platform-thread-tls-child', GTlsValue = Pointer(PtrUInt($BEEF)));
  RequireTrue('platform-thread-tls-isolated', platform_tls_get(LKey) = Pointer(PtrUInt($DEAD)));
  RequireOk('platform-thread-tls-destroy', platform_tls_destroy(LKey));

  LCpuCount := platform_cpu_count;
  LSelf := platform_thread_self;
  RequireTrue('platform-thread-cpu-count', LCpuCount >= 1);
  RequireTrue('platform-thread-id', platform_thread_id <> 0);
  RequireTrue('platform-thread-self', LSelf <> 0);
  platform_thread_yield;
  platform_thread_sleep_ns(1);

  WriteLn('platform-thread-self=', LSelf);
  WriteLn('platform-thread-id=', platform_thread_id);
  WriteLn('platform-thread-cpu-count=', LCpuCount);
  WriteLn('platform-thread-lifecycle-status=pass');
end.
