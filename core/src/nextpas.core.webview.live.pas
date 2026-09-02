unit nextpas.core.webview.live;

{** @desc webview 家族活窗注册表（家族内共享，不经门面，Owner 单源 L1 bytes.ops 已反哺 thin-forward 2026-09-02）。

       单源：L1 bytes.ops.TCompactLiveRegistry<T>（VecGrowCapacity 0→4→2× / VecRemoveSwap O(1) / Snapshot/Trim inline 单源零额外调用，零拷贝，跨家族 window.live 同源 VecGrow/VecRemoveSwap 零重复）；
       性能：inline 薄转发零额外调用，短临界 <1µs 指针-only，零拷贝；
       稳定性：析构逐槽 Default(T) 释放不丢；契约以 CONTRACT §1.2 为准，缺能力先反哺 Owner。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops;

{ 紧凑 Vec：bytes.ops 单源 inline 薄转发 }
generic procedure WebviewLiveAdd<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
generic procedure WebviewLiveRemove<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
generic procedure WebviewLiveRemoveSwap<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;

type
  { L1 薄别名：TCompactLiveRegistry 单源，inline 零额外调用，零拷贝（Register via VecGrow 0→4→2× 单源、Unregister via VecRemoveSwap O(1) swap 零拷贝、Snapshot via VecSnapshot 单 SetLength + managed/blittable 分支零拷贝、Trim via VecTrim 单源）；
    Owner 已反哺 L1 bytes.ops 已落地 2026-09-02 经设计评审，跨家族 window.live 已用 VecGrow/VecRemoveSwap 单源同源薄转发零重复；业务以 CONTRACT §1.2 为准，现薄转发不自溢（新代码优先直用 bytes.ops.TCompactLiveRegistry<T> L1 单源，见 CONTRACT §1.2/§50，Clear 逐槽 Default(T) 释放不丢，inline/零拷贝不丢）。 }
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
  // perf: single source bytes.ops VecRemoveOrdered O(n) 保序搬移 single source; not inline per design-conventions §2 红线二 (real loop bans inline, avoids I-Cache bloat), trailing Default(T) 释放 ref 不丢；order-sensitive 保留，热关闭路径请用 Swap
  specialize VecRemoveOrdered<T>(AList, ACount, AInst);
end;

generic procedure WebviewLiveRemoveSwap<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
begin
  // perf: single source bytes.ops VecRemoveSwap inline O(1) 零拷贝末尾换位，trailing Default(T) 释放 ref，不保序，热关闭默认避免 O(n²)
  specialize VecRemoveSwap<T>(AList, ACount, AInst);
end;

end.
