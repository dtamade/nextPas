# nextpas.core.simd 极简行动清单

这页只回答两件事：现在应该做什么，以及现在不要做什么。

## 当前状态（2026-05-21）

- 当前 `simd` 不应再按“接口/实现仍未收口”处理。
- 最新 release 证据说明：
  - `python3 tests/nextpas.core.simd/check_interface_implementation_completeness.py --strict` 仍为绿，`P0/P1/P2=0`
  - 最新 `freeze-status` 已是：
    - `ready=True`
    - `mainline-ready=True`
    - `cross-ready=True`
  - 其中关键 closeout 项都已经 PASS：
    - `cross_gate_required_steps`
    - `linux_qemu_cpuinfo_nonx86_evidence`
    - `windows_preflight_latest`
    - `windows_evidence_verify`
    - `windows_sources_not_newer_than_evidence`
    - `windows_closeout_summary`
  - 当前 fresh Windows evidence 批次为 `SIMD-20260521-153`，对应 GH run `26230362365`
- 因此，当前 `HEAD` 更准确的状态应记为：
  - `code-green / cross-ready`
  - 到这里不要再把状态写成 `evidence-refresh-required` 或 `RECENT_BILLING_BLOCK`
- 当前最该记住的操作判断：
  - 默认不要再重开 closeout blocker 讨论；下一步应回到真实实现 residual、family qualification 或 raw-leaf qualification
  - 只有当 future `freeze-status` 再次变红时，才回到 evidence refresh 处理链
- 当前 public API 覆盖的 gate 判断也已固定：
  - canonical `public-api-coverage` 现在默认按 `strict-thin` 运行
  - future `thin > 0` 会直接让 `gate` / `gate-strict` 变红
  - 只有为了诊断历史薄点，才临时设 `SIMD_PUBLIC_API_TEST_COVERAGE_STRICT_THIN=0`；不要把非 strict 结果当 canonical green

补一条当前冻结判定纪律：

- 只要 `freeze-status` 仍是 `ready=True / cross-ready=True`，就不要把 billing / freshness 重新视为当前 blocker。
- 如果 future `freeze-status` 再次变红，再先看是不是 freshness blocker：
  - `linux_sources_not_newer_than_gate`
  - `windows_sources_not_newer_than_evidence`
- 只有在 future preflight 真正回到 `RECENT_BILLING_BLOCK` 时，才把 `windows_preflight_latest` 重新视为 blocker。

补一条当前判断规则：

- 如果最新 `freeze-status` 提示 gate artifact 旧于最新 `src/nextpas.core.simd*` 源码，先重跑 release `gate` 再判断，不要把旧 artifact 误读成新回归。
- 如果 latest `gate_summary.md` 以后又被 fast-gate 覆盖，导致 `qemu-cpuinfo-nonx86-evidence=SKIP`，先看 `logs/rehearsal/backups/` 或 `logs/windows-closeout/<batch>/gate_summary.md`；`freeze-status` 现在会自动回退到仍满足 closeout 口径的 gate snapshot。
- 如果 `closeout-host-local` 为绿，不要直接把它当成 `freeze-status` 绿：前者消费的是 `qemu-nonx86-evidence`，后者在当前口径下还额外要求 `qemu-cpuinfo-nonx86-evidence`。

## 现在应该做什么

### 0. 先确认这轮是不是“实现问题”而不是“接口命名焦虑”

当前 `SIMD` 的 façade/runtime/cpuinfo/dispatch/dataplane/public-ABI/direct 这一整条公开面与发布缝已经封边。没有新的语义 bug 证据时，不要再把时间花在接口命名、层次搬运、入口再分拆上；后续默认聚焦：

- 实现正确性
- 并发稳定性
- fallback / wiring 完整性
- non-x86 可移植性
- 证据链新鲜度

### 1. 先读这些文件

- `docs/simd/map.md`
- `docs/simd/maintenance.md`
- `docs/simd/handoff.md`
- `docs/simd/closeout.md`
- `docs/SIMD_LAYERING_IMPLEMENTATION.md`

### 2. 改代码前先定位层级

先问自己：你要改的是哪一层？

- 主入口：`simd.pas` / `api.pas`
- 控制真相：`dispatch.pas` / `cpuinfo.pas`
- 发布缝：`dataplane.pas` / `public_abi.impl.inc` / `direct.pas`
- 后端注册：多数看 `*.register.inc`；`SSE2` 直接看 `sse2.pas`
- 后端快路径：`*.facade.inc`
- 向量族实现：`*.family.inc`

### 3. 日常改动先跑快门禁

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh check
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DispatchAPI
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DirectDispatch
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh gate
```

上面这组里：

- `check`：编译卫生 + 基础 runner parity；现在还会 fresh 编译 `NEON/RISCVV` 的 opt-in `--list-suites` 路径，并带上 `check_riscvv_abi_shape.py`，专门防止 non-x86 opt-in compile drift / RISCVV hidden-result-pointer ABI 漂移再次躲过默认门禁
- 两个 `--suite`：最关键的 dispatch / direct 回归
- `gate`：日常改动使用的快门禁 / 基础门禁
- `public-api-coverage`：当前已不是“只看有没有测到”的宽松统计；默认就是 full-covered 且 `thin=0` 的 hard guard
- `public-operator-surface`：`check` / `gate` 中默认执行，锁住 unsigned `VecU*Add/Sub/Mul/And/Or/Xor/Not` 与 `nextpas.core.simd` operator 声明/实现/委派的一致性，覆盖 generated facade 声明和主门面手写补充面
- `gate`：现在默认还会重跑历史爆炸组合 `TTestCase_PublicAbi,TTestCase_SimdConcurrentPublicAbi,TTestCase_SimdConcurrentFramework`，用来盯住 runtime 发布 / public ABI / 并发框架交叉回归
- 如果你改的是 `runtime / cpuinfo / dataplane / façade` 这一层接口边界，优先再补两条：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_RuntimeAPI
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DataPlane
```

- `TTestCase_RuntimeAPI`：验证 canonical/legacy façade、`runtime` / `cpuinfo` 语义边界，以及 control-plane wrapper 一致性
- `TTestCase_DataPlane`：验证 data-plane published snapshot、direct dispatch 与 public ABI binding 一致性
- 如果你改的是当前 x86 bounded frontier 的实现证明面，优先再补一条：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh impl-smoke-x86
```

- `impl-smoke-x86`：固定重跑当前 x86 bounded frontier 的高价值 proof 集合；它不是 full closeout，而是按 `impl-smoke-sse2 -> DispatchAPI bounded frontier` 的顺序把 `SSE2 structure/contracts smoke`、`SSE2 compare/vector-math parity`、`SSE3/SSSE3/SSE4.x incremental clone + semantic parity contract`、`AVX512 shift boundary`、`AVX2 wide select`、`AVX2 wide FMA composition` 收成单条高频入口
- 如果你改了 `TSimdBackendInfo` / `TSimdDispatchTable` 的声明本身，再额外跑：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh contract-signature
```

- 如果你改了 public ABI wrapper 的声明、ABI 常量或 `publicabi_smoke.h` mirror，再额外跑：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh publicabi-signature
```

- 如果你只是手动跑 `interface-completeness` checker，默认产物现在应该进入 `tests/nextpas.core.simd/logs/interface_completeness.{json,md}`；只有在明确刷新 tracked doc 时，才显式传 `--md-file tests/nextpas.core.simd/docs/interface_implementation_completeness.md`

### 4. 准备 closeout / release 再跑完整门禁

`closeout-release` 是完整 release 收口的唯一官方入口：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh closeout-release SIMD-YYYYMMDD-152
```

内部固定顺序是 `win-evidence-preflight -> impl-smoke-x86 -> closeout-host-local -> win-evidence-via-gh -> freeze-status`。
它会先确认当前 Windows preflight 没被 Billing/额度阻塞；通过后再把 x86 bounded frontier 与 host-local non-x86/QEMU 证明跑到位，最后进入 Windows evidence GH 闭环并回到 canonical `freeze-status` 做最终确认。
但对当前 `HEAD`，更先要记住的是：这条主线已经 fresh 收口到 `cross-ready=True`。只有当 future `freeze-status` 再次红在 `linux_sources_not_newer_than_gate` 或 `windows_sources_not_newer_than_evidence` 时，才先补 fresh `gate` / fresh Windows evidence；只有当 future `win-evidence-preflight` 再次返回 `RECENT_BILLING_BLOCK` 时，才把那一轮状态记成 `code-green / release-evidence-blocked`。

如果你只想先看完整 release 门禁轮廓，而不是直接一波收口，也可以单独跑：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict
```

如果你要做的是当前 worktree 的 host-local strict closeout，而不是完整 Windows / native cross-arch release 收口，优先直接跑：

```bash
SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=0 FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh closeout-host-local
```

`closeout-host-local` 的固定顺序是 `impl-audit-nonx86 -> gate-strict`。当前口径下，它默认会把 `qemu-nonx86-evidence` 打开，并把 `SIMD_GATE_REQUIRE_NONX86_NATIVE_EVIDENCE` 降到 `0`；也就是说，在没有真实 `arm64/riscv64` 硬件时，`linux/arm64 + linux/riscv64` 的 QEMU runtime evidence 就是当前 closeout 的充分证明。
但这条证明只服务 host-local strict closeout。若目标是 canonical `freeze-status` / Windows finalize 主线，还要额外把 `qemu-cpuinfo-nonx86-evidence` 刷进最新 `gate_summary.md`，并补上 fresh Windows evidence verify；两者不要混写成同一条“Linux QEMU 已完成”。
`gate-strict` 会在 `gate` 的基础上额外打开 repeat、coverage/wiring strict、non-x86 / evidence 等更重的检查，更适合发布前或阶段性收口时运行。当前默认 release-gate 口径是 `SIMD_GATE_QEMU_NONX86_EVIDENCE=1`、`SIMD_GATE_REQUIRE_NONX86_NATIVE_EVIDENCE=0`；native evidence 仍可作为附加证据导入和校验，但没有硬件时，不再把 native host 当成 blocker。
当前默认 `gate` 已包含 `contract-signature` 与 `publicabi-signature` 结构护栏；如果仓库内 dispatch contract 或 public ABI wrapper 漂移，会直接在 gate 红掉。
当前默认 `check/gate` 也会把 non-x86 opt-in smoke 放到隔离子目录 `nonx86.optin/neon`、`nonx86.optin/riscvv` 下做 fresh `--list-suites` 编译验证；如果只想单独复验这层，也可以直接跑：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh nonx86-optin-list-suites
```

如果你正在收口 non-x86 register ownership / wiring truthfulness，直接跑对应 backend 的 checker：

```bash
python3 tests/nextpas.core.simd/check_nonx86_register_truthfulness.py --backend neon --summary-line --strict
python3 tests/nextpas.core.simd/check_nonx86_register_truthfulness.py --backend riscvv --summary-line --strict
```

当且仅当你显式打开 `SIMD_ENABLE_NEON_BACKEND=1` 或 `SIMD_ENABLE_RISCVV_BACKEND=1` 时，`BuildOrTest.sh check` 会自动跑 summary 版，`BuildOrTest.sh gate` 会自动跑 strict 版。

如果你做的是 non-x86 implementation audit，而不是只看单个 slot，优先直接跑聚合入口：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh impl-audit-nonx86
```

默认它会串行跑：helper semantics、`implementation-matrix-sync`、wiring-sync strict-extra、RISCVV ABI shape、`neon/riscvv` register truthfulness strict，以及 `DispatchAPI/DirectDispatch/DataPlane` release targeted suite。
其中 `key-slot-audit` 会把少量高价值 wide slot 明确分成两类契约再审一遍：`backend_owned` 必须真的由 backend register 接管，`reuse_base_scalar` 则必须继续继承 `FillBaseDispatchTable`，不能靠“误绑一个 wrapper”混过去。
当前 non-x86 implementation 主线的 backend/slot/契约/证据/下一步动作，请以 `docs/simd/implementation-matrix.md` 为准；后续审查优先沿这张矩阵推进，而不是散点翻文件。
如果你显式提供 `SIMD_NONX86_NATIVE_EVIDENCE_ROOT=...`，它还会把归档 native evidence verifier 一起带上；如果没提供，就只做 source/runtime-side implementation audit，不会伪装成 native runtime closeout。
如果你要拆开诊断，再单独跑下面这些底层 checker：

```bash
python3 tests/nextpas.core.simd/check_nonx86_helper_semantics.py --summary-line
python3 tests/nextpas.core.simd/check_nonx86_key_slot_audit.py --summary-line
python3 tests/nextpas.core.simd/check_nonx86_wiring_sync.py --summary-line
python3 tests/nextpas.core.simd/check_riscvv_abi_shape.py --summary-line
python3 tests/nextpas.core.simd/check_nonx86_register_truthfulness.py --backend neon --summary-line --strict
python3 tests/nextpas.core.simd/check_nonx86_register_truthfulness.py --backend riscvv --summary-line --strict
```

其中 `check_nonx86_helper_semantics.py` 现在会同时检查 helper/native-evidence，以及 compare/mask / shift/bitwise / arithmetic/minmax 的 source-side 语义矩阵：

- `Test_DirectDispatchTable_MultiBackend_SignedWideCompareMaskMatrix_Parity`
- `Test_WideCompareMaskParity_IfAvailable`
- `Test_WideSignedBitwiseShiftParity_IfAvailable`
- `Test_WideIntegerArithmeticMinMaxParity_IfAvailable`
- `Test_DataPlane_WideBitwiseShiftSnapshot_Follows_CurrentDispatchSemantics`
- `Test_DataPlane_WideArithmeticMinMaxSnapshot_Follows_CurrentDispatchSemantics`

non-x86 wiring grouped-batch assertions 现在统一收敛到 `AssertNonX86DispatchTableWiringGroupsAssigned`；`check_nonx86_wiring_sync.py` 会要求 legacy/grouped 两个入口都复用这一个 helper。

文档里的 `WiringGrouped` 标记、`Wiring grouped-batch assertions` 说明，以及 `Test_NonX86_DispatchTable_WiringChecklist_Grouped` 入口，现在都应该和这个共享 helper 一起维护，不再各自维护独立 slot 名单。

如果你手里正好有真实 `arm64` / `riscv64` 原生主机，native execution evidence 仍然有正式入口，但它现在是加分项，不再是当前 closeout 的必需前置：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh native-evidence
```

如果你在 `x86_64` worktree 上只是校验已归档的 native evidence，而不是重新采集原生 runtime 证据，正式 verifier 入口是：

```bash
SIMD_NONX86_NATIVE_EVIDENCE_ROOT=tests/nextpas.core.simd/fixtures/native-evidence \
bash tests/nextpas.core.simd/BuildOrTest.sh verify-nonx86-native-evidence
```

如果原生 `arm64` / `riscv64` 主机已经把 fresh evidence 目录拷回当前机器，最高效的回灌入口是直接导入 fixtures 并立刻跑 verifier：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh import-nonx86-native-evidence /path/to/native-evidence-drop
```

如果 `neon` / `riscvv` 结果分别放在两个不同目录，也可以一次传两个 source root：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh import-nonx86-native-evidence /path/to/arm64-drop /path/to/riscvv-drop
```

默认导入目标是 `tests/nextpas.core.simd/fixtures/native-evidence`；如需 dry-run 到临时目录，可设置 `SIMD_NONX86_NATIVE_EVIDENCE_IMPORT_DEST=/tmp/simd-native-import-123`。
如果你只是想对当前仓库里已经存在的 `fixtures/native-evidence` 重新跑一遍导入链路，现在也可以把它自己当 source root 传进去；脚本会识别“source 已经在目标目录里”，转成 verify-only no-op，而不是先删再拷。
`verify-nonx86-native-evidence` 失败时现在也会直接打印具体 `backend`、`summary.md` 和 `environment.txt` 路径，方便第一时间定位是哪份归档还旧。
同一条链路现在还会拒绝 synthetic / repackaged evidence：如果 `summary.md` header 时间戳和目录名不一致，或者 summary 带着 `/tmp/simd-import-smoke` 这类演练 marker，importer / verifier 会直接 fail-close。

如果你想在 `x86_64` worktree 上把“导入 external native evidence + verifier + host-local strict closeout”一波收掉，直接跑：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh closeout-host-local-from-import /path/to/native-evidence-drop
```

需要显式切到 backend-asm / direct-fpc 采集时，可再加：

```bash
SIMD_NATIVE_EVIDENCE_RUNNER=direct-fpc \
SIMD_NATIVE_EVIDENCE_ENABLE_BACKEND_ASM=1 \
bash tests/nextpas.core.simd/BuildOrTest.sh native-evidence riscvv
```

当前口径必须明确区分两类证据：

- x86_64 主机只能跑 source checker 和已归档 evidence verifier，不能把 `--list-suites`、compile-only，或 fixture 校验当成 fresh non-x86 runtime 证据：

```bash
python3 tests/nextpas.core.simd/check_nonx86_helper_semantics.py --summary-line
python3 tests/nextpas.core.simd/check_nonx86_key_slot_audit.py --summary-line
python3 tests/nextpas.core.simd/check_riscvv_abi_shape.py --summary-line
SIMD_NONX86_NATIVE_EVIDENCE_ROOT=tests/nextpas.core.simd/fixtures/native-evidence \
bash tests/nextpas.core.simd/BuildOrTest.sh verify-nonx86-native-evidence
```

- QEMU `qemu-nonx86-evidence` 现在会跑 `linux/arm64` / `linux/riscv64` 的 `TTestCase_NonX86BackendParity,TTestCase_DataPlane` runtime parity；在没有真实硬件时，这就是当前 arm64/riscv64 runtime closeout 的充分证明：

```bash
SIMD_QEMU_BUILD_POLICY=if-missing SIMD_QEMU_PLATFORMS='linux/arm64 linux/riscv64' FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh qemu-nonx86-evidence
```

- `freeze-status` / 手工 Windows closeout 主线现在还额外要求 QEMU CPUInfo cross evidence；它和上面的 runtime parity 不是同一条 lane：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh qemu-cpuinfo-nonx86-evidence
FAFAFA_BUILD_MODE=Release SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_QEMU_NONX86_EVIDENCE=0 SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 SIMD_GATE_CPUINFO_LAZY_REPEAT=3 SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate
```

- 当前最新真实状态是：`2026-05-21 22:55:37` 的 canonical gate 已把 `qemu-cpuinfo-nonx86-evidence`、`qemu-cpuinfo-nonx86-full-evidence`、`qemu-cpuinfo-nonx86-full-repeat` 全部刷成 PASS，且 full `freeze-status` 已 `ready=True / mainline-ready=True / cross-ready=True`；当前 fresh Windows closeout 已归档到 `SIMD-20260521-153`，对应 GH run `26230362365`。也就是说，这条 CPUInfo cross evidence 已重新进入 canonical green closeout，而不是只停在 Linux-only 阶段。

- 如果后面补到真实硬件，`native-evidence` 仍然会串行采集 `DispatchAPI/PublicAbi` 以及 `TTestCase_NonX86BackendParity,TTestCase_DataPlane`；但在当前项目约束里，没有硬件时，不再把 native host 当成 blocker：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/collect_nonx86_native_evidence.sh neon
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/collect_nonx86_native_evidence.sh riscvv
```

如果你已经从 nightly / `simd-freeze-audit` 下载了 Linux + Windows artifacts，想在本地继续复验 `freeze-status` 或 `win-closeout-finalize`，先恢复 canonical `logs/`：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh restore-nightly-evidence \
  /tmp/simd-linux-evidence \
  /tmp/simd-windows-b07-evidence
```

`perf-smoke` 默认仍是显式开关；若要把它纳入 closeout 门禁，请设置 `SIMD_GATE_PERF_SMOKE=1`，或直接走 `evidence-linux`。若 active backend 仍落在 `Scalar`，当前会直接失败，因为这意味着没有拿到可用于 closeout 的 SIMD 性能证据。

如果你是在同一台机器上并发跑多个 `SIMD` helper，或者只是想做不落默认产物目录的 dry-run，优先设置 `SIMD_OUTPUT_ROOT`。

```bash
SIMD_OUTPUT_ROOT=/tmp/simd-run-123 bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict
```

或者：

```bash
SIMD_OUTPUT_ROOT=/tmp/simd-run-123 bash tests/nextpas.core.simd/BuildOrTest.sh evidence-linux
```

这不会替代 Windows 实机 evidence；它只是把 `bin2/lib2/logs` 改写到隔离目录，方便预演与并发回归。
当前 shell gate 链路里的 `cpuinfo` / `cpuinfo.x86` / `publicabi` / `nonx86.optin` 子 runner 也会自动落到隔离根下的对应子目录；`run_all_tests` 过滤链里尊重 `SIMD_OUTPUT_ROOT` 的 simd 模块则会进一步落到 `run_all/<module>/`。
如果需要回收这批隔离产物，直接执行同根 `SIMD_OUTPUT_ROOT=/tmp/simd-run-123 bash tests/nextpas.core.simd/BuildOrTest.sh clean`；主 runner 现在会把顶层 `bin/lib`、这些子目录以及 `run_all/` 一并清掉。
真正的 Windows 收口主线应优先使用 `win-evidence-via-gh`。
这里同样要带当前前提理解：当前 `win-evidence-preflight` 已经重新放行；现在这句“优先主线”真正卡住的是 evidence freshness。若 future preflight 再次回到 `RECENT_BILLING_BLOCK`，才重新降回 billing blocker 语义。
若显式试 `SIMD_WIN_EVIDENCE_USE_BASH_GATE=1`，也只限 `cmd.exe` 真能解析 `bash` 的环境；当前本机 Wine 不属于这种环境，不要把它当成 host-side Unix bridge 逃生口。
2) Git Bash / WSL 回灌 fail-close cross gate（必需）
若走手工 Windows 实机路径，则必须先跑 `FAFAFA_BUILD_MODE=Release SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_QEMU_NONX86_EVIDENCE=0 SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 SIMD_GATE_CPUINFO_LAZY_REPEAT=3 SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate`，再执行 `win-closeout-finalize`。

## Task 2 / Task 3 维护顺序（当前已回填完成）

当前 `docs/simd/implementation-matrix.md` 已经把 `Task 2 / Task 3` 用 `2026-04-19` fresh evidence 回填完成。下面这组顺序保留给以后再次刷新同类 lane 时复用，不要在没有 fresh regression 的情况下把 `Task 3` 机械写回 `pending`。

1. 先记 `Task 2` 的 fresh 证据键值：
   - `NONX86_HELPER_SEMANTICS_SUMMARY`
   - `NONX86_IMPL_AUDIT_SUMMARY`
   - `qemu-nonx86-evidence` 最新 `summary.md` 路径
   - `closeout-host-local` 最终结果
2. 再更新 `docs/simd/closeout.md`：
   - 只写已经落盘的结果
   - 把 QEMU 路径写成可点击路径，后续不用二次查 logs
3. 然后更新 `docs/simd/implementation-matrix.md`：
   - 把相关 family 的 `runtime evidence` / `current status` 补到最新
   - 只有 fresh red 真落在某个 task family 上，才把对应 `next action` 收回到 `ready-to-refresh`，而不是默认改成 `pending`
4. 最后再更新 phase2 plan：
   - 只记录已经落盘的事实
   - 如果旧批次其实已经 commit/push，记得把遗留的 `in_progress` 状态真正收成 `completed`

最重要的一条：

- 没有 fresh runtime evidence，就不要把 task 写成 complete；同样，没有 fresh regression，也不要把已经 green 的 task 回退成 `pending`.

## 现在不要做什么

### 1. 不要继续硬拆 `SSE2`

`src/nextpas.core.simd.sse2.pas` 现在是明确的稳定边界。

### 2. 不要再拆测试文件

测试文件拆分尝试已经回滚，后续保持单文件更稳。

### 3. 不要把 `gate` 当成发布放行的唯一依据

`gate` 是快门禁，不是发布门禁。

### 4. 不要跨多个 backend 同时大改

优先做小范围、按需修改。

## 如果看到这些错误

- `Text file busy`：先顺序重跑，再判断是不是代码回归
- `Function nesting > 31`：先恢复到最近稳定状态，不要继续叠加拆分
- `backend_slot_counts` 下降：先检查脚本有没有跟上 `{$I ...}` include

## 一句话版本

现在最值得做的是：小范围修正 + 文档同步；最不值得做的是：继续激进拆分 `SSE2` 或测试文件。
