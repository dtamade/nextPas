# nextpas.core.text.unicode — 接口契约

## 概述

`nextpas.core.text.unicode` 是 nextPas 的 Unicode 处理模块，提供 NFC/NFD/NFKC/NFKD 规范化、
DUCET 排序、UAX#29 文本分割、大小写映射和属性查询。基于 Unicode 16.0.0 数据。

## 模块结构

| 子模块 | 职责 |
|--------|------|
| `types.pas` | 基础类型（含 `TIndicConjunctBreak`） |
| `base.pas` | 区间二分查找原语 |
| `props.pas` | GC / BinaryProperty / GCB / InCB / **WBP** |
| `casefold.pas` | 大小写映射 + CaseFold |
| `normalize.pas` | NFC/NFD/NFKC/NFKD + QuickCheck |
| `segment.pas` | UAX#29 + `GraphemeClusterByteLen` + **`WordBreakByteLen`** |
| `collate.pas` | DUCET 排序 |
| `script.pas` / `block.pas` | Script / Block |
| `data.pas` | IUnicodeDataManager |
| 门面 `unicode.pas` | re-export（含 `GraphemeClusterByteLen` / `WordBreakByteLen` / InCB / WBP） |

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
4. **单一真源**：`GraphemeNext` 与 `NextGraphemeCluster` 边界一致
5. **GB9c**：`InCB=Consonant … Linker … × Consonant` 已实现
6. **Word**：`NextWord` / `SegmentWords` 按 UAX#29 边界切分（含空白段）
### 排序

自反 / 对称 / 传递；`Compare` 与 sort key 符号一致；仅 DUCET。

## 错误处理

| 场景 | 行为 |
|------|------|
| 空输入 | 空结果 |
| 非法 UTF-8 | 按 U+FFFD、消费 1 字节（可与 Prepend 组簇） |
| 代理对 | 无效序列 |

## 已知限制

1. 无 CLDR tailored grapheme / word
2. Collation 仅 DUCET（无 locale）
3. Sentence/Line 未接官方 BreakTest 全量

## 测试入口

```bash
for t in test_case test_data test_enhance test_grapheme_uax29 \
         test_normalize test_property test_collate \
         test_conformance_normalize test_conformance_grapheme \
         test_conformance_word; do
  make -C core/tests/nextpas.core.text.unicode/$t clean test
done
```

Fixture 生成：

```bash
python3 core/scripts/gen_unicode_fixtures.py --version 16.0.0 \
  --fixtures-dir core/tests/nextpas.core.text.unicode/data
python3 core/scripts/gen_unicode_wbp.py --version 16.0.0 --output-dir core/src
```

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-07-19 | WordBreak 官方 harness + WBP 表 + UAX#29 NextWord |
| 2026-07-19 | Conformance harness；CCC/compose 修复；GB9c/InCB；Grapheme 真源合并 |
| 2026-07-11 | enhance 边界测试与文档四件套 |
