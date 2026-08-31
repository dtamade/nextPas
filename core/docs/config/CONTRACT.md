# nextpas.core.config 代码契约

**模块路径**：`core/src/nextpas.core.config*.pas` + `config.*.inc` 实现分片
**层级**：L3（依赖 L0–L2：`ini`、`json`、`yaml`、`toml`、`os.env`、`platform.watch`、`sync`、`errors`、`text.conv`）
**Owner**：config-json-xml-toml-yaml-csv-ini lane
**最后更新**：2026-08-31
**版本**：2.4（对齐真实单元与 API；废止 1.0 中 config.cli / config.loader / 虚构 base 描述）

---

## 概要

统一配置加载与查询：以 `IConfig`/`IConfigBuilder` 只读契约 + `TConfig` 可变实现，
支持 ini/json/yaml/toml 多格式解析、Builder 优先级合并、`$(key)` 插值与 watch 变更订阅。

## 1. 源文件与职责

| 单元 | 职责 |
|------|------|
| `config.pas` | `IConfig`、`IConfigBuilder`、`TConfig`、`TConfigFormat`、`EConfigError`、加载/读写/插值/lookup、`ConfigBuilder`/`ConfigLoad` 声明 |
| `config.builder` | `ConfigBuilder` / `ConfigLoad` 实现；source pipeline 回放 |
| `config.flatten` | JSON/YAML/TOML DOM → 扁平 dot-path 条目 |
| `config.export` | 扁平条目 → INI/JSON/YAML/TOML 文本；原子写文件；representability |
| `config.env` | 环境变量名 → config key 映射辅助（含 Windows env block 游标） |
| `config.watcher` | `TConfigWatcher` 热加载（`platform.watch`） |

**不存在的单元**（禁止写成现状）：`config.base`、`config.loader`、`config.cli`。

---

## 2. 接口契约(公开 API)

### 2.1 格式与错误

```pascal
type
  TConfigFormat = (cfIni, cfJson, cfYaml, cfToml);
  EConfigError = class(EParseError);
```

无 `cfXml`、`cfCsv`。

### 2.2 只读边界 `IConfig`

```pascal
IConfig = interface
  function GetCount: Integer;
  function GetString / GetRawString / GetStringArray / GetRawStringArray;
  function GetInt / GetBool / GetFloat;
  function TryGetInt / TryGetBool / TryGetFloat / TryGetDurationNs / TryGetByteSize;
  function GetStringRequired / GetIntRequired / GetBoolRequired / GetFloatRequired;
  procedure Require(const AKeys: array of string);
  function Has / GetKeys / GetSection;
  function GetInterpolationMode: TConfigInterpolationMode;
  function ToIni / ToJson / ToYaml / ToToml;
  property Count: Integer;
end;
```

### 2.3 Builder `IConfigBuilder`

```pascal
IConfigBuilder = interface
  function AddDefault(const AKey, AValue: string): IConfigBuilder;
  function AddIni / AddJson / AddYaml / AddToml(const AContent: string): IConfigBuilder;
  function AddEnv(const APrefix: string): IConfigBuilder;
  function AddFile(const APath: string; AFormat: TConfigFormat): IConfigBuilder; overload;
  function AddFile(const APath: string): IConfigBuilder; overload; // 扩展名自动识别
  function AddKeyValues(const AKeys, AValues: array of string): IConfigBuilder;
  function SetInterpolationMode(AMode: TConfigInterpolationMode): IConfigBuilder;
  function RequireKeys(const AKeys: array of string): IConfigBuilder;
  function Build: IConfig;           // 只读快照，owned
  function BuildConfig: TConfig;     // 可变，调用方 Free
  function TryBuild(out AConfig: IConfig; out AError: string): Boolean;
end;

function ConfigBuilder: IConfigBuilder;
function ConfigLoad(const APath: string; AFormat: TConfigFormat): IConfig; overload;
function ConfigLoad(const APath: string): IConfig; overload; // 扩展名 + 内容嗅探
function ConfigBorrow(AConfig: TConfig): IConfig; // 非拥有 IConfig 视图
function ConfigSection(const AConfig: IConfig; const APrefix: string): IConfig; // viper Sub
function ConfigSection(AConfig: TConfig; const APrefix: string): IConfig; overload;
function TryDetectConfigFormat(const APath: string; out AFormat: TConfigFormat): Boolean;
function TrySniffConfigFormat(const AContent: string; out AFormat: TConfigFormat): Boolean;
function TryParseConfigDurationNs(const AText: string; out ANanos: Int64): Boolean;
function TryParseConfigByteSize(const AText: string; out ABytes: Int64): Boolean;
```

`ConfigSection`：非拥有前缀视图；`GetString('host')` ≡ parent `prefix.host`；`To*` export 抛 `EConfigError`。
`GetDurationNs` / `GetDurationNsRequired`：后缀 `ns|us|ms|s|m|h`；裸整数按秒。
`GetByteSize` / `GetByteSizeRequired`：`b|kb|kib|mb|mib|gb|gib`（1024 进制）；裸整数=字节。

`AddKeyValues` 按链顺序应用；不依赖 `args`。长度不等或空 key 在 **Add 时** 立即 `EConfigError`。

扩展名映射（大小写不敏感）：`.ini`→`cfIni`，`.json`→`cfJson`，`.yaml`/`.yml`→`cfYaml`，`.toml`→`cfToml`。

**无格式路径**（`AddFile(path)` / `ConfigLoad(path)` / `LoadFromFile` / `TryLoadFromFile`）：

1. 扩展名命中 → 按扩展加载
2. 扩展加载失败或无/未知扩展 → `TrySniffConfigFormat`（试解析：JSON 对象/数组 → TOML → YAML map/seq → INI 含 `=`）
3. 仍失败 → 诊断错误（含 path / sniff）

**显式格式路径**（`AddFile(path, format)` / `TryLoadFromFile(path, format)` / watcher 重载）**严格按指定格式**：解析失败即失败，**不做**内容嗅探降级。理由：热重载撕裂写场景下，截断的 TOML（如 `key = `）会被嗅探成合法 INI 而静默替换活配置。

### 2.4 可变 `TConfig`（摘要）

- 加载：`LoadFromIni/Json/Yaml/Toml/File/Env` + `TryLoad*` / `TryLoadJson|Yaml|Toml` 别名；`LoadFromFile`/`TryLoadFromFile` 支持显式格式或扩展名自动识别
- 写入：`SetString/Int/Bool/Float/StringArray`、`SetDefault`、`DeleteKey`、`DeleteSection`、`Clear`、`ReplaceFrom`
- 拷贝/合并：`Clone`（调用方 Free）、`MergeFrom(TConfig|IConfig)`（后写覆盖）
- 诊断：`DebugDump` / `ConfigDebugDump`（排序 `key=rawValue` 行）
- 导出：`ToIni/Json/Yaml/Toml`、`SaveTo*`
- 读取：与 `IConfig` 对称的 Get*/TryGet*/Require/Has/GetKeys/GetSection + DurationNs/ByteSize
- 插值：`SetInterpolationMode` / `GetInterpolationMode`

### 2.5 Watcher

```pascal
TConfigWatcher = class
  constructor Create(AConfig: TConfig; const AFilePath: string; AFormat: TConfigFormat); overload;
  constructor Create(AConfig: TConfig; const AFilePath: string); overload; // 扩展+嗅探
  function CheckReload: Boolean;
  property OnReload: TConfigReloadEvent;
end;
```

使用 watcher 时显式 `uses nextpas.core.config.watcher`。

---

## 3. 存储模型与优先级

### 3.1 存储

- **扁平**、**大小写不敏感** 的 dot-path KV 表（.NET `IConfiguration` 取向）
- 嵌套对象/表 → `server.host`
- 数组/序列 → `tags.0`、`servers.0.host`（**规范数组下标**）
- 值一律以 string 存；类型 getter 做解析

### 3.2 Builder 优先级

1. `AddDefault` 始终最低，与在链中的位置无关
2. 其余 source 按 **添加顺序** 应用
3. 后写覆盖先写
4. `AddEnv` 只是普通 source；要最高优先就放到最后

### 3.3 插值

- Getter-time 插值（`${key}`），由 `TConfigInterpolationMode` 控制：
  - `cimDefault`：可选 getter 保留未解析 `${x}`；Required 对未解析失败
  - `cimStrict`：所有解析 getter 对未解析失败
  - `cimDisabled`：不展开；`GetString` 行为接近 raw
- `GetRawString` / `GetRawStringArray` 永不插值
- 循环依赖 → 始终 `EConfigError`（与 mode 无关）
- Builder：`SetInterpolationMode`；`IConfig.GetInterpolationMode` 可读

---

## 4. 错误与失败契约

| 路径 | 行为 |
|------|------|
| `LoadFrom*` | 解析/加载失败抛 `EConfigError`（带格式诊断） |
| `TryLoad*` / `TryBuild` | `False` + error string，不抛 config-domain 失败 |
| `Get*Required` / `Require` | 缺失/空/类型错 → `EConfigError` |
| 可选 `Get*` | 默认值，不抛 |
| Export representability | 无法忠实表示的 INI/结构 → 抛错，不静默损坏 |

---

## 5. Lifetime / 线程

- `IConfig`（Build）：owned 只读快照，引用计数
- `BuildConfig` / `TConfig.Create`：调用方 `Free`
- `TConfig` 内部 `IRWLock`：读可并发，写互斥；加载过程非「无锁可重入」
- `TConfigWatcher` 拥有路径与格式；不拥有 `TConfig` 所有权（由外部保证 config 寿命）

---

## 6. 不变量

- **[INV-1]** 键非空；层次路径校验（空段等拒绝）
- **[INV-2]** 格式加载走真实 DOM 模块 + `flatten`，禁止手写行解析 JSON/YAML/TOML
- **[INV-3]** 数组索引规范（canonical indexes）
- **[INV-4]** 多源合并后仍是一张扁平表
- **[INV-5]** YAML：`LoadFromYaml` 只展平 `IYamlDocument.Root`；底层 parser **拒绝多文档**
  （第二个 `---` → 解析错误，不静默合并多根）

---

## 7. 依赖边界

| 依赖 | 用途 |
|------|------|
| `ini` / `json` / `yaml` / `toml` | 解析与 export 底层 |
| `os.env` | 环境变量 |
| `platform.watch` | 热加载 |
| `sync` | RWLock |
| `text.conv` | 数字/布尔文本 |

禁止：在 config 内重新实现 JSON/YAML/TOML 解析器。

---

## 8. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.config/test_config_facade_surface
make focused FOCUS=core/tests/nextpas.core.config/test_config_phase3
make focused FOCUS=core/tests/nextpas.core.config/test_config_export
```

套件含：core、env windows contract、examples、export、mutation、nested、format contracts、ini/toml/yaml export、phase3、facade_surface。

示例：`core/examples/nextpas.core.config/`（startup / export / mutation）。

---

## 9. Out of scope / Future

| 项 | 状态 |
|----|------|
| `AddKeyValues` 浅 CLI/map 注入 | **已实现**（不依赖 `args`） |
| typed bind `ConfigUnmarshal` | **已实现**于 `nextpas.core.reflect.marshal`（`IConfig`/`TConfig` + section prefix） |
| 嵌套 record 递归 bind | **已实现**（`AddRecordField` + `VisitRecord`，字段名叠进 prefix） |
| string dynarray bind | **已实现**（`AddDynArrayField` + `GetStringArray`） |
| CLI 浅桥 `config.args` | **已实现**（`ConfigBuilderAddPresentArgs` + 显式 kind 映射） |
| 插值 mode | **已实现**（`cimDefault` / `cimStrict` / `cimDisabled`） |
| borrowed `IConfig` | **已实现**（`ConfigBorrow`，非拥有视图） |
| 扩展名自动识别 | **已实现**（`TryDetectConfigFormat`） |
| 内容嗅探（无/错扩展） | **已实现**（`TrySniffConfigFormat` + 无格式加载路径） |
| Builder 内硬 `uses args` | Out of scope（浅桥独立单元） |
| XML/CSV 作为 `TConfigFormat` | Out of scope |
| `config.cli` 独立单元名 | 不采用；用 `AddKeyValues` |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始（含虚构子模块，已废止） | — |
| 2026-07-20 | 2.0 | 对齐 6 单元真实 API 与 Builder 优先级 | config-formats lane |
| 2026-07-20 | 2.1 | `AddKeyValues` 浅覆盖源 | config-formats lane |
| 2026-07-20 | 2.2 | 插值 mode / ConfigBorrow 契约对齐；扩展名自动识别 | config-formats lane |
| 2026-07-20 | 2.3 | 内容嗅探 `TrySniffConfigFormat`；错扩展恢复 | config-formats lane |
| 2026-07-26 | 2.4 | 显式格式路径收紧为严格（去嗅探降级）；无格式路径嗅探不变 | hotfix |
