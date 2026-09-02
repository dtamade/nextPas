unit nextpas.core.webview.live;

{** @desc webview 家族活窗注册表 — 已收敛至 L1 单源（兼容薄别名）。

       单源：L1 bytes.ops.TCompactLiveRegistry<T>（VecGrowCapacity 0→4→2× / VecRemoveSwap O(1) / Snapshot/Trim inline 单源零额外调用，零拷贝，跨家族 window.live 同源 VecGrow/VecRemoveSwap 零重复）；
       收敛：过程式 WebviewLiveAdd/Remove/RemoveSwap 双形已收敛删除（冗余薄转发消除，统一经 bytes.ops VecGrow/VecRemoveSwap 单源 inline 零额外调用）；本单元保留 TWebviewLiveRegistry<T> 兼容薄别名（deprecated，inline 零额外调用、零拷贝），新代码优先直用 L1 bytes.ops.TCompactLiveRegistry<T> 单源以提升跨家族复用度；
       性能：inline 薄转发零额外调用，短临界 <1µs 指针-only，零拷贝；
       稳定性：析构逐槽 Default(T) 释放不丢；契约以 CONTRACT §1.2 为准，缺能力先反哺 Owner. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops;

type
  { L1 兼容薄别名（deprecated）：新代码直用 bytes.ops.TCompactLiveRegistry<T> L1 单源，见 CONTRACT §1.2/§50；本别名 inline 薄转发零额外调用、零拷贝（Register via VecGrow 0→4→2× 单源、Unregister via VecRemoveSwap O(1) swap 零拷贝、Snapshot via VecSnapshot 单 SetLength + managed/blittable 分支零拷贝、Trim via VecTrim 单源）；Clear 逐槽 Default(T) 释放不丢. }
  generic TWebviewLiveRegistry<T> = class(specialize TCompactLiveRegistry<T>)
  end deprecated 'Use bytes.ops.TCompactLiveRegistry<T> L1 single source (VecGrow 0→4→2× / VecRemoveSwap O(1) zero-copy, inline)';

implementation

end.
