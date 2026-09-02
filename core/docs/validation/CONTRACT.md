# nextpas.core.validation 代码契约

**模块路径**：`core/src/nextpas.core.validation.pas`（1 个源文件，511 行）
**层级**：L2（validation helpers；L0-L1，零 SysUtils，明文收集式校验）
**Owner**：validation lane
**最后更新**：2026-08-31
**版本**：1.1

---

## 1. 接口契约

### 1.1 载体

```pascal
type
  TValidationError = record
    Field: string;
    Message: string;
  end;
  TValidationErrors = array of TValidationError;
```

### 1.2 TValidator — fluent builder（record 值语义，链式返回 `Self` 零拷贝视图）

```pascal
TValidator = record
  class function Create(const AField: string): TValidator; static;
  function Required(const AValue: string): TValidator;
  function MinLen(const AValue: string; AMin: Integer): TValidator;
  function MaxLen(const AValue: string; AMax: Integer): TValidator;
  function MinInt(AValue: Int64; AMin: Int64): TValidator;
  function MaxInt(AValue: Int64; AMax: Int64): TValidator;
  function RangeInt(AValue: Int64; AMin, AMax: Int64): TValidator;
  function Email(const AValue: string): TValidator;
  function NotEmpty(const AValue: string): TValidator;
  function Matches(const AValue, APattern: string): TValidator; // * ? glob
  function OneOf(const AValue: string; const AOptions: array of string): TValidator;
  function Custom(AValid: Boolean; const AMsg: string): TValidator;
  function URL(const AValue: string): TValidator;    // http/https
  function IPv4(const AValue: string): TValidator;
  function Contains(const AValue, ASubstr: string): TValidator;
  function StartsWith(const AValue, APrefix: string): TValidator;
  function EndsWith(const AValue, ASuffix: string): TValidator;
  function Alpha(const AValue: string): TValidator;
  function AlphaNum(const AValue: string): TValidator;
  function Numeric(const AValue: string): TValidator;
  function IsValid: Boolean;
  function Errors: TValidationErrors;
  function FirstError: string;
end;
```

链式示例：`TValidator.Create('name').Required(AName).MinLen(AName,2).MaxLen(AName,64)`；每步 `Result := Self`，零额外分配，错误通过 `FErrors` 数组累计。

### 1.3 TValidationResult — 多字段聚合

```pascal
TValidationResult = record
  class function Create: TValidationResult; static;
  procedure Add(const AValidator: TValidator);
  procedure AddError(const AField, AMsg: string);
  function IsValid: Boolean;
  function Errors: TValidationErrors;
  function ErrorCount: Integer;
  function ErrorMessages: string; // "field: msg; field: msg"
end;
```

`Add` 将 `TValidator.FErrors` 批量追加至 `FErrors`（`SetLength` + `OldLen` 偏移拷贝），避免逐项重分配时的中间串。

---

## 2. 校验语义

| 规则 | 失败条件 | Message |
|------|----------|---------|
| `Required` | `Length=0` | `is required` |
| `NotEmpty` | 仅空白 (`' ' #9 #10 #13`) | `must not be empty` |
| `MinLen/MaxLen` | 长度越界 | `must be at least/at most N characters` |
| `MinInt/MaxInt/RangeInt` | 数值越界 | `must be at least/at most/between` |
| `Email` | 无 `@` 或 `@` 在首/尾 | `must be a valid email address` |
| `URL` | 非 `http://`/`https://` 或无 host | `must be a valid URL` |
| `IPv4` | 非 4 段 `0-255` 点分 | `must be a valid IPv4 address` |
| `Matches` | glob `* ?` 不匹配 | `must match pattern "..."` |
| `OneOf` | 不在 `AOptions` | `must be one of the allowed values` |
| `Contains/StartsWith/EndsWith` | 子串/前缀/后缀缺失 | `must contain/start with/end with "..."` |
| `Alpha/AlphaNum/Numeric` | 字符集不符或空 | `must contain only letters/digits/...` |

---

## 3. 依赖边界

- 允许：`nextpas.core.base`（异常分类，`TBytes` 等若需），`nextpas.core.errors` 间接。
- 禁止：`SysUtils`（`IntToStr` 自实现 `IntToStrSimple` 零依赖）、`platform`/`Windows`/`BaseUnix`、`regex`/`net` 等 L2 同层重实现。
- Owner 复用：字符串谓词 (`StrStartsWith/EndsWith/Contains`) 为本模块内联纯函数，不重复 `bytes.ops`/`text.compare` 全量实现；如后续需复杂 Unicode/正则，委托 `text`/`regex` owner，不在本模块重造（当前 ASCII 语义已满足门禁）。

---

## 4. 不变量

- **[INV-1]** 校验为累计式：单字段多规则失败时 `Errors` 长度等于失败规则数，不短路。
- **[INV-2]** 空 `TValidator`（未调用任何规则）`IsValid=True`，`Errors=[]`。
- **[INV-3]** `TValidationResult.ErrorMessages` 以 `; ` 分隔 `field: message`，空结果返回 `''`。
- **[INV-4]** `Matches` 空模式仅匹配空值（`''` ↔ `''`）。
- **[INV-5]** 数值/长度消息经 `IntToStrSimple` 产生，无 `SysUtils` 调用。

---

## 5. 性能

- `TValidator` 为 `record`，链式调用返回 `Self` 拷贝（栈上，`string` 为 COW），零堆分配于成功路径。
- `AddError`/`Add` 采用 `Inc(FErrorCount)+SetLength` 批量生长；`ErrorMessages` 仅在报告时拼接，校验路径零中间串。
- 热路径 `StrStartsWith/EndsWith/Contains` 为内联友好小循环（单次遍历，无临时 `Copy`），`OneOf` 为线性 `High(AOptions)` 扫描。

---

## 6. 错误与资源

- 校验失败不抛异常，调用方以 `IsValid`/`Errors` 分支；仅参数性 API 使用方自定抛异常。
- 无句柄/分配器外资源；`string` 由编译器管理，异常不丢。

---

## 7. 测试入口

```bash
make -C core/tests/nextpas.core.validation clean test
make focused FOCUS=core/tests/nextpas.core.validation/test_validation
```

套件：`test_validation`（Required/长度/数值/Email/NotEmpty/Matches/OneOf/Custom/聚合/边界/Url/IPv4/Contains/StartsWith/EndsWith/Alpha/AlphaNum/Numeric 等 80+ 用例）。

---

## 8. Out of scope

- 不做异步/网络校验（`URL` 仅语法，非可达性）。
- 不做 i18n/Unicode 归一（当前 ASCII `Alpha*` 语义）。
- 复杂正则委托 `nextpas.core.regex`，不在本模块重实现 glob 以外语法。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始实现：fluent `TValidator` + `TValidationResult` | validation lane |
| 2026-08-31 | 1.1 | 文档矩阵补齐：新增 `docs/validation/`（README+CONTRACT），对齐 `core-module-registry` L2 `validation`（`module-registry` deprecated alias），零 SysUtils 证据 | core-docs |
