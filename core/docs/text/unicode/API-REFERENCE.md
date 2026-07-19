# nextpas.core.text.unicode — API 参考

## 门面单元

```pascal
uses nextpas.core.text.unicode;
```

统一 re-export 所有子模块的公共 API。以下按功能域组织。

---

## 规范化 (normalize.pas)

### NFD / NFC / NFKD / NFKC

```pascal
function NFD(const AText: string): string;   // Canonical Decomposition
function NFC(const AText: string): string;   // Canonical Decomposition + Composition
function NFKD(const AText: string): string;  // Compatibility Decomposition
function NFKC(const AText: string): string;  // Compatibility Decomposition + Composition
```

将 UTF-8 字符串转换为指定 Unicode 规范化形式。

- **NFD**: 展开所有规范分解，按 CCC 重排 combining marks
- **NFC**: NFD 后重新组合可能的码点对
- **NFKD**: 展开所有分解（包括兼容性分解）
- **NFKC**: NFKD 后重新组合

```pascal
// 示例: e acute 分解
NFD('é')  // → 'e' + U+0301 (combining acute)
NFC('é')  // → 'é' (U+00E9, precomposed)

// 示例: 兼容性分解
NFKD('ℌ')  // → 'H' (black-letter H)
NFKC('ℌ')  // → 'H'
```

### IsNormalizedNFD / NFC / NFKD / NFKC

```pascal
function IsNormalizedNFD(const AText: string): Boolean;
function IsNormalizedNFC(const AText: string): Boolean;
function IsNormalizedNFKD(const AText: string): Boolean;
function IsNormalizedNFKC(const AText: string): Boolean;
```

检查字符串是否已经是指定规范化形式。

- 先用 QuickCheck 快速判断（O(n) 无分配）
- QuickCheck 不确定时回退到完整规范化比较

```pascal
IsNormalizedNFC('é')                    // → True (precomposed)
IsNormalizedNFC('e' + U+0301)           // → False (decomposed)
IsNormalizedNFD('e' + U+0301)           // → True
```

### QuickCheckNFD / NFC / NFKD / NFKC

```pascal
function QuickCheckNFD(const AText: string): Boolean;
function QuickCheckNFKD(const AText: string): Boolean;
function QuickCheckNFC(const AText: string): Boolean;
function QuickCheckNFKC(const AText: string): Boolean;
```

快速检查：返回 True 表示**确定**已规范化，False 表示**可能**未规范化。

比 `IsNormalizedNxx` 更快（无分配），适合"先快速检查再决定是否规范化"的模式。

```pascal
if not QuickCheckNFC(AText) then
  AText := NFC(AText);  // 可能未规范化，才执行完整规范化
```

### GetCanonicalCombiningClass

```pascal
function GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte;
```

获取码点的 Canonical Combining Class (CCC)。

- 0 = starter（基础字符）
- 1-240 = combining mark 排序值
- 230 = ABOVE（acute、diaeresis 等）
- 202 = BELOW（cedilla 等）
- 220 = BELOW（多数下加符号）

```pascal
GetCanonicalCombiningClass(Ord('A'))   // → 0 (starter)
GetCanonicalCombiningClass($0301)      // → 230 (combining acute)
GetCanonicalCombiningClass($0327)      // → 202 (combining cedilla)
```

### GetDecompositionMapping

```pascal
function GetDecompositionMapping(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeCodepoint; out ALen: Byte;
  out AIsCompatibility: Boolean): Boolean;
```

获取码点的分解映射。

- **返回 True**: 有分解，`ADst[0..ALen-1]` 为分解序列
- **返回 False**: 无分解
- **AIsCompatibility**: True = 兼容性分解（NFKC/NFKD 使用），False = 规范分解
- **ADst 数组**: 至少 18 个元素（最大分解长度为 18，U+FDFA）

```pascal
var Dst: array[0..17] of TUnicodeCodepoint;
    Len: Byte;
    IsCompat: Boolean;
GetDecompositionMapping($00E9, Dst, Len, IsCompat);
// Len=2, Dst[0]=$65('e'), Dst[1]=$0301(combing acute), IsCompat=False

GetDecompositionMapping($FDFA, Dst, Len, IsCompat);
// Len=18, 18个阿拉伯码点, IsCompat=True
```

### IsCompositionExcluded

```pascal
function IsCompositionExcluded(const ACp: TUnicodeCodepoint): Boolean;
```

检查码点是否在 Full_Composition_Exclusion 列表中。被排除的码点不会在 NFC 组合阶段被生成。

排除条件:
- 兼容性可分解的码点
- 单例分解（canonical 分解到单个码点）
- 非 starter 分解（分解序列首码点 CCC > 0）
- Hangul 音节和 Jamo（有独立组合逻辑）

```pascal
IsCompositionExcluded($0340)  // → True (单例: → U+0300)
IsCompositionExcluded($0344)  // → True (非starter: → U+0308+U+0301)
IsCompositionExcluded($00E9)  // → False (正常组合码点)
```

---

## 排序 (collate.pas)

### TCollationOptions

```pascal
type
  TCollationStrength = (
    csPrimary,      // 忽略大小写和重音
    csSecondary,    // 区分重音，忽略大小写
    csTertiary,     // 区分大小写（默认）
    csQuaternary,   // 码点值兜底
    csIdentical     // 等同 quaternary
  );

  TCollationOptions = record
    Strength: TCollationStrength;  // 默认 csTertiary
    CaseLevel: Boolean;            // 大小写级别（二三级之间）
    FrenchAccents: Boolean;        // 法语重音（从右到左比较）
    NumericOrdering: Boolean;      // 数字序列按数值排序
  end;
```

### UnicodeCollator / UnicodeCollatorWithOptions

```pascal
function UnicodeCollator: IUnicodeCollator;
function UnicodeCollatorWithOptions(const AOptions: TCollationOptions): IUnicodeCollator;
```

获取排序器实例。`UnicodeCollator` 使用默认选项 (csTertiary)。

```pascal
var Col := UnicodeCollator;
Col.Compare('apple', 'banana');  // → -1

var Opts := DefaultCollationOptions;
Opts.NumericOrdering := True;
var NumCol := UnicodeCollatorWithOptions(Opts);
NumCol.Compare('file9', 'file10');  // → -1 (数值排序)
```

### IUnicodeCollator

```pascal
type
  IUnicodeCollator = interface
    function Compare(const A, B: string): Integer;
    function TextEquals(const A, B: string): Boolean;
    function StartsWith(const AText, APrefix: string): Boolean;
    function EndsWith(const AText, ASuffix: string): Boolean;
    function Contains(const AText, ASubstring: string): Boolean;
    function IndexOf(const AText, ASubstring: string): SizeInt;
    function GetSortKey(const AText: string): TCollationKey;
  end;
```

| 方法 | 说明 |
|------|------|
| `Compare(A, B)` | 比较两个字符串，返回 -1/0/1 |
| `TextEquals(A, B)` | 排序等价性检查 |
| `StartsWith(Text, Prefix)` | 排序感知的前缀检查 |
| `EndsWith(Text, Suffix)` | 排序感知的后缀检查 |
| `Contains(Text, Substring)` | 排序感知的包含检查 |
| `IndexOf(Text, Substring)` | 排序感知的子串查找，0=未找到 |
| `GetSortKey(Text)` | 生成排序键（可存储/传输） |

### GetCollationWeight

```pascal
function GetCollationWeight(const ACp: TUnicodeCodepoint): UInt32;
```

获取码点的 DUCET 排序权重（packed: primary<<16 | secondary<<8 | tertiary）。

- 0 = ignorable（格式字符、combining marks）
- 非零 = 有排序意义

```pascal
GetCollationWeight(Ord('A'))     // → $23EC2008 (primary=$23EC, secondary=$20, tertiary=$08)
GetCollationWeight($0301)        // → 0 (combining acute, ignorable)
GetCollationWeight($200B)        // → 0 (ZWSP, ignorable)
```

### SortStrings

```pascal
procedure SortStrings(var A: array of string);
```

使用当前默认排序器对字符串数组原地排序。

---

## 分割 (grapheme.pas / segment.pas)

### IUnicodeSegmenter

```pascal
type
  IUnicodeSegmenter = interface
    function NextGraphemeCluster(const AText: string; APos: SizeInt): SizeInt;
    function NextWord(const AText: string; APos: SizeInt): SizeInt;
    function NextLine(const AText: string; APos: SizeInt): SizeInt;       { hard }
    function NextSentence(const AText: string; APos: SizeInt): SizeInt;
    function NextLineBreak(const AText: string; APos: SizeInt): SizeInt;  { UAX#14 soft }
    function SegmentLineBreaks(const AText: string): TSegmentResultArray;
    { ... Segment* / Count* 等见源码 }
  end;
```

| 方法 | 说明 |
|------|------|
| `NextGraphemeCluster(Text, Pos)` | 下一个字素簇边界位置 |
| `NextWord(Text, Pos)` | 下一个词边界位置 |
| `NextLine(Text, Pos)` | **硬**行：CR/LF/NEL/LS/PS |
| `NextLineBreak(Text, Pos)` | **软**行：UAX#14 换行机会（`LineBreakByteLen`） |
| `SegmentLineBreaks(Text)` | 软行切段（`stLineBreak`） |
| `NextSentence(Text, Pos)` | 下一个句子边界位置 |

```pascal
var Seg := UnicodeSegmenter;
Seg.NextWord('hello world', 1);        // → 6
Seg.NextLine('hello world', 1);        // → 12（无硬分隔符）
Seg.NextLineBreak('hello world', 1);   // → 7（空格后机会）
function LineBreakByteLen(Data, Len): SizeUInt; // 字节核
```

### UnicodeSegmenter

```pascal
function UnicodeSegmenter: IUnicodeSegmenter;
```

获取默认分割器单例。

---

## 属性查询 (data.pas / props.pas)

### IUnicodeDataManager

```pascal
type
  IUnicodeDataManager = interface
    function GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory;
    function HasBinaryProperty(const ACp: TUnicodeCodepoint; const AProp: TBinaryProperty): Boolean;
    function GetScript(const ACp: TUnicodeCodepoint): TScript;
    function GetBlock(const ACp: TUnicodeCodepoint): TUnicodeBlock;
    function GetUpperCaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function GetLowerCaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function GetTitleCaseMapping(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
    function CaseFoldFull(const ACp: TUnicodeCodepoint; out AOut: array of TUnicodeCodepoint): Byte;
    function GetDecompositionMapping(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap; out AIsCompatibility: Boolean): Byte;
    function GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte;
    function GetCompositionExclusion(const ACp: TUnicodeCodepoint): Boolean;
  end;
```

### UnicodeData

```pascal
function UnicodeData: IUnicodeDataManager;
```

获取属性管理器单例（临界区保护）。

```pascal
var D := UnicodeData;
D.GetGeneralCategory(Ord('A'));           // → gcuUppercaseLetter
D.HasBinaryProperty($0020, ubpWhiteSpace); // → True
D.GetScript($4E00);                       // → scHan
D.GetBlock($4E00);                        // → ubCJKUnifiedIdeographs
D.GetLowerCaseMapping(Ord('A'));           // → Ord('a')
```

---

## 大小写 (case.pas)

### IsUpper / IsLower

```pascal
function IsUpper(const ACp: TUnicodeCodepoint): Boolean;
function IsLower(const ACp: TUnicodeCodepoint): Boolean;
```

检查码点是否为大写/小写字母。

### CaseFoldSimple / CaseFoldFull

```pascal
function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
function CaseFoldFull(const ACp: TUnicodeCodepoint; out AOut: array of TUnicodeCodepoint): Byte;
```

- **CaseFoldSimple**: 简单大小写折叠（1:1 映射），适合快速比较
- **CaseFoldFull**: 完整大小写折叠（可能 1:N），返回输出长度

```pascal
CaseFoldSimple(Ord('A'))  // → Ord('a')
CaseFoldSimple($00DF)     // → $00DF (ß 不变，需 CaseFoldFull 展开为 'ss')
```

---

## 工具函数 (utils.pas)

### IsAsciiString

```pascal
function IsAsciiString(const AValue: string): Boolean;
```

检查字符串是否全部由 ASCII 字符组成（U+0000-U+007F）。

使用 8 字节并行检查（UInt64 + 0x8080808080808080 位掩码），比逐字节检查快 ~8x。

```pascal
IsAsciiString('hello')    // → True
IsAsciiString('helloé')   // → False
IsAsciiString('')          // → True
```

---

## 基础类型 (base.pas)

### TUnicodeCodepoint

```pascal
type
  TUnicodeCodepoint = UInt32;
```

Unicode 码点类型，范围 0x0000-0x10FFFF。

### 辅助函数

```pascal
function Utf8Len(const ACp: TUnicodeCodepoint): Byte;
function ToUtf8(const ACp: TUnicodeCodepoint): string;
function FromUtf8(const AStr: string; out ACp: TUnicodeCodepoint): Boolean;
function IsValidCodepoint(const ACp: TUnicodeCodepoint): Boolean;
function IsHighSurrogate(const ACp: TUnicodeCodepoint): Boolean;
function IsLowSurrogate(const ACp: TUnicodeCodepoint): Boolean;
```

---

## 常量

```pascal
const
  UNICODE_MAX_CODEPOINT = $10FFFF;
  UNICODE_REPLACEMENT_CHAR = $FFFD;
```
