# nextpas.core.text.unicode — 接口契约

## 概述

`nextpas.core.text.unicode` 是 nextPas 的 Unicode 处理模块，提供 NFC/NFD/NFKC/NFKD 规范化、
DUCET 排序、UAX#29 文本分割、大小写映射和属性查询。基于 Unicode 16.0.0 数据。

## 模块结构

| 子模块 | 职责 |
|--------|------|
| `types.pas` | 基础类型（含 `TIndicConjunctBreak`） |
| `base.pas` | 区间二分查找原语 |
| `props.pas` | GC / Binary / GCB / InCB / WBP / SBP / LBP / **Bidi_Class** / brackets / **East_Asian_Width** |
| `casefold.pas` | 大小写映射 + CaseFold |
| `normalize.pas` | NFC/NFD/NFKC/NFKD + QuickCheck |
| `segment.pas` | UAX#29 Grapheme/Word/Sentence + **UAX#14 LineBreak** ByteLen |
| `bidi.pas` | **UAX#9** 双向算法（至 L2） |
| `collate.pas` | DUCET 排序 |
| `script.pas` / `block.pas` | Script / Block |
| `data.pas` | IUnicodeDataManager |
| 门面 `unicode.pas` | re-export（含 ResolveBidi / GetBidiClass / 边界 ByteLen） |

`text.grapheme.GraphemeNext` 委托 `GraphemeClusterByteLen` 做边界，本地只计算显示宽度。

## 不变量

### 规范化

1. 幂等：`NFD(NFD(s))=NFD(s)`，`NFC(NFC(s))=NFC(s)`
2. ASCII 快路径：纯 ASCII 规范化后不变
3. **官方一致性**：Unicode 16.0 `NormalizationTest.txt` 全量通过（~19965 行）

### 分割

1. 覆盖性 / 非空 / 边界单调
2. **官方一致性**：`GraphemeBreakTest.txt` 全量通过（~1093 行）
3. **官方一致性**：`WordBreakTest.txt` 全量通过（~1826 行）
4. **官方一致性**：`SentenceBreakTest.txt` 全量通过（~512 行）
5. **官方一致性**：`LineBreakTest.txt` 全量通过（~16672 行，UAX#14）
6. **单一真源**：`GraphemeNext` 与 `NextGraphemeCluster` 边界一致
7. **GB9c**：`InCB=Consonant … Linker … × Consonant` 已实现
8. **Word**：`NextWord` / `SegmentWords` 按 UAX#29 边界切分（含空白段）
9. **Sentence**：`NextSentence` / `SegmentSentences` 按 UAX#29 边界（`SentenceBreakByteLen`）
10. **Line 双语义**：
    - **硬** `NextLine` / `SegmentLines`：仅硬分隔符（CR/LF/NL 等），**不是** UAX#14
    - **软** `LineBreakByteLen` / `NextLineBreak` / `SegmentLineBreaks`：UAX#14 换行机会（`stLineBreak`）

### 双向（UAX#9）

1. **官方一致性**：`BidiCharacterTest.txt` 全量（~91707 数据行）fail=0
2. **官方一致性**：`BidiTest.txt` abstract 全量（~770k 方向×行）fail=0
3. 覆盖规则至 **L2**（含 X10 isolating runs、N0 括号配对）；**L3/L4** 平台相关，不在门禁
4. API：`GetBidiClass` / `ResolveBidi` / `ResolveBidiClasses`（`AParagraphDir`：0=LTR,1=RTL,2=auto）

### 大小写（CaseFolding / SpecialCasing）

1. **官方一致性**：UCD 16.0 `CaseFolding.txt` 状态 C/F/S 全量 fail=0（默认 **clRoot**）
2. **官方一致性**：`SpecialCasing.txt` 无条件行 fail=0；**Final_Sigma** 字符串 lower 上下文
3. API：`UTF8ToUpper/Lower/Title/CaseFold`（无参 = root）；`TCaseLocale` / `TCaseOptions` 重载
4. **Locale（可选）**：`clTurkish` / `clAzeri` 启用 CaseFold **T**（2 行）+ SpecialCasing **tr/az**（含 `After_I` / `Not_Before_Dot`）；`clRoot` 默认与现网一致
5. **未实现**：`lt`（立陶宛）条件 SpecialCasing；完整 CLDR tailoring
6. `UTF8ToTitle` = 逐码点 title（非 Word_Break 词首）

### 排序（UCA / DUCET）

1. **官方一致性**：UCA 16.0 `CollationTest_NON_IGNORABLE` 全量（~206286 数据行，skip 代理）fail=0
2. **官方一致性**：UCA 16.0 `CollationTest_SHIFTED` 全量（~227801 行）fail=0
3. 实现：多 CE expansion、contraction（contiguous + discontiguous non-starter 扩展）、variable weighting（NonIgnorable / Shifted）
4. API：`IUnicodeCollator` / `UnicodeCollatorWithOptions`；`TCollationOptions.VariableWeighting`；门禁 strength=identical
5. 仍仅 **DUCET**（无 CLDR locale tailor）

## 错误处理

| 场景 | 行为 |
|------|------|
| 空输入 | 空结果 |
| 非法 UTF-8 | 按 U+FFFD、消费 1 字节（可与 Prepend 组簇） |
| 代理对 | 无效序列 |

## 已知限制

1. 无 CLDR tailored grapheme / word
2. Collation 仅 DUCET（无 CLDR locale tailor）；UCA CollationTest 官方全绿
3. **硬** `NextLine` 不替换为 UAX#14；软换行用 `LineBreakByteLen` / `NextLineBreak` / `SegmentLineBreaks`
4. East_Asian_Width 真表（UCD 16.0）：`GetEastAsianWidth`；LB19a `$EastAsian`=F|W|H；列宽 A→1

## 测试入口

**一键门禁（M1）**：

```bash
make -C core/tests/nextpas.core.text.unicode gate
```

导航：[ROADMAP.md](ROADMAP.md) · 性能准则：[SCORECARD.md](SCORECARD.md)

Fixture / UCD 升版生成：见 [README.md#ucd-升版一条龙](README.md#ucd-升版一条龙)。

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-07-20 | M1：ROADMAP + SCORECARD + `make gate`；测试入口收敛 |
| 2026-07-20 | Turkic/locale Case：TCaseLocale + CaseFold T + SpecialCasing tr/az |
| 2026-07-20 | UAX#9 Bidi 官方双 harness 全绿（Character+Abstract）+ ResolveBidi API |
| 2026-07-20 | NextLineBreak / SegmentLineBreaks 便利 API；stLineBreak |
| 2026-07-20 | LineBreak 官方 16672/16672 全绿；硬 NextLine / 软 LineBreakByteLen 双语义钉死 |
| 2026-07-19 | SentenceBreak 官方 harness + SBP + UAX#29 NextSentence |
| 2026-07-19 | WordBreak 官方 harness + WBP 表 + UAX#29 NextWord |
| 2026-07-19 | Conformance harness；CCC/compose 修复；GB9c/InCB；Grapheme 真源合并 |
| 2026-07-11 | enhance 边界测试与文档四件套 |
