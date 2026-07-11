# Text Unicode 模块增强设计文档

## 概述

本文档记录 text-unicode 模块的增强设计，包括架构重构和新功能添加。

## 设计目标

1. **功能完整性**：添加 Script、Block、文本分割、排序规则等 Unicode 功能
2. **架构改进**：采用四层结构，分离类型定义、属性查询、算法实现和门面层
3. **性能优化**：优化查找算法，添加快速路径
4. **测试完善**：添加新功能测试，确保向后兼容

## 架构设计

### 四层结构

```
┌─────────────────────────────────────┐
│          门面层 (text.unicode.pas)    │
├─────────────────────────────────────┤
│         算法层                       │
│  - casefold.pas (大小写折叠)         │
│  - normalize.pas (规范化)            │
│  - segment.pas (文本分割)            │
│  - collate.pas (排序规则)            │
├─────────────────────────────────────┤
│         属性层                       │
│  - props.pas (通用属性)              │
│  - script.pas (Script 属性)          │
│  - block.pas (Block 属性)            │
├─────────────────────────────────────┤
│         基础层                       │
│  - types.pas (类型定义)              │
│  - base.pas (工具函数)               │
│  - data.pas (数据管理)               │
└─────────────────────────────────────┘
```

### 模块职责

#### 基础层

- **types.pas**：定义所有 Unicode 相关类型（TUnicodeCodepoint、TGeneralCategory、TBinaryProperty、TUnicodeScript、TUnicodeBlock 等）
- **base.pas**：提供工具函数（FindRange2、FindRange3Value）
- **data.pas**：统一数据管理接口（IUnicodeDataManager）

#### 属性层

- **props.pas**：通用属性查询（HasBinaryProperty、GetGeneralCategory、IsUpper、IsLower 等）
- **script.pas**：Script 属性查询（GetScript、IsScript）
- **block.pas**：Block 属性查询（GetBlock、IsBlock）

#### 算法层

- **casefold.pas**：大小写折叠（CodepointToLower、CodepointToUpper、CaseFoldSimple、CaseFoldFull）
- **normalize.pas**：Unicode 规范化（NFD、NFC、NFKD、NFKC）
- **segment.pas**：文本分割（SegmentGraphemeClusters、SegmentWords、SegmentLines、SegmentSentences）
- **collate.pas**：排序规则（UnicodeCollator、Compare、GetSortKey）

#### 门面层

- **text.unicode.pas**：统一门面，导出所有功能

## 新增功能

### 1. Script 属性

查询字符所属的 Script（如 Latin、Cyrillic、Han 等）。

```pascal
function GetScript(const ACp: TUnicodeCodepoint): TUnicodeScript;
function IsScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean;
```

### 2. Block 属性

查询字符所属的 Unicode Block（如 Basic Latin、CJK Unified 等）。

```pascal
function GetBlock(const ACp: TUnicodeCodepoint): TUnicodeBlock;
function IsBlock(const ACp: TUnicodeCodepoint; const ABlock: TUnicodeBlock): Boolean;
```

### 3. 文本分割

按 Grapheme Cluster、Word、Line、Sentence 分割文本。

```pascal
function SegmentGraphemeClusters(const AText: string): TSegmentResultArray;
function SegmentWords(const AText: string): TSegmentResultArray;
function SegmentLines(const AText: string): TSegmentResultArray;
function SegmentSentences(const AText: string): TSegmentResultArray;
```

### 4. 排序规则

Unicode 排序规则，支持多语言排序。

```pascal
function UnicodeCollator: IUnicodeCollator;
function UnicodeCollatorWithOptions(const AOptions: TCollationOptions): IUnicodeCollator;
```

## 类型定义

### TUnicodeScript

Unicode Script 枚举，包含所有 Unicode 16.0 定义的 Script。

### TUnicodeBlock

Unicode Block 枚举，包含所有 Unicode 16.0 定义的 Block。

### TSegmentType

文本分割类型：
- stGraphemeCluster：字素簇
- stWord：单词
- stLine：行
- stSentence：句子

### TSegmentResult

分割结果记录：
- Start：起始位置
- Length：长度
- SegmentType：分割类型

### TCollationStrength

排序强度：
- csPrimary：主要差异（如 a vs b）
- csSecondary：次要差异（如 a vs á）
- csTertiary：三级差异（如 a vs A）
- csQuaternary：四级差异（如平假名 vs 片假名）
- csIdentical：完全相同

### TCollationOptions

排序选项：
- Strength：排序强度
- CaseLevel：是否启用大小写级别
- FrenchAccents：是否使用法语重音排序
- NumericOrdering：是否使用数字排序

## 测试策略

### 单元测试

每个新模块都有对应的单元测试：
- test_enhance.lpr：测试 Script、Block、文本分割、排序规则功能

### 集成测试

确保新功能与现有功能兼容：
- 运行所有 unicode 测试套件
- 确保无内存泄漏

### 性能测试

优化查找算法：
- ASCII 快速路径
- 二分查找优化

## 待办事项

1. **UTF-8 解码实现**：✅ 已完成，使用现有的 text.utf8 模块
2. **数据表完善**：✅ 已完成，Script 和 Block 数据表已从 Unicode 数据文件生成
3. **性能优化**：进一步优化查找算法和内存使用
4. **文档完善**：添加 API 文档和使用示例

## 向后兼容性

所有更改都保持向后兼容：
- 现有类型和函数签名不变
- 新增类型和函数通过门面层导出
- 现有测试继续通过

## 依赖关系

```
text.unicode.pas
├── text.unicode.types.pas
├── text.unicode.base.pas
├── text.unicode.props.pas
├── text.unicode.casefold.pas
├── text.unicode.normalize.pas
├── text.unicode.script.pas
├── text.unicode.block.pas
├── text.unicode.segment.pas
└── text.unicode.collate.pas
```

## 总结

本次增强完成了 text-unicode 模块的架构重构和功能扩展，采用四层结构分离关注点，添加了 Script、Block、文本分割、排序规则等 Unicode 功能。虽然部分功能（如 UTF-8 解码）尚未完全实现，但整体架构已经就位，为后续开发奠定了基础。
