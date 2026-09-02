unit nextpas.core.webview.live;

{** @desc webview 家族活窗注册表 — 已物理删除，单源收敛至 L1 bytes.ops.TCompactLiveRegistry<T>。

       兼容薄别名 TWebviewLiveRegistry<T> 已于 2026-09-02 物理删除（deprecated 兼容期结束），家族内不再导入本单元，消除 glob 噪音与跨家族复用度损耗。
       单源：L1 bytes.ops.TCompactLiveRegistry<T>（VecGrowCapacity 0→4→2× / VecRemoveSwap O(1) / Snapshot/Trim inline 单源零额外调用，零拷贝，跨家族 window.live 同源 VecGrow/VecRemoveSwap 零重复）；
       性能：inline 薄转发零额外调用，短临界 <1µs 指针-only，零拷贝；
       稳定性：析构逐槽 Default(T) 释放不丢；契约以 CONTRACT §1.2 为准，缺能力先反哺 Owner. *}

{$I nextpas.core.settings.inc}

interface

// 物理删除：本单元已空，仅保留单元声明以避免外部历史导入硬失败；家族内已全量直用 bytes.ops.TCompactLiveRegistry<T> 单源 inline 零拷贝。

implementation

end.
