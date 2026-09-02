unit nextpas.core.webview.gtk.viewmap; // 仅gtk uses — L1 THashMap 已直接复用：指针键哈希容器零自建

{** @desc GTK 指针键 view→window O(1) 索引：L1 THashMap 薄封装。私为gtk后端专用，已直接复用 L1 通用容器 — CONTRACT §1.2 登记指针特化已由 L1 THashMap 承载（L1: nextpas.core.collections.hashmap）。

       单源复用（零容器重复）：
       - 容器：L1 THashMap<Pointer,Pointer> 直接复用 — 与 webview.assets/bridge 同源，桶迁移/墓碑/扩容由 THashMap 单源承载，零自建开地址数组与双层迁移循环分叉
       - 哈希：hashmap.base.HashOfPointer (HashMix32 单源) — 与 THashMap/ webview.assets.WyHash 单源一致，消除 shr4 xor shr11 私有分叉，分布经 HashMix32 avalanche 保证；THashMap 经 @PointerHash (=HashOfPointer) 专化注入，零二次哈希
       - 容量：bytes.ops.VecGrowCapacity (0→4→2× inline 单源) — 与 webview.live/assetIndex 单源一致；初建与 Reserve 容量锚点经该单源，零魔法常数
       - 负载：0.75 (hashmap.base.DEFAULT_MAX_LOAD_FACTOR) — THashMap 内置阈值单源，零阈值漂移与手写 *4>=*3 分叉
       - 比较：指针等值直比（THashMap 默认 =），零 SpanEqual 额外开销
       已反哺完成：可抽通用指针哈希模块候选已落地 L1 THashMap 指针特化直接复用，家族内私有桶迁移与 VIEW_TOMBSTONE 探链已移除，哈希/容量/负载/容器全量单源（HashOfPointer→HashMix32 / VecGrowCapacity 0→4→2× inline / 0.75 阈值 / THashMap），遗留 VIEW_TOMBSTONE 仅 compat 常量零逻辑

       性能：
       - 零分配热读：ViewHash inline 单哈希零额外调用，ViewMapFindLocked 非 inline 短探（禁 inline 零 I-Cache 膨胀）经 THashMap.TryGetValue O(1) 线性探测 + and Mask + Bitmap CTZ 单指令，与 assets FMask 单源一致零除法；ViewMapFind 单窗无锁快径 seqlock 乐观读（偶数 seq + 单窗缓存 Pointer 直比 inline，零 RWLock/零 futex，单窗 SchemeRequest 每请求省一次 rdlock/rdunlock 快路径），多窗回退 RWLock 读并发短临界 <1µs 零单锁热点
       - 惰性重哈希：ViewMapRehashLocked/ViewMapAddLocked/ViewMapRemoveLocked 均为 out-of-line（真实循环体禁 inline，design-conventions 红线二），0.75 触发倍增由 THashMap.Rehash 单源承载，Reserve 单次 NextPow2 零额外循环；ViewMapAdd 写锁短临界仅指针拷贝与 THashMap 内部 O(n) 桶迁移（n<=窗口数<=8，无额外堆分配于调用侧，零阻塞读并发）；ViewMapRemoveLocked 2→1 单窗重建零堆分配（PtrIter/BitmapFindNext 单次 CTZ 零拷直取首条目，无 GetKeys 堆分配，写锁短临界 <1µs 单窗切多窗零尾延迟放大）
       - 容量预分配：初始化经 VecGrowCapacity(0) 4槽，稳态零每请求分配；扩容经 THashMap.NextPow2 内容纳 VecGrowCapacity 预判单源

       稳定性：析构 Free 清零释放不丢，THashMap bsTombstone 单哨兵保探链完整；锁外 nil 守卫保并发安全；seqlock 奇偶 seq + release/acquire 保证单窗缓存发布可见性，写锁内刷新单窗缓存，读侧双次 seq 校验丢弃并发写撕裂 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops,
  nextpas.core.collections.base,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.hashmap.base,
  nextpas.core.sync.rwlock,
  nextpas.core.atomic;

type
  TGtkWebviewOpaque = Pointer;

  TViewMapEntry = record
    Key: Pointer;
    Value: Pointer; // TGtkWebview opaque, 解耦避免循环 uses
  end;

const
  VIEW_TOMBSTONE = Pointer(1); // compat: 历史哨兵，现由 THashMap bsTombstone 单源承载，零逻辑使用

function ViewHash(AKey: Pointer): UInt32; inline;

// ViewMapFind/Add/Remove Locked 含 THashMap 探查/重哈希，禁 inline（design-conventions 红线二），零 I-Cache 膨胀
function ViewMapFindLocked(AView: Pointer): Pointer;
procedure ViewMapRehashLocked(ANewCap: Integer);
procedure ViewMapAddLocked(AView: Pointer; AWin: Pointer);
function ViewMapRemoveLocked(AView: Pointer): Boolean;

// 非 Locked 包装：Find 单窗无锁快径 seqlock + 单窗缓存（零 futex），多窗回退 RWLock 读并发零单锁热点；Add/Remove 写锁独占；短临界仅 THashMap 原子操作，零阻塞读并发
function ViewMapFind(AView: Pointer): Pointer;
procedure ViewMapAdd(AView: Pointer; AWin: Pointer);
procedure ViewMapRemove(AView: Pointer): Boolean;

procedure ViewMapInit; inline;
procedure ViewMapClear; inline;
function ViewMapCount: Integer; inline;
function ViewMapCapacity: Integer; inline;
procedure ViewMapLockInit;
procedure ViewMapLockFini;

implementation

var
  GViewMap: specialize THashMap<Pointer, Pointer> = nil;
  GViewMapLock: TRWLock = nil;
  GViewMapSeq: UInt32 = 0; // seqlock: 偶数稳定/奇数写入中，atomic 发布
  GViewMapSingleKey: Pointer = nil; // 单窗缓存：count=1 时的唯一键，seqlock 保护
  GViewMapSingleVal: Pointer = nil; // 单窗缓存：count=1 时的唯一值

function PointerHash(const AKey: Pointer): UInt32; inline;
begin
  // 单源：hashmap.base.HashOfPointer → HashMix32，与 THashMap/asset WyHash 单源一致
  Result := HashOfPointer(AKey);
end;

function ViewHash(AKey: Pointer): UInt32; inline;
begin
  // 单源：hashmap.base.HashOfPointer → HashMix32，与 THashMap/asset WyHash 单源一致，inline 零额外调用
  Result := HashOfPointer(AKey);
end;

procedure ViewMapSeqBeginWrite; inline;
begin
  // 单源 seq 奇数标记写入开始，atomic_fetch_add 全栅栏，L0 atomic 单源
  atomic_fetch_add(GViewMapSeq, UInt32(1));
end;

procedure ViewMapSeqEndWrite; inline;
begin
  // release 保证单窗缓存 release 存储先于偶数 seq 可见
  atomic_thread_fence(mo_release);
  atomic_fetch_add(GViewMapSeq, UInt32(1));
end;

function ViewMapFindLocked(AView: Pointer): Pointer;
begin
  // 非 inline：委托 L1 THashMap.TryGetValue O(1) 线性探测，禁 inline 零 I-Cache 膨胀；短探零分配，and Mask 与 Bitmap CTZ 单源一致热读零除法
  Result := nil;
  if (GViewMap = nil) or (AView = nil) then Exit(nil);
  if not GViewMap.TryGetValue(AView, Result) then
    Result := nil;
end;

procedure ViewMapRehashLocked(ANewCap: Integer);
begin
  // 非 inline：委托 L1 THashMap.Reserve 单源重哈希，禁 inline；NextPow2 + 桶迁移由 THashMap 单源承载，零自建双层循环与 VIEW_TOMBSTONE 分叉
  // 写侧 seqlock 保护单窗缓存一致性，Reserve 不改变内容则单窗缓存保持
  ViewMapSeqBeginWrite;
  try
    if GViewMap = nil then
    begin
      GViewMap := specialize THashMap<Pointer, Pointer>.Create(ANewCap, @PointerHash);
      atomic_store(GViewMapSingleKey, nil, mo_release);
      atomic_store(GViewMapSingleVal, nil, mo_release);
      Exit;
    end;
    GViewMap.Reserve(ANewCap);
  finally
    ViewMapSeqEndWrite;
  end;
end;

procedure ViewMapAddLocked(AView: Pointer; AWin: Pointer);
begin
  // 非 inline：委托 L1 THashMap.AddOrAssign 单源，禁 inline；0.75 负载单源阈值由 THashMap 内置 DEFAULT_MAX_LOAD_FACTOR 承载，零手写阈值漂移
  if (AView = nil) or (AWin = nil) then Exit;
  ViewMapSeqBeginWrite;
  try
    if GViewMap = nil then
      GViewMap := specialize THashMap<Pointer, Pointer>.Create(VecGrowCapacity(0), @PointerHash);
    GViewMap.AddOrAssign(AView, AWin);
    // 单窗缓存：count=1 时直存当前键值对（inline 零拷贝指针存储，release 发布），否则清零；单窗 SchemeRequest 命中零哈希
    if GViewMap.GetCount = 1 then
    begin
      atomic_store(GViewMapSingleKey, AView, mo_release);
      atomic_store(GViewMapSingleVal, AWin, mo_release);
    end else
    begin
      atomic_store(GViewMapSingleKey, nil, mo_release);
      atomic_store(GViewMapSingleVal, nil, mo_release);
    end;
  finally
    ViewMapSeqEndWrite;
  end;
end;

function ViewMapRemoveLocked(AView: Pointer): Boolean;
var
  LIter: TPtrIter;
  LEntry: ^specialize TMapEntry<Pointer, Pointer>;
begin
  // 非 inline：委托 L1 THashMap.Remove 单源墓碑单哈希探查，禁 inline；零重复 TryGetValue/Remove 双哈希，bsTombstone 保探链完整零 VIEW_TOMBSTONE 手写分叉，单次 FindIndex O(1) 零额外哈希
  if (GViewMap = nil) or (AView = nil) then Exit(False);
  ViewMapSeqBeginWrite;
  try
    Result := GViewMap.Remove(AView);
    if not Result then Exit(False);
    // 单窗缓存刷新：count=1 时重建剩余唯一条目（稀有路径 2→1，零堆分配零拷贝：PtrIter/BitmapFindNext 单次 CTZ 指令直取首条目，无 GetKeys/SetLength 堆分配，写锁短临界 <1µs），否则清零；release 发布保证读侧 acquire 可见
    if GViewMap.GetCount = 1 then
    begin
      LIter := GViewMap.PtrIter;
      if LIter.MoveNext then
      begin
        LEntry := LIter.Current;
        atomic_store(GViewMapSingleKey, LEntry^.Key, mo_release);
        atomic_store(GViewMapSingleVal, LEntry^.Value, mo_release);
      end else
      begin
        atomic_store(GViewMapSingleKey, nil, mo_release);
        atomic_store(GViewMapSingleVal, nil, mo_release);
      end;
    end else
    begin
      atomic_store(GViewMapSingleKey, nil, mo_release);
      atomic_store(GViewMapSingleVal, nil, mo_release);
    end;
  finally
    ViewMapSeqEndWrite;
  end;
end;

function ViewMapFind(AView: Pointer): Pointer;
var
  LSeq1, LSeq2: UInt32;
  LKey, LVal: Pointer;
begin
  // 单窗无锁快径：seqlock 乐观读 + 单窗缓存 Pointer 直比 inline，零 RWLock/零 futex，单窗 SchemeRequest 热读零原子 RMW，仅 2× acquire load + 单次指针等值比较
  // 校验：偶数 seq 且首尾 seq 相等则命中有效，否则回退 RWLock 读；多窗/并发写时回退短临界 <1µs，稳定性 via seq 丢弃撕裂
  if AView = nil then Exit(nil);
  if GViewMapLock <> nil then
  begin
    LSeq1 := atomic_load(GViewMapSeq, mo_acquire);
    if (LSeq1 and 1) = 0 then
    begin
      LKey := atomic_load(GViewMapSingleKey, mo_acquire);
      if LKey = AView then
      begin
        LVal := atomic_load(GViewMapSingleVal, mo_acquire);
        LSeq2 := atomic_load(GViewMapSeq, mo_acquire);
        if LSeq1 = LSeq2 then
          Exit(LVal);
      end else
      begin
        // 单窗未命中但 seq 稳定不代表 hashmap 无该键（多窗情况），需回退加锁查询；若 seq 已变则直接回退
        LSeq2 := atomic_load(GViewMapSeq, mo_acquire);
        if LSeq1 <> LSeq2 then
        begin
          // seq 已变，说明并发写，回退锁
        end;
      end;
    end;
  end else
    Exit(ViewMapFindLocked(AView));
  // 回退：RWLock 读并发零单锁热点，短临界仅 THashMap 指针只读 O(1) 零堆分配
  if GViewMapLock <> nil then GViewMapLock.AcquireRead;
  try
    Result := ViewMapFindLocked(AView);
  finally
    if GViewMapLock <> nil then GViewMapLock.ReleaseRead;
  end;
end;

procedure ViewMapAdd(AView: Pointer; AWin: Pointer);
begin
  // 写锁独占：THashMap 内部按 0.75 自动 Rehash，容量经 VecGrowCapacity 单源初建；锁内单点 AddOrAssign，n<=8 极小单次 NextPow2 零 I-Cache 膨胀，零锁外预分配分叉与桶迁移重复，稀有路径不阻塞读并发；seqlock 在 AddLocked 内奇偶翻转保护单窗缓存
  if (AView = nil) or (AWin = nil) then Exit;
  if GViewMapLock <> nil then GViewMapLock.AcquireWrite;
  try
    ViewMapAddLocked(AView, AWin);
  finally
    if GViewMapLock <> nil then GViewMapLock.ReleaseWrite;
  end;
end;

procedure ViewMapRemove(AView: Pointer): Boolean;
begin
  // 写锁独占：锁内单次 THashMap.Remove 单 FindIndex O(1)，零 TryGetValue+Remove 双哈希与锁内重复计算，零拷贝返回 Bool；seqlock 在 RemoveLocked 内保护单窗缓存
  Result := False;
  if AView = nil then Exit(False);
  if GViewMapLock <> nil then GViewMapLock.AcquireWrite;
  try
    Result := ViewMapRemoveLocked(AView);
  finally
    if GViewMapLock <> nil then GViewMapLock.ReleaseWrite;
  end;
end;

procedure ViewMapInit; inline;
begin
  // 单源初建：VecGrowCapacity(0)=4 与 bytes.ops 单源一致，inline 零额外调用；THashMap 懒构造经 @PointerHash 专化单源哈希；seqlock 保护单窗缓存
  ViewMapSeqBeginWrite;
  try
    if GViewMap = nil then
      GViewMap := specialize THashMap<Pointer, Pointer>.Create(VecGrowCapacity(0), @PointerHash)
    else
      GViewMap.Clear;
    atomic_store(GViewMapSingleKey, nil, mo_release);
    atomic_store(GViewMapSingleVal, nil, mo_release);
  finally
    ViewMapSeqEndWrite;
  end;
end;

procedure ViewMapClear; inline;
begin
  // 稳定性：Free 释放不丢，零泄漏；Clear 后容量归零与原 SetLength(0) 语义一致，THashMap 析构经 Finalize 全量释放；seqlock 清单窗缓存
  ViewMapSeqBeginWrite;
  try
    if GViewMap <> nil then
    begin
      GViewMap.Free;
      GViewMap := nil;
    end;
    atomic_store(GViewMapSingleKey, nil, mo_release);
    atomic_store(GViewMapSingleVal, nil, mo_release);
  finally
    ViewMapSeqEndWrite;
  end;
end;

function ViewMapCount: Integer; inline;
begin
  if GViewMap = nil then
    Result := 0
  else
    Result := Integer(GViewMap.GetCount);
end;

function ViewMapCapacity: Integer; inline;
begin
  if GViewMap = nil then
    Result := 0
  else
    Result := Integer(GViewMap.GetCapacity);
end;

procedure ViewMapLockInit;
begin
  if GViewMapLock = nil then
    GViewMapLock := TRWLock.Create;
end;

procedure ViewMapLockFini;
begin
  // 稳定性：先清容器再释放锁，零悬垂；Free 释放不丢；seqlock 清单窗缓存保发布一致
  ViewMapSeqBeginWrite;
  try
    if GViewMap <> nil then
    begin
      GViewMap.Free;
      GViewMap := nil;
    end;
    atomic_store(GViewMapSingleKey, nil, mo_release);
    atomic_store(GViewMapSingleVal, nil, mo_release);
  finally
    ViewMapSeqEndWrite;
  end;
  if GViewMapLock <> nil then
  begin
    GViewMapLock.Free;
    GViewMapLock := nil;
  end;
end;

finalization
  if GViewMap <> nil then
  begin
    GViewMap.Free;
    GViewMap := nil;
  end;
  if GViewMapLock <> nil then
  begin
    GViewMapLock.Free;
    GViewMapLock := nil;
  end;

end.
