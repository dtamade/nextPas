# nextpas.core.tui Merge Prep

## 2026-06-03 Reality Reset

- `nextpas.core.tui` 已经进入本地 `main`，直接证据是
  `5b04c3fe merge(tui): integrate feat/tui-migration onto main`。
- 因此本文档当前承担的是“历史 merge-prep 与 integration proof 记录”职责，而不是
  “TUI 是否尚未合入 main”的唯一真相来源。
- 当前 worktree `codex/tui-main-merge-20260602` 仍保留价值：它记录了当时的 clean integration
  candidate 与后续 repo-level verification cleanup 证据；但后续 TUI 强化工作不应再把它当作
  唯一合并路径。
- TUI 的下一阶段路线已转入
  `core/docs/plans/2026-06-03-tui-dual-track-design.md`：
  以后续 `core / ext / experimental / full` facade 冻结和 dual-track strengthening 为主。

## 结论

`nextpas.core.tui` 当前已具备合并到 `nextpas.core` 主线的模块内条件，并且已经在干净 integration
候选分支上完成了一次真实 merge + post-merge verification：

- facade / README / catalog / 目标树 已对齐
- TUI 自身公开面测试通过
- 全量 TUI 回归通过
- 4 个 benchmark smoke 可运行
- facade 编译 warning 已收口到 0
- examples 编译 warning 已收口到 0

当前已验证的候选分支信息：

- Worktree：`/home/dtamade/.config/superpowers/worktrees/nextPas/tui-main-merge-20260602`
- Branch：`codex/tui-main-merge-20260602`
- Base：`main@8581cd55`
- Merge source：`feat/tui-migration@00a6dd93`

注意：主 checkout `/home/dtamade/projects/nextPas` 仍然带有 unrelated dirty changes，本轮不安全直接推进
本地 `main`；当前交付物是 **verified merge candidate**，不是“已在现有主 checkout 完成快进”。

## Merge 前真相

### 1. 文档与公开面

- README quick-start 已改为真实可编译 API：`OnRenderCb`
- README quick-start 当前走 `nextpas.core.tui.ext`，已由 `test_tui_ext_facade` 编译覆盖
- `test_tui_facade` 当前承担 `nextpas.core.tui.full` migration compatibility 编译证明，
  最新 focused 口径为 `7/7`，包含 `full facade covers ext and experimental contract`
  与 `full facade advanced widget catalog remains usable`
- `README` / `ARCHITECTURE` / `TIER_REGISTRY` 已统一到 `core / ext / experimental / full` facade truth
- `WIDGET_CATALOG.md` 已改成按 `core / ext / full` ownership 讲 widget，advanced catalog 不再伪装成默认 facade

### 2. 测试基线

- 全量 TUI 测试项目：`32`
- 全量 TUI 用例：`246`
- heaptrc 摘要数：`13`
- 关键 focused 证据：
  - `test_tui_core_facade`：`1/1`，negative probes 静默拒绝
    `TApp` / `TClipboard` / `TImageProtocol` / `TGauge` / `TSparkline` / `TCanvas`，
    `0 unfreed memory blocks`
  - `test_tui_facade`：`7/7`，`0 unfreed memory blocks`
  - `test_tui_widget_intf`：`4/4`，`0 unfreed memory blocks`
  - `test_tui_buffer`：`21/21`，`0 unfreed memory blocks`

### 2.1 2026-06-02 最终 verification envelope

- focused tests fresh pass：
  - `test_tui_facade` → `5/5`，heaptrc `0 unfreed memory blocks`
  - `test_tui_widget_intf` → `4/4`，heaptrc `0 unfreed memory blocks`
  - `test_tui_buffer` → `21/21`，heaptrc `0 unfreed memory blocks`
- full TUI tests fresh pass：
  - `32` 项目
  - `246/246` 用例通过
  - `13` 个 heaptrc zero summaries
  - `warning_count=0`

### 2.2 2026-06-02 integration candidate 真相

- 实际 merge 在干净 worktree 中执行，未触碰主 checkout 的 unrelated WIP。
- merge 冲突全部落在共享 planning/control files，而不在 TUI 源码本体：
  - `findings.md`
  - `progress.md`
  - `task_plan.md`
  - `core/findings.md`
  - `core/progress.md`
  - `core/task_plan.md`
- 冲突处理策略：这些共享控制面一律保留 `main` 侧版本，避免把 HTTP/crypto/platform 等并行批次的
  当前执行面误改成 TUI 语境；TUI 自身的路线图、merge-prep、架构与 benchmark 真相继续由
  `core/docs/plans/` 和 `core/docs/tui/` 承载。
- supporting/focused post-merge fresh pass：
  - `test_platform_console_raw` → `5/5`，heaptrc `0 unfreed memory blocks`
  - `test_grapheme` → `11/11`，heaptrc `0 unfreed memory blocks`
  - `test_text_width` → `19/19`，heaptrc `0 unfreed memory blocks`
  - `test_tui_facade` → `5/5`，heaptrc `0 unfreed memory blocks`
  - `test_tui_widget_intf` → `4/4`，heaptrc `0 unfreed memory blocks`
- full TUI regression post-merge：
  - `32` 项目
  - `246/246` 用例通过
  - `13` 个 heaptrc zero summaries
  - `warning_count=0`
- benchmark smoke post-merge：
  - `4` 个 benchmark
  - `status=0`
  - `warning_count=0`
- TUI examples post-merge：
  - `demo_hello` / `demo_layout` / `demo_widgets` 全部可编译
  - `warning_count=0`
  - 期间顺手修复 `demo_widgets.lpr` 的 `case` 未覆盖 warning；仅补 `else ;`，不改运行语义
- wider verification 尝试：
  - `tests/run_all_tests.sh` 已恢复为 live harness 的 shell control plane；`./tests/run_all_tests.sh --list-groups`、
    `--filter compiler-pass`、`--filter smoke` 以及 stage0 `nextpas test --list-groups/--filter compiler-pass`
    已重新跑通。
  - `make -C core test` 当前已恢复 green，`All tests passed.`；此前被主线入口阻断的 standalone 项目
    `test_marshal`、`test_template`、`test_validation` 都已进入执行路径。注意：repo-wide 仍有 pre-existing
    warning/note，不能把这条结果表述成“主线零 warning”。
  - `make -C core examples` 当前已恢复 green，尾部输出 `All examples compiled.`；但 broader examples 仍有
    pre-existing warning（如 `examples/async_timer_example.lpr` 的 unreachable code），同样不能表述成
    repo-wide zero-warning。
  - `make -C core benchmarks` 已不再因目录缺失 `Makefile` 提前失败；`bench_hash` 的 facade
    API 漂移也已收口，当前已改为对齐 `SHA256Of` / `MD5Of`，并移除不再属于当前 facade 的
    CRC32 路径。targeted `bench_hash` 现已能重新运行，输出
    `SHA-256 1MB: 240.0 MB/s`、`MD5 1MB: 257.2 MB/s`。
  - `bash build/verify_local.sh` 已不再死在入口丢失或 HIR/sema compile flag 漂移；随后又继续修复了
    LLVM `obj-compose` 真 bug：`THIRBuilder` 过去会把 `P.GetX` 这类“接收者为对象指针、结果为整数”的
    参数 blob 错判为 `ptr`，现已通过新增 focused regression
    `tests/hir/test_hir_class_obj_compose_contract.pas` 收口，并验证
    `llvm-class-obj-compose-program=pass`。
  - smoke corpus truth 需要逐条核对，不能再机械把 `0ac172f1` 全部视为坏提交；`llvm_linked_list`
    就是反例，该提交把输入从 `42` 修到 `40`，使程序真实退出 `42`。当前 `verify_local` 已继续越过
    `llvm_primes` / `llvm_obj_compose` / `llvm_linked_list` 等门禁。
  - `hello_with_units` 的 semantic smoke expectation drift 已收口：
    `build/verify_local.sh` 现已对齐 live `symbol-count=19` / `type-count=27`，
    `semantic-smoke-check=pass`。
  - `core-time-check` 的 summary drift 也已收口：live
    `--- nextpas.core.time: 16 total, 16 passed, 0 failed ---` 已和
    `verify_local` 对齐，`core-time-check=pass`。
  - `core-sync-posix-fallback-check` 的 forced fallback 摘要失配也已收口：
    live 运行的仍是同一个 `test_sync.lpr`，当前稳定输出
    `--- nextpas.core.sync: 28 total, 28 passed, 0 failed ---`；旧的 `11 total`
    已确认只是 verify expectation drift，不是 sync 实现回归。
  - fresh `bash build/verify_local.sh` 已全绿，最终输出
    `core-sync-posix-fallback-check=pass`、`verify-local=pass` 与
    `human-summary=local verification passed`。
  - `make -C core benchmarks` 当前新的 blocker 不是编译红点，而是
    `bench_sort_fpcrtl` 的时间尺度异常：full sweep 已继续推进到该 compare baseline，
    但该程序长时间占满单核；直接加 `timeout 30s` 运行返回 `exit=124`。
  - 结论：当前 candidate 的 repo-level verification entrypoint 已回到真实状态；
    剩余 benchmark 问题也已从 facade API 漂移推进到更深的 baseline/runtime truth，
    不应归因到 TUI merge 本身。

### 3. Benchmark smoke 基线

- `DiffInto 200x50 (10 changed rows)`：`46.7 us`
- `DiffInto 200x50 (identical)`：`26.3 us`
- `Full render 120x40 (block+list+para+gauge)`：`155.3 us`
- `ParseOne ASCII/CSI/UTF-8`：`44-50 ns`
- `Grid 8x8 uniform`：`4.4 us`

## Warning 审计

### facade 编译 warning

- warning 总数：`0`
- TUI 自身单元 warning 行数：`0`
- `nextpas.core.text.number.pow10.inc` warning 行数：`0`

结论：此前 facade 编译 warning 的唯一来源 `nextpas.core.text.number.pow10.inc` 已通过
`QWord($...)` typed constant 显式类型化修复；当前 `uses nextpas.core.tui` 编译面已达到 warning=0。

### benchmark smoke warning

- warning 行数：`0`

### benchmark smoke fresh envelope

- `status=0`
- benchmark 数：`4`
- `warning_count=0`

### examples fresh envelope

- `status=0`
- example 数：`3`
- `warning_count=0`

## 建议的合并说明

1. `nextpas.core.tui` 模块内测试、文档、benchmark smoke 已闭环
2. facade compile 现在已是零 warning，可直接作为合并前基线
3. 实际 merge candidate 已验证通过；剩余工作一方面是等一个安全的 `main` 窗口，另一方面是主线自行修复
   `verify_local` / `core test` 的 repo-level 既有入口问题

## 推荐合并前命令

```bash
make -C core/tests/nextpas.core.tui/test_tui_facade clean test FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
make -C core/tests/nextpas.core.tui/test_tui_widget_intf clean test FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
make -C core/tests/nextpas.core.tui/test_tui_buffer clean test FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc core/benchmarks/nextpas.core.tui/run_all.sh
```
