# nextpas.core.text 代码契约

> 模块路径: `core/src/nextpas.core.text.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

文本处理子系统。提供 Unicode 感知的字符串操作、UTF-8 编码、
字素簇分割、文本宽度计算、格式化和比较。

---

## 模块族

| 单元 | 职责 |
|------|------|
| `text.conv` | 类型转换（IntToStr/FloatToStr/StrToInt 等） |
| `text.char` | 字符分类和转换 |
| `text.utf8` | UTF-8 编解码 |
| `text.unicode.*` | Unicode 属性和规范化 |
| `text.grapheme` | 字素簇分割 |
| `text.width` | 显示宽度计算（CJK 双宽） |
| `text.view` | TStringView 非拥有视图 |
| `text.builder` | TBufStringBuilder 高效构建 |
| `text.compare` | 字符串比较（大小写敏感/不敏感） |
| `text.format` | 格式化输出 |
| `text.number` | 数字格式化 |
| `text.scan` | 文本扫描/解析 |
| `text.escape` | 转义/反转义 |
| `text.strings` | 字符串工具（Split/Join/Trim 等） |
| `text.base` | 基础类型和常量 |

---

## 关键接口

### 类型转换 (text.conv)

```pascal
function IntToStr(AValue: Int64): string;
function FloatToStr(AValue: Double): string;
function StrToInt(const AValue: string): Int64;
function StrToFloat(const AValue: string): Double;
function BoolToStr(AValue: Boolean): string;
```

### TStringView (text.view)

```pascal
type
  TStringView = record
    function Len: SizeUInt;
    function Slice(AOffset, ALength: SizeUInt): TStringView;
    function ToString: string;
    function IsEmpty: Boolean;
  end;
```

### TBufStringBuilder (text.builder)

```pascal
type
  TBufStringBuilder = record
    procedure Append(const AValue: string);
    procedure AppendChar(ACh: AnsiChar);
    procedure Clear;
    function AsView: TStringView;
    function Len: SizeUInt;
    function Cap: SizeUInt;
  end;
```

### 字符串工具 (text.strings)

```pascal
function Split(const AValue, ASep: string): TStringArray;
function Join(const AParts: TStringArray; const ASep: string): string;
function Trim(const AValue: string): string;
function Contains(const AHaystack, ANeedle: string): Boolean;
function StartsWith(const AValue, APrefix: string): Boolean;
function EndsWith(const AValue, ASuffix: string): Boolean;
```

---

## 前置条件

1. `StrToInt`: 输入必须是有效整数格式
2. `StrToFloat`: 输入必须是有效浮点格式
3. `TStringView.Slice`: offset + length <= view length
4. `Split`: 分隔符不能为空字符串

---

## 后置条件

1. `IntToStr`: 返回非空数字字符串
2. `TBufStringBuilder.Len`: 返回已追加字符数
3. `Split`: 返回的数组长度 >= 1

---

## 错误语义

| 场景 | 行为 |
|------|------|
| `StrToInt("abc")` | raise EConvertError |
| `StrToFloat("abc")` | raise EConvertError |
| `TStringView.Slice` 越界 | raise EOutOfRange |

---

## 线程安全

- 所有函数为纯函数或值类型操作，无线程安全问题
- TBufStringBuilder 为值类型 record，不共享

---

## 内存管理

- TStringView 为非拥有视图，不分配内存
- TBufStringBuilder 使用栈缓冲区
- Split/Join 等返回新分配的字符串

---

## 测试覆盖

| 套件 | 路径 |
|------|------|
| test_text_* | `core/tests/nextpas.core.text*/` |

---

## 依赖关系

- 依赖: base, platform（UTF-8 底层）
- 被依赖: 几乎所有需要文本处理的模块

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
