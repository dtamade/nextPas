# nextPas tests/

`tests/` 是 nextPas 第一阶段的验证系统边界，不是实现完成后的附录。这里当前承接的
不是抽象的“以后会有测试”，而是已经和 `stage0`、RTL、CRT、diagnostics 与回归路径
接起来的真实执行资产。

如果你要看冻结后的规则，先读
`docs/architecture/test-harness-specification.md`。如果你要看当前 unit/module
兼容边界，继续读 `docs/architecture/unit-resolution-specification.md` 和
`docs/architecture/compatibility-matrix.md`。

## 这一层当前承接什么

- `run_all_tests.sh`：shell 控制面，暴露稳定的 `--list-groups` 与 `--filter <group>`
- `harness/`：Pascal 执行层、snapshot helper 和统一失败留证语义
- `snapshots/`：`compiler-fail` 与 `diagnostics` 的 text-baseline 资产
- 稳定 group：`compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt`、
  `regression`

`smoke` 是横跨这些 group 的最小执行视角，不是另起的长期第七类。

## 当前 fixture 命名约定

| Group           | Fixture convention                  | 当前契约                                           |
| --------------- | ----------------------------------- | -------------------------------------------------- |
| `compiler-pass` | `tests/compiler/pass/*_pass.pas`    | nextPas `stage0 build` 成功，且产物可运行          |
| `compiler-fail` | `tests/compiler/fail/*_fail.pas`    | nextPas `stage0 build` 失败，并对比 canonical text |
| `diagnostics`   | `tests/diagnostics/**/*.pas`        | 宿主 `fpc` 失败，并对比 canonical text             |
| `rtl`           | `tests/rtl/*_smoke.pas`             | 宿主 `fpc` 编译并运行                              |
| `crt`           | `tests/crt/*_smoke.pas`             | 宿主 `fpc` 编译并运行                              |
| `regression`    | `tests/regression/*_regression.pas` | 宿主 `fpc` 编译并运行                              |

这套命名现在直接决定 fixture 收集规则。非 `.pas` 文件、二进制、`.o`、旧 runner 产物都不会再
被当成测试输入。

## 当前结果对象边界

`tests/` 的长期契约不是“stdout 恰好有哪几行”，而是以下三类结果对象：

- `CommandResultEnvelope`
  - 回答命令级 outcome、selector、status、result 和 human summary
- diagnostics snapshot
  - 回答稳定的 text-baseline 是什么
- build trace / run output evidence
  - 回答真实执行时发生了什么，以及产物或日志落在哪里

这意味着当前 shell projection 会稳定暴露这些字段：

- `fixture-result=...`
- `executed-fixture-count=...`
- `passed-fixture-count=...`
- `failed-fixture-count=...`
- `snapshot-entry=...`
- `smoke-group=... executed=<n> ...`
- `command-envelope=<json>`

但真正的长期 truth 不是“只 scrape 某一行文本”，而是这些字段背后的执行和 evidence
语义。

## `smoke` 现在到底证明什么

`make test-smoke` 现在会通过 `tests/run_all_tests.sh --filter smoke`：

- 真实执行每个 group 的最小 fixture
- 汇总缺失 fixture、缺失 snapshot、unstable snapshot 和 failing groups
- 输出每个 group 的 `executed=<n>`，而不是只看目录计数

所以 `smoke passed` 现在至少能证明：当前最小 baseline 真实跑过了。

但它仍然不能替代这些更大的结论：

- 不能证明 nextPas 已完全脱离宿主 `fpc`
- 不能证明 multi-root workspace 或更深的 package graph 已稳定
- 不能证明完整 compiler pipeline 已独立闭环

## 这一层当前如何避免污染源码树

- runner bootstrap 产物写到 `build/harness/bootstrap/runner`
- fixture 的 build/run 输出与 host-backed 二进制写到 `build/harness/work/...`
- `tests/snapshots/*.diff.txt` 只在 baseline 缺失或不稳定时生成 evidence

这条规则的目的是让 fixture collection 和源码树状态尽量解耦，不再因为工作区里残留二进制而
误判测试输入。

## 这里现在不做什么

- 不把 `smoke` 重新退化成“文件齐全检查”
- 不把 host-backed group 说成 nextPas 已完全接管
- 不把临时生成物继续写回 `tests/` 源码目录
- 不把 snapshot mismatch 吞成模糊的基础设施错误
