# nextpas.core.text 代码契约

> 模块路径: `core/src/nextpas.core.text.*.pas`
> 维护者: AI
> 最后更新: 2026-07-19

详细契约以 `core/docs/text/CONTRACT.md` 与 `core/docs/text/unicode/CONTRACT.md` 为准。

---

## 概述

文本处理子系统。提供 Unicode 感知的字符串操作、UTF-8 编码、
字素簇分割、文本宽度计算、格式化和比较。Unicode 数据版本：**16.0.0**。

---

## 模块族

| 单元 | 职责 |
|------|------|
| `text.conv` | 文本转换 owner：IntToStr/FloatToStr/StrToInt、**SameText**（ASCII）、Format、Trim 等 |
| `text.char` | 字符分类和转换 |
| `text.utf8` | UTF-8 编解码 |
| `text.unicode.*` | 属性 / casefold / normalize / segment / collate / script / block |
| `text.grapheme` | 字素簇宽度门面（边界 → `GraphemeClusterByteLen`） |
| `text.width` | 显示宽度计算（CJK 双宽） |
| `text.view` | TStringView 非拥有视图 |
| `text.builder` | 字符串构建 |
| `text.compare` | 字符串比较（含 Canonical / CaseFold） |
| `text.format` | 格式化输出 |
| `text.number` | 数字格式化 |
| `text.scan` | 文本扫描/解析 |
| `text.escape` | 转义/反转义 |
| `text.strings` / `text.utils` | 字符串工具 |
| `text.base` | 基础类型和常量 |

---

## 关键接口

### Grapheme / Unicode（2026-07-19）

```pascal
// 日常宽度：边界 UAX#29 + 显示宽度启发式
function GraphemeNext(const AData: PByte; const ALen: SizeUInt): TGraphemeResult;

// 门面 re-export（nextpas.core.text.unicode）
function GraphemeClusterByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
function GetIndicConjunctBreak(const ACp: TUnicodeCodepoint): TIndicConjunctBreak;
function NFC/NFD/NFKC/NFKD(...): string;
```

- 官方一致性：`NormalizationTest.txt`、`GraphemeBreakTest.txt`、`WordBreakTest.txt`、`SentenceBreakTest.txt`、`LineBreakTest.txt` 全量离线 harness
- GB9c（InCB）已实现
- Line **双语义**：硬 `NextLine`（分隔符）vs 软 `LineBreakByteLen` / `NextLineBreak` / `SegmentLineBreaks`（UAX#14）

### 类型转换 / 文本工具 (text.conv)

`text.conv` 是 **Format / SameText / IntToStr / Trim** 等文本转换 API 的实现 owner。
`nextpas.core.system.sysutils` 仅作 SysUtils 名兼容薄门面，不得写成这些 API 的 owner。

```pascal
function IntToStr(AValue: Int64): string;
function FloatToStr(AValue: Double): string;
function StrToInt(const AValue: string): Int64;
function StrToFloat(const AValue: string): Double;
function BoolToStr(AValue: Boolean): string;
function SameText(const A, B: string): Boolean;  // ASCII fold; not unicode casefold
function Format(const AFmt: string; const AArgs: array of const): string;
function Trim(const AStr: string): string;
```

### TStringView / Builder / strings

见 `core/docs/text/README.md` 与 `core/docs/text/CONTRACT.md`。

---

## 已知限制

- Case：CaseFolding C/F/S + SpecialCasing 无条件 + Final_Sigma 官方门禁；无 tr/az/lt

1. Collation 仅 DUCET（无 CLDR locale）；UCA 16.0 CollationTest NON_IGNORABLE+SHIFTED 官方全绿
2. UAX#9 Bidi 至 L2 官方 harness 全绿（L3/L4 平台相关，不在门禁）
3. 硬 `NextLine` 非 UAX#14；软换行用 `LineBreakByteLen` / `NextLineBreak`
4. East_Asian_Width 真表（UCD 16.0）；列宽 A→1；LB19a 用 F|W|H
5. 无 CLDR tailored grapheme/word

---

## 测试入口

| 套件 | 路径 |
|------|------|
| unicode 手写 + conformance | `core/tests/nextpas.core.text.unicode/` |
| grapheme / width | `core/tests/nextpas.core.text.grapheme/`、`.../text.width/` |
| 其它 text 子模块 | `core/tests/nextpas.core.text.*/` |

Fixture 生成：

```bash
python3 core/scripts/gen_unicode_fixtures.py --version 16.0.0 \
  --fixtures-dir core/tests/nextpas.core.text.unicode/data
```

---

## 依赖关系

- 依赖: L0（base, exception 等）；不直接绑 FPC SysUtils 作为长期实现
- 被依赖: 几乎所有需要文本处理的模块（含 TUI/width 消费者）

---

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-07-19 | Conformance harness；grapheme 真源；GB9c；与 core/docs 对齐 |
| 2026-07-04 | 初始版本 |
