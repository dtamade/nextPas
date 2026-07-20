# nextpas.core.text.unicode — 使用指南

## 场景 1: 文本规范化管线

### 输入规范化

```pascal
uses nextpas.core.text.unicode;

// 用户输入可能混合各种 Unicode 形式，先规范化再存储
function NormalizeInput(const AText: string): string;
begin
  // NFC 是最常见的存储形式（precomposed）
  // 先快速检查，避免不必要的规范化
  if QuickCheckNFC(AText) then
    Result := AText
  else
    Result := NFC(AText);
end;
```

### 大小写无关比较

```pascal
// 方案 1: CaseFold（推荐，最准确）
function CaseFoldEquals(const A, B: string): Boolean;
var
  LCF_A, LCF_B: string;
begin
  LCF_A := UTF8CaseFold(A);
  LCF_B := UTF8CaseFold(B);
  Result := LCF_A = LCF_B;
end;

// 方案 2: 排序器（适合需要排序的场景）
function CollationEquals(const A, B: string): Boolean;
begin
  Result := UnicodeCollator.TextEquals(A, B);
end;
```

### NFD vs NFC 选择

```
NFC  → 存储、传输（更紧凑，多数系统期望此形式）
NFD  → 搜索、比较（分解后更容易做子串匹配）
NFKC → 标识符规范化、搜索引擎索引
NFKD → 搜索（宽松匹配，忽略格式差异）
```

---

## 场景 2: 区域感知排序

### 默认 DUCET 排序

```pascal
var Col := UnicodeCollator;
// 基本比较
Col.Compare('apple', 'Banana');   // → -1 (a < B in DUCET)

// 数组排序
var Names: array[0..2] of string = ('Müller', 'Adler', 'Böhm');
SortStrings(Names);
// 结果: Adler, Böhm, Müller
```

### 强度级别

```pascal
// Primary: 忽略大小写和重音
var POpts := DefaultCollationOptions;
POpts.Strength := csPrimary;
var PCol := UnicodeCollatorWithOptions(POpts);
PCol.Compare('resume', 'résumé');  // → 0 (相等)

// Tertiary: 区分大小写
var TOpts := DefaultCollationOptions;
TOpts.Strength := csTertiary;
var TCol := UnicodeCollatorWithOptions(TOpts);
TCol.Compare('a', 'A');  // → -1 (小写 < 大写)
```

### 数值排序

```pascal
var Opts := DefaultCollationOptions;
Opts.NumericOrdering := True;
var NumCol := UnicodeCollatorWithOptions(Opts);

// 文件名排序
NumCol.Compare('file2', 'file10');   // → -1 (2 < 10)
NumCol.Compare('file9', 'file10');   // → -1 (9 < 10)
NumCol.Compare('file99', 'file100'); // → -1 (99 < 100)
```

### 法语重音排序

```pascal
var Opts := DefaultCollationOptions;
Opts.FrenchAccents := True;
Opts.Strength := csSecondary;
var FrCol := UnicodeCollatorWithOptions(Opts);
// 法语规则: 从右到左比较重音
// côte < coté < côte < côté
```

---

## 场景 3: 文本分割

### 字素簇分割（显示宽度）

```pascal
var Seg := UnicodeSegmenter;

// 统计显示字符数（不是字节数！）
Seg.CountGraphemeClusters('hello');            // → 5
Seg.CountGraphemeClusters('你好世界');           // → 4
Seg.CountGraphemeClusters(Utf8Of([$1F600]));   // → 1 (emoji)

// 按字素簇截取（不破坏 emoji/CJK）
var S := 'hello你好🌍world';
Seg.SubstringByGraphemeClusters(S, 5, 3);  // → '你好🌍'
```

### 词分割（CJK 分词）

```pascal
var Seg := UnicodeSegmenter;
var Text := 'hello world';
var Pos := 1;
while Pos <= Length(Text) do
begin
  var NextPos := Seg.NextWord(Text, Pos);
  // 处理 Text[Pos..NextPos-1]
  Pos := NextPos;
end;
```

### 换行机会

```pascal
var Seg := UnicodeSegmenter;
// 找到所有可能的换行位置
var Pos := 1;
while Pos <= Length(AText) do
begin
  var BreakPos := Seg.NextLine(AText, Pos);
  // BreakPos 是可以断行的位置
  Pos := BreakPos;
end;
```

---

## 场景 4: 属性分类

### 标识符验证

```pascal
function IsValidIdentifier(const AText: string): Boolean;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LFirst: Boolean;
begin
  if AText = '' then Exit(False);
  LFirst := True;
  LIter.Init(PByte(PAnsiChar(AText)), SizeUInt(Length(AText)));
  while LIter.Next(LCp) do
  begin
    if LFirst then
    begin
      // 首字符: Letter 或 underscore
      if not (UnicodeData.GetGeneralCategory(LCp) in [gcuUppercaseLetter, gcuLowercaseLetter,
        gcuTitlecaseLetter, gcuModifierLetter, gcuOtherLetter]) and (LCp <> Ord('_')) then
        Exit(False);
      LFirst := False;
    end
    else
    begin
      // 后续字符: Letter, Number, underscore
      if not (UnicodeData.GetGeneralCategory(LCp) in [gcuUppercaseLetter, gcuLowercaseLetter,
        gcuTitlecaseLetter, gcuModifierLetter, gcuOtherLetter,
        gcuDecimalNumber, gcuLetterNumber, gcuOtherNumber]) and (LCp <> Ord('_')) then
        Exit(False);
    end;
  end;
  Result := True;
end;
```

### 脚本检测

```pascal
var D := UnicodeData;
D.GetScript($4E00);   // → scHan (汉字)
D.GetScript($0627);   // → scArabic (阿拉伯文)
D.GetScript($0410);   // → scCyrillic (西里尔文)
D.GetScript(Ord('A')); // → scLatin (拉丁文)
```

### 块检测

```pascal
var D := UnicodeData;
D.GetBlock($4E00);    // → ubCJKUnifiedIdeographs
D.GetBlock($1F600);   // → ubEmoticons
D.GetBlock($0041);    // → ubBasicLatin
```

---

## 场景 5: 排序键缓存

```pascal
// 排序键可以缓存，避免重复计算
type
  TSortedEntry = record
    Key: TCollationKey;
    Value: string;
  end;

var Col := UnicodeCollator;
var Entries: array[0..99] of TSortedEntry;
for I := 0 to 99 do
begin
  Entries[I].Value := SomeData[I];
  Entries[I].Key := Col.GetSortKey(SomeData[I]);  // 一次计算
end;

// 排序键字节比较（比 Compare 更快）
for I := 1 to 99 do
  if CompareBytes(Entries[I-1].Key, Entries[I].Key) > 0 then
    // 需要排序
```

---

## 常见陷阱

### 1. 字节长度 ≠ 字符数

```pascal
Length('hello')     // → 5 (字节，ASCII 巧合等于字符数)
Length('你好')       // → 6 (字节，不是 2 个字符)
// 正确: 用字素簇计数
UnicodeSegmenter.CountGraphemeClusters('你好')  // → 2
```

### 2. 字符串比较 ≠ Unicode 排序

```pascal
// 字节比较 (错误)
'a' < 'B'  // → True (0x61 < 0x42 是错的)

// Unicode 排序 (正确)
UnicodeCollator.Compare('a', 'B')  // → -1 (DUCET: a < B)
```

### 3. NFC 不等于"预组合"

```pascal
// NFC 不保证所有字符都是预组合形式
// 例如: combining marks 可能无法组合
NFC('a' + U+0301)  // → 'á' (U+00E9, 组合成功)
NFC('a' + U+0300 + U+0301)  // → 'a' + U+0300 + U+0301 (无法组合)
```

### 4. NFD 改变字符串长度

```pascal
Length('é')           // → 2 字节 (U+00E9)
Length(NFD('é'))       // → 3 字节 ('e' + U+0301)
Length(NFD('ℌ'))       // → 1 字节 ('H')  ← 注意: NFD 不展开兼容分解
Length(NFKD('ℌ'))      // → 1 字节 ('H')  ← NFKD 展开兼容分解
```

## 双门面与 locale Case（M1/M2）

```pascal
uses nextpas.core.text.unicode;

// 日常 root（text 门面也可）
S := UTF8ToLower('İSTANBUL');

// Turkic
var O: TCaseOptions;
O.Locale := clTurkish;
S := UTF8ToLower('İSTANBUL', O);  // i + ...

// 词首 Title（Word_Break）；默认 UTF8ToTitle 仍是逐码点
S := UTF8ToTitleWords('hello world'); // Hello World
```

## 硬行 vs 软换行

```pascal
// 硬：仅 CR/LF/NL…
P := UnicodeSegmenter.NextLine(Text, P);
// 软 UAX#14：
P := NextLineBreak(Text, P);
```

## Bidi 视觉序（TUI RTL，P2-3）

```pascal
uses nextpas.core.text.unicode;

// 完整解析：段落等级 + levels + VisualToLogical
R := ResolveBidi(MixedHebrewEnglish, 2); // auto
// R.VisualToLogical[vis] = logical codepoint index

// 仅有 levels 时重排
Map := ReorderBidiVisually(R.Levels);

// 逻辑 → 视觉
L2V := InvertBidiIndexMap(R.VisualToLogical, Length(R.Levels));

// 显示串：按视觉序拼 UTF-8（不含 L3 镜像）
Display := ApplyBidiVisualOrder(MixedHebrewEnglish, 2);
```


## 错误策略（P3-2）

三层模型见 [ERROR_MODEL.md](../ERROR_MODEL.md)：

- **L0** Unicode 处理：非法 UTF-8 → U+FFFD，不抛
- **L1** StrTo* / Format / View：异常或 Try*
- **L2** IDNA：`TIDNAErrorKind`，不抛

```pascal
var K: TIDNAErrorKind;
ACE := IDNAToASCII(Domain, K);
if K <> idnaOk then
  // 使用 IDNAErrorKindName(K)
```
