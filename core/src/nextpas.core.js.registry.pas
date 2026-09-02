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
  // L0-L1 single source: vault 同步经 sync.mutex→platform.sync + sync.vault single source EnsureVaultLock (loop out-of-line per red-line 2), 原子经 atomic single source, 退避经 platform.thread (via vault helper)
  nextpas.core.sync.mutex,
  nextpas.core.sync.vault,
  nextpas.core.atomic,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  // bootstrap: registry 为 L2 唯一扇出点，5 后端工厂经 JsRegisterBackend 扩展优雅，factory 零直接 uses 传递经此单源（显式收敛，非掩盖）
  nextpas.core.js.fake,
  nextpas.core.js.js888,
  nextpas.core.js.v8,
  nextpas.core.js.chakra,
  nextpas.core.js.quickjs.loader,
  nextpas.core.js.quickjs;
const
  JS_REGISTRY_NEG_TTL_NS = QWord(2000000000); // 2s negative TTL: unavailable → TTL后重探，动态so可恢复
type
  // owner 边界隔离：单 vault 收敛工厂三数组与锁，模块化隔离裸全局；Lock 为托管 IMutex，非 64B 对齐，数组为变长托管类型，不宣称 64B 友好
  TJsRegistryVault = record
    Lock: IMutex;
    Factories: array[TJsBackendKind] of TJsRuntimeFactory;
    Avail: array[TJsBackendKind] of TJsAvailableFunc;
    Registered: array[TJsBackendKind] of Boolean;
    AvailCache: array[TJsBackendKind] of Int32; // 0=unknown 1=unavailable 2=available, 零初值 unknown
    AvailCacheAt: array[TJsBackendKind] of QWord; // monotonic ns at negative cache, 0=none, TTL过期重探
  end;
  PTJsRegistryVault = ^TJsRegistryVault;
var
  // vault single owner：非裸全局语义，经 VaultRef inline 单源访问，lazy 原子 Exactly-Once，IMutex 快照 O(1) 零锁外派发
  GVault: TJsRegistryVault;
  GVaultInit: Int32 = 0; // 0=uninit 1=initializing 2=ready, atomic cas single source via atomic
function VaultRef: PTJsRegistryVault; inline;
begin
  // perf: inline single indirection, zero-copy vault ref, single source for all vault access, no duplicate @GVault
  Result := @GVault;
end;
procedure EnsureVaultLock; inline;
begin
  // inline → vault single source
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
    // stability: cache invalidation exactly-once under lock, 可变闭包新值下轮锁内调用
    VaultRef^.AvailCache[AKind] := 0; // unknown → force reprobe, 复用 zero-init 语义
    VaultRef^.AvailCacheAt[AKind] := 0;
    atomic_thread_fence(mo_release);
  finally
    VaultRef^.Lock.Release;
  end;
end;
function JsRegistryIsRegistered(AKind: TJsBackendKind): Boolean;
var
  LRes: Boolean;
begin
  // perf: O(1) Ord(AKind) 零拷贝，init后无锁快照零竞争（单次 acquire load），未就绪才加锁；不 inline：含锁与分支，守 design-conventions §2 红线2
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
function JsRegistryAvailable(AKind: TJsBackendKind): Boolean;
var
  LReg: Boolean;
  LAvail: TJsAvailableFunc;
  LCached: Int32;
  LAvailRes: Boolean;
  LNow: QWord;
begin
  // perf: O(1) enum-index, 零拷贝 vault ref, 单次 lock 批探测缓存 B/op=0 热命中, bytes.ops 单源探针；不 inline：含锁/fence/分支，守 design-conventions §2 红线2
  // stability: 可变闭包 Avail 锁内调用, never 锁外派发, 负向 TTL 过期重探, try-finally 不丢, IMutex→platform.sync 原子保护
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    atomic_thread_fence(mo_acquire);
    LReg := VaultRef^.Registered[AKind];
    if not LReg then Exit(False);
    LCached := VaultRef^.AvailCache[AKind];
    if LCached = 2 then Exit(True);
    if LCached = 1 then
    begin
      LNow := QWord(platform_monotonic_ns);
      if (VaultRef^.AvailCacheAt[AKind] <> 0) and ((LNow - VaultRef^.AvailCacheAt[AKind]) < JS_REGISTRY_NEG_TTL_NS) then
        Exit(False);
      // TTL expired → fall through reprobe
    end;
    LAvail := VaultRef^.Avail[AKind];
    if not Assigned(LAvail) then
    begin
      VaultRef^.AvailCache[AKind] := 2;
      VaultRef^.AvailCacheAt[AKind] := 0;
      Exit(True);
    end;
    // 可变闭包锁内调用：快照后立即在同一临界区执行, 防止并发篡改与并发重复探测
    LAvailRes := LAvail();
    if LAvailRes then
    begin
      VaultRef^.AvailCache[AKind] := 2;
      VaultRef^.AvailCacheAt[AKind] := 0;
    end
    else
    begin
      VaultRef^.AvailCache[AKind] := 1;
      VaultRef^.AvailCacheAt[AKind] := QWord(platform_monotonic_ns);
    end;
    Result := LAvailRes;
  finally
    VaultRef^.Lock.Release;
  end;
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
  LCached: Int32;
  LAvailRes: Boolean;
begin
  // perf: O(1) enum-index dispatch via registry vault snapshot via VaultRef, no case-branch duplication, platform.sync 快照零拷贝 + BytesCopy 单源 inline, extension via JsRegisterBackend
  // stability: CheckJsRuntimeOptions by caller (factory) fail-closed before dispatch, no resource on throw; creation exactly-once, lock 批探测缓存+外部派发防死锁持有期最小, pure.base JsPureClose / quickjs StoreClear幂等不丢 via callee ctor/clear, try-finally 不丢
  // perf: 长期缓存 AvailCache B/op=0 热命中零拷贝, 负向 TTL 过期重探, 批量 Create 零重复探测, 可变闭包锁内单次探针
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    atomic_thread_fence(mo_acquire);
    LReg := VaultRef^.Registered[AKind];
    if not LReg then
      raise EJsError.Create('Unsupported backend', jecNotSupported, 'Error', '', AKind);
    LCached := VaultRef^.AvailCache[AKind];
    if LCached = 1 then
    begin
      if (VaultRef^.AvailCacheAt[AKind] = 0) or ((QWord(platform_monotonic_ns) - VaultRef^.AvailCacheAt[AKind]) >= JS_REGISTRY_NEG_TTL_NS) then
        LCached := 0 // TTL expired → reprobe
      else
      begin
        if AKind = jsbkQuickJs then
          raise EJsBackendUnavailable.Create('QuickJS not available (probe: ' + JsQuickJsProbeNames + ')', jecUnknown, 'Error', '', jsbkQuickJs)
        else
          raise EJsBackendUnavailable.Create('Backend not available', jecUnknown, 'Error', '', AKind);
      end;
    end;
    if LCached = 0 then
    begin
      LAvail := VaultRef^.Avail[AKind];
      if Assigned(LAvail) then
      begin
        // 可变闭包锁内调用, 负向 TTL 保护, 单次探针 Exactly-Once per kind
        LAvailRes := LAvail();
        if LAvailRes then
        begin
          VaultRef^.AvailCache[AKind] := 2;
          VaultRef^.AvailCacheAt[AKind] := 0;
        end
        else
        begin
          VaultRef^.AvailCache[AKind] := 1;
          VaultRef^.AvailCacheAt[AKind] := QWord(platform_monotonic_ns);
        end;
        if not LAvailRes then
        begin
          if AKind = jsbkQuickJs then
            raise EJsBackendUnavailable.Create('QuickJS not available (probe: ' + JsQuickJsProbeNames + ')', jecUnknown, 'Error', '', jsbkQuickJs)
          else
            raise EJsBackendUnavailable.Create('Backend not available', jecUnknown, 'Error', '', AKind);
        end;
      end
      else
      begin
        VaultRef^.AvailCache[AKind] := 2;
        VaultRef^.AvailCacheAt[AKind] := 0;
      end;
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
  // stability: IMutex refcount 释放不丢, platform_mutex_destroy 经 TMutex.Destroy 单源 via atomic release, 无泄漏, GVaultInit 复位
  VaultRef^.Lock := nil;
  atomic_store(GVaultInit, Int32(0), mo_release);
end.
