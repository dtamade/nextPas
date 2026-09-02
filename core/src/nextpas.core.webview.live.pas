unit nextpas.core.webview.live;

{** @desc webview 家族共享的活窗注册表（M6 复用提纯的 webview 版）。

       目的：消除 gtk/wk/webview2/fake 4 后端对“动态数组 + VecGrow + 末尾换位删除
       + Count 双计数”样板的重复拷贝，统一 Vec 单源（bytes.ops.VecGrow /
       VecGrowCapacity inline 零额外调用，0→4→2×），保持单点修复能力。

       设计：
       - 本单元为家族内特权共享（不经门面 re-export），仅被 `webview.*` 后端 uses
       - 提供泛型 helpers：WebviewLiveAdd / WebviewLiveRemove / WebviewLiveRemoveSwap
         inline 薄转发 bytes.ops Vec 单源（VecRemoveSwap O(1) 零拷贝末尾换位为热关闭路径默认，VecRemoveOrdered O(n) 保序仅 order-sensitive 保留），避免逐元素 shift 的 O(n²) 退化
       - 另提供泛型类 TWebviewLiveRegistry<T> 为 L1 bytes.ops.TCompactLiveRegistry<T> 的家族内薄别名（已反哺 L1 通用容器，CONTRACT §1.2/§50 可抽模块候选已落地 L1，零重复实现，inline 单源，跨家族与 window.live 同构已收敛至 bytes.ops 单源），Count 为 O(1) inline 读；Unregister 默认 O(1) swap，UnregisterSwap 同源
       - 线程假设：Register/Unregister 仅在主线程调用（Create/Close 经
         Dispatcher marshal），Count 无锁 inline 读；若需跨线程再引入 ILock
       - 与 collections.slotregistry 互补：slotregistry 适用于稀疏槽复用
         （-1 sentinel + Free 栈），此处为紧凑 Vec 语义；选型依据：webview
         活窗列表为短小紧凑迭代（FindByView / PumpAll），无需稀疏槽。
       - 抽取评估（CONTRACT §1.2/§50 可抽模块候选已显式登记并反哺落地 L1）：utils/callbacks
         与 live/pool（含本单元 WebviewPoolTryAcquire/Release）已评估为通用
         辅助/池模块抽取候选，其中 live 紧凑 Vec 已反哺至 L1 bytes.ops 通用注册表
         TCompactLiveRegistry<T>（VecGrowCapacity 0→4→2× inline
         零额外调用、VecRemoveSwap/Ordered 零拷贝、Default(T) 释放不丢），本单元
         TWebviewLiveRegistry<T> 仅为 L1 薄别名 inline 零额外调用，跨家族与 window.live
         同构重复已消除（同源 bytes.ops 单源单实现），通用池若独立需反哺 L1 通用池 owner
         sync.pool/collections 并经设计评审，不在当前 slice 自行外溢（守四件套纯度、L0-L3 守恒）。
       - 性能：全部 inline 薄转发零额外调用，Swap O(1) 零拷贝末尾换位热关闭默认，
         Snapshot/Trim 单次 SetLength、Pool 短临界区仅指针存取堆分配在外（<1µs）。
       - 稳定性：析构 Clear 逐槽 Default(T) nil 释放 ref/interface，Pool 溢出方
         Dispose 单所有权释放不丢，trailing nil 保探链。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex;

{ 紧凑 Vec 语义：Add/Remove 单源，bytes.ops VecGrow inline 复用 — 已反哺 L1 通用注册表，家族内薄别名零重复 }
generic procedure WebviewLiveAdd<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
generic procedure WebviewLiveRemove<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
generic procedure WebviewLiveRemoveSwap<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
{ 池化 Slab 通用抽象：GIdlePool/GCompletionPool 双池复用单源，避免各自手写 Acquire/Release 与 SetLength 扩容重复；短临界区仅指针存取，堆分配在外，零拷贝 inline — 可抽模块候选已显式登记并评估（live 已反哺 L1 bytes.ops，pool 待反哺 L1 通用池 owner sync.pool/collections/bytes.ops 并经设计评审，当前家族内薄封装不经门面 re-export，CONTRACT §1.2/§50） }
generic function WebviewPoolTryAcquire<T>(var APool: array of T; var ACount: Integer; ALock: TMutex): T; inline;
generic function WebviewPoolTryRelease<T>(var APool: array of T; var ACount: Integer; ALock: TMutex; const AItem: T): Boolean; inline;

type
  { 已反哺 L1：紧凑 Vec 泛型封装 TWebviewLiveRegistry<T> 为 L1 bytes.ops.TCompactLiveRegistry<T> 薄别名，CONTRACT §1.2/§50 已落地；与 window.live 同构已收敛至 bytes.ops 单源（VecGrow/VecRemoveSwap/VecSnapshot/VecTrim inline 零额外调用，0→4→2× 单源），零重复实现，家族内不另立实现 }
  generic TWebviewLiveRegistry<T> = class(specialize TCompactLiveRegistry<T>)
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

end.
