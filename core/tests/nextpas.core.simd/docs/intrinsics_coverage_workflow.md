# SIMD Intrinsics 覆盖检查工作流

## 目标

为当前 live intrinsics carrier 建立“接口声明 ↔ direct-test 引用”映射检查，避免后续迭代出现新增接口未补低层测试的情况。

## 检查脚本

- 脚本：
  - `tests/nextpas.core.simd/check_intrinsics_coverage_layout_contract.py`
  - `tests/nextpas.core.simd/check_intrinsics_coverage.py`
- 检查范围：
  - `src/nextpas.core.simd.intrinsics.sse.pas`
  - `src/nextpas.core.simd.intrinsics.mmx.pas`
  - `src/nextpas.core.simd.intrinsics.avx2.pas`
  - `src/nextpas.core.simd.intrinsics.aes.pas`
  - `src/nextpas.core.simd.intrinsics.sha.pas`
  - `src/nextpas.core.simd.intrinsics.x86.sse2.pas`
  - 当前 live carrier：
    - `tests/nextpas.core.simd/nextpas.core.simd.intrinsics.avx2.testcase.pas`
    - `tests/nextpas.core.simd/nextpas.core.simd.sse2contracts.testcase.pas`
    - `tests/nextpas.core.simd/nextpas.core.simd.sse3_correctness.testcase.pas`
    - `tests/nextpas.core.simd/test_mmx_raw_leaf_parity/test_mmx_raw_leaf_parity.lpr`
    - `tests/nextpas.core.simd/test_sse_raw_leaf_parity/test_sse_raw_leaf_parity.lpr`
    - `tests/nextpas.core.simd/test_sse2_raw_leaf_parity.pas`
    - `tests/nextpas.core.simd.intrinsics.experimental/nextpas.core.simd.intrinsics.experimental.testcase.pas`

> `symbol_ref` coverage 直接扫描源码文本，不会预处理 `{$I ...}` wrapper。对采用“顶层兼容 wrapper + 子目录 canonical project”布局的测试，carrier 应指向 canonical `.lpr` / `.pas`，而不是顶层 include wrapper。

脚本输出字段：

- `declared`：接口声明数
- `tested`：被 current carrier 直接引用的声明数
- `missing`：声明存在但缺少同名测试
- `extra`：测试存在但无同名声明（通常是组合/别名测试）
- `thin`：已命中但引用密度仍低于当前阈值的符号
- `carrier`：当前用于聚合统计的 live test carrier

> 判定规则：required 模块以 `missing_required=0` 为通过条件；optional tracked 模块会报告
> `missing_optional`，但默认不阻塞。启用对应 `--require-*` 开关后，optional 模块才进入
> required blocker。

## 运行方式

### 默认 coverage

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh coverage
```

该入口先跑 `check_intrinsics_coverage_layout_contract.py`，再跑 live `check_intrinsics_coverage.py`。默认只把 `sse`、`mmx`、`sse2-x86-raw` 作为 required blocker；`avx2`、`aes`、`sha` 会被统计，但默认是 optional tracked coverage。

### Windows

```bat
tests\nextpas.core.simd\buildOrTest.bat coverage
```

> 当前 worktree 已恢复 `BuildOrTest.sh coverage`；它会先跑 `check_intrinsics_coverage_layout_contract.py`，再跑 live `check_intrinsics_coverage.py`。
> 当前本地可执行 helper：`BuildOrTest.sh coverage`、`BuildOrTest.sh wiring-sync`、`BuildOrTest.sh nonx86-ieee754`、`BuildOrTest.sh perf-smoke`、`run_backend_benchmarks.sh`、`BuildOrTest.sh gate-summary-selfcheck`、`BuildOrTest.sh freeze-status-linux`。
> 当前 historical `evidence-linux` / `gate` / `gate-strict` shell mainline 仍未恢复。
> 以当前 HEAD 为准，默认 required coverage 是 `sse` 79/79、`mmx` 75/75、`sse2-x86-raw` 221/221，`missing_required=0 missing_optional=0`。

## Strict 与 closure 入口

默认模式只要求 required 模块没有缺口。

如需把 `extra`（测试名无同名声明）也作为失败条件，可启用 strict 模式。

历史 `2026-02-08` 的 `sse/mmx missing=0, extra=0` 基线已不再代表当前树；当前应以 live checker 输出为准，不再沿用旧日志当真值。

```bash
SIMD_COVERAGE_STRICT_EXTRA=1 bash tests/nextpas.core.simd/BuildOrTest.sh coverage
```

如需把 experimental AES/SHA direct-test coverage 提升为 required：

```bash
SIMD_COVERAGE_STRICT_EXTRA=1 SIMD_COVERAGE_REQUIRE_EXPERIMENTAL=1 bash tests/nextpas.core.simd/BuildOrTest.sh coverage
```

如需同时把 AVX2 也提升为 required：

```bash
SIMD_COVERAGE_STRICT_EXTRA=1 SIMD_COVERAGE_REQUIRE_AVX2=1 SIMD_COVERAGE_REQUIRE_EXPERIMENTAL=1 bash tests/nextpas.core.simd/BuildOrTest.sh coverage
```

`BuildOrTest.sh experimental-intrinsics-tests` 运行 dedicated AES/SHA experimental runner：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh experimental-intrinsics-tests
make -C core/tests/nextpas.core.simd experimental-intrinsics-focused
```

Makefile focused 入口是 `make -C core/tests/nextpas.core.simd experimental-intrinsics-focused`。

当前 `experimental-intrinsics-focused` 还会运行 forced non-x86 AES import/fail-close probe：
它在本机编译 `nextpas.core.simd.intrinsics.aes` import/call surface，并通过
test-only guard 证明调用会 fail-close。This is not real non-x86 runtime evidence；
真实 non-x86 runtime 仍必须依赖 QEMU 或目标机证据。

`BuildOrTest.sh experimental-intrinsics-closure` 是显式 opt-in closure gate。它会串行执行：

1. `BuildOrTest.sh check`
2. `SIMD_COVERAGE_STRICT_EXTRA=1 SIMD_COVERAGE_REQUIRE_AVX2=1 SIMD_COVERAGE_REQUIRE_EXPERIMENTAL=1 BuildOrTest.sh coverage`
3. `check_intrinsics_experimental_status.py --summary-line`
4. `BuildOrTest.sh experimental-intrinsics-tests`

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh experimental-intrinsics-closure
make -C core/tests/nextpas.core.simd experimental-intrinsics-closure
```

closure 固定启用 `SIMD_COVERAGE_STRICT_EXTRA=1`、`SIMD_COVERAGE_REQUIRE_AVX2=1`、`SIMD_COVERAGE_REQUIRE_EXPERIMENTAL=1`。当前 strict closure truth 是 `aes` 6/6、`sha` 7/7，且 stable/default coverage 仍保持 `missing_required=0 missing_optional=0`。

当前 experimental intrinsics tests 不进入 default stable/nightly blocker；默认口径只保护 experimental isolation，runtime experimental tests 通过显式 closure gate 收口。

Experimental closure proof is not stable public semantic proof. AESENC, AESENCLAST, AESDEC, AESDECLAST, AESKEYGENASSIST standard-rcon, and AESIMC each have hardware semantic evidence
for `aes_aesenc_si128`, `aes_aesenclast_si128`, `aes_aesdec_si128`, `aes_aesdeclast_si128`,
`aes_aeskeygenassist_si128`, and `aes_aesimc_si128`
on `CPUX86_64 + simd_has_aes`; `aes_aeskeygenassist_si128` is limited to the
AES key schedule rcon subset, and unsupported rcon values fail-close. SHA coverage 当前只证明
显式 opt-in runner 在 `CPUX86_64 + simd_has_sha` 条件下有 smoke-only availability checks；
SHA smoke-only availability checks are not SHA semantic vectors。更多 AES-NI / SHA-NI semantic
vectors 必须另起 focused slice，并带硬件 evidence 或明确的 skip/host-capability 边界。

## Linux 证据一键收集

历史上可通过 `evidence-linux` action 串行收集一批完整 Linux closeout 证据（coverage/strict/advanced/backend-bench/perf/gate-summary/freeze-status-linux）：

当前 worktree 中，这条 historical shell mainline 仍保持 fail-close；若只是本地继续复验 Linux 证据面，请按上面的细粒度 helper 串行执行，并直接调用 `tests/nextpas.core.simd/run_backend_benchmarks.sh` 补 bench 证据。

当前仓库没有 dedicated SIMD nightly workflow 文件。不要把 `evidence-linux`、Windows B07 证据或 `gate-strict` 写成已恢复的 CI blocker；本 worktree 当前的真实 Linux 复验方式是按 `coverage`、`experimental-intrinsics-closure`、`wiring-sync`、`nonx86-ieee754`、`perf-smoke`、`gate-summary-selfcheck`、`freeze-status-linux` 等细粒度 helper 串行执行。

如果未来恢复 dedicated nightly closeout workflow，必须先恢复对应 workflow 文件与 shell mainline，再同步更新本页和 `check_linux_evidence_shell_surface.py` 的 source-contract。


## Wiring 对账与门禁摘要

`non-x86` 的 wiring 对账支持独立运行与门禁内可选强约束。

### Linux/macOS

```bash
# 独立对账（strict）
SIMD_WIRING_SYNC_STRICT_EXTRA=1 bash tests/nextpas.core.simd/BuildOrTest.sh wiring-sync

# check 默认会跑 wiring-sync；如需 strict-extra，再叠加这个环境变量
SIMD_WIRING_SYNC_STRICT_EXTRA=1 bash tests/nextpas.core.simd/BuildOrTest.sh check

# 查看 gate 摘要
bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary
```

默认产物：
- 文本日志：`tests/nextpas.core.simd/logs/wiring_sync.txt`
- JSON 快照：`tests/nextpas.core.simd/logs/wiring_sync.json`
- gate 摘要：`tests/nextpas.core.simd/logs/gate_summary.md`
- `gate_summary.md` 列：`Time / Step / Status / DurationMs / Event / Detail / Artifacts`
- 事件标记：`NORMAL / SLOW_WARN / SLOW_CRIT / FAILED / SKIP`
- 阈值：`SIMD_GATE_STEP_WARN_MS`（默认 20000）与 `SIMD_GATE_STEP_FAIL_MS`（默认 120000）

### Windows

```bat
tests\nextpas.core.simd\buildOrTest.bat wiring-sync
tests\nextpas.core.simd\buildOrTest.bat check
set SIMD_GATE_WIRING_SYNC=1 && tests\nextpas.core.simd\buildOrTest.bat gate
tests\nextpas.core.simd\buildOrTest.bat gate-summary
```

如需临时关闭 `check` 里的这条默认对账，显式设置 `SIMD_CHECK_WIRING_SYNC=0`。


### historical gate 失败链路记录（Linux）

Historical `BuildOrTest.sh gate` 曾将关键步骤写入 `gate_summary.md`，包含 `PASS/FAIL/SKIP`。当前 `gate` mainline 仍是 fail-close placeholder；如果需要复验摘要导出和过滤能力，请直接运行 `gate-summary-selfcheck`，不要把 historical `gate` 当成 live Linux command。

可选参数：
- `SIMD_GATE_SUMMARY_FILE`：自定义摘要文件路径
- `SIMD_GATE_SUMMARY_APPEND=1`：追加到已有摘要（默认每次 gate 重置摘要）
- `SIMD_GATE_SUMMARY_TAIL=120`：`gate-summary` 查看尾部行数
- `SIMD_WIRING_SYNC_JSON=0`：关闭 wiring-sync JSON 快照生成
- `SIMD_GATE_SUMMARY_FILTER=ALL|FAIL|SLOW`：`gate-summary` 视图过滤（默认 `ALL`）
- `SIMD_GATE_SUMMARY_JSON=1`：导出 machine-readable 摘要 JSON（需 Python 运行时；缺失时 fail-close）
- `SIMD_GATE_SUMMARY_JSON_FILE`：自定义摘要 JSON 路径（默认 `tests/nextpas.core.simd/logs/gate_summary.json`）
- `BuildOrTest.sh gate-summary-selfcheck`：快速自检 gate-summary 过滤/导出能力
- 共享导出器：`tests/nextpas.core.simd/export_gate_summary_json.py`
- `SIMD_GATE_SUMMARY_MAX_DETAIL=260`：限制 detail 长度，避免超长表格
- `SIMD_GATE_SUMMARY_APPLY=1`：`gate-summary-inject` 将样本覆盖到当前摘要（默认非侵入 shadow）
- `SIMD_GATE_SUMMARY_BACKUP_FILE=<path>`：`gate-summary-rollback` 指定回滚备份文件
- 失败传播语义：`gate` 对步骤采用 fail-fast，首个失败 step 会立即终止 gate 并写入 `failed-step=<step>`
- 强制失败演练当前不通过 historical `gate` 入口执行；需要恢复时，先恢复 shell mainline，再同步更新本页和 source-contract。


## gate-summary 诊断手册（Linux）

### 快速查看失败步骤

```bash
SIMD_GATE_SUMMARY_FILTER=FAIL bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary
```

### 快速查看慢步骤

```bash
SIMD_GATE_SUMMARY_FILTER=SLOW bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary
```

### 导出 JSON 给脚本消费

```bash
SIMD_GATE_SUMMARY_FILTER=FAIL SIMD_GATE_SUMMARY_JSON=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary
```

输出：`tests/nextpas.core.simd/logs/gate_summary.json`

若启用 `SIMD_GATE_SUMMARY_JSON=1` 但当前环境缺少 Python 运行时，`gate-summary` 会直接返回非零，避免把“未导出 JSON”误判成成功。

### 排障建议

1. 先看 `FAIL` 视图定位首个失败 step。  
2. 再看 `SLOW` 视图识别慢链路（`SLOW_WARN/SLOW_CRIT`）。
3. 用 `Artifacts` 列直接跳转相关日志（`build.txt/test.txt/wiring_sync*.txt/json`、`run_all_tests_summary_sh.txt`）。  
4. 如 detail 过长，用 `SIMD_GATE_SUMMARY_MAX_DETAIL` 控制摘要长度。  


### gate-summary 自检（Linux）

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-selfcheck
```

用途：在不跑全量 gate 的情况下，快速验证 `ALL/FAIL/SLOW` 过滤与 JSON 导出链路是否可用。

### freeze-status 自检（Linux）

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status-rehearsal
```

用途：在本地构造“NOT READY/READY”双场景，验证冻结判定逻辑不会回归。


### gate-summary 样本与阈值演练（Linux）

```bash
# 生成可控 FAIL 样本
bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-sample fail

# 生成可控 SLOW 样本
bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-sample slow

# 执行阈值回归演练（FAIL/SLOW/JSON）
bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-rehearsal
```

可选阈值参数（演练脚本）：
- `SIMD_REHEARSAL_WARN_MS`（默认 `10000`）
- `SIMD_REHEARSAL_FAIL_MS`（默认 `15000`）

演练产物目录：`tests/nextpas.core.simd/logs/rehearsal/`


### gate-summary 样本与阈值演练（Windows 脚本层）

```bat
:: 生成样本
set SIMD_GATE_STEP_WARN_MS=10000 && set SIMD_GATE_STEP_FAIL_MS=15000 && tests\nextpas.core.simd\buildOrTest.bat gate-summary-sample slow

:: 运行演练（依赖 bash）
tests\nextpas.core.simd\buildOrTest.bat gate-summary-rehearsal
```


### 非侵入式注入与一键回滚（Linux）

```bash
# 1) 非侵入式注入（默认只生成样本，不改当前 gate_summary.md）
bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-inject fail

# 2) 应用注入（先备份再覆盖）
SIMD_GATE_SUMMARY_APPLY=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-inject slow

# 3) 查看备份列表
bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-backups

# 4) 一键回滚（默认恢复最新备份）
bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-rollback
```

脚本：
- `tests/nextpas.core.simd/inject_gate_summary_sample.sh`
- `tests/nextpas.core.simd/rollback_gate_summary_sample.sh`
- `tests/nextpas.core.simd/list_gate_summary_backups.sh`


### 非侵入式注入与一键回滚（Windows 脚本层）

```bat
:: 非侵入式注入（默认）
tests\nextpas.core.simd\buildOrTest.bat gate-summary-inject fail

:: 应用注入（覆盖前自动备份）
set SIMD_GATE_SUMMARY_APPLY=1 && tests\nextpas.core.simd\buildOrTest.bat gate-summary-inject slow

:: 查看备份
tests\nextpas.core.simd\buildOrTest.bat gate-summary-backups

:: 回滚最近备份
tests\nextpas.core.simd\buildOrTest.bat gate-summary-rollback
```
