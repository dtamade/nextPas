# SIMD 完成度矩阵（Linux 视角）

更新时间：2026-03-11

## 1) 总体门禁状态

- Direct mapping 覆盖：`sse/mmx missing=0, extra=0`
- strict-extra：通过
- `AdvancedAlgorithms`：通过
- `perf-smoke`：通过（non-scalar backend healthy）
- `gate`：通过（simd + cpuinfo + cpuinfo.x86）
- Release 全链 gate（含 nonx86/qemu 选项）：通过
  - `FAFAFA_BUILD_MODE=Release SIMD_GATE_NONX86_IEEE754=1 SIMD_GATE_QEMU_NONX86_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate`
  - `gate PASS @ 2026-03-02 09:43:02`
- Linux 证据包：已生成（`logs/evidence-*`）
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
- 注意：这里的“已归档”表示历史 Windows 实机证据批次曾闭环，不等于当前 `HEAD` 仍是 `cross-ready`；如果最新 `freeze-status` 因 freshness / verifier / source-newer-than-evidence 变红，应以最新 `freeze-status` 为准。
- `closeout-release` 已作为完整 release 收口入口固化到 runner 与主文档。
- 机器检查：`check_interface_implementation_completeness.py --strict` 通过（`dispatch=558, P0=0/P1=0/P2=0`）
- 机器检查产物：
  - `tests/nextpas.core.simd/logs/interface_completeness.json`
  - `tests/nextpas.core.simd/docs/interface_implementation_completeness.md`

## 2) 接口族完成度

| 接口族                  | 机制实现状态                      | 测试状态 | 说明                                |
| ----------------------- | --------------------------------- | -------- | ----------------------------------- |
| Load/Store/Movq         | ✅ 主要路径机制化（x86/x64）      | ✅       | 含非对齐与回退测试                  |
| Set/Move 基础           | ✅（多数）                        | ✅       | `movehl/movelh/movss/movd` 均有覆盖 |
| 向量算术 `*_ps`         | ✅（add/sub/mul/div）             | ✅       | 高优先路径已机制化                  |
| 标量算术 `*_ss`         | ✅（add/sub/mul/div）             | ✅       | lane0 语义由测试约束                |
| 数学函数 sqrt/rcp/rsqrt | ✅                                | ✅       | 含标量/向量                         |
| Compare 基础            | ✅（多数）+ 语义实现（ord/unord） | ✅       | NaN/Inf 边界已补强                  |
| Shuffle/Unpack          | ✅+语义实现（shuffle）            | ✅       | imm8 多模式已补测                   |
| Convert                 | ✅（cvtsi2ss/cvtss2si/cvttss2si） | ✅       | 舍入模式行为有测试护栏              |
| Cache Control           | ✅（prefetch/sfence/stream）      | ✅       | 含 stream fallback 诊断测试         |
| CSR/Misc                | ✅                                | ✅       | get/setcsr roundtrip 通过           |

## 3) 剩余优化候选（按风险优先）

1. **低风险**：继续补齐边界测试（2026-02-09 已补入 `imm8` 组合、`imm8 0..255` 全量烟测、`NaN payload` 场景，以及 `ss`/`movhl,movlh` 位级语义护栏）。
2. **中风险**：统一部分“语义实现函数”的机制化策略（需严控 ABI 与跨平台回退）。
3. **中风险**：将 Linux 证据收集流程接入 CI stage（可选 job，不阻断主线）。

## 4) DoD 对照

- [x] API/架构一致性持续审计（当前批次无破坏性变更）
- [x] 关键路径正确性测试通过
- [x] SIMD gate 通过
- [x] 性能烟测通过
- [x] Linux 证据完整（含摘要）
- [x] Linux non-x86（arm/v7, arm64, riscv64）QEMU Release 证据通过
- [x] Windows 实机证据曾归档（历史批次；脚本+校验器+日志）
  - 注：此处记录的是历史归档完成态；当前源码时间线若已晚于该日志，仍需重新看 `freeze-status` 判断当前是否 cross-ready。

## 5) Linux Non-x86 闭环（2026-03-02）

- 首轮 arch-matrix 暴露阻断：
  - `tests/nextpas.core.simd/logs/qemu-multiarch-20260302-084959/summary.md`
  - 失败平台：`linux/arm/v7`, `linux/arm64`, `linux/riscv64`
  - 根因：`src/nextpas.core.simd.cpuinfo.pas` 在非 x86 编译时无条件访问 `X86` 字段。
- 修复后复验：
  - `tests/nextpas.core.simd/logs/qemu-multiarch-20260302-085958/summary.md`（arch-matrix 全 PASS）
  - `tests/nextpas.core.simd/logs/qemu-multiarch-20260302-091515/summary.md`（nonx86-evidence 全 PASS）
  - `tests/nextpas.core.simd/logs/qemu-multiarch-20260302-092937/summary.md`（gate 内 arch-matrix 全 PASS）
  - `tests/nextpas.core.simd/logs/rvv-opcode-lane-20260302-094743/summary.md`（RVV opcode lane 可选深度验证 PASS）

## 6) 剩余语义实现盘点（Batch31）

### A. 设计上保留语义/别名实现（非缺陷）

- `sse_set_ps/sse_set_ss/sse_setr_ps`
- `sse_shuffle_ps`（`imm8` 动态重排，语义实现更清晰）
- `sse_andn_ps`
- `sse_unpckhps/sse_unpcklps`
- `sse_movhl_ps/sse_movlh_ps`

### B. 混合实现（机制路径 + 安全回退）

- `load/store/movq/stream/prefetch/getcsr/setcsr/sfence`
- 这类函数已有 x86/x64 机制路径，保留跨平台或对齐安全回退。

### C. 下一批低风险候选

1. `sse_movaps`：可评估由纯复制实现收敛到机制化复制（保持不引入对齐陷阱）。
2. 对 `shuffle_ps` 增加更多 imm8 语义测试（继续扩大行为护栏）。

## 7) 持续补强增量（2026-02-09）

- 已补入 `cmpeq/cmpneq_ss` 位级语义护栏（`-0/+0`、`qNaN payload`、lane 保持）。
- 已补入 `movemask_ps` 符号位矩阵断言（含 NaN/Inf 组合）。
- 已补入 `cmpgt/cmpge_ss` 位级语义护栏（`3>2`、`-0/+0`、`1<2`）与 lane 保持断言。
- 已补入比较对偶关系矩阵：
  - `cmpgt_ps(a,b) == cmplt_ps(b,a)`
  - `cmpge_ps(a,b) == cmple_ps(b,a)`
  - `ss` 版本对 lane0 做同构断言。
- 已补入 `movemask_ps` 符号位 16 组全量断言（`mask=0..15`）。
- 已补入 `cmpgt/cmpge_ps` 的 `Inf/-Inf` 分层语义矩阵断言（3 组 4-lane）。
- 已补入 compare 关系矩阵断言：`cmpgt/cmple` 与 `cmpge/cmplt` 在 finite/Inf 场景的互斥/完备不变量。
- 已补入 compare 掩码向量到 `movemask_ps` 位序映射一致性断言（`cmpgt/ge/lt/le/eq/neq`）。
- 已补入 `cmpeq/cmplt/cmpgt` 与 `cmpneq` 的分区/补集一致性矩阵断言（finite/Inf）。
- 已补入 `compare_ss` lane0 分区与 lane1..3 位级保持矩阵断言（`eq/lt/gt/neq`）。
- 已补入 compare 组合一致性断言：`cmpge/cmple` 与 `cmpgt/cmplt/cmpeq` 在 `ps+ss` 路径的恒等关系。
- 已补入 `compare_ss -> movemask_ps` 位序联动断言：bit0 随 lane0 掩码切换，bit1..3 保持来自 A。
- 已补入 `cmpge_ss/cmple_ss` 在 `-0/+0` 与 `Inf` 边界下的 bit0 映射与 lane 保持矩阵断言。
- 已补入 `cmpord_ss/cmpunord_ss` 在 ordered/unordered（qNaN payload）场景下的 bit0 映射与 lane 保持断言。
- 已补入 `ss` compare 家族横向一致性断言：统一 ordered 矩阵下验证 bit0 映射、lane 保持与族内组合恒等关系。
- 已补入 unordered 专项矩阵：`cmpord/cmpunord/eq/neq_ss` 在 qNaN payload 场景下的 bit0 映射、lane 保持与互补关系断言。
- 已补入 `cmpord_ps/cmpunord_ps` 在 qNaN payload 矩阵下的整掩码映射与互补关系断言（`OR=0xF, AND=0`）。
- 已补入 `ps` compare 家族在 ordered 矩阵下的 bitmask 映射与组合恒等关系断言（`neq/~eq`, `ge=gt|eq`, `le=lt|eq`）。
- 已补入 `ps` compare + `movemask` 稳定性 smoke 矩阵（finite/Inf），并校验 compare 家族组合恒等关系。
- 已补入 `DispatchAPI` 横向一致性 smoke：`Test_VecF32x4_CoreOps_DispatchCrossBackendParity`，覆盖 `sbScalar/sbSSE2/sbAVX2` 可用后端的 `Add/Mul/Min/Max/CmpLt/ReduceAdd` 一致性断言（registered + TrySetActiveBackend）。
- 已补入 non-x86 最小 parity smoke：`Test_NonX86_MinimalDispatchParity_IfAvailable`，对 `sbNEON/sbRISCVV` 采用“已注册即测”策略，覆盖 `VecF32x4 Add/CmpLt/ReduceAdd`。
- 已补入 non-x86 wiring 护栏：`Test_NonX86_DispatchTable_WiringChecklist`，对已注册 `sbNEON/sbRISCVV` 校验 `Core + Mask + Narrow` 高价值槽位绑定完整性。
- 已扩展 non-x86 wiring 护栏到 P1：覆盖 `Narrow Compare` 全系（`Lt/Le/Gt/Ge/Ne`）与 `Mask Any/None/PopCount/FirstSet`（`Mask2/4/8/16`）。
- 已完成 non-x86 P1 wiring 收口：新增 `Narrow bitwise`（`And/Or/Xor/Not`）与 `F32x4 ReduceMin/ReduceMax/ReduceMul` 的槽位完整性断言。
- 已新增 non-x86 runtime parity：`Test_NonX86_NarrowBitwiseReduce_RuntimeParity_IfAvailable`，以 Scalar 为基准校验 `Narrow bitwise + F32x4 ReduceMin/Max/Mul` 结果一致性。
- 已新增 non-x86 runtime parity（Compare + Mask）：`Test_NonX86_NarrowCompareMask_RuntimeParity_IfAvailable`，覆盖 `Narrow Compare` 与 `Mask2/4/8/16` 行为函数的 Scalar 一致性。
- 已新增 non-x86 runtime parity：
  - `Test_NarrowAndNotParity_IfAvailable`
  - `Test_DotParity_IfAvailable`
  - `Test_I16x32_CoreParity_IfAvailable`
  - `Test_I8x64_CoreParity_IfAvailable`
  - `Test_U32x16_U64x8_CoreParity_IfAvailable`
  - `Test_WideInteger_FuzzSeed_Parity_IfAvailable`
- 2026-03-11 机器检查快照：`dispatch=558, neon=558, riscvv=558, P0=0/P1=0/P2=0`
- 2026-03-11 最新 backend benchmark summary：`tests/nextpas.core.simd/logs/backend-bench-20260311-103804/summary.md`
- 关键性能结论：
  - `VecI16x32Add`：`3.35x`；raw：`3.07x`
  - `VecU32x16Mul`：`0.99x`；raw：`1.00x`
  - `VecU64x8Add`：`0.76x`；raw：`0.80x`
  - `VecU8x64Max`：`3.96x`；raw：`4.31x`
  - `VecF32x4Add`：`0.76x`；raw：`0.89x`
- 说明：宽整型若仅靠 wrapper/标量复用，当前可保证 correctness，但不必然带来性能正收益。
- Linux 冻结判定：non-x86（NEON/RISCVV）已完成 wiring + runtime parity 双层闭环；后面的 “Windows 实机证据已闭环” 只应理解成历史归档事实，不是当前 `HEAD` 仍 cross-ready 的信号，当前 Windows readiness 以 latest `freeze-status` / `win-evidence-preflight` 为准。
- 已新增 Windows 证据批量收口能力：
  - `buildOrTest.bat verify-win-evidence`（日志校验）
  - `buildOrTest.bat evidence-win-verify`（采集 + 校验证据包；仅限真实 Windows runner / Windows 实机，且需要 native Windows `LAZBUILD`；手工路径仍需后续 fail-close cross gate + finalize）
  - 若显式试 `SIMD_WIN_EVIDENCE_USE_BASH_GATE=1`，也只限 `cmd.exe` 真能解析 `bash` 的环境；当前本机 Wine 不属于这种环境，不要把它当成 host-side Unix bridge 逃生口。
  - `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-via-gh SIMD-YYYYMMDD-152`（推荐的一键 GH 闭环）
  - Runbook：`tests/nextpas.core.simd/docs/windows_b07_closeout_runbook.md`

## 8) 机器检查快照（2026-03-11）

- 命令：
  - `python3 tests/nextpas.core.simd/check_interface_implementation_completeness.py --strict`
  - `python3 tests/nextpas.core.simd/generate_interface_checklist_v2.py`
- 快照结果：
  - dispatch slots total：`558`
  - backend slot counts：`scalar=558, sse2=463, sse3=10, ssse3=2, sse41=28, sse42=1, avx2=491, avx512=187, neon=558, riscvv=558`
  - severity：`P0=0 / P1=0 / P2=0`
  - 说明：机器检查为 token/赋值启发式扫描，不等同于完整语义正确性证明。
- 结论：
  - 当前 non-x86 在机器检查口径下已达到 dispatch 满覆盖。
  - 语义一致性仍以 suite 回归与跨后端对照测试作为最终依据。

## 9) 历史 Windows 归档批次（非当前 HEAD ready 信号）

<!-- SIMD-WIN-CLOSEOUT-2026-03-10 -->

- Windows 实机证据：已归档（2026-03-10）
  - Log: tests/nextpas.core.simd/logs/windows_b07_gate.log
  - Summary: tests/nextpas.core.simd/logs/windows_b07_closeout_summary.md
  - 验证：verify_windows_b07_evidence PASS

<!-- SIMD-WIN-CLOSEOUT-2026-03-14 -->

- Windows 实机证据：已归档（2026-03-14）
  - Log: tests/nextpas.core.simd/logs/windows_b07_gate.log
  - Summary: tests/nextpas.core.simd/logs/windows_b07_closeout_summary.md
  - 验证：verify_windows_b07_evidence PASS

<!-- SIMD-WIN-CLOSEOUT-2026-03-21 -->

- Windows 实机证据：已归档（2026-03-21）
  - Log: tests/nextpas.core.simd/logs/windows-closeout/SIMD-20260320-152/windows_b07_gate.log
  - Summary: tests/nextpas.core.simd/logs/windows-closeout/SIMD-20260320-152/windows_b07_closeout_summary.md
  - 验证：verify_windows_b07_evidence PASS

<!-- SIMD-WIN-CLOSEOUT-2026-03-24 -->

- Windows 实机证据：已归档（2026-03-24）
  - Log: tests/nextpas.core.simd/logs/windows_b07_gate.log
  - Summary: tests/nextpas.core.simd/logs/windows_b07_closeout_summary.md
  - 验证：verify_windows_b07_evidence PASS

<!-- SIMD-WIN-CLOSEOUT-2026-04-02 -->

- Windows 实机证据：已归档（2026-04-02）
  - Log: tests/nextpas.core.simd/logs/windows-closeout/SIMD-20260402-152/windows_b07_gate.log
  - Summary: tests/nextpas.core.simd/logs/windows-closeout/SIMD-20260402-152/windows_b07_closeout_summary.md
  - 验证：verify_windows_b07_evidence PASS

<!-- SIMD-WIN-CLOSEOUT-2026-05-19 -->
- Windows 实机证据：已归档（2026-05-19）
  - Log: tests/nextpas.core.simd/logs/windows-closeout/SIMD-20260519-152/windows_b07_gate.log
  - Summary: tests/nextpas.core.simd/logs/windows-closeout/SIMD-20260519-152/windows_b07_closeout_summary.md
  - 验证：verify_windows_b07_evidence PASS

<!-- SIMD-WIN-CLOSEOUT-2026-05-20 -->
- Windows 实机证据：已归档（2026-05-20）
  - Log: tests/nextpas.core.simd/logs/windows-closeout/SIMD-20260520-152/windows_b07_gate.log
  - Summary: tests/nextpas.core.simd/logs/windows-closeout/SIMD-20260520-152/windows_b07_closeout_summary.md
  - 验证：verify_windows_b07_evidence PASS

<!-- SIMD-WIN-CLOSEOUT-2026-05-21 -->
- Windows 实机证据：已归档（2026-05-21）
  - Log: tests/nextpas.core.simd/logs/windows-closeout/SIMD-20260521-152/windows_b07_gate.log
  - Summary: tests/nextpas.core.simd/logs/windows-closeout/SIMD-20260521-152/windows_b07_closeout_summary.md
  - 验证：verify_windows_b07_evidence PASS

<!-- SIMD-WIN-CLOSEOUT-2026-05-23 -->
- Windows 实机证据：已归档（2026-05-23）
  - Log: tests/nextpas.core.simd/logs/windows_b07_gate.log
  - Summary: tests/nextpas.core.simd/logs/windows_b07_closeout_summary.md
  - 验证：verify_windows_b07_evidence PASS
