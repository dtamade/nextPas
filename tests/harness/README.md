# nextPas harness/

`tests/harness/` 是 nextPas 第一阶段验证控制面的 Pascal 执行层。这里现在已经不再靠
“目录里有多少 fixture / snapshot”来判定成功，而是会真实编译、真实运行、真实对比
baseline。

如果你要看长期边界，读
`docs/architecture/test-harness-specification.md`。如果你要看当前全仓 gate，读
`build/verify_local.sh`。

## 这个目录当前负责什么

- `tests/run_all_tests.sh`：shell 控制面，暴露稳定的 `--list-groups` 与
  `--filter <group>` 入口
- `tests/harness/runner.pas`：Pascal 执行层，负责 fixture 收集、真实执行、group/smoke
  结果汇总与 `command-envelope=<json>` 投影
- `tests/harness/snapshot_support.pas`：snapshot key、canonical text normalization 和
  diff evidence helper

`tests/run_all_tests.sh` 当前会把 runner 编译到：

```text
build/harness/bootstrap/runner
```

也就是说，runner bootstrap 产物已经不再写回 `tests/harness/` 源码目录。
同一条 shell 控制面还会把 `stage0` 驱动自举到：

```text
build/stage0-bootstrap/nextpas
```

所以 `compiler-pass` / `compiler-fail` 不再依赖源码树里“碰巧已经有一个”
`tools/stage0/nextpas`。

如果 bootstrap 失败，shell 层当前会额外输出：

- `bootstrap-step=<step>`
- `bootstrap-command=<command>`
- `bootstrap-stderr-file=<path>`

并在 stderr 文件非空时直接回显原始 stderr evidence，避免失败只剩一句模糊的
`stage0-build-failed`。

## 当前公开分组与 fixture 契约

| Group           | Fixture pattern                     | 当前真实执行路径                                     |
| --------------- | ----------------------------------- | ---------------------------------------------------- |
| `compiler-pass` | `tests/compiler/pass/*_pass.pas`    | 调用 scratch-built `stage0 build`，再真实运行产物    |
| `compiler-fail` | `tests/compiler/fail/*_fail.pas`    | 调用 scratch-built `stage0 build`，预期失败，并对比 canonical text |
| `diagnostics`   | `tests/diagnostics/**/*.pas`        | 调用宿主 `fpc`，预期失败，并对比 canonical text      |
| `rtl`           | `tests/rtl/*_smoke.pas`             | 调用宿主 `fpc` 编译，再真实运行二进制                |
| `crt`           | `tests/crt/*_smoke.pas`             | 调用宿主 `fpc` 编译，再真实运行二进制                |
| `regression`    | `tests/regression/*_regression.pas` | 调用宿主 `fpc` 编译，再真实运行二进制                |

`smoke` 是横跨这些分组的最小验证视角，不是额外的第七类长期 group。

## 公开命令表面

Run:

```bash
./tests/run_all_tests.sh --list-groups
```

Then:

```bash
./tests/run_all_tests.sh --filter compiler-pass
./tests/run_all_tests.sh --filter compiler-fail
./tests/run_all_tests.sh --filter smoke
```

`smoke` 现在会真实执行每个 group 的最小 fixture 集，而不是只检查 fixture 数量或 snapshot
文件是否存在。

## 输出与留证

group 运行现在会稳定投影这些字段：

- `fixture-result=<path> tool=<tool> executed=1 exit-code=<code> result=<pass|failure>`
- `executed-fixture-count=<n>`
- `passed-fixture-count=<n>`
- `failed-fixture-count=<n>`
- `snapshot-status=ready|missing|unstable`（仅 snapshot-bearing groups）
- `command-envelope=<json>`

bootstrap failure 路径还会额外投影：

- `bootstrap-step=<step>`
- `bootstrap-command=<command>`
- `bootstrap-stderr-file=<path>`

snapshot-bearing groups 还会为每个 fixture 额外输出：

- `snapshot-entry=<key> fixture=<path> status=<ready|missing|unstable> path=<snapshot> diff=<diff>`

当前 canonical baseline compare 的规则是：

- `compiler-fail` 和 `diagnostics` 会生成 canonical actual text
- 如果缺少 snapshot，会把 evidence 写到 `tests/snapshots/*.diff.txt`
- 如果 snapshot 与实际文本不一致，也会把 diff evidence 写到同一路径

`smoke` 视角当前会为每个 group 输出一条：

- `smoke-group=<group> result=<...> expectation=<...> fixtures=<n> executed=<n> snapshot=<...>`

所以 `smoke` 的绿灯现在代表“真实执行过这批最小样例并且 baseline 稳定”，而不是
“目录结构看起来齐了”。

## 临时产物现在落在哪里

fixture 的 build/run 输出和 host-backed 二进制现在写到：

```text
build/harness/work/<fixture-token>/
```

`stage0` bootstrap 二进制与 stderr evidence 则写到：

```text
build/stage0-bootstrap/
```

这让源码树不再承担临时产物目录的角色，也降低了生成物反向污染 fixture 收集的风险。

## 这一阶段要诚实描述什么

- `compiler-pass` 与 `compiler-fail` 已经走 nextPas `stage0 build`
- `diagnostics`、`rtl`、`crt` 与 `regression` 仍然是 host-backed，当前通过宿主 `fpc`
  证明 baseline
- `smoke passed` 现在可以作为真实执行 gate，但它仍不等于 “nextPas 已完全接管全部编译路径”

这份 README 只描述当前仓库已经落地并验证过的行为，不替未来阶段提前背书。
