# nextpas.core.ini 代码契约

**模块路径**：`core/src/nextpas.core.ini.pas`（1 个源文件）
**层级**：配置文本格式（依赖 L0：`text.conv`、`errors`、`mem`）
**Owner**：config-json-xml-toml-yaml-csv-ini lane
**最后更新**：2026-08-31
**版本**：1.2（+ `TIniError` 结构化诊断）

---

## 1. 源文件与职责

单文件：`TIniFile` class、`TIniError`、`TIniSection` / `TIniEntry` 内部存储、`IniParse*` / `IniStringify`。

---

## 2. 公开 API

```pascal
type
  TIniError = record
    Message: string;
    Line: UInt32;
    Column: UInt32;
    Offset: SizeUInt;
    property Col: UInt32 read Column write Column;  // alias
  end;

  TIniFile = class
    constructor Create(const AAllocator: TMemAllocator = nil);
    destructor Destroy; override;

    procedure LoadFromString(const AContent: string);
    procedure LoadFromFile(const AFileName: string);
    function TryLoadFromString(const AContent: string; out AError: string): Boolean; overload;
    function TryLoadFromString(const AContent: string; out AError: TIniError): Boolean; overload;
    function TryLoadFromFile(const APath: string; out AError: string): Boolean; overload;
    function TryLoadFromFile(const APath: string; out AError: TIniError): Boolean; overload;
    procedure SaveToFile(const AFileName: string);
    function ToString: string; override;

    function ReadString(const ASection, AKey, ADefault: string): string;
    function ReadInteger(const ASection, AKey: string; ADefault: Int64): Int64;
    function ReadBool(const ASection, AKey: string; ADefault: Boolean): Boolean;
    procedure WriteString(const ASection, AKey, AValue: string);
    procedure WriteInteger(const ASection, AKey: string; AValue: Int64);
    procedure WriteBool(const ASection, AKey: string; AValue: Boolean);

    function SectionExists(const ASection: string): Boolean;
    function KeyExists(const ASection, AKey: string): Boolean;
    procedure DeleteKey(const ASection, AKey: string);
    procedure DeleteSection(const ASection: string);
    function GetSections: TStringArray;
    function GetKeys(const ASection: string): TStringArray;
    function Allocator: TMemAllocator;
    property Strict: Boolean;  // default False; try-load rejects bare lines when True
  end;

function IniParse(const AContent: string): TIniFile;
function IniParseWith(const AContent: string; const AAllocator: TMemAllocator): TIniFile;
function IniStringify(const AFile: TIniFile): string;
```

特征：section `[name]`、`key=value`、注释 `;` / `#`、保留 value 内空白。

---

## 3. 错误与失败契约

| API | 行为 |
|-----|------|
| `LoadFromString` | 宽松解析；重复 section 合并、重复 key last-wins；裸行（非 section / 非 key=value）忽略 |
| `TryLoadFromString` / `TryLoadFromFile` | `False` + string **或** `TIniError`（重载）；`Strict=True` 时裸行失败 |
| `IniParse(IReader)` | `IoReadAll` + bulk cap（`FORMAT_BULK_PARSE_MAX_BYTES`） |
| `LoadFromFile` / `SaveToFile` | 经 `nextpas.core.fs`（`ReadFileText` / `WriteAtomic`）；I/O 失败抛 `ENextPasError`；**禁止** `TextFile`/`AssignFile` |
| OOM | `EResourceExhaustedError` |

行尾：LF、CRLF、lone CR 均识别。结构化 `TIniError` 提供 `Message`/`Line`/`Column`/`Offset`（`Col` 别名）；string 重载格式为 `line N, column C: message`（与历史兼容）。

---

## 4. Lifetime / 所有权

- 调用方拥有 `TIniFile` 并 `Free`
- `IniParse` / `IniParseWith` 返回新实例，调用方负责释放
- 内部 section/entry 由 `TIniFile` + allocator 管理

---

## 5. 不变量

- **[INV-1]** section/key 查找大小写不敏感（实现 `CaseInsensitiveEqual`）
- **[INV-2]** 重复 section 合并到已有；重复 key 更新为最后值
- **[INV-3]** `ToString` / `IniStringify` / `SaveToFile` 可 roundtrip 常规内容

---

## 6. 与 config 的关系

- `TConfigFormat.cfIni` 存在
- `TConfig.LoadFromIni` / `TryLoadFromIni` 通过 `TIniFile` 加载并展平为 dot-path（`section.key`）
- `IConfig.ToIni` / `SaveToIni` 经 `config.export`，带 **representability** 护栏（非法 section/key/value 不静默写出）

INI 模块本身不实现 config 插值或多源合并。

---

## 7. 依赖边界

- `nextpas.core.text.conv`、`errors`、`mem`
- 禁止 SysUtils INI 包装作为长期方案

---

## 8. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.ini/test_ini_facade_surface
make focused FOCUS=core/tests/nextpas.core.ini/test_ini_roundtrip
```

套件：`test_ini`、`test_ini_edge_cases`、`test_ini_roundtrip`、`test_ini_facade_surface`。
Config 侧另有 `test_config_ini_export`。

---

## 9. Out of scope / Future

- 不引入 `IIniDocument` 除非有强 consumer
- 不支持任意嵌套（非 INI 模型）；嵌套由 config 的 `section.sub.key` 约定表达
- 完整 Windows INI API 兼容层：不做

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-20 | 1.0 | 首次契约，对齐 TIniFile 真实 API | config-formats lane |
| 2026-08-31 | 1.2 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
