# CI Evidence Matrix（CI 证据矩阵）

这份矩阵记录当前 CI job 证明了什么，也记录它没有证明什么。它的作用是把 CI truth
和本地 Makefile gates 对齐，避免把绿色 workflow 误读成更宽的 source、compile 或
runtime evidence。

## Truth Categories

- `source-contract`：检查源码、文档、workflow 或路径约定。它证明文本和 owner 规则，
  不证明可执行行为。
- `forced-compile`：编译某个 target 或 host 表面，但不声称这个 target 上的 runtime 行为。
- `runtime`：在当前 host 上运行测试、示例、benchmark 或 harness。
- `CI truth`：证明 CI 调用的是本地同一套公开 gate。它不能替代模块 focused gate；
  当模块改动需要 heaptrc/no-leak 证据时，也不能替代那些证据。

## Current CI Matrix

| Workflow | Job | Public gate | Truth category | Boundary |
| --- | --- | --- | --- | --- |
| Linux Verification (`.github/workflows/ci.yml`) | `verify-linux-x86_64` | `make test-tooling` | `CI truth` and `source-contract` | Tooling contracts must run before local verification. |
| Linux Verification (`.github/workflows/ci.yml`) | `verify-linux-x86_64` | `make verify` | `runtime`, `forced-compile`, and `CI truth` | Mirrors `build/verify_local.sh` through the root Makefile. |
| Core CI (`.github/workflows/core-ci.yml`) | `test-linux` | `make -C .. core-ci-test` | `runtime` | Runs core tests and TUI benchmark smoke through the root Makefile gate. |
| Core CI (`.github/workflows/core-ci.yml`) | `test-macos` | `make -C .. core-ci-best-effort-test CORE_CI_HOST=macOS` | `runtime` evidence where tests pass | Pass count 是有用的 host 覆盖；skipped rows 不是模块 readiness。 |
| Core CI (`.github/workflows/core-ci.yml`) | `test-freebsd` | `make -C "$GITHUB_WORKSPACE" core-ci-best-effort-test CORE_CI_HOST=FreeBSD` | `runtime` evidence where tests pass | Push-only FreeBSD 覆盖；skipped rows 仍然是显式 non-evidence。 |

## Local Helpers Are Not CI Matrix Rows

`make lane-focused LANE=<platform|mem|system|config|http>` and
`make landing-check ... LANE=<lane>` 是 local/reporting helper。它们用于为 `Ready`
报告打印或推导 focused evidence，但不是 CI matrix entries，也不应该出现在 workflow
的 `run:` steps 里。

如果一个 slice 改了 `.github/`、`scripts/`、`tests/tooling/`、`docs/worktrees.md`
或这份 CI 证据矩阵，就运行 `make test-tooling`。如果一个 slice 改了
`build/verify_local.sh` 或它拥有的 compiler/local verification surface，就运行
`make verify`。

在 root CI 里，`make test-tooling` must run before `make verify`。

## Reading CI Results

按声明的 truth category 读取 CI 结果：

- `make test-tooling` pass 证明 tooling contracts 和 workflow wiring。
- `make verify` pass 证明 Linux x86_64 上的 local verification mirror。
- Core CI host pass 只证明那个 host 上实际跑过的测试的 runtime behavior。
- 带 skips 的 best-effort host loop 是 coverage signal，不是 landing approval。

模块 `Ready` 报告仍然需要 `docs/worktrees.md` 中对应的 focused gate，以及和改动表面匹配的
source/compile/runtime/no-leak evidence。
