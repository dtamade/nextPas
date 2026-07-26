# bench lane 值班备忘

**对象**：`.worktrees/bench` / 分支 `bench`
**状态默认**：Maintenance Idle（B43+；B48 文档卫生已 land `origin/main`）
**最后更新**：2026-07-26

## 1. 职责边界

| 做 | 不做（默认） |
|----|----------------|
| 框架回归：`make bench-module-test` | EBR × BenchRun（见 `ebr-benchrun-design-note.md`） |
| 文档/registry/契约口径纠偏 | 全量 `bench/SCORECARD.md` 60+ track 刷新 |
| scorecard 子集 smoke | 向 `IBenchResults` / `IBenchSuite` 堆公共 API |
| 消费侧 checklist **记录**（模块 `.lpr` 大改归各 lane） | raw merge 长期 `bench` 进 `main` |
| 明确授权的小修 / 卫生 | 无问题陈述的门面大拆 |

## 2. 日常命令

```bash
# 框架全量 focused gate（22 PROJECTS + hygiene）
make bench-module-test

# 轻量跨语言 smoke
make bench-scorecard-smoke

# 契约脚本
bash scripts/bench-contract-check.sh
```

权威入口：`README.md`、`goal-tree.md`、`CONTRACT.md`、`consumer-guide.md`。

## 3. Landing 纪律（硬）

本仓库 **多人 / 多 agent 并行**，本地 `main` 常被：

```text
git reset --hard origin/main
# 或 merge 其他 landing 前先对齐 origin
```

因此：

1. **禁止** 把整个长期 `bench` lane raw merge 进 `main`。
2. **只** path-limited 候选：
   `landing/bench-YYYYMMDD` ← cherry-pick 逻辑提交（勿带 lane merge 噪音）。
3. `make landing-check BASE_REF=main ALLOW_PATHS="..." FOCUS=core/tests/nextpas.core.bench`。
4. **`git merge --ff-only landing/...` 成功后，必须立刻 `git push origin main`**。
5. **未 push 的 local Landed 不算数**——会被 `reset → origin/main` 抹掉（B44 曾中招）。
6. Landed 声明前做 **内容探针**（勿只看 SHA）：

```bash
git show origin/main:core/docs/core-module-registry.md | rg '`bench`'
# 期望：focused-runtime
git show origin/main:.gitignore | rg 'arrayops/\*_bench'
git ls-tree -r origin/main --name-only | rg 'arrayops/arrayops_bench$' || echo ELF_GONE
```

### ALLOW_PATHS 模板（B44 类卫生包）

```text
.gitignore arrayops bitrotate bytewise charclass memalloc random setmember
bench core/docs/bench core/docs/core-module-registry.md
```

## 4. Lane 同步

- Idle 期间：`behind origin/main` 变大时择机 `git merge origin/main`。
- 冲突：非 bench 路径优先 **main**；本模块文档/源码冲突才细审。
- `ahead` 含历史 merge 属正常，**不要** 因此 ff 整 lane 进 main。

## 5. 回归基线怎么记

跑完 `make bench-module-test` 后，在报告或本文件「最近证据」节记：

- 日期、`HEAD` / `origin/main` 短 SHA
- exit code、22 suites 是否全绿
- 若失败：suite 名 + 是否与本 lane 改动相关

## 6. 最近证据

| 日期 | 底座 | 命令 | 结果 |
|------|------|------|------|
| 2026-07-20 | lane `ed47d339f`（registry `focused-runtime`；B44 在 origin 祖先链）；当时 behind origin=3 | `make bench-module-test` | **exit 0**；**22/22** suites；**505** tests passed / 0 failed；heaptrc 末 suite 0 leaks；hygiene pass |
| 2026-07-20 | B45 可用性落地 | `make bench-module-test` + `bench-contract-check` + example compile | **22/22** suites **506** tests；contract pass（orphan warn）；quick_start/demo_basic/bb_smoke 编译通过 |
| 2026-07-20 | B47 消费侧 API drift | 原红 12 + json_raw + Skip 修复；`make -C <bench> clean build` 全绿；`bench-contract-check` | 见 commit；门面大拆/EBR/SCORECARD 仍 Idle |
| 2026-07-21 | B48 T1 文档卫生 | `bench-contract-check` + `make hygiene` + `git diff --check` | 历史 docs→archive；CONTRACT/ARCH/API/22 口径；无源码变更 |
| 2026-07-21 | B49 T2 半成品收口 | integration/timeout 路径 + contract-check | 删 entry TimeoutMs；object_pool→recipe；删 orphan test |
| 2026-07-26 | lane merge origin/main 后 | `make bench-module-test` + `bench-contract-check` + `bench-scorecard-smoke` | **22/22**；**506** tests；contract **12/12**；hygiene pass |
| 2026-07-26 | **Landed** `ab54e9a9d` → `origin/main` | path-limited `core/docs/bench`；`landing-candidate=pass` + focused gate | B48 根目录历史 docs 去重；archive 保留；**已 push** |
| 2026-07-26 | idle cycle；`origin/main`=`796bd168e`；behind=0 | `bench-module-test` + contract + scorecard-smoke + consumer build | **22/22**；**506** tests；contract **12/12**；inttohex ok；hash/json bench build ok |
| 2026-07-26 | audit 全量闭环（F-01–F-26）；HEAD `c28c60fb8` | `bench-module-test` + contract + scorecard/consumer smoke | **22/22**；**510** tests；contract **13/13**（+C10）；inttohex+hash/json ok；见 findings.md |
| 2026-07-26 | merge origin/main（吸收 audit landing `a5075603c`）；SCORECARD 行尾对齐 main | 连续 3 次 `bench-module-test` | 2 绿 1 红：`test_bench_matrix` 偶发 fpc `Can't find unit test.diff`（**F-27** flake，严格前缀取证；单独 6/6 绿） |
| 2026-07-26 | F-27 缓解：gate 循环拆构建/运行、构建重试一次；report 套件补 `all` 别名 | `bench-module-test` + contract-check | **exit 0**；**22/22**；**510** tests；0 retry 触发；hygiene pass |
| 2026-07-26 | **Landed** `c90f620c2` → `origin/main`（F-27 gate retry + report all）；landing worktree 已删 | `landing-check`（candidate=pass + focused 22/22 510 + hygiene）；内容探针 BUILD-FLAKE-RETRY/F-27 均在 origin/main | **已 push**；lane 已回吸 origin/main |
| 2026-07-26 | F-22 注释卫生：8 源文件 46 处 ticket 标签清理（活约束保留说明，噪音整删）；纯注释级 diff | `bench-module-test` + contract-check + `git diff --check` | **exit 0**；**22/22**；**510** tests；contract 全通过 |
| 2026-07-26 | **Landed** `bf61139c9`（F-22 注释卫生）→ `origin/main`；lane 回吸至最新 main | rebase×2 追热仓库 + landing-check pass×2 + 单套件构建探针 + 回吸后 `bench-module-test` | **exit 0**；**22/22**；**510** tests；0 retry；内容探针 F-22 Resolved / SRC-CLEAN |
| 2026-07-26 | F-25 scipy 金标落地：4 个 `golden_*.inc` + 生成器自检 + 22 断言接入 4 既存套件；顺手修出 F-28（Skewness G1）/F-29（KS2 tie 走查）/F-30（`{$MINFPCONSTPREC 64}`×3 单元） | `bench-module-test` + `bench-contract-check`；四套件单跑 heaptrc 0 leaks | **exit 0**；**22/22** 全 0 failed；**521** tests（510+11 golden 用例）；0 retry；contract **13/13** |
| 2026-07-26 | 金标 tranche 2：CI/离群点/TrimmedMean/CohenD/Welch 布尔/Bayesian 六组金标 + 5 新测试过程；揪出并修复 F-31（ModZ MAD 双奇偶 off-by-one，修复前金标实测红）/F-32（level/alpha 边界比较失配，`BENCH_LEVEL_EPS`）；F-30 补涂 report 单元收尾 | `bench-module-test` + `bench-contract-check`；两改动套件单跑 heaptrc 0 leaks | **exit 0**；**22/22** 全 0 failed；**526** tests（+5）；0 retry；contract **13/13** |
| 2026-07-26 | 金标 tranche 3：OLS 回归双数据集（TIGHT R²≈0.9998 / LOOSE R²≈0.904，复刻公式自检 <tol/2）+ CoefficientOfVariation（ddof=1，Welford 复刻自检）；一次全绿无新 bug——统计面主干至此全部有外部金标 | `bench-module-test` + `bench-contract-check`；stats 套件单跑 heaptrc 0 leaks | **exit 0**；**22/22** 全 0 failed；**527** tests（+1）；0 retry；contract **13/13** |
| 2026-07-26 | 金标 tranche 4：D'Agostino-Pearson K2 双数据集（右偏/近正态）+ Welch t + Cohen's d；揪出并修复 **F-33**（K2 四重口径错致双向误判，修复前金标实测红 K2=1.880 vs 期望 13.775）；Welch/Effect 一次全绿转防回归钉 | `bench-module-test` ×2 + `bench-contract-check`；advanced 套件单跑 heaptrc 0 leaks；首跑 1 次 F-27 类构建 flake（重跑两连绿，无 FLAKE/Fatal 标记） | **exit 0**；**22/22** 全 0 failed；**528** tests（+1）；contract **13/13** |

> 新一次回归后更新本表一行即可。

### 2026-07-26 收口

- B48 文档卫生已 **push 到 origin/main**（`ab54e9a9d`）。
- 源码/测试/示例此前已在 main；本次仅 docs 去重。
- landing worktree：`.worktrees/landing/bench-20260726`（可删）。
- **Idle 值班中**：不排期 API/EBR/全量 SCORECARD；只合 main、跑门禁、修回归。
