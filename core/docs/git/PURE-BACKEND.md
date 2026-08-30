# nextpas.core.git 纯 Pascal 后端契约（PURE-BACKEND）

**模块**：`nextpas.core.git.*`
**层级**：L2
**北极星**：`NewGitManager(gbNative)` 或 `uses nextpas.core.git.native.manager` 时，编译期与运行期彻底不依赖 `libgit2`（无 `dlopen`、无 `-lgit2`、无 `libgit2.so`、产物体积不含 libgit2 声明）。
**状态**：Phase 0 契约冻结（gbAuto 首版 = gbLibGit2，见 §3 迁移公告）
**关联**：`CONTRACT.md` §1.1 / `native-reference-map.md` / `scripts/git-contract-check.sh` C4

---

## 1. 依赖图

### 1.1 重构后目标图

```
nextpas.core.git.base (TGitStatusEntry 等)
        ↑
nextpas.core.git.intf (IGitManager / IGitRepository / IGitCommit)
   ↑                    ↑
   |                    |
native.manager      libgit2.manager
   ↑                    ↑
   |                    |
native.*              libgit2.ffi / binding / backend / bindings
 (repo/status/refs/    (dlopen/dlsym + external 'c')
  log/revwalk/...)
        \                /
         \              /
      nextpas.core.git.factory (TGitBackend, NewGitManager)
                ↑
      nextpas.core.git (聚合门面，re-export base/intf 类型 + inline NewGitManager → factory)
```

### 1.2 路径说明

- **纯路径**：`factory(gbNative)` → `native.manager` → `native.*` → 零 `libgit2`。
  仅 `uses intf + native.base/repo/refs/status/objmodel/...`，禁止出现 `nextpas.core.git.libgit2`。
- **兼容路径**：`factory(gbAuto)` 首版 → `libgit2.manager` → 现有行为不变；
  存量 `uses nextpas.core.git; NewGitManager;` 零改动，仍走 `dlopen`。
- **归一原则**：依赖隔离在单元级（`uses` 图），FPC 通过编译图决定链接，不用 `{$IFDEF}` 分叉。
- **唯一汇聚点**：`factory` 是唯一同时依赖 `native.manager` 与 `libgit2.manager` 的单元；
  其余单元不得跨轨。
- **枚举锚点**：后端选择由 `TGitBackend = (gbNative, gbLibGit2, gbAuto)` 驱动，定义于 `nextpas.core.git.factory`，首版 `gbAuto=gbLibGit2`，语义详见 §4。

### 1.3 允许 / 禁止

| 单元 | 允许 `uses` | 禁止 `uses` |
|------|-------------|-------------|
| `git.native.manager` | `git.intf`, `git.native.*` | `git.libgit2*`, `git.factory` |
| `git.native.repository` | `git.intf`, `git.native.*` | `git.libgit2*` |
| `git.libgit2.manager` | `git.intf`, `git.libgit2.ffi/binding/backend` | `git.native.*`（除 `base` 的 `EGitError` 收敛外） |
| `git.factory` | `git.base`, `git.intf`, `git.native.manager`, `git.libgit2.manager` | —（唯一跨轨） |
| `git.pas` 门面 | `git.base`, `git.intf`, `git.factory` | `git.libgit2*`, `git.native.*` 直引 |

---

## 2. 选择矩阵

| uses 场景 | 后端参数 | 实际后端 | 是否含 libgit2（编译图 / 运行时 dlopen / 产物符号） |
|-----------|----------|----------|------------------------------------------------------|
| `uses nextpas.core.git; NewGitManager;` | `gbAuto`（默认） | `gbLibGit2`（首版） | 是 / 是（`dlopen libgit2.so`）/ 是（`git_*` 符号） |
| `uses nextpas.core.git.factory; NewGitManager(gbNative);` | `gbNative` | `gbNative` | 否 / 否 / 否 |
| `uses nextpas.core.git.factory; NewGitManager(gbLibGit2);` | `gbLibGit2` | `gbLibGit2` | 是 / 是 / 是 |
| `uses nextpas.core.git.factory; NewGitManager(gbAuto);` | `gbAuto` | `gbLibGit2`（首版）→ 下版本 `gbNative` | 首版是 / 首版是 / 首版是；下版本否 |
| `uses nextpas.core.git.native.manager; TNativeGitManager.Create;` | —（直连） | `gbNative` | 否 / 否 / 否 |
| `uses nextpas.core.git;` 但不调用 `NewGitManager`（仅类型） | — | — | 取决于门面实现：重构后门面仅 `uses factory`，类型 re-export 不拉 libgit2；若门面仍硬 `uses libgit2` 则仍含（Phase 2 消除） |

> 判定标准：`fpc -va` 的 `Loading` 行出现 `libgit2` 即视为编译图污染；
`nm -D build/bin/<pure>` 含 `git_` 视为产物污染。

---

## 3. 迁移公告

### 3.1 gbAuto 语义版本化

- **首版（Phase 0–4）**：`gbAuto = gbLibGit2`。存量代码 `NewGitManager` / `NewGitManager(gbAuto)` 行为与重构前完全一致，零 breaking change。
- **下版本（公告）**：`gbAuto` 将切换为 `gbNative`。切换前将在 `CHANGELOG.md` 与本文件顶部以 `BREAKING` 公告，并提供 `gbLibGit2` 显式保留路径。
- 迁移建议：新代码显式传参 `gbNative` 或 `gbLibGit2`，避免依赖 `gbAuto` 的隐式默认值；`gbAuto` 仅用于“跟随默认后端”的场景。

### 3.2 时间线

| 阶段 | gbAuto 指向 | 备注 |
|------|-------------|------|
| Phase 0（当前） | `gbLibGit2` | 契约冻结，C4 门禁落地 |
| Phase 1–3 | `gbLibGit2` | `native.manager/repository` 闭合，纯测试/Demo 绿 |
| 下版本 | `gbNative` | 切换前发迁移公告，`gbLibGit2` 仍可用 |

---

## 4. TGitBackend 语义

```pascal
// nextpas.core.git.factory
type
  TGitBackend = (gbNative, gbLibGit2, gbAuto);
function NewGitManager(ABackend: TGitBackend = gbAuto): IGitManager;
```

| 枚举 | 语义 | 错误模型 |
|------|------|----------|
| `gbNative` | 创建 `TNativeGitManager`，仅依赖 `native.*`，零 libgit2。未实现方法（首版仅闭合 `OpenRepository/IsGitRepository/InitRepository + Status/Head/LookupCommit/Close`）抛 `EGitError('not implemented for native backend: <Method>')` | `EGitError` 来自 `git.native.base` |
| `gbLibGit2` | 创建 `TLibGit2Manager`，经 `platform.dl` 的 `dlopen/dlsym` 运行时加载 `libgit2`，缺库时抛 `EGitError` | `EGitError`（历史在 `libgit2.backend`，收敛至 `native.base`） |
| `gbAuto` | 策略别名：首版 = `gbLibGit2`，下版本 = `gbNative` | 同所指后端 |

**门面转发**：

```pascal
// nextpas.core.git
function NewGitManager: IGitManager; inline;
begin
  Result := git.factory.NewGitManager(gbAuto);
end;
```

门面保留无参重载以兼容存量，语义等价于 `factory.NewGitManager(gbAuto)`。

**零 IFDEF**：`gbNative` 与 `gbLibGit2` 的隔离由 `uses` 图保证，不在同一单元内用 `{$IFDEF}` 分叉。

---

## 5. 门禁

- `scripts/git-contract-check.sh` C4：
  - `grep -R "nextpas.core.git.libgit2" core/src/nextpas.core.git.native.manager.pas core/src/nextpas.core.git.native.repository.pas` 必须零命中；
  - 全量 `native.*` 闭包 `grep -R "libgit2" core/src/nextpas.core.git.native.*` 零命中；
  - `fpc -va` 编译 `test_git_pure_manager.lpr` 的 `Loading.*libgit2` 零命中（Phase 0 grep 版先行，产物版 TODO，见脚本内注释）；
  - `nm -D build/bin/test_git_pure_manager | grep git_` 零命中（验收门禁，非 Phase 0 脚本内强制）。
- `make hygiene` 与 `git diff --check` 为 Phase 0 唯一门禁，不跑全量 `make verify`。

---

## 6. 非目标

- 首版不补全 `IGitRepositoryExt` 的 `Push/Fetch/Clone/Remote` 等，统一抛 `EGitError`。
- 不重写 `libgit2.bindings` 生成器，不动 `vendors/`。
- 不引入 `settings.inc` 开关，不改 `compiler/` 与 `stage0`。
