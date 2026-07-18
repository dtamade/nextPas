# nextpas.core.text.unicode — 接口契约

## 概述

`nextpas.core.text.unicode` 是 nextPas 的 Unicode 处理模块，提供 NFC/NFD/NFKC/NFKD 规范化、
DUCET 排序、UAX#29 文本分割、大小写映射和属性查询。基于 Unicode 16.0.0 数据。

## 模块结构

| 子模块 | 职责 |
|--------|------|
| `types.pas` | 基础类型定义（TUnicodeCodepoint 等） |
| `base.pas` | TUnicodeCodepoint 辅助函数（Utf8Len/ToUtf8/FromUtf8） |
| `utf8` | UTF-8 编解码（TUTF8Iterator/AppendUtf8Codepoint） |
| `data.pas` | 属性查询门面（GeneralCategory/BinaryProperty/Script/Block） |
| `normalize.pas` | NFC/NFD/NFKC/NFKD 规范化 + QuickCheck + CCC |
| `collate.pas` | DUCET 排序（IUnicodeCollator/Compare/GetSortKey） |
| `grapheme.pas` | UAX#29 字素簇分割 |
| `segment.pas` | 词/行/句子分割 |
| `case.pas` | 大小写映射 + CaseFold |
| `props.pas` | 属性查询（Script/Block/GeneralCategory） |
| `utils.pas` | 工具函数（IsAsciiString 等） |
| `.pas`（门面） | 统一 re-export 所有公共 API |

## 不变量

### 规范化

1. **幂等性**: `NFD(NFD(s)) = NFD(s)`, `NFC(NFC(s)) = NFC(s)`
2. **往返性**: `NFC(NFD(s))` 产生规范等价的 NFC 字符串
3. **稳定性**: 已规范化的字符串再次规范化不变
4. **QuickCheck 一致性**: `QuickCheckNFC(s) = True` ⟹ `IsNormalizedNFC(s) = True`
5. **空串**: 所有规范化函数对空串返回空串
6. **ASCII 快速路径**: 纯 ASCII 字符串规范化后不变（O(1) 检测）

### 排序

1. **自反性**: `Compare(a, a) = 0`
2. **对称性**: `Compare(a, b) = -Compare(b, a)`
3. **传递性**: `Compare(a, b) < 0 ∧ Compare(b, c) < 0` ⟹ `Compare(a, c) < 0`
4. **排序键一致性**: `Compare(a, b)` 与 `memcmp(GetSortKey(a), GetSortKey(b))` 符号一致
5. **确定性**: 相同输入始终产生相同结果

### 分割

1. **覆盖性**: 分割结果覆盖整个输入字符串（无遗漏、无重叠）
2. **非空性**: 每个分割片段非空
3. **边界单调性**: 分割边界位置严格递增

## 错误处理

| 场景 | 行为 |
|------|------|
| 空字符串输入 | 返回空串/空数组/0 |
| 无效 UTF-8 字节 | 替换为 U+FFFD，继续处理 |
| 代理对 (U+D800-U+DFFF) | 视为无效 UTF-8，替换为 U+FFFD |
| 超出 Unicode 范围 (>U+10FFFF) | 属性查询返回默认值，规范化保持不变 |
| 码点无分解 | 返回原始码点 |
| 码点无组合 | 返回原始码点对 |

## 线程安全

- **UnicodeData**: 临界区保护的单例，首次访问时初始化
- **UnicodeCollator**: 临界区保护的单例
- **UnicodeSegmenter**: 临界区保护的单例
- **无状态函数** (NFD/NFC/NFKD/NFKC/GetCanonicalCombiningClass): 天然线程安全
- **IUnicodeCollator 实例**: 实例方法非线程安全，需外部同步或每线程创建

## 内存管理

- 所有返回 `string` 的函数：调用方拥有内存，FPC 自动管理
- `TWeightArray`/`TCollationKey`: 动态数组，引用计数自动管理
- `IUnicodeCollator`/`IUnicodeSegmenter`/`IUnicodeDataManager`: 接口引用计数
- 内部 `TCodepointBuffer`: 栈分配，函数返回时自动释放

## 性能特征

| 操作 | 复杂度 | 备注 |
|------|--------|------|
| IsAsciiString | O(n/8) | 8 字节并行检查 |
| NFD/NFC (ASCII) | O(1) | 快速路径检测 |
| NFD/NFC (BMP) | O(n) | 表查找 O(1) 每码点 |
| NFD/NFC (SMP) | O(n log m) | m = SMP 范围数 |
| GetCanonicalCombiningClass | O(1) BMP / O(log m) SMP | |
| Compare | O(n) | 排序键比较 |
| GetSortKey | O(n) | 单遍收集权重 |
| QuickCheckNFD/NFC | O(n) | 无分配，纯检查 |
| 字素/词/行/句分割 | O(n) | 状态机单遍 |

## 已知限制

1. **Indic Conjunct (GB9c)**: Unicode 15.1 新增规则，需要 `InCB` 属性支持，当前未实现
2. **Tailored Grapheme Break**: UAX#29 默认规则，不支持 CLDR 定制
3. **Collation Tailoring**: 使用 DUCET 默认权重，不支持区域排序定制
4. **Sort Key 长度**: 长字符串排序键可能较长（每码点 4-6 字节）
