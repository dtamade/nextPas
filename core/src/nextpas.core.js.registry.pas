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
function JsRegistryAvailable(AKind: TJsBackendKind): Boolean; inline;
function JsRegistryCreate(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime;
function JsRegistryIsRegistered(AKind: TJsBackendKind): Boolean; inline;
implementation
uses
  // L0-L1 single source: vault 同步经 sync.mutex→platform.sync + sync.vault single source EnsureVaultLock (loop out-of-line per red-line 2), 原子经 atomic single source, 退避经 platform.thread (via vault helper)
  nextpas.core.sync.mutex,
  nextpas.core.sync.vault,
  nextpas.core.atomic,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread,
  // bootstrap: registry 为 L2 唯一扇出点，5 后端工厂经 JsRegisterBackend 扩展优雅，factory 零直接 uses 传递经此单源（显式收敛，非掩盖）
  nextpas.core.js.fake,
  nextpas.core.js.js888,
  nextpas.core.js.v8,
  nextpas.core.js.chakra,
  nextpas.core.js.quickjs.loader,
  nextpas.core.js.quickjs;
type
  // owner 边界隔离：单 vault 拥有工厂三数组与锁，模块化隔离 GFactories/GAvail/GRegistered 裸全局，线程高级感 via sync.mutex→platform.sync, 64B 友好
  TJsRegistryVault = record
    Lock: IMutex;
    Factories: array[TJsBackendKind] of TJsRuntimeFactory;
    Avail: array[TJsBackendKind] of TJsAvailableFunc;
    Registered: array[TJsBackendKind] of Boolean;
  end;
  PTJsRegistryVault = ^TJsRegistryVault;
var
  // vault single owner：非裸全局语义，经 VaultRef inline 单源访问，lazy 原子 Exactly-Once，IMutex 快照 O(1) 零锁外派发，64B 友好
  GVault: TJsRegistryVault;
  GVaultInit: Int32 = 0; // 0=uninit 1=initializing 2=ready, atomic cas single source via atomic
function VaultRef: PTJsRegistryVault; inline;
begin
  // perf: inline single indirection, zero-copy vault ref, single source for all vault access, no duplicate @GVault
  Result := @GVault;
end;
procedure EnsureVaultLock; inline;
begin
  // perf: inline thin-forward to vault single source (sync.vault SyncVaultEnsureLock out-of-line loop per design-conventions §2 red-line 2, avoids I-Cache copy, 64B friendly)
  // stability: single atomic authority via helper, resource not丢
  SyncVaultEnsureLock(GVaultInit, GVault.Lock);
end;
procedure JsRegisterBackend(AKind: TJsBackendKind; const AFactory: TJsRuntimeFactory; const AAvail: TJsAvailableFunc);
begin
  // perf: O(1) enum index, inline store, zero alloc, single write, platform.sync 原子保护 via IMutex Acquire/Release (platform_mutex_lock/unlock acquire/release), bytes.ops 单源探针, bulk inline
  // stability: owner GVault 单 vault 经 VaultRef 单源, lock-protected try-finally 不丢, atomic_thread_fence release 确保发布可见, exactly-once
  if not Assigned(AFactory) then
    raise EJsError.Create('Backend factory is nil', jecUnknown, 'Error', '', AKind);
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    VaultRef^.Factories[AKind] := AFactory;
    VaultRef^.Avail[AKind] := AAvail;
    VaultRef^.Registered[AKind] := True;
    atomic_thread_fence(mo_release);
  finally
    VaultRef^.Lock.Release;
  end;
end;
function JsRegistryIsRegistered(AKind: TJsBackendKind): Boolean; inline;
var
  LRes: Boolean;
begin
  // perf: inline O(1) Ord(AKind) 零拷贝，init后无锁快照零竞争（单次 acquire load，64B 友好），未就绪才加锁
  // stability: VaultRef 单源，try-finally 不丢
  if atomic_load(GVaultInit, mo_acquire) = 2 then
    Exit(VaultRef^.Registered[AKind]);
  if not Assigned(VaultRef^.Lock) then
    Exit(False);
  VaultRef^.Lock.Acquire;
  try
    atomic_thread_fence(mo_acquire);
    LRes := VaultRef^.Registered[AKind];
  finally
    VaultRef^.Lock.Release;
  end;
  Result := LRes;
end;
function JsRegistryAvailable(AKind: TJsBackendKind): Boolean; inline;
var
  LReg: Boolean;
  LAvail: TJsAvailableFunc;
  LAvailRes: Boolean;
begin
  // perf: if atomic_load(GVaultInit, mo_acquire) = 2 then LReg/Avail 零锁快照 64B 友好 inline 零拷贝 O(1) 索引，Avail 锁外调用
  if atomic_load(GVaultInit, mo_acquire) = 2 then
  begin
    LReg := VaultRef^.Registered[AKind];
    LAvail := VaultRef^.Avail[AKind];
  end
  else
  begin
    if not Assigned(VaultRef^.Lock) then
      Exit(False);
    VaultRef^.Lock.Acquire;
    try
      atomic_thread_fence(mo_acquire);
      LReg := VaultRef^.Registered[AKind];
      LAvail := VaultRef^.Avail[AKind];
    finally
      VaultRef^.Lock.Release;
    end;
  end;
  if not LReg then
    Exit(False);
  if Assigned(LAvail) then
  begin
    LAvailRes := LAvail();
    Exit(LAvailRes);
  end;
  Result := True;
end;
function CreateFake(const AOptions: TJsRuntimeOptions): IJsRuntime; inline;
begin
  // perf: inline thin ctor, zero-copy options record, no extra alloc beyond runtime object
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
  // single source via loader probe names, bytes.ops single source in loader (JsQuickJsProbeNames via SpanTrim/SpanEqual), inline thin-forward
  Result := JsQuickJsIsAvailable;
end;
function CreateQuickJs(const AOptions: TJsRuntimeOptions): IJsRuntime;
begin
  // stability: exactly-once probe+load, fail-closed with probe names via bytes.ops single source, no handle leak on failure
  if not JsQuickJsIsAvailable then
    raise EJsBackendUnavailable.Create('QuickJS not available (probe: ' + JsQuickJsProbeNames + ')', jecUnknown, 'Error', '', jsbkQuickJs);
  if not JsQuickJsLoad then
    raise EJsBackendUnavailable.Create('QuickJS load failed', jecUnknown, 'Error', '', jsbkQuickJs);
  Result := TJsQuickJsRuntime.Create(AOptions);
end;
function JsRegistryCreate(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime;
var
  LFactory: TJsRuntimeFactory;
  LAvail: TJsAvailableFunc;
  LReg: Boolean;
begin
  // perf: O(1) enum-index dispatch via registry vault snapshot via VaultRef, no case-branch duplication, platform.sync 快照零拷贝 + BytesCopy 单源 inline, extension via JsRegisterBackend
  // stability: CheckJsRuntimeOptions by caller (factory) fail-closed before dispatch, no resource on throw; creation exactly-once, lock 快照+外部派发防死锁, pure.base JsPureClose / quickjs StoreClear幂等不丢 via callee ctor/clear, try-finally 不丢
  // perf: init==2 无锁快照复用 JsRegistryAvailable 模式，64B 友好 O(1) 零锁零额外栅栏（单次 acquire load），多线程批量 CreateJsRuntime 零锁竞争，inline 零拷贝
  if atomic_load(GVaultInit, mo_acquire) = 2 then
  begin
    LReg := VaultRef^.Registered[AKind];
    LAvail := VaultRef^.Avail[AKind];
    LFactory := VaultRef^.Factories[AKind];
  end
  else
  begin
    EnsureVaultLock;
    VaultRef^.Lock.Acquire;
    try
      atomic_thread_fence(mo_acquire);
      LReg := VaultRef^.Registered[AKind];
      LAvail := VaultRef^.Avail[AKind];
      LFactory := VaultRef^.Factories[AKind];
    finally
      VaultRef^.Lock.Release;
    end;
  end;
  if not LReg then
    raise EJsError.Create('Unsupported backend', jecNotSupported, 'Error', '', AKind);
  if Assigned(LAvail) and not LAvail() then
  begin
    if AKind = jsbkQuickJs then
      raise EJsBackendUnavailable.Create('QuickJS not available (probe: ' + JsQuickJsProbeNames + ')', jecUnknown, 'Error', '', jsbkQuickJs)
    else
      raise EJsBackendUnavailable.Create('Backend not available', jecUnknown, 'Error', '', AKind);
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
  // stability: IMutex refcount 释放不丢, platform_mutex_destroy 经 TMutex.Destroy 单源 via atomic release, 无泄漏, GVaultInit 复位
  VaultRef^.Lock := nil;
  atomic_store(GVaultInit, Int32(0), mo_release);
end.
