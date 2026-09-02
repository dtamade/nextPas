# nextpas.core.tui.layout — 布局引擎域契约

**模块**：`nextpas.core.tui.layout.{base,intf,pas}` 四件套（聚合 `layout` + `layout.grid` + `layout.dsl` + `frame_budget`）
**层级**：L3 tui
**四件套**：`layout.base` ← `layout.intf` ← `layout` 门面；实现聚合 `layout`/`grid`/`dsl`/`frame_budget`
**依赖**：L0–L2 only（`bytes.ops` 单源约束计算，不复制）
**对应主契约**：`CONTRACT.md` §1.1 layout + §6.1 Scorecard SC18/SC22
**门禁**：布局无资源悬垂（纯值类型 + `TRect` 视图零拷贝，无堆分配）

## 职责

- `TConstraint`（`ckLength`/`ckMin`/`ckMax`/`ckPercentage`/`ckFill`/`ckRatio`）+ `ComputeSlotSizes`
- `VerticalSplit`/`HorizontalSplit`/`Grid`（VBox/HBox/Flex/Grid 求解）
- `frame_budget`（帧预算 tick，避免布局震荡）

## 性能

- 复用 `bytes.ops` 单源（约束数组 `TByteSpan` 视图，不复制）
- 热点 `inline`：`Flex`/`Pct`/`Fixed`/`AtLeast`/`AtMost`/`V`/`H` 约束求解
- `ComputeSlotSizes` 单遍分配，`TRectArray` 视图零拷贝裁剪

## 稳定性

- 布局纯函数（输入 `TRect` + 约束 → 输出 `TRectArray`），无资源泄漏
- 比例约束分母为 0 时 `inline` 防御返回 `ckFill`

## Owner 边界

- 缺能力先反哺 `bytes.ops`（约束计算）/`sync`，不绕 `platform` 直接布局
