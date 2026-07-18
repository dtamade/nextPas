# nextpas.core.os.env 代码契约

**模块路径**：`core/src/nextpas.core.os.env.pas`（1 个源文件）
**层级**：L2（依赖 L1: text.base; 委托 platform.env）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-19
**版本**：1.3

---

## 1. 接口契约

### 1.1 模块定位

环境变量操作的高层 facade。委托给 `nextpas.core.platform.env` 实现平台无关的环境变量访问。

### 1.2 核心函数

| 函数 | 说明 |
|------|------|
| `EnvironmentVariables: TStringArray` | 返回所有环境变量（NAME=VALUE 格式） |
| `GetEnvironmentVariable(AName): string` | 获取环境变量值 |
| `GetEnv(AName): string` | GetEnvironmentVariable 的简写 |
| `TryGetEnv(AName, AValue): Boolean` | 尝试获取，返回是否成功 |
| `HasEnv(AName): Boolean` | 检查环境变量是否存在 |
| `EnvironmentVariableNamesCaseSensitive: Boolean` | 平台是否区分大小写 |
| `SetEnv(AName, AValue)` | 设置环境变量 |
| `UnsetEnv(AName)` | 删除环境变量 |
| `ExpandEnv(AValue): string` | 展开 `${VAR}` / `$VAR` / `%VAR%` |
| `ExpandEnvWithDefault` / `ExpandEnvStrict` | 默认值 / 严格模式 |
| `UserHomeDir` / `UserCacheDir` / `UserConfigDir` / `UserDataDir` | 用户目录 |

---

## 2. 不变量

- **[INV-1]** 变量名不能为空，不能包含 `=` 或 NUL
- **[INV-2]** 变量值不能包含 NUL
- **[INV-3]** 未定义的变量展开为空字符串（loose）
- **[INV-4]** `$` 后无变量名字符时保留原样 `$`
- **[INV-5]** 未终止的 `${...}` 抛 EArgumentError
- **[INV-6]** `TryGetEnv`/`HasEnv` 区分「存在且为空」与「未定义」；`GetEnv` 两者均 `''`
- **[INV-7]** `%NAME%` 仅匹配非空 `[A-Za-z0-9_]`；不完整 `%` 保留字面量
- **[INV-8]** 本单元与 env 测试不 `uses` FPC RTL；环境访问仅经 `platform.env`

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 变量名为空 | EArgumentError |
| 变量名含 `=` | EArgumentError |
| 变量名/值含 NUL | EArgumentError |
| 未终止的 `${...}` | EArgumentError |
| 平台调用失败 | EIOError |

---

## 4. 线程安全

❌ 非线程安全（与 C 标准库 getenv/setenv 一致）。多线程环境下调用方需自行加锁。

---

## 5. 内存管理

- EnvironmentVariables 返回新 TStringArray，调用方负责释放
- GetEnv/TryGetEnv 返回新 string，调用方负责释放
- 无全局缓存

---

## 6. 测试覆盖

**最后校准：2026-07-19**（以 `make -C core/tests/nextpas.core.os.env/test_os_env test` 输出为准）。

| 测试文件 | 参考通过数 | 说明 |
|----------|-----------|------|
| test_os_env | 36 | Get/Set/Unset/Expand/%VAR%/XDG/User*Dir |
| **合计** | **1 个测试目录** | heaptrc 0 leak |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-11 | 1.0 | 初始版本 | Claude |
| 2026-07-19 | 1.1 | 测试数口径校准（含 XDG） | Claude |
| 2026-07-19 | 1.2 | UserDataDir + %VAR%；INV-6/7；测试 36 | Claude |
| 2026-07-19 | 1.3 | INV-8 FPC RTL 隔离 | Claude |
