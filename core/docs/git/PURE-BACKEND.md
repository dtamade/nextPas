# nextpas.core.git 纯 Pascal 后端契约（PURE-BACKEND）

**模块**：`nextpas.core.git.*`
**层级**：L2
**北极星**：`uses nextpas.core.git; NewGitManager` 或 `uses nextpas.core.git.factory; NewNativeGitManager/NewGitManager(gbNative)` 或 `uses nextpas.core.git.native.manager; TNativeGitManager.Create`（未拉入 `nextpas.core.git.libgit2` 注册单元）时编译期/运行期/产物三零（`fpc -va Loading` 与 `nm -D` 双零，无 `dlopen`/`-lgit2`/`libgit2.so`，产物不含 `libgit2` 声明，`bytes.ops` 零拷贝 + `inline` 值类型枚举分发，接口引用计数零泄漏）；`factory.NewGitManager(gbAuto/gbLibGit2)` 需显式 `uses nextpas.core.git.libgit2` 注册才可用，否则 fail-closed 抛 `EGitError`；全维度三零经门面/ factory 纯路径/直连三重达成（门面 impl 零 libgit2，base←intf←factory←facade 隔离）。
**状态**：gbAuto 已切换为 gbNative（BREAKING 见 CHANGELOG Unreleased；门面 impl 零 libgit2，`uses nextpas.core.git` 默认纯路径，需 libgit2 时显式 `uses nextpas.core.git.libgit2` + `gbLibGit2`）
**关联**：`CONTRACT.md` §1.1 / `native-reference-map.md` / `scripts/git-contract-check.sh` C4（`core/tests/common.mk:75-78` `haltonnotreleased+log` 双 pin 因 FPC trunk `FlushFunc` 设备语义）

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
  log/revwalk/...)          ↑
                            | RegisterLibGit2Creator(@NewGitManager) initialization
                            |
      nextpas.core.git.factory (TGitBackend, NewGitManager/NewNativeGitManager, RegisterLibGit2Creator) ← 静态仅 native.manager
                ↑                    ↑
      nextpas.core.git (聚合门面，re-export base/intf + inline → factory(gbAuto)，impl 零 libgit2，base←intf←impl←facade 隔离)
       nextpas.core.git.libgit2 (初始化 RegisterLibGit2Creator(@NewGitManager)，显式 uses 才注入 libgit2 轨道)
```

### 1.2 路径说明

- **纯路径（全维度三零）**：`git.NewGitManager`（未显式 uses libgit2）或 `factory(gbNative)`/`NewNativeGitManager` 或 `native.manager.TNativeGitManager.Create` → `native.*` → 编译期/运行时/产物三零（`fpc -va Loading libgit2` 零命中与 `nm -D <pure_bin> | grep " git_"` 零命中，双零；未拉入 `libgit2` 注册单元时编译图零 `libgit2`，`bytes.ops` 零拷贝 + `inline` 值类型枚举零拷贝分发，接口引用计数零泄漏，资源 `try..finally` 不丢，`EGitError` 单源 `native.base`）。
- **全维度零 `libgit2` 直连路径**：`uses nextpas.core.git.native.manager; TNativeGitManager.Create` → `native.*` → 同上三零（门面/ factory 纯路径/直连三重达成，未拉入 `libgit2` 时编译图/产物双零）。
- **兼容路径**：显式 `uses nextpas.core.git.libgit2; factory(gbAuto)` 或 `git.NewGitManager`（已注册）首版 → `libgit2.manager` → 显式注册后与旧行为一致；未注册时 `gbAuto/gbLibGit2` fail-closed 抛 `EGitError`（`not registered`）。
- **归一原则**：依赖隔离在单元级（`uses` 图），FPC 通过编译图决定链接，不用 `{$IFDEF}` 分叉。
- **汇聚点**：`factory` 静态仅依赖 `native.manager`，`libgit2` 经 `RegisterLibGit2Creator` 注册注入；`nextpas.core.git` 门面 impl 零 libgit2（`base←intf←factory←facade` 隔离），不再为兼容路径静态聚合点，需显式 `uses nextpas.core.git.libgit2` 才注入；其余单元不得跨轨。
- **枚举锚点**：后端选择由 `TGitBackend = (gbNative, gbLibGit2, gbAuto)` 驱动，定义于 `nextpas.core.git.factory`，`gbAuto=gbNative`，语义详见 §4。

### 1.3 允许 / 禁止

| 单元 | 允许 `uses` | 禁止 `uses` |
|------|-------------|-------------|
| `git.native.manager` | `git.intf`, `git.native.*` | `git.libgit2*`, `git.factory` |
| `git.native.repository` | `git.intf`, `git.native.*` | `git.libgit2*` |
| `git.libgit2.manager` | `git.intf`, `git.libgit2.ffi/binding/backend` | `git.native.*`（除 `base` 的 `EGitError` 收敛外） |
| `git.factory` | `git.base`, `git.intf`, `git.native.manager` (+ `native.base` EGitError) | `git.libgit2*` 静态（经注册注入） |
| `git.libgit2` | `git.intf`, `git.libgit2.ffi/binding/backend`, `git.factory` (注册) | `git.native.*` |
| `git.pas` 门面 | `git.base`, `git.intf`, `git.factory` (impl 零 libgit2，`base←intf←factory←facade` 隔离) | `git.libgit2*` / `git.native.*` 直引（需显式 uses libgit2 才走 libgit2 轨道） |

---

## 2. 选择矩阵

| uses 场景 | 后端参数 | 实际后端 | 是否含 libgit2（编译图 / 运行时 dlopen / 产物符号） |
|-----------|----------|----------|------------------------------------------------------|
| `uses nextpas.core.git; NewGitManager;` | `gbAuto`（默认） | `gbLibGit2`（首版, 已注册）/ fail-closed（未注册） | 未显式 uses libgit2 时否 / 否 / 否（门面 impl 零 libgit2；显式 `uses nextpas.core.git.libgit2` 注册后是 / 是 / 是） |
| `uses nextpas.core.git.factory; NewGitManager(gbNative);` 或 `NewNativeGitManager;` | `gbNative` | `gbNative` | 否 / 否 / 否（`inline` 值类型枚举零拷贝，未拉入 libgit2 注册单元时三零，经门面/ factory 纯路径/直连三重达成） |
| `uses nextpas.core.git.factory; NewGitManager(gbLibGit2);` | `gbLibGit2` | `gbLibGit2` | 需显式注册时是 / 是 / 是；未注册时 fail-closed（`EGitError not registered`）/ 否 / 否 |
| `uses nextpas.core.git.factory; NewGitManager(gbAuto);` | `gbAuto` | `gbNative` | 否 / 否 / 否 |
| `uses nextpas.core.git.native.manager; TNativeGitManager.Create;` | —（直连） | `gbNative` | 否 / 否 / 否 |
| `uses nextpas.core.git;` 但不调用 `NewGitManager`（仅类型） | — | — | 否（门面 impl 零 libgit2，类型 re-export 不拉 libgit2） |

> 判定标准：`fpc -va` 的 `Loading` 行出现 `libgit2` 即视为编译图污染；
`nm -D build/bin/<pure>` 含 `git_` 视为产物污染。

---

## 3. 迁移公告

### 3.1 gbAuto 语义版本化

- **历史（Phase 5 前）**：`gbAuto = gbLibGit2`（需显式 `uses nextpas.core.git.libgit2` 注册才生效，未注册时 `gbAuto/gbLibGit2` fail-closed 抛 `EGitError('not registered')`）；门面 impl 已零 libgit2（`base←intf←factory←facade` 隔离）。
- **当前**：`gbAuto = gbNative`。切换已在 `CHANGELOG.md` 以 `BREAKING` 公告，`gbLibGit2` 显式保留路径可用（显式 `uses libgit2`）；`uses nextpas.core.git` 门面默认纯路径，`factory` 注册注入不变，门面/ factory 纯路径/直连三重三零。
- 迁移建议：新代码显式传参 `gbNative` 或 `gbLibGit2`，避免依赖 `gbAuto` 的隐式默认值；`gbAuto` 仅用于“跟随默认后端”的场景；需三零证据的纯后端用门面（未注册时）或 `factory(gbNative)`/`NewNativeGitManager` 或直连 `nextpas.core.git.native.manager.TNativeGitManager.Create`（`fpc -va Loading` / `nm -D` 双零）。

### 3.2 时间线

| 阶段 | gbAuto 指向 | 备注 |
|------|-------------|------|
| Phase 0–4 | `gbLibGit2` | 契约冻结，C4 门禁落地（门面仍 impl 注入 libgit2） |
| Phase 5（当前） | `gbLibGit2`（需显式注册） | 门面纯化完成（impl 零 libgit2，`base←intf←factory←facade` 隔离，门面亦三零） |
| 下版本 | `gbNative` | 切换前发迁移公告，`gbLibGit2` 仍可用（显式 `uses libgit2`） |

---

## 4. TGitBackend 语义

```pascal
// nextpas.core.git.factory
type
  TGitBackend = (gbNative, gbLibGit2, gbAuto);
  TLibGit2Creator = function: IGitManager;
procedure RegisterLibGit2Creator(ACreator: TLibGit2Creator);
function NewGitManager(ABackend: TGitBackend = gbAuto): IGitManager; inline;
function NewNativeGitManager: IGitManager; inline; // 纯路径别名, 零 libgit2, inline 转发 TNativeGitManager.Create
```

| 枚举 | 语义 | 错误模型 |
|------|------|----------|
| `gbNative` | `factory` 分发创建 `TNativeGitManager`（`Result := TNativeGitManager.Create`，`inline` 值类型枚举零拷贝分发，接口引用计数拥有，无 `try` 泄漏，`bytes.ops` 单源；未拉入 `libgit2` 时编译图/产物双零，运行时零 `dlopen`）；`TNativeGitManager` 仅依赖 `native.*`，零 `libgit2`，未实现方法（首版仅闭合 `OpenRepository/IsGitRepository/InitRepository + Status/Head/LookupCommit/Close`）抛 `EGitError('not implemented for native backend: <Method>')` | `EGitError` 来自 `git.native.base`（`factory.EGitError = native.base.EGitError`，不经 `libgit2.backend`，异常不丢，`try..finally` 资源不丢） |
| `gbLibGit2` | 创建 `TLibGit2Manager`，经 `platform.dl` 的 `dlopen/dlsym` 运行时加载 `libgit2`，缺库时抛 `EGitError` | `EGitError`（历史在 `libgit2.backend`，收敛至 `native.base`） |
| `gbAuto` | 策略别名：恒等于 `gbNative` | 同 native 后端 |

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

- `scripts/git-contract-check.sh` C4（已闭环，`CONTRACT.md` §6 与本节双重声明；CI 矩阵证据已落地）：
  - `grep -R "nextpas.core.git.libgit2" core/src/nextpas.core.git.native.manager.pas core/src/nextpas.core.git.native.repository.pas` 必须零命中；
  - 全量 `native.*` 闭包 `grep -R "libgit2" core/src/nextpas.core.git.native.*` 零命中；
  - `fpc -va` 编译 `test_git_pure_manager.lpr` 的 `Loading.*libgit2` 零命中（`fpc -va` 实检，见脚本 C4.3a；`grep` 版为辅助，编译图以 `fpc -va Loading` 为准；CI 取 `fpc -va 2>&1 | grep -i "Loading.*libgit2"` 零命中为通过证据）；
  - `nm -D <pure_bin> | grep " git_"` 零命中（产物实检，见脚本 C4.3b；`<pure_bin>` 优先 `core/build/projects/nextpas.core.git/test_git_pure_manager/test_git_pure_manager`，无产物时现场编译后检查；CI 以 `nm -D` 零命中为产物三零证据）。
- `make hygiene` 与 `git diff --check` 为必要门禁；`make focused FOCUS=core/tests/nextpas.core.git/test_git_pure_manager` 为纯后端门禁（`build/verify_local.sh` 聚合 `git-contract-check`）。
- `hygiene` 与 `heaptrc` 双 pin 门禁依赖 FPC trunk `FlushFunc` 设备语义：`heaptrc` 退出期 `StdErr` 文本记录仅句柄为设备（`pipe/tty`）时获 `FlushFunc` 逐写刷新，重定向至普通文件则缓冲且退出时不刷新、小 dump 整体丢失、大 dump 截断；故 `core/tests/common.mk:75-78` 采用 `HEAPTRC='haltonnotreleased,log=*.heaptrc'` 双通道（`haltonnotreleased` 泄漏即 `exit 203`，`log=` 落盘 `heaptrc` 关闭自有文件）+ 双 pin（`grep '^Heap dump by heaptrc unit'` 存在性防真空 + `grep '^0 unfreed memory blocks : 0$'` 零泄漏 + `haltonnotreleased` `exit 203`）自动化，`grep` 程序输出的旧路径已废弃；纯后端三零校验的 `fpc -va` 实检已纳入 CI 矩阵证据（`C4.3a` `Loading` 零命中 + `C4.3b` `nm -D` 零命中），以 `fpc -va` 为准、`grep` 为辅。

---

## 6. 非目标

- 首版不补全 `IGitRepositoryExt` 的 `Push/Fetch/Clone/Remote` 等，统一抛 `EGitError`。
- 不重写 `libgit2.bindings` 生成器，不动 `vendors/`。
- 不引入 `settings.inc` 开关，不改 `compiler/` 与 `stage0`。
