# nextpas.core.text.unicode — Unicode 子模块族

## 概述

`nextpas.core.text.unicode` 是 nextPas 框架的 Unicode 处理模块族，提供完整的 Unicode 16.0 支持。它涵盖属性查询、大小写映射、规范化、文本分割、排序规则等核心 Unicode 能力。

模块族采用 **门面 + 子模块** 架构：`nextpas.core.text.unicode` 是消费者入口，只做类型别名和 inline forward；真实算法和数据在各子模块中。

## 模块架构

```
┌─────────────────────────────────────────────────────────────┐
│  nextpas.core.text.unicode (门面)                           │
│  类型别名 + inline forward，消费者唯一入口                   │
├─────────────────────────────────────────────────────────────┤
│  子模块层                                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ types    │ │ base     │ │ props    │ │ casefold │      │
│  │ 基础类型 │ │ 区间查找 │ │ 属性查询 │ │ 大小写   │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ normalize│ │ segment  │ │ collate  │ │ script   │      │
│  │ 规范化   │ │ 文本分割 │ │ 排序规则 │ │ 脚本属性 │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                   │
│  │ block    │ │ data     │ │ utils    │                   │
│  │ 块属性   │ │ 数据表   │ │ 共享工具 │                   │
│  └──────────┘ └──────────┘ └──────────┘                   │
├─────────────────────────────────────────────────────────────┤
│  .inc 数据层（自动生成）                                     │
│  data.inc, props.inc, casefold.inc, normalize.inc,          │
│  gcb.inc, collate.inc, script.inc, block.inc                │
└─────────────────────────────────────────────────────────────┘
```

## 子模块详解

### types — 基础类型定义

**文件**: `nextpas.core.text.unicode.types.pas`

定义所有 Unicode 类型枚举和记录，是整个模块族的类型根基。

| 类型 | 用途 |
|------|------|
| `TUnicodeCodepoint` | Unicode 码点 (`UInt32`) |
| `TGeneralCategory` | 通用类别枚举（30 值） |
| `TBinaryProperty` | 二值属性枚举（21 值） |
| `TGraphemeBreakProperty` | 字素簇分割属性（15 值） |
| `TUnicodeScript` | 脚本属性枚举（160+ 值） |
| `TUnicodeBlock` | Unicode 块枚举（300+ 值） |
| `TCodepointRange2` | 码点范围（Lo, Hi, Delta） |
| `TCodepointRange3` | 码点范围（Lo, Hi, Byte 值） |
| `TCodepointRange16` | 码点范围（Lo, Hi, UInt16 值） |
| `TCaseFoldEntry` | 大小写折叠映射条目 |

### base — 共享查找原语

**文件**: `nextpas.core.text.unicode.base.pas`

提供二分查找原语，供所有子模块共享。

| 函数 | 用途 |
|------|------|
| `FindRange2` | 在 `TCodepointRange2` 数组中查找，返回索引 |
| `FindRange3Value` | 在 `TCodepointRange3` 数组中查找，返回 Byte 值 |
| `FindRange16Value` | 在 `TCodepointRange16` 数组中查找，返回 UInt16 值 |

### props — 属性查询

**文件**: `nextpas.core.text.unicode.props.pas`

Unicode 属性查询的核心实现。BMP 使用 256×256 stage-2 查表（O(1)），SMP 使用范围二分查找（O(log n)）。

| 函数 | 用途 |
|------|------|
| `HasBinaryProperty` | 查询 21 种二值属性 |
| `GetGeneralCategory` | 获取通用类别 |
| `GetGraphemeBreakProperty` | 获取字素簇分割属性 |
| `IsLetter`, `IsDigit`, `IsWhitespace` 等 | 语义分类快捷函数 |

**数据来源**: `nextpas.core.text.unicode.data.inc`, `nextpas.core.text.unicode.props.inc`, `nextpas.core.text.unicode.gcb.inc`

### casefold — 大小写映射

**文件**: `nextpas.core.text.unicode.casefold.pas`

Unicode 大小写映射和 case folding。

| 函数 | 用途 |
|------|------|
| `CodepointToLower` / `CodepointToUpper` / `CodepointToTitle` | 单码点映射 |
| `CaseFoldSimple` | 简单 case fold（1:1 映射） |
| `CaseFoldFull` | 完整 case fold（可能 1:N 映射） |
| `UTF8ToUpper` / `UTF8ToLower` / `UTF8CaseFold` | 字符串级映射 |

### normalize — 规范化

**文件**: `nextpas.core.text.unicode.normalize.pas`

Unicode 规范化算法（UAX #15），支持 NFC/NFD/NFKC/NFKD。

| 函数 | 用途 |
|------|------|
| `NFD` | 规范分解 |
| `NFC` | 规范组合（Hangul + canonical composition） |
| `NFKD` / `NFKC` | 兼容分解/组合 |
| `IsNormalizedNFD` / `IsNormalizedNFC` | 规范化检查（完整规范化比较） |
| `IsNormalizedNFKD` / `IsNormalizedNFKC` | 兼容规范化检查 |
| `QuickCheckNFD` / `QuickCheckNFC` | 快速规范化检查（O(n) 无分配） |

**算法要点**:
1. NFD: 递归分解 → 按 CCC 排序
2. NFC: NFD → Hangul 组合 → canonical composition（CCC 间隔检查）
3. QuickCheck: 检查 combining class 顺序 + 可组合对（无内存分配，比完整规范化快得多）

### segment — 文本分割（UAX #29）

**文件**: `nextpas.core.text.unicode.segment.pas`

基于 UAX #29 的文本分割实现，支持字素簇、单词、句子、行分割。

| 函数 | 用途 |
|------|------|
| `SegmentGraphemeClusters` | 字素簇分割（完整 GB 规则） |
| `SegmentWords` | 单词分割（CJK 表意文字独立分词） |
| `SegmentSentences` | 句子分割 |
| `SegmentLines` | 行分割 |

**支持的 GB 规则**: GB1, GB3, GB4, GB5, GB6, GB7, GB8, GB9, GB9a, GB9b, GB11, GB12-13, GB999

**CJK 分词**: CJK 表意文字（U+4E00-U+9FFF, U+3400-U+4DBF, U+F900-U+FAFF）每个字符作为独立单词返回。

### collate — 排序规则（DUCET）

**文件**: `nextpas.core.text.unicode.collate.pas`

基于 DUCET（Default Unicode Collation Element Table）的排序实现。

| 函数/类型 | 用途 |
|-----------|------|
| `GetCollationWeight` | 获取码点的 DUCET 打包权重（UInt32） |
| `UnpackPrimary` / `UnpackSecondary` / `UnpackTertiary` | 解包权重分量 |
| `UnicodeCollator` | 全局排序器实例 |
| `UnicodeCollatorWithOptions` | 自定义排序选项的排序器 |
| `IUnicodeCollator.Compare` | 字符串比较 |
| `IUnicodeCollator.GetSortKey` | 生成排序键 |
| `IUnicodeCollator.Equals` / `StartsWith` / `EndsWith` / `Contains` / `IndexOf` | 语义操作 |

**排序键格式**: NFD 规范化 → 单遍权重收集 → 三级权重排序键
- Level 1: 主权重（2 字节大端）— 基础字符排序
- Level 2: 次权重（2 字节大端）— 变音差异
- Level 3: 三级权重（2 字节大端）— 大小写/假名差异
- 级别分隔符: 0x01，终止符: 0x00

**性能优化**:
- `GetSortKey`: 单遍收集所有权重（`CollectWeights`），然后写入各级（避免 3 次迭代）
- `Compare`: 直接逐级比较权重数组（避免生成完整排序键）

**打包权重格式**: `(primary << 16) | (secondary << 8) | tertiary`

**覆盖范围**:
- 39,749 个 DUCET 显式条目
- CJK 隐式权重（Extension A + Unified + Compatibility = 28,096 字符）
- Tangut/Nushu/Khitan 隐式权重

### script — 脚本属性

**文件**: `nextpas.core.text.unicode.script.pas`

Unicode 脚本属性查询（160+ 脚本）。

| 函数 | 用途 |
|------|------|
| `GetScript` | 获取码点的脚本属性 |
| `IsScript` | 检查码点是否属于指定脚本 |

### block — Unicode 块

**文件**: `nextpas.core.text.unicode.block.pas`

Unicode 块属性查询（300+ 块）。

| 函数 | 用途 |
|------|------|
| `GetBlock` | 获取码点所属的 Unicode 块 |
| `IsBlock` | 检查码点是否属于指定块 |

## 数据生成管线

所有 `.inc` 数据文件由 `core/scripts/gen_unicode_data.py` 自动生成：

```bash
python3 core/scripts/gen_unicode_data.py --output-dir core/src
```

**数据来源**（Unicode 16.0）:
- `UnicodeData.txt` — 码点名称、类别、分解映射、大小写映射
- `DerivedCoreProperties.txt` — 二值派生属性
- `CaseFolding.txt` — 大小写折叠
- `DerivedNormalizationProps.txt` — 规范化属性 + 组合排除
- `auxiliary/GraphemeBreakProperty.txt` — 字素簇分割属性
- `emoji/emoji-data.txt` — Emoji 属性
- `allkeys.txt`（DUCET） — 排序权重

**生成的 .inc 文件**:

| 文件 | 内容 | 大小 |
|------|------|------|
| `data.inc` | 类别查表 + 大小写映射 | ~500KB |
| `props.inc` | 二值属性范围表 | ~200KB |
| `casefold.inc` | 大小写折叠数据 | ~50KB |
| `normalize.inc` | 分解/组合/CCC 数据 | ~600KB |
| `gcb.inc` | 字素簇分割属性 | ~230KB |
| `collate.inc` | DUCET 排序权重 | ~1.2MB |
| `script.inc` | 脚本属性范围 | ~100KB |
| `block.inc` | 块属性范围 | ~50KB |

## 使用指南

### 基本用法（通过门面）

```pascal
uses
  nextpas.core.text.unicode;

begin
  // 属性查询
  Check(IsLetter($03A9), 'omega is a letter');
  Check(IsWhitespace($3000), 'ideographic space is whitespace');

  // 大小写
  CheckEqual(Int64($0041), Int64(CodepointToUpper($0061)), 'a → A');
  CheckEqual('HELLO', UTF8ToUpper('hello'), 'hello → HELLO');

  // 规范化
  CheckEqual(#$C3#$85, NFC('A' + #$CC#$8A), 'A+ring → Å');

  // 字素簇分割
  Segments := SegmentGraphemeClusters('A' + #$CC#$81 + 'B');
  // Segments = ['Á', 'B']

  // 排序
  Collator := UnicodeCollator;
  Check(Collator.Compare('apple', 'banana') < 0, 'apple < banana');
end;
```

### 直接使用子模块

```pascal
uses
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.unicode.segment,
  nextpas.core.text.unicode.collate;

begin
  // 直接调用规范化
  Decomposed := NFD('Å');

  // 直接调用分割
  Segments := SegmentGraphemeClusters('👨‍👩‍👧‍👦');

  // 自定义排序选项
  Options := DefaultCollationOptions;
  Options.Strength := csTertiary;  // 区分大小写
  Collator := UnicodeCollatorWithOptions(Options);
end;
```

## 测试覆盖

| 测试套件 | 测试数 | 覆盖范围 |
|----------|--------|----------|
| `test_property` | 6 | 属性查询、类别、二值属性 |
| `test_case` | 7 | 大小写映射、case fold |
| `test_normalize` | 10 | NFD/NFC/NFKD/NFKC、QuickCheck |
| `test_enhance` | 6 | Script/Block 属性、便利函数、CJK 分词 |
| `test_grapheme_uax29` | 13 | UAX #29 全部 GB 规则 |
| `test_collate` | 13 | DUCET 三级权重、排序键、强度级别、排序方法 |
| **总计** | **54** | |

```bash
# 运行所有 unicode 测试
for t in test_case test_enhance test_grapheme_uax29 test_normalize test_property test_collate; do
  make -C core/tests/nextpas.core.text.unicode/$t clean test
done
```

## 依赖关系

```
types ← base ← props ← casefold ← normalize ← segment
                                      ↑
                                    collate
                                      ↑
                                    script, block
                                      ↑
                              unicode (门面)
```

- 只向下依赖，无循环
- `utils` 是共享工具层，被多个子模块引用
- `.inc` 数据文件由 `props.pas`、`normalize.pas`、`collate.pas` 等按需 include

## 设计约束

1. **门面不写逻辑**：`unicode.pas` 只做类型别名和 inline forward。
2. **数据自动生成**：所有 `.inc` 文件由 `gen_unicode_data.py` 生成，禁止手动编辑。
3. **BMP O(1) 查表**：BMP 码点使用 256×256 stage-2 表，SMP 使用范围二分查找。
4. **NFD 前置**：规范化和排序都先做 NFD，确保算法正确性。
5. **零外部依赖**：只依赖 `nextpas.core.text.utf8` 和 `nextpas.core.base`。
