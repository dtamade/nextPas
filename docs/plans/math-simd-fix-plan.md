# Math/SIMD 模块全面整改计划

## 状态: ✅ 全部完成 (2026-07-06)

## 问题清单 (Codex 审查发现)

### Critical (5项)
| # | 问题 | 文件 | 行 |
|---|------|------|-----|
| C1 | SSE2 ArrayExpF32 覆盖已计算的指数 n | sse2.batch.inc | 3913 |
| C2 | ArrayLogF32 未分类负数/零/NaN/Inf | sse2.batch.inc:4021, avx2.batch.inc:4003 |
| C3 | SSE2 ArrayModF32 使用 SSE4.1 roundps 但无 HasSSE41 门控 | sse2.batch.inc:5553, sse2.register.inc:720 |
| C4 | BatchHypotSimdF32 使用 sqrt(x*x+y*y) 溢出 | sse2.batch.inc:5446 |
| C5 | BatchNormalize 绕过稳定归一化 (大值溢出) | vec.batch.simd.pas:208 |

### Important (4项)
| # | 问题 | 文件 | 行 |
|---|------|------|-----|
| I1 | BatchClampF32 不继承 scalar 边界契约 | batch.pas:284 |
| I2 | 新增批量函数未进入公共门面 | batch.pas (缺失) |
| I3 | AVX2 Exp 在分类前钳位 (丢失 NaN/Inf 语义) | avx2.batch.inc:3621 |
| I4 | 测试拓扑漏检 (4个测试项目未加入聚合 Makefile) | Makefile:3 |

---

## 修复方案

### C1: SSE2 ArrayExpF32 指数覆盖 Bug

**根因**: 第 3913 行 `cvtps2dq xmm1, [rax]` 从内存重新加载原始输入到 xmm1，覆盖了已计算的整数 n。

**代码追踪**:
- 3880: `cvtps2dq xmm1, xmm1` → xmm1 = round(x * log2e) 作为 int32 (n)
- 3881: `cvtdq2ps xmm2, xmm1` → xmm2 = n 作为 float
- 3883-3889: 计算 r = x - n*ln2，结果在 xmm0
- 3892-3910: Horner 多项式，结果在 xmm2
- 3913: `cvtps2dq xmm1, [rax]` → **BUG**: 重新加载原始输入覆盖了 xmm1 中的 n！

**修复**: 删除第 3913 行及注释行 3914-3916。保留 3917-3918 行，它们正确使用 xmm1 中的 int32 n。

```asm
    // 删除这4行:
    // cvtps2dq xmm1, [rax]     // reload... no, we have n in xmm1 already (int)
    // Actually xmm1 still has n as int from cvtps2dq above
    // Wait, we did cvtps2dq xmm1, xmm1 then cvtdq2ps xmm2, xmm1
    // So xmm1 still has n as int32!
    
    // 保留:
    pslld xmm1, 23
    paddd xmm2, xmm1
```

**验证**: 4元素测试 `Exp([0, 1, 2, 3])` 应返回 `[1, 2.718, 7.389, 20.086]`

---

### C2: ArrayLogF32 特殊值分类

**根因**: SSE2/AVX2 的 Log SIMD 路径直接从 IEEE 754 位提取指数和尾数，不检查：
- 负数输入 → 应返回 NaN
- 零输入 → 应返回 -Inf
- NaN → 应传递
- +Inf → 应返回 +Inf

**修复方案**: 在 SIMD 循环开始处添加分类。对特殊值预处理后，对正常值执行原始算法，最后 blend 结果。

对于每个元素：
1. 提取符号位和特殊值掩码
2. 对正常值 (>0, 非 Inf/NaN) 执行原有算法
3. 对特殊值：负数→NaN, 零→-Inf, NaN→NaN, +Inf→+Inf
4. blend 最终结果

**SSE2 实现** (在 `@loop4` 标签后):
```asm
    movups xmm0, [rax]
    
    // 分类: 检查特殊值
    // xmm5 = 输入副本用于分类
    movaps xmm5, xmm0
    
    // 检查 NaN: (bits & 0x7FFFFFFF) > 0x7F800000
    movaps xmm6, xmm5
    // 需要 NaN/Inf/零/负数的掩码...
    
    // 正常路径: 用原始算法计算
    // ...
    
    // Blend: 特殊值结果 vs 正常结果
```

**复杂度**: 这是最复杂的修复，需要在 SIMD 循环中添加分类逻辑。

**简化方案**: 对特殊值使用标量回退（`@tail_scalar` 已有正确实现），在 SIMD 循环前预分类。

---

### C3: SSE2 ArrayModF32/ArrayFractF32 SSE4.1 门控

**根因**: 
- `SSE2ArrayFractF32` (line 5500) 使用 `roundps xmm1, xmm0, 3` (SSE4.1)
- `SSE2ArrayModF32` (line 5553) 使用 `roundps xmm2, xmm2, 3` (SSE4.1)
- 但 `sse2.register.inc` line 720 无条件注册 `ArrayModF32`

**修复**: 在 `sse2.register.inc` 中，将 `ArrayModF32` 的注册移到 `HasSSE41` 检查内。

**sse2.register.inc 修改**:
```pascal
  // 当前 (line 719-720):
  // Utility
  dispatchTable.ArrayModF32 := @SSE2ArrayModF32;

  // 修改为:
  // Utility
  if HasSSE41 then
    dispatchTable.ArrayModF32 := @SSE2ArrayModF32
  else
    dispatchTable.ArrayModF32 := @ScalarArrayModF32;
```

同时需要提供 `ScalarArrayModF32` 标量回退实现。

---

### C4: BatchHypotSimdF32 溢出修复

**根因**: `sqrt(x*x + y*y)` 当 x 或 y 很大时 (如 3e20)，x*x 溢出 float32 范围。

**修复方案**: 使用稳定 hypot 算法:
```
ax = abs(x), ay = abs(y)
if ax < ay: swap(ax, ay)
if ax == 0: return 0
r = ay / ax
return ax * sqrt(1 + r*r)
```

**SSE2 实现**:
```asm
  @loop4:
    movups xmm0, [rax]     // x
    movups xmm1, [rdx]     // y
    
    // abs
    pcmpeqd xmm4, xmm4
    psrld xmm4, 1           // 0x7FFFFFFF mask
    andps xmm0, xmm4        // |x|
    andps xmm1, xmm4        // |y|
    
    // max = max(|x|, |y|), min = min(|x|, |y|)
    movaps xmm2, xmm0       // |x|
    movaps xmm3, xmm1       // |y|
    maxps xmm2, xmm1        // max
    minps xmm3, xmm0        // min
    
    // r = min / max (where max > 0)
    divps xmm3, xmm2        // r = min/max
    
    // result = max * sqrt(1 + r*r)
    mulps xmm3, xmm3        // r*r
    movss xmm4, [LOne]
    shufps xmm4, xmm4, 0
    addps xmm3, xmm4        // 1 + r*r
    sqrtps xmm3, xmm3       // sqrt(1 + r*r)
    mulps xmm2, xmm3        // max * sqrt(1 + r*r)
    
    movups [rcx], xmm2
```

---

### C5: BatchNormalize 溢出修复

**根因**: `VecF32x3Normalize` 调用 `LengthF32x3` 计算 `sqrt(x*x + y*y + z*z)`，大值溢出。

**修复方案**: 在 `VecF32x3Normalize`/`VecF32x4Normalize` 中使用稳定归一化:
```
max = max(abs(x), abs(y), abs(z))
if max == 0: return zero vector
scaled = vec / max
len = sqrt(scaled.x² + scaled.y² + scaled.z²)
return scaled / len
```

这需要修改 SSE2/AVX2 的 `NormalizeF32x3`/`NormalizeF32x4` 函数。

---

### I1: BatchClampF32 边界契约

**修复**: 在 `BatchClampF32` 入口添加 `RequireClampBounds` 检查。

```pascal
function BatchClampF32(...): SizeInt;
begin
  RequireClampBounds(AMin, AMax);  // 新增
  Result := BatchClampSimdF32(AInput, AMin, AMax, AOutput);
end;
```

---

### I2: 公共 API 补全

**修复**: 在 `nextpas.core.math.batch.pas` 接口部分添加:

```pascal
function BatchAtan2F32(const AY, AX: array of Single;
                       var AOutput: array of Single): SizeInt;

function BatchHypotF32(const AX, AY: array of Single;
                       var AOutput: array of Single): SizeInt;

function BatchFractF32(const AInput: array of Single;
                       var AOutput: array of Single): SizeInt;

function BatchModF32(const AInput: array of Single;
                     const ADivisor: Single;
                     var AOutput: array of Single): SizeInt;

function BatchSignF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;

function BatchStepF32(const AEdge, AInput: array of Single;
                      var AOutput: array of Single): SizeInt;

function BatchSmoothstepF32(const AEdge0, AEdge1, AInput: array of Single;
                            var AOutput: array of Single): SizeInt;
```

并添加对应的 implementation 委托。

---

### I3: AVX2 Exp 分类前钳位修复

**根因**: avx2.batch.inc 3621-3623 在分类前钳位:
```asm
vminps ymm0, ymm0, ymm5    // clamp to max → NaN 被转为 max!
vmaxps ymm0, ymm0, ymm4    // clamp to min → -Inf 被转为 min!
```

**修复**: 先分类特殊值，再钳位正常值，最后 blend。

---

### I4: 测试拓扑补全

**修复**: 在 `core/tests/nextpas.core.math/Makefile` 的 PROJECTS 中添加:
```
test_batch_scalar test_batch_simd test_vec_compat
```

---

## 测试策略

### 新增测试用例 (在 test_batch_simd 中)

1. **Exp 4元素测试**: `Exp([0, 1, 2, 3])` → `[1, 2.718, 7.389, 20.086]`
2. **Log 特殊值**: `Log([-1, 0, 1, Inf])` → `[NaN, -Inf, 0, Inf]`
3. **Hypot 大值**: `Hypot([3e20], [4e20])` → `[5e20]`
4. **Clamp 逆边界**: `Clamp([1], [5], [0])` → EArgumentError

### 验证步骤

```bash
# 1. 单元测试
make -C core/tests/nextpas.core.math/test_batch_simd clean test

# 2. 聚合测试
make -C core/tests/nextpas.core.math clean test

# 3. SIMD focused gate
make focused FOCUS=core/tests/nextpas.core.math/test_batch_simd

# 4. 完整 SIMD gate
make focused FOCUS=tests/simd

# 5. Hygiene
make hygiene
git diff --check
```

---

## 执行顺序

1. **Phase 1 (Critical C1, C3)**: 简单修复，不涉及算法重写
   - C1: 删除 1 行代码
   - C3: 移动注册到 HasSSE41 检查内 + 添加标量回退

2. **Phase 2 (Critical C4, C5)**: 算法重写
   - C4: 重写 SSE2/AVX2 Hypot 为稳定算法
   - C5: 重写 Normalize 为稳定算法

3. **Phase 3 (Critical C2, I3)**: 特殊值处理
   - C2: ArrayLogF32 特殊值分类
   - I3: AVX2 Exp 分类前处理

4. **Phase 4 (Important I1, I2, I4)**: API 和契约
   - I1: BatchClamp 边界检查
   - I2: 公共 API 补全
   - I4: Makefile 补全

5. **Phase 5**: 测试覆盖
   - 新增测试用例
   - 全量验证
