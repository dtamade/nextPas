# bench lane 值班备忘

**对象**：`.worktrees/bench` / 分支 `bench`
**状态默认**：Maintenance Idle（B43+；B44 卫生包已 land）
**最后更新**：2026-07-20

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

> 新一次回归后更新本表一行即可。
