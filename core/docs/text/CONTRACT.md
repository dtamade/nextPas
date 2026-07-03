# nextpas.core.text 代码契约

**模块路径**：`core/src/nextpas.core.text*.pas`（31 个源文件）
**层级**：L1（依赖 L0: base, exception）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块架构

```
text.base          ← TStringArray, 基础常量
text.char          ← 字符分类/转换
text.utf8          ← UTF-8 编码/解码
text.view          ← TStringView（非拥有字符串视图）
text.builder       ← IStringBuilder（可变字符串构建）
text.strings       ← 字符串操作（Trim/Pad/Split/Join/Contains...）
text.conv          ← 类型↔字符串转换（IntToStr/Format 等）
text.format        ← 格式化引擎
text.compare       ← 字符串比较（Ordinal/Natural/CaseInsensitive）
text.escape        ← C/JSON/HTML 转义/反转义
text.grapheme      ← Grapheme cluster 处理
text.width         ← 显示宽度计算（EastAsianWidth）
text.number        ← 高性能数字→字符串（Ryu 算法）
text.scan          ← 字符串扫描/解析
text.unicode       ← Unicode 属性/大小写/规范化
  ├── text.unicode.base    ← 基础类型
  ├── text.unicode.casefold ← 大小写折叠
  ├── text.unicode.normalize ← NFC/NFD 规范化
  ├── text.unicode.props    ← 字符属性查询
  └── text.unicode.utils    ← 工具函数
text.tstring       ← TString 拥有型字符串类型
text.pas           ← UTF-8 门面（re-export 常用符号）
```

### 1.2 核心类型

| 类型 | 文件 | 说明 |
|------|------|------|
| `TStringView` | view.pas | 非拥有 UTF-8 视图 (PChar + Len) |
| `IStringBuilder` | builder.pas | 可变字符串构建接口 |
| `TString` | tstring.pas | 拥有型引用计数字符串 |
| `TStringArray` | base.pas | `array of string` 别名 |

### 1.3 IStringBuilder 接口

```pascal
IStringBuilder = interface
  function Append(const AStr: string): IStringBuilder;
  function AppendCodepoint(ACP: UInt32): IStringBuilder;
  function AppendFmt(const AFmt: string; const AArgs: array of const): IStringBuilder;
  function AppendLine: IStringBuilder; overload;
  function AppendLine(const AStr: string): IStringBuilder; overload;
  procedure Clear;
  function ToString: string;
  function Length: SizeInt;
end;
```

### 1.4 关键函数

| 领域 | 函数 | 说明 |
|------|------|------|
| 转换 | IntToStr, Int64ToStr, UIntToStr, FloatToStr, BoolToStr | 类型→字符串 |
| 转换 | StrToInt, StrToInt64, StrToUInt, StrToFloat, StrToBool | 字符串→类型 |
| 转换 | TryStrToInt, TryStrToInt64... | 安全转换（Boolean 返回） |
| 操作 | Trim, TrimLeft, TrimRight, PadLeft, PadRight | 空白处理 |
| 操作 | Split, Join, Contains, StartsWith, EndsWith | 搜索/拆分 |
| 操作 | ToLower, ToUpper, Replace, Reverse | 变换 |
| 比较 | SameText, CompareText, NaturalCompare | 比较 |
| 格式 | Format, Fmt | 格式化 |
| 宽度 | TextWidth, TextWidthRange | EastAsianWidth 显示宽度 |
| Unicode | IsLetter, IsDigit, ToLower(cp), ToUpper(cp), Normalize | Unicode 属性 |
| 数字 | RyuFloatToStr | 高精度浮点→字符串 |
| 转义 | EscapeC, EscapeJSON, UnescapeC, UnescapeJSON | 转义 |

---

## 2. 不变量

- **[INV-1]** `TStringView.Data` 指向有效 UTF-8 内存（调用方保证生命周期）
- **[INV-2]** `IStringBuilder.ToString` 返回完整构建结果的拷贝
- **[INV-3]** 所有 UTF-8 处理函数对非法序列返回替换字符 (U+FFFD) 而非崩溃
- **[INV-4]** `Format` 的 %s/%d/%% 格式化与 FPC SysUtils.Format 语义兼容
- **[INV-5]** `TextWidth` 返回显示列数（全角=2，半角=1）
- **[INV-6]** `TString` 引用计数，最后一个引用释放时自动释放内存

---

## 3. 错误处理

| 场景 | 策略 |
|------|------|
| StrToInt 无效输入 | 返回 0 或抛 EConvertError |
| TryStrToInt 无效输入 | 返回 False |
| TStringView nil+非零长度 | 抛 EArgumentNil |
| Format 参数不足 | 输出 ??? 或跳过 |
| 非法 UTF-8 序列 | 替换字符 U+FFFD |
| 无效转义序列 | 抛 EConvertError 或 TUnescapeError |

---

## 4. 线程安全

| 类型 | 线程安全 | 说明 |
|------|----------|------|
| 纯函数（Trim/Split/Format 等） | ✅ | 无共享状态 |
| TStringView | ✅ | 非拥有视图 |
| IStringBuilder | ❌ | 调用方同步 |
| TString | ❌ | 引用计数非原子 |
| Unicode 属性表 | ✅ | 只读数据 |

---

## 5. 内存管理

- `TStringView`：非拥有，零分配
- `IStringBuilder`：内部 buffer 动态增长，ToString 拷贝
- `TString`：引用计数，COW 语义
- 纯函数（Trim/Split 等）：返回新分配的 string
- Unicode 属性表：编译时内嵌 (.inc 文件)

---

## 6. 测试覆盖

| 子系统 | 测试文件 | 测试数 |
|--------|----------|--------|
| 核心文本操作 | test_text | ~50 |
| 类型转换 | test_text_conv | ~30 |
| TString 类型 | test_tstring | ~20 |
| **合计** | **3 个测试目录** | **~100** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本：31 文件 / 六项契约 | Claude |
