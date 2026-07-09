# SIMD 优化实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修复 SSE4.1 兼容性问题，向量化 Sign/Step/Smoothstep，优化 Tan 堆分配

**Architecture:** 分层注册架构 - SSE2 注册标量/SSE2 实现，SSE4.1 覆盖为 roundps 版本，AVX2 继承并覆盖为 256-bit 版本

**Tech Stack:** FPC inline assembly (SSE2/SSE4.1/AVX2), threadvar TLS, dispatch table 分层覆盖

---

## Phase 1: SSE4.1 兼容性修复 (正确性)

### Task 1.1: 添加 SSE4.1 条件检测到 SSE2 注册

**Files:**
- Modify: `core/src/nextpas.core.simd.sse2.register.inc:688-693`

**Step 1: 读取当前注册代码**

```bash
head -n 720 core/src/nextpas.core.simd.sse2.register.inc | tail -n 40
```

**Step 2: 修改注册逻辑为条件判断**

将:
```pascal
  // Rounding
  dispatchTable.ArrayCeilF32 := @SSE2ArrayCeilF32;
  dispatchTable.ArrayFloorF32 := @SSE2ArrayFloorF32;
  dispatchTable.ArrayRoundF32 := @SSE2ArrayRoundF32;
  dispatchTable.ArrayTruncF32 := @SSE2ArrayTruncF32;
  dispatchTable.ArrayFractF32 := @SSE2ArrayFractF32;
```

改为:
```pascal
  // Rounding - SSE4.1 roundps 指令，纯 SSE2 CPU 使用标量回退
  if HasSSE41 then
  begin
    dispatchTable.ArrayCeilF32 := @SSE2ArrayCeilF32;
    dispatchTable.ArrayFloorF32 := @SSE2ArrayFloorF32;
    dispatchTable.ArrayRoundF32 := @SSE2ArrayRoundF32;
    dispatchTable.ArrayTruncF32 := @SSE2ArrayTruncF32;
    dispatchTable.ArrayFractF32 := @SSE2ArrayFractF32;
  end
  else
  begin
    dispatchTable.ArrayCeilF32 := @ScalarArrayCeilF32;
    dispatchTable.ArrayFloorF32 := @ScalarArrayFloorF32;
    dispatchTable.ArrayRoundF32 := @ScalarArrayRoundF32;
    dispatchTable.ArrayTruncF32 := @ScalarArrayTruncF32;
    dispatchTable.ArrayFractF32 := @ScalarArrayFractF32;
  end;
```

**Step 3: 验证编译**

```bash
make -C core/tests/nextpas.core.simd clean test
```

Expected: 全部通过

**Step 4: Commit**

```bash
git add core/src/nextpas.core.simd.sse2.register.inc
git commit -m "fix(simd): SSE4.1 条件检测，纯 SSE2 CPU 回退标量实现

- Ceil/Floor/Round/Trunc/Fract 使用 roundps 需要 SSE4.1
- 纯 SSE2 CPU 自动使用标量实现，避免 #UD 崩溃
- 使用现有 HasSSE41 检测函数"
```

---

## Phase 2: Sign SIMD 向量化

### Task 2.1: 实现 SSE2ArraySignF32

**Files:**
- Modify: `core/src/nextpas.core.simd.sse2.batch.inc:4839-4842`

**Step 1: 读取当前实现**

```bash
sed -n '4835,4860p' core/src/nextpas.core.simd.sse2.batch.inc
```

**Step 2: 替换为 SSE2 SIMD 实现**

将:
```pascal
procedure SSE2ArraySignF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  // Delegate to scalar implementation
  ScalarArraySignF32(aSrc, aDst, aCount);
end;
```

改为:
```pascal
procedure SSE2ArraySignF32(aSrc, aDst: PSingle; aCount: SizeUInt);
const
  ONE: Single = 1.0;
  MINUS_ONE: Single = -1.0;
var
  pS, pD: PSingle;
  LOne, LMinusOne: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;
  LOne := ONE;
  LMinusOne := MINUS_ONE;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm2, [LOne]       // 1.0
    shufps xmm2, xmm2, 0    // broadcast to all lanes
    movss xmm3, [LMinusOne]  // -1.0
    shufps xmm3, xmm3, 0    // broadcast to all lanes

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]       // load src
    xorps xmm1, xmm1         // 0.0
    cmpps xmm4, xmm0, xmm1, 6  // src > 0 (GT)
    cmpps xmm5, xmm1, xmm0, 6  // 0 > src => src < 0 (LT, swapped operands)
    andps xmm4, xmm2          // 1.0 where src > 0
    andps xmm5, xmm3          // -1.0 where src < 0
    orps xmm4, xmm5           // combine
    movups [rcx], xmm4
    add rax, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done

  @scalar_loop:
    movss xmm0, [rax]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja @positive
    jb @negative
    // zero case
    movss [rcx], xmm1
    jmp @next
  @positive:
    movss [rcx], xmm2
    jmp @next
  @negative:
    movss [rcx], xmm3
  @next:
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;
```

**Step 3: 运行测试验证**

```bash
make -C core/tests/nextpas.core.simd clean test
```

Expected: 全部通过

**Step 4: Commit**

```bash
git add core/src/nextpas.core.simd.sse2.batch.inc
git commit -m "perf(simd): Sign SSE2 向量化，消除分支

- 使用 cmpps + andps + orps 实现无分支 sign
- SIMD 路径处理 4 个 float，标量处理尾部
- 预期 3-5x 加速"
```

---

## Phase 3: Step SIMD 向量化

### Task 3.1: 实现 SSE2ArrayStepF32

**Files:**
- Modify: `core/src/nextpas.core.simd.sse2.batch.inc:4845-4848`

**Step 1: 读取当前实现**

```bash
sed -n '4845,4860p' core/src/nextpas.core.simd.sse2.batch.inc
```

**Step 2: 替换为 SSE2 SIMD 实现**

将:
```pascal
procedure SSE2ArrayStepF32(aEdge, aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  // Delegate to scalar implementation
  ScalarArrayStepF32(aEdge, aSrc, aDst, aCount);
end;
```

改为:
```pascal
procedure SSE2ArrayStepF32(aEdge, aSrc, aDst: PSingle; aCount: SizeUInt);
const
  ONE: Single = 1.0;
var
  pE, pS, pD: PSingle;
  LOne: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pE := aEdge;
  pS := aSrc;
  pD := aDst;
  LOne := ONE;

  asm
    mov rax, pS       // src
    mov rdx, pE       // edge
    mov rcx, pD       // dst
    mov r8, aCount
    movss xmm2, [LOne]  // 1.0
    shufps xmm2, xmm2, 0

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rdx]       // edge
    movups xmm1, [rax]       // src
    cmpps xmm0, xmm1, 2     // edge <= src (NLT = NOT LESS THAN)
    andps xmm0, xmm2         // 1.0 where edge <= src, 0.0 otherwise
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done

  @scalar_loop:
    movss xmm0, [rdx]   // edge
    movss xmm1, [rax]   // src
    cmpps xmm0, xmm1, 2 // edge <= src
    andps xmm0, xmm2
    movss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;
```

**Step 3: 运行测试验证**

```bash
make -C core/tests/nextpas.core.simd clean test
```

Expected: 全部通过

**Step 4: Commit**

```bash
git add core/src/nextpas.core.simd.sse2.batch.inc
git commit -m "perf(simd): Step SSE2 向量化，消除分支

- 使用 cmpps NLT + andps 实现无分支 step
- step(edge, x) = x >= edge ? 1.0 : 0.0
- 预期 3-5x 加速"
```

---

## Phase 4: Smoothstep SIMD 向量化

### Task 4.1: 实现 SSE2ArraySmoothstepF32

**Files:**
- Modify: `core/src/nextpas.core.simd.sse2.batch.inc:4851-4854`

**Step 1: 读取当前实现**

```bash
sed -n '4851,4870p' core/src/nextpas.core.simd.sse2.batch.inc
```

**Step 2: 替换为 SSE2 SIMD 实现**

将:
```pascal
procedure SSE2ArraySmoothstepF32(aEdge0, aEdge1, aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  // Delegate to scalar implementation
  ScalarArraySmoothstepF32(aEdge0, aEdge1, aSrc, aDst, aCount);
end;
```

改为:
```pascal
procedure SSE2ArraySmoothstepF32(aEdge0, aEdge1, aSrc, aDst: PSingle; aCount: SizeUInt);
const
  THREE: Single = 3.0;
  TWO: Single = 2.0;
  ZERO: Single = 0.0;
  ONE_VAL: Single = 1.0;
var
  pE0, pE1, pS, pD: PSingle;
  LThree, LTwo, LZero, LOne: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pE0 := aEdge0;
  pE1 := aEdge1;
  pS := aSrc;
  pD := aDst;
  LThree := THREE;
  LTwo := TWO;
  LZero := ZERO;
  LOne := ONE_VAL;

  asm
    mov r9, pE0       // edge0
    mov r10, pE1      // edge1
    mov rax, pS       // src
    mov rcx, pD       // dst
    mov r8, aCount
    movss xmm4, [LThree]
    shufps xmm4, xmm4, 0   // 3.0 broadcast
    movss xmm5, [LTwo]
    shufps xmm5, xmm5, 0   // 2.0 broadcast
    movss xmm6, [LZero]
    shufps xmm6, xmm6, 0   // 0.0 broadcast
    movss xmm7, [LOne]
    shufps xmm7, xmm7, 0   // 1.0 broadcast

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    // v = (src - edge0) / (edge1 - edge0)
    movups xmm0, [rax]       // src
    movups xmm1, [r9]        // edge0
    movups xmm2, [r10]       // edge1
    subps xmm0, xmm1         // src - edge0
    subps xmm2, xmm1         // edge1 - edge0
    divps xmm0, xmm2         // (src - edge0) / (edge1 - edge0)

    // clamp v to [0, 1]
    maxps xmm0, xmm6         // v = max(v, 0)
    minps xmm0, xmm7         // v = min(v, 1)

    // t = v * v
    movaps xmm1, xmm0
    mulps xmm1, xmm1         // t = v*v

    // result = t * (3 - 2*v)
    movaps xmm2, xmm4        // 3.0
    movaps xmm3, xmm5        // 2.0
    mulps xmm3, xmm0         // 2*v
    subps xmm2, xmm3         // 3 - 2*v
    mulps xmm1, xmm2         // t * (3 - 2*v)

    movups [rcx], xmm1
    add r9, 16
    add r10, 16
    add rax, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done

  @scalar_loop:
    // v = (src - edge0) / (edge1 - edge0)
    movss xmm0, [rax]
    movss xmm1, [r9]
    movss xmm2, [r10]
    subss xmm0, xmm1
    subss xmm2, xmm1
    divss xmm0, xmm2

    // clamp
    maxps xmm0, xmm6
    minps xmm0, xmm7

    // t = v*v
    movaps xmm1, xmm0
    mulss xmm1, xmm1

    // result = t * (3 - 2*v)
    movaps xmm2, xmm4
    movaps xmm3, xmm5
    mulss xmm3, xmm0
    subss xmm2, xmm3
    mulss xmm1, xmm2

    movss [rcx], xmm1
    add r9, 4
    add r10, 4
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;
```

**Step 3: 运行测试验证**

```bash
make -C core/tests/nextpas.core.simd clean test
```

Expected: 全部通过

**Step 4: Commit**

```bash
git add core/src/nextpas.core.simd.sse2.batch.inc
git commit -m "perf(simd): Smoothstep SSE2 向量化，纯算术流水线

- Hermite 插值: t*t*(3-2*v) 全部 SIMD 实现
- 使用 maxps/minps 实现 clamp，无分支
- 预期 2-4x 加速"
```

---

## Phase 5: Tan 堆分配优化

### Task 5.1: 添加 threadvar 缓冲区

**Files:**
- Modify: `core/src/nextpas.core.simd.sse2.batch.inc:4280-4338`
- Modify: `core/src/nextpas.core.simd.avx2.batch.inc:5368-5438`

**Step 1: 在 SSE2 batch 文件顶部添加 threadvar**

在 `core/src/nextpas.core.simd.sse2.batch.inc` 文件开头 (procedure 声明之前) 添加:

```pascal
// Thread-local scratch buffers for Tan computation
// 避免每次调用 SetLength 分配堆内存
threadvar
  GTanSinBuf: array of Single;
  GTanCosBuf: array of Single;
  GTanBufCapacity: SizeUInt;

procedure EnsureTanScratch(aCount: SizeUInt);
begin
  if GTanBufCapacity < aCount then
  begin
    GTanBufCapacity := aCount;
    SetLength(GTanSinBuf, aCount);
    SetLength(GTanCosBuf, aCount);
  end;
end;
```

**Step 2: 修改 SSE2ArrayTanF32 使用 threadvar**

将:
```pascal
procedure SSE2ArrayTanF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pSin, pCos, pD: PSingle;
  LSinBuf, LCosBuf: array of Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;

  // Allocate temporary buffers for sin and cos
  SetLength(LSinBuf, aCount);
  SetLength(LCosBuf, aCount);

  // Compute sin and cos using SIMD
  SSE2ArraySinF32(aSrc, @LSinBuf[0], aCount);
  SSE2ArrayCosF32(aSrc, @LCosBuf[0], aCount);
```

改为:
```pascal
procedure SSE2ArrayTanF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pSin, pCos, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;

  // 使用 threadvar 缓冲区，避免每次堆分配
  EnsureTanScratch(aCount);

  // Compute sin and cos using SIMD
  SSE2ArraySinF32(aSrc, @GTanSinBuf[0], aCount);
  SSE2ArrayCosF32(aSrc, @GTanCosBuf[0], aCount);
```

**Step 3: 同样修改 AVX2ArrayTanF32**

在 `core/src/nextpas.core.simd.avx2.batch.inc` 文件开头添加相同的 threadvar 和 EnsureTanScratch。

修改 AVX2ArrayTanF32 使用 threadvar 缓冲区。

**Step 4: 运行测试验证**

```bash
make -C core/tests/nextpas.core.simd clean test
```

Expected: 全部通过

**Step 5: Commit**

```bash
git add core/src/nextpas.core.simd.sse2.batch.inc core/src/nextpas.core.simd.avx2.batch.inc
git commit -m "perf(simd): Tan 使用 threadvar 缓冲区，消除堆分配

- threadvar 线程局部存储，自动线程安全
- 缓冲区只增不减，峰值水位策略
- 热路径后零分配开销"
```

---

## Phase 6: 基准测试验证

### Task 6.1: 运行完整基准测试

**Step 1: 运行基准测试**

```bash
core/tests/nextpas.core.math/bench_batch_simd/bench_batch_simd
```

**Step 2: 验证性能提升**

Expected:
- Sign: 3-5x 加速 (新增 SIMD)
- Step: 3-5x 加速 (新增 SIMD)
- Smoothstep: 2-4x 加速 (新增 SIMD)
- Ceil/Floor/Round/Trunc: 保持原有加速

**Step 3: Commit**

```bash
git add -A
git commit -m "test(simd): 基准测试验证优化效果"
```

---

## 验证清单

- [ ] 纯 SSE2 模拟环境不崩溃 (Phase 1)
- [ ] Sign SIMD 正确性测试通过
- [ ] Step SIMD 正确性测试通过
- [ ] Smoothstep SIMD 正确性测试通过
- [ ] Tan 缓冲区复用正常
- [ ] 基准测试显示预期加速
- [ ] 所有 1730+ 测试通过
- [ ] 代码风格一致
