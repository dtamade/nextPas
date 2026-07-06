# RISC-V V 后端正确性测试需求

## 状态

当前 RISC-V V 后端为实验性（`SIMD_EXPERIMENTAL_RISCVV`），仅有 4 个合约/接线测试。
需要在 QEMU 或真机环境下补充向量运算正确性验证。

## 需要覆盖的操作

以下操作需要与 Scalar 后端结果进行 parity 验证：

### F32x4 基础
- Add / Sub / Mul / Div
- CmpEq / CmpLt / CmpGt
- ReduceAdd / ReduceMin / ReduceMax
- Floor / Ceil / Round / Trunc
- Fma

### I32x4 基础
- Add / Sub
- And / Or / Xor / Not
- ShiftLeft / ShiftRight
- CmpEq / CmpLt

### Load/Store
- Aligned / Unaligned Load
- Store

## 运行环境要求

- QEMU user-mode (riscv64) + FPC cross-compiler
- 或 GitHub Actions 的 `simd-riscvv-native-evidence.yml` workflow
- 编译标志: `-dSIMD_EXPERIMENTAL_RISCVV -dFAFAFA_SIMD_TEST_REGISTER_RISCVV_BACKEND`

## 参考

- 现有 CI: `.github/workflows/simd-riscvv-native-evidence.yml`
- Docker 脚本: `tests/nextpas.core.simd/docker/run_riscv64_rvv_image.sh`
