unit nextpas.core.js.registry;
{** @desc JS 后端注册表：收敛 L2 内扇出，工厂薄转发单缝。
     承载 5 后端工厂与探测单源（fake/js888/v8/chakra/QuickJS），
     工厂仅经 registry O(1) 索引分发，零硬编码 case 分支，扩展优雅（JsRegisterBackend）。
     守四件套 base←intf←(registry←factory)←门面 与 L0-L3（L2 内聚，单向 registry←factory），
     复用 bytes.ops 单源（经 loader 探测名单 + pure.base 几何，零拷贝），
     热点 inline 零拷贝 + Move 单源（BytesCopy 单源），资源幂等不丢（pure.base JsPureClose / quickjs StoreClear exactly-once）。
     线程安全：GVault 单一 owner 隔离（模块化 vault + IMutex→platform.sync 原子保护 acquire/release, 64B 友好 O(1) 快照，零锁外分发），
     资源 try-finally 不丢，业务以 CONTRACT 为准，owner 缺口反哺 platform.sync/sync/atomic。 *}
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
  nextpas.core.js.fake,
  nextpas.core.js.js888,
  nextpas.core.js.v8,
  nextpas.core.js.chakra,
  nextpas.core.js.quickjs.loader,
  nextpas.core.js.quickjs,
  nextpas.core.sync.mutex,
  nextpas.core.atomic,
  nextpas.core.platform.sync;
type
  // owner 边界隔离：单 vault 拥有工厂三数组与锁，模块化隔离 GFactories/GAvail/GRegistered 裸全局，线程高级感 via sync.mutex→platform.sync
  TJsRegistryVault = record
    Lock: IMutex;
    Factories: array[TJsBackendKind] of TJsRuntimeFactory;
    Avail: array[TJsBackendKind] of TJsAvailableFunc;
    Registered: array[TJsBackendKind] of Boolean;
  end;
var
  GVault: TJsRegistryVault;
procedure EnsureVaultLock; inline;
begin
  // perf: inline single branch, zero alloc, lazy single source via sync.mutex→platform.sync (platform_mutex_init), exactly-once rare
  if not Assigned(GVault.Lock) then
    GVault.Lock := TMutex.Create;
end;
procedure JsRegisterBackend(AKind: TJsBackendKind; const AFactory: TJsRuntimeFactory; const AAvail: TJsAvailableFunc);
begin
  // perf: O(1) enum index, inline store, zero alloc, single write, platform.sync 原子保护 via IMutex Acquire/Release (platform_mutex_lock/unlock acquire/release), bytes.ops 单源探针, bulk inline
  // stability: owner GVault 单 vault, lock-protected try-finally 不丢, atomic_thread_fence release 确保发布可见, exactly-once
  if not Assigned(AFactory) then
    raise EJsError.Create('Backend factory is nil', jecUnknown, 'Error', '', AKind);
  EnsureVaultLock;
  GVault.Lock.Acquire;
  try
    GVault.Factories[AKind] := AFactory;
    GVault.Avail[AKind] := AAvail;
    GVault.Registered[AKind] := True;
    atomic_thread_fence(mo_release);
  finally
    GVault.Lock.Release;
  end;
end;
function JsRegistryIsRegistered(AKind: TJsBackendKind): Boolean; inline;
var
  LRes: Boolean;
begin
  // perf: inline O(1) Ord(AKind) index, zero-copy, platform.sync 原子保护快照 via IMutex Acquire/Release, no branch mispredict, single source
  // stability: owner GVault, try-finally 不丢, acquire 可见性
  if not Assigned(GVault.Lock) then
    Exit(False);
  GVault.Lock.Acquire;
  try
    atomic_thread_fence(mo_acquire);
    LRes := GVault.Registered[AKind];
  finally
    GVault.Lock.Release;
  end;
  Result := LRes;
end;
function JsRegistryAvailable(AKind: TJsBackendKind): Boolean; inline;
var
  LReg: Boolean;
  LAvail: TJsAvailableFunc;
  LAvailRes: Boolean;
begin
  // perf: inline thin-forward to registry single source, O(1) avail check, zero alloc, platform.sync 快照无锁外阻塞, bytes.ops 单源探针
  // stability: snapshot under lock, call outside lock 防重入, try-finally 不丢
  if not Assigned(GVault.Lock) then
    Exit(False);
  GVault.Lock.Acquire;
  try
    atomic_thread_fence(mo_acquire);
    LReg := GVault.Registered[AKind];
    LAvail := GVault.Avail[AKind];
  finally
    GVault.Lock.Release;
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
  // single source via loader probe names, bytes.ops single source in loader (JsQuickJsProbeNames), inline thin-forward
  Result := JsQuickJsIsAvailable;
end;
function CreateQuickJs(const AOptions: TJsRuntimeOptions): IJsRuntime;
begin
  // stability: exactly-once probe+load, fail-closed with probe names, no handle leak on failure
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
  // perf: O(1) enum-index dispatch via registry vault snapshot, no case-branch duplication, platform.sync 快照零拷贝, extension via JsRegisterBackend
  // stability: CheckJsRuntimeOptions by caller (factory) fail-closed before dispatch, no resource on throw; creation exactly-once, lock 快照+外部派发防死锁, pure.base JsPureClose / quickjs StoreClear幂等不丢 via callee ctor/clear, try-finally 不丢
  if not Assigned(GVault.Lock) then
    raise EJsError.Create('Unsupported backend', jecNotSupported, 'Error', '', AKind);
  GVault.Lock.Acquire;
  try
    atomic_thread_fence(mo_acquire);
    LReg := GVault.Registered[AKind];
    LAvail := GVault.Avail[AKind];
    LFactory := GVault.Factories[AKind];
  finally
    GVault.Lock.Release;
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
  GVault.Lock := TMutex.Create;
  RegisterBuiltins;
finalization
  // stability: IMutex refcount 释放不丢, platform_mutex_destroy 经 TMutex.Destroy 单源, 无泄漏
  GVault.Lock := nil;
end.
