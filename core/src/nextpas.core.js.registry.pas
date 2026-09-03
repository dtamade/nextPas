unit nextpas.core.js.registry;
{** @desc L2: JS 后端注册表：L2 唯一扇出 owner，收敛 5 后端工厂与探测单源 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf;
type
  TJsRuntimeFactory = function(const AOptions: TJsRuntimeOptions): IJsRuntime;
  TJsAvailableFunc = function: Boolean;
procedure JsRegisterBackend(AKind: TJsBackendKind; const AFactory: TJsRuntimeFactory; const AAvail: TJsAvailableFunc = nil);
function JsRegistryAvailable(AKind: TJsBackendKind): Boolean;
function JsRegistryCreate(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime;
function JsRegistryIsRegistered(AKind: TJsBackendKind): Boolean;
implementation
uses
  nextpas.core.sync.intf, // IMutex owner (uses not transitive via sync.mutex)
  nextpas.core.sync.mutex,
  nextpas.core.sync.vault,
  nextpas.core.atomic,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.bytes.ops,
  nextpas.core.js.fake,
  nextpas.core.js.js888,
  nextpas.core.js.v8,
  nextpas.core.js.chakra,
  nextpas.core.js.quickjs.loader,
  nextpas.core.js.quickjs;
const
  JS_REGISTRY_NEG_TTL_NS = QWord(2000000000); // 2s negative TTL
type
  // single slot groups AvailCache+At into one record — vault minimizes multi-array sprawl, TTL helper inline single source
  TJsAvailSlot = record State: Int32; At: QWord; end; // 0=unknown 1=unavail 2=avail
  TJsRegistryVault = record
    Lock: IMutex;
    Factories: array[TJsBackendKind] of TJsRuntimeFactory;
    Avail: array[TJsBackendKind] of TJsAvailableFunc;
    Registered: array[TJsBackendKind] of Boolean;
    AvailSlot: array[TJsBackendKind] of TJsAvailSlot;
  end;
  PTJsRegistryVault = ^TJsRegistryVault;
var
  GVault: TJsRegistryVault;
  GVaultInit: Int32 = 0; // 0=uninit 1=init 2=ready, atomic single source
function VaultRef: PTJsRegistryVault; inline;
begin
  Result := @GVault;
end;
procedure EnsureVaultLock; inline;
begin
  SyncVaultEnsureLock(GVaultInit, GVault.Lock);
end;
// perf: inline TTL check single source, zero-copy, O(1), branchless hot
function IsNegativeTtlValid(const ASlot: TJsAvailSlot): Boolean; inline;
var LNow: QWord;
begin
  if (ASlot.State <> 1) or (ASlot.At = 0) then Exit(False);
  LNow := QWord(platform_monotonic_ns);
  Result := (LNow - ASlot.At) < JS_REGISTRY_NEG_TTL_NS;
end;
procedure AvailSlotSet(AKind: TJsBackendKind; AState: Int32; AAt: QWord); inline;
begin
  // inline single source for cache store, zero alloc, single write, release fence outside
  VaultRef^.AvailSlot[AKind].State := AState;
  VaultRef^.AvailSlot[AKind].At := AAt;
end;
procedure JsRegisterBackend(AKind: TJsBackendKind; const AFactory: TJsRuntimeFactory; const AAvail: TJsAvailableFunc);
begin
  if not Assigned(AFactory) then
    raise EJsError.Create('Backend factory is nil', jecUnknown, 'Error', '', AKind);
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    VaultRef^.Factories[AKind] := AFactory;
    VaultRef^.Avail[AKind] := AAvail;
    VaultRef^.Registered[AKind] := True;
    BytesZero(@VaultRef^.AvailSlot[AKind], SizeUInt(SizeOf(TJsAvailSlot))); // single source via bytes.ops, zero-copy, reuse FillChar
    atomic_thread_fence(mo_release);
  finally
    VaultRef^.Lock.Release;
  end;
end;
function JsRegistryIsRegistered(AKind: TJsBackendKind): Boolean;
var LRes: Boolean;
begin
  if atomic_load(GVaultInit, mo_acquire) = 2 then
    Exit(VaultRef^.Registered[AKind]);
  if not Assigned(VaultRef^.Lock) then Exit(False);
  VaultRef^.Lock.Acquire;
  try
    atomic_thread_fence(mo_acquire);
    LRes := VaultRef^.Registered[AKind];
  finally
    VaultRef^.Lock.Release;
  end;
  Result := LRes;
end;
function JsRegistryAvailable(AKind: TJsBackendKind): Boolean;
var LReg: Boolean; LAvail: TJsAvailableFunc; LCached: Int32; LRes: Boolean;
begin
  // perf: lock-free fast path for available hot hit (B/op=0, zero IMutex), batch Create zero contention, inline + acquire fence
  if atomic_load(GVaultInit, mo_acquire) = 2 then
  begin
    LCached := atomic_load(VaultRef^.AvailSlot[AKind].State, mo_acquire);
    if LCached = 2 then
    begin
      atomic_thread_fence(mo_acquire);
      if VaultRef^.Registered[AKind] then Exit(True);
    end;
  end;
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    atomic_thread_fence(mo_acquire);
    LReg := VaultRef^.Registered[AKind];
    if not LReg then Exit(False);
    LCached := VaultRef^.AvailSlot[AKind].State;
    if LCached = 2 then Exit(True);
    if (LCached = 1) and IsNegativeTtlValid(VaultRef^.AvailSlot[AKind]) then Exit(False);
    LAvail := VaultRef^.Avail[AKind];
    if not Assigned(LAvail) then
    begin
      AvailSlotSet(AKind, 2, 0);
      Exit(True);
    end;
    LRes := LAvail();
    if LRes then AvailSlotSet(AKind, 2, 0) else AvailSlotSet(AKind, 1, QWord(platform_monotonic_ns));
    Result := LRes;
  finally
    VaultRef^.Lock.Release;
  end;
end;
function CreateFake(const AOptions: TJsRuntimeOptions): IJsRuntime; inline;
begin
  Result := TJsFakeRuntime.Create(jsbkFake, AOptions);
end;
function CreateJs888(const AOptions: TJsRuntimeOptions): IJsRuntime; inline;
begin
  Result := TJsJs888Runtime.Create(AOptions);
end;
function CreateV8(const AOptions: TJsRuntimeOptions): IJsRuntime; inline;
begin
  Result := TJsV8Runtime.Create(AOptions);
end;
function CreateChakra(const AOptions: TJsRuntimeOptions): IJsRuntime; inline;
begin
  Result := TJsChakraRuntime.Create(AOptions);
end;
function QuickJsAvailable: Boolean; inline;
begin
  Result := JsQuickJsIsAvailable;
end;
function CreateQuickJs(const AOptions: TJsRuntimeOptions): IJsRuntime;
begin
  if not JsQuickJsIsAvailable then
    raise EJsBackendUnavailable.Create('QuickJS not available (probe: ' + JsQuickJsProbeNames + ')', jecUnknown, 'Error', '', jsbkQuickJs);
  if not JsQuickJsLoad then
    raise EJsBackendUnavailable.Create('QuickJS load failed', jecUnknown, 'Error', '', jsbkQuickJs);
  Result := TJsQuickJsRuntime.Create(AOptions);
end;
function JsRegistryCreate(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime;
var LFactory: TJsRuntimeFactory; LAvail: TJsAvailableFunc; LReg: Boolean; LCached: Int32; LRes: Boolean;
begin
  // perf: lock-free fast path for available cache=2 — zero IMutex, B/op=0, batch CreateJsRuntime zero lock amplification
  if atomic_load(GVaultInit, mo_acquire) = 2 then
  begin
    LCached := atomic_load(VaultRef^.AvailSlot[AKind].State, mo_acquire);
    if LCached = 2 then
    begin
      atomic_thread_fence(mo_acquire);
      if VaultRef^.Registered[AKind] then
      begin
        LFactory := VaultRef^.Factories[AKind];
        if Assigned(LFactory) then
        begin
          Result := LFactory(AOptions);
          Exit;
        end;
      end;
    end;
  end;
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    atomic_thread_fence(mo_acquire);
    LReg := VaultRef^.Registered[AKind];
    if not LReg then raise EJsError.Create('Unsupported backend', jecNotSupported, 'Error', '', AKind);
    LCached := VaultRef^.AvailSlot[AKind].State;
    if LCached = 1 then
    begin
      if IsNegativeTtlValid(VaultRef^.AvailSlot[AKind]) then
      begin
        if AKind = jsbkQuickJs then raise EJsBackendUnavailable.Create('QuickJS not available (probe: ' + JsQuickJsProbeNames + ')', jecUnknown, 'Error', '', jsbkQuickJs)
        else raise EJsBackendUnavailable.Create('Backend not available', jecUnknown, 'Error', '', AKind);
      end else LCached := 0;
    end;
    if LCached = 0 then
    begin
      LAvail := VaultRef^.Avail[AKind];
      if Assigned(LAvail) then
      begin
        LRes := LAvail();
        if LRes then AvailSlotSet(AKind, 2, 0) else AvailSlotSet(AKind, 1, QWord(platform_monotonic_ns));
        if not LRes then
        begin
          if AKind = jsbkQuickJs then raise EJsBackendUnavailable.Create('QuickJS not available (probe: ' + JsQuickJsProbeNames + ')', jecUnknown, 'Error', '', jsbkQuickJs)
          else raise EJsBackendUnavailable.Create('Backend not available', jecUnknown, 'Error', '', AKind);
        end;
      end else AvailSlotSet(AKind, 2, 0);
    end;
    LFactory := VaultRef^.Factories[AKind];
  finally
    VaultRef^.Lock.Release;
  end;
  Result := LFactory(AOptions);
end;
procedure RegisterBuiltins;
begin
  EnsureVaultLock;
  JsRegisterBackend(jsbkFake, @CreateFake, nil);
  JsRegisterBackend(jsbkJs888, @CreateJs888, nil);
  JsRegisterBackend(jsbkV8, @CreateV8, nil);
  JsRegisterBackend(jsbkChakra, @CreateChakra, nil);
  JsRegisterBackend(jsbkQuickJs, @CreateQuickJs, @QuickJsAvailable);
end;
initialization
  EnsureVaultLock;
  RegisterBuiltins;
finalization
  // stability: publish not-ready before releasing mutex to close lock-free window; drain holder via TryAcquire to avoid AV on concurrent Create
  if atomic_load(GVaultInit, mo_acquire) = 2 then
  begin
    atomic_store(GVaultInit, Int32(0), mo_release);
    atomic_thread_fence(mo_seq_cst);
    if Assigned(GVault.Lock) then
    begin
      if GVault.Lock.TryAcquire then
      try
        GVault.Lock.Release;
        GVault.Lock := nil;
      except
        GVault.Lock := nil;
      end
      else
        GVault.Lock := nil; // leak-safe: holder still active, OS reclaims at exit
    end;
  end else
  begin
    atomic_store(GVaultInit, Int32(0), mo_release);
    GVault.Lock := nil;
  end;
end.
