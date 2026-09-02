# nextpas.core.simd 维护指南

> 最后更新: 2026-08-31

## 概述

本文档提供 SIMD 模块的维护指南，包括日常维护、问题排查、性能优化等。

## 日常维护

### 1. 代码审查

**检查清单**:
- [ ] 新增操作是否有标量回退
- [ ] 新增操作是否有测试覆盖
- [ ] 新增操作是否有基准测试
- [ ] 新增操作是否遵循命名规范
- [ ] 新增操作是否有文档

### 2. 测试验证

```bash
# 运行所有 SIMD 测试
make -C core/tests/nextpas.core.simd clean test

# 运行特定测试
make -C core/tests/nextpas.core.simd/test_dispatch clean test

# 运行基准测试
make -C core/tests/nextpas.core.simd/bench_dispatch_overhead clean test
```

### 3. 性能监控

```bash
# 基准测试
./bench_simd --iterations=1000

# 性能对比
./bench_simd --compare=scalar,sse2,avx2
```

## 问题排查

### 1. 编译错误

**问题**: 找不到 SIMD 类型
**解决**: 检查 `uses nextpas.core.simd.base`

**问题**: 找不到 SIMD 函数
**解决**: 检查 `uses nextpas.core.simd`

### 2. 运行时错误

**问题**: 分段错误
**解决**: 检查内存对齐

**问题**: 结果不正确
**解决**: 检查特殊值处理 (NaN, Inf, -0.0)

### 3. 性能问题

**问题**: 性能低于预期
**解决**: 检查是否使用了最优后端

**问题**: 分派器开销大
**解决**: 使用批量操作或编译期快速路径

## 性能优化

### 1. 批量操作

```pascal
// 不推荐: 逐个操作
for I := 0 to N-1 do
  C[I] := VecF32x4Add(A[I], B[I]);

// 推荐: 批量操作
BatchAddF32x4(A, B, C);
```

### 2. 编译期快速路径

```pascal
{$IFDEF HAS_AVX2}
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := AVX2AddF32x4(a, b);  // 直接调用
end;
{$ENDIF}
```

### 3. 内存对齐

```pascal
// 不推荐: 未对齐内存
var
  A: array[0..3] of Single;

// 推荐: 对齐内存
var
  A: TVecF32x4;  // 自动 16-byte 对齐
```

## 代码规范

### 1. 命名规范

- **向量类型**: `TVecF32x4`, `TVecF64x2`, `TVecI32x4`
- **掩码类型**: `TMask4`, `TMask8`, `TMask16`
- **函数名**: `VecF32x4Add`, `MemEqual`, `Utf8Validate`
- **后端名**: `SSE2AddF32x4`, `AVX2AddF32x4`, `NEONAddF32x4`

### 2. 代码风格

- **缩进**: 2 空格
- **命名**: PascalCase
- **参数**: `const` 前缀
- **返回值**: `Result`

### 3. 文档注释

```pascal
{**
 * @desc 两个 128-bit 浮点向量相加
 *
 * @params
 *   A  第一个向量
 *   B  第二个向量
 *
 * @return 相加结果
 *
 * @note 自动选择最优后端
 *}
function VecF32x4Add(const A, B: TVecF32x4): TVecF32x4; inline;
```

## 新增操作

### 1. 添加新操作

**步骤**:
1. 在 `base.pas` 中添加类型定义 (如果需要)
2. 在 `dispatch.pas` 中添加函数指针槽位
3. 在 `scalar.pas` 中添加标量实现
4. 在 `sse2.pas` 中添加 SSE2 实现
5. 在 `avx2.pas` 中添加 AVX2 实现
6. 在 `neon.pas` 中添加 NEON 实现
7. 在 `simd.pas` 中添加门面函数
8. 添加测试
9. 添加基准测试
10. 更新文档

### 2. 示例: 添加 VecF32x4Fma

**Step 1**: 在 `base.pas` 中添加类型 (如果需要)

**Step 2**: 在 `dispatch.pas` 中添加槽位
```pascal
type
  TSimdDispatchTable = record
    // ... 其他操作
    FmaF32x4: function(const a, b, c: TVecF32x4): TVecF32x4;
  end;
```

**Step 3**: 在 `scalar.pas` 中添加标量实现
```pascal
function ScalarFmaF32x4(const a, b, c: TVecF32x4): TVecF32x4;
begin
  Result.f[0] := a.f[0] * b.f[0] + c.f[0];
  Result.f[1] := a.f[1] * b.f[1] + c.f[1];
  Result.f[2] := a.f[2] * b.f[2] + c.f[2];
  Result.f[3] := a.f[3] * b.f[3] + c.f[3];
end;
```

**Step 4**: 在 `sse2.pas` 中添加 SSE2 实现
```pascal
function SSE2FmaF32x4(const a, b, c: TVecF32x4): TVecF32x4; assembler;
asm
  movups xmm0, [a]
  movups xmm1, [b]
  movups xmm2, [c]
  mulps xmm0, xmm1     // a * b
  addps xmm0, xmm2     // a * b + c
  movups [Result], xmm0
end;
```

**Step 5**: 在 `simd.pas` 中添加门面函数
```pascal
function VecF32x4Fma(const a, b, c: TVecF32x4): TVecF32x4; inline;
begin
  Result := GetSimdFacadeDispatchFastPath^.FmaF32x4(a, b, c);
end;
```

**Step 6**: 添加测试
```pascal
procedure TestVecF32x4Fma;
var
  A, B, C, Result: TVecF32x4;
begin
  A := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  B := VecF32x4Make(5.0, 6.0, 7.0, 8.0);
  C := VecF32x4Make(9.0, 10.0, 11.0, 12.0);
  Result := VecF32x4Fma(A, B, C);
  Assert(Result.f[0] = 14.0);  // 1*5+9
  Assert(Result.f[1] = 22.0);  // 2*6+10
  Assert(Result.f[2] = 32.0);  // 3*7+11
  Assert(Result.f[3] = 44.0);  // 4*8+12
end;
```

**Step 7**: 添加基准测试
```pascal
procedure BenchVecF32x4Fma(const ACtx: IBenchContext);
var
  A, B, C, Result: TVecF32x4;
begin
  A := VecF32x4Splat(1.0);
  B := VecF32x4Splat(2.0);
  C := VecF32x4Splat(3.0);
  Result := VecF32x4Fma(A, B, C);
end;
```

## 新增后端

### 1. 添加新后端

**步骤**:
1. 创建 `nextpas.core.simd.<backend>.pas`
2. 实现所有操作
3. 注册到分派器
4. 添加测试
5. 添加基准测试
6. 更新文档

### 2. 示例: 添加 AVX-512 后端

**Step 1**: 创建 `nextpas.core.simd.avx512.pas`

**Step 2**: 实现所有操作
```pascal
function AVX512AddF32x16(const a, b: TVecF32x16): TVecF32x16; assembler;
asm
  vmovups zmm0, [a]
  vmovups zmm1, [b]
  vaddps zmm0, zmm0, zmm1
  vmovups [Result], zmm0
end;
```

**Step 3**: 注册到分派器
```pascal
procedure RegisterAVX512Backend;
var
  dispatchTable: TSimdDispatchTable;
begin
  FillBaseDispatchTable(dispatchTable);
  dispatchTable.Backend := sbAVX512;
  dispatchTable.AddF32x16 := @AVX512AddF32x16;
  // ... 其他操作
  RegisterBackend(sbAVX512, dispatchTable);
end;

initialization
  RegisterAVX512Backend;
```

**Step 4**: 添加测试

**Step 5**: 添加基准测试

**Step 6**: 更新文档

## 文档维护

### 文档结构

```
docs/simd/
├── README.md              # 模块概述、快速入门
├── architecture.md        # 架构设计
├── api.md                 # 公开 API 参考
├── backends.md            # 后端实现详解
├── intrinsics.md          # Intrinsics 层详解
├── dispatch.md            # 分派器层详解
├── platforms.md           # 平台支持
├── roadmap.md             # 路线图和计划任务
└── maintenance.md         # 维护指南
```

### 文档更新

**何时更新**:
- 新增操作
- 新增后端
- 性能优化
- Bug 修复
- 架构变更

**如何更新**:
1. 更新相关文档
2. 检查文档一致性
3. 运行文档测试 (如果有的话)
4. 提交文档

## 已知技术债（Known Technical Debt）

| 债项 | 状态 | 约束 |
|------|------|------|
| LoongArch/SVE/SVE2 | experimental/stub intrinsics only；仅作为 opt-in qualification surface；not stable backend；有源码、有 fail-close guard、有环境变量守卫，但缺 release-grade runtime proof | 不可在生产路径激活；已标注为 experimental stub |
| 并发 suite heaptrc | opt-in：`make concurrent-heaptrc`（共享 `x86-heaptrc-build`，5 个并发 suite / 30 tests，`Suites:` 计数 pin + HEAPTRC 环境通道 + dump-file pin）；2026-08-31 落地，M4.1 换到诚实通道，M4.3 进入 `test-all` | 新增并发 suite 必须同步 Makefile `CONCURRENT_SUITES` 与 `CONCURRENT_SUITE_COUNT`，否则计数 pin fail-close |
| ~~TTestCase_DirectDispatch 无调度~~ | **已解决（M4.3, 2026-08-31）**：`make direct-dispatch-focused` 调度大 parity suite（32 tests，`Suites: 1` pin + heaptrc pins），与 `concurrent-heaptrc` 共享 `x86-heaptrc-build`，均已进入 `test-all` | `--suite=` 为精确匹配（实测 `TTestCase_DirectDispatch` 不连带 `...Concurrent`）|
| runner 未知参数静默忽略 | `nextpas.core.simd.test.lpr` 的 `ParseCustomArgs` 跳过不认识的参数（历史上 `--suite=` 因此被吞、`neon-optin-focused` 静默全量跑）；`--suite=` 已于 2026-08-31 实装并 fail-close | 传给 runner 的新参数必须实测生效（看 Summary 计数），不能只看退出码 |
| **FPC trunk heaptrc 控制台 dump 丢失** | FPC 3.3.1-19195（2026-01-07 安装）退出期 heap dump 永不到达 stdout/stderr（连泄漏程序也静默）；环境变量通道正常：`HEAPTRC=haltonnotreleased` → 泄漏时退出码 203，`log=<file>` → dump 落文件。M4.1 已把本 lane 全部 -gh 门换到 `HEAPTRC='haltonnotreleased,log=…'` + `HEAPTRC_PINS`（dump 存在 + `0 unfreed` 双 pin，防真空）；`common.mk` 增加 `HEAPTRC_GATE=1` opt-in（math 全家 16 个可执行项目已挂） | **规则：任何泄漏门禁止 grep 程序输出找 heaptrc 行——必须走环境变量通道**；跨模块影响（全仓 output-grep 泄漏证据可疑）已上报总控 |
| test_api_coverage.pas 死文件贡献覆盖信用 | fpcunit 时代老单体，无任何 Makefile/脚本执行它，但 `check_public_api_test_coverage.py` rglob 扫其文本计覆盖（720 符号中部分仅靠它计数）| 「执行层死、合同层活」：删除会打红覆盖门，需专项卡评估（补真测试或迁移计数）；文内 Single 字面量陷阱已修（M4.2）|
| FPC Single-重载字面量陷阱 | `uses nextpas.core.math` 后，裸实数/整数字面量（`Exp(1.0)`、`Ln(2)`）绑定 Single 重载（2⁻²⁵ 舍入）；f9bc1d94e 由此弄坏 batch_math；生产侧 `SIMD_PI: Single` 曾毒化 F64 atan2/Jacobi（M4.2 以 `SIMD_PI_F64` 修复） | **规则：Double 语境的字面量实参必须 `Double(…)` 显式定型或用 Double 变量**；紧容差断言的期望值表达式尤其要查；`Power` 等值精确用例（0.25/±Inf/±0）侥幸常绿属脆弱面 |

## 公开 façade 边界提醒

维护时不要把以下面误当稳定 ABI：

- `VecF32x4Gather` / `VecI32x4Gather` 及 scatter 家族可经 public facade 调用，但目前 not part of the current stable public ABI wrapper（public ABI wrapper 只覆盖已冻结的核心原语面）；语义契约见 `docs/simd/api.md`。
- `TF16` / `THalf`（含 `AVX512BF16`、`NEON FP16` 候选路径）仍在 future ABI boundary 之外，只规划显式转换 API。
- 矩阵转置是两条独立 owner 路径：`TSimdF32Matrix.Transpose` / `TSimdF64Matrix.Transpose` 与 SIMD lane transpose 原语；不存在统一 Transpose 稳定面。
