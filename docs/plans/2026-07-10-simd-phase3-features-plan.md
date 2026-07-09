# Phase 3: 功能扩展（更多数据类型）实现计划

**分支**: simd-phase3-features  
**目标**: 扩展 SIMD 支持的数据类型，覆盖更多应用场景

---

## 任务清单

### 3.1 整数类型扩展

#### 3.1.1 I8/U8 批量操作
- [ ] ArrayAddI8: 字节数组加法
- [ ] ArraySubI8: 字节数组减法
- [ ] ArrayMulI8: 字节数组乘法
- [ ] ArrayAndI8: 字节数组按位与
- [ ] ArrayOrI8: 字节数组按位或
- [ ] ArrayXorI8: 字节数组按位异或
- [ ] ArrayAddU8: 无符号字节数组加法
- [ ] ArraySubU8: 无符号字节数组减法
- [ ] ArrayMulU8: 无符号字节数组乘法
- [ ] ArrayAndU8: 无符号字节数组按位与
- [ ] ArrayOrU8: 无符号字节数组按位或
- [ ] ArrayXorU8: 无符号字节数组按位异或

#### 3.1.2 I16/U16 批量操作
- [ ] ArrayAddI16: 短整数数组加法
- [ ] ArraySubI16: 短整数数组减法
- [ ] ArrayMulI16: 短整数数组乘法
- [ ] ArrayAndI16: 短整数数组按位与
- [ ] ArrayOrI16: 短整数数组按位或
- [ ] ArrayXorI16: 短整数数组按位异或
- [ ] ArrayAddU16: 无符号短整数数组加法
- [ ] ArraySubU16: 无符号短整数数组减法
- [ ] ArrayMulU16: 无符号短整数数组乘法
- [ ] ArrayAndU16: 无符号短整数数组按位与
- [ ] ArrayOrU16: 无符号短整数数组按位或
- [ ] ArrayXorU16: 无符号短整数数组按位异或

#### 3.1.3 I64/U64 批量操作
- [ ] ArrayAddI64: 长整数数组加法
- [ ] ArraySubI64: 长整数数组减法
- [ ] ArrayMulI64: 长整数数组乘法
- [ ] ArrayAndI64: 长整数数组按位与
- [ ] ArrayOrI64: 长整数数组按位或
- [ ] ArrayXorI64: 长整数数组按位异或
- [ ] ArrayAddU64: 无符号长整数数组加法
- [ ] ArraySubU64: 无符号长整数数组减法
- [ ] ArrayMulU64: 无符号长整数数组乘法
- [ ] ArrayAndU64: 无符号长整数数组按位与
- [ ] ArrayOrU64: 无符号长整数数组按位或
- [ ] ArrayXorU64: 无符号长整数数组按位异或

### 3.2 浮点类型扩展

#### 3.2.1 F64 批量操作优化
- [ ] 检查现有 F64 批量操作性能
- [ ] 优化 F64 批量操作的循环展开
- [ ] 添加 F64 批量操作的预取优化

#### 3.2.2 复数类型支持
- [ ] 定义 Complex32/Complex64 类型
- [ ] 实现复数加法/减法/乘法
- [ ] 实现复数模长/幅角计算

### 3.3 特殊类型扩展

#### 3.3.1 布尔位图操作
- [ ] 定义位图类型
- [ ] 实现位图 And/Or/Xor 操作
- [ ] 实现位图 Population Count

#### 3.3.2 定点数支持
- [ ] 定义 Q16/Q32 类型
- [ ] 实现定点数加法/减法/乘法
- [ ] 实现定点数转换函数

---

## 实现顺序

1. **第一步**: 添加 I8/U8 批量操作到 dispatch table
2. **第二步**: 实现 SSE2 的 I8/U8 批量操作
3. **第三步**: 实现 AVX2 的 I8/U8 批量操作
4. **第四步**: 实现 AVX-512 的 I8/U8 批量操作
5. **第五步**: 添加 I16/U16 批量操作
6. **第六步**: 添加 I64/U64 批量操作
7. **第七步**: 测试验证

---

## 技术细节

### I8/U8 批量操作实现

```pascal
// SSE2 实现示例
procedure SSE2ArrayAddI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
var pS1, pS2, pD: PInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    // 64 bytes per iteration (4x xmm registers)
    movdqu xmm0, [rax]; paddb xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddb xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; paddb xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; paddb xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; paddb xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddb xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; paddb xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; add r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;
```

### 性能目标

| 操作 | 平台 | 目标吞吐量 |
|------|------|------------|
| ArrayAddI8 | SSE2 | 16+ GB/s |
| ArrayAddI8 | AVX2 | 32+ GB/s |
| ArrayAddI8 | AVX-512 | 64+ GB/s |
| ArrayAddI16 | SSE2 | 8+ GB/s |
| ArrayAddI16 | AVX2 | 16+ GB/s |
| ArrayAddI16 | AVX-512 | 32+ GB/s |

---

## 验证标准

- [ ] I8/U8 批量操作实现并通过测试
- [ ] I16/U16 批量操作实现并通过测试
- [ ] I64/U64 批量操作实现并通过测试
- [ ] F64 批量操作优化完成
- [ ] 所有新操作性能达标
- [ ] 所有现有测试通过

---

**创建时间**: 2026-07-10  
**维护者**: dtamade
