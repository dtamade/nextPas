# Config 模块 Phase 3 — 接口边界与构建器设计

## 目标

Phase 2 已经让 `nextpas.core.config` 具备生产可用的加载、错误、数组、section、required 和插值能力。Phase 3 的目标不是重写配置存储，而是补齐更适合大型应用和框架内部消费的组合层：

- 增加只读 `IConfig` 边界，让 HTTP、TLS、app 等模块可以依赖配置契约，而不是依赖可变 `TConfig` 实现。
- 增加 fluent builder/source pipeline，让多源配置的加载顺序、默认值、文件读取、env 覆盖和 required 校验成为一个清晰启动流程。
- 明确 source priority：默认值最低，显式 source 按添加顺序加载，后加载覆盖先加载，env 只是一个 source，是否最高由调用方把它放到最后决定。
- 给插值策略留出 API 位置，但不改变 Phase 2 的默认 getter-time 严格插值语义。
- 保持 `TConfig`、`TConfigWatcher`、`ReplaceFrom`、struct mapping 兼容，不破坏已通过的 87 个 config 测试。

## 当前基线

- seed branch: `codex/config-phase3-main-20260602`
- current main base when seeded: `9ee09c80 feat(compiler): C4C add typed signedness emission`
- latest config landing on main: `d5013326 merge: config phase2 api contract`
- public unit: `nextpas.core.config`
- current config tests: 95 tests, heaptrc 0 leaks
- current storage model: flat, case-insensitive dot-path KV

## 2026-06-02 首批落地状态

已完成本轮首批闭环：

- Phase 3A：`IConfig` 只读边界已落地，覆盖当前 `TConfig` 全部只读能力。
- Phase 3B：`IConfigBuilder` + `ConfigBuilder` 已落地，支持 default / in-memory source / env / required / `Build` / `BuildConfig` / `TryBuild`。
- Phase 3C：`AddFile` + `ConfigLoad` 已落地，文件加载失败带路径上下文。

本轮刻意不做：

- borrowed `IConfig` adapter
- interpolation mode 扩展（继续保持现有 getter-time 严格插值）
- `nextpas.core.config` 拆分重构

本轮新增 focused suite：

- `tests/nextpas.core.config/test_config_phase3`

当前 config 测试基线已变为：

- `58` existing config tests
- `29` nested/DOM flatten tests
- `8` Phase 3 builder/interface/file-source tests
- 合计 `95` tests，heaptrc `0` leaks

## 非目标

- 不改成树形配置对象。
- 不改变 `LoadFromIni/Json/Yaml/Toml/Env` 的覆盖规则。
- 不改变 `GetString` 默认插值行为。
- 不在本轮做性能 benchmark；benchmark 等 API 稳定后单独进行。
- 不为了“纯门面”一次性拆散整个 `nextpas.core.config.pas`。该文件已经超过 800 行，后续应拆分，但 Phase 3 先保护行为稳定。

## 设计选项

### 选项 A：保守 additive 层（推荐）

保留 `TConfig` 为唯一可变实现，新增只读 `IConfig` 和 builder。builder 内部使用 `TConfig`，最终可以返回拥有生命周期的 `IConfig`，也可以返回调用方手动释放的 `TConfig`。

优点：
- 对现有调用方零破坏。
- 不干扰 `IRWLock`、watcher、`ReplaceFrom` 和 struct mapping。
- 新模块可以先依赖 `IConfig`，逐步减少对可变实现的耦合。
- 测试面清晰，适合 TDD 小步落地。

缺点：
- `nextpas.core.config.pas` 短期继续偏大。
- `IConfig` 与 `TConfig` 之间需要一个生命周期安全的包装策略。

### 选项 B：立即拆分为 facade/base/intf/builder/impl

把 `TConfigFormat`、`TStringArray`、`EConfigError`、`IConfig`、builder 和实现全部拆到标准四件套。

优点：
- 更贴近设计规范的理想结构。
- 后续模块边界更清楚。

缺点：
- 改动面大，容易碰到同事已有 work 的边界。
- 需要迁移大量实现和测试，合并风险高。
- Phase 3 的核心价值会被结构迁移噪音稀释。

### 选项 C：只加文件加载 helper，不加 `IConfig`

只补 `LoadFromFile/TryLoadFromFile` 和几个 builder-like 函数。

优点：
- 最小改动，最快落地。

缺点：
- 不能解决跨模块依赖可变 `TConfig` 的长期问题。
- 不能形成领域最优框架需要的启动配置 pipeline。

推荐选项 A。它把公共契约、构建流程和兼容性放在第一位，把大规模文件拆分留到行为稳定后的专门重构轮。

## Public API 草案

### 只读配置接口

`IConfig` 只暴露读取能力，不暴露 `LoadFromXxx`、`SetDefault`、`ReplaceFrom` 或 watcher。这样依赖方不能意外修改全局配置。

```pascal
type
  IConfig = interface
    ['{7F5F1A22-8C52-44C8-9E38-9CF5C3F2C101}']
    function GetCount: Integer;
    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetRawString(const AKey: string; const ADefault: string = ''): string;
    function GetStringArray(const AKey: string): TStringArray;
    function GetRawStringArray(const AKey: string): TStringArray;
    function GetStringRequired(const AKey: string): string;
    function GetInt(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetIntRequired(const AKey: string): Int64;
    function GetBool(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetBoolRequired(const AKey: string): Boolean;
    function GetFloat(const AKey: string; ADefault: Double = 0.0): Double;
    function GetFloatRequired(const AKey: string): Double;
    procedure Require(const AKeys: array of string);
    function Has(const AKey: string): Boolean;
    function GetSection(const APrefix: string): TStringArray;
    function GetKeys: TStringArray;
    property Count: Integer read GetCount;
  end;
```

生命周期原则：
- `TConfig` 保持 manual Free，不改为 ref-counted class。
- builder 返回的 `IConfig` 必须拥有内部 `TConfig`，调用方不需要 Free。
- 现有 `TConfig` 转 `IConfig` 的 borrowed adapter 暂不进入 Phase 3 首批实现。原因是它会把
  `TConfig` 的 manual lifetime 泄漏到 interface 调用方，很容易制造悬垂引用。
- 如果后续确实有 watcher/live config consumer 需要 borrowed view，只允许以显式危险命名公开：
  `ConfigBorrowedView(AConfig: TConfig): IConfig`。该函数不得取得所有权，必须要求源 `TConfig`
  存活时间覆盖返回的 `IConfig` 使用期，并在 `AConfig = nil` 时抛 `EConfigError`。
- borrowed view 的测试边界必须锁定三点：读取代理到源 `TConfig`；源变更后 view 反映最新值；
  view 释放不释放源 `TConfig`。源提前释放后的行为不定义，不写“支持”测试。

### 插值模式

Phase 2 的默认行为是 getter-time 严格插值：`${KEY}` 先查 config，再查 env；未解析、空占位符、未闭合和循环都抛 `EConfigError`。

Phase 3 不改变默认行为。以下枚举只是 future draft，用于约束后续设计方向；它还不是当前公开 API：

```pascal
type
  TConfigInterpolationMode = (
    cimReadTime,   // 默认：现有 getter-time 严格插值
    cimDisabled    // 读取原始值，不展开 ${...}
  );
```

实现顺序：
- Phase 3A/3B/3C 已保持 `cimReadTime` 默认和现有 `TConfig` getter 行为。
- Phase 3D1 已先落显式 raw-read API，把“不插值读取”作为可测试的独立能力，而不是先引入全局模式。
- `GetRawString` / `GetRawStringArray` 已加入 `TConfig` 与 `IConfig`。它们只返回扁平存储中的原始值，
  不展开 `${...}`，默认值也不展开。`GetSection` / `GetKeys` 天然不涉及插值，不需要 raw 变体。
- 暂不新增 `GetRawStringRequired`。required 语义仍属于现有插值 getter；raw required 若有真实需求，
  后续单独设计，避免把“原始文本存在”与“业务配置有效”混在一起。
- 只有 raw-read API 的测试稳定后，才允许评估 `TConfigInterpolationMode` / `WithInterpolation`。
  如果最终引入 mode，必须明确它是否影响 `BuildConfig` 返回的 mutable `TConfig`；不得让同一 builder 的
  `Build` 与 `BuildConfig` 在插值策略上出现隐式分叉。

### Builder 接口

builder 用 interface 生命周期，调用方链式调用后 `Build`：

```pascal
type
  IConfigBuilder = interface
    ['{B1C9DA74-337C-40D7-9703-029BD7D7E201}']
    function AddDefault(const AKey, AValue: string): IConfigBuilder;
    function AddIni(const AContent: string): IConfigBuilder;
    function AddJson(const AContent: string): IConfigBuilder;
    function AddYaml(const AContent: string): IConfigBuilder;
    function AddToml(const AContent: string): IConfigBuilder;
    function AddEnv(const APrefix: string): IConfigBuilder;
    function AddFile(const APath: string; AFormat: TConfigFormat): IConfigBuilder;
    function RequireKeys(const AKeys: array of string): IConfigBuilder;
    function Build: IConfig;
    function BuildConfig: TConfig;
    function TryBuild(out AConfig: IConfig; out AError: string): Boolean;
  end;

function ConfigBuilder: IConfigBuilder;
function ConfigLoad(const APath: string; AFormat: TConfigFormat): IConfig;
```

Naming notes:
- `AddXxx` is used because a builder can hold multiple sources of the same kind.
- `Build` returns read-only `IConfig` with automatic lifetime.
- `BuildConfig` returns mutable `TConfig`; caller owns and must `Free`.
- `TryBuild` catches `EConfigError` and file/config loading errors that are part of expected config loading. It must not swallow unrelated runtime/programming errors unless they are already surfaced as `EConfigError`.

Builder instances are reusable. Each `Build`, `BuildConfig`, or `TryBuild` call must replay the recorded source plan into a fresh `TConfig` instance.

Ownership rules:
- `Build` creates a fresh `TConfig`, transfers ownership to an internal owned `IConfig` wrapper, and returns that wrapper.
- `BuildConfig` creates a fresh `TConfig` and transfers ownership completely to the caller. The builder must not retain, free, or reuse that returned instance.
- `TryBuild` follows the same ownership rule as `Build` on success. On failure it returns `False`, sets `AConfig := nil`, and leaves no partially built config visible to the caller.

### Source priority

Builder applies sources in this order:

1. All defaults collected through `AddDefault`.
2. Explicit sources in the order they were added.
3. Required validation after all sources load.

This means defaults are always lowest priority, independent of where `AddDefault` appears in the chain. Example:

```pascal
Cfg := ConfigBuilder
  .AddDefault('host', '127.0.0.1')
  .AddFile('app.toml', cfToml)
  .AddFile('local.toml', cfToml)
  .AddEnv('APP_')
  .RequireKeys(['host'])
  .Build;
```

If `APP_HOST` should not be highest priority, the caller simply adds `AddEnv` earlier. The builder does not give env implicit magic priority. Environment keys keep the Phase 2 behavior: the prefix is stripped, the remaining name is lowercased, and underscores are preserved.

Within the default group, later `AddDefault` calls for the same key override earlier defaults. `RequireKeys` calls are cumulative and run after all defaults and explicit sources have been applied.

Implementation note: this default-group behavior is intentionally different from `TConfig.SetDefault`, which writes only when the key is missing. The builder must first merge defaults into an internal list, keeping the last value for each key, and then apply that merged list to the fresh config before explicit sources. It must not implement defaults by replaying every `AddDefault` call through `SetDefault` in call order.

### File loading

`AddFile(APath, AFormat)` reads text through `nextpas.core.fs.ReadFileText` and dispatches to the matching `LoadFromXxx`.

Error semantics:
- missing/unreadable file raises `EConfigError` with context `config file load error: <path>`.
- unsupported `cfUnknown` raises `EConfigError`.
- malformed content preserves the partially built config state internally but `Build` fails and returns no config.
- `TryBuild` reports the error string and returns `False`.

### Watcher integration

`TConfigWatcher` remains class-based and targets mutable `TConfig`. Phase 3 does not force watcher into `IConfig`.

Recommended app pattern:

```pascal
Live := ConfigBuilder
  .AddFile('app.toml', cfToml)
  .AddEnv('APP_')
  .BuildConfig;

Watcher := TConfigWatcher.Create(Live, 'app.toml', cfToml);
```

If a module only needs reads, the application can expose an `IConfig` built from a stable snapshot. Live hot reload plus `IConfig` can be designed later as `IConfigProvider` if actual consumers need it.

## Implementation Phases

### Phase 3A: `IConfig` read boundary

- Add `IConfig`.
- Add owned wrapper that delegates to an internal `TConfig`.
- Add builder `Build` returning owned `IConfig`.
- Do not change existing `TConfig` lifetime.

Tests:
- `Build` returns readable `IConfig`.
- returned `IConfig` remains valid after builder interface goes out of scope.
- `IConfig` exposes arrays, sections, required getters, and count.
- no mutation methods exist on the interface surface.

### Phase 3B: Builder source pipeline

- Add `IConfigBuilder` and `ConfigBuilder`.
- Add `AddDefault`, `AddIni`, `AddJson`, `AddYaml`, `AddToml`, `AddEnv`.
- Add `RequireKeys`.
- Add `BuildConfig` for callers that need watcher or manual mutation.
- Add `TryBuild`.

Tests:
- defaults are lowest priority even if configured after sources.
- repeated `AddDefault` for the same key uses the last default value before explicit sources load.
- source order is stable: later explicit source overrides earlier explicit source.
- env priority is order-dependent, not implicit.
- `RequireKeys` runs after all sources.
- `Build`, `BuildConfig`, and `TryBuild` each create independent config instances; freeing or mutating one result does not affect later build results.
- `TryBuild` returns `False`, non-empty error, and nil config on malformed in-memory source or required-key failure.

### Phase 3C: File sources

- Add `AddFile` and `ConfigLoad`.
- Use existing `ReadFileText`.
- Preserve current parser metadata in `EConfigError` where available.

Tests:
- INI/JSON/YAML/TOML files load through builder.
- missing file returns `False` from `TryBuild`.
- unsupported format raises/returns config error.
- malformed file includes path and parser detail.
- `TryBuild` returns `False`, non-empty error, and nil config for missing file, unsupported format, and malformed file.

### Phase 3D: Interpolation mode

- Keep default `cimReadTime`.
- Split this into two future slices:
  - Phase 3D1: explicit raw-read API (`GetRawString` / `GetRawStringArray`) on `TConfig` and `IConfig`.
  - Phase 3D2: optional whole-config interpolation policy only after raw-read behavior is locked.
- Status: Phase 3D1 is complete and covered by focused tests; only Phase 3D2 remains open.
- Do not expose `WithInterpolation` before Phase 3D1 is complete.
- When `WithInterpolation` is introduced, `cimDisabled` must be implemented by raw-read semantics and focused tests,
  or explicitly rejected with `EConfigError` and focused tests.

Do not implement `cimDisabled` by string post-processing after interpolation; raw read must bypass interpolation before placeholder expansion.

Tests for Phase 3D1:
- `GetRawString` returns raw stored values containing `${...}` without expansion.
- `GetRawString` returns raw defaults without expansion.
- `GetRawStringArray` preserves sparse numeric order and returns raw array values.
- Existing `GetString` / `GetStringArray` interpolation tests remain unchanged.
- `IConfig` raw methods delegate to the owned config and remain valid after builder release.

Tests for Phase 3D2, if implemented:
- `WithInterpolation(cimReadTime)` is default-compatible with existing getters.
- `WithInterpolation(cimDisabled)` uses raw-read behavior for string, typed getters, arrays, and required checks.
- `Build` and `BuildConfig` mode semantics are identical, or the API rejects unsupported combinations explicitly.

Design boundary for Phase 3D2:
- Phase 3D2 remains deferred until a concrete consumer needs whole-config disabled interpolation. Phase 3D1 raw-read APIs
  already cover the current "read without expansion" requirement.
- If Phase 3D2 is revived, the only public mode entrypoint in this slice should be
  `IConfigBuilder.WithInterpolation(AMode: TConfigInterpolationMode): IConfigBuilder`.
- `WithInterpolation` must stamp the fresh built `TConfig` instance with one internal mode so that `Build` and `BuildConfig`
  share identical read semantics. The builder must not let `Build` and `BuildConfig` silently diverge.
- Do not add `WithInterpolation` to `IConfig`. That would immediately reopen borrowed/shared view semantics or clone
  semantics, which are intentionally outside the Phase 3 scope.
- Do not add a public mode-switch API to existing direct `TConfig.Create` consumers in Phase 3D2. In this slice, callers
  that create `TConfig` manually keep using explicit raw getters when they need non-interpolated reads.
- `TConfigWatcher` remains compatible because it reloads into the same `TConfig` instance; the instance-level mode chosen at
  build time stays stable across `ReplaceFrom` / reload cycles.

## Module organization

Keep Phase 3A/3B public types in `nextpas.core.config.pas` first. This is intentional:

- `IConfigBuilder.BuildConfig` returns `TConfig`, so extracting `IConfigBuilder` into `nextpas.core.config.intf.pas` before moving `TConfig` would create an awkward type ownership problem.
- `TConfig` is already the tested mutable implementation and should not be moved during the first builder slice.
- The first implementation goal is behavioral API coverage, not a facade refactor.

A later dedicated refactor can split the module once the Phase 3 behavior is stable:

- `nextpas.core.config.base.pas`: `TStringArray`, `TConfigFormat`, `TConfigInterpolationMode`.
- `nextpas.core.config.intf.pas`: `IConfig` and any builder interfaces that no longer need to mention a type declared only in the facade.
- `nextpas.core.config.store.pas` or `nextpas.core.config.impl.pas`: `TConfig` implementation.
- `nextpas.core.config.pas`: facade aliases and inline helpers.

Do not combine that split with the first Phase 3 implementation slice.

## Compatibility

- Existing `TConfig` callers keep compiling.
- Existing short aliases `TryLoadJson/Yaml/Toml` stay.
- Existing canonical `TryLoadFromXxx(... out AError)` stays.
- Existing watcher behavior stays: invalid reload raises `EConfigError`, old config remains.
- `LoadFromEnv` keeps current key behavior: prefix stripped, remaining env var lowercased, underscores preserved.
- Literal dotted keys keep colliding with nested dot paths; later source wins.

## Test and verification gate

Add a new focused suite:

```bash
make -C tests/nextpas.core.config/test_config_phase3 test
```

Keep all existing suites:

```bash
make -C tests/nextpas.core.config/test_config test
make -C tests/nextpas.core.config/test_config_nested test
make -C tests/nextpas.core.config/test_config_phase2 test
```

If builder touches file loading or parser facade surfaces, also run:

```bash
make -C tests/nextpas.core.ini/test_ini test
make -C tests/nextpas.core.json/test_json_facade test
make -C tests/nextpas.core.yaml/test_yaml_facade test
make -C tests/nextpas.core.toml/test_toml_facade test
make -C tests/nextpas.core.xml/test_xml test
```

Completion requires:
- all changed public APIs covered by focused tests;
- all relevant suites pass;
- heaptrc reports `0 unfreed memory blocks`;
- `git diff --check` passes;
- Codex review before commit.

## Open decisions before implementation

已收敛：

1. Borrowed `IConfig` adapter 暂不实现。若后续有真实 consumer，再以 `ConfigBorrowedView` 显式危险命名设计。
2. `cimDisabled` 暂不公开。下一批先实现显式 raw-read API，避免模式 API 先于底层语义。
3. `BuildConfig` 已在首批实现，因为 watcher 仍需要 mutable `TConfig`。
4. Phase 3D2 暂不立刻实现；只有出现真实 consumer 时，才重新开启 whole-config mode。
5. 若 Phase 3D2 重启，mode API 只允许从 builder 进入；不新增 `IConfig.WithInterpolation`、borrowed view 或
   raw required 的同批扩张。

## Recommended next implementation slice

Phase 3 首批闭环、Phase 3D1 raw-read 能力、以及 Phase 3D2 设计边界都已完成。建议下一批遵守以下收敛策略：

1. 保持 `GetRawString` / `GetRawStringArray` 作为明确的 raw-read 基线，不继续追加 raw required 或 borrowed view。
2. 没有真实 consumer 之前，不实现 `WithInterpolation(cimDisabled)`；避免为了"接口完整"提前扩大行为面。
3. 若后续确实需要 whole-config mode，单独开一个实现批次，只做 builder-scope `WithInterpolation` 与 focused tests，
   不与 borrowed view、raw required、module split 混在同一 commit。
