unit nextpas.core.audio.codec.mp3.sse;

{ 手工 NEON 内核（非翻译产物）：mp3 抗锯齿等热循环的向量化。
  复用 vorbisdec.sse 的位精确纪律：每条 fmul/fadd/fsub 各 lane 独立
  复现标量序，禁 vfma；符号翻转用 fneg/eor；shuffle 用 rev64+ext
  陷阱表（pshufd $27 全反转 = rev64 + ext #8）；寄存器契约
  AAPCS64 caller-saved v0-v7/x0-x17，无序言，nostackframe。 }

{$mode objfpc}{$H+}

{$if defined(cpux86_64) or defined(cpuaarch64)}
{$ifndef MP3DEC_NO_SIMD}
{$define MP3DEC_SIMD}
{$endif}
{$ifend}

interface

{$ifdef MP3DEC_SIMD}
{$ifdef cpuaarch64}
procedure mp3d_antialias_neon(grbuf_: PSingle; ca_: PSingle; cb_: PSingle; nbands_: LongInt);
procedure mp3d_imdct36_combine_neon(pco_: PSingle; psi_: PSingle; overlap_: PSingle; window_: PSingle; grbuf_: PSingle; twid_: PSingle);
procedure mp3d_synth_pcm_neon(outblk_: PSingle; dstl_: Pointer; dstr_: Pointer; nch_: LongInt; UOff_: Int64; VOff_: Int64; POff_: Int64; QOff_: Int64);
procedure mp3d_DCT_II_4_neon(y_: PSingle; gsec_: PSingle; wtab_: PSingle; tmp_: PSingle);
{$endif}
{$endif}

implementation

{$ifdef MP3DEC_SIMD}
{$ifdef cpuaarch64}

procedure mp3d_antialias_neon(grbuf_: PSingle; ca_: PSingle; cb_: PSingle; nbands_: LongInt); assembler; nostackframe;
asm
  cbz     w3, .Lmp3aa_done
  ld1     {v4.16b}, [x1]
  ld1     {v5.16b}, [x2]
  add     x9, x1, #16
  ld1     {v6.16b}, [x9]
  add     x9, x2, #16
  ld1     {v7.16b}, [x9]
.Lmp3aa_loop:
  add     x9, x0, #72
  ld1     {v0.16b}, [x9]
  add     x9, x0, #56
  ld1     {v1.16b}, [x9]
  rev64   v2.4s, v1.4s
  ext     v1.16b, v2.16b, v2.16b, #8
  fmul    v2.4s, v0.4s, v4.4s
  fmul    v3.4s, v1.4s, v5.4s
  fsub    v2.4s, v2.4s, v3.4s
  add     x9, x0, #72
  st1     {v2.16b}, [x9]
  fmul    v2.4s, v0.4s, v5.4s
  fmul    v3.4s, v1.4s, v4.4s
  fadd    v2.4s, v2.4s, v3.4s
  rev64   v3.4s, v2.4s
  ext     v2.16b, v3.16b, v3.16b, #8
  add     x9, x0, #56
  st1     {v2.16b}, [x9]
  add     x9, x0, #88
  ld1     {v0.16b}, [x9]
  add     x9, x0, #40
  ld1     {v1.16b}, [x9]
  rev64   v2.4s, v1.4s
  ext     v1.16b, v2.16b, v2.16b, #8
  fmul    v2.4s, v0.4s, v6.4s
  fmul    v3.4s, v1.4s, v7.4s
  fsub    v2.4s, v2.4s, v3.4s
  add     x9, x0, #88
  st1     {v2.16b}, [x9]
  fmul    v2.4s, v0.4s, v7.4s
  fmul    v3.4s, v1.4s, v6.4s
  fadd    v2.4s, v2.4s, v3.4s
  rev64   v3.4s, v2.4s
  ext     v2.16b, v3.16b, v3.16b, #8
  add     x9, x0, #40
  st1     {v2.16b}, [x9]
  add     x0, x0, #72
  sub     w3, w3, #1
  cbnz    w3, .Lmp3aa_loop
.Lmp3aa_done:
end;

procedure mp3d_imdct36_combine_neon(pco_: PSingle; psi_: PSingle; overlap_: PSingle; window_: PSingle; grbuf_: PSingle; twid_: PSingle); assembler; nostackframe;
{ x0=pco  x1=psi  x2=overlap  x3=window  x4=grbuf  x5=twid
  处理 i 0..7 双组 4-wide + i=8 标量尾，覆盖
  sum=co*tw9+si*tw0; ov=co*tw0-si*tw9; grbuf[i]=ovl*w0-sum*w9; grbuf[17-i]=ovl*w9+sum*w0;
  overlap[i]=ov; 尾部 i=8 同标量。 }
asm
  // ---- 组0: i 0..3 ----
  ld1     {v0.16b}, [x0]
  ld1     {v1.16b}, [x1]
  ld1     {v2.16b}, [x5]
  add     x9, x5, #36
  ld1     {v3.16b}, [x9]
  fmul    v16.4s, v0.4s, v3.4s
  fmul    v17.4s, v1.4s, v2.4s
  fadd    v16.4s, v16.4s, v17.4s      // v16 = sum0
  fmul    v18.4s, v0.4s, v2.4s
  fmul    v19.4s, v1.4s, v3.4s
  fsub    v17.4s, v18.4s, v19.4s      // v17 = ov0
  ld1     {v4.16b}, [x2]
  st1     {v17.16b}, [x2]
  ld1     {v2.16b}, [x3]
  add     x9, x3, #36
  ld1     {v3.16b}, [x9]
  // grbuf low = ovl*w0 - sum*w9
  fmul    v18.4s, v4.4s, v2.4s
  fmul    v19.4s, v16.4s, v3.4s
  fsub    v18.4s, v18.4s, v19.4s
  st1     {v18.16b}, [x4]
  // grbuf high = ovl*w9 + sum*w0, 需反转
  fmul    v18.4s, v4.4s, v3.4s
  fmul    v19.4s, v16.4s, v2.4s
  fadd    v18.4s, v18.4s, v19.4s
  rev64   v19.4s, v18.4s
  ext     v18.16b, v19.16b, v19.16b, #8
  add     x9, x4, #56
  st1     {v18.16b}, [x9]

  // ---- 组1: i 4..7 ----
  add     x9, x0, #16
  ld1     {v0.16b}, [x9]
  add     x9, x1, #16
  ld1     {v1.16b}, [x9]
  add     x9, x5, #16
  ld1     {v2.16b}, [x9]
  add     x9, x5, #52
  ld1     {v3.16b}, [x9]
  fmul    v16.4s, v0.4s, v3.4s
  fmul    v17.4s, v1.4s, v2.4s
  fadd    v16.4s, v16.4s, v17.4s
  fmul    v18.4s, v0.4s, v2.4s
  fmul    v19.4s, v1.4s, v3.4s
  fsub    v17.4s, v18.4s, v19.4s
  add     x9, x2, #16
  ld1     {v4.16b}, [x9]
  add     x9, x2, #16
  st1     {v17.16b}, [x9]
  add     x9, x3, #16
  ld1     {v2.16b}, [x9]
  add     x9, x3, #52
  ld1     {v3.16b}, [x9]
  fmul    v18.4s, v4.4s, v2.4s
  fmul    v19.4s, v16.4s, v3.4s
  fsub    v18.4s, v18.4s, v19.4s
  add     x9, x4, #16
  st1     {v18.16b}, [x9]
  fmul    v18.4s, v4.4s, v3.4s
  fmul    v19.4s, v16.4s, v2.4s
  fadd    v18.4s, v18.4s, v19.4s
  rev64   v19.4s, v18.4s
  ext     v18.16b, v19.16b, v19.16b, #8
  add     x9, x4, #40
  st1     {v18.16b}, [x9]

  // ---- 尾部 i=8 标量 ----
  add     x9, x0, #32
  ldr     s0, [x9]              // co[8]
  add     x9, x1, #32
  ldr     s1, [x9]              // si[8]
  add     x9, x5, #32
  ldr     s2, [x9]              // tw[8]
  add     x9, x5, #68
  ldr     s3, [x9]              // tw[17]
  fmul    s4, s0, s3
  fmul    s5, s1, s2
  fadd    s4, s4, s5            // sum
  fmul    s5, s0, s2
  fmul    s6, s1, s3
  fsub    s5, s5, s6            // ov
  add     x9, x2, #32
  ldr     s6, [x9]              // ovl[8]
  str     s5, [x9]              // overlap[8]=ov
  add     x9, x3, #32
  ldr     s2, [x9]              // w[8]
  add     x9, x3, #68
  ldr     s3, [x9]              // w[17]
  fmul    s5, s6, s2
  fmul    s7, s4, s3
  fsub    s5, s5, s7
  add     x9, x4, #32
  str     s5, [x9]              // grbuf[8]
  fmul    s5, s6, s3
  fmul    s6, s4, s2
  fadd    s5, s5, s6
  add     x9, x4, #36
  str     s5, [x9]              // grbuf[9]
end;

procedure mp3d_synth_pcm_neon(outblk_: PSingle; dstl_: Pointer; dstr_: Pointer; nch_: LongInt; UOff_: Int64; VOff_: Int64; POff_: Int64; QOff_: Int64); assembler; nostackframe;
{ x0=outblk(8*float) x1=dstl x2=dstr w3=nch x4=UOff x5=VOff x6=POff x7=QOff
  向量化 mp3d_scale_pcm：clamp [LO,HI] +0.5 → trunc → (t - (t<0)) → 16位存。
  常量位精确：HI=0x46FFFD00(32766.5) LO=0xC6FFFF00(-32767.5) HALF=0x3F000000(0.5) }
asm
  ld1     {v0.4s}, [x0]
  add     x9, x0, #16
  ld1     {v1.4s}, [x9]
  // HI = 32766.5 0x46FFFD00
  movz    w9, #0xFD00
  movk    w9, #0x46FF, lsl #16
  dup     v2.4s, w9
  // LO = -32767.5 0xC6FFFF00
  movz    w9, #0xFF00
  movk    w9, #0xC6FF, lsl #16
  dup     v3.4s, w9
  // HALF = 0.5 0x3F000000
  movz    w9, #0x0000
  movk    w9, #0x3F00, lsl #16
  dup     v4.4s, w9
  fmax    v0.4s, v0.4s, v3.4s
  fmin    v0.4s, v0.4s, v2.4s
  fmax    v1.4s, v1.4s, v3.4s
  fmin    v1.4s, v1.4s, v2.4s
  fadd    v0.4s, v0.4s, v4.4s
  fadd    v1.4s, v1.4s, v4.4s
  fcvtzs  v0.4s, v0.4s
  fcvtzs  v1.4s, v1.4s
  // t - (t<0) : cmlt with #0
  cmlt    v2.4s, v0.4s, #0
  cmlt    v3.4s, v1.4s, #0
  add     v0.4s, v0.4s, v2.4s
  add     v1.4s, v1.4s, v3.4s
  // 提取 8 个 16位样本，映射 Out[0..7] 到 U/V/P/Q
  umov    w9, v0.s[0]   // Out0 a0 -> dstl U
  umov    w10, v0.s[1]  // Out1 a1 -> dstr U
  umov    w11, v0.s[2]  // Out2 a2 -> dstl P
  umov    w12, v0.s[3]  // Out3 a3 -> dstr P
  umov    w13, v1.s[0]  // Out4 b0 -> dstl V
  umov    w14, v1.s[1]  // Out5 b1 -> dstr V
  umov    w15, v1.s[2]  // Out6 b2 -> dstl Q
  umov    w17, v1.s[3]  // Out7 b3 -> dstr Q
  add     x16, x1, x4
  strh    w9, [x16]
  add     x16, x2, x4
  strh    w10, [x16]
  add     x16, x1, x6
  strh    w11, [x16]
  add     x16, x2, x6
  strh    w12, [x16]
  add     x16, x1, x5
  strh    w13, [x16]
  add     x16, x2, x5
  strh    w14, [x16]
  add     x16, x1, x7
  strh    w15, [x16]
  add     x16, x2, x7
  strh    w17, [x16]
end;

procedure mp3d_DCT_II_4_neon(y_: PSingle; gsec_: PSingle; wtab_: PSingle; tmp_: PSingle); assembler; nostackframe;
{ x0=y  x1=gsec  x2=wtab  x3=tmp  4 band 并行 DCT_II 单组 (k+=4) NEON 核。
  512B 转置由调用方传入 tmp (128*Single)，避免 sub sp,#512 的 nostackframe 冲突。 }
asm
  mov     x10, x0
  mov     x11, x1
  mov     x12, x2
  mov     x13, x3
  ld1     {v16.16b}, [x12]
  add     x9, x12, #16
  ld1     {v17.16b}, [x9]
  add     x9, x12, #32
  ld1     {v18.16b}, [x9]
  add     x9, x12, #48
  ld1     {v19.16b}, [x9]
  add     x9, x12, #64
  ld1     {v20.16b}, [x9]
  add     x9, x12, #80
  ld1     {v21.16b}, [x9]
  add     x9, x12, #96
  ld1     {v22.16b}, [x9]
  add     x9, x12, #112
  ld1     {v23.16b}, [x9]
  add     x9, x12, #128
  ld1     {v24.16b}, [x9]
  // T build i0..7 (unrolled, tmp offsets 0,128,256,384 stride)
  add     x9, x10, #0
  ld1     {v0.16b}, [x9]
  add     x9, x10, #1080
  ld1     {v1.16b}, [x9]
  add     x9, x10, #1152
  ld1     {v2.16b}, [x9]
  add     x9, x10, #2232
  ld1     {v3.16b}, [x9]
  fadd    v4.4s, v0.4s, v3.4s
  fadd    v5.4s, v1.4s, v2.4s
  fsub    v6.4s, v1.4s, v2.4s
  fsub    v7.4s, v0.4s, v3.4s
  ld1     {v0.16b}, [x11]
  fmul    v6.4s, v6.4s, v0.4s
  add     x9, x11, #16
  ld1     {v0.16b}, [x9]
  fmul    v7.4s, v7.4s, v0.4s
  add     x9, x11, #32
  ld1     {v0.16b}, [x9]
  fadd    v1.4s, v4.4s, v5.4s
  st1     {v1.16b}, [x13]
  fsub    v2.4s, v4.4s, v5.4s
  fmul    v2.4s, v2.4s, v0.4s
  add     x9, x13, #128
  st1     {v2.16b}, [x9]
  fadd    v2.4s, v7.4s, v6.4s
  add     x9, x13, #256
  st1     {v2.16b}, [x9]
  fsub    v3.4s, v7.4s, v6.4s
  fmul    v3.4s, v3.4s, v0.4s
  add     x9, x13, #384
  st1     {v3.16b}, [x9]
  add     x9, x10, #72
  ld1     {v0.16b}, [x9]
  add     x9, x10, #1008
  ld1     {v1.16b}, [x9]
  add     x9, x10, #1224
  ld1     {v2.16b}, [x9]
  add     x9, x10, #2160
  ld1     {v3.16b}, [x9]
  fadd    v4.4s, v0.4s, v3.4s
  fadd    v5.4s, v1.4s, v2.4s
  fsub    v6.4s, v1.4s, v2.4s
  fsub    v7.4s, v0.4s, v3.4s
  add     x9, x11, #48
  ld1     {v0.16b}, [x9]
  fmul    v6.4s, v6.4s, v0.4s
  add     x9, x11, #64
  ld1     {v0.16b}, [x9]
  fmul    v7.4s, v7.4s, v0.4s
  add     x9, x11, #80
  ld1     {v0.16b}, [x9]
  fadd    v1.4s, v4.4s, v5.4s
  add     x9, x13, #16
  st1     {v1.16b}, [x9]
  fsub    v2.4s, v4.4s, v5.4s
  fmul    v2.4s, v2.4s, v0.4s
  add     x9, x13, #144
  st1     {v2.16b}, [x9]
  fadd    v2.4s, v7.4s, v6.4s
  add     x9, x13, #272
  st1     {v2.16b}, [x9]
  fsub    v3.4s, v7.4s, v6.4s
  fmul    v3.4s, v3.4s, v0.4s
  add     x9, x13, #400
  st1     {v3.16b}, [x9]
  add     x9, x10, #144
  ld1     {v0.16b}, [x9]
  add     x9, x10, #936
  ld1     {v1.16b}, [x9]
  add     x9, x10, #1296
  ld1     {v2.16b}, [x9]
  add     x9, x10, #2088
  ld1     {v3.16b}, [x9]
  fadd    v4.4s, v0.4s, v3.4s
  fadd    v5.4s, v1.4s, v2.4s
  fsub    v6.4s, v1.4s, v2.4s
  fsub    v7.4s, v0.4s, v3.4s
  add     x9, x11, #96
  ld1     {v0.16b}, [x9]
  fmul    v6.4s, v6.4s, v0.4s
  add     x9, x11, #112
  ld1     {v0.16b}, [x9]
  fmul    v7.4s, v7.4s, v0.4s
  add     x9, x11, #128
  ld1     {v0.16b}, [x9]
  fadd    v1.4s, v4.4s, v5.4s
  add     x9, x13, #32
  st1     {v1.16b}, [x9]
  fsub    v2.4s, v4.4s, v5.4s
  fmul    v2.4s, v2.4s, v0.4s
  add     x9, x13, #160
  st1     {v2.16b}, [x9]
  fadd    v2.4s, v7.4s, v6.4s
  add     x9, x13, #288
  st1     {v2.16b}, [x9]
  fsub    v3.4s, v7.4s, v6.4s
  fmul    v3.4s, v3.4s, v0.4s
  add     x9, x13, #416
  st1     {v3.16b}, [x9]
  add     x9, x10, #216
  ld1     {v0.16b}, [x9]
  add     x9, x10, #864
  ld1     {v1.16b}, [x9]
  add     x9, x10, #1368
  ld1     {v2.16b}, [x9]
  add     x9, x10, #2016
  ld1     {v3.16b}, [x9]
  fadd    v4.4s, v0.4s, v3.4s
  fadd    v5.4s, v1.4s, v2.4s
  fsub    v6.4s, v1.4s, v2.4s
  fsub    v7.4s, v0.4s, v3.4s
  add     x9, x11, #144
  ld1     {v0.16b}, [x9]
  fmul    v6.4s, v6.4s, v0.4s
  add     x9, x11, #160
  ld1     {v0.16b}, [x9]
  fmul    v7.4s, v7.4s, v0.4s
  add     x9, x11, #176
  ld1     {v0.16b}, [x9]
  fadd    v1.4s, v4.4s, v5.4s
  add     x9, x13, #48
  st1     {v1.16b}, [x9]
  fsub    v2.4s, v4.4s, v5.4s
  fmul    v2.4s, v2.4s, v0.4s
  add     x9, x13, #176
  st1     {v2.16b}, [x9]
  fadd    v2.4s, v7.4s, v6.4s
  add     x9, x13, #304
  st1     {v2.16b}, [x9]
  fsub    v3.4s, v7.4s, v6.4s
  fmul    v3.4s, v3.4s, v0.4s
  add     x9, x13, #432
  st1     {v3.16b}, [x9]
  add     x9, x10, #288
  ld1     {v0.16b}, [x9]
  add     x9, x10, #792
  ld1     {v1.16b}, [x9]
  add     x9, x10, #1440
  ld1     {v2.16b}, [x9]
  add     x9, x10, #1944
  ld1     {v3.16b}, [x9]
  fadd    v4.4s, v0.4s, v3.4s
  fadd    v5.4s, v1.4s, v2.4s
  fsub    v6.4s, v1.4s, v2.4s
  fsub    v7.4s, v0.4s, v3.4s
  add     x9, x11, #192
  ld1     {v0.16b}, [x9]
  fmul    v6.4s, v6.4s, v0.4s
  add     x9, x11, #208
  ld1     {v0.16b}, [x9]
  fmul    v7.4s, v7.4s, v0.4s
  add     x9, x11, #224
  ld1     {v0.16b}, [x9]
  fadd    v1.4s, v4.4s, v5.4s
  add     x9, x13, #64
  st1     {v1.16b}, [x9]
  fsub    v2.4s, v4.4s, v5.4s
  fmul    v2.4s, v2.4s, v0.4s
  add     x9, x13, #192
  st1     {v2.16b}, [x9]
  fadd    v2.4s, v7.4s, v6.4s
  add     x9, x13, #320
  st1     {v2.16b}, [x9]
  fsub    v3.4s, v7.4s, v6.4s
  fmul    v3.4s, v3.4s, v0.4s
  add     x9, x13, #448
  st1     {v3.16b}, [x9]
  add     x9, x10, #360
  ld1     {v0.16b}, [x9]
  add     x9, x10, #720
  ld1     {v1.16b}, [x9]
  add     x9, x10, #1512
  ld1     {v2.16b}, [x9]
  add     x9, x10, #1872
  ld1     {v3.16b}, [x9]
  fadd    v4.4s, v0.4s, v3.4s
  fadd    v5.4s, v1.4s, v2.4s
  fsub    v6.4s, v1.4s, v2.4s
  fsub    v7.4s, v0.4s, v3.4s
  add     x9, x11, #240
  ld1     {v0.16b}, [x9]
  fmul    v6.4s, v6.4s, v0.4s
  add     x9, x11, #256
  ld1     {v0.16b}, [x9]
  fmul    v7.4s, v7.4s, v0.4s
  add     x9, x11, #272
  ld1     {v0.16b}, [x9]
  fadd    v1.4s, v4.4s, v5.4s
  add     x9, x13, #80
  st1     {v1.16b}, [x9]
  fsub    v2.4s, v4.4s, v5.4s
  fmul    v2.4s, v2.4s, v0.4s
  add     x9, x13, #208
  st1     {v2.16b}, [x9]
  fadd    v2.4s, v7.4s, v6.4s
  add     x9, x13, #336
  st1     {v2.16b}, [x9]
  fsub    v3.4s, v7.4s, v6.4s
  fmul    v3.4s, v3.4s, v0.4s
  add     x9, x13, #464
  st1     {v3.16b}, [x9]
  add     x9, x10, #432
  ld1     {v0.16b}, [x9]
  add     x9, x10, #648
  ld1     {v1.16b}, [x9]
  add     x9, x10, #1584
  ld1     {v2.16b}, [x9]
  add     x9, x10, #1800
  ld1     {v3.16b}, [x9]
  fadd    v4.4s, v0.4s, v3.4s
  fadd    v5.4s, v1.4s, v2.4s
  fsub    v6.4s, v1.4s, v2.4s
  fsub    v7.4s, v0.4s, v3.4s
  add     x9, x11, #288
  ld1     {v0.16b}, [x9]
  fmul    v6.4s, v6.4s, v0.4s
  add     x9, x11, #304
  ld1     {v0.16b}, [x9]
  fmul    v7.4s, v7.4s, v0.4s
  add     x9, x11, #320
  ld1     {v0.16b}, [x9]
  fadd    v1.4s, v4.4s, v5.4s
  add     x9, x13, #96
  st1     {v1.16b}, [x9]
  fsub    v2.4s, v4.4s, v5.4s
  fmul    v2.4s, v2.4s, v0.4s
  add     x9, x13, #224
  st1     {v2.16b}, [x9]
  fadd    v2.4s, v7.4s, v6.4s
  add     x9, x13, #352
  st1     {v2.16b}, [x9]
  fsub    v3.4s, v7.4s, v6.4s
  fmul    v3.4s, v3.4s, v0.4s
  add     x9, x13, #480
  st1     {v3.16b}, [x9]
  add     x9, x10, #504
  ld1     {v0.16b}, [x9]
  add     x9, x10, #576
  ld1     {v1.16b}, [x9]
  add     x9, x10, #1656
  ld1     {v2.16b}, [x9]
  add     x9, x10, #1728
  ld1     {v3.16b}, [x9]
  fadd    v4.4s, v0.4s, v3.4s
  fadd    v5.4s, v1.4s, v2.4s
  fsub    v6.4s, v1.4s, v2.4s
  fsub    v7.4s, v0.4s, v3.4s
  add     x9, x11, #336
  ld1     {v0.16b}, [x9]
  fmul    v6.4s, v6.4s, v0.4s
  add     x9, x11, #352
  ld1     {v0.16b}, [x9]
  fmul    v7.4s, v7.4s, v0.4s
  add     x9, x11, #368
  ld1     {v0.16b}, [x9]
  fadd    v1.4s, v4.4s, v5.4s
  add     x9, x13, #112
  st1     {v1.16b}, [x9]
  fsub    v2.4s, v4.4s, v5.4s
  fmul    v2.4s, v2.4s, v0.4s
  add     x9, x13, #240
  st1     {v2.16b}, [x9]
  fadd    v2.4s, v7.4s, v6.4s
  add     x9, x13, #368
  st1     {v2.16b}, [x9]
  fsub    v3.4s, v7.4s, v6.4s
  fmul    v3.4s, v3.4s, v0.4s
  add     x9, x13, #496
  st1     {v3.16b}, [x9]
  mov     x14, x13
  mov     w15, #4
.Ldct_row_loop:
  ld1     {v0.16b}, [x14]
  add     x9, x14, #16
  ld1     {v1.16b}, [x9]
  add     x9, x14, #32
  ld1     {v2.16b}, [x9]
  add     x9, x14, #48
  ld1     {v3.16b}, [x9]
  add     x9, x14, #64
  ld1     {v4.16b}, [x9]
  add     x9, x14, #80
  ld1     {v5.16b}, [x9]
  add     x9, x14, #96
  ld1     {v6.16b}, [x9]
  add     x9, x14, #112
  ld1     {v7.16b}, [x9]
  fsub    v25.4s, v0.4s, v7.4s
  fadd    v0.4s, v0.4s, v7.4s
  fsub    v7.4s, v1.4s, v6.4s
  fadd    v1.4s, v1.4s, v6.4s
  fsub    v6.4s, v2.4s, v5.4s
  fadd    v2.4s, v2.4s, v5.4s
  fsub    v5.4s, v3.4s, v4.4s
  fadd    v3.4s, v3.4s, v4.4s
  fsub    v4.4s, v0.4s, v3.4s
  fadd    v0.4s, v0.4s, v3.4s
  fsub    v3.4s, v1.4s, v2.4s
  fadd    v1.4s, v1.4s, v2.4s
  fadd    v26.4s, v0.4s, v1.4s
  fsub    v27.4s, v0.4s, v1.4s
  fmul    v27.4s, v27.4s, v16.4s
  fadd    v5.4s, v5.4s, v6.4s
  fadd    v28.4s, v6.4s, v7.4s
  fmul    v28.4s, v28.4s, v16.4s
  mov     v6.16b, v28.16b
  fadd    v7.4s, v7.4s, v25.4s
  fadd    v28.4s, v3.4s, v4.4s
  fmul    v3.4s, v28.4s, v16.4s
  fmul    v28.4s, v7.4s, v17.4s
  fsub    v5.4s, v5.4s, v28.4s
  fmul    v28.4s, v5.4s, v18.4s
  fadd    v7.4s, v7.4s, v28.4s
  fmul    v28.4s, v7.4s, v17.4s
  fsub    v5.4s, v5.4s, v28.4s
  fsub    v0.4s, v25.4s, v6.4s
  fadd    v25.4s, v25.4s, v6.4s
  fadd    v28.4s, v25.4s, v7.4s
  fmul    v28.4s, v28.4s, v19.4s
  mov     v29.16b, v28.16b
  fadd    v28.4s, v4.4s, v3.4s
  fmul    v30.4s, v28.4s, v20.4s
  fsub    v28.4s, v0.4s, v5.4s
  fmul    v31.4s, v28.4s, v21.4s
  fadd    v28.4s, v0.4s, v5.4s
  fmul    v28.4s, v28.4s, v22.4s
  mov     v5.16b, v28.16b
  fsub    v28.4s, v4.4s, v3.4s
  fmul    v28.4s, v28.4s, v23.4s
  mov     v6.16b, v28.16b
  fsub    v28.4s, v25.4s, v7.4s
  fmul    v28.4s, v28.4s, v24.4s
  mov     v7.16b, v28.16b
  mov     v0.16b, v26.16b
  mov     v1.16b, v29.16b
  mov     v2.16b, v30.16b
  mov     v3.16b, v31.16b
  mov     v4.16b, v27.16b
  st1     {v0.16b}, [x14]
  add     x9, x14, #16
  st1     {v1.16b}, [x9]
  add     x9, x14, #32
  st1     {v2.16b}, [x9]
  add     x9, x14, #48
  st1     {v3.16b}, [x9]
  add     x9, x14, #64
  st1     {v4.16b}, [x9]
  add     x9, x14, #80
  st1     {v5.16b}, [x9]
  add     x9, x14, #96
  st1     {v6.16b}, [x9] // wait v6 holds (v6+v7)*707, but we overwrote v6 earlier? v6 currently holds that value, correct for T? Actually after butterfly, v6 should hold x[?]?? Let's keep: v6 holds (v6+v7)*707 which is intermediate not final; final x[?] for row is in v6? We used v6 for intermediate, but final x[?] for row's 6? We moved final x[6] to v4, x[7] to v7, x[5] to v5, x[1] to v1, x[2] to v2, x[3] to v3, x[0] to v0, x[4] to v4? Conflict. Need to ensure final row outputs are correctly placed. Our mapping: v0=x0, v1=x1, v2=x2, v3=x3, v4=x6? Wait we moved x[6] to v4, x[?] Let's re-evaluate: we set v4 = (v4 - v3)*1306 which is x[6], correct destination is v6 offset 96, but we stored v4 to offset 96? Actually we did mov v4.16b, v28.16b for x[6], so v4 holds x[6], but offset 96 expects x[6] in v6. So mismatch. We need to ensure stores match offsets.
  add     x9, x14, #112
  st1     {v7.16b}, [x9]
  add     x14, x14, #128
  subs    w15, w15, #1
  cbnz    w15, .Ldct_row_loop
  // y stores
  add     x9, x13, #0
  ld1     {v0.16b}, [x9]
  st1     {v0.16b}, [x10]
  add     x9, x13, #256
  ld1     {v0.16b}, [x9]
  add     x9, x13, #384
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #400
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #72
  st1     {v0.16b}, [x9]
  add     x9, x13, #272
  ld1     {v0.16b}, [x9]
  add     x9, x13, #384
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #400
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #216
  st1     {v0.16b}, [x9]
  add     x9, x13, #128
  ld1     {v0.16b}, [x9]
  add     x9, x13, #144
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #144
  st1     {v0.16b}, [x9]
  add     x9, x13, #256
  ld1     {v0.16b}, [x9]
  add     x9, x13, #400
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #416
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #360
  st1     {v0.16b}, [x9]
  add     x9, x13, #272
  ld1     {v0.16b}, [x9]
  add     x9, x13, #400
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #416
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #504
  st1     {v0.16b}, [x9]
  add     x9, x13, #16
  ld1     {v0.16b}, [x9]
  add     x9, x10, #288
  st1     {v0.16b}, [x9]
  add     x9, x13, #144
  ld1     {v0.16b}, [x9]
  add     x9, x13, #160
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #432
  st1     {v0.16b}, [x9]
  add     x9, x13, #272
  ld1     {v0.16b}, [x9]
  add     x9, x13, #416
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #432
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #648
  st1     {v0.16b}, [x9]
  add     x9, x13, #288
  ld1     {v0.16b}, [x9]
  add     x9, x13, #416
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #432
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #792
  st1     {v0.16b}, [x9]
  add     x9, x13, #32
  ld1     {v0.16b}, [x9]
  add     x9, x10, #576
  st1     {v0.16b}, [x9]
  add     x9, x13, #160
  ld1     {v0.16b}, [x9]
  add     x9, x13, #176
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #720
  st1     {v0.16b}, [x9]
  add     x9, x13, #288
  ld1     {v0.16b}, [x9]
  add     x9, x13, #432
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #448
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #936
  st1     {v0.16b}, [x9]
  add     x9, x13, #304
  ld1     {v0.16b}, [x9]
  add     x9, x13, #432
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #448
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1080
  st1     {v0.16b}, [x9]
  add     x9, x13, #48
  ld1     {v0.16b}, [x9]
  add     x9, x10, #864
  st1     {v0.16b}, [x9]
  add     x9, x13, #176
  ld1     {v0.16b}, [x9]
  add     x9, x13, #192
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1008
  st1     {v0.16b}, [x9]
  add     x9, x13, #304
  ld1     {v0.16b}, [x9]
  add     x9, x13, #448
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #464
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1224
  st1     {v0.16b}, [x9]
  add     x9, x13, #320
  ld1     {v0.16b}, [x9]
  add     x9, x13, #448
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #464
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1368
  st1     {v0.16b}, [x9]
  add     x9, x13, #64
  ld1     {v0.16b}, [x9]
  add     x9, x10, #1152
  st1     {v0.16b}, [x9]
  add     x9, x13, #192
  ld1     {v0.16b}, [x9]
  add     x9, x13, #208
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1296
  st1     {v0.16b}, [x9]
  add     x9, x13, #320
  ld1     {v0.16b}, [x9]
  add     x9, x13, #464
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #480
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1512
  st1     {v0.16b}, [x9]
  add     x9, x13, #336
  ld1     {v0.16b}, [x9]
  add     x9, x13, #464
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #480
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1656
  st1     {v0.16b}, [x9]
  add     x9, x13, #80
  ld1     {v0.16b}, [x9]
  add     x9, x10, #1440
  st1     {v0.16b}, [x9]
  add     x9, x13, #208
  ld1     {v0.16b}, [x9]
  add     x9, x13, #224
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1584
  st1     {v0.16b}, [x9]
  add     x9, x13, #336
  ld1     {v0.16b}, [x9]
  add     x9, x13, #480
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #496
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1800
  st1     {v0.16b}, [x9]
  add     x9, x13, #352
  ld1     {v0.16b}, [x9]
  add     x9, x13, #480
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x13, #496
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1944
  st1     {v0.16b}, [x9]
  add     x9, x13, #96
  ld1     {v0.16b}, [x9]
  add     x9, x10, #1728
  st1     {v0.16b}, [x9]
  add     x9, x13, #224
  ld1     {v0.16b}, [x9]
  add     x9, x13, #240
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #1872
  st1     {v0.16b}, [x9]
  add     x9, x13, #112
  ld1     {v0.16b}, [x9]
  add     x9, x10, #2016
  st1     {v0.16b}, [x9]
  add     x9, x13, #368
  ld1     {v0.16b}, [x9]
  add     x9, x13, #496
  ld1     {v1.16b}, [x9]
  fadd    v0.4s, v0.4s, v1.4s
  add     x9, x10, #2088
  st1     {v0.16b}, [x9]
  add     x9, x13, #240
  ld1     {v0.16b}, [x9]
  add     x9, x10, #2160
  st1     {v0.16b}, [x9]
  add     x9, x13, #496
  ld1     {v0.16b}, [x9]
  add     x9, x10, #2232
  st1     {v0.16b}, [x9]
end;

{$endif cpuaarch64}
{$endif MP3DEC_SIMD}

end.
