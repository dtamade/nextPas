# nextpas.core.csv 代码契约

**模块路径**：`core/src/nextpas.core.csv.pas`（1 个源文件）
**层级**：表格格式工具（依赖 L0：`errors`、`mem`）；**不**进入 `TConfigFormat`
**Owner**：config-json-xml-toml-yaml-csv-ini lane
**最后更新**：2026-07-20
**版本**：2.0（对齐真实 record API + free helpers）

---

## 1. 源文件与职责

单文件模块：`TCsvReader`、`TCsvWriter`、`TCsvError`、`CsvParse*`。

---

## 2. 公开 API

```pascal
type
  TStringArray = array of string;
  TStringMatrix = array of TStringArray;

  TCsvError = record
    Message: string;
    Offset: SizeUInt;
    Line: UInt32;
    Column: UInt32;
  end;

  TCsvReader = record
    procedure Init(...);
    procedure Done;
    class function Create(...): TCsvReader; static;
    function ReadRow(out AFields: TStringArray): Boolean;
    function ReadAll: TStringMatrix;
    function HasError: Boolean;
    function GetError: string;
    function Error: TCsvError;
    function Allocator: TMemAllocator;
    property Delimiter: AnsiChar;
  end;

  TCsvWriter = record
    class function Create(...): TCsvWriter; static;
    class function CreateWith(const AAllocator: TMemAllocator; ...): TCsvWriter; static;
    procedure WriteRow(const AFields: array of string);
    procedure WriteField(const AField: string);
    procedure EndRow;
    function ToString: string;
    function Allocator: TMemAllocator;
  end;

function CsvParse(const AInput: string; ADelimiter: AnsiChar = ','): TStringMatrix;
function CsvParseWith(const AInput: string; const AAllocator: TMemAllocator; ...): TStringMatrix;
```

选项：`Delimiter`、`FieldsPerRecord`、`TrimSpace`、`Comment`、allocator。

---

## 3. 错误与失败契约

- 解析失败 **in-band**：`HasError` / `GetError` / `Error`，不抛业务解析异常
- `ReadRow` 返回 `False`：EOF **或** 错误（先查 `HasError`）
- `ReadAll`：只返回失败记录 **之前** 的完整行；不追加触发错误的残缺/宽度不匹配行
- `TCsvError`：`Message`、`Line`、`Column`、`Offset`

---

## 4. Lifetime / 所有权

- `TCsvReader` 内部持有输入 `string` 引用，防止悬垂
- `ReadRow`/`ReadAll` 返回的字段字符串为 **拥有副本**
- record 值语义；`Init`/`Done` 或 `Create` 路径按实现使用
- Writer 内部 buffer；`ToString` 产出独立 string

---

## 5. 不变量

- **[INV-1]** RFC 4180 取向：默认 `,` 与 `"`；引号内可含分隔符与换行；`""` → `"`
- **[INV-2]** 行尾 CRLF 或 LF
- **[INV-3]** 固定字段数校验可选（`FieldsPerRecord`）

---

## 6. 依赖边界

- `nextpas.core.errors`、`mem.intf` / `mem.allocator.base`
- **与 config 无直接耦合**（config 不加载 CSV）

---

## 7. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.csv/test_csv_facade_surface
make focused FOCUS=core/tests/nextpas.core.csv/test_csv_roundtrip
```

套件：`test_csv`、`test_csv_edge_cases`、`test_csv_roundtrip`、`test_csv_facade_surface`。

---

## 8. Out of scope / Future

- 不强制 `ICsvDocument` 式 interface 包装
- 不作为 config 多源格式
- 流式 `IStream` 入口：Future，需独立 slice

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始 | — |
| 2026-07-20 | 2.0 | 补全 Create/Init、CsvParse、错误与 ReadAll 语义 | config-formats lane |
