# RISCVV Native Closeout Runbook

更新时间：2026-05-21

这份 runbook 只解决一件事：当你需要 fresh `riscvv` native evidence 时，如何从当前 repo 的 operator helper 走到可消费的 artifact，而不是在 dirty worktree、未推送 ref、或未就绪 runner 上反复空转。

## 适用边界

- 当前 repo 已提供：
  - `BuildOrTest.sh native-evidence-via-gh`
  - `BuildOrTest.sh native-evidence-via-gh-clean`
  - `BuildOrTest.sh riscvv-runner-registration`
  - `BuildOrTest.sh riscvv-runner-host-preflight`
  - `BuildOrTest.sh riscvv-runner-3cmd`
  - `BuildOrTest.sh release-evidence`
- 当前 repo 不提供：
  - `riscv64` runner binary / service
  - repo-ops 侧的最终 runner 实现
  - 把 token 写进任何 repo-tracked 文件的能力

## 最短路径

先打印 3-command 摘要：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh riscvv-runner-3cmd
```

如果你直接要开始执行，按下面顺序：

```bash
SIMD_RISCVV_RUNNER_TOKEN_FILE=/tmp/fafafa-simd-riscvv-runner.token \
FAFAFA_BUILD_MODE=Release \
bash tests/nextpas.core.simd/BuildOrTest.sh riscvv-runner-registration

FAFAFA_BUILD_MODE=Release \
bash tests/nextpas.core.simd/BuildOrTest.sh riscvv-runner-host-preflight

FAFAFA_BUILD_MODE=Release \
bash tests/nextpas.core.simd/BuildOrTest.sh native-evidence-via-gh-clean riscvv

FAFAFA_BUILD_MODE=Release \
bash tests/nextpas.core.simd/BuildOrTest.sh release-evidence
```

## 阶段 1：Repo-side 准备 registration token

推荐命令：

```bash
SIMD_RISCVV_RUNNER_TOKEN_FILE=/tmp/fafafa-simd-riscvv-runner.token \
FAFAFA_BUILD_MODE=Release \
bash tests/nextpas.core.simd/BuildOrTest.sh riscvv-runner-registration
```

它会做的事：

- 解析当前 repo slug
- 调用 `actions/runners/registration-token`
- 固定建议标签为 `self-hosted,Linux,riscv64`
- 可选把 token 安全落到 repo 外路径

它不会做的事：

- 安装 runner
- 启动 runner
- 把 token 写进 repo 内文件

## 阶段 2：真实 riscv64 host preflight

在目标 host 上执行：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh riscvv-runner-host-preflight
```

当前 preflight 会 fail-close 检查：

- `uname -m` 必须真实为 `riscv64`
- 必需命令：`bash`、`sudo`、`curl`、`tar`、`git`
- `sudo -n true` 必须可用
- GitHub 与 FPC snapshot URL 必须可达

如果这里都没通过，不要继续 dispatch workflow。

## 阶段 3：采集 fresh native evidence

当 repo-visible `self-hosted,Linux,riscv64` runner 已就绪后，优先使用 clean-worktree 入口：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh native-evidence-via-gh-clean riscvv
```

这条路径的意义：

- 当前 closeout worktree 可以继续保持 dirty
- helper 会基于当前已推送 ref 创建临时 clean worktree
- 然后复用现有 `native-evidence-via-gh` dispatch / poll / download / verify 合同
- artifact 最终仍然写回当前 worktree 的 `tests/nextpas.core.simd/logs/`

如果你已经有可信的 GH run id，也可以复用：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh native-evidence-via-gh riscvv <run-id>
```

## 常见 fail-close 场景

- `Refuse dispatch: local worktree has uncommitted changes.`
  - 用 `native-evidence-via-gh-clean`，或者先提交并推送。
- `Refuse dispatch: remote ref does not match local HEAD.`
  - 先把当前 SIMD 改动推到远端，再重试。
- `Refuse clean-worktree dispatch: remote ref is missing or not a branch.`
  - 当前 ref 还没推送，或不是可 dispatch 的远端分支。
- `No matching self-hosted runner available for labels: self-hosted, Linux, riscv64`
  - repo-visible runner 还没真正在线，或标签不对。

## 阶段 4：回写 machine-readable bundle

fresh artifact 落地后，不要靠手工读目录判断 closeout 状态。直接重导 bundle：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh release-evidence
```

预期变化：

- `release_evidence.json` 会重新扫描 `native-evidence-*` / `native-evidence-gh/*`
- 若 `riscvv` artifact 已 fresh 落地，`external_blockers` 会同步收敛
- `release_ready` 仍只跟随 `freeze_status.freeze_ready`

## 什么时候才需要再跑重链路

下面两种情况再去重跑 `gate-strict` / `freeze-status`：

1. 本轮改动触碰了 closeout 主合同
2. 你需要把 gate/freeze/bundle 的时间线重新对齐

否则，补了 fresh RISCVV native artifact 之后，优先先做 `release-evidence`，不要无意义重跑整条门禁链。
