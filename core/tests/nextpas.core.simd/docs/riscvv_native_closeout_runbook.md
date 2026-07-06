# RISCVV Native Closeout Runbook

更新时间：2026-06-07

这份 runbook 只记录当前 worktree 的 live truth：当你需要 fresh `riscvv` native evidence 时，哪些入口现在能用，哪些 historical helper 名字不要再信。

## 适用边界

- 当前 repo 当前不提供：
  - `BuildOrTest.sh native-evidence-via-gh`
  - `BuildOrTest.sh native-evidence-via-gh-clean`
  - `BuildOrTest.sh riscvv-runner-registration`
  - `BuildOrTest.sh riscvv-runner-host-preflight`
  - `BuildOrTest.sh riscvv-runner-3cmd`
  - `BuildOrTest.sh release-evidence`
- 历史 runbook / manifest 里提到的 GH dispatch / clean-worktree / runner-registration helper 在当前 worktree 并未恢复。
- 当前 repo 仍然提供并支持：
  - `collect_nonx86_native_evidence.sh riscvv`
  - `BuildOrTest.sh import-nonx86-native-evidence /path/to/native-evidence-drop`
  - `BuildOrTest.sh verify-nonx86-native-evidence`
  - `BuildOrTest.sh closeout-host-local-from-import /path/to/native-evidence-drop`

## 当前可用路径

### 1. 在真实 riscv64 host 采集 native evidence

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/collect_nonx86_native_evidence.sh riscvv
```

这一步必须在真实 `riscv64` host 上执行；`x86_64` worktree、Wine、QEMU wrapper 或 historical GH helper 名字都不能替代 native host。

### 2. 把 artifact 拷回当前 worktree 并导入

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh import-nonx86-native-evidence /path/to/native-evidence-drop
```

这条入口会把最新 `native-evidence-riscvv-*` 目录导入到 `tests/nextpas.core.simd/fixtures/native-evidence`，然后立刻执行 verifier。

如果你只想 verify 当前目录里的归档，而不做导入，也可以直接跑：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh verify-nonx86-native-evidence
```

### 3. 在当前 worktree 做 host-local closeout

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh closeout-host-local-from-import /path/to/native-evidence-drop
```

这条入口会先导入 external native evidence，再复用当前存在的 host-local closeout 链。

## 不要做的事

- 不要再执行 `native-evidence-via-gh` / `native-evidence-via-gh-clean` / `riscvv-runner-*` / `release-evidence`；这些名字在当前 worktree 只应该被理解成 historical notes。
- 不要把 dirty `x86_64` worktree 当成 `riscv64` native runner。
- 不要手工 `cp` 到 `fixtures/native-evidence` 后跳过 verifier；导入链已经负责目录命名、summary timestamp 和 synthetic marker 的 fail-close。

## 什么时候需要重链路

- 你改了 non-x86 helper/source contract，需要 fresh `riscvv` artifact
- 你拿到的是新的 external native evidence，需要重新导入并收口 host-local closeout

除此之外，不要因为旧 runbook 里还提到 GH helper 名字，就误以为当前 repo 还有一条可用的 GH dispatch 主线。
