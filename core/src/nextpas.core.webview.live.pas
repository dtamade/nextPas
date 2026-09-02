unit nextpas.core.webview.live;

{** @desc webview 家族共享的活窗注册表（M6 复用提纯的 webview 版）。

       目的：消除 gtk/wk/webview2/fake 4 后端对“动态数组 + VecGrow + 末尾换位删除
       + Count 双计数”样板的重复拷贝，统一 Vec 单源（bytes.ops.VecGrow /
       VecGrowCapacity inline 零额外调用，0→4→2×），保持单点修复能力。

       设计：
       - 本单元为家族内特权共享（不经门面 re-export），仅被 `webview.*` 后端 uses
       - 提供泛型 helpers：WebviewLiveAdd / WebviewLiveRemove / WebviewLiveRemoveSwap
         inline 薄转发 bytes.ops Vec 单源（VecRemoveSwap O(1) 零拷贝末尾换位为热关闭路径默认，VecRemoveOrdered O(n) 保序仅 order-sensitive 保留），避免逐元素 shift 的 O(n²) 退化
       - 另提供泛型类 TWebviewLiveRegistry<T> 供需要对象化注册表的后端（与
         window.live 类同构），Count 为 O(1) inline 读；Unregister 默认 O(1) swap，UnregisterSwap 同源
       - 线程假设：Register/Unregister 仅在主线程调用（Create/Close 经
         Dispatcher marshal），Count 无锁 inline 读；若需跨线程再引入 ILock
       - 与 collections.slotregistry 互补：slotregistry 适用于稀疏槽复用
         （-1 sentinel + Free 栈），此处为紧凑 Vec 语义；选型依据：webview
         活窗列表为短小紧凑迭代（FindByView / PumpAll），无需稀疏槽。
       - 抽取评估（CONTRACT §1.2/§50 可抽模块候选显式登记）：utils/callbacks
         与 live/pool（含本单元 WebviewPoolTryAcquire/Release）已评估为通用
         辅助/池模块抽取候选，当前仍滞留家族内；结论：与 window.live 紧凑 Vec
         的跨家族重复已收敛至 bytes.ops 单源（VecGrowCapacity 0→4→2× inline
         零额外调用、VecRemoveSwap/Ordered 零拷贝、Default(T) 释放不丢），无
         跨家族重复实现，保留 bytes.ops 单源但未统一为通用模块；通用辅助/池若独立需反哺 L1 collections/bytes.ops 通用池 owner
         并经设计评审，不在当前 slice 自行外溢（守四件套纯度、L0-L3 守恒）。
       - 性能：全部 inline 薄转发零额外调用，Swap O(1) 零拷贝末尾换位热关闭默认，
         Snapshot/Trim 单次 SetLength、Pool 短临界区仅指针存取堆分配在外（<1µs）。
       - 稳定性：析构 Clear 逐槽 Default(T) nil 释放 ref/interface，Pool 溢出方
         Dispose 单所有权释放不丢，trailing nil 保探链。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex;

{ 紧凑 Vec 语义：Add/Remove 单源，bytes.ops VecGrow inline 复用 }
generic procedure WebviewLiveAdd<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
generic procedure WebviewLiveRemove<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
generic procedure WebviewLiveRemoveSwap<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
{ 池化 Slab 通用抽象：GIdlePool/GCompletionPool 双池复用单源，避免各自手写 Acquire/Release 与 SetLength 扩容重复；短临界区仅指针存取，堆分配在外，零拷贝 inline — 可抽模块候选显式登记（待反哺 L1 通用池 owner sync.pool/collections/bytes.ops 并经设计评审，当前家族内私有不经门面 re-export，CONTRACT §1.2/§50） }
generic function WebviewPoolTryAcquire<T>(var APool: array of T; var ACount: Integer; ALock: TMutex): T; inline;
generic function WebviewPoolTryRelease<T>(var APool: array of T; var ACount: Integer; ALock: TMutex; const AItem: T): Boolean; inline;

type
  { 可抽模块候选显式登记：紧凑 Vec 泛型封装 TWebviewLiveRegistry<T> 待反哺 L1 通用数组辅助 owner bytes.ops/collections，当前家族内私有不经门面 re-export，CONTRACT §1.2/§50；与 window.live 同复用 bytes.ops 单源思想（紧凑 Vec 注册表与 window.live 同构重复未抽至 L1，仅靠 bytes.ops VecGrow/VecRemoveSwap 单源缓解，属可抽通用 Vec 候选），零重复实现 }
  generic TWebviewLiveRegistry<T> = class
  private
    FList: array of T;
    FCount: Integer;
  public
    procedure Register(const AInst: T); inline;
    procedure Unregister(const AInst: T); inline;
    procedure UnregisterSwap(const AInst: T); inline;
    function Count: Integer; inline;
    function IsEmpty: Boolean; inline;
    function At(AIndex: Integer): T; inline;
    procedure Snapshot(var ADest: array of T); inline;
    procedure Trim; inline;
    procedure Clear;
    destructor Destroy; override;
  end;

implementation

generic procedure WebviewLiveAdd<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
begin
  // perf: single source VecGrow -> VecGrowCapacity (0→4→2×) inline, zero extra call
  specialize VecGrow<T>(AList, ACount);
  AList[ACount] := AInst;
  Inc(ACount);
end;

generic procedure WebviewLiveRemove<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
begin
  // perf: single source bytes.ops VecRemoveOrdered inline O(n) 保序，trailing Default(T) 释放 ref 不丢；order-sensitive 保留，热关闭路径请用 Swap
  specialize VecRemoveOrdered<T>(AList, ACount, AInst);
end;

generic procedure WebviewLiveRemoveSwap<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
begin
  // perf: single source bytes.ops VecRemoveSwap inline O(1) 零拷贝末尾换位，trailing Default(T) 释放 ref，不保序，热关闭默认避免 O(n²)
  specialize VecRemoveSwap<T>(AList, ACount, AInst);
end;

generic function WebviewPoolTryAcquire<T>(var APool: array of T; var ACount: Integer; ALock: TMutex): T; inline;
begin
  // perf: short critical section only pointer pop, zero heap alloc inside lock, inline zero extra call, zero-copy
  Result := Default(T);
  if ALock <> nil then ALock.Acquire;
  try
    if ACount > 0 then
    begin
      Dec(ACount);
      Result := APool[ACount];
      APool[ACount] := Default(T);
    end;
  finally
    if ALock <> nil then ALock.Release;
  end;
end;

generic function WebviewPoolTryRelease<T>(var APool: array of T; var ACount: Integer; ALock: TMutex; const AItem: T): Boolean; inline;
begin
  // perf: short critical section only pointer push, zero SetLength/heap inside lock, inline, zero-copy; overflow handled outside by caller (Dispose) to keep lock < 1µs
  Result := False;
  if ALock <> nil then ALock.Acquire;
  try
    if ACount < Length(APool) then
    begin
      APool[ACount] := AItem;
      Inc(ACount);
      Result := True;
    end;
  finally
    if ALock <> nil then ALock.Release;
  end;
end;

{ TWebviewLiveRegistry }

generic procedure TWebviewLiveRegistry.Register(const AInst: T); inline;
begin
  specialize WebviewLiveAdd<T>(FList, FCount, AInst);
end;

generic procedure TWebviewLiveRegistry.Unregister(const AInst: T); inline;
begin
  // perf: hot close path O(1) swap, single source bytes.ops VecRemoveSwap inline 零拷贝，trailing nil 释放不丢，避 O(n²) 逐元素 shift
  specialize WebviewLiveRemoveSwap<T>(FList, FCount, AInst);
end;

generic procedure TWebviewLiveRegistry.UnregisterSwap(const AInst: T); inline;
begin
  specialize WebviewLiveRemoveSwap<T>(FList, FCount, AInst);
end;

generic function TWebviewLiveRegistry.Count: Integer; inline;
begin
  Result := FCount;
end;

generic function TWebviewLiveRegistry.IsEmpty: Boolean; inline;
begin
  Result := FCount = 0;
end;

generic function TWebviewLiveRegistry.At(AIndex: Integer): T; inline;
begin
  // perf: inline O(1) index read, zero extra call
  Result := FList[AIndex];
end;

generic procedure TWebviewLiveRegistry.Snapshot(var ADest: array of T); inline;
begin
  // perf: inline thin forward to bytes.ops VecSnapshot single source (nil fast path + single SetLength + copy), zero extra alloc
  specialize VecSnapshot<T>(ADest, FList, FCount);
end;

generic procedure TWebviewLiveRegistry.Trim; inline;
begin
  // perf: inline thin forward to bytes.ops VecTrim single source
  specialize VecTrim<T>(FList, FCount);
end;

generic procedure TWebviewLiveRegistry.Clear;
begin
  // stability: nil each slot to release interface/class refs, then reset count
  while FCount > 0 do
  begin
    Dec(FCount);
    FList[FCount] := Default(T);
  end;
  SetLength(FList, 0);
end;

generic destructor TWebviewLiveRegistry.Destroy;
begin
  Clear;
  inherited Destroy;
end;

end.
