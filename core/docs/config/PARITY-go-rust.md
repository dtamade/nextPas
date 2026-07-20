# config × Go / Rust 对标（Wave I）

**状态日期**：2026-07-20
**范围**：`nextpas.core.config`（+ `config.args` / reflect bind）
**标杆**：Go `spf13/viper` / `koanf`；Rust `config-rs` / `figment`；.NET `IConfiguration`（存储模型）

> 对标的是**多源合并、插值、类型读取、可诊断失败**，不是符号名复制。

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.2** | Sub、DurationNs、ByteSize、watcher auto |
| **规模 Scale** | **9.1** | 四格式 + env + keyvalues + args + bind + Sub |
| **综合** | **9.1** | 对齐 viper 常用 DX；remote 仍 Future |

**目标线**：质量 ≥ 9.0；规模 Essential ≥ 0.85。
**证据**：[`SCORECARD.md`](./SCORECARD.md)

---

## Essential 矩阵

| 能力 | Go/Rust 标杆 | nextpas | 状态 |
|------|--------------|---------|------|
| 多源 builder | viper/koanf merge | `ConfigBuilder` 顺序覆盖 | Done |
| 默认值 | SetDefault | `AddDefault`（始终最低） | Done |
| 文件加载 | ReadInConfig | `AddFile` / `ConfigLoad` | Done |
| 扩展名自动识别 | viper 扩展映射 | `TryDetectConfigFormat` + 无格式重载 | Done |
| 内容嗅探 | 部分库有 | `TrySniffConfigFormat`（结构根 + 试解析） | Done |
| Env 前缀 | AutomaticEnv | `AddEnv(prefix)` | Done |
| CLI 注入 | pflag/bind | `AddKeyValues` + `config.args` | Done |
| 类型 getter | GetInt/Bool | GetInt/Bool/Float + Required | Done |
| 插值 | ${} / expand | `cimDefault/Strict/Disabled` | Done |
| 只读快照 | — | `IConfig` Build / `ConfigBorrow` | Done |
| 热加载 | WatchConfig | `TConfigWatcher` | Done |
| 导出 | WriteConfig | ToIni/Json/Yaml/Toml + representability | Done |
| 结构体 bind | Unmarshal | `ConfigUnmarshal` (reflect.marshal) | Done |
| 嵌套/数组 bind | mapstructure | 嵌套 record + string dynarray | Done |
| Sub 子树视图 | Sub() | `ConfigSection` | Done |
| GetDuration | GetDuration | `GetDurationNs` 最小后缀 | Done |
| 人可读大小 | — | `GetByteSize` (KiB 进制) | Done |
| Watch 自动格式 | — | `TConfigWatcher.Create(path)` auto | Done |
| XML/CSV 作 config 格式 | 少见 | Out of scope | Deferred |

---

## 本轮关闭

| 项 | 结论 |
|----|------|
| 扩展名 auto-detect | **Done** — `.ini/.json/.yaml/.yml/.toml`（Wave I） |
| CONTRACT §3.3 与 mode 实现漂移 | **已修**（Wave I） |
| 内容嗅探 / 错扩展恢复 | **Done**（Wave J） |
| SCORECARD | **Done**（Wave J） |
| ConfigSection / DurationNs | **Done**（Wave K） |
| remote source | 仍 Future |

---

## 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.config/test_config_facade_surface
make focused FOCUS=core/tests/nextpas.core.config/test_config_phase3
```
