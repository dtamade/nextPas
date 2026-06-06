# nextPas Test Harness 规范

用这份规范定义 nextPas 第一阶段验证 `harness` 的真实边界。这里的重点不是“以后可以扩展成
什么测试平台”，而是把当前仓库已经落地并验证过的控制面、执行面和 evidence 面写清楚。

如果你要看 future IDE test panel 为什么必须复用这套结果语义，继续读
`ide-specification.md`。

## 先把当前事实说清楚

`harness` 现在已经不是一个“统计 fixture 和 snapshot 有没有存在”的目录检查器。
当前仓库里的 `tests/run_all_tests.sh` 与 `tests/harness/runner.pas` 会真实执行 fixture，
并把结果投影成稳定的 group / smoke 输出。

这条事实很重要，因为它直接关系到本地验证和 CI 的可信度：

- `smoke` 现在必须代表真实执行过最小 baseline
- CI 绿灯不能再只代表目录结构和 snapshot 文件数量看起来正确
- snapshot mismatch 必须留下可回放 evidence，而不是吞成模糊失败

## `tests/` 下的职责拆分

第一阶段当前固定的职责边界如下：

| 路径                                 | 当前职责                                                              |
| ------------------------------------ | --------------------------------------------------------------------- |
| `tests/run_all_tests.sh`             | shell 控制面，暴露 `--list-groups` 与 `--filter <group>`              |
| `tests/harness/runner.pas`           | fixture 收集、真实执行、group/smoke 汇总、envelope 投影               |
| `tests/harness/snapshot_support.pas` | snapshot key、canonical text normalization 与 diff evidence helper    |
| `tests/snapshots/`                   | `compiler-fail` 与 `diagnostics` 的 text-baseline 资产                |
| `.sisyphus/tmp/harness/`             | runner bootstrap、fixture build output、run output 和临时二进制根目录 |
| `.sisyphus/tmp/stage0-bootstrap/`    | `stage0` bootstrap 二进制与 bootstrap stderr evidence 根目录          |

shell 层负责公开入口，Pascal 层负责执行语义，snapshot 层负责长期 baseline 资产。

## 稳定 group 与 fixture 命名契约

第一阶段当前必须稳定暴露这些 group：

- `compiler-pass`
- `compiler-fail`
- `diagnostics`
- `rtl`
- `crt`
- `regression`

`smoke` 是横跨这些 group 的最小执行视角，不是替代它们的第七个长期类别。

这些 group 当前的 fixture 契约固定如下：

| Group           | Fixture pattern                     | 当前真实执行契约                                     |
| --------------- | ----------------------------------- | ---------------------------------------------------- |
| `compiler-pass` | `tests/compiler/pass/*_pass.pas`    | 调用 scratch-built `stage0 build`，再真实运行产物    |
| `compiler-fail` | `tests/compiler/fail/*_fail.pas`    | 调用 `stage0 build`，预期失败，并对比 canonical text |
| `diagnostics`   | `tests/diagnostics/**/*.pas`        | 调用宿主 `fpc`，预期失败，并对比 canonical text      |
| `rtl`           | `tests/rtl/*_smoke.pas`             | 调用宿主 `fpc` 编译，再真实运行二进制                |
| `crt`           | `tests/crt/*_smoke.pas`             | 调用宿主 `fpc` 编译，再真实运行二进制                |
| `regression`    | `tests/regression/*_regression.pas` | 调用宿主 `fpc` 编译，再真实运行二进制                |

这意味着 fixture 收集规则已经是公开契约的一部分，而不是 runner 内部的临时实现细节。

对当前 `compiler-pass` / `compiler-fail` 组，runner 还已经固定这条真实控制面：

- `tests/run_all_tests.sh` 会先把 `tools/stage0/nextpas.pas` 自举到
  `.sisyphus/tmp/stage0-bootstrap/nextpas`
- runner 会通过 `NEXTPAS_STAGE0` / `NEXTPAS_WORKSPACE_ROOT` 消费这条 scratch-built 控制面
- 每个 fixture 都会显式传入 `--workspace <repo-root>`
- `compiler-pass` fixture 还会显式传入 per-fixture `--out-dir .sisyphus/tmp/harness/<fixture-token>/bin`

这条设计的意义很直接：测试 runner 不再依赖源码树旁边“碰巧有一个可执行 `tools/stage0/nextpas`”。

## `smoke` 必须执行真实 fixture，而不是只检查库存

第一阶段之后，`./tests/run_all_tests.sh --filter smoke` 至少要满足这些要求：

- 真实执行每个 group 的最小 fixture
- 对每个 group 输出 `fixtures=<n>` 与 `executed=<n>`
- 对 snapshot-bearing groups 继续输出 `snapshot=ready|missing|unstable`
- 汇总 `missing-fixtures`、`missing-snapshots`、`unstable-snapshots` 和 `group-failures`

也就是说，`smoke` 不再允许退化成下面这些假绿路径：

- 只数目录里有多少 `.pas`
- 只看 `tests/snapshots/` 里有没有同名文件
- 只因为 runner 或 snapshot 文件存在就返回 success

如果 `compiler-pass`、`rtl`、`crt`、`regression` 没有真实跑过，`smoke passed` 就不成立。

## 公开结果语义必须分成三条线

`harness` 当前至少要把这三类对象分开：

- `CommandResultEnvelope`
  - 回答命令级 outcome、selector、status、result 和 human summary
- diagnostics snapshot
  - 回答稳定的 text-baseline 是什么
- build / run evidence
  - 回答真实执行产物、build output 与 run output 落在哪里

当前仓库里已经落地的 machine-readable bridge 是：

```text
command-envelope=<json>
```

与此同时，line-based projection 继续保留这些字段，方便本地回放和 CI grep：

- `fixture-result=...`
- `executed-fixture-count=...`
- `passed-fixture-count=...`
- `failed-fixture-count=...`
- `snapshot-status=...`
- `smoke-group=...`
- `command-outcome=success|failure`
- `human-summary=...`
- `bootstrap-step=...`（仅 bootstrap failure 路径）
- `bootstrap-command=...`（仅 bootstrap failure 路径）
- `bootstrap-stderr-file=...`（仅 bootstrap failure 路径）

这里的重点是：shell projection 可以继续存在，但它不再替代真实执行和结果对象本身。
同样，bootstrap failure 也不能再只留下一个 failure kind；当前如果 stderr 文件非空，
shell 层还必须直接回显原始 stderr evidence，保证失败可回放。

## snapshot-bearing groups 必须比较 canonical actual text

当前 `compiler-fail` 与 `diagnostics` 是 snapshot-bearing groups。它们当前必须满足：

- fixture 真实执行后，生成 canonical actual text
- canonical actual text 与 snapshot 基线逐字节比较
- 缺少 snapshot 时，写出 `tests/snapshots/*.diff.txt`
- snapshot mismatch 时，也写出 `tests/snapshots/*.diff.txt`
- 输出必须显式暴露 baseline locator：
  `snapshot-entry=<key> fixture=<path> status=<...> path=<snapshot> diff=<diff>`

这条规则的目标是让失败能被回放，而不是只剩一句“snapshot 不对”。

## runner bootstrap 和临时产物不再写回源码树

runner bootstrap 现在固定输出到：

```text
.sisyphus/tmp/harness/bootstrap/runner
```

`stage0` bootstrap 当前固定输出到：

```text
.sisyphus/tmp/stage0-bootstrap/nextpas
```

fixture 相关的 build / run evidence 当前固定输出到：

```text
.sisyphus/tmp/harness/<fixture-token>/
```

而 bootstrap failure 的 stderr evidence 当前固定写到：

```text
.sisyphus/tmp/stage0-bootstrap/*.stderr.txt
```

这条布局有两个目的：

- 避免 runner、自举产物和 host-backed 二进制继续污染 `tests/` 源码目录
- 避免 fixture collection 被历史生成物反向干扰

因此，源码树本身不再承担临时构建目录的职责。

对应到 `compiler-pass` 组，这还意味着：

- fixture binary 不再回写到 `tests/compiler/pass/` 目录
- stage0 产物和 host FPC scratch 不再落在 fixture 邻近源码目录
- source tree 是否“脏”不再反向影响 fixture collection

Linux x86_64 baseline 的 stage0 target artifact 运行路径还必须和本地验证保持一致：
如果产物请求的 ELF interpreter 是 `/lib/ld64.so.1`，而当前 host 缺少这个 interpreter，
但 `/lib64/ld-linux-x86-64.so.2` 可执行，runner 可以通过该 loader 显式运行目标产物。
这条 fallback 只适用于 stage0 生成的 target artifact run；宿主 `fpc`、`stage0`
驱动本身，以及 `rtl` / `crt` / `regression` 等 host-backed fixture 仍按普通进程直接运行。

## `harness` 和 `stage0`、本地验证、CI 的关系

- `compiler-pass` 与 `compiler-fail` 当前已经通过 `stage0 build` 进入真实 nextPas 控制面
- `build/verify_local.sh` 当前必须复用 `./tests/run_all_tests.sh --filter smoke`
- Linux CI 当前直接复用 `./build/verify_local.sh`

也就是说，本地验证和 CI 现在都应该建立在同一条 `harness` 结果语义之上，而不是各自维护一套
只在自己环境里碰巧成立的判断规则。

## 这里必须诚实保留 host-backed 边界

当前 `harness` 不应该把所有 group 都说成“已经由 nextPas 完全接管”。

现实边界是：

- `compiler-pass` / `compiler-fail` 已进入 nextPas `stage0 build`
- `diagnostics` / `rtl` / `crt` / `regression` 仍然由宿主 `fpc` 执行

这不是缺点，而是当前阶段的诚实边界。文档必须写清楚，否则 CI 的绿灯会被误读成
“nextPas 已经独立接管全部编译与运行路径”。

## 第一阶段非目标

- 不把 `harness` 扩成并行调度器或分布式测试平台
- 不提前为 Windows 或 macOS 写分支
- 不让 `smoke` 重新退化成目录和 snapshot 存在性检查
- 不把 trace、snapshot 和最终命令结果再次揉成一份模糊文本
- 不把 host-backed group 过度包装成 nextPas 已完全接管的能力声明

第一阶段真正要交付的，是一套可信、可回放、和当前实现一致的验证控制面。
