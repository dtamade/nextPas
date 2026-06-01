# Config 模块 — 加载器修复（DOM 递归展平）

## 修正后的背景（关键）

初读 config 为 419 行旧版，规划"完整重建"。Codex 审查发现实际 main 已是 **673 行**：
同事提交 `20e504ce feat(config,reflect): hot-reload + struct mapping` 已合并，新增了
**线程安全(IRWLock) + 热加载(TConfigWatcher) + ReplaceFrom + struct mapping**，测试 33→**35**。

→ 原"完整重建"方案是**破坏性的**，已废弃。改为**最小侵入、非破坏性**的外科手术。

## 真实问题（同事未修，仍是硬伤）

| 缺陷 | main 673 行现状 |
|------|------|
| `LoadFromJson` 不递归 | 只遍历顶层 object，`{"server":{"host":"x"}}` 静默丢 `server.host` |
| `LoadFromYaml` 手写行解析 | 无视 `yaml`(63测试) DOM，嵌套/序列/多行全废 |
| `LoadFromToml` 手写行解析 | 无视 `toml`(277测试) DOM，内联表/数组/dotted key 全废 |

## 方案：只替换 3 个加载器的解析逻辑为 DOM 递归展平

**完整保留**：IRWLock 锁、TConfigWatcher、ReplaceFrom、struct mapping、全部 35 测试、
错误契约（解析失败静默 Exit，不改契约以免惊扰同事代码）、扁平 dot-path 模型、公共 API。

**只改**：3 个 `LoadFromXxx` 的内部解析 → 调用 `nextpas.core.{json,yaml,toml}` DOM，
递归展平成扁平 dot-path：
- 嵌套对象/表 → `server.host`、`db.pool.size`
- 数组/序列 → `tags.0`、`tags.1`、`servers.0.host`（.NET IConfiguration 模型）
- 标量忠实渲染：int→IntToStr，float→FloatToStr，bool→'true'/'false'，null→''，
  TOML datetime→ISO8601

**新增私有方法**（additive，不改公共 API）：`FlattenJsonNode/FlattenYamlNode/FlattenTomlNode`
+ 单元级 helper：`RenderJsonScalar/RenderYamlScalar/RenderTomlScalar/TomlDateTimeToStr`。

**安全要点**：递归用 while 循环 + UInt32 计数（避免空容器 `Len-1` 下溢的经典 bug）。

## 向后兼容验证（35 测试）

现有输入全是扁平结构 → 递归展平对它们是恒等变换。逐项核对：
- `{"server.host":"json_host"}`（字面 key 含点）→ 顶层标量 → `server.host` ✓
- YAML `port: 8080` → DOM ynkInt → "8080" → GetInt=8080 ✓
- TOML `[server]\nport=8080` → 展平 `server.port="8080"` ✓
- ReplaceFrom/Watcher/锁：零改动 ✓

## 测试计划（保留 35 + 新增覆盖新能力）

新增独立测试项目验证：嵌套 JSON/YAML/TOML 展平、数组展平、深层嵌套对象数组、
空容器边界、标量类型忠实渲染。目标 0 泄漏（heaptrc）。

## 不在本轮（Phase 2，单独 PR，避免破坏协作）

GetStringArray/GetSection 便利 getter、IConfig/Builder fluent、EConfigError 显式错误 +
TryLoad、占位符插值 ${VAR}、必填校验。这些是增量特性，不属于"修复坏加载器"。

## 落地结果（已完成）

- 改动：`src/nextpas.core.config.pas` +224/-111；只动 implementation uses + 3 个 LoadFromXxx
  + 新增单元级 helper。同事的 IRWLock/TConfigWatcher/ReplaceFrom/struct mapping 零改动。
- 测试：原 35 测试全绿 + 新增 `test_config_nested`（20 测试）全绿，两套均 0 内存泄漏（heaptrc）。
- 顺带利好：`TConfigWatcher.DoReload` 调 LoadFromYaml/Toml，热加载也从手写行解析升级为 DOM，
  之前嵌套配置热加载是坏的，现已修正。

## Codex 审查结论（已采纳）

通过：递归展平、空容器下溢防护、锁顺序（解析在写锁外、写入在写锁内）、value record 生命周期、
TomlDateTimeToStr 的 ISO8601（offset/nanosecond 全路径正确）、FloatToStr locale 无关 roundtrip。
采纳改进：顶层 object/array 去重为 `FlattenXxxNode(Self, '', LRoot)`（少 ~40 行，顺带支持顶层数组）；
补注释说明扁平模型 key 歧义与递归深度约束。

## 明确待办（Phase 2，本轮未做，避免误以为已完成）

- **解析失败仍静默**（`if HasError then Exit`）：v2 设计目标 #6 的 EConfigError + TryLoadXxx
  变体留待下一轮。这是距离"领域最优"最大的未竟项。
- float NaN/Inf 不支持往返（FloatToStr 渲染为 "Nan"/"Inf"）——config 场景基本无害，已知限制。
- GetStringArray/GetSection、IConfig/Builder fluent、${VAR} 插值、必填校验。

## Phase 2 状态更新（2026-06-02）

上述 Phase 2 待办中的 config v2 API 已在后续批次完成：

- `LoadFromJson` / `LoadFromYaml` / `LoadFromToml` 解析失败抛 `EConfigError`，
  `TryLoadJson` / `TryLoadYaml` / `TryLoadToml` 与兼容的 `TryLoadFromXxx`
  变体返回 `Boolean` 和错误文本。
- `GetSection` 与 `GetStringArray` 已覆盖扁平 dot-path 子段和标量数组重组。
- `${...}` 插值已接入 `GetString`、类型 getter、默认字符串和 `GetStringArray`；
  配置 key 优先，其次环境变量，`$${...}` 转义，未解析占位符在普通读取中保留。
- `GetStringRequired` / `GetIntRequired` / `GetBoolRequired` /
  `GetFloatRequired` / `Require` 已完成。required API 会对缺失、空白、
  未解析占位符和非法类型抛 `EConfigError`。
- `TConfigWatcher` 在 JSON/YAML/TOML 坏 reload 时传播 `EConfigError`，
  并保留旧配置。

仍不在 Phase 2 范围：IConfig/Builder fluent、基准对照、单元拆分。
