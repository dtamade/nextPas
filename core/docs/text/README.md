# nextpas.core.text

`nextpas.core.text` 是 `nextpas.core` 的 L1 文本基础设施模块。它负责
UTF-8 字符串处理、Unicode 支持、数值/格式化转换、只读视图、Builder、
扫描与终端显示宽度这类通用文本能力。

大多数业务代码应该优先 `uses nextpas.core.text`。需要更低层的扫描、
属性表或算法细节时，再直接引用对应子模块。

## 把模块看成四层

`nextpas.core.text` 现在可以按 4 层来理解：

| 层级            | 作用                                        | 典型单元                                                                                                                               |
| --------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Foundation      | 公开基础类型、ASCII 分类、共享 Unicode 载体 | `text.base`, `text.char`, `text.unicode.base`, `text.unicode.utils`                                                                    |
| Core Primitives | 面向字节和 UTF-8 的原语能力                 | `text.view`, `text.scan`, `text.utf8`, `text.number`, `text.unicode.props`, `text.unicode.case`, `text.unicode.normalize`              |
| Composites      | 在原语之上组合更完整的文本行为              | `text.builder`, `text.compare`, `text.escape`, `text.strings`, `text.utils`, `text.width`, `text.grapheme`, `text.conv`, `text.format` |
| Facades         | 聚合高频 surface，减少消费者 `uses` 列表    | `text`, `text.unicode`                                                                                                                 |

依赖方向保持单向：Foundation -> Core Primitives -> Composites -> Facades。
门面只做类型别名和 inline forward，不承载真实算法。

## 先知道每个子模块做什么

### Foundation

| 单元                              | 职责                              | 关键 API                                                         | 适合场景                                      |
| --------------------------------- | --------------------------------- | ---------------------------------------------------------------- | --------------------------------------------- |
| `nextpas.core.text.base`          | 公开文本基础载体                  | `TStringArray`                                                   | 门面、字符串集合工具共享数组类型              |
| `nextpas.core.text.char`          | ASCII/byte 级字符分类与大小写转换 | `IsDigit`, `IsWhitespace`, `IsJsonSpecial`, `ToLower`, `ToUpper` | 写扫描器、escape、ASCII 快路径                |
| `nextpas.core.text.unicode.base`  | Unicode 公共类型与常量            | `TUnicodeCodepoint`, `TBinaryProperty`, `TGeneralCategory`       | 需要直接处理码点和属性枚举                    |
| `nextpas.core.text.unicode.utils` | Unicode 共享区间和辅助结构        | `TCodepointRange`, 区间查找辅助                                  | `unicode`, `width`, `grapheme` 的内部共享工具 |

### Core Primitives

| 单元                                  | 职责                                   | 关键 API                                                                        | 适合场景                                |
| ------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------- |
| `nextpas.core.text.view`              | 非 owning 的 UTF-8/byte 视图           | `TStringView.Create`, `Slice`, `Trim`, `IndexOfStr`                             | parser、零拷贝 slice、轻量比较          |
| `nextpas.core.text.scan`              | SIMD 优先的扫描原语                    | `ScanSkipWhitespace`, `ScanJsonNumber`, `ScanFindSubstring`, `ViewMatchLiteral` | JSON/TOML/YAML/tokenizer 这类指针式扫描 |
| `nextpas.core.text.utf8`              | UTF-8 解码、编码、校验、迭代           | `UTF8Decode`, `UTF8Encode`, `UTF8IsValid`, `TUTF8Iterator`                      | 需要自己控制码点迭代或校验边界          |
| `nextpas.core.text.number`            | 数值到缓冲区的底层格式化               | `IntToBuffer`, `UIntToBuffer`, `FloatToBuffer`                                  | Builder、writer、formatter 的底层输出   |
| `nextpas.core.text.unicode.props`     | Unicode property/general category 查询 | `HasBinaryProperty`, `GetGeneralCategory`, `IsLetter`, `IsWhitespace`           | Unicode 语义分类、校验规则              |
| `nextpas.core.text.unicode.case`      | Unicode 大小写与 case folding          | `CodepointToUpper`, `UTF8ToUpper`, `UTF8CaseFold`, `CaseFoldFull`               | 大小写归一化、无大小写比较              |
| `nextpas.core.text.unicode.normalize` | Unicode 规范化                         | `NFD`, `NFC`, `NFKD`, `NFKC`, `IsNormalizedNFC`                                 | 规范化比较、搜索前预处理                |

### Composites

| 单元                         | 职责                                | 关键 API                                                             | 适合场景                              |
| ---------------------------- | ----------------------------------- | -------------------------------------------------------------------- | ------------------------------------- |
| `nextpas.core.text.builder`  | 可增长字符串构建器                  | `MakeStringBuilder`, `IStringBuilder.AppendStr`, `AppendView`, `AppendInt` | writer、formatter、escape 输出拼接    |
| `nextpas.core.text.compare`  | 文本比较与 Unicode 等价比较         | `TextEqual`, `TextEqualI`, `TextEqualCanonical`, `TextEqualCaseFold` | 用户输入比较、协议字段比较            |
| `nextpas.core.text.escape`   | JSON string escape/unescape         | `JsonEscapeToBuffer`, `JsonUnescapeToBuffer`, `JsonFindStringEnd`    | JSON 编码器、scanner、日志转义        |
| `nextpas.core.text.strings`  | `TStringArray` 工具与批量字符串操作 | `StringsSplit`, `StringsJoin`, `StringsTrimAll`, `GlobMatch`         | 配置行、批量字符串转换                |
| `nextpas.core.text.utils`    | 通用字符串 helper                   | `Trim`, `PadLeft`, `RepeatString`, `StringReplace`                   | 应用代码中的日常文本处理              |
| `nextpas.core.text.width`    | 终端显示宽度                        | `CodepointWidth`, `StringDisplayWidth`                               | TUI、表格布局、列宽计算               |
| `nextpas.core.text.grapheme` | grapheme cluster 边界与聚合宽度     | `GraphemeNext`, `TGraphemeResult`                                    | cursor 移动、emoji/ZWJ cluster 宽度   |
| `nextpas.core.text.conv`     | 数值与字符串转换的高层入口          | `IntToStr`, `TryStrToInt`, `FloatToStr`, `TextOfChar`                | 业务层格式化、解析入口                |
| `nextpas.core.text.format`   | 轻量格式化器                        | `TextFormat`                                                         | 不想引 `SysUtils.Format` 的格式化输出 |

### Facades

| 单元                        | 职责                                      | 关键 API                                                                                | 适合场景                                     |
| --------------------------- | ----------------------------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------- |
| `nextpas.core.text.unicode` | 聚合 property/case/normalize 高频 surface | `UTF8ToUpper`, `UTF8CaseFold`, `NFC`, `HasBinaryProperty`                               | 只关心 Unicode 能力，不想分别引入 3 个子模块 |
| `nextpas.core.text`         | 聚合高频文本 surface                      | `TextTrim`, `TStringView`, `IStringBuilder`, `MakeStringBuilder`, `TextEqualCanonical` | 大多数上层代码的默认入口                     |

## 依赖规则要守住

`nextpas.core.text` 是 L1，只能向下依赖 L0。模块内还要守住两个局部规则：

1. 门面不写逻辑，只做 alias 和 inline forward。
2. 子模块只向下依赖，避免横向循环。

`text / encoding / bytes` 这组三者是仓库里的特例，按 interface/implementation
分区引用：

```text
encoding(interface) -> bytes, text
bytes(implementation) -> encoding
text(implementation) -> encoding
```

这意味着：

- `text` 可以在 implementation 里借用 `encoding` 便利能力。
- `text` 的 interface 部分不要把 `encoding` 反向拉进来。
- 如果某个 helper 需要跨 `text`/`bytes`/`encoding` 三边可见，优先先判断
  它是不是应该下沉到更基础的 owner。

## SIMD 快路径现在覆盖哪些地方

下面这些单元已经有明确的 SIMD 或 CPU dispatch 热路径：

| 单元          | 快路径内容                                             | 退化策略                      |
| ------------- | ------------------------------------------------------ | ----------------------------- |
| `text.view`   | 相等比较、查找、计数                                   | 回退到标量循环                |
| `text.scan`   | byte/range 查找、子串扫描、JSON number/whitespace 扫描 | AVX2/SSE2 后回退标量          |
| `text.escape` | JSON escape/unescape 的 ASCII 批量拷贝与特殊字符探测   | 回退逐字节处理                |
| `text.utf8`   | UTF-8 校验走 dispatch table                            | 无 SIMD 实现时走标量解码      |
| `text.width`  | `StringDisplayWidth` 的 ASCII 宽度累计                 | 非 ASCII 回退到 grapheme 解码 |

写新代码时，优先保留 “ASCII 先快扫，复杂输入再回退” 这条形状，不要让
少量 Unicode 边界把整个热路径拖成纯标量慢路径。

## 用 Unicode 能力时怎么选入口

常见场景可以这样选：

| 需求                          | 推荐入口                                                            | 说明                                                  |
| ----------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------- |
| 按 Unicode 语义比较两个字符串 | `TextEqualCanonical`, `TextEqualCaseFold`                           | 直接从 `nextpas.core.text` 用即可                     |
| 做大小写映射或 case fold      | `UTF8ToUpper`, `UTF8ToLower`, `UTF8CaseFold`                        | 高频场景已从 facade 暴露                              |
| 做 NFC/NFD 规范化             | `NFC`, `NFD`, `IsNormalizedNFC`                                     | facade 适合高频入口；更完整 surface 在 `text.unicode` |
| 查 Unicode 属性               | `nextpas.core.text.unicode.HasBinaryProperty`, `GetGeneralCategory` | property API 保持在 `text.unicode` owner 下更清晰     |
| 逐码点处理                    | `nextpas.core.text.utf8` 或 `nextpas.core.text.unicode.base`        | 需要自己控制迭代与码点类型时更直接                    |

一个实用原则是：如果你只是在处理字符串，先从 `nextpas.core.text` 开始；
如果你已经在处理码点、属性枚举、扫描指针，就直接进对应子模块。

## 这些例子就是常见用法

### 用 facade 处理日常文本

```pascal
uses
  nextpas.core.text;

var
  Parts: TStringArray;
begin
  Parts := TextSplit(TextTrim('  a,b,c  '), ',');
  CheckEqual('a|b|c', TextJoin(Parts, '|'), 'split + join');
end;
```

### 用 builder 和 JSON escape 输出文本

```pascal
uses
  nextpas.core.text;

var
  B: IStringBuilder;
  Src: string;
  Escaped: array[0..127] of AnsiChar;
  N: SizeUInt;
begin
  B := MakeStringBuilder;
  B.AppendStr('value=');
  B.AppendInt(42);
  Src := B.ToString;

  N := JsonEscapeToBuffer(PAnsiChar(Src), Length(Src), @Escaped[0]);
  SetString(Src, PAnsiChar(@Escaped[0]), N);
end;
```

### 做 Unicode 等价比较和规范化

```pascal
uses
  nextpas.core.text;

var
  Composed: string;
  Decomposed: string;
begin
  Composed := #$C3#$85;           // U+00C5
  Decomposed := 'A' + #$CC#$8A;   // U+0041 U+030A

  Check(TextEqualCanonical(Composed, Decomposed), 'canonical equal');
  CheckEqual(Composed, NFC(Decomposed), 'normalize to NFC');
end;
```

### 算显示宽度时优先用 width/grapheme

```pascal
uses
  nextpas.core.text;

var
  Width: SizeUInt;
begin
  Width := StringDisplayWidth('A' + #$E4#$B8#$AD + #$F0#$9F#$98#$80);
  CheckEqual(Int64(5), Int64(Width), 'ASCII + CJK + emoji width');
end;
```

### 做 parser 时直接用 scan，而不是把低层 API 再包一层

```pascal
uses
  nextpas.core.text.scan;

var
  Offset: SizeUInt;
  S: string;
begin
  S := '   {"ok":true}';
  Offset := ScanSkipWhitespace(PAnsiChar(S), Length(S));
  CheckEqual(Int64(3), Int64(Offset), 'skip leading whitespace');
end;
```

### 查 Unicode property 时直接用 unicode facade

```pascal
uses
  nextpas.core.text.unicode;

begin
  Check(IsWhitespace($3000), 'ideographic space is whitespace');
  Check(IsLetter($03A9), 'omega is a letter');
end;
```

## 设计约束不要放松

这个模块当前有几条硬约束：

1. **全框架默认 UTF-8。**
   `nextpas.core.text` 不为 locale-dependent 编码语义背书。字符串 API 的默认前提是
   UTF-8 字节序列。
2. **ASCII 快路径优先。**
   常见英文配置、协议头、关键字、标识符必须先走轻量 fast path，再在需要时回退到
   Unicode 逻辑。
3. **SIMD 必须可移植。**
   可以用 AVX2/SSE2/dispatch 提速，但行为真值必须由标量路径定义，不能让不同 CPU
   得到不同答案。
4. **门面保持克制。**
   `nextpas.core.text` 只 lift 高频 consumer API。像 `scan` 这类指针导向工具，和
   property 表这种专业 surface，继续留在 owner 子模块。
5. **宽度与比较遵守 Unicode 语义，但只在 owner 里集中实现。**
   不要在上层模块重新拼自己的 case-fold、normalize、emoji width 规则。

如果你准备在 `text` 里新增能力，先回答两个问题：

- 这是真正的高频 facade surface，还是 owner 子模块里的专用能力？
- 它有没有先保住 ASCII/标量真值，再去做 SIMD 或 Unicode 扩展？
