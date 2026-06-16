# SIMD BuildOrTest.sh 命令矩阵

> 最后更新: 2026-06-13
> 基于 `core/tests/nextpas.core.simd/BuildOrTest.sh` (1071 行)

## 总览

共 **47 个子命令**，分为 10 个类别。7 个历史命令在当前 worktree 中 fail-close。

---

## 一、日常开发快门禁

| 子命令 | 步骤数 | 产物 | 关键环境变量 | 可行环境 |
|--------|--------|------|-------------|----------|
| `check` | 3 | `logs/build.txt`, `logs/test.txt`, `logs/dispatch_contract_signature.json`, `logs/public_abi_signature.json` | `SIMD_ENABLE_NEON_BACKEND` (opt-in), `SIMD_ENABLE_RISCVV_BACKEND` (opt-in) | Linux/macOS |
| `test` | 1-2 | 编译产物 + `logs/test.txt` | `FAFAFA_BUILD_MODE=Release`, `SIMD_RUN_ONLY_BUILD=1`, `SIMD_ENABLE_NEON_BACKEND`, `SIMD_ENABLE_RISCVV_BACKEND`, `SIMD_ENABLE_AVX512_BACKEND`, `SIMD_FPC_EXTRA_DEFINES` | Linux/macOS |
| `contract-signature` | 1 | `logs/dispatch_contract_signature.json` | — | Linux/macOS |
| `publicabi-signature` | 1 | `logs/public_abi_signature.json` | — | Linux/macOS |
| `coverage` | 2 | `logs/intrinsics_coverage.json` | `SIMD_COVERAGE_STRICT_EXTRA=1`, `SIMD_COVERAGE_REQUIRE_AVX2=1`, `SIMD_COVERAGE_REQUIRE_EXPERIMENTAL=1` | Linux/macOS |
| `wiring-sync` | 1 | stdout | `SIMD_WIRING_SYNC_STRICT_EXTRA=1` | Linux/macOS |
| `nonx86-ieee754` | 1 | `logs/test.txt` | — | Linux/macOS |
| `perf-smoke` | 1 | `logs/test.txt` | `SIMD_PERF_VECTOR_ASM=0/1/auto` (默认 auto: x86_64 开启) | Linux/macOS |
| `nonx86-optin-list-suites` | 2 | `logs/nonx86.optin/[neon\|riscvv]/` | — | Linux/macOS |
| `helper-semantics` | 1 | stdout | — | Linux/macOS |

---

## 二、实现回归

| 子命令 | 步骤 | 串行顺序 | 产物 |
|--------|------|---------|------|
| `impl-smoke-nonx86` | 8 | helper-semantics → key-slot-audit → wiring-sync-strict → riscvv-abi-shape → register-truthfulness(neon) → register-truthfulness(riscvv) → backend-parity → dataplane-parity | stdout chain |
| `impl-audit-nonx86` | 9+ | impl-smoke-nonx86 → implementation-matrix-sync → native-evidence-verify-optional | `logs/implementation_matrix_sync.json` |

---

## 三、Closeout / Release

| 子命令 | 实际行为 | 可行环境 |
|--------|---------|---------|
| `closeout-host-local` | impl-audit-nonx86 + **fail-close**（需要 QEMU） | Linux/macOS |
| `closeout-host-local-from-import` | import → closeout-host-local | Linux/macOS |
| `closeout-release` | **fail-close**（历史 Windows/GH closeout 未恢复） | — |
| `win-evidence-preflight` | **fail-close** | — |
| `win-evidence-via-gh` | **fail-close** | — |
| `finalize-win-evidence` | **fail-close** | — |
| `win-closeout-snippets` | **fail-close** | — |
| `win-closeout-finalize` | **fail-close** | — |

---

## 四、Gate Summary 工具链

| 子命令 | 输入 | 输出 | 阈值环境变量 |
|--------|------|------|-------------|
| `gate-summary` | `logs/gate_summary.md` | stdout + `logs/gate_summary.json` | `SIMD_GATE_STEP_WARN_MS` (默认 20000), `SIMD_GATE_STEP_FAIL_MS` (默认 120000), `SIMD_GATE_SUMMARY_FILTER=ALL\|FAIL\|SLOW` |
| `gate-summary-sample` | — | `logs/gate_summary.sample.<scenario>.md` | 同上 |
| `gate-summary-rehearsal` | 调用 `rehearse_gate_summary_thresholds.sh` | stdout | 同上 |
| `gate-summary-selfcheck` | 调用 rehearsal | stdout | — |
| `gate-summary-inject` | — | 注入 sample → canonical logs | — |
| `gate-summary-rollback` | — | 恢复上一个 backup | — |
| `gate-summary-backups` | — | 列出 backups | — |

---

## 五、Freeze Status

| 子命令 | 行为 | 产物 |
|--------|------|------|
| `freeze-status` | 跨平台 freeze readiness | `logs/freeze_status.json` |
| `freeze-status-linux` | Linux-only freeze | `logs/freeze_status.json` |
| `freeze-status-rehearsal` | 演练失败场景 | stdout |

---

## 六、Evidence 验证

| 子命令 | 输入要求 |
|--------|---------|
| `verify-win-evidence` | Windows evidence logs（需真实 Windows runner 生成） |
| `historical-closeout-note-check` | 扫描 `docs/simd/` 中的过期 closeout 标注 |
| `active-closeout-truth-check` | 扫描 active closeout docs 是否与 HEAD 漂移 |
| `evidence-linux` | **fail-close**（历史 Linux closeout 未恢复） |

---

## 七、QEMU（Docker）

| 子命令 | 代理目标 |
|--------|---------|
| `qemu-nonx86-evidence` | `docker/run_multiarch_qemu.sh nonx86-evidence` |
| `qemu-cpuinfo-nonx86-evidence` | `docker/run_multiarch_qemu.sh cpuinfo-nonx86-evidence` |
| `qemu-cpuinfo-nonx86-full-evidence` | `docker/run_multiarch_qemu.sh cpuinfo-nonx86-full-evidence` |
| `qemu-cpuinfo-nonx86-full-repeat` | `docker/run_multiarch_qemu.sh cpuinfo-nonx86-full-repeat` |
| `qemu-cpuinfo-nonx86-suite-repeat` | `docker/run_multiarch_qemu.sh cpuinfo-nonx86-suite-repeat` |
| `qemu-arch-matrix-evidence` | `docker/run_multiarch_qemu.sh arch-matrix-evidence` |
| `qemu-nonx86-experimental-asm` | `docker/run_multiarch_qemu.sh nonx86-experimental-asm` |

---

## 八、实验性 Intrinsics

| 子命令 | 行为 |
|--------|------|
| `experimental-intrinsics-tests` | 代理到 `nextpas.core.simd.intrinsics.experimental/BuildOrTest.sh test-all` |
| `experimental-intrinsics-closure` | check → coverage(strict+avx2+experimental) → experimental-status-check → experimental-tests |

---

## 九、Native Evidence

| 子命令 | 行为 |
|--------|------|
| `native-evidence [neon\|riscvv]` | 代理到 `collect_nonx86_native_evidence.sh` |
| `verify-nonx86-native-evidence` | 校验 `fixtures/native-evidence/` 中的归档 |
| `import-nonx86-native-evidence` | 导入外部 evidence → 自动 verify |

---

## 十、Windows Closeout 辅助

| 子命令 | 行为 |
|--------|------|
| `win-closeout-dryrun` / `win-closeout-3cmd` | 打印推荐的 Windows 3 步 closeout 命令链 |

---

## 完整环境变量矩阵

| 变量 | 影响子命令 | 类型 | 默认值 |
|------|-----------|------|--------|
| `SIMD_OUTPUT_ROOT` | 全部 | 路径 | `core/build/tests/nextpas.core.simd` |
| `FAFAFA_BUILD_MODE=Release` | test, perf-smoke, impl-*, closeout-* | flag | — |
| `SIMD_ENABLE_NEON_BACKEND=1` | test, check, nonx86-optin-list-suites | flag | `0` |
| `SIMD_ENABLE_RISCVV_BACKEND=1` | test, check, nonx86-optin-list-suites | flag | `0` |
| `SIMD_ENABLE_AVX512_BACKEND=1` | test | flag | `0` |
| `SIMD_RUN_ONLY_BUILD=1` | test | flag | `0` |
| `SIMD_FPC_EXTRA_DEFINES` | test | string | — |
| `SIMD_PERF_VECTOR_ASM` | perf-smoke | `0\|1\|auto` | `auto` |
| `SIMD_COVERAGE_STRICT_EXTRA` | coverage, experimental-intrinsics-closure | flag | `0` |
| `SIMD_COVERAGE_REQUIRE_AVX2` | coverage, experimental-intrinsics-closure | flag | `0` |
| `SIMD_COVERAGE_REQUIRE_EXPERIMENTAL` | coverage, experimental-intrinsics-closure | flag | `0` |
| `SIMD_WIRING_SYNC_STRICT_EXTRA` | wiring-sync, impl-smoke-nonx86 | flag | `0` |
| `SIMD_GATE_STEP_WARN_MS` | gate-summary-* | ms | `20000` |
| `SIMD_GATE_STEP_FAIL_MS` | gate-summary-* | ms | `120000` |
| `SIMD_GATE_SUMMARY_FILTER` | gate-summary | `ALL\|FAIL\|SLOW` | `ALL` |
| `SIMD_GATE_SUMMARY_FILE` | gate-summary | 路径 | `logs/gate_summary.md` |
| `SIMD_GATE_SUMMARY_JSON` | gate-summary | flag | `0` |
| `SIMD_NONX86_NATIVE_EVIDENCE_ROOT` | verify-nonx86-native-evidence, closeout-*, impl-audit-nonx86 | 路径 | `fixtures/native-evidence` |
| `SIMD_QEMU_PLATFORMS` | closeout-host-local, QEMU actions | 字符串 | — |
| `SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE` | closeout-host-local | flag | `1` |
| `FPC_BIN` / `FPC` | 全部 (编译) | 路径 | `fpc` |
| `PYTHON_BIN` | Python checker | 路径 | `python3` |

---

## 建议日常矩阵

### 日常改动后必须跑

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh check
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DispatchAPI
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DirectDispatch
```

### 改动 x86 bounded frontier 时

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh impl-smoke-x86  # (需外部提供)
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh impl-smoke-nonx86
```

### 改动 dispatch/runtime/cpuinfo 接口时

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_RuntimeAPI
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DataPlane
bash tests/nextpas.core.simd/BuildOrTest.sh contract-signature
bash tests/nextpas.core.simd/BuildOrTest.sh publicabi-signature
```

### Host-local closeout

```bash
SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' \
SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=0 \
FAFAFA_BUILD_MODE=Release \
bash tests/nextpas.core.simd/BuildOrTest.sh closeout-host-local
```

---

## 补充说明

- `dispatch_slots_total` 有两个口径：旧文档中的 `558` 和新 checker (`616`)。`616` 是当前 canonical 值（`check_interface_implementation_completeness.py --strict` 输出），`558` 是历史快照。详见 `docs/simd/closeout.md` 和 `docs/interface_implementation_completeness.md`。
- `gate` / `gate-strict` / `evidence-linux` 在当前 `BuildOrTest.sh` 中均为 fail-close，因为历史 Linux gate/closeout 主链尚未恢复。替代路径是 `check` + 定向 suites + `gate-summary-selfcheck` + `freeze-status-linux`。
- 所有 QEMU 子命令均依赖 Docker（`docker/run_multiarch_qemu.sh`）。
### NEON asm 门控说明

NEON asm 启用依赖三重编译期 define：
- `NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM` — 共享主控（NEON + RISCVV 共用）
- `NEXTPAS_SIMD_ENABLE_NEON_ASM` — NEON 专属开关
- `NEXTPAS_SIMD_NEON_ASM_COMPILER_READY` — 编译器就绪开关

G14.3 评估认为第三个 define 冗余（已被 `FPC_FULLVERSION >= 030301` 覆盖），但当前保留以维持显式语义和编译安全。待 arm64 CI 环境就绪后再考虑简化。

### `check_simd_contract_roadmap.py` 硬编码 558 已知问题

`check_simd_contract_roadmap.py:302-308` 的正则会匹配所有 `558/558` 形式（如 README.md 中 NEON 的 `558 / 558` backend 自有槽位覆盖率），将其误报为 stale snapshot。这些 backend 自有槽位数（558）不等于 canonical dispatch_slots_total（616），但 checker 的正则无法区分两者。建议后续 refinements：
- 将 README.md 的 backend 表格中的 `558` 更新为 `616`（显示 canonical 总数）
- 或修改 checker 正则排除 backend-specific 上下文

### NEON asm 门控说明

NEON asm 启用依赖三重编译期 define：
- `NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM` — 共享主控（NEON + RISCVV 共用）
- `NEXTPAS_SIMD_ENABLE_NEON_ASM` — NEON 专属开关
- `NEXTPAS_SIMD_NEON_ASM_COMPILER_READY` — 编译器就绪开关

G14.3 评估认为第三个 define 冗余（已被 `FPC_FULLVERSION >= 030301` 覆盖），但当前保留以维持显式语义和编译安全。待 arm64 CI 环境就绪后再考虑简化。