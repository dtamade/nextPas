// === AVX2 Memory Functions (256-bit) ===

function MemEqual_AVX2(a, b: Pointer; len: SizeUInt): LongBool; assembler; nostackframe;
// RDI = a, RSI = b, RDX = len
asm
  xor eax, eax           // Default result = false
  test rdx, rdx
  jz @equal              // Empty = equal
  test rdi, rdi
  jz @check_both_nil
  test rsi, rsi
  jz @done
  cmp rdi, rsi
  je @equal              // Same pointer = equal

  xor rcx, rcx           // i = 0

@loop32:
  lea r8, [rcx + 32]
  cmp r8, rdx
  ja @loop16
  vmovdqu ymm0, [rdi + rcx]
  vpcmpeqb ymm0, ymm0, [rsi + rcx]
  vpmovmskb eax, ymm0
  cmp eax, $FFFFFFFF
  jne @not_equal_cleanup
  add rcx, 32
  jmp @loop32

@loop16:
  lea r8, [rcx + 16]
  cmp r8, rdx
  ja @remainder
  vmovdqu xmm0, [rdi + rcx]
  vpcmpeqb xmm0, xmm0, [rsi + rcx]
  vpmovmskb eax, xmm0
  cmp eax, $FFFF
  jne @not_equal_cleanup
  add rcx, 16
  jmp @loop16

@remainder:
  cmp rcx, rdx
  jae @equal_cleanup
  movzx r8d, byte ptr [rdi + rcx]
  movzx r9d, byte ptr [rsi + rcx]
  cmp r8d, r9d
  jne @not_equal_cleanup
  inc rcx
  jmp @remainder

@check_both_nil:
  test rsi, rsi
  jz @equal
  jmp @done

@not_equal_cleanup:
  vzeroupper
  xor eax, eax
  ret

@equal_cleanup:
  vzeroupper
@equal:
  mov eax, 1
@done:
end;

function MemFindByte_AVX2(p: Pointer; len: SizeUInt; value: Byte): PtrInt; assembler; nostackframe;
// RDI = p, RSI = len, RDX = value
asm
  mov rax, -1            // Default result = -1 (not found)
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done

  // Broadcast value to all 32 bytes in ymm1
  vmovd xmm1, edx
  vpbroadcastb ymm1, xmm1

  xor rcx, rcx           // i = 0

@loop32:
  lea r8, [rcx + 32]
  cmp r8, rsi
  ja @loop16
  vmovdqu ymm0, [rdi + rcx]
  vpcmpeqb ymm0, ymm0, ymm1
  vpmovmskb r8d, ymm0
  test r8d, r8d
  jnz @found32
  add rcx, 32
  jmp @loop32

@found32:
  bsf r8d, r8d
  lea rax, [rcx + r8]
  vzeroupper
  ret

@loop16:
  lea r8, [rcx + 16]
  cmp r8, rsi
  ja @remainder
  vmovdqu xmm0, [rdi + rcx]
  vpcmpeqb xmm0, xmm0, xmm1
  vpmovmskb r8d, xmm0
  test r8d, r8d
  jnz @found16
  add rcx, 16
  jmp @loop16

@found16:
  bsf r8d, r8d
  lea rax, [rcx + r8]
  vzeroupper
  ret

@remainder:
  cmp rcx, rsi
  jae @cleanup
  movzx r8d, byte ptr [rdi + rcx]
  cmp r8d, edx
  je @found_remainder
  inc rcx
  jmp @remainder

@found_remainder:
  mov rax, rcx
  vzeroupper
  ret

@cleanup:
  vzeroupper
  mov rax, -1
@done:
end;

function SumBytes_AVX2(p: Pointer; len: SizeUInt): UInt64; assembler; nostackframe;
// RDI = p, RSI = len
// Use vpsadbw for fast byte summation
asm
  xor rax, rax           // sum = 0
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done

  vpxor ymm2, ymm2, ymm2 // accumulator
  vpxor ymm3, ymm3, ymm3 // zero for psadbw
  xor rcx, rcx           // i = 0

@loop32:
  lea r8, [rcx + 32]
  cmp r8, rsi
  ja @loop16
  vmovdqu ymm0, [rdi + rcx]
  vpsadbw ymm0, ymm0, ymm3
  vpaddq ymm2, ymm2, ymm0
  add rcx, 32
  jmp @loop32

@loop16:
  // Before 128-bit loop, reduce 256-bit accumulator to avoid losing high bits
  vextracti128 xmm4, ymm2, 1    // xmm4 = high 128 bits of ymm2
  vpaddq xmm2, xmm2, xmm4        // xmm2 = sum of high and low (now only 128-bit)

@loop16_inner:
  lea r8, [rcx + 16]
  cmp r8, rsi
  ja @remainder
  vmovdqu xmm0, [rdi + rcx]
  vpsadbw xmm0, xmm0, xmm3
  vpaddq xmm2, xmm2, xmm0
  add rcx, 16
  jmp @loop16_inner

@remainder:
  // Sum the 128-bit accumulator (2 x 64-bit values in xmm2)
  vpshufd xmm1, xmm2, $4E      // swap high/low 64-bit
  vpaddq xmm0, xmm2, xmm1
  vmovq rax, xmm0
  vzeroupper

  // Handle remaining bytes
@remainder_loop:
  cmp rcx, rsi
  jae @done
  movzx r8d, byte ptr [rdi + rcx]
  add rax, r8
  inc rcx
  jmp @remainder_loop

@done:
end;

function CountByte_AVX2(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; assembler; nostackframe;
// RDI = p, RSI = len, RDX = value
// Use popcnt instruction (available on all AVX2 CPUs)
asm
  xor rax, rax           // count = 0
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done

  // Broadcast value to all 32 bytes in ymm1
  vmovd xmm1, edx
  vpbroadcastb ymm1, xmm1

  xor rcx, rcx           // i = 0

@loop32:
  lea r8, [rcx + 32]
  cmp r8, rsi
  ja @loop16
  vmovdqu ymm0, [rdi + rcx]
  vpcmpeqb ymm0, ymm0, ymm1
  vpmovmskb r8d, ymm0
  popcnt r8d, r8d
  add rax, r8
  add rcx, 32
  jmp @loop32

@loop16:
  lea r8, [rcx + 16]
  cmp r8, rsi
  ja @remainder
  vmovdqu xmm0, [rdi + rcx]
  vpcmpeqb xmm0, xmm0, xmm1
  vpmovmskb r8d, xmm0
  popcnt r8d, r8d
  add rax, r8
  add rcx, 16
  jmp @loop16

@remainder:
  vzeroupper
@remainder_loop:
  cmp rcx, rsi
  jae @done
  movzx r8d, byte ptr [rdi + rcx]
  cmp r8d, edx
  jne @skip
  inc rax
@skip:
  inc rcx
  jmp @remainder_loop

@done:
end;

// MinMaxBytes_AVX2 - 使用 AVX2 vpminub/vpmaxub 指令查找字节数组的最小和最大值
// 使用 256 位宽向量一次处理 32 字节
procedure MinMaxBytes_AVX2(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte); assembler; nostackframe;
asm
  // 参数: RDI = p, RSI = len, RDX = &minVal, RCX = &maxVal
  // 保存 minVal 和 maxVal 指针
  push rbx
  mov r8, rdx       // r8 = &minVal
  mov r9, rcx       // r9 = &maxVal
  
  // 边界检查
  test rsi, rsi
  jz @empty
  
  // 初始化 min = 255, max = 0
  mov al, 255
  mov bl, 0
  
  // 如果长度 < 32，跳到标量处理
  cmp rsi, 32
  jb @scalar_loop
  
  // 初始化 YMM 寄存器
  // ymm0 = min (全 255)
  // ymm1 = max (全 0)
  vpcmpeqb ymm0, ymm0, ymm0   // ymm0 = all 1s (255)
  vpxor ymm1, ymm1, ymm1       // ymm1 = all 0s
  
  // 计算向量循环次数
  mov rcx, rsi
  shr rcx, 5            // rcx = len / 32
  
  // 向量主循环
@vector_loop:
  vmovdqu ymm2, [rdi]   // 加载 32 字节
  vpminub ymm0, ymm0, ymm2    // min = min(min, data)
  vpmaxub ymm1, ymm1, ymm2    // max = max(max, data)
  add rdi, 32
  dec rcx
  jnz @vector_loop
  
  // 水平归约 256 位到标量
  // 提取高低 128 位并比较
  vextracti128 xmm2, ymm0, 1    // xmm2 = high 128 of ymm0
  vextracti128 xmm3, ymm1, 1    // xmm3 = high 128 of ymm1
  vpminub xmm0, xmm0, xmm2      // xmm0 = min of high and low
  vpmaxub xmm1, xmm1, xmm3      // xmm1 = max of high and low
  
  // 128 位归约到 64 位
  vpsrldq xmm2, xmm0, 8
  vpsrldq xmm3, xmm1, 8
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  // 64 位归约到 32 位
  vpsrldq xmm2, xmm0, 4
  vpsrldq xmm3, xmm1, 4
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  // 32 位归约到 16 位
  vpsrldq xmm2, xmm0, 2
  vpsrldq xmm3, xmm1, 2
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  // 16 位归约到 8 位
  vpsrldq xmm2, xmm0, 1
  vpsrldq xmm3, xmm1, 1
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  // 提取结果
  vpextrb eax, xmm0, 0          // al = min
  vpextrb ebx, xmm1, 0          // bl = max
  
  // 计算剩余字节
  and rsi, 31           // len % 32
  jz @store_result
  
  // 处理剩余字节
@scalar_loop:
  test rsi, rsi
  jz @store_result
  movzx ecx, byte ptr [rdi]
  cmp cl, al
  cmovb eax, ecx       // if (data < min) min = data
  cmp cl, bl
  cmova ebx, ecx       // if (data > max) max = data
  inc rdi
  dec rsi
  jnz @scalar_loop
  
@store_result:
  mov [r8], al         // *minVal = al
  mov [r9], bl         // *maxVal = bl
  vzeroupper
  pop rbx
  jmp @return
  
@empty:
  mov byte ptr [r8], 0
  mov byte ptr [r9], 0
  pop rbx
  
@return:
end;

// BitsetPopCount_AVX2 - 使用 POPCNT 指令计算位集中置 1 的位数
// 一次处理 8 字节（64位）使用硬件 POPCNT 指令
function BitsetPopCount_AVX2(p: Pointer; len: SizeUInt): SizeUInt; assembler; nostackframe;
asm
  // 参数: RDI = p, RSI = len
  // 返回: RAX = 置 1 的位数
  
  xor rax, rax          // result = 0
  
  // 边界检查
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done
  
  // 主循环：一次处理 8 字节
  mov rcx, rsi
  shr rcx, 3            // rcx = len / 8
  jz @remainder
  
@main_loop:
  popcnt rdx, qword ptr [rdi]
  add rax, rdx
  add rdi, 8
  dec rcx
  jnz @main_loop
  
@remainder:
  // 处理剩余字节 (0-7)
  and rsi, 7            // len % 8
  jz @done
  
@scalar_loop:
  movzx edx, byte ptr [rdi]
  popcnt edx, edx
  add rax, rdx
  inc rdi
  dec rsi
  jnz @scalar_loop
  
@done:
end;

// Utf8Validate_AVX2 - 完整 SIMD UTF-8 验证 (Lemire lookup4, 纯汇编)
// 32 字节/iter 处理所有 UTF-8 序列，不回退标量。
// 参考: simdjson utf8_lookup4_algorithm.h, Lemire arXiv:2010.03090
function Utf8Validate_AVX2(p: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;
// RDI = p, RSI = len. Returns AL (Boolean).
asm
  // === 边界检查 ===
  test rsi, rsi
  jz @valid
  test rdi, rdi
  jz @invalid

  // === 初始化状态寄存器 ===
  vpxor ymm13, ymm13, ymm13    // prev_block = 0
  vpxor ymm14, ymm14, ymm14    // prev_incomplete = 0
  vpxor ymm15, ymm15, ymm15    // error = 0

  // === 初始化常量寄存器 ===
  // ymm12 = mask 0x0F
  mov eax, $0F0F0F0F
  vmovd xmm12, eax
  vpbroadcastd ymm12, xmm12

  // ymm11 = LUT Byte1High: 02 02 02 02 02 02 02 02 80 80 80 80 21 01 15 49
  sub rsp, 16
  mov rax, $8080808002020202
  mov [rsp], rax
  mov rax, $4915012180808080
  mov [rsp+8], rax
  vmovdqu xmm11, [rsp]
  vinserti128 ymm11, ymm11, xmm11, 1
  add rsp, 16

  // ymm10 = LUT Byte1Low: E7 A3 83 83 8B CB CB CB CB CB CB CB CB DB CB CB
  sub rsp, 16
  mov rax, $CBCBCB8B838383E7
  mov [rsp], rax
  mov rax, $CBCBDBCBCBCBCBCB
  mov [rsp+8], rax
  vmovdqu xmm10, [rsp]
  vinserti128 ymm10, ymm10, xmm10, 1
  add rsp, 16

  // ymm9 = LUT Byte2High: 01 01 01 01 01 01 01 01 E6 AE BA BA 01 01 01 01
  sub rsp, 16
  mov rax, $0101010101010101
  mov [rsp], rax
  mov rax, $0101010101010101
  mov [rsp+8], rax
  mov byte [rsp+8], $E6
  mov byte [rsp+9], $AE
  mov byte [rsp+10], $BA
  mov byte [rsp+11], $BA
  vmovdqu xmm9, [rsp]
  vinserti128 ymm9, ymm9, xmm9, 1
  add rsp, 16

  // ymm8 = IncompleteMax: FF*29, EF, DF, BF
  vpcmpeqb ymm8, ymm8, ymm8    // all FF
  sub rsp, 32
  vmovdqu [rsp], ymm8
  mov byte [rsp+29], $EF
  mov byte [rsp+30], $DF
  mov byte [rsp+31], $BF
  vmovdqu ymm8, [rsp]
  add rsp, 32

  // === 栈上常量: splat_60, splat_70, splat_80 ===
  sub rsp, 96
  mov eax, $60606060
  vmovd xmm0, eax
  vpbroadcastd ymm0, xmm0
  vmovdqu [rsp], ymm0           // [rsp] = splat_60

  mov eax, $70707070
  vmovd xmm0, eax
  vpbroadcastd ymm0, xmm0
  vmovdqu [rsp+32], ymm0        // [rsp+32] = splat_70

  mov eax, $80808080
  vmovd xmm0, eax
  vpbroadcastd ymm0, xmm0
  vmovdqu [rsp+64], ymm0        // [rsp+64] = splat_80

  // === 主循环 ===
@loop:
  cmp rsi, 32
  jb @tail

  vmovdqu ymm0, [rdi]

  // ASCII fast-path
  vpmovmskb eax, ymm0
  test eax, eax
  jnz @non_ascii

  // 全 ASCII chunk: error |= prev_incomplete; prev_incomplete = 0; prev_block = curr
  vpor ymm15, ymm15, ymm14
  vpxor ymm14, ymm14, ymm14
  vmovdqa ymm13, ymm0
  jmp @advance

@non_ascii:
  // === ProcessChunk: lookup4 验证 ===
  // prev1 = PrevBytes(curr, prev_block, 1)
  vperm2i128 ymm1, ymm13, ymm0, $21
  vpalignr ymm2, ymm0, ymm1, 15    // ymm2 = prev1

  // nibble extraction
  vpsrlw ymm3, ymm2, 4
  vpand ymm3, ymm3, ymm12          // prev1_hi_nibble
  vpand ymm4, ymm2, ymm12          // prev1_lo_nibble
  vpsrlw ymm5, ymm0, 4
  vpand ymm5, ymm5, ymm12          // curr_hi_nibble

  // 3x vpshufb lookup
  vpshufb ymm3, ymm11, ymm3        // B1H = LUT1[prev1_hi]
  vpshufb ymm4, ymm10, ymm4        // B1L = LUT2[prev1_lo]
  vpshufb ymm5, ymm9, ymm5         // B2H = LUT3[curr_hi]

  // special_cases = B1H & B1L & B2H
  vpand ymm3, ymm3, ymm4
  vpand ymm3, ymm3, ymm5

  // must_be_2_3_continuation
  vpalignr ymm6, ymm0, ymm1, 14    // prev2
  vpalignr ymm7, ymm0, ymm1, 13    // prev3
  vpsubusb ymm6, ymm6, [rsp]       // sat_sub(prev2, $60)
  vpsubusb ymm7, ymm7, [rsp+32]    // sat_sub(prev3, $70)
  vpor ymm6, ymm6, ymm7
  vpand ymm6, ymm6, [rsp+64]       // must23_80

  // error |= (sc ^ must23_80)
  vpxor ymm3, ymm3, ymm6
  vpor ymm15, ymm15, ymm3

  // prev_incomplete = sat_sub(curr, IncompleteMax)
  vpsubusb ymm14, ymm0, ymm8
  // prev_block = curr
  vmovdqa ymm13, ymm0

@advance:
  add rdi, 32
  sub rsi, 32
  jmp @loop

  // === 尾部处理 (1-31 字节) ===
@tail:
  test rsi, rsi
  jz @finalize

  // 零填充 32 字节栈缓冲区
  sub rsp, 32
  vpxor ymm0, ymm0, ymm0
  vmovdqu [rsp], ymm0

  // 逐字节拷贝剩余数据
  mov rcx, rsi
  lea rdx, [rsp]
@copy_tail:
  movzx eax, byte [rdi]
  mov [rdx], al
  inc rdi
  inc rdx
  dec rcx
  jnz @copy_tail

  // 加载并处理
  vmovdqu ymm0, [rsp]
  add rsp, 32

  // 完整 ProcessChunk (同上)
  vperm2i128 ymm1, ymm13, ymm0, $21
  vpalignr ymm2, ymm0, ymm1, 15
  vpsrlw ymm3, ymm2, 4
  vpand ymm3, ymm3, ymm12
  vpand ymm4, ymm2, ymm12
  vpsrlw ymm5, ymm0, 4
  vpand ymm5, ymm5, ymm12
  vpshufb ymm3, ymm11, ymm3
  vpshufb ymm4, ymm10, ymm4
  vpshufb ymm5, ymm9, ymm5
  vpand ymm3, ymm3, ymm4
  vpand ymm3, ymm3, ymm5
  vpalignr ymm6, ymm0, ymm1, 14
  vpalignr ymm7, ymm0, ymm1, 13
  vpsubusb ymm6, ymm6, [rsp]       // splat_60 still at rsp (after add rsp,32 above... wait)
  // 注意: 上面 add rsp,32 后 splat 常量仍在 [rsp] (因为之前 sub rsp,96 的空间还在)
  vpsubusb ymm7, ymm7, [rsp+32]
  vpor ymm6, ymm6, ymm7
  vpand ymm6, ymm6, [rsp+64]
  vpxor ymm3, ymm3, ymm6
  vpor ymm15, ymm15, ymm3
  vpsubusb ymm14, ymm0, ymm8

  // === 最终检查 ===
@finalize:
  vpor ymm15, ymm15, ymm14
  vptest ymm15, ymm15
  setz al
  movzx eax, al

  // 清理栈 (96 bytes for splat constants)
  add rsp, 96
  vzeroupper
  ret

@valid:
  mov eax, 1
  ret

@invalid:
  xor eax, eax
  ret
end;

// MemReverse_AVX2 - 使用标量字节反转（优化版本）
// 策略: 从两端向中间交换，利用 bswap 一次处理 8 字节
procedure MemReverse_AVX2(p: Pointer; len: SizeUInt); assembler; nostackframe;
asm
  // RDI = p, RSI = len
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done
  cmp rsi, 1
  je @done
  
  // pLeft = p, pRight = p + len - 1
  mov rax, rdi               // rax = pLeft
  lea rdx, [rdi + rsi - 1]   // rdx = pRight
  
  // 主循环: 一次交换 8 字节 (64-bit)
@loop8:
  lea rcx, [rax + 8]
  cmp rcx, rdx
  ja @loop1
  
  // 加载左右各 8 字节
  mov r8, qword ptr [rax]      // left 8 bytes
  mov r9, qword ptr [rdx - 7]  // right 8 bytes (rdx 指向最后一个字节)
  
  // 使用 bswap 反转字节序
  bswap r8
  bswap r9
  
  // 交换写回
  mov qword ptr [rax], r9
  mov qword ptr [rdx - 7], r8
  
  add rax, 8
  sub rdx, 8
  jmp @loop8
  
  // 处理剩余字节: 一次交换 1 字节
@loop1:
  cmp rax, rdx
  jae @done
  
  movzx ecx, byte ptr [rax]
  movzx r8d, byte ptr [rdx]
  mov byte ptr [rax], r8b
  mov byte ptr [rdx], cl
  
  inc rax
  dec rdx
  jmp @loop1
  
@done:
end;

// AsciiIEqual_AVX2 - 向量化 ASCII 大小写不敏感比较
// 策略: 将两边都转为小写后比较
function AsciiIEqual_AVX2(a, b: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;
asm
  // RDI = a, RSI = b, RDX = len
  mov rax, 1             // 默认 true
  
  test rdx, rdx
  jz @done
  test rdi, rdi
  jz @check_both_nil
  test rsi, rsi
  jz @false
  cmp rdi, rsi
  je @done               // 同一指针
  
  // 准备常量:
  // 'A' = 65, 'Z' = 90, 差值 = 32
  mov r8d, 64            // 'A' - 1
  vmovd xmm2, r8d
  vpbroadcastb ymm2, xmm2  // ymm2 = all 64 ('A'-1)
  
  mov r8d, 91            // 'Z' + 1  
  vmovd xmm3, r8d
  vpbroadcastb ymm3, xmm3  // ymm3 = all 91 ('Z'+1)
  
  mov r8d, 32
  vmovd xmm4, r8d
  vpbroadcastb ymm4, xmm4  // ymm4 = all 32 (大小写差)
  
  xor rcx, rcx           // i = 0
  
@loop32:
  lea r8, [rcx + 32]
  cmp r8, rdx
  ja @loop_remainder
  
  // 加载 32 字节
  vmovdqu ymm0, [rdi + rcx]  // a
  vmovdqu ymm1, [rsi + rcx]  // b
  
  // 将 a 转为小写: 如果在 A-Z 范围，加 32
  vpcmpgtb ymm5, ymm0, ymm2      // a > 'A'-1
  vpcmpgtb ymm6, ymm3, ymm0      // 'Z'+1 > a
  vpand ymm5, ymm5, ymm6          // 在 A-Z 范围内
  vpand ymm5, ymm5, ymm4          // 掩码 & 32
  vpaddb ymm0, ymm0, ymm5         // a += 32 (if A-Z)
  
  // 将 b 转为小写
  vpcmpgtb ymm5, ymm1, ymm2
  vpcmpgtb ymm6, ymm3, ymm1
  vpand ymm5, ymm5, ymm6
  vpand ymm5, ymm5, ymm4
  vpaddb ymm1, ymm1, ymm5
  
  // 比较
  vpcmpeqb ymm0, ymm0, ymm1
  vpmovmskb r8d, ymm0
  cmp r8d, $FFFFFFFF
  jne @false_cleanup
  
  add rcx, 32
  jmp @loop32
  
@loop_remainder:
  vzeroupper
  cmp rcx, rdx
  jae @done
  
  // 标量处理剩余字节
@scalar_loop:
  movzx r8d, byte ptr [rdi + rcx]
  movzx r9d, byte ptr [rsi + rcx]
  
  // 转小写
  cmp r8d, 65
  jb @skip_lower1
  cmp r8d, 90
  ja @skip_lower1
  add r8d, 32
@skip_lower1:
  cmp r9d, 65
  jb @skip_lower2
  cmp r9d, 90
  ja @skip_lower2
  add r9d, 32
@skip_lower2:
  
  cmp r8d, r9d
  jne @false
  
  inc rcx
  cmp rcx, rdx
  jb @scalar_loop
  jmp @done
  
@check_both_nil:
  test rsi, rsi
  jnz @false
  jmp @done
  
@false_cleanup:
  vzeroupper
@false:
  xor eax, eax
@done:
end;

// ToLowerAscii_AVX2 - 向量化 ASCII 大写转小写
procedure ToLowerAscii_AVX2(p: Pointer; len: SizeUInt); assembler; nostackframe;
asm
  // RDI = p, RSI = len
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done
  
  // 准备常量
  mov eax, 64            // 'A' - 1
  vmovd xmm2, eax
  vpbroadcastb ymm2, xmm2
  
  mov eax, 91            // 'Z' + 1
  vmovd xmm3, eax
  vpbroadcastb ymm3, xmm3
  
  mov eax, 32
  vmovd xmm4, eax
  vpbroadcastb ymm4, xmm4
  
  xor rcx, rcx
  
@loop32:
  lea rax, [rcx + 32]
  cmp rax, rsi
  ja @remainder
  
  vmovdqu ymm0, [rdi + rcx]
  vpcmpgtb ymm5, ymm0, ymm2      // > 'A'-1
  vpcmpgtb ymm6, ymm3, ymm0      // < 'Z'+1
  vpand ymm5, ymm5, ymm6          // in A-Z
  vpand ymm5, ymm5, ymm4          // mask & 32
  vpaddb ymm0, ymm0, ymm5         // += 32
  vmovdqu [rdi + rcx], ymm0
  
  add rcx, 32
  jmp @loop32
  
@remainder:
  vzeroupper
  cmp rcx, rsi
  jae @done
  
@scalar_loop:
  movzx eax, byte ptr [rdi + rcx]
  cmp eax, 65
  jb @skip
  cmp eax, 90
  ja @skip
  add eax, 32
  mov byte ptr [rdi + rcx], al
@skip:
  inc rcx
  cmp rcx, rsi
  jb @scalar_loop
  
@done:
end;

// ToUpperAscii_AVX2 - 向量化 ASCII 小写转大写
procedure ToUpperAscii_AVX2(p: Pointer; len: SizeUInt); assembler; nostackframe;
asm
  // RDI = p, RSI = len
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done
  
  // 准备常量: 'a' = 97, 'z' = 122
  mov eax, 96            // 'a' - 1
  vmovd xmm2, eax
  vpbroadcastb ymm2, xmm2
  
  mov eax, 123           // 'z' + 1
  vmovd xmm3, eax
  vpbroadcastb ymm3, xmm3
  
  mov eax, 32
  vmovd xmm4, eax
  vpbroadcastb ymm4, xmm4
  
  xor rcx, rcx
  
@loop32:
  lea rax, [rcx + 32]
  cmp rax, rsi
  ja @remainder
  
  vmovdqu ymm0, [rdi + rcx]
  vpcmpgtb ymm5, ymm0, ymm2      // > 'a'-1
  vpcmpgtb ymm6, ymm3, ymm0      // < 'z'+1
  vpand ymm5, ymm5, ymm6          // in a-z
  vpand ymm5, ymm5, ymm4          // mask & 32
  vpsubb ymm0, ymm0, ymm5         // -= 32
  vmovdqu [rdi + rcx], ymm0
  
  add rcx, 32
  jmp @loop32
  
@remainder:
  vzeroupper
  cmp rcx, rsi
  jae @done
  
@scalar_loop:
  movzx eax, byte ptr [rdi + rcx]
  cmp eax, 97
  jb @skip
  cmp eax, 122
  ja @skip
  sub eax, 32
  mov byte ptr [rdi + rcx], al
@skip:
  inc rcx
  cmp rcx, rsi
  jb @scalar_loop
  
@done:
end;

// MemCopy_AVX2 - 大缓冲区使用 NT stores 避免 cache 污染
// < 256KB: rep movsb (利用 CPU ERMS 优化)
// >= 256KB: vmovdqu load + vmovntdq store (bypass cache, 要求 dst 32B 对齐)
procedure MemCopy_AVX2(src, dst: Pointer; len: SizeUInt); assembler; nostackframe;
// RDI = src, RSI = dst, RDX = len
asm
  test rdx, rdx
  jz @done
  test rdi, rdi
  jz @done
  test rsi, rsi
  jz @done

  // < 256KB 或 dst 未对齐: 用 rep movsb
  cmp rdx, 262144
  jb @use_move
  test rsi, 31
  jnz @use_move

  // === NT store path (>= 256KB, dst 32B aligned) ===
  mov rcx, rdx
  shr rcx, 5
  test rcx, rcx
  jz @nt_tail

@nt_loop:
  vmovdqu ymm0, [rdi]
  vmovntdq [rsi], ymm0
  add rdi, 32
  add rsi, 32
  dec rcx
  jnz @nt_loop

  sfence

@nt_tail:
  and rdx, 31
  test rdx, rdx
  jz @nt_done
  // rep movsb needs RSI=src, RDI=dst — swap
  mov rax, rdi
  mov rdi, rsi
  mov rsi, rax
  mov rcx, rdx
  cld
  rep movsb

@nt_done:
  vzeroupper
  ret

@use_move:
  // rep movsb: RSI=source, RDI=dest — swap our params
  mov rax, rdi        // rax = src (was in RDI)
  mov rdi, rsi        // RDI = dst (for rep movsb dest)
  mov rsi, rax        // RSI = src (for rep movsb source)
  mov rcx, rdx        // RCX = len
  cld
  rep movsb

@done:
end;

// MemSet_AVX2 - 使用 FPC 内置 FillChar 函数（已足够优化）
// 提供此接口保持 API 一致性，实际调用 FPC 运行时库
procedure MemSet_AVX2(dst: Pointer; len: SizeUInt; value: Byte);
begin
  if (len = 0) or (dst = nil) then
    Exit;
  FillChar(dst^, len, value);
end;

// MemDiffRange_AVX2 - 向量化查找两个缓冲区第一个和最后一个不同字节的位置
// 策略: 使用 AVX2 vpcmpeqb 比较 32 字节，找到不等的位置
function MemDiffRange_AVX2(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
var
  pa, pb: PByte;
  i, blockStart: SizeUInt;
  mask: UInt32;
  foundFirst: Boolean;
  firstPos, lastPos: SizeUInt;
begin
  firstDiff := 0;
  lastDiff := 0;
  Result := False;
  
  if len = 0 then Exit;
  
  if (a = nil) or (b = nil) then
  begin
    if a <> b then
    begin
      firstDiff := 0;
      lastDiff := len - 1;
      Result := True;
    end;
    Exit;
  end;
  
  pa := PByte(a);
  pb := PByte(b);
  foundFirst := False;
  firstPos := 0;
  lastPos := 0;
  i := 0;
  
  // 向量循环: 一次处理 32 字节
  while i + 32 <= len do
  begin
    asm
      mov rax, pa
      add rax, i
      mov rdx, pb
      add rdx, i
      vmovdqu ymm0, [rax]
      vpcmpeqb ymm0, ymm0, [rdx]
      vpmovmskb eax, ymm0
      not eax               // 反转: 1 表示不等
      mov mask, eax
    end;
    
    if mask <> 0 then
    begin
      // 找到不等字节
      blockStart := i;
      
      // 找第一个不等位置
      if not foundFirst then
      begin
        asm
          mov eax, mask
          bsf eax, eax       // 找第一个置位
          mov firstPos, rax
        end;
        firstPos := blockStart + firstPos;
        foundFirst := True;
      end;
      
      // 更新最后一个不等位置
      asm
        mov eax, mask
        bsr eax, eax         // 找最后一个置位
        mov lastPos, rax
      end;
      lastPos := blockStart + lastPos;
    end;
    
    Inc(i, 32);
  end;
  
  asm
    vzeroupper
  end;
  
  // 处理剩余字节
  while i < len do
  begin
    if pa[i] <> pb[i] then
    begin
      if not foundFirst then
      begin
        firstPos := i;
        foundFirst := True;
      end;
      lastPos := i;
    end;
    Inc(i);
  end;
  
  if foundFirst then
  begin
    firstDiff := firstPos;
    lastDiff := lastPos;
    Result := True;
  end;
end;

// BytesIndexOf_AVX2 - 向量化字节序列搜索
// 策略: 使用 AVX2 搜索 needle 的第一个字节，找到后验证完整匹配
function BytesIndexOf_AVX2(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
var
  ph, pn: PByte;
  i, j: SizeUInt;
  firstByte: Byte;
  mask: UInt32;
  bitPos: Integer;
  found: Boolean;
begin
  Result := -1;
  
  if (haystackLen = 0) or (needleLen = 0) or (haystack = nil) or (needle = nil) then
    Exit;
  
  if needleLen > haystackLen then
    Exit;
  
  ph := PByte(haystack);
  pn := PByte(needle);
  firstByte := pn[0];
  
  // 如果 needle 只有 1 字节，使用 MemFindByte
  if needleLen = 1 then
  begin
    Result := MemFindByte_AVX2(haystack, haystackLen, firstByte);
    Exit;
  end;
  
  i := 0;
  
  // 向量化搜索第一个字节
  while i + 32 <= haystackLen - needleLen + 1 do
  begin
    asm
      // 广播第一个字节
      movzx eax, firstByte
      vmovd xmm1, eax
      vpbroadcastb ymm1, xmm1
      
      // 加载 32 字节并比较
      mov rax, ph
      add rax, i
      vmovdqu ymm0, [rax]
      vpcmpeqb ymm0, ymm0, ymm1
      vpmovmskb eax, ymm0
      mov mask, eax
    end;
    
    // 检查每个匹配位置
    while mask <> 0 do
    begin
      asm
        mov eax, mask
        bsf eax, eax
        mov bitPos, eax
      end;
      
      // 验证完整匹配
      if i + SizeUInt(bitPos) + needleLen <= haystackLen then
      begin
        found := True;
        for j := 1 to needleLen - 1 do
        begin
          if ph[i + SizeUInt(bitPos) + j] <> pn[j] then
          begin
            found := False;
            Break;
          end;
        end;
        
        if found then
        begin
          asm
            vzeroupper
          end;
          Result := PtrInt(i + SizeUInt(bitPos));
          Exit;
        end;
      end;
      
      // 清除已检查的位
      mask := mask and not (1 shl bitPos);
    end;
    
    Inc(i, 32);
  end;
  
  asm
    vzeroupper
  end;
  
  // 标量处理剩余部分
  while i <= haystackLen - needleLen do
  begin
    if ph[i] = firstByte then
    begin
      found := True;
      for j := 1 to needleLen - 1 do
      begin
        if ph[i + j] <> pn[j] then
        begin
          found := False;
          Break;
        end;
      end;
      
      if found then
      begin
        Result := PtrInt(i);
        Exit;
      end;
    end;
    Inc(i);
  end;
end;

