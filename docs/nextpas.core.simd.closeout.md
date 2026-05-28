# nextpas.core.simd 收尾与回归矩阵

这份文档给下一位维护者一个直接可用的结论：**现在模块是什么状态、日常改动该跑什么、发布前该补什么、还有哪些债没收完。**

如果你只想看最短版本：

- 公开 façade 和 dispatch contract 边界可以按 stable surface 理解
- backend 成熟度并不完全相同，`sbRISCVV` 仍按 experimental / 受限成熟度看待
- experimental intrinsics 默认入口链已经隔离
- adapter wiring 现在有更强的自动校验，但还没有走到“自动生成 Pascal 代码”的程度
- façade 层现在区分了 `supported-on-cpu` 与 `dispatchable-in-this-binary` 两种后端视图

## 2026-05-21 当前收口判断

- 代码主线可以按“已收口”理解：
  - `python3 tests/nextpas.core.simd/check_interface_implementation_completeness.py --strict` 最新结果仍为 `dispatch_slots_total=558`、`P0/P1/P2=0`
  - canonical release `gate` 已 PASS，且 `linux_gate_required_steps_mainline` 与 `linux_qemu_cpuinfo_nonx86_evidence` 都在最新 gate 中为 PASS
  - `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status-linux` 当前仍是 `ready=True / mainline-ready=True`
- 发布级 closeout 现在也已经回绿：
  - `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status` 当前是 `ready=True / mainline-ready=True / cross-ready=True`
  - `cross_gate_required_steps` 已 PASS
  - `windows_preflight_latest` 已 PASS：`status=PASS code=OK`
  - `windows_evidence_verify` 已 PASS
  - `windows_sources_not_newer_than_evidence` 已 PASS
  - `windows_closeout_summary` 已 PASS
  - 本轮 fresh Windows evidence 归档批次为 `SIMD-20260521-153`，对应 GH run `26230362365`
- 因此，当前最准确的结论是：
  - `code-green / cross-ready`
  - 不要再把当前 `HEAD` 写成 `evidence-refresh-required`；closeout blocker 已经真实解除
- public API 覆盖这条线也已经从“现状碰巧是绿”收成 canonical guard：
  - canonical `public-api-coverage` 现在默认按 `strict-thin` 运行
  - 当前不只是 full-covered，而且 `thin=0` 已经被默认 `gate` / `gate-strict` 守住
  - future `thin > 0` 会直接让 `gate` / `gate-strict` 变红；只有为了诊断历史薄点，才临时设 `SIMD_PUBLIC_API_TEST_COVERAGE_STRICT_THIN=0`

### 2026-05-21 future refresh note

- 如果 future `freeze-status` 里的 Linux gate artifact 旧于最新 `src/nextpas.core.simd*` 源码，先重跑一次 release `gate`，不要把旧 gate summary 当成新代码回归。
- 如果 future `freeze-status` 里的 Windows evidence log 旧于最新 `src/nextpas.core.simd*` 源码，先重跑一次 GH/Windows evidence，再判断 `cross-ready`；不要继续沿用旧的 `RECENT_BILLING_BLOCK` 叙事。
- 如果 latest `gate_summary.md` 以后又被日常 fast-gate 覆盖，导致 `qemu-cpuinfo-nonx86-evidence=SKIP`，先看 `logs/rehearsal/backups/` 或 `logs/windows-closeout/<batch>/gate_summary.md` 是否仍保留了更早的 closeout gate snapshot；`freeze-status` 现在会自动把这些 snapshot 当 fallback candidate。
- 如果 `win-evidence-preflight` 未来再次返回 `RECENT_BILLING_BLOCK`，当前批次才按 `code-green / release-evidence-blocked` 收口，不把 Windows evidence 阻塞误判成 SIMD 代码回归；此时优先处理 billing / 实机 Windows runner，而不是继续空转 `win-evidence-via-gh`。
- 如果未来手工 Windows 证据链与 fail-close cross gate 已经 fresh PASS，那么 `windows_preflight_latest` 只再代表 GH 路径是否可用，不再是当前 readiness blocker；`freeze-status` 应把它降格成 non-readiness signal，而不是留下一个与 `ready=True` 并存的 `FAIL`。
- 如果 `win-evidence-preflight` 的 live GitHub 查询只是瞬时 `WORKFLOW_QUERY_FAILED`，但本地仍有 fresh 的 latest operator truth，stdout 继续以 latest report 为准；瞬时 query noise 会写到 `logs/win_preflight_latest.diagnostic.{json,md}`，不会覆写 `win_preflight_latest.{json,md}`。
- 如果 `tests/nextpas.core.simd/buildOrTest.bat` 或 `collect_windows_b07_evidence.bat` 新于 `logs/windows_b07_gate.log`，就把当前 Windows log / closeout summary 视为 stale historical evidence；`freeze-status` 现在会把这种 runner drift 单独标红，而不是继续把旧 verifier fail 当成当前实现真相。
- 当前 `HEAD` 的最新 closeout summary 已经对应 verifier PASS；因此这条线当前不再是 verifier root-cause 调查，而是 fresh evidence refresh。
- 当 `windows_b07_gate.log` 已刷新，但 `windows_b07_closeout_summary.md` 仍旧于当前 log 时，`freeze-status` 现在会把 summary 单独标成 stale，并把 next-action 补成 `finalize-win-evidence`；不要再把旧 summary 当成当前 closeout truth。
- 如果 `qemu-cpuinfo-nonx86-evidence` 又回到 `SKIP`，那说明 latest canonical gate 已被 fast-gate 覆盖或这轮并未刷新 Linux CPUInfo cross evidence；这时可以继续做仓库内文档/policy 收口，但不要把 `freeze-status` 写成 green。
- `qemu-nonx86-evidence` 和 `qemu-cpuinfo-nonx86-evidence` 现在必须分开理解：
  - 前者服务 `closeout-host-local` 的 non-x86 runtime parity / dataplane 实现收口
  - 后者服务 canonical `gate` / `freeze-status` 的 CPUInfo cross-platform 证据

## 这一轮收了什么

这轮收尾主要完成了 8 组工作：

1. **文档 landing / API 名称纠偏**
   - 统一了 README、模块总览、API 文档的阅读入口
   - 修正了 `VecF32x4LoadAligned` / `VecF32x4StoreAligned` 等公开 façade 名称
   - 把历史草案文档明确标成“不要当真相源”

2. **cpuinfo 测试绿灯语义修正**
   - 把 `AssertTrue(..., True)` 形式的伪 skip 改成显式 skip
   - 避免“没测到”被统计成正常通过

3. **`cpuinfo.x86` 样本驱动测试增强**
   - 新增 vendor / brand / AVX / AVX2 / AVX-512 gating 的样本驱动测试
   - 抽出最小 pure helper seam，降低对当前宿主机的依赖

4. **stable / experimental 边界收口**
   - 明确 stable 的是公开 façade 与 in-repo dispatch contract，而不是“每个 backend 都一样成熟”
   - 明确 `sbRISCVV` 仍是 experimental / 受限成熟度 backend
   - 明确 experimental intrinsics 默认不属于 stable surface

5. **adapter wiring 校验增强**
   - `backend.adapter.map.csv` 现在是 adapter-managed slots 的声明式事实真相源，`backend.adapter.map.inc` 由它生成
   - `adapter-sync` 除了校验 `backend.iface <-> backend.adapter`，还会校验：
     - CSV spec 与 checked-in generated include 是否漂移
     - 映射里引用的 slot 是否真实存在于 `TSimdDispatchTable`
     - 这些 slot 是否被 `FillBaseDispatchTable` 覆盖

6. **dispatch contract hard guard**
   - `check_dispatch_contract_signature.py` 会对 `TSimdBackendInfo` / `TSimdDispatchTable` 的声明签名做 machine-readable 校验
   - `gate` 默认已带上 `contract-signature` step，用来防止仓库内 dispatch contract 被无意改坏
7. **public ABI hard guard**
   - `check_public_abi_signature.py` 会对 public ABI wrapper 的 Pascal 声明、ABI 常量、backend/capability ID 映射，以及 `publicabi_smoke.h` consumer contract 做 machine-readable 校验
   - `gate` / `gate-strict` 默认已带上 `publicabi-signature` step，用来防止 public ABI wrapper 被无意改坏
8. **runtime / cpuinfo / dataplane 接口封边**
   - `TSimdBackendArray` 现在归 `nextpas.core.simd.base` 所有，`cpuinfo` / `runtime` 只返回这个共享容器类型
   - `nextpas.core.simd` 现在直接重导出 canonical `GetCPUInfo`；`GetCPUInformation` 降级为兼容别名
   - data-plane published snapshot 不再在复用旧节点时重写内容；同一 dispatch 只会重新发布既有 immutable snapshot
   - `example_simd_dispatch` 与接口文档现在显式区分 `CPU-supported` 和 `current runtime backend`

## 2026-04-15 runtime / cpuinfo closeout facts

- bounded frontier：`runtime / cpuinfo / dataplane / façade wrapper / docs-example alignment`
- fresh targeted suites：
  - `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_RuntimeAPI` -> `[TEST] OK`
  - `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DataPlane` -> `[TEST] OK`
- fresh fast gate：
  - `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh check` -> `[CHECK] OK`
  - `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh gate` -> `[GATE] OK`
- fresh host-local strict closeout：
  - `SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=0 FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh closeout-host-local` -> `[CLOSEOUT-HOST-LOCAL] OK`
  - qemu runtime summary: [qemu-multiarch-20260415-010346-869191/summary.md](/home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/logs/qemu-multiarch-20260415-010346-869191/summary.md)
  - qemu cpuinfo summary: [qemu-multiarch-20260415-011042-887472/summary.md](/home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/logs/qemu-multiarch-20260415-011042-887472/summary.md)
- 当前结论：
  - 接口层 canonical/legacy 口径已经封边：`cpuinfo` 只回答 CPU/OS capability，`runtime` 负责 active/registered/dispatchable/control-plane
  - data-plane published snapshot 的不可变语义已经落到实现上，不再依赖“复用节点但内容刚好相同”的隐式假设
  - Windows evidence 仍保持为独立外部边界；这轮 host-local closeout 没有伪装成 Windows 完成

## 现在可以怎么理解这个模块

先把几个边界分开：

- **稳定面**：`nextpas.core.simd` / `nextpas.core.simd.api` 对外公开的 façade，以及 `TSimdDispatchTable` 这类已明确写进稳定约束的 in-repo dispatch contract 边界
- **实现面**：`dispatch`、`cpuinfo`、各 backend 单元、`backend.iface` / `backend.adapter`
- **实验面**：experimental intrinsics，以及 `sbRISCVV` 这类仍在受限成熟度区间的 backend

这意味着：

- 正常使用者可以把公开 API 当作稳定入口
- 当前 `TSimdDispatchTable` 可以按仓库内稳定 contract 理解，但不应被当成 public binary ABI
- `cpuinfo` 的 `GetSupportedBackendList` / `GetBestSupportedBackend` 是 `supported_on_cpu` 视图的推荐入口
- `GetAvailableBackends` / `GetBestBackendOnCPU` 继续保留，但只按兼容别名理解
- façade 层的 `GetRegisteredBackendList` / `IsBackendRegisteredInBinary` 反映的是 `registered` 视图
- façade 层的 `GetAvailableBackendList` / `GetDispatchableBackendList` 反映的是 `dispatchable` 视图
- `GetCurrentBackend` / `GetCurrentBackendInfo` 反映的是 `active` 视图
- 维护者不能把“façade stable”误读成“所有 backend 都同样成熟、同样覆盖、同样适合发布级承诺”
- 默认门禁会保护主链路，但不会自动替你证明“所有 experimental 路径都已发布级保证”

## 2026-04-11 implementation audit snapshot / 2026-04-14 implementation closeout wave

这一轮实现层收口的 fresh 证据，应该按下面的边界理解：

- `NONX86_HELPER_SEMANTICS_SUMMARY`：source checker 已覆盖 helper/native-evidence，以及 compare/mask / shift/bitwise / arithmetic/minmax 的 source-side 语义矩阵
- `NEON hygiene source truth`：`check_nonx86_helper_semantics.py` 现在还会 fail-close 锁定 `src/nextpas.core.simd.neon.pas` 里的 `ShiftLeftI32x16` / `ShiftRightArithI64x4` invalid-count fallback、`NEONShiftLeftI64x4Asm` 的 `uxtw  x1, w1`、`NEONShiftLeftI64x2` / `NEONShiftLeftU64x2` / `NEONShiftLeftU64x4` 的 64-bit lane count widening，以及 `NEONSelectF32x4` 的逐 lane mask 选择逻辑
- `NEON register/runtime truth`：fresh `check_nonx86_register_truthfulness.py --backend neon --summary-line --strict` 现在是 `backend=neon assignments=341 asm_exact=280 asm_suffix_only=10 backend_composed=51 wrapper_only=0 scalar_passthrough=0 no_def=0 miswired=0 strict=1`；其中 `51` 个 `backend_composed` 都属于 asm-only backend-local composition，而剩余 `10` 个 `asm_suffix_only` 仍是保留 invalid-count => scalar fallback 的 shift companion，不是待删 wrapper debt
- `NONX86_KEY_SLOT_AUDIT_SUMMARY`：key wide slot 已按 `backend_owned` / `reuse_base_scalar` 两类契约审计，避免把“故意继承 base scalar”的实现误报成缺口，也避免 backend-owned 槽位悄悄退回 wrapper/scalar
- `WIRING_SYNC_SUMMARY`：non-x86 wiring slot 名单已收敛到 `AssertNonX86DispatchTableWiringGroupsAssigned`，legacy/grouped 两个测试入口不再各自维护一份 60-slot 名单
- `NONX86_REGISTER_TRUTHFULNESS_SUMMARY`：`neon` / `riscvv` strict 模式通过
- `RISCVV facade/register hygiene`：`riscvv.facade.inc` 现在明确把 scalar-pass-through facade helper 留在 base scalar slot，不再伪造 backend-local 包装层；其中 `RISCVVShiftLeftU32x8` / `RISCVVShiftRightU32x8` 现在也显式回到 `ScalarShiftLeftU32x8` / `ScalarShiftRightU32x8`，作为这一轮 `facade hygiene` 的 source truth 一部分固定下来。与此同时，`DispatchAPI` 的 `Test_RISCVV_KeyOwnedWideSlots_Stay_BackendOwned` 继续把 `AndI64x8` / `NotI64x8` / `ShiftLeftI32x16` / `ShiftRightArithI64x4` / `SubI32x8` / `MinU32x8` / `AddI64x4` / `MulI32x16` / `SubI64x8` / `ClampF64x4` / `ClampF64x8` 从“无 scalar 例外断言”升级成 dedicated source truth；`Test_RISCVV_ExtractSlots_Reuse_BaseScalar_When_NoAsmWrappers_Are_Dead` 已把 9 个 `Extract*` slot 翻正为“asm side 保留 helper-backed wrapper、no-asm host 直接 reuse base scalar slot”的真实合同；`Test_RISCVV_WideRoundingAndF32ClampSlots_Reuse_BaseScalar_When_ScalarForwarders_Are_Dead` 已把 `Ceil/Floor/Round/TruncF32x8/F64x4/F32x16/F64x8` 与 `ClampF32x8/F32x16` 收成 `reuse_base_scalar`；`Test_RISCVV_DotF64Slots_Reuse_BaseScalar_When_ScalarForwarders_Are_Dead` 已把 `DotF64x2/F64x4` 翻正为同一合同；`Test_RISCVV_ExactScalarHelperSlots_Reuse_BaseScalar_When_Owners_Are_Dead` 又把 9 个 `I64/U64/Cmp/Min/Max` exact-scalar owner 收成 `reuse_base_scalar`；`Test_RISCVV_AndNotSlots_Keep_AsmOwnedCompositions_And_Reuse_BaseScalar_When_NoAsm` 则把最后 3 个 `AndNotI8x16/U16x8/U8x16` 固定为“asm side 保留 local composition、register 只在 asm 打开时发布 backend slot、no-asm host 直接 reuse base scalar slot”的真实合同；最新一轮又把 non-public `RISCVVCmpNeU32x4` helper duplicate truth 收回到 `ScalarCmpNeU32x4`，`riscvv.helpers.inc` 不再保留本地 compare loop。`check_interface_implementation_completeness.py` 也已同步把 `DotF64x2/F64x4` 与 wide `Ceil/Floor/Round/Trunc` 的 intentional base-scalar reuse 从 false positive 中排除。当前 helper/native-evidence/source-shape 的 live source truth 以 `python3 tests/nextpas.core.simd/check_nonx86_helper_semantics.py --summary-line` 为准，active closeout 文档不再硬编码这条 checker 的 `checks` 计数。与此同时，`check_riscvv_sensitive_hold_set.py` 会 fail-close 守住 no-asm `riscvv.facade.inc` 里最后允许保留的 7 个敏感 residual：`RISCVVRcpF64x4 / RISCVVClampF64x4 / RISCVVClampF64x8 / RISCVVReduceAddF64x4 / RISCVVReduceAddF64x8 / RISCVVReduceMulF64x4 / RISCVVReduceMulF64x8`；`NONX86_REGISTER_TRUTHFULNESS_SUMMARY backend=riscvv assignments=432 asm_exact=312 asm_suffix_only=117 backend_composed=3 wrapper_only=0 scalar_passthrough=0 no_def=0 miswired=0 strict=1`、`asm-only composed ok=3` 与 `NONX86_KEY_SLOT_AUDIT_SUMMARY backends=neon,riscvv slots=136 issues=0 status=ok` 仍保持不变
- `RISCVV_ABI_SHAPE_SUMMARY`：宽向量 direct-return asm 已统一回到 hidden-result-pointer ABI 形状，`a0` 只保留 Result 指针语义
- `NONX86_NATIVE_EVIDENCE_SUMMARY`：native non-x86 evidence verifier 已有正式入口，可在 `x86_64` 上对归档 evidence 做 fail-close 校验
- `docs/nextpas.core.simd.implementation-matrix.md`：当前 implementation 主线的 working ledger，固定记录 backend/slot/契约/source truth/runtime evidence/next action，避免下轮再回到“看起来好像没问题”的散点审查
- `docs/plans/2026-04-14-simd-only-patch-bundle.md`：当前 `simd` 收口波次的 patch bundle 清单，明确区分“x86 bounded frontier 最小集”和“SIMD 主线完整集合”，避免在脏工作区里把非 SIMD 改动误混进提交
- `impl-smoke-x86`：当前 x86 bounded frontier 的高频 smoke 入口，固定按 `impl-smoke-sse2 -> DispatchAPI bounded frontier` 的顺序重跑 `SSE2 structure/contracts smoke`、`SSE2 compare/vector-math parity`、`SSE3/SSSE3/SSE4.x incremental clone + semantic parity contract`、`AVX512 shift boundary`、`AVX2 wide select`、`AVX2 wide FMA composition` proof；它只负责快速确认 x86 证明面没有 fresh 漂移，不替代 `closeout-host-local`
- `DataPlane wide snapshot`：`Test_DataPlane_WideBitwiseShiftSnapshot_Follows_CurrentDispatchSemantics` / `Test_DataPlane_WideArithmeticMinMaxSnapshot_Follows_CurrentDispatchSemantics` 已覆盖 `I64x8 bitwise` 与 wide arithmetic/minmax 的高价值 dataplane 快照，不再只盯抽样老点位
- `qemu-nonx86-evidence`：`linux/arm64` / `linux/riscv64` fresh 通过；runner 现在固定使用隔离 `SIMD_OUTPUT_ROOT`，单次 build 后复用 binary 继续跑 `TTestCase_NonX86BackendParity,TTestCase_DataPlane` 与 backend bench，已规避旧链路里 `arm64` 重复 full rebuild 触发的 `ppca64` `FIRSTCALLPARAN` ICE。它证明的是 non-x86 runtime parity / dataplane 实现层，不是 `freeze-status` 的 CPUInfo closeout 证据
- `qemu-cpuinfo-nonx86-evidence`：`linux/arm/v7`、`linux/arm64`、`linux/riscv64` 的 CPUInfo cross-platform 证据；`2026-05-17 10:47:10` fresh gate 已把这一条刷成 PASS，summary 为 [qemu-multiarch-20260517-103904-1404563/summary.md](/home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/logs/qemu-multiarch-20260517-103904-1404563/summary.md)。这是 canonical `gate` / `freeze-status` 当前真正消费的 Linux-side cross evidence
- `NONX86_IMPL_AUDIT_SUMMARY`：新的聚合实现审计入口已把 helper semantics、key-slot audit、wiring-sync、RISCVV ABI shape、`riscvv-sensitive-hold-set`、register truthfulness strict 和 targeted release suite 收成单条命令；当前 head 的 canonical non-x86 implementation audit 结果应以 `steps=7 ... status=ok` 为准
- `impl-smoke-nonx86`：新增轻量日常入口，定位是高频实现回归；它当前固定覆盖 helper semantics、key-slot audit、wiring-sync、`riscvv-sensitive-hold-set`、register truthfulness strict 与 targeted parity，负责尽快暴露 non-x86 source/runtime contract 的 fresh 漂移，不替代 `impl-audit-nonx86` 的完整实现审计，也不替代 `closeout-host-local` 的 strict closeout 证明
- `AVX2 public ABI capability contract`：x86 bounded frontier 这一轮没有挖到新的实现红点，收口点转为接口证据补齐。`DispatchAPI` 现在显式覆盖 `sbAVX2` 的 `scFMA` / `scShuffle` 正向暴露，以及 `SetVectorAsmEnabled(False)` 后 public ABI `CapabilityBits` 清零契约；后续不再需要从 registered-table 的 `BackendInfo.Capabilities` 间接推断 public ABI 是否同步
- `x86 implementation frontier`：这一轮 bounded implementation 专审没有 fresh 复现新的 AVX512 / AVX2 实现 bug，但把最薄弱的实现证明面补强了：
  - `SSE2 structure/contracts smoke`：`BuildOrTest.sh` 现在提供 `impl-smoke-sse2`，把 `sse2-structure-check`、`TTestCase_SSE2Contracts`、`TTestCase_BackendSmoke`、`TTestCase_RuntimeAPI`、`TTestCase_DataPlane` 收成一条 release smoke；`impl-smoke-x86` 也已把它纳入固定前置步骤。当前 fresh 结果是 `SSE2_STRUCTURE_SUMMARY ... status=ok` 和 `SSE2_IMPL_SMOKE_SUMMARY steps=5 ... status=ok`，意味着 `SSE2` 当前这波 root/register/select/wide include 重排不再只是本地改动，而是带结构 contract 和 runtime contract 的正式证据
  - `SSE2 I64x2 compare parity`：`DispatchAPI` 新增 `Test_SSE2_I64x2_Compare_Use_NonScalar_Impl_And_Keep_Parity`，现在会强制 `sbSSE2` 并直接探测 `CmpEqI64x2 / CmpGtI64x2` 的 runtime parity，尤其覆盖 `same-high-word + unsigned-low` 这类最容易在 64-bit compare 分解里出错的 edge mask。当前 fresh 结果没有复现新的 compare drift，但 base backend 的这条实现路径已经从“只有通用 facade parity”升级成了带强制 backend 的直接证据
  - `SSE2 F32 vector-math parity`：`DispatchAPI` 新增 `Test_SSE2_F32VectorMath_Use_NonScalar_Impl_And_Keep_Parity`，现在会强制 `sbSSE2` 并直接探测 `RoundF32x4 / DotF32x3 / CrossF32x3` 的 runtime parity；proof 使用 exact half-step round 输入，以及带 lane-3 payload 的 dot/cross 输入，明确锁住 `RoundF32x4` 的 signed half-step 行为和 `Dot/CrossF32x3` 只消费前三个 lane 的语义。当前 fresh 结果没有复现新的 vector-math drift，base backend 这组代表性 math primitive 也不再只有 facade 级旁证
  - `SSE3 / SSSE3 / SSE4.1 / SSE4.2 incremental clone + semantic parity contracts`：`DispatchAPI` 现在不只钉住小型增量 x86 backend 的 representative ownership/inheritance，还补上了 exact-input runtime parity。`SSE3` 现在同时验证 `ReduceAddF32x4 / DotF32x4 / NormalizeF32x4`（含 zero-vector）对 scalar 的运行时结果；`SSSE3` 验证继承的 `MinI8x16 / MaxI8x16`；`SSE4.1` 现在验证 `MulI32x4 / DotF32x4 / RoundF32x4 / SelectF32x4 / NormalizeF32x4 / NormalizeF32x3 / CmpEqI64x2`；`SSE4.2` 验证 `CmpGtI64x2`。这轮 fresh red 真实抓出了三个实现问题并已修复：`SSE41SelectF32x4` 的 mask polarity 反了，`SSE3NormalizeF32x4/F32x3` 仍停留在 `rsqrtps` 近似路径而没有走与 scalar 一致的精确长度除法路径，以及 `SSE41NormalizeF32x4/F32x3` 同样还保留近似 `rsqrtps` 路径并缺少 zero-vector 的 scalar 等价分支
  - `AVX512 U32x16/U64x8`：`DispatchAPI` 新增 `Test_AVX512_U32x16_U64x8_ShiftBoundary_Contracts`，把 `shift boundary` 的 source truth（invalid-count guard + zero-fill）和运行时 `0 / width-1 / width` parity 一起钉住
  - `AVX2 wide implementation`：`DispatchAPI` 新增 `Test_AVX2_WideSelect_Parity_WithScalar_When_VectorAsmEnabled`，把 `SelectF32x16` / `SelectF64x8` 从原来的 `dispatch == facade` 自证，升级为对 `ScalarSelectF32x16` / `ScalarSelectF64x8` 的直接 parity proof
  - `AVX2 wide FMA composition`：`DispatchAPI` 新增 `Test_AVX2_WideFma_ExactInputs_FollowsHalfComposition`，把 `FmaF32x16` / `FmaF64x8` 明确钉在 `register source truth + AVX2FmaF32x8/F64x4 lo/hi composition + exact-input runtime parity` 上，不再只停留在 wide facade 自证
  - 2026-04-19 fresh rerun `X86_IMPL_SMOKE_SUMMARY steps=2 ... status=ok`，说明这条 bounded frontier 目前仍处于 hold-green 状态
  - 当前结论应按 “fresh green + proof strengthened + stop condition met” 理解，而不是再继续发散翻 x86 全家桶
- implementation aggregate audit：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh impl-audit-nonx86
```

- host-local strict closeout：

```bash
SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=0 FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh closeout-host-local
```

2026-04-19 fresh rerun：`[CLOSEOUT-HOST-LOCAL] OK`

- latest fresh QEMU non-x86 evidence：
  - runtime summary: [qemu-multiarch-20260419-012508-1690172/summary.md](/home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/logs/qemu-multiarch-20260419-012508-1690172/summary.md)
  - cpuinfo summary: [qemu-multiarch-20260419-013630-1748481/summary.md](/home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/logs/qemu-multiarch-20260419-013630-1748481/summary.md)

- legacy targeted parity smoke 仍保留为显式诊断入口：`TTestCase_NonX86BackendParity,TTestCase_DirectDispatch,TTestCase_DataPlane`

- full gate：

```bash
FAFAFA_BUILD_MODE=Release SIMD_ENABLE_NEON_BACKEND=1 SIMD_ENABLE_RISCVV_BACKEND=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate
```

这一轮不只是补注释。当前 worktree 已经落地了经 `release + impl-audit + QEMU evidence` 支撑的 `ABI / wiring / shift` 修正：`riscvv.pas` 的 hidden-result-pointer ABI 形状、`riscvv.register.inc` / `riscvv.facade.inc` 的 ownership/wiring 收口，以及 `neon.pas` 的 shift/select hygiene 都已经进入 fresh green 状态。

这批结果当前证明的是：`x86_64` 主机上的 source/runtime contract、dispatch wiring、scalar parity 没看到 fresh 漂移。
`impl-audit-nonx86` 和 `closeout-host-local` 现在把 host-local implementation audit / strict closeout 固化成正式入口。
QEMU non-x86 runtime evidence 现在就是当前 non-x86 收口主线的一部分。
当前项目口径下，只要 `qemu-nonx86-evidence` 在 `linux/arm64` / `linux/riscv64` fresh 通过，就把它作为当前 host-local non-x86 runtime closeout 的充分证明；这轮最新 fresh 证据就是上面的 `qemu-multiarch-20260419-012508-1690172` / `qemu-multiarch-20260419-013630-1748481`。但如果目标是让 canonical `freeze-status` 变绿，还必须额外刷新 `qemu-cpuinfo-nonx86-evidence`；`2026-05-17 10:47:10` 这条 Linux CPUInfo cross evidence 已经补绿，当前剩余 blocker 只在 Windows evidence。没有硬件时，不再把 native host 当成 blocker。native host evidence 仍可补充，但不再是这轮收口的前置条件。

当前 arm64 / riscv64 closeout 的充分证明，仍然以上面这组 fresh `QEMU non-x86 runtime evidence` 为准。

## Task 2 / Task 3 closeout facts (2026-04-19 fresh)

- `Task 2 / shift-bitwise`：
  - helper semantics：`NONX86_HELPER_SEMANTICS_SUMMARY checks=45 status=ok`
  - implementation audit：`2026-04-19` 的历史聚合结果是 `NONX86_IMPL_AUDIT_SUMMARY steps=6 ... status=ok`；当前 head 已把 `riscvv-sensitive-hold-set` 升格进 canonical audit 链，因此 live truth 以 `steps=7` 为准
  - qemu runtime summary: [qemu-multiarch-20260419-012508-1690172/summary.md](/home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/logs/qemu-multiarch-20260419-012508-1690172/summary.md)
  - qemu cpuinfo summary: [qemu-multiarch-20260419-013630-1748481/summary.md](/home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/logs/qemu-multiarch-20260419-013630-1748481/summary.md)
  - 当前结论：boundary semantics、invalid-count fallback 和 data-plane snapshot 已具备 fresh closeout 证据；下一轮只需要 `hold green`
- `Task 3 / arithmetic-minmax-mul`：
  - targeted release suites：`FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DispatchAPI,TTestCase_DirectDispatch,TTestCase_DataPlane` -> `[TEST] OK`
  - helper semantics：`NONX86_HELPER_SEMANTICS_SUMMARY checks=45 status=ok`
  - implementation audit：`2026-04-19` 的历史聚合结果是 `NONX86_IMPL_AUDIT_SUMMARY steps=6 ... status=ok`；当前 head 已把 `riscvv-sensitive-hold-set` 升格进 canonical audit 链，因此 live truth 以 `steps=7` 为准
  - qemu runtime summary: [qemu-multiarch-20260419-012508-1690172/summary.md](/home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/logs/qemu-multiarch-20260419-012508-1690172/summary.md)
  - qemu cpuinfo summary: [qemu-multiarch-20260419-013630-1748481/summary.md](/home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/logs/qemu-multiarch-20260419-013630-1748481/summary.md)
  - 这轮直接证据：
    - `DispatchAPI`：`MulI32x8` / `MulU32x8` low-32 truncation probe，`AddU32x8` / `AddU64x4` / `SubU64x4` lane-tag probe
    - `DirectDispatch` / `DataPlane`：wide arithmetic/minmax 与 dataplane snapshot 已覆盖当前高 ROI family
  - 当前结论：`arithmetic/minmax/mul` 已具备 fresh closeout 证据；下一轮只需要 `hold green`
- `NEON hygiene`：
  - `src/nextpas.core.simd.neon.pas` 当前除了 Task 2 主线，还顺带收了 `shift/select/facade hygiene`，并补齐了 64-bit lane 左移对 `Integer` count 的显式 zero-extension
  - 当前 fresh 结果：`NONX86_HELPER_SEMANTICS_SUMMARY` 继续为 `status=ok`；当前 helper/native-evidence/source-shape 结果以 live `check_nonx86_helper_semantics.py --summary-line` source truth 为准。`NONX86_REGISTER_TRUTHFULNESS_SUMMARY backend=neon assignments=341 asm_exact=280 asm_suffix_only=10 backend_composed=51 wrapper_only=0 scalar_passthrough=0 no_def=0 miswired=0 strict=1`、`NONX86_KEY_SLOT_AUDIT_SUMMARY backends=neon,riscvv slots=136 issues=0 status=ok`
  - 这意味着当前残余不再是 `wrapper_only` 债务：`51` 个 `backend_composed` 都是 asm-only local composition，而那 `10` 个 `asm_suffix_only` shift companion 继续承担 invalid-count => scalar fallback 合同，不能直接绑成 raw `_Asm`
  - 如果后续想把提交历史切得更干净，建议单列成 `NEON shift/select hygiene` 一组，而不是再和 `RISCVV ABI` 收口混写
- `RISCVV facade/register hygiene`：
  - `src/nextpas.core.simd.riscvv.facade.inc` / `src/nextpas.core.simd.riscvv.register.inc` 这一轮只做了结构收口，不改 public API / ABI，也不改 key-slot ownership 结论
  - `RISCVVShiftLeftU32x8` / `RISCVVShiftRightU32x8` 现在显式回到 `ScalarShiftLeftU32x8` / `ScalarShiftRightU32x8`；这不是“暂时能跑”的宽松写法，而是当前 `RISCVV facade hygiene` 明确锁定的 source truth
  - fresh checker 现在证明的更准确口径是：`ExtractF32x16` / `ExtractF32x8` / `ExtractF64x2` / `ExtractF64x4` / `ExtractI32x4` / `ExtractI32x8` / `ExtractI32x16` / `ExtractI64x2` / `ExtractI64x4` 必须保留 asm-gated register 结构，但 no-asm host 不该再发布 RISCVV scalar-forward wrapper；它们当前应直接 reuse base scalar slot
  - 当前 fresh 结果：`NONX86_REGISTER_TRUTHFULNESS_SUMMARY backend=riscvv assignments=432 asm_exact=312 asm_suffix_only=117 backend_composed=3 wrapper_only=0 scalar_passthrough=0 no_def=0 miswired=0 strict=1`，`NONX86_KEY_SLOT_AUDIT_SUMMARY backends=neon,riscvv slots=136 issues=0 status=ok`
- 对 `x86_64` worktree 来说：
  - `checker ok` 和 `compile/list-suites ok` 仍不能代替 fresh non-x86 runtime evidence
  - 文档里要继续把 “source-side proof” 和 “QEMU/native runtime proof” 分开写

## 推荐回归命令矩阵

### Linux / macOS

#### 日常改动

Run:
```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh impl-smoke-x86
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh impl-smoke-nonx86
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh check
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DispatchAPI
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DirectDispatch
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh gate
```

这组命令适合：
- 文档同步
- façade 小修
- dispatch / cpuinfo 的局部修改
- backend 小范围修正

其中 `impl-smoke-x86` 负责当前 x86 bounded frontier 的高频证明回归，`impl-smoke-nonx86` 负责 non-x86 helper semantics / wiring ownership / targeted parity 的高频回归；要做完整实现审计或 strict closeout，仍然分别看 `impl-audit-nonx86` / `closeout-host-local`。

#### `cpuinfo` 便携路径

Run:
```bash
bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --suite=TTestCase_PlatformSpecific
bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --suite=TTestCase_LazyCPUInfo
```

#### `cpuinfo.x86` 样本驱动路径

Run:
```bash
bash tests/nextpas.core.simd.cpuinfo.x86/BuildOrTest.sh test --suite=TTestCase_SampleDriven
bash tests/nextpas.core.simd.cpuinfo.x86/BuildOrTest.sh test --suite=TTestCase_Global
```

#### adapter wiring / experimental boundary

Run:
```bash
bash tests/nextpas.core.simd/BuildOrTest.sh adapter-sync
bash tests/nextpas.core.simd/BuildOrTest.sh experimental-intrinsics
```

#### 发布前 / closeout

`closeout-release` 现在是完整发布收口的官方主入口：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh closeout-release SIMD-YYYYMMDD-152
```

它会按 `win-evidence-preflight -> impl-smoke-x86 -> closeout-host-local -> win-evidence-via-gh -> freeze-status` 的固定顺序收口；如果你只是做阶段性实现收口、手工 Windows 诊断，或只想单独复验某一段证据链，再退回下面这些拆分命令。

如果目标是当前 Linux/macOS worktree 的 host-local strict closeout，优先直接跑：

Run:
```bash
SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=0 FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh closeout-host-local
```

`closeout-host-local` 的固定顺序是 `impl-audit-nonx86 -> gate-strict`。当前默认它会把 `SIMD_GATE_QEMU_NONX86_EVIDENCE=1`、`SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1`、`SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1`、`SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1` 与 `SIMD_GATE_CPUINFO_LAZY_REPEAT=3` 一起带上，并把 `SIMD_GATE_REQUIRE_NONX86_NATIVE_EVIDENCE=0` 降为可选，同时继续把 Windows evidence requirement 降到可选，因此适合当前 `x86_64` 主机上的实现层阶段收口。
如果目标是完整发布门禁 / Windows closeout 主线，再跑：

Run:
```bash
bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict
```

`gate-strict` 是发布门禁，不是日常快门禁。它会补上更重的 repeat 与结构一致性路径。
默认它会强制 coverage / wiring / repeat / non-x86 / Windows evidence 等 closeout 检查；其中 non-x86 运行证明当前默认走 `SIMD_GATE_QEMU_NONX86_EVIDENCE=1`，而 `SIMD_GATE_REQUIRE_NONX86_NATIVE_EVIDENCE=0` 只保留为可选附加证据。`perf-smoke` 仍是显式可选项，除非你设置 `SIMD_GATE_PERF_SMOKE=1`，或者走 `evidence-linux` 这条固定会把 perf 带进去的证据链。

如果你只是想基于现有 `gate_summary.json` / `freeze_status.json` / native-evidence 目录重导 machine-readable closeout bundle，而不是重跑整条重链路，直接用：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh release-evidence
```

如果后续要补 fresh RISCVV enhanced evidence，不要在 dirty worktree 上反复手工 dispatch。当前 repo 已提供：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh riscvv-runner-3cmd
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh native-evidence-via-gh-clean riscvv
```

第一条用于打印 repo-side bootstrap/operator 最短路径；第二条会基于当前已推送 ref 临时创建 clean worktree 做 GH dispatch/download，并把 artifact 仍然写回当前 worktree 的 `tests/nextpas.core.simd/logs/`。完整说明见 [riscvv_native_closeout_runbook.md](/home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/docs/riscvv_native_closeout_runbook.md)。

如果 fresh `arm64/riscv64` native evidence 已经从外部机器拷回当前 worktree，不要再手工 `cp`/猜目录；直接用：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh import-nonx86-native-evidence /path/to/native-evidence-drop
```

它会把最新的 `native-evidence-neon-*` / `native-evidence-riscvv-*` 导入到 `tests/nextpas.core.simd/fixtures/native-evidence`，并立刻跑 `verify-nonx86-native-evidence`。导入绿了之后，再执行：

```bash
SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=0 FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh closeout-host-local
```

如果你只是想把当前 `fixtures/native-evidence` 再过一遍 importer/verifier，不必手工 `cp` 到别处；现在直接把该目录当 source root 传给 `import-nonx86-native-evidence` 也是安全的，脚本会识别为 verify-only no-op，而不会自删 source。verifier 若失败，也会直接带出具体 `backend`、`summary.md` 和 `environment.txt` 路径。
为了防止把演练产物误当真证据回灌，importer / verifier 现在还会拒绝 synthetic 或 repackaged evidence：例如 `summary.md` header 时间戳和目录名不一致，或者 summary 里还残留 `/tmp/simd-import-smoke` 这类 import-smoke marker，都会直接 fail-close。

如果你不想分两步，当前 worktree 也已经有一键入口：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh closeout-host-local-from-import /path/to/native-evidence-drop
```

如果你是在 Linux 上做 dry-run、对比不同脚本口径，或者同一轮里要并发跑 `gate` / `gate-strict` / `evidence-linux`，建议显式设置 `SIMD_OUTPUT_ROOT`，避免互相覆盖默认 `bin2/lib2/logs`。

Run:
```bash
SIMD_OUTPUT_ROOT=/tmp/simd-closeout-123 \
SIMD_NONX86_NATIVE_EVIDENCE_ROOT=tests/nextpas.core.simd/fixtures/native-evidence \
SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=0 \
FAFAFA_BUILD_MODE=Release \
bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict
```

或者：
```bash
SIMD_OUTPUT_ROOT=/tmp/simd-closeout-123 bash tests/nextpas.core.simd/BuildOrTest.sh evidence-linux
```

这类隔离运行适合预演和并发回归，但**不会替代** Windows 实机 evidence。真正收口应优先走 `win-evidence-via-gh` / `win-closeout-finalize` 主线；`finalize-win-evidence` 只保留给拆分诊断或低层脚本调用。
`perf-smoke`、QEMU / Windows evidence 仍保留为显式可选项；如果你要把这些重证据也纳入发布门禁，可先设置对应 `SIMD_GATE_*` 开关再运行。
它也会把 `wiring-sync`、`interface-completeness`、`adapter-sync` 这类结构一致性检查一起带上。

### Windows

#### 日常改动

Run:
```bat
tests\nextpas.core.simd\buildOrTest.bat check
tests\nextpas.core.simd\buildOrTest.bat test --suite=TTestCase_DispatchAPI
tests\nextpas.core.simd\buildOrTest.bat test --suite=TTestCase_DirectDispatch
tests\nextpas.core.simd\buildOrTest.bat gate
```

#### `cpuinfo` 便携路径

Run:
```bat
tests\nextpas.core.simd.cpuinfo\buildOrTest.bat test --suite=TTestCase_PlatformSpecific
tests\nextpas.core.simd.cpuinfo\buildOrTest.bat test --suite=TTestCase_LazyCPUInfo
```

#### `cpuinfo.x86` 样本驱动路径

Run:
```bat
tests\nextpas.core.simd.cpuinfo.x86\buildOrTest.bat test --suite=TTestCase_SampleDriven
tests\nextpas.core.simd.cpuinfo.x86\buildOrTest.bat test --suite=TTestCase_Global
```

#### adapter wiring / experimental boundary

Run:
```bat
tests\nextpas.core.simd\buildOrTest.bat adapter-sync
tests\nextpas.core.simd\buildOrTest.bat experimental-intrinsics
```

#### 发布前 / closeout

Run:
```bat
tests\nextpas.core.simd\buildOrTest.bat gate-strict
```

## 建议最小提交面

如果现在的目标是“先把 Linux 侧 closeout 相关修复稳定落地”，而不是一次性把所有 `SIMD` 文档/历史整理都带上，建议按下面三类处理：

### 必须保留

- **运行时修复**：`src/nextpas.core.simd.intrinsics.sse.pas`、`src/nextpas.core.simd.intrinsics.mmx.pas`、`tests/nextpas.core.simd/nextpas.core.simd.bench.pas`、`tests/nextpas.core.simd.intrinsics.sse/nextpas.core.simd.intrinsics.sse.testcase.pas`
- **门禁与 evidence helper**：`tests/nextpas.core.simd/BuildOrTest.sh`、`tests/nextpas.core.simd/buildOrTest.bat`、`tests/nextpas.core.simd/run_backend_benchmarks.sh`、`tests/nextpas.core.simd/collect_linux_simd_evidence.sh`、`tests/nextpas.core.simd/docker/run_multiarch_qemu.sh`
- **gate / freeze 语义**：`tests/nextpas.core.simd/generate_gate_summary_sample.py`、`tests/nextpas.core.simd/export_gate_summary_json.py`、`tests/nextpas.core.simd/rehearse_freeze_status.sh`、`tests/nextpas.core.simd/evaluate_simd_freeze_status.py`
- **`cpuinfo` 子 runner 隔离**：`tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh`、`tests/nextpas.core.simd.cpuinfo/buildOrTest.bat`、`tests/nextpas.core.simd.cpuinfo.x86/BuildOrTest.sh`、`tests/nextpas.core.simd.cpuinfo.x86/buildOrTest.bat`

### 可以后移

- `docs/nextpas.core.simd.md`
- `src/nextpas.core.simd.README.md`
- 其他偏阅读地图 / 维护叙事增强、但不直接影响 closeout 路径是否可跑通的文档整理

### 必须等 Windows 实证

- Windows evidence 真正通过 verifier 之前，不要把 release candidate checklist / completeness matrix / closeout roadmap 里的 Windows 项自动勾成完成
- `2026-03-10` / `2026-04-19` 这两批 Windows evidence 只能当“历史批次曾闭环”的归档事实，不能直接当成当前 `HEAD` 仍满足 **cross-platform freeze** 的证明
- 当前真实状态必须跟最新 `freeze-status` 走；截至 `2026-05-21` 当前 `HEAD` 应按 `code-green / cross-ready` 理解。只有 future source drift 或 future Windows evidence drift 再把 `freeze-status` 拉红时，才重新回到 freshness / billing 诊断。

## 还有哪些债没收完

这些不是“现在坏了”，而是后续最值得继续清理的地方：

1. **`dispatch / adapter` 还没走到真正的单一代码生成**
   - 现在已经有更强 checker
   - 但还没有做到“由一份源自动生成 Pascal 接线代码”

2. **`sbRISCVV` 仍是 experimental / 受限成熟度**
   - 口径已经统一
   - 但成熟度本身并没有因为文档收口而改变

3. **Windows 实机证据仍应继续补**
   - Windows 脚本口径已经对齐
   - 但脚本文案对齐不等于所有 Windows 实机场景都已重新验证

   Windows 实机 evidence 过 verifier 时，日志至少要包含这些字段：
   - `Source: collect_windows_b07_evidence.bat`
   - `HostOS: Windows_NT`
   - `CmdVer: Microsoft Windows ...`
   - `Working dir: C:\\...`（Windows 风格路径）

   Windows 日志一旦到位，按这个顺序收口：

   Run:
   ```bat
   tests\nextpas.core.simd\buildOrTest.bat evidence-win-verify
   ```

   前提条件：

   - 这一步必须运行在真实 Windows runner / Windows 实机上
   - `LAZBUILD` 必须解析到 native Windows `.exe/.bat/.cmd`
   - 不要把 `LAZBUILD` 指到 `Z:\opt\...` 这类 Wine 可见但 `cmd.exe` 不能执行的 Linux ELF
   - 本机 Wine 当前只适合作为 batch smoke / 日志新鲜度探针，不算可 finalize 的 Windows evidence runner
   - 若显式试 `SIMD_WIN_EVIDENCE_USE_BASH_GATE=1`，也只限 `cmd.exe` 真能解析 `bash` 的环境；当前本机 Wine 不属于这种环境，不要把它当成 host-side Unix bridge 逃生口

   `evidence-win-verify` 是 Windows native batch 路径上刻意保留的 alias；它对应的 canonical verifier 名字仍是 `verify-win-evidence`。这里继续用 alias，是为了让 `CMD/PowerShell` 侧 closeout 手册保持最短路径，不影响 shell 主线的 `win-evidence-via-gh` / `verify-win-evidence` 命名。

   Then run the required fail-close cross gate:
   ```bash
   FAFAFA_BUILD_MODE=Release SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_QEMU_NONX86_EVIDENCE=0 SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 SIMD_GATE_CPUINFO_LAZY_REPEAT=3 SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate
   ```

   Then:
   ```bash
   FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-finalize SIMD-YYYYMMDD-152
   ```

   这里不能直接从 `evidence-win-verify` 跳到 `win-closeout-finalize`，因为 native batch evidence 不会生成 fresh `gate_summary.md/json`；如果少了这步 cross gate，`freeze-status` 看到的仍可能是旧摘要。

   如果你只是在拆分诊断 closeout helper，才单独使用：

   ```bash
   bash tests/nextpas.core.simd/BuildOrTest.sh finalize-win-evidence
   bash tests/nextpas.core.simd/apply_windows_b07_closeout_updates.sh --apply --batch-id SIMD-YYYYMMDD-152
   ```

4. **非 x86 / QEMU 证据链仍然是发布前话题**
   - 日常快门禁不会默认把这些重路径都打开
   - closeout 时仍然应该靠 `gate-strict` 和对应 evidence 路径补强

5. **`perf-smoke` 仍是环境敏感证据**
   - 适合在固定机器 / 固定基线下显式开启
   - 不再作为默认 `gate-strict` 阻塞项；需要时请设置 `SIMD_GATE_PERF_SMOKE=1`

## 收口后的主线优先级

如果现在继续推进，不建议再把“所有 benchmark 里不够好看的一行”都当成主线。当前更合理的排序是：

1. **保留并复用已确认 ROI 的 fast-path**
   - `VecI16x32Add`
   - `VecU8x64Max`

2. **只做低成本观察**
   - `VecU32x16Mul`
   - 理由：门面开销已经压平到接近持平，不再是明确事故

3. **降级观察，不再主动深挖**
   - `VecU64x8Add`
   - `VecF32x4Add`
   - 理由：一个 raw 仍弱于 scalar，一个连小粒度 raw 都不具备当前轮次 ROI

4. **继续真正会影响发布质量的主线**
   - stable boundary 收口
   - evidence contract 统一
   - 真相源文档与 runbook 一致性

## 维护时最容易踩的坑

- 把 `gate` 当成发布放行的唯一依据
- 把 stable façade 误读成“所有 backend 都同等稳定”
- 在 `backend.adapter.map.csv` / generated include 之外重复维护 adapter 映射
- 改了 dispatch slot，却忘了看 adapter-sync / base-fill 覆盖
- 在 `SSE2` 上继续激进物理拆分

## 一句话交接

今天这个模块更像这样：**公开 API 已经比以前更稳定、更可读、更可验证；但 backend 成熟度仍有层次，experimental 路径仍要单独看待。**
