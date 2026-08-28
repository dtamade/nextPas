# nextPas 终局路线图 — 2026-08-28 最终版

> 一页说清 nextPas 要长成什么、按什么顺序长、怎么证明长成了、以及何时必须回退。
> 本文档是 `master-roadmap / compiler-roadmap / bootstrap-roadmap / goal-tree` 的收敛封版，替代所有散落的 `ROADMAP_FINAL_*.md` 草稿。

---

## 0. 判定

**北极星**：nextPas = 现代、高性能、优雅的 Pascal 原生开发平台 — 自有编译器主干 + 自有 RTL/core/framework + 统一 workspace/package/tooling + 自有 GUI/IDE，能认真兼容 FPC 并超越历史惯性。

**优雅的判定**：每层有 owner、truth object、projection、promotion gate、诚实非目标；新增能力优先复用现有 control plane；所有成功/失败可解释、可验证、可回滚。

**五维质量门**（本轮“追求完美”标尺）：

| 维度 | 定义 | 硬门槛 |
|------|------|--------|
| 性能 | 关键路径可量化、可复现 | bench 基线 + 回归红线 |
| 高级感 | API 一致、零样板、可组合 | facade 审查 + consumer 审计 |
| 复用度 | table-driven、零重复、单真相 | 重复代码扫描 + owner 边界 |
| 稳定性 | 炸弹、边界、并发、异常全覆盖 | 163 级别测试 + `E*LimitError` |
| 完整性 | 文档、契约、验证、证据同版本 | `README + CONTRACT + TEST` 同步 |

---

## 1. 约束与基线

- `FPC /home/dtamade/projects/fpc` 为兼容性取证来源，非口头兼容。
- `Linux x86_64` 唯一宿主/目标基线，先收敛再矩阵扩展。
- `stage0 = FPC trunk` 托管，直至 `bootstrap-roadmap` 晋级门槛真实赢下。
- `rtl/core = nextpas-owned` 真实落点；`core/` 为 L0-L3 基础设施，`compiler/tooling` 只提需求不直接改 `core/`。
- `build / test / verify` 共享 machine-readable `CommandResultEnvelope`，`build/verify_local.sh` 为本地权威门。
- 产物卫生：`.o .ppu .a .so .dylib link*.res` 永不入源码树，`scripts/build-hygiene-check.sh` 拦截。

**当前全局位置（2026-08-28）**

- `stage0` 主干已拥有 `CompilationSession / Lexer/Green CST/AST / UnitGraph / Typed HIR / MIR / backend / toolchain runner / query/env/pkg/doctor`。
- `core` 已形成 L0(base/errors/platform/mem/log.intf) → L1(bytes/text/collections/sync/async) → L2(fs/net/tls/crypto/json/yaml/sevenz/zip) → L3(http/websocket/tui/config/app) 分层，`sevenz` 作为 L2 标杆已达 **163 tests / heaptrc 0 / hygiene pass / `ESevenZLimitError` 炸弹门**。
- 最大未完成面：`G1.5 overload / G1.6 diagnostics` 完整度、`G2 ABI`、`G4 package resolver`、`G6 LSP`。

---

## 2. 双轴视图

```
产品轴：Control Surface → Syntax Frontend → Unit Resolution & Semantic Core → Typed HIR/MIR/Backend/Toolchain → Target/Cross/LLVM/C Interop → Workspace/Tooling → GUI/IDE
自举轴：stage0 → stage1 → stage2
```

- `master-roadmap` 负责产品轴顺序
- `compiler-roadmap` 负责编译器接管顺序
- `bootstrap-roadmap` 负责所有权迁移
- `goal-tree` 负责每批绑定 G0-G8 节点

任何一批无法指向 `G0-G8` 即为方向不清。

---

## 3. 七段封版（唯一推荐主线）

每段回答：冻结什么 → 晋级门 → 回退症状。

### 段 1：Control Surface & Session Foundation

- **冻结**：`nextpas build/test / tests/run_all_tests.sh / build/verify_local.sh` 统一 `CommandIntent/Context/ResultEnvelope`；`CompilationSession` 拥有 source/TargetFacts/diagnostics。
- **晋级门**：machine-readable 桥接、本地/CI 同契约、失败种类可复用、session 拥有输入与汇聚。
- **回退**：文本抓取判成败、target/failure 分叉、全局状态漂移、文档与命令不一致。

### 段 2：Syntax Frontend

- **冻结**：`Source DB → Lexer → Green CST(immutable) → AST facade` 唯一主骨；语法失败进 diagnostics。
- **晋级门**：smoke 可执行骨架、parser 失败进 sink、生命周期可解释（interning/arena/cheap reparse 就绪）。
- **回退**：syntax 回写语义、仅字符串观失败、语法树多份物化。

### 段 3：Unit Resolution & Semantic Core

- **冻结**：`UnitId/ResolvedUnit/SearchPathSet/UnitGraph` 持有；`Typed HIR / symbol graph / type graph` 为 truth。
- **晋级门**：name resolution 进 `UnitGraph`、失败进 diagnostics。
- **回退**：AST 原地回写、路径试探、backend 猜测 facts。
- **当前重点**：补 `G1.5 overload`（arity/default/implicit conversion/ranking/visibility/ambiguity）与 `G1.6` 结构化 `unknown-callable / unknown-member`。

### 段 4：Typed HIR / MIR / Backend / Toolchain

- **冻结**：`Typed HIR → MIR → Codegen adapter → TargetFacts + output intent`；`assembler/linker/archiver` 独立编排；产物计划显式（`units/<target>/ bin/ lib/ share/`）。
- **晋级门**：MIR 为正式 backend input、tool invocation 有 plan/profile/失败映射、落点可解释。
- **回退**：backend 重做 overload、opaque shell 模板、落点不可解释。

### 段 5：Target / Cross / LLVM / C Interop

- **冻结**：`HostFacts + TargetFacts + ToolchainBinding + Sysroot` 统一主键；LLVM 为 specialization；calling convention/symbol/library 为 foreign contract。
- **晋级门**：三套名字系统合一、cross 不依赖 host fallback、双 backend 同消费 `MIR/TargetFacts`。
- **回退**：LLVM 要第二套 IR、cross 散落、raw linker args 泄漏。

### 段 6：Workspace & Developer Tooling

- **冻结**：`WorkspaceModel/PackageRef/TargetSelection/ArtifactRootSet` 共享 truth；`pkg/env/fmt/doc/doctor/query/test/bench` 为 thin entrypoint + shared core。
- **三线能力**（同壳不同核）：`LSP = LanguageServiceSession` 拥有 revision；`fmt = source snapshot + trivia view → edit set`；`test = WorkspaceModel → harness`。
- **晋级门**：无需各写 root discovery、root 可区分、truth 可解释所有视角、LSP/fmt/test 不复制 parser/model。
- **回退**：各工具私有 model、install 不对齐、复制推导逻辑。

### 段 7：GUI Framework & IDE

- **冻结**：`UiScene/UiRuntime/RenderBackend/PlatformShell` 四件套；`RenderAssetBundle/text/layout/interaction/theme/motion/a11y` 同栈；IDE 复用 compiler/toolchain/workspace truth。
- **晋级门**：硬件加速主路径、无第二套 runtime/shell/truth/theme、preview 复用管线。
- **回退**：LCL 兼容层、私有 truth、preview 私有管线。

**近期纪律**：只要 `SourceRoot/Workspace truth` 仍靠最小扫描撑着，优先级回 `resolver/diagnostics/workspace ownership`，再扩 toolchain richness。

---

## 4. 自举轴（与产品轴正交）

| 阶段 | 拥有者 | 含义 | 晋级门 |
|------|--------|------|--------|
| stage0 | FPC trunk | 托管编译器在 `tools/stage0/nextpas.pas` | `make rebuild-compiler` + `make verify` |
| stage1 | nextPas 编译器 | 接管 `nextpas.core.*` 唯一实现层 | `units/<target>/` stub 双编译、`core` 自举 |
| stage2 | nextPas-native RTL | `rtl/core/system` 彻底替代 FPC `System` | `np.system.*` 契约稳定、`TObject.Free` 自有 |

**双编译器纪律**：源码 `uses SysUtils` 在 FPC 下走真实 RTL，在 nextPas 下走 `units/<target>/stub`；逐步用 `nextpas.core.text.conv` 等自有类型替代，stub 自然废弃；禁止 `{$IFDEF}` 分叉与 `nextpas.core` 包装 FPC 遗留类型。

---

## 5. L0-L3 架构纪律（`core/` 宪法）

```
L0: base, errors, platform, mem, log.intf  ← 仅 FPC RTL
L1: bytes, text, collections, sync, async  ← 仅 L0
L2: fs, net, tls, crypto, json, yaml, sevenz, zip ← 仅 L0-L1
L3: http, websocket, tui, config, app     ← 仅 L0-L2
```

- 只向下依赖，同层无环。
- 四件套：`nextpas.core.<mod>.pas` 门面纯 re-export；`base` 类型；`intf` 接口；`ffi` 外部绑定；`impl` 实现。`base ← intf ← impl ← 门面`。
- `nextpas.core` 为唯一实现层，不为 FPC 做兼容包。
- Worktree 纪律：`main` 仅总控 landing；模块开发在 `.worktrees/<mod>` 单 lane；跨模块需说明原因/范围/风险/额外验证；合并前 `worktree clean + focused gate + git diff --check + make hygiene`。

---

## 6. G0-G8 与段落映射

| Goal | 段 | 终局证据 |
|------|----|----------|
| G0 控制面 | 1 | `task_plan/progress/findings` + `verify_local` 小步可回滚 |
| G1.1 Session | 1-3 | `TCompilationSession` 投影 `symbols/bindings/definitions` |
| G1.2 Syntax | 2 | Green CST + bench + parser fixture |
| G1.3 Unit | 3 | `UnitGraph` + missing/ambiguous/cycle 结构化 |
| G1.4 Semantic | 3 | symbol/type/scope + `Typed HIR` |
| G1.5 Overload | 3 | 完整 ranking/visibility/ambiguity |
| G1.6 Diagnostics | 3 | code/phase/range/subject/snapshot |
| G2 Backend | 4 | `HIR→MIR→backend→artifact plan→runner` |
| G3 Core | 全 | `core` L0-L3 + `System.pas` 自举 |
| G4 Workspace | 6 | `WorkspaceModel/PackageRef/Lock/InstallPlan` |
| G5 Tools | 6 | `build/test/query/doctor/env/pkg/fmt/doc/bench` machine envelope |
| G6 LSP/IDE | 6-7 | `LanguageServiceSession` revision |
| G7 FPC 兼容 | 3 | `fpc` 源码取证 + `COMPATIBILITY_MATRIX` |
| G8 性能 | 4,6 | bench 基线 + 增量/惰性策略 |

---

## 7. 标杆：`nextpas.core.sevenz`（L2 完美模板）

> 用 `sevenz` 定义“什么样的 L2 才算封版”。

- **163 tests**：UTF/FILETIME/LZMA2（含 stored fallback/chunk-cap）、backend 切换、writer→reader 往返、Delta/Deflate/BZip2 向量、BCJ 全家（x86/ARM/ARM64/PPC/IA64/SPARC/ARMT/RISCV）+ BCJ2 4 流、AES-256（含 `p7zip` 金库、KAT、IV 唯一性）、multi-folder（阈值/过滤/密码/plain）、流式 `AddFileFromReader/FinishTo/CreateFromReader`、`Copy`、FS 联邦、`for..in`、progress、`Move+CRC` 单遍。
- **性能**：`FLowerNames + SortedIdxIgnoreCase/Rev + TSwissTableStr` O(1) 哈希 + `LowerBoundPrefix/Suffix` O(log N) 零分配 `CompareReversed`；`ExtractIndicesGrouped` 单 folder 单解码；`TBytesViewStream` 零拷贝；`BZip2` 9/30；bench `encode ~6 MB/s / decode pure ~17 / ffi ~42 / BCJ ~200 / Delta ~80 / extraction ~300 MB/s`。
- **高级感**：`ExtractAll + IgnoreCase` 全族 + `Try*WithError` 無異常探針 + `FlushExtractedToFs` 统一。
- **复用度**：`levels` 纯映射复用、`filters` 表驱动、`coders` 统一分发、`limits` 共享炸弹常数。
- **稳定性**：`ESevenZLimitError` 炸弹（header 64MiB/pack 64MiB/total 8GiB/unpack 8GiB / 1M files/folders/streams/CRC / 64KiB name / 256KiB window）、`WriterSinglePassCrc`、`ExtractTo` 256KiB 增量 `Crc32Update`、`2-entry LRU + ClearCache`。
- **完整性**：`README + CONTRACT + TEST` 同版，`git diff --check 0`。

**推广**：所有新 L2（`zip/crypto/http`）以 `sevenz` 为 checklist 落地。

---

## 8. 验证矩阵（每段晋级的硬证据）

| 层 | 命令 | 门槛 |
|----|------|------|
| 单元 | `make -C core/tests/<mod>/<gate> clean test` | `heaptrc 0, warnings 0` |
| 集成 | `make hygiene && git diff --check` | `build-hygiene=pass` |
| 性能 | `make -C core/benchmarks/<mod>/bench_* run` | 基线 ± 5% 波动内 |
| 互操作 | `scripts/sevenz-interop.sh` / `scripts/zip-interop.sh` | `7z/p7zip/xz` 双向一致 |
| 本地权威 | `build/verify_local.sh` | `verify-local=pass` |
| 发布 | `make verify` | 全量 `pass` |

任何一段声称晋级，必须同时提供：分支/worktree/HEAD、保留文件、禁止带入清单、focused gate 证据、merge 建议（`Ready/Blocked/Landed/Needs Review`）。

---

## 9. 度量与红线

- **正确**：所有公开失败有 `code/phase/range`，`try` 不抛；`valid` 逐字节确定（加密除外随机 IV）。
- **性能**：新增分配 `O(log N)` 以下，热路径 `inline`，窗口 `64KiB/256KiB` 单遍。
- **复用**：同语义代码单一 owner，跨模块复制需 `Needs Review`。
- **优雅**：`core/AGENTS + design-conventions` 为审稿基准。
- **非目标诚实**：`ABI compatibility deferred`、`PPMD writer` 未做、`Formatter/LSP server` 仅 API 验证未公开 server。

---

## 10. 风险与回退

| 风险 | 信号 | 回退动作 |
|------|------|----------|
| 前端语义漂移 | `sema` 需猜 AST | 回 `Green CST` 不可变 |
| Workspace 分叉 | 各工具私有 model | 回 `WorkspaceModel` 唯一 truth |
| 性能私有 cache | 大项目 eager 扫描 | 回 lazy index + 复用 |
| 产物污染 | `.o/.ppu` 落源码 | `make hygiene` 拦截 + `make clean` |
| 炸弹 | 超 `SEVENZ_MAX_*` 未抛 | 补 `ESevenZLimitError` 用例 |

---

## 11. 执行节奏

- **每轮开始**：`目标节点 / 当前缺口 / 本轮交付 / 验证方式 / 本轮不做`
- **每轮结束**：`完成节点 / 新增能力 / 验证结果 / 剩余风险 / 下一节点`
- **提交**：一提交一可回滚，`git diff --cached` 先审；禁止 `reset --hard / checkout -- <file>` 删脏 worktree。
- **Worktree**：`scripts/worktree-add.sh <branch> [base]` 创建 `.worktrees/<mod>`，`scripts/worktree-audit.sh` 审计；`main` 不做模块开发。

---

## 12. 立即下一批（按依赖排序）

1. **P1 G1.5**：`overload resolver` 补 `imported no-match + default ranking`（`nextpas.core.compiler` lane，`diagnostics` snapshot）
2. **P2 G4**：`WorkspaceModel` 只读 truth → `pkg plan` preflight（`core` lane 提需求，compiler 侧不改 `core/`）
3. **P3 G2**：`MIR → LLVM` 同 `TargetFacts` 复用，`ppmd writer` 仍 deferred
4. **P4 G3**：`System.pas` `np_object_alloc/free` 接 allocator free + `invalid trap` 结构化
5. **横向**：以 `sevenz 163` 为模板封 `zip` 与 `crypto` L2

---

## 附录：文档权威层级

- `docs/architecture/` 与 `docs/adr/` 为稳定事实
- `docs/plans/` 与 `core/docs/plans/` 为活动计划
- `core/docs/design-conventions.md` 为 `core` 设计规范
- `AGENTS.md → core/AGENTS.md → docs/worktrees.md` 为协作入口

> 本终局路线图自 `2026-08-28` 起为唯一推荐主线；任何偏离需以 `ADR` 显式记录。

