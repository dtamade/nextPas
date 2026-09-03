# nextpas.core.tui.buffer — 渲染模型/缓冲域契约

**模块**：`nextpas.core.tui.buffer.{base,intf,pas}` 四件套（薄门面；聚合 `cell`/`style`/`text`）
**层级**：L3 tui（依赖 `text.width` + `bytes.ops` 单源）
**四件套**：`buffer.base` ← `buffer.intf` ← `buffer` 门面；实现聚合 `buffer` + `overlay` + `cell`/`style`
**依赖**：L0–L2 only（`text.width`/`text.utf8`/`bytes.ops` 单源，不复制 width/ANSI）
**对应主契约**：`CONTRACT.md` §1.1 Text/layout/render model + §5 内存管理 + §5.1–5.6 Capability
**门禁**：`heaptrc 0 unfreed`（`Destroy`/`Resize` 配对 `FreeMem` + `IAllocator` 生命周期不丢）

## 职责

- 双缓冲 `TBuffer`（`array of TCell` + `DirtyRows` bitmask）+ `TOverlayBuffer`
- `Diff`/`DiffInto`（仅 dirty 行 + cell 级 QWord 比对，复用 `TByteSpan` cell 视图）
- 宽字形边界归一化（2 列 glyph + Skip 标记，`NormalizeWideGlyphBoundaries`）
- `SetString`/`FillH`/`SetStyle` 热路径（ASCII 快速分支 + uniform bulk Move）

## 性能

- 零拷贝 `TByteSpan` cell 视图（`ContentPtr`/`CellAt` 直接指针，不复制）
- 热点 `inline`：`MarkRowDirty`/`ContentBase`/`IndexOfPos`/`CellReset`/`CellEquals`
- `DiffInto` 复用 `APatches` 数组（只增不减，单次 `SetLength`）
- 复用 `bytes.ops` 单源（`CellGlyph` 23 字节内联，不经 `SysUtils`）

## 稳定性

- `TBuffer.Destroy` / `Resize` 配对 `FreeMem`（`IAllocator` 非空路径）+ `heaptrc 0`
- `buffer` 生命周期 ⊆ `allocator` 生命周期（接口 refcount）
- 越界 `CellAt` 返回 `nil`，热路径裁剪不抛异常

## Owner 边界

- 缺能力先反哺 `text.width`/`bytes.ops`/`mem.intf`，不绕 `platform` 直接分配
