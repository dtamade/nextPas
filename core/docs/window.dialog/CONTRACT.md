# nextpas.core.window.dialog — 已移除 (Tombstone)

> **Removed**：`nextpas.core.window.dialog*` 四件套别名已于 2026-09-02 迁移移除，规范路径为 `nextpas.core.dialog` Owner-faithful（`core/docs/dialog/CONTRACT.md`）。消除 dotted 与 Owner 分裂恢复高级感，业务以 `core/docs/dialog/CONTRACT.md` 为准。
> 物理 `nextpas.core.dialog.*` 单源 `bytes.ops WindowDialogGrowCapacity 0→32→2×` direct L2→L1 inline 零拷贝 O(1)均摊不经 `window.impl`，heaptrc 0。

**最后更新**：2026-09-02（匠心修复：迁移后移除 `window.dialog` 四件套别名，`dialog.impl` 直连 `bytes.ops`，bench 已迁移）

本文件为墓碑，历史快照已归档至 `core/docs/dialog/CONTRACT.md`。
