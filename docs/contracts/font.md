# nextpas.core.font 代码契约

> 模块路径: `core/src/nextpas.core.font.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

字体子系统 Facade 聚合器。统一导出 TTF 解析器、扫描线光栅化器、
精简版塑形器、字形 atlas。支持 CFF/CFF2、可变字体、OpenType 特性。

---

## 模块族

| 子模块 | 职责 |
|--------|------|
| font.base | 基础类型（TGlyphID, TFontMetrics 等） |
| font.ttface | TrueType/OpenType 字体解析 |
| font.rasterizer | 扫描线光栅化 |
| font.shaper | 文本塑形（GSUB/GPOS） |
| font.atlas | 字形图集管理 |

---

## 关键特性

- TrueType 轮廓解析（glyf/loca/head/hhea/maxp）
- CFF/CFF2 字体支持（OTTO parsing, Type 2 charstring）
- 可变字体（fvar/avar/gvar/hvar/VVAR）
- OpenType 特性（kern/liga/calt/mark/mkmk/clig）
- GSUB 替换（Single/Multiple/Alternate/Context/ChainedContext）
- GPOS 定位（Single/Pair/MarkToBase/MarkToLigature/Cursive/MarkToMark）
- LCD 亚像素光栅化（3x4 非对称过采样）

---

## 线程安全

- 字体解析后只读，可安全并发查询
- Atlas 不线程安全（需外部同步）

---

## 依赖关系

- 依赖: base, math, mem, platform.freetype.ffi
- 被依赖: tui, 图形渲染

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
