// === AVX2 Memory Functions (256-bit) ===

function MemEqual_AVX2(a, b: Pointer; len: SizeUInt): LongBool; assembler; nostackframe;
// SysV: RDI = a, RSI = b, RDX = len
// Win64: RCX = a, RDX = b, R8 = len
asm
{$IFDEF UNIX}
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
{$ELSE}
  // Windows x64: RCX = a, RDX = b, R8 = len
  xor eax, eax
  test r8, r8
  jz @equal
  test rcx, rcx
  jz @check_both_nil
  test rdx, rdx
  jz @done
  cmp rcx, rdx
  je @equal

  // Use r10 as index (rcx/rdx are params)
  xor r10, r10

@loop32:
  lea r9, [r10 + 32]
  cmp r9, r8
  ja @loop16
  vmovdqu ymm0, [rcx + r10]
  vpcmpeqb ymm0, ymm0, [rdx + r10]
  vpmovmskb eax, ymm0
  cmp eax, $FFFFFFFF
  jne @not_equal_cleanup
  add r10, 32
  jmp @loop32

@loop16:
  lea r9, [r10 + 16]
  cmp r9, r8
  ja @remainder
  vmovdqu xmm0, [rcx + r10]
  vpcmpeqb xmm0, xmm0, [rdx + r10]
  vpmovmskb eax, xmm0
  cmp eax, $FFFF
  jne @not_equal_cleanup
  add r10, 16
  jmp @loop16

@remainder:
  cmp r10, r8
  jae @equal_cleanup
  movzx r9d, byte ptr [rcx + r10]
  movzx r11d, byte ptr [rdx + r10]
  cmp r9d, r11d
  jne @not_equal_cleanup
  inc r10
  jmp @remainder

@check_both_nil:
  test rdx, rdx
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
{$ENDIF}
end;

function MemFindByte_AVX2(p: Pointer; len: SizeUInt; value: Byte): PtrInt; assembler; nostackframe;
// SysV: RDI = p, RSI = len, RDX = value
// Win64: RCX = p, RDX = len, R8 = value
asm
{$IFDEF UNIX}
  mov rax, -1
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done

  vmovd xmm1, edx
  vpbroadcastb ymm1, xmm1

  xor rcx, rcx

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
{$ELSE}
  // Windows x64: RCX = p, RDX = len, R8 = value
  mov rax, -1
  test rdx, rdx
  jz @done
  test rcx, rcx
  jz @done

  vmovd xmm1, r8d
  vpbroadcastb ymm1, xmm1

  xor r10, r10

@loop32:
  lea r9, [r10 + 32]
  cmp r9, rdx
  ja @loop16
  vmovdqu ymm0, [rcx + r10]
  vpcmpeqb ymm0, ymm0, ymm1
  vpmovmskb r9d, ymm0
  test r9d, r9d
  jnz @found32
  add r10, 32
  jmp @loop32

@found32:
  bsf r9d, r9d
  lea rax, [r10 + r9]
  vzeroupper
  ret

@loop16:
  lea r9, [r10 + 16]
  cmp r9, rdx
  ja @remainder
  vmovdqu xmm0, [rcx + r10]
  vpcmpeqb xmm0, xmm0, xmm1
  vpmovmskb r9d, xmm0
  test r9d, r9d
  jnz @found16
  add r10, 16
  jmp @loop16

@found16:
  bsf r9d, r9d
  lea rax, [r10 + r9]
  vzeroupper
  ret

@remainder:
  cmp r10, rdx
  jae @cleanup
  movzx r9d, byte ptr [rcx + r10]
  cmp r9d, r8d
  je @found_remainder
  inc r10
  jmp @remainder

@found_remainder:
  mov rax, r10
  vzeroupper
  ret

@cleanup:
  vzeroupper
  mov rax, -1
@done:
{$ENDIF}
end;

function SumBytes_AVX2(p: Pointer; len: SizeUInt): UInt64; assembler; nostackframe;
// SysV: RDI = p, RSI = len
// Win64: RCX = p, RDX = len
asm
{$IFDEF UNIX}
  xor rax, rax
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done

  vpxor ymm2, ymm2, ymm2
  vpxor ymm3, ymm3, ymm3
  xor rcx, rcx

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
  vextracti128 xmm4, ymm2, 1
  vpaddq xmm2, xmm2, xmm4

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
  vpshufd xmm1, xmm2, $4E
  vpaddq xmm0, xmm2, xmm1
  vmovq rax, xmm0
  vzeroupper

@remainder_loop:
  cmp rcx, rsi
  jae @done
  movzx r8d, byte ptr [rdi + rcx]
  add rax, r8
  inc rcx
  jmp @remainder_loop

@done:
{$ELSE}
  // Windows x64: RCX = p, RDX = len
  xor rax, rax
  test rdx, rdx
  jz @done
  test rcx, rcx
  jz @done

  vpxor ymm2, ymm2, ymm2
  vpxor ymm3, ymm3, ymm3
  xor r10, r10

@loop32:
  lea r8, [r10 + 32]
  cmp r8, rdx
  ja @loop16
  vmovdqu ymm0, [rcx + r10]
  vpsadbw ymm0, ymm0, ymm3
  vpaddq ymm2, ymm2, ymm0
  add r10, 32
  jmp @loop32

@loop16:
  vextracti128 xmm4, ymm2, 1
  vpaddq xmm2, xmm2, xmm4

@loop16_inner:
  lea r8, [r10 + 16]
  cmp r8, rdx
  ja @remainder
  vmovdqu xmm0, [rcx + r10]
  vpsadbw xmm0, xmm0, xmm3
  vpaddq xmm2, xmm2, xmm0
  add r10, 16
  jmp @loop16_inner

@remainder:
  vpshufd xmm1, xmm2, $4E
  vpaddq xmm0, xmm2, xmm1
  vmovq rax, xmm0
  vzeroupper

@remainder_loop:
  cmp r10, rdx
  jae @done
  movzx r8d, byte ptr [rcx + r10]
  add rax, r8
  inc r10
  jmp @remainder_loop

@done:
{$ENDIF}
end;

function CountByte_AVX2(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; assembler; nostackframe;
// SysV: RDI = p, RSI = len, RDX = value
// Win64: RCX = p, RDX = len, R8 = value
asm
{$IFDEF UNIX}
  xor rax, rax
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done

  vmovd xmm1, edx
  vpbroadcastb ymm1, xmm1

  xor rcx, rcx

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
{$ELSE}
  // Windows x64: RCX = p, RDX = len, R8 = value
  xor rax, rax
  test rdx, rdx
  jz @done
  test rcx, rcx
  jz @done

  vmovd xmm1, r8d
  vpbroadcastb ymm1, xmm1

  xor r10, r10

@loop32:
  lea r9, [r10 + 32]
  cmp r9, rdx
  ja @loop16
  vmovdqu ymm0, [rcx + r10]
  vpcmpeqb ymm0, ymm0, ymm1
  vpmovmskb r9d, ymm0
  popcnt r9d, r9d
  add rax, r9
  add r10, 32
  jmp @loop32

@loop16:
  lea r9, [r10 + 16]
  cmp r9, rdx
  ja @remainder
  vmovdqu xmm0, [rcx + r10]
  vpcmpeqb xmm0, xmm0, xmm1
  vpmovmskb r9d, xmm0
  popcnt r9d, r9d
  add rax, r9
  add r10, 16
  jmp @loop16

@remainder:
  vzeroupper
@remainder_loop:
  cmp r10, rdx
  jae @done
  movzx r9d, byte ptr [rcx + r10]
  cmp r9d, r8d
  jne @skip
  inc rax
@skip:
  inc r10
  jmp @remainder_loop

@done:
{$ENDIF}
end;

// MinMaxBytes_AVX2 - 使用 AVX2 vpminub/vpmaxub 指令查找字节数组的最小和最大值
// 使用 256 位宽向量一次处理 32 字节
procedure MinMaxBytes_AVX2(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte); assembler; nostackframe;
// SysV: RDI = p, RSI = len, RDX = &minVal, RCX = &maxVal
// Win64: RCX = p, RDX = len, R8 = &minVal, R9 = &maxVal
asm
{$IFDEF UNIX}
  push rbx
  mov r8, rdx       // r8 = &minVal
  mov r9, rcx       // r9 = &maxVal
  
  test rsi, rsi
  jz @empty
  
  mov al, 255
  mov bl, 0
  
  cmp rsi, 32
  jb @scalar_loop
  
  vpcmpeqb ymm0, ymm0, ymm0
  vpxor ymm1, ymm1, ymm1
  
  mov rcx, rsi
  shr rcx, 5

@vector_loop:
  vmovdqu ymm2, [rdi]
  vpminub ymm0, ymm0, ymm2
  vpmaxub ymm1, ymm1, ymm2
  add rdi, 32
  dec rcx
  jnz @vector_loop
  
  vextracti128 xmm2, ymm0, 1
  vextracti128 xmm3, ymm1, 1
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  vpsrldq xmm2, xmm0, 8
  vpsrldq xmm3, xmm1, 8
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  vpsrldq xmm2, xmm0, 4
  vpsrldq xmm3, xmm1, 4
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  vpsrldq xmm2, xmm0, 2
  vpsrldq xmm3, xmm1, 2
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  vpsrldq xmm2, xmm0, 1
  vpsrldq xmm3, xmm1, 1
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  vpextrb eax, xmm0, 0
  vpextrb ebx, xmm1, 0
  
  and rsi, 31
  jz @store_result

@scalar_loop:
  test rsi, rsi
  jz @store_result
  movzx ecx, byte ptr [rdi]
  cmp cl, al
  cmovb eax, ecx
  cmp cl, bl
  cmova ebx, ecx
  inc rdi
  dec rsi
  jnz @scalar_loop
  
@store_result:
  mov [r8], al
  mov [r9], bl
  vzeroupper
  pop rbx
  jmp @return
  
@empty:
  mov byte ptr [r8], 0
  mov byte ptr [r9], 0
  pop rbx
  
@return:
{$ELSE}
  // Windows x64: RCX = p, RDX = len, R8 = &minVal, R9 = &maxVal
  push rbx
  push rsi
  push rdi
  mov rdi, rcx      // rdi = p
  mov rsi, rdx      // rsi = len
  // r8 = &minVal (already)
  // r9 = &maxVal (already)
  
  test rsi, rsi
  jz @empty
  
  mov al, 255
  mov bl, 0
  
  cmp rsi, 32
  jb @scalar_loop
  
  vpcmpeqb ymm0, ymm0, ymm0
  vpxor ymm1, ymm1, ymm1
  
  mov rcx, rsi
  shr rcx, 5

@vector_loop:
  vmovdqu ymm2, [rdi]
  vpminub ymm0, ymm0, ymm2
  vpmaxub ymm1, ymm1, ymm2
  add rdi, 32
  dec rcx
  jnz @vector_loop
  
  vextracti128 xmm2, ymm0, 1
  vextracti128 xmm3, ymm1, 1
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  vpsrldq xmm2, xmm0, 8
  vpsrldq xmm3, xmm1, 8
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  vpsrldq xmm2, xmm0, 4
  vpsrldq xmm3, xmm1, 4
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  vpsrldq xmm2, xmm0, 2
  vpsrldq xmm3, xmm1, 2
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  vpsrldq xmm2, xmm0, 1
  vpsrldq xmm3, xmm1, 1
  vpminub xmm0, xmm0, xmm2
  vpmaxub xmm1, xmm1, xmm3
  
  vpextrb eax, xmm0, 0
  vpextrb ebx, xmm1, 0
  
  and rsi, 31
  jz @store_result

@scalar_loop:
  test rsi, rsi
  jz @store_result
  movzx ecx, byte ptr [rdi]
  cmp cl, al
  cmovb eax, ecx
  cmp cl, bl
  cmova ebx, ecx
  inc rdi
  dec rsi
  jnz @scalar_loop
  
@store_result:
  mov [r8], al
  mov [r9], bl
  vzeroupper
  pop rdi
  pop rsi
  pop rbx
  jmp @return
  
@empty:
  mov byte ptr [r8], 0
  mov byte ptr [r9], 0
  pop rdi
  pop rsi
  pop rbx
  
@return:
{$ENDIF}
end;

// BitsetPopCount_AVX2 - 使用 POPCNT 指令计算位集中置 1 的位数
// 一次处理 8 字节（64位）使用硬件 POPCNT 指令
function BitsetPopCount_AVX2(p: Pointer; len: SizeUInt): SizeUInt; assembler; nostackframe;
// SysV: RDI = p, RSI = len
// Win64: RCX = p, RDX = len
asm
{$IFDEF UNIX}
  xor rax, rax
  
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done
  
  mov rcx, rsi
  shr rcx, 3
  jz @remainder
  
@main_loop:
  popcnt rdx, qword ptr [rdi]
  add rax, rdx
  add rdi, 8
  dec rcx
  jnz @main_loop
  
@remainder:
  and rsi, 7
  jz @done
  
@scalar_loop:
  movzx edx, byte ptr [rdi]
  popcnt edx, edx
  add rax, rdx
  inc rdi
  dec rsi
  jnz @scalar_loop
  
@done:
{$ELSE}
  // Windows x64: RCX = p, RDX = len
  xor rax, rax
  
  test rdx, rdx
  jz @done
  test rcx, rcx
  jz @done
  
  mov r10, rdx
  shr r10, 3
  jz @remainder
  
@main_loop:
  popcnt r8, qword ptr [rcx]
  add rax, r8
  add rcx, 8
  dec r10
  jnz @main_loop
  
@remainder:
  and rdx, 7
  jz @done
  
@scalar_loop:
  movzx r8d, byte ptr [rcx]
  popcnt r8d, r8d
  add rax, r8
  inc rcx
  dec rdx
  jnz @scalar_loop
  
@done:
{$ENDIF}
end;

// Utf8Validate_AVX2 - 完整 SIMD UTF-8 验证 (Lemire lookup4, 纯汇编)
// 32 字节/iter 处理所有 UTF-8 序列，不回退标量。
// 参考: simdjson utf8_lookup4_algorithm.h, Lemire arXiv:2010.03090
function Utf8Validate_AVX2(p: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;
// SysV: RDI = p, RSI = len
// Win64: RCX = p, RDX = len
asm
{$IFDEF UNIX}
  // === 边界检查 ===
  test rsi, rsi
  jz @valid
  test rdi, rdi
  jz @invalid
{$ELSE}
  // Windows x64: RCX = p, RDX = len -> remap to RDI, RSI
  // rdi/rsi are non-volatile on Windows, must save
  test rdx, rdx
  jz @valid
  test rcx, rcx
  jz @invalid
  push rdi
  push rsi
  mov rdi, rcx
  mov rsi, rdx
{$ENDIF}

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
  vpsubusb ymm6, ymm6, [rsp]
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
{$IFNDEF UNIX}
  pop rsi
  pop rdi
{$ENDIF}
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
// SysV: RDI = p, RSI = len
// Win64: RCX = p, RDX = len
asm
{$IFDEF UNIX}
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done
  cmp rsi, 1
  je @done
  
  mov rax, rdi
  lea rdx, [rdi + rsi - 1]
  
@loop8:
  lea rcx, [rax + 8]
  cmp rcx, rdx
  ja @loop1
  
  mov r8, qword ptr [rax]
  mov r9, qword ptr [rdx - 7]
  
  bswap r8
  bswap r9
  
  mov qword ptr [rax], r9
  mov qword ptr [rdx - 7], r8
  
  add rax, 8
  sub rdx, 8
  jmp @loop8
  
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
{$ELSE}
  // Windows x64: RCX = p, RDX = len
  test rdx, rdx
  jz @done
  test rcx, rcx
  jz @done
  cmp rdx, 1
  je @done
  
  mov rax, rcx               // rax = pLeft
  lea r10, [rcx + rdx - 1]  // r10 = pRight
  
@loop8:
  lea r8, [rax + 8]
  cmp r8, r10
  ja @loop1
  
  mov r8, qword ptr [rax]
  mov r9, qword ptr [r10 - 7]
  
  bswap r8
  bswap r9
  
  mov qword ptr [rax], r9
  mov qword ptr [r10 - 7], r8
  
  add rax, 8
  sub r10, 8
  jmp @loop8
  
@loop1:
  cmp rax, r10
  jae @done
  
  movzx r8d, byte ptr [rax]
  movzx r9d, byte ptr [r10]
  mov byte ptr [rax], r9b
  mov byte ptr [r10], r8b
  
  inc rax
  dec r10
  jmp @loop1
  
@done:
{$ENDIF}
end;

// AsciiIEqual_AVX2 - 向量化 ASCII 大小写不敏感比较
// 策略: 将两边都转为小写后比较
function AsciiIEqual_AVX2(a, b: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;
// SysV: RDI = a, RSI = b, RDX = len
// Win64: RCX = a, RDX = b, R8 = len
asm
{$IFDEF UNIX}
  mov rax, 1
  
  test rdx, rdx
  jz @done
  test rdi, rdi
  jz @check_both_nil
  test rsi, rsi
  jz @false
  cmp rdi, rsi
  je @done

  mov r8d, 64
  vmovd xmm2, r8d
  vpbroadcastb ymm2, xmm2

  mov r8d, 91
  vmovd xmm3, r8d
  vpbroadcastb ymm3, xmm3

  mov r8d, 32
  vmovd xmm4, r8d
  vpbroadcastb ymm4, xmm4

  xor rcx, rcx

@loop32:
  lea r8, [rcx + 32]
  cmp r8, rdx
  ja @loop_remainder

  vmovdqu ymm0, [rdi + rcx]
  vmovdqu ymm1, [rsi + rcx]

  vpcmpgtb ymm5, ymm0, ymm2
  vpcmpgtb ymm6, ymm3, ymm0
  vpand ymm5, ymm5, ymm6
  vpand ymm5, ymm5, ymm4
  vpaddb ymm0, ymm0, ymm5

  vpcmpgtb ymm5, ymm1, ymm2
  vpcmpgtb ymm6, ymm3, ymm1
  vpand ymm5, ymm5, ymm6
  vpand ymm5, ymm5, ymm4
  vpaddb ymm1, ymm1, ymm5

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

@scalar_loop:
  movzx r8d, byte ptr [rdi + rcx]
  movzx r9d, byte ptr [rsi + rcx]

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
{$ELSE}
  // Windows x64: RCX = a, RDX = b, R8 = len
  mov rax, 1
  
  test r8, r8
  jz @done
  test rcx, rcx
  jz @check_both_nil
  test rdx, rdx
  jz @false
  cmp rcx, rdx
  je @done

  // Prepare constants
  mov r9d, 64
  vmovd xmm2, r9d
  vpbroadcastb ymm2, xmm2

  mov r9d, 91
  vmovd xmm3, r9d
  vpbroadcastb ymm3, xmm3

  mov r9d, 32
  vmovd xmm4, r9d
  vpbroadcastb ymm4, xmm4

  xor r10, r10

@loop32:
  lea r9, [r10 + 32]
  cmp r9, r8
  ja @loop_remainder

  vmovdqu ymm0, [rcx + r10]
  vmovdqu ymm1, [rdx + r10]

  vpcmpgtb ymm5, ymm0, ymm2
  vpcmpgtb ymm6, ymm3, ymm0
  vpand ymm5, ymm5, ymm6
  vpand ymm5, ymm5, ymm4
  vpaddb ymm0, ymm0, ymm5

  vpcmpgtb ymm5, ymm1, ymm2
  vpcmpgtb ymm6, ymm3, ymm1
  vpand ymm5, ymm5, ymm6
  vpand ymm5, ymm5, ymm4
  vpaddb ymm1, ymm1, ymm5

  vpcmpeqb ymm0, ymm0, ymm1
  vpmovmskb r9d, ymm0
  cmp r9d, $FFFFFFFF
  jne @false_cleanup

  add r10, 32
  jmp @loop32

@loop_remainder:
  vzeroupper
  cmp r10, r8
  jae @done

@scalar_loop:
  movzx r9d, byte ptr [rcx + r10]
  movzx r11d, byte ptr [rdx + r10]

  cmp r9d, 65
  jb @skip_lower1
  cmp r9d, 90
  ja @skip_lower1
  add r9d, 32
@skip_lower1:
  cmp r11d, 65
  jb @skip_lower2
  cmp r11d, 90
  ja @skip_lower2
  add r11d, 32
@skip_lower2:

  cmp r9d, r11d
  jne @false

  inc r10
  cmp r10, r8
  jb @scalar_loop
  jmp @done

@check_both_nil:
  test rdx, rdx
  jnz @false
  jmp @done

@false_cleanup:
  vzeroupper
@false:
  xor eax, eax
@done:
{$ENDIF}
end;

// ToLowerAscii_AVX2 - 向量化 ASCII 大写转小写
procedure ToLowerAscii_AVX2(p: Pointer; len: SizeUInt); assembler; nostackframe;
// SysV: RDI = p, RSI = len
// Win64: RCX = p, RDX = len
asm
{$IFDEF UNIX}
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done
  
  mov eax, 64
  vmovd xmm2, eax
  vpbroadcastb ymm2, xmm2
  
  mov eax, 91
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
  vpcmpgtb ymm5, ymm0, ymm2
  vpcmpgtb ymm6, ymm3, ymm0
  vpand ymm5, ymm5, ymm6
  vpand ymm5, ymm5, ymm4
  vpaddb ymm0, ymm0, ymm5
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
{$ELSE}
  // Windows x64: RCX = p, RDX = len
  test rdx, rdx
  jz @done
  test rcx, rcx
  jz @done
  
  mov eax, 64
  vmovd xmm2, eax
  vpbroadcastb ymm2, xmm2
  
  mov eax, 91
  vmovd xmm3, eax
  vpbroadcastb ymm3, xmm3
  
  mov eax, 32
  vmovd xmm4, eax
  vpbroadcastb ymm4, xmm4
  
  xor r10, r10
  
@loop32:
  lea rax, [r10 + 32]
  cmp rax, rdx
  ja @remainder
  
  vmovdqu ymm0, [rcx + r10]
  vpcmpgtb ymm5, ymm0, ymm2
  vpcmpgtb ymm6, ymm3, ymm0
  vpand ymm5, ymm5, ymm6
  vpand ymm5, ymm5, ymm4
  vpaddb ymm0, ymm0, ymm5
  vmovdqu [rcx + r10], ymm0
  
  add r10, 32
  jmp @loop32
  
@remainder:
  vzeroupper
  cmp r10, rdx
  jae @done
  
@scalar_loop:
  movzx eax, byte ptr [rcx + r10]
  cmp eax, 65
  jb @skip
  cmp eax, 90
  ja @skip
  add eax, 32
  mov byte ptr [rcx + r10], al
@skip:
  inc r10
  cmp r10, rdx
  jb @scalar_loop
  
@done:
{$ENDIF}
end;

// ToUpperAscii_AVX2 - 向量化 ASCII 小写转大写
procedure ToUpperAscii_AVX2(p: Pointer; len: SizeUInt); assembler; nostackframe;
// SysV: RDI = p, RSI = len
// Win64: RCX = p, RDX = len
asm
{$IFDEF UNIX}
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done
  
  mov eax, 96
  vmovd xmm2, eax
  vpbroadcastb ymm2, xmm2
  
  mov eax, 123
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
  vpcmpgtb ymm5, ymm0, ymm2
  vpcmpgtb ymm6, ymm3, ymm0
  vpand ymm5, ymm5, ymm6
  vpand ymm5, ymm5, ymm4
  vpsubb ymm0, ymm0, ymm5
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
{$ELSE}
  // Windows x64: RCX = p, RDX = len
  test rdx, rdx
  jz @done
  test rcx, rcx
  jz @done
  
  mov eax, 96
  vmovd xmm2, eax
  vpbroadcastb ymm2, xmm2
  
  mov eax, 123
  vmovd xmm3, eax
  vpbroadcastb ymm3, xmm3
  
  mov eax, 32
  vmovd xmm4, eax
  vpbroadcastb ymm4, xmm4
  
  xor r10, r10
  
@loop32:
  lea rax, [r10 + 32]
  cmp rax, rdx
  ja @remainder
  
  vmovdqu ymm0, [rcx + r10]
  vpcmpgtb ymm5, ymm0, ymm2
  vpcmpgtb ymm6, ymm3, ymm0
  vpand ymm5, ymm5, ymm6
  vpand ymm5, ymm5, ymm4
  vpsubb ymm0, ymm0, ymm5
  vmovdqu [rcx + r10], ymm0
  
  add r10, 32
  jmp @loop32
  
@remainder:
  vzeroupper
  cmp r10, rdx
  jae @done
  
@scalar_loop:
  movzx eax, byte ptr [rcx + r10]
  cmp eax, 97
  jb @skip
  cmp eax, 122
  ja @skip
  sub eax, 32
  mov byte ptr [rcx + r10], al
@skip:
  inc r10
  cmp r10, rdx
  jb @scalar_loop
  
@done:
{$ENDIF}
end;

// MemCopy_AVX2 - 大缓冲区使用 NT stores 避免 cache 污染
// < 256KB: rep movsb (利用 CPU ERMS 优化)
// >= 256KB: vmovdqu load + vmovntdq store (bypass cache, 要求 dst 32B 对齐)
procedure MemCopy_AVX2(src, dst: Pointer; len: SizeUInt); assembler; nostackframe;
// SysV: RDI = src, RSI = dst, RDX = len
// Win64: RCX = src, RDX = dst, R8 = len
asm
{$IFDEF UNIX}
  test rdx, rdx
  jz @done
  test rdi, rdi
  jz @done
  test rsi, rsi
  jz @done

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
  mov rax, rdi
  mov rdi, rsi
  mov rsi, rax
  mov rcx, rdx
  cld
  rep movsb

@done:
{$ELSE}
  // Windows x64: RCX = src, RDX = dst, R8 = len
  test r8, r8
  jz @done
  test rcx, rcx
  jz @done
  test rdx, rdx
  jz @done

  cmp r8, 262144
  jb @use_move
  test rdx, 31
  jnz @use_move

  // === NT store path (>= 256KB, dst 32B aligned) ===
  mov r10, r8
  shr r10, 5
  test r10, r10
  jz @nt_tail

@nt_loop:
  vmovdqu ymm0, [rcx]
  vmovntdq [rdx], ymm0
  add rcx, 32
  add rdx, 32
  dec r10
  jnz @nt_loop

  sfence

@nt_tail:
  and r8, 31
  test r8, r8
  jz @nt_done
  // rep movsb: RDI=dst, RSI=src, RCX=len
  push rdi
  push rsi
  mov rdi, rdx
  mov rsi, rcx
  mov rcx, r8
  cld
  rep movsb
  pop rsi
  pop rdi

@nt_done:
  vzeroupper
  ret

@use_move:
  // rep movsb: RDI=dst, RSI=src, RCX=len
  push rdi
  push rsi
  mov rdi, rdx
  mov rsi, rcx
  mov rcx, r8
  cld
  rep movsb
  pop rsi
  pop rdi

@done:
{$ENDIF}
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
