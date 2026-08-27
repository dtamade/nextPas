unit nextpas.core.audio.codec.flac.sse;

{ 手工 NEON 内核：FLAC 去相关与 wasted_bits 的向量化。
  定点 32 位为主；64 位中间与 LPC dot 需 64 位累加与 floor Sar64。
  兼容性：ppcrossa64 3.3.1 的 aarch64 汇编器对 widen/narrow
  (sxtl/sxtl2/xtn/xtn2/sshll/sshll2/shrn/shrn2/saddl/smull 等)
  的 .2s/.2d/.4s 组合报 Invalid arrangement / Unrecognized opcode，
  因此 mid_side 与 LPC 的 64 位路径弃用 sxtl/xtn，改用向量加载 +
  sxtw/asr 的 4-wide 标量展开（每 4 样点一个向量 ld1/st1，lane 经
  umov/ins 提取/回填，或纯 GPR ldr/str；dot 经 sxtw+mul+add 64 位
  累加，asr x12,x12,w3 完成 Sar64 floor）。该迂回仍比纯标量少分支，
  且仅用已验证通过的指令：ld1/st1 .4s、dup .4s、ushl .4s、
  umov/ins/ldr/str、sxtw、lsl/orr/and/add/sub/mul/asr 等。 }

{$mode objfpc}{$H+}

{$if defined(cpux86_64) or defined(cpuaarch64)}
{$ifndef FLAC_NO_SIMD}
{$define FLAC_SIMD}
{$endif}
{$ifend}

interface

{$ifdef FLAC_SIMD}
{$ifdef cpuaarch64}
procedure flac_left_side_neon(dst1_: PInt32; src0_: PInt32; n_: LongWord); // dst1[i] = src0 - dst1
procedure flac_right_side_neon(dst0_: PInt32; src1_: PInt32; n_: LongWord); // dst0[i] += src1[i]
procedure flac_wasted_bits_neon(dst_: PInt32; n_: LongWord; shift_: LongWord); // dst[i] <<= shift
procedure flac_mid_side_neon(mid_: PInt32; side_: PInt32; n_: LongWord); // m=(mid<<1)|(side&1); mid=(m+side)>>1 floor; side=(m-side)>>1
procedure flac_lpc_restore_neon(out_: PInt32; coeff_: PInt32; order_: LongWord; shift_: LongWord; n_: LongWord); // LPC 预测还原：dot=Σ out*coeff，Sar64
{$endif}
{$endif}

implementation

{$ifdef FLAC_SIMD}
{$ifdef cpuaarch64}

procedure flac_left_side_neon(dst1_: PInt32; src0_: PInt32; n_: LongWord); assembler; nostackframe;
{ x0=dst1  x1=src0  w2=n }
asm
  cbz     w2, .Lfls_left_done
  lsr     w3, w2, #2
  cbz     w3, .Lfls_left_tail
.Lfls_left_loop:
  ld1     {v0.4s}, [x1], #16
  ld1     {v1.4s}, [x0]
  sub     v1.4s, v0.4s, v1.4s
  st1     {v1.4s}, [x0], #16
  sub     w3, w3, #1
  cbnz    w3, .Lfls_left_loop
.Lfls_left_tail:
  and     w2, w2, #3
  cbz     w2, .Lfls_left_done
.Lfls_left_tail_loop:
  ldr     w3, [x1], #4
  ldr     w4, [x0]
  sub     w4, w3, w4
  str     w4, [x0], #4
  sub     w2, w2, #1
  cbnz    w2, .Lfls_left_tail_loop
.Lfls_left_done:
end;

procedure flac_right_side_neon(dst0_: PInt32; src1_: PInt32; n_: LongWord); assembler; nostackframe;
asm
  cbz     w2, .Lfls_right_done
  lsr     w3, w2, #2
  cbz     w3, .Lfls_right_tail
.Lfls_right_loop:
  ld1     {v0.4s}, [x1], #16
  ld1     {v1.4s}, [x0]
  add     v1.4s, v1.4s, v0.4s
  st1     {v1.4s}, [x0], #16
  sub     w3, w3, #1
  cbnz    w3, .Lfls_right_loop
.Lfls_right_tail:
  and     w2, w2, #3
  cbz     w2, .Lfls_right_done
.Lfls_right_tail_loop:
  ldr     w3, [x1], #4
  ldr     w4, [x0]
  add     w4, w4, w3
  str     w4, [x0], #4
  sub     w2, w2, #1
  cbnz    w2, .Lfls_right_tail_loop
.Lfls_right_done:
end;

procedure flac_wasted_bits_neon(dst_: PInt32; n_: LongWord; shift_: LongWord); assembler; nostackframe;
{ dst[i] <<= shift，shift 0..31，4-wide shl }
asm
  cbz     w1, .Lwb_done
  cbz     w2, .Lwb_done
  dup     v2.4s, w2
  lsr     w3, w1, #2
  cbz     w3, .Lwb_tail
.Lwb_loop:
  ld1     {v0.4s}, [x0]
  ushl    v0.4s, v0.4s, v2.4s
  st1     {v0.4s}, [x0], #16
  sub     w3, w3, #1
  cbnz    w3, .Lwb_loop
.Lwb_tail:
  and     w1, w1, #3
  cbz     w1, .Lwb_done
.Lwb_tail_loop:
  ldr     w3, [x0]
  lsl     w3, w3, w2
  str     w3, [x0], #4
  sub     w1, w1, #1
  cbnz    w1, .Lwb_tail_loop
.Lwb_done:
end;

procedure flac_mid_side_neon(mid_: PInt32; side_: PInt32; n_: LongWord); assembler; nostackframe;
{ 4-wide 向量 ld1 + sxtw/lsl/orr/add/sub/asr 标量展开，避免 sxtl/xtn。
  x0=mid  x1=side  w2=n。v0/v1 为输入块，v2/v3 为输出块经 umov/ins 组装。 }
asm
  cbz     w2, .Lmid_done
  lsr     w3, w2, #2
  cbz     w3, .Lmid_tail
.Lmid_loop:
  ld1     {v0.4s}, [x0]
  ld1     {v1.4s}, [x1]
  umov    w4, v0.s[0]
  umov    w5, v1.s[0]
  sxtw    x4, w4
  sxtw    x5, w5
  lsl     x4, x4, #1
  and     x6, x5, #1
  orr     x4, x4, x6
  add     x6, x4, x5
  sub     x7, x4, x5
  asr     x6, x6, #1
  asr     x7, x7, #1
  ins     v2.s[0], w6
  ins     v3.s[0], w7
  umov    w6, v0.s[1]
  umov    w7, v1.s[1]
  sxtw    x6, w6
  sxtw    x7, w7
  lsl     x6, x6, #1
  and     x8, x7, #1
  orr     x6, x6, x8
  add     x8, x6, x7
  sub     x9, x6, x7
  asr     x8, x8, #1
  asr     x9, x9, #1
  ins     v2.s[1], w8
  ins     v3.s[1], w9
  umov    w8, v0.s[2]
  umov    w9, v1.s[2]
  sxtw    x8, w8
  sxtw    x9, w9
  lsl     x8, x8, #1
  and     x10, x9, #1
  orr     x8, x8, x10
  add     x10, x8, x9
  sub     x11, x8, x9
  asr     x10, x10, #1
  asr     x11, x11, #1
  ins     v2.s[2], w10
  ins     v3.s[2], w11
  umov    w10, v0.s[3]
  umov    w11, v1.s[3]
  sxtw    x10, w10
  sxtw    x11, w11
  lsl     x10, x10, #1
  and     x12, x11, #1
  orr     x10, x10, x12
  add     x12, x10, x11
  sub     x13, x10, x11
  asr     x12, x12, #1
  asr     x13, x13, #1
  ins     v2.s[3], w12
  ins     v3.s[3], w13
  st1     {v2.4s}, [x0], #16
  st1     {v3.4s}, [x1], #16
  sub     w3, w3, #1
  cbnz    w3, .Lmid_loop
.Lmid_tail:
  and     w2, w2, #3
  cbz     w2, .Lmid_done
.Lmid_tail_loop:
  ldr     w3, [x0]
  ldr     w4, [x1]
  sxtw    x5, w3
  sxtw    x6, w4
  lsl     x5, x5, #1
  and     x7, x6, #1
  orr     x5, x5, x7
  add     x7, x5, x6
  sub     x8, x5, x6
  asr     x7, x7, #1
  asr     x8, x8, #1
  str     w7, [x0], #4
  str     w8, [x1], #4
  sub     w2, w2, #1
  cbnz    w2, .Lmid_tail_loop
.Lmid_done:
end;

procedure flac_lpc_restore_neon(out_: PInt32; coeff_: PInt32; order_: LongWord; shift_: LongWord; n_: LongWord); assembler; nostackframe;
{ x0=out  x1=coeff  w2=order  w3=shift  w4=n。外层 i=order..n-1，内层 dot 4-wide
  展开用 sxtw+mul+add 累加，末尾 asr x12,x12,x3 实现 Sar64 floor。AAPCS64
  仅用 v0-v7/x0-x17，nostackframe。 }
asm
  cmp     w4, w2
  b.ls    .Llpc_done
  mov     w5, w2
.Llpc_outer:
  cmp     w5, w4
  b.hs    .Llpc_done
  mov     x12, #0
  mov     w6, #0
  lsr     w7, w2, #2
  cbz     w7, .Llpc_j_tail
.Llpc_j_loop4:
  sub     w8, w5, w6
  sub     w8, w8, #1
  sxtw    x9, w8
  ldr     w10, [x0, x9, lsl #2]
  ldr     w11, [x1, x6, lsl #2]
  sxtw    x10, w10
  sxtw    x11, w11
  mul     x10, x10, x11
  add     x12, x12, x10
  sub     w9, w8, #1
  add     w11, w6, #1
  sxtw    x9, w9
  ldr     w10, [x0, x9, lsl #2]
  ldr     w11, [x1, x11, lsl #2]
  sxtw    x10, w10
  sxtw    x11, w11
  mul     x10, x10, x11
  add     x12, x12, x10
  sub     w9, w8, #2
  add     w11, w6, #2
  sxtw    x9, w9
  ldr     w10, [x0, x9, lsl #2]
  ldr     w11, [x1, x11, lsl #2]
  sxtw    x10, w10
  sxtw    x11, w11
  mul     x10, x10, x11
  add     x12, x12, x10
  sub     w9, w8, #3
  add     w11, w6, #3
  sxtw    x9, w9
  ldr     w10, [x0, x9, lsl #2]
  ldr     w11, [x1, x11, lsl #2]
  sxtw    x10, w10
  sxtw    x11, w11
  mul     x10, x10, x11
  add     x12, x12, x10
  add     w6, w6, #4
  sub     w7, w7, #1
  cbnz    w7, .Llpc_j_loop4
.Llpc_j_tail:
  and     w7, w2, #3
  cbz     w7, .Llpc_dot_done
.Llpc_j_tail_loop:
  sub     w8, w5, w6
  sub     w8, w8, #1
  sxtw    x9, w8
  ldr     w10, [x0, x9, lsl #2]
  ldr     w11, [x1, x6, lsl #2]
  sxtw    x10, w10
  sxtw    x11, w11
  mul     x10, x10, x11
  add     x12, x12, x10
  add     w6, w6, #1
  sub     w7, w7, #1
  cbnz    w7, .Llpc_j_tail_loop
.Llpc_dot_done:
  cbz     w3, .Llpc_no_shift
  asr     x12, x12, x3
.Llpc_no_shift:
  sxtw    x9, w5
  ldr     w10, [x0, x9, lsl #2]
  sxtw    x10, w10
  add     x12, x12, x10
  str     w12, [x0, x9, lsl #2]
  add     w5, w5, #1
  b       .Llpc_outer
.Llpc_done:
end;

{$endif cpuaarch64}
{$endif FLAC_SIMD}

end.
