unit nextpas.core.audio.codec.vorbis.sse;
{ 手工 SIMD 内核（非翻译产物）：vorbis 热点逐元素向量化。
  位精确原理：每条 mul/add/sub 的各 lane 独立复现标量的双乘一加/
  减 op 序，IEEE 754 逐位一致；全程禁止重结合与 FMA（ARM 侧禁
  vfma/vfms，只用 fmul+fadd/fsub）。符号翻转只施加于单个乘积或单次
  差值（等价改写减法为加负数，有限值恒精确），不施加于多顶和差结果。
  汇编一律单元级过程：FPC 嵌套过程带隐藏 parent-frame 首参，会整体挤占
  参数寄存器槽位。
  x86_64：SysV 前三参 RDI,RSI,RDX，第四参 LongInt 走 ECX、Int64 走
  RCX。Win64 序言搬移 RCX,RDX,R8,R9 且必须 push/pop 保护 RSI/RDI
  （MS x64 非易失，SysV 易失）。
  aarch64：AAPCS64 参数 x0-x3（LongInt 用 w3），只碰调用者保存寄存器
  （x0-x17、v0-v7 与 v16-v31），无序言无退出序列；洗牌用 UZP/ZIP/TRN/
  EXT/REV64 原生重排，掩码常量循环外 mov/dup/ins 构造一次。
  其余目标整单元为空。}
{$mode objfpc}{$H+}

{ 目标有 SIMD 实现时置位，供接口/调用方共用同一判定 }
{$if defined(cpux86_64) or defined(cpuaarch64)}
{$define VDEC_SIMD}
{$ifend}

interface

{$ifdef VDEC_SIMD}

{ K5：codebook_ddr_stereo pair 循环。pairs_ 为任意值，消费
  floor(pairs_/2)*2 对：
  o0_[k+t] += muls_[2t]，o1_[k+t] += muls_[2t+1]，t = 0..消费对数-1 }
procedure vdec_ddr_pair_add(o0_: PSingle; o1_: PSingle; muls_: PSingle; pairs_: LongInt);

{ K6 分段内核。参数语义与翻译体调用点一致；尾部一律标量回退，
  对任意迭代数保持正确 }
procedure vdec_mdct_fold1(buf2_: PSingle; buffer_: PSingle; aa_: PSingle; iters_: LongInt);
procedure vdec_mdct_fold2(buf2_: PSingle; buffer_: PSingle; aa_: PSingle; iters_: LongInt);
procedure vdec_mdct_step2(u_: PSingle; v_: PSingle; aastart_: PSingle; meta_: Int64);
{ meta_ 低 32 位 = astride（bfly_r）或 k0（bfly_s），高 32 位 = 迭代数 }
procedure vdec_mdct_bfly_r(ee0_: PSingle; ee2_: PSingle; a_: PSingle; meta_: Int64);
procedure vdec_mdct_bfly_s(ee0_: PSingle; ee2_: PSingle; a_: PSingle; meta_: Int64);
procedure vdec_mdct_ld654(z_: PSingle; a2_: PSingle; iters_: LongInt);
procedure vdec_mdct_step7(v_: PSingle; c_: PSingle; n2_: LongInt);
procedure vdec_mdct_step8(buffer_: PSingle; v_: PSingle; bstart_: PSingle; n2_: LongInt);

{$endif VDEC_SIMD}

implementation

{$ifdef cpux86_64}

const
  VDEC_SIGN_EVEN: array[0..3] of LongWord = ($80000000, 0, $80000000, 0);
  VDEC_SIGN_ODD: array[0..3] of LongWord = (0, $80000000, 0, $80000000);
  VDEC_SIGN_LANE2: array[0..3] of LongWord = (0, 0, $80000000, 0);
  VDEC_SIGN_HI: array[0..3] of LongWord = (0, 0, $80000000, $80000000);
  VDEC_SIGN_LO: array[0..3] of LongWord = (0, $80000000, $80000000, 0);
  VDEC_SIGN_ALL: array[0..3] of LongWord = ($80000000, $80000000, $80000000, $80000000);
  VDEC_KEEP_EVEN: array[0..3] of LongWord = ($FFFFFFFF, 0, $FFFFFFFF, 0);
  VDEC_KEEP_ODD: array[0..3] of LongWord = (0, $FFFFFFFF, 0, $FFFFFFFF);

{ ── K5 ─────────────────────────────────────────────────────────────── }

procedure vdec_ddr_pair_add(o0_: PSingle; o1_: PSingle; muls_: PSingle; pairs_: LongInt); assembler; nostackframe;
{ 每 4 对一块：movups×2 载入 muls，shufps $88/$DD 解交织偶/奇后各自
  addps 到 o0_/o1_ 的 16 字节；余 2-3 对走单个 8 float 半块（movq 只写
  低 8 字节）。消费 floor(pairs_/2)*2 对。Linux：RDI=o0_ RSI=o1_
  RDX=muls_ ECX=pairs_ }
asm
{$ifdef windows}
  { Win64 ABI：RSI/RDI 非易失，须保存；成对 push 保持栈对齐 }
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movq     %r8, %rdx
  movl     %r9d, %ecx
{$endif}
  testl    %ecx, %ecx
  je       .Ldp_done
  movslq   %ecx, %rax
.Ldp_blk4:
  cmpq     $4, %rax
  jb       .Ldp_half
  movups   (%rdx), %xmm0
  movups   16(%rdx), %xmm1
  movaps   %xmm0, %xmm2
  shufps   $0x88, %xmm1, %xmm0      { [m0,m2,m4,m6] → o0 加数 }
  shufps   $0xDD, %xmm1, %xmm2      { [m1,m3,m5,m7] → o1 加数 }
  movups   (%rdi), %xmm3
  addps    %xmm0, %xmm3
  movups   %xmm3, (%rdi)
  movups   (%rsi), %xmm4
  addps    %xmm2, %xmm4
  movups   %xmm4, (%rsi)
  addq     $16, %rdi
  addq     $16, %rsi
  addq     $32, %rdx
  subq     $4, %rax
  jnz      .Ldp_blk4
.Ldp_half:
  cmpq     $2, %rax                 { 余 2-3 对：单块 8 float 半块，只写低 8 字节 }
  jb       .Ldp_done
  movups   (%rdx), %xmm0
  movaps   %xmm0, %xmm1
  shufps   $0x88, %xmm1, %xmm0      { [m0,m2,m0,m2] }
  shufps   $0xDD, %xmm1, %xmm1      { [m1,m3,m1,m3] 自洗牌 }
  movups   (%rdi), %xmm3
  addps    %xmm0, %xmm3
  movq     %xmm3, (%rdi)
  movups   (%rsi), %xmm4
  addps    %xmm1, %xmm4
  movq     %xmm4, (%rsi)
  addq     $8, %rdi
  addq     $8, %rsi
  addq     $16, %rdx
  subq     $2, %rax
  jnz      .Ldp_half
.Ldp_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

{ ── step0 折叠循环 1 ───────────────────────────────────────────────── }

procedure vdec_mdct_fold1(buf2_: PSingle; buffer_: PSingle; aa_: PSingle; iters_: LongInt); assembler; nostackframe;
{ 标量语义（第 j 迭代）：d[1] = e[0]*AA[0] - e[2]*AA[1]；
  d[0] = e[0]*AA[1] + e[2]*AA[0]。e = buffer_[4j]，AA = aa_[2j]，
  d 对自 buf2_[4*iters_-2] 逐迭代下落 2。4 迭代/块向量化，尾部标量。
  Linux：RDI=buf2_ RSI=buffer_ RDX=aa_ ECX=iters_ }
asm
{$ifdef windows}
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movq     %r8, %rdx
  movl     %r9d, %ecx
{$endif}
  movslq   %ecx, %r9
  shlq     $4, %r9                  { r9 = 16*iters 字节 }
  leaq     -32(%rdi,%r9), %r11      { r11 = &buf2 浮点下标 4*iters-8 }
  movl     %ecx, %eax
  andl     $-4, %eax                { eax = 向量化迭代数 }
  movl     %eax, %r8d
  sarl     $2, %r8d                 { r8d = 块数 }
  movslq   %eax, %rax
  testl    %r8d, %r8d
  jz       .Lf1_tail
  movl     %r8d, %r10d
.Lf1_blk:
  movups   (%rsi), %xmm0            { [E_j0[0..3]] }
  movups   16(%rsi), %xmm1          { [E_j1[0..3]] }
  movaps   %xmm0, %xmm2
  unpcklps %xmm1, %xmm0             { [E00,E10,E01,E11] }
  unpckhps %xmm1, %xmm2             { [E02,E12,E03,E13] }
  movups   32(%rsi), %xmm1
  movups   48(%rsi), %xmm3
  movaps   %xmm1, %xmm4
  unpcklps %xmm3, %xmm1             { [E20,E30,E21,E31] }
  unpckhps %xmm3, %xmm4             { [E22,E32,E23,E33] }
  movaps   %xmm0, %xmm5
  shufps   $0x44, %xmm1, %xmm5      { e0v = [E00,E10,E20,E30]，迭代序 lane }
  shufps   $0x44, %xmm4, %xmm2      { e2v = [E02,E12,E22,E32]，低半取 j0/j1 高交织 }
  movups   (%rdx), %xmm1            { Q0 = [AA_a0,AA_a1,AA_b0,AA_b1] }
  movups   16(%rdx), %xmm0          { Q1 }
  movaps   %xmm1, %xmm3
  shufps   $0x88, %xmm0, %xmm1      { A0v = AA 偶序，迭代序 }
  shufps   $0xDD, %xmm0, %xmm3      { A1v = AA 奇序 }
  movaps   %xmm5, %xmm0
  mulps    %xmm1, %xmm0             { P00 = e0v*A0v }
  mulps    %xmm3, %xmm5             { P01 = e0v*A1v }
  movaps   %xmm2, %xmm4
  mulps    %xmm3, %xmm4             { P21 = e2v*A1v }
  mulps    %xmm1, %xmm2             { P20 = e2v*A0v }
  subps    %xmm4, %xmm0             { d1v = e0*A0 − e2*A1（迭代序）}
  addps    %xmm2, %xmm5             { d0v = e0*A1 + e2*A0 }
  pshufd   $0x1B, %xmm0, %xmm0      { 反转至内存升序 }
  pshufd   $0x1B, %xmm5, %xmm5
  movaps   %xmm5, %xmm1
  unpcklps %xmm0, %xmm1
  movups   %xmm1, (%r11)
  movaps   %xmm5, %xmm1
  unpckhps %xmm0, %xmm1
  movups   %xmm1, 16(%r11)
  addq     $64, %rsi
  addq     $32, %rdx
  subq     $32, %r11
  decl     %r10d
  jnz      .Lf1_blk
.Lf1_tail:
  andl     $3, %ecx
  je       .Lf1_done
  addq     $24, %r11                { 尾部 d 对起点 = 块游标下移 6 float }
.Lf1_tloop:
  movss    (%rsi), %xmm0            { e[0] }
  movss    8(%rsi), %xmm1           { e[2] }
  movss    (%rdx), %xmm2            { AA[0] }
  movss    4(%rdx), %xmm3           { AA[1] }
  movaps   %xmm0, %xmm4
  mulss    %xmm2, %xmm4             { e0*AA0 }
  movaps   %xmm1, %xmm5
  mulss    %xmm3, %xmm5             { e2*AA1 }
  subss    %xmm5, %xmm4             { d[1] }
  mulss    %xmm3, %xmm0             { e0*AA1 }
  mulss    %xmm2, %xmm1             { e2*AA0 }
  addss    %xmm1, %xmm0             { d[0] }
  movss    %xmm4, 4(%r11)
  movss    %xmm0, (%r11)
  addq     $16, %rsi
  addq     $8, %rdx
  subq     $8, %r11
  decl     %ecx
  jnz      .Lf1_tloop
.Lf1_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

{ ── step0 折叠循环 2（取负分支） ───────────────────────────────────── }

procedure vdec_mdct_fold2(buf2_: PSingle; buffer_: PSingle; aa_: PSingle; iters_: LongInt); assembler; nostackframe;
{ 标量语义：d[1] = (-e[2])*AA[0] - (-e[0])*AA[1]；
  d[0] = (-e[2])*AA[1] + (-e[0])*AA[0]。e[2] = buffer_[4*iters_-1-4j]，
  e[0] = buffer_[4*iters_-3-4j]，AA = aa_[2j] 续接循环 1，d 对续接下落。
  输入先整体取负再走同型公式（符号位翻转精确）。尾部标量回退。
  Linux：RDI=buf2_ RSI=buffer_ RDX=aa_ ECX=iters_ }
asm
{$ifdef windows}
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movq     %r8, %rdx
  movl     %r9d, %ecx
{$endif}
  movq     %rsi, %r10               { r10 = buffer_ 基址（尾部窗口直取用）}
  movslq   %ecx, %rax
  shlq     $3, %rax                 { 8*it：fold2 只写 buf2 上半区 }
  leaq     -32(%rdi,%rax), %r11     { r11 = &buf2 浮点下标 2*iters-8 }
  movl     %ecx, %eax
  andl     $-4, %eax
  movl     %eax, %r8d
  sarl     $2, %r8d                 { r8d = 块数 }
  movslq   %ecx, %r9
  shlq     $4, %r9                  { r9 = 16*iters 字节（buffer 窗口）}
  leaq     -64(%rsi,%r9), %rsi      { rsi = 首块窗口低址（float 4it-16）}
  testl    %r8d, %r8d
  jz       .Lf2_tail
  movl     %r8d, %r9d
.Lf2_blk:
  movups   (%rsi), %xmm0
  movups   16(%rsi), %xmm1
  movaps   %xmm0, %xmm2
  unpckhps %xmm1, %xmm2             { [Q0_2,Q1_2,Q0_3,Q1_3] }
  unpcklps %xmm1, %xmm0             { [Q0_0,Q1_0,Q0_1,Q1_1] }
  movups   32(%rsi), %xmm1
  movups   48(%rsi), %xmm3
  movaps   %xmm1, %xmm4
  unpckhps %xmm3, %xmm4             { [Q2_2,Q3_2,Q2_3,Q3_3] }
  unpcklps %xmm3, %xmm1             { [Q2_0,Q3_0,Q2_1,Q3_1] }
  movaps   %xmm2, %xmm5
  shufps   $0xEE, %xmm4, %xmm5      { x2v，内存序 lane（lane0 ↔ 最高 j）}
  shufps   $0xEE, %xmm1, %xmm0      { x0v }
  xorps    VDEC_SIGN_ALL(%rip), %xmm5
  xorps    VDEC_SIGN_ALL(%rip), %xmm0
  movups   (%rdx), %xmm1            { Q0 = AA 升序 }
  movups   16(%rdx), %xmm2          { Q1 }
  movaps   %xmm1, %xmm3
  shufps   $0x88, %xmm2, %xmm1      { A0v' 迭代升序 }
  shufps   $0xDD, %xmm2, %xmm3      { A1v' }
  pshufd   $0x1B, %xmm1, %xmm1      { 反转 → 与 x 向量内存序 lane 对齐 }
  pshufd   $0x1B, %xmm3, %xmm3
  movaps   %xmm5, %xmm2
  mulps    %xmm1, %xmm2             { P20 = x2n*A0v }
  mulps    %xmm3, %xmm5             { P21 = x2n*A1v }
  movaps   %xmm0, %xmm4
  mulps    %xmm3, %xmm4             { P01 = x0n*A1v }
  mulps    %xmm1, %xmm0             { P00 = x0n*A0v }
  subps    %xmm4, %xmm2             { d1v = (−e2)AA0 − (−e0)AA1 }
  addps    %xmm0, %xmm5             { d0v = (−e2)AA1 + (−e0)AA0 }
  movaps   %xmm5, %xmm0
  unpcklps %xmm2, %xmm0
  movups   %xmm0, (%r11)
  movaps   %xmm5, %xmm0
  unpckhps %xmm2, %xmm0
  movups   %xmm0, 16(%r11)
  addq     $32, %rdx
  subq     $32, %r11
  subq     $64, %rsi                { 窗口随迭代下行 }
  decl     %r9d
  jnz      .Lf2_blk
.Lf2_tail:
  andl     $3, %ecx
  je       .Lf2_done
  addq     $24, %r11                { 尾部首对 = 块游标下移 6 float }
  movslq   %ecx, %rax               { 尾迭代数 tc = iters - v }
  shlq     $4, %rax                 { ×16 字节 }
  leaq     -12(%r10,%rax), %r10     { 首尾迭代 e[0] = float 4it-3-4v }
.Lf2_tloop:
  movss    (%r10), %xmm0            { e[0] }
  movss    8(%r10), %xmm1           { e[2] }
  movss    (%rdx), %xmm2            { AA[0] }
  movss    4(%rdx), %xmm3           { AA[1] }
  xorps    VDEC_SIGN_ALL(%rip), %xmm0
  xorps    VDEC_SIGN_ALL(%rip), %xmm1
  movaps   %xmm1, %xmm4
  mulss    %xmm2, %xmm4             { (-e2)*AA0 }
  movaps   %xmm0, %xmm5
  mulss    %xmm3, %xmm5             { (-e0)*AA1 }
  subss    %xmm5, %xmm4             { d[1] }
  mulss    %xmm3, %xmm1             { (-e2)*AA1 }
  mulss    %xmm2, %xmm0             { (-e0)*AA0 }
  addss    %xmm0, %xmm1             { d[0] }
  movss    %xmm4, 4(%r11)
  movss    %xmm1, (%r11)
  subq     $16, %r10
  addq     $8, %rdx
  subq     $8, %r11
  decl     %ecx
  jnz      .Lf2_tloop
.Lf2_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

{ ── step2 ──────────────────────────────────────────────────────────── }

procedure vdec_mdct_step2(u_: PSingle; v_: PSingle; aastart_: PSingle; meta_: Int64); assembler; nostackframe;
{ 标量语义（每体 4 输出，AA 体间降 8）：
  d0[k]=e0[k]+e1[k]；
  d1[0]=v40*AA[4]+v41*AA[5]；d1[1]=v41*AA[4]-v40*AA[5]；
  d1[2]=v42*AA[0]+v43*AA[1]；d1[3]=v43*AA[0]-v42*AA[1]。
  其中 vk0=e0[k]-e1[k]，vk1=e0[k+1]-e1[k+1]。d0=&u_[n4] 升，d1=&u_[0] 升。
  meta 低 32 位 = n4（e0/d0 起始 float 偏移），高 32 位 = 迭代数；
  生产中 n4=n2 shr 2、迭代数=n2 shr 3，二者相差 2 倍，勿混用。
  Linux：RDI=u_ RSI=v_ RDX=aastart_ RCX=meta_ }
asm
{$ifdef windows}
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movq     %r8, %rdx
  movq     %r9, %rcx
{$endif}
  movq     %rcx, %rax               { rax = meta }
  movl     %eax, %r8d
  movslq   %r8d, %r10               { r10 暂存 sext(n4) }
  leaq     (%rsi,%r10,4), %r8       { r8 = e0 = v+n4 }
  movq     %rsi, %r9                { r9 = e1 = v }
  leaq     (%rdi,%r10,4), %r10      { r10 = d0 = u+n4 }
  movq     %rdi, %r11               { r11 = d1 = u }
  shrq     $32, %rax                { 高 32 位 = 迭代数 }
  movl     %eax, %ecx               { ecx = 迭代数（尾部 andl $3 复用）}
  movl     %ecx, %eax
  sarl     $2, %eax                 { 组数（4 体/组）}
  movslq   %eax, %rax
  testq    %rax, %rax
  jz       .Ls2_tail
.Ls2_grp:
  movl     $4, %esi                 { 组内体计数（rsi 已腾空）}
.Ls2_in:
  movups   (%r8), %xmm0             { e0v }
  movups   (%r9), %xmm1             { e1v }
  movaps   %xmm0, %xmm2
  addps    %xmm1, %xmm2             { d0v }
  movups   %xmm2, (%r10)
  subps    %xmm1, %xmm0             { dv = [v40,v41,v42,v43] }
  movaps   %xmm0, %xmm3
  pshufd   $0xB1, %xmm3, %xmm3      { dvs }
  movups   16(%rdx), %xmm4          { Y = AA[4..7] }
  movups   (%rdx), %xmm5            { Z = AA[0..3] }
  shufps   $0x44, %xmm5, %xmm4      { X = [AA4,AA5,AA0,AA1] }
  mulps    %xmm4, %xmm0             { T = dv*X = [v40*AA4,v41*AA5,v42*AA0,v43*AA1] }
  mulps    %xmm4, %xmm3             { U = dvs*X = [v41*AA4,v40*AA5,v43*AA0,v42*AA1] }
  movaps   %xmm0, %xmm2
  pshufd   $0xB1, %xmm2, %xmm2
  addps    %xmm2, %xmm0             { 每 lane 对内和 = d1 偶位值 }
  movaps   %xmm3, %xmm2
  pshufd   $0xB1, %xmm2, %xmm2
  subps    %xmm2, %xmm3             { 每 lane 对内差 = d1 奇位值 }
  andps    VDEC_KEEP_EVEN(%rip), %xmm0
  andps    VDEC_KEEP_EVEN(%rip), %xmm3
  pshufd   $0xD8, %xmm0, %xmm0      { S' = [S0,S2,·,·] 偶位前移 }
  pshufd   $0xD8, %xmm3, %xmm3      { D' }
  movaps   %xmm0, %xmm2
  unpcklps %xmm3, %xmm2             { [S0,D0,S2,D2] = [d1_0..d1_3] }
  movups   %xmm2, (%r11)
  addq     $16, %r8
  addq     $16, %r9
  addq     $16, %r10
  addq     $16, %r11
  subq     $32, %rdx
  decl     %esi
  jnz      .Ls2_in
  decq     %rax
  jnz      .Ls2_grp
.Ls2_tail:
  andl     $3, %ecx
  je       .Ls2_done
.Ls2_tloop:
  movss    0(%r8), %xmm0
  movss    4(%r8), %xmm1
  movss    0(%r9), %xmm2
  movss    4(%r9), %xmm3
  movaps   %xmm0, %xmm4
  subss    %xmm2, %xmm4             { v40 }
  movaps   %xmm1, %xmm5
  subss    %xmm3, %xmm5             { v41 }
  addss    %xmm2, %xmm0
  addss    %xmm3, %xmm1
  movss    %xmm0, (%r10)
  movss    %xmm1, 4(%r10)
  movss    16(%rdx), %xmm0          { AA[4] }
  movss    20(%rdx), %xmm1          { AA[5] }
  movaps   %xmm5, %xmm2
  mulss    %xmm0, %xmm2             { v41*AA4 }
  movaps   %xmm4, %xmm3
  mulss    %xmm1, %xmm3             { v40*AA5 }
  mulss    %xmm0, %xmm4             { v40*AA4 }
  mulss    %xmm1, %xmm5             { v41*AA5 }
  addss    %xmm5, %xmm4             { d1[0] = v40*AA4 + v41*AA5 }
  subss    %xmm3, %xmm2             { d1[1] = v41*AA4 − v40*AA5 }
  movss    %xmm4, (%r11)
  movss    %xmm2, 4(%r11)
  movss    8(%r8), %xmm0
  movss    12(%r8), %xmm1
  movss    8(%r9), %xmm2
  movss    12(%r9), %xmm3
  movaps   %xmm0, %xmm4
  subss    %xmm2, %xmm4             { v42 }
  movaps   %xmm1, %xmm5
  subss    %xmm3, %xmm5             { v43 }
  addss    %xmm2, %xmm0
  addss    %xmm3, %xmm1
  movss    %xmm0, 8(%r10)
  movss    %xmm1, 12(%r10)
  movss    (%rdx), %xmm0            { AA[0] }
  movss    4(%rdx), %xmm1           { AA[1] }
  movaps   %xmm5, %xmm2
  mulss    %xmm0, %xmm2             { v43*AA0 }
  movaps   %xmm4, %xmm3
  mulss    %xmm1, %xmm3             { v42*AA1 }
  mulss    %xmm0, %xmm4             { v42*AA0 }
  mulss    %xmm1, %xmm5             { v43*AA1 }
  addss    %xmm5, %xmm4             { d1[2] = v42*AA0 + v43*AA1 }
  subss    %xmm3, %xmm2             { d1[3] = v43*AA0 − v42*AA1 }
  movss    %xmm4, 8(%r11)
  movss    %xmm2, 12(%r11)
  addq     $16, %r8
  addq     $16, %r9
  addq     $16, %r10
  addq     $16, %r11
  subq     $32, %rdx
  decl     %ecx
  jnz      .Ls2_tloop
.Ls2_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

{ ── step3 蝶形（iter0 / r_loop 共用，astride 可变） ────────────────── }

procedure vdec_mdct_bfly_r(ee0_: PSingle; ee2_: PSingle; a_: PSingle; meta_: Int64); assembler; nostackframe;
{ 每外层迭代 4 蝶形（ee[-7..0]），第 k 蝶形用 A[stride*k]、A[stride*k+1]，
  完后 ee0_/ee2_ 各降 8、a_ 升 4*stride。复数乘核：偶 lane = y 角色，
  奇 lane = x 角色，out = [oL,oH] 经 $D8 双重洗牌归位。尾部无（调用方
  保证 iters 为 lim shr 2）。Linux：RDI=ee0_ RSI=ee2_ RDX=a_
  RCX=meta_ }
asm
{$ifdef windows}
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movq     %r8, %rdx
  movq     %r9, %rcx
{$endif}
  movq     %rcx, %r9
  shrq     $32, %r9                 { r9 = 迭代数 }
  movl     %ecx, %r10d
  movslq   %r10d, %r10              { r10 = stride（float 数）}
  shlq     $2, %r10                 { r10 = stride 字节数 }
  testq    %r9, %r9
  je       .Lbr_done
.Lbr_iter:
  { 块 B：窗口 ee[-3..0]，对 (k-3,k-2)=蝶1 tw A[s]，(k-1,k0)=蝶0 tw A[0] }
  leaq     (%rdx,%r10), %rax
  movups   (%rax), %xmm2
  movups   (%rdx), %xmm3
  movaps   %xmm2, %xmm4
  shufps   $0x44, %xmm3, %xmm4      { T = TB = [A_s0,A_s1,A0,A1] }
  pshufd   $0xB1, %xmm4, %xmm5      { Ts = 对内交换 }
  movups   -12(%rdi), %xmm0
  movups   -12(%rsi), %xmm1
  movaps   %xmm0, %xmm2
  addps    %xmm1, %xmm2
  movups   %xmm2, -12(%rdi)
  subps    %xmm1, %xmm0             { dif }
  movaps   %xmm0, %xmm1
  pshufd   $0xB1, %xmm1, %xmm1      { dvs }
  movaps   %xmm1, %xmm2
  mulps    %xmm4, %xmm2             { M3 = dvs*T }
  mulps    %xmm4, %xmm0             { M1 = dif*T }
  mulps    %xmm5, %xmm1             { M2 = dvs*Ts }
  addps    %xmm1, %xmm0             { PL 双 lane = oL }
  xorps    VDEC_SIGN_ODD(%rip), %xmm2
  movaps   %xmm2, %xmm1
  pshufd   $0xB1, %xmm1, %xmm1
  addps    %xmm1, %xmm2             { PH 双 lane = oH }
  shufps   $0xD8, %xmm2, %xmm0
  pshufd   $0xD8, %xmm0, %xmm0      { [oL0,oH0,oL',oH'] 内存序 }
  movups   %xmm0, -12(%rsi)
  { 块 A：窗口 ee[-7..-4]，对 (k-7,k-6)=蝶3 tw A[3s]，(k-5,k-4)=蝶2 tw A[2s] }
  leaq     (%rdx,%r10), %rax
  leaq     (%rax,%r10,2), %rax
  movups   (%rax), %xmm2
  leaq     (%rdx,%r10,2), %rax
  movups   (%rax), %xmm3
  movaps   %xmm2, %xmm4
  shufps   $0x44, %xmm3, %xmm4      { T = TA = [A_3s0,A_3s1,A_2s0,A_2s1] }
  pshufd   $0xB1, %xmm4, %xmm5
  movups   -28(%rdi), %xmm0
  movups   -28(%rsi), %xmm1
  movaps   %xmm0, %xmm2
  addps    %xmm1, %xmm2
  movups   %xmm2, -28(%rdi)
  subps    %xmm1, %xmm0
  movaps   %xmm0, %xmm1
  pshufd   $0xB1, %xmm1, %xmm1
  movaps   %xmm1, %xmm2
  mulps    %xmm4, %xmm2
  mulps    %xmm4, %xmm0
  mulps    %xmm5, %xmm1
  addps    %xmm1, %xmm0
  xorps    VDEC_SIGN_ODD(%rip), %xmm2
  movaps   %xmm2, %xmm1
  pshufd   $0xB1, %xmm1, %xmm1
  addps    %xmm1, %xmm2
  shufps   $0xD8, %xmm2, %xmm0
  pshufd   $0xD8, %xmm0, %xmm0
  movups   %xmm0, -28(%rsi)
  leaq     (%rdx,%r10,4), %rdx      { A += 4*stride }
  subq     $32, %rdi
  subq     $32, %rsi
  decl     %r9d
  jnz      .Lbr_iter
.Lbr_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

{ ── step3 蝶形（s_loop，twiddle 固定广播） ─────────────────────────── }

procedure vdec_mdct_bfly_s(ee0_: PSingle; ee2_: PSingle; a_: PSingle; meta_: Int64); assembler; nostackframe;
{ 同 bfly_r 但 twiddle 基址固定（生产调用里 a_ 随外层 r 迭代由调用方
  推进），蝶形间距 a_off 独立于指针步进 k0。meta_ 打包：
    bit  0-15 = k0（ee0_/ee2_ 每 float 步进）
    bit 16-31 = a_off（相邻蝶形的 A 下标间距）
    bit 32-63 = 迭代数
  块 B：对 (-3,-2) tw A[a_off]，(-1,0) tw A[0]；
  块 A：对 (-7,-6) tw A[3a_off]，(-5,-4) tw A[2a_off]。
  Linux：RDI=ee0_ RSI=ee2_ RDX=a_ RCX=meta_ }
asm
{$ifdef windows}
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movq     %r8, %rdx
  movq     %r9, %rcx
{$endif}
  movq     %rcx, %r9
  shrq     $32, %r9                 { r9 = 迭代数 }
  movzwl   %cx, %r10d
  movslq   %r10d, %r10
  shlq     $2, %r10                 { r10 = 4*k0 字节（步进）}
  movl     %ecx, %r8d
  shrl     $16, %r8d
  movslq   %r8d, %r8
  shlq     $2, %r8                  { r8 = 4*a_off 字节（twiddle 间距）}
  testq    %r9, %r9
  je       .Lbs_done
.Lbs_iter:
  leaq     (%rdx,%r8), %rax
  movups   (%rax), %xmm2            { [A_a..A_a+3] }
  movups   (%rdx), %xmm3            { [A0..A3] }
  movaps   %xmm2, %xmm4
  shufps   $0x44, %xmm3, %xmm4      { T = [A_a0,A_a1,A0,A1] }
  pshufd   $0xB1, %xmm4, %xmm5      { Ts }
  movups   -12(%rdi), %xmm0
  movups   -12(%rsi), %xmm1
  movaps   %xmm0, %xmm2
  addps    %xmm1, %xmm2
  movups   %xmm2, -12(%rdi)
  subps    %xmm1, %xmm0
  movaps   %xmm0, %xmm1
  pshufd   $0xB1, %xmm1, %xmm1      { dvs }
  movaps   %xmm1, %xmm2
  mulps    %xmm4, %xmm2             { M3 }
  mulps    %xmm4, %xmm0             { M1 }
  mulps    %xmm5, %xmm1             { M2 }
  addps    %xmm1, %xmm0
  xorps    VDEC_SIGN_ODD(%rip), %xmm2
  movaps   %xmm2, %xmm1
  pshufd   $0xB1, %xmm1, %xmm1
  addps    %xmm1, %xmm2
  shufps   $0xD8, %xmm2, %xmm0
  pshufd   $0xD8, %xmm0, %xmm0
  movups   %xmm0, -12(%rsi)
  leaq     (%rdx,%r8), %rax
  leaq     (%rax,%r8,2), %rax
  movups   (%rax), %xmm2            { [A_3a..] }
  leaq     (%rdx,%r8,2), %rax
  movups   (%rax), %xmm3            { [A_2a..] }
  movaps   %xmm2, %xmm4
  shufps   $0x44, %xmm3, %xmm4      { T = [A_3a0,A_3a1,A_2a0,A_2a1] }
  pshufd   $0xB1, %xmm4, %xmm5
  movups   -28(%rdi), %xmm0
  movups   -28(%rsi), %xmm1
  movaps   %xmm0, %xmm2
  addps    %xmm1, %xmm2
  movups   %xmm2, -28(%rdi)
  subps    %xmm1, %xmm0
  movaps   %xmm0, %xmm1
  pshufd   $0xB1, %xmm1, %xmm1
  movaps   %xmm1, %xmm2
  mulps    %xmm4, %xmm2
  mulps    %xmm4, %xmm0
  mulps    %xmm5, %xmm1
  addps    %xmm1, %xmm0
  xorps    VDEC_SIGN_ODD(%rip), %xmm2
  movaps   %xmm2, %xmm1
  pshufd   $0xB1, %xmm1, %xmm1
  addps    %xmm1, %xmm2
  shufps   $0xD8, %xmm2, %xmm0
  pshufd   $0xD8, %xmm0, %xmm0
  movups   %xmm0, -28(%rsi)
  subq     %r10, %rdi
  subq     %r10, %rsi
  decl     %r9d
  jnz      .Lbs_iter
.Lbs_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

{ ── step3 合并迭代（ld654） ────────────────────────────────────────── }

procedure vdec_mdct_ld654(z_: PSingle; a2_: PSingle; iters_: LongInt); assembler; nostackframe;
{ 标量语义：组1 z[-3..0]+=? 与 z[-11..-8]，组2 z[-7..-4] 与
  z[-15..-12]（含 ±A2 缩放与符号交换），随后 iter_54(z)、iter_54(z-8)，
  z 每轮降 16 float。Linux：RDI=z_ RSI=a2_ RDX=iters_ }
asm
{$ifdef windows}
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movl     %r8d, %edx
{$endif}
  movss    (%rsi), %xmm0
  shufps   $0x00, %xmm0, %xmm0      { A2 广播 }
  movaps   %xmm0, %xmm1
  xorps    VDEC_SIGN_EVEN(%rip), %xmm1  { [−A2,A2,−A2,A2] }
  movl     %edx, %r9d
  testl    %r9d, %r9d
  je       .Lld_done
.Lld_iter:
  { 组1：X=[z-3..z0]，Y=[z-11..z-8]。xmm0=A2 广播、xmm1=±A2 全程常驻 }
  movups   -12(%rdi), %xmm2
  movups   -44(%rdi), %xmm3
  movaps   %xmm2, %xmm4
  addps    %xmm3, %xmm4
  movups   %xmm4, -12(%rdi)
  movaps   %xmm2, %xmm5
  subps    %xmm3, %xmm5             { Df = [l11,l00,k11,k00] }
  movaps   %xmm5, %xmm2             { Df 副本供合并 }
  pshufd   $0xB1, %xmm5, %xmm3
  xorps    VDEC_SIGN_EVEN(%rip), %xmm3
  addps    %xmm3, %xmm5             { [l11-l00, l00+l11, junk, junk] }
  mulps    %xmm0, %xmm5
  shufps   $0xE4, %xmm2, %xmm5      { [z-11,z-10,z-9,z-8] 新值 }
  movups   %xmm5, -44(%rdi)
  { 组2：X2=[z-7..z-4]，Y2=[z-15..z-12] }
  movups   -28(%rdi), %xmm2
  movups   -60(%rdi), %xmm3
  movaps   %xmm2, %xmm4
  addps    %xmm3, %xmm4
  movups   %xmm4, -28(%rdi)
  movaps   %xmm2, %xmm5
  subps    %xmm3, %xmm5             { D2 = [l11,l00,k11,k00] }
  movaps   %xmm5, %xmm2             { D2 副本供 kp }
  pshufd   $0xB1, %xmm5, %xmm3
  xorps    VDEC_SIGN_EVEN(%rip), %xmm3
  addps    %xmm3, %xmm5             { SD2 = [l11-l00, l00+l11, junk, junk] }
  pshufd   $0xE1, %xmm5, %xmm3      { [l00+l11, l11-l00, ·, ·] }
  mulps    %xmm1, %xmm3             { [(l00+l11)(-A2), (l11-l00)A2, ·, ·] }
  pshufd   $0xB8, %xmm2, %xmm2      { [dc,dc,k00,k11] }
  xorps    VDEC_SIGN_LANE2(%rip), %xmm2
  shufps   $0xE4, %xmm2, %xmm3      { [z-15,z-14,z-13,z-12] 新值 }
  movups   %xmm3, -60(%rdi)
  { iter54(z)：Lo=[z-7..z-4]，Hi=[z-3..z0] }
  movups   -28(%rdi), %xmm2
  movups   -12(%rdi), %xmm3
  pshufd   $0x1B, %xmm3, %xmm4      { X = [z0,z-1,z-2,z-3] }
  pshufd   $0x1B, %xmm2, %xmm2      { Lo 反转对齐配对 }
  movaps   %xmm4, %xmm5
  addps    %xmm2, %xmm5             { sum = [y0,y1,y2,y3] }
  subps    %xmm2, %xmm4             { dif = [k00,k11,k22,k33] }
  movaps   %xmm5, %xmm2
  movlhps  %xmm5, %xmm2             { [y0,y1,y0,y1] }
  movaps   %xmm5, %xmm3
  movhlps  %xmm5, %xmm3             { [y2,y3,y2,y3]，dst 高半须为 sum 高半 }
  xorps    VDEC_SIGN_HI(%rip), %xmm3
  addps    %xmm3, %xmm2             { [z0n,z-1n,z-2n,z-3n] }
  pshufd   $0x1B, %xmm2, %xmm2
  movups   %xmm2, -12(%rdi)
  movaps   %xmm4, %xmm2
  movlhps  %xmm4, %xmm2             { [k00,k11,k00,k11] }
  movaps   %xmm4, %xmm3
  movhlps  %xmm4, %xmm3             { [k22,k33,k22,k33] }
  pshufd   $0xB1, %xmm3, %xmm3      { [k33,k22,k33,k22] }
  xorps    VDEC_SIGN_LO(%rip), %xmm3
  addps    %xmm3, %xmm2             { R = [k00+k33,k11+k22,k00-k33,k11-k22] }
  pshufd   $0x1B, %xmm2, %xmm2      { [z-7n,z-6n,z-5n,z-4n] }
  movups   %xmm2, -28(%rdi)
  { iter54(z-8) }
  movups   -60(%rdi), %xmm2
  movups   -44(%rdi), %xmm3
  pshufd   $0x1B, %xmm3, %xmm4
  pshufd   $0x1B, %xmm2, %xmm2
  movaps   %xmm4, %xmm5
  addps    %xmm2, %xmm5
  subps    %xmm2, %xmm4
  movaps   %xmm5, %xmm2
  movlhps  %xmm5, %xmm2
  movaps   %xmm5, %xmm3
  movhlps  %xmm5, %xmm3
  xorps    VDEC_SIGN_HI(%rip), %xmm3
  addps    %xmm3, %xmm2
  pshufd   $0x1B, %xmm2, %xmm2
  movups   %xmm2, -44(%rdi)
  movaps   %xmm4, %xmm2
  movlhps  %xmm4, %xmm2
  movaps   %xmm4, %xmm3
  movhlps  %xmm4, %xmm3
  pshufd   $0xB1, %xmm3, %xmm3
  xorps    VDEC_SIGN_LO(%rip), %xmm3
  addps    %xmm3, %xmm2
  pshufd   $0x1B, %xmm2, %xmm2
  movups   %xmm2, -60(%rdi)
  subq     $64, %rdi
  decl     %r9d
  jnz      .Lld_iter
.Lld_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

{ ── step7（C twiddle） ─────────────────────────────────────────────── }

procedure vdec_mdct_step7(v_: PSingle; c_: PSingle; n2_: LongInt); assembler; nostackframe;
{ 标量语义（d=v 起，e=v+n2-4 起）：a02=d[k]-e[k+2]，a11=d[k+1]+e[k+3]；
  b0=C[k+1]*a02+C[k]*a11，b1=C[k+1]*a11-C[k]*a02；b2=d[k]+e[k+2]，
  b3=d[k+1]-e[k+3]；d[k]=b2+b0，d[k+1]=b3+b1，e[k+2]=b2-b0，
  e[k+3]=b1-b3。d 升 4、e 降 4、C 升 4。迭代数 =(n2+3) div 8。
  Linux：RDI=v_ RSI=c_ RDX=n2_ }
asm
{$ifdef windows}
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movl     %r8d, %edx
{$endif}
  movslq   %edx, %rax
  leaq     3(%rax), %rax
  shrq     $3, %rax                 { 迭代数 = (n2+3)>>3 }
  testq    %rax, %rax
  je       .Lv7_done
  movq     %rax, %rcx               { rcx = 迭代数 }
  movq     %rsi, %r8                { r8 = C 游标 }
  movslq   %edx, %rax
  shlq     $2, %rax
  leaq     (%rdi,%rax), %rsi
  subq     $16, %rsi                { rsi = e 起点 = v+4*n2-16 字节 }
.Lv7_iter:
  movups   (%rdi), %xmm0            { D }
  movups   (%rsi), %xmm1            { E }
  movups   (%r8), %xmm2             { Cv }
  movaps   %xmm1, %xmm3
  pshufd   $0x4E, %xmm1, %xmm3      { Erot = [e2,e3,e0,e1] }
  movaps   %xmm3, %xmm4
  xorps    VDEC_SIGN_EVEN(%rip), %xmm4
  addps    %xmm0, %xmm4             { a02v = [a02A,a11A,a02B,a11B] }
  xorps    VDEC_SIGN_ODD(%rip), %xmm3
  addps    %xmm0, %xmm3             { b2v = [b2A,b3A,b2B,b3B] }
  movaps   %xmm4, %xmm5
  pshufd   $0xB1, %xmm5, %xmm5      { a02s = [a11A,a02A,a11B,a02B]，先于 P 构建 }
  pshufd   $0xF5, %xmm2, %xmm1      { Cp = [C1,C1,C3,C3] }
  mulps    %xmm1, %xmm4             { P = a02v*Cp }
  pshufd   $0xA0, %xmm2, %xmm1      { Co = [C0,C0,C2,C2] }
  mulps    %xmm1, %xmm5             { Q = a02s*Co }
  xorps    VDEC_SIGN_ODD(%rip), %xmm5
  addps    %xmm5, %xmm4             { b0v = [b0A,b1A,b0B,b1B] }
  movaps   %xmm3, %xmm1
  addps    %xmm4, %xmm1             { Dout = b2v+b0v }
  movups   %xmm1, (%rdi)
  movaps   %xmm4, %xmm1
  subps    %xmm3, %xmm1             { U = b0v-b2v：奇位真差 b1-b3（零符号精确）}
  movaps   %xmm3, %xmm0
  subps    %xmm4, %xmm0             { T = b2v-b0v：偶位真差 b2-b0 }
  andps    VDEC_KEEP_EVEN(%rip), %xmm0
  andps    VDEC_KEEP_ODD(%rip), %xmm1
  orps     %xmm1, %xmm0             { [subA:e2',subA:e3',subB:e0',subB:e1'] }
  pshufd   $0x4E, %xmm0, %xmm0      { 窗口序 [e0,e1,e2,e3]：subB 对在前 }
  movups   %xmm0, (%rsi)
  addq     $16, %rdi
  subq     $16, %rsi
  addq     $16, %r8
  decl     %ecx
  jnz      .Lv7_iter
.Lv7_done:
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

{ ── step8（B kernel，散写已归并为连续 16B 存储） ────────────────────── }

procedure vdec_mdct_step8(buffer_: PSingle; v_: PSingle; bstart_: PSingle; n2_: LongInt); assembler; nostackframe;
{ Linux：RDI=buffer_ RSI=v_ RDX=bstart_ ECX=n2_ }
asm
{$ifdef windows}
  push     %rdi
  push     %rsi
  movq     %rcx, %rdi
  movq     %rdx, %rsi
  movq     %r8, %rdx
  movl     %r9d, %ecx
{$endif}
  movslq   %ecx, %rax
  leaq     (%rsi,%rax,4), %r8
  subq     $32, %r8                 { r8 = e = buf2+n2-8 }
  movq     %rdx, %r9                { r9 = B }
  leaq     (%rdi,%rax,4), %r10      { r10 = d2 = buffer+n2 }
  leaq     (%rdi,%rax,4), %r11
  subq     $16, %r11                { r11 = d1 = buffer+n2-4；d3 = d1+4*n2 }
  shlq     $2, %rax
  movq     %rax, %rsi               { rsi = 4*n2（d3 相对 d1 的常量偏移）}
  movl     %ecx, %eax
  shrl     $3, %eax
  subq     $16, %rsp                { PVc 跨块保存槽（无调用，对齐无碍）}
  testl    %eax, %eax
  je       .Ls8_done
  movl     %eax, %ecx
.Ls8_iter:
  movups   (%r8), %xmm0             { Ev 低址块 }
  movups   (%r9), %xmm1             { Bv 低址块 }
  { 每对偶：p奇=e0·B1−e1·B0（真减），p偶=−e0·B0−e1·B1（双操作数先取负再加） }
  movaps   %xmm1, %xmm2
  pshufd   $0xB1, %xmm2, %xmm2      { W = [B1,B0,B3,B2] }
  movaps   %xmm0, %xmm3
  mulps    %xmm1, %xmm3             { Dg = Ev*Bv 对角积 }
  movaps   %xmm0, %xmm4
  mulps    %xmm2, %xmm4             { An = Ev*W 反对角积 }
  movaps   %xmm3, %xmm5
  pshufd   $0xB1, %xmm5, %xmm5      { swap(Dg) }
  xorps    VDEC_SIGN_ALL(%rip), %xmm3
  xorps    VDEC_SIGN_ALL(%rip), %xmm5
  addps    %xmm5, %xmm3             { PN = (−Dg)+(−Ds) = [p0,p0,p2,p2] }
  movaps   %xmm4, %xmm5
  pshufd   $0xB1, %xmm5, %xmm5      { swap(An) }
  subps    %xmm5, %xmm4             { SN = An−As = [p1,−p1,p3,−p3] }
  andps    VDEC_KEEP_EVEN(%rip), %xmm4
  andps    VDEC_KEEP_ODD(%rip), %xmm3
  orps     %xmm3, %xmm4             { PVc = [p1',p0',p3',p2'] }
  movups   %xmm4, (%rsp)            { 存槽，腾出寄存器 }
  { 块 2（高址对）→ PVd，同构：对偶 (e4,e5)→(p0,p1)、(e6,e7)→(p2,p3) }
  movups   16(%r8), %xmm0
  movups   16(%r9), %xmm1
  movaps   %xmm1, %xmm2
  pshufd   $0xB1, %xmm2, %xmm2      { W }
  movaps   %xmm0, %xmm3
  mulps    %xmm1, %xmm3             { Dg }
  movaps   %xmm0, %xmm4
  mulps    %xmm2, %xmm4             { An }
  movaps   %xmm3, %xmm5
  pshufd   $0xB1, %xmm5, %xmm5
  xorps    VDEC_SIGN_ALL(%rip), %xmm3
  xorps    VDEC_SIGN_ALL(%rip), %xmm5
  addps    %xmm5, %xmm3             { PN }
  movaps   %xmm4, %xmm5
  pshufd   $0xB1, %xmm5, %xmm5
  subps    %xmm5, %xmm4             { SN }
  andps    VDEC_KEEP_EVEN(%rip), %xmm4
  andps    VDEC_KEEP_ODD(%rip), %xmm3
  orps     %xmm3, %xmm4             { PVd = [p1,p0,p3,p2] }
  { 四路输出组装与存储：PVc=低址块(L)、PVd=高址块(H)；
    e 降序处理，高址对落 d 输出低址槽；$02/$77 低半复用索引，
    movlhps 拼高低两半 }
  movups   (%rsp), %xmm5            { 取回 PVc=L }
  pshufd   $0x02, %xmm4, %xmm0      { H [p3,p1,·,·] }
  pshufd   $0x02, %xmm5, %xmm1      { L }
  movlhps  %xmm1, %xmm0             { D0v=[p3H,p1H,p3L,p1L] }
  pshufd   $0x77, %xmm4, %xmm2      { H' [p2,p0,·,·] }
  pshufd   $0x77, %xmm5, %xmm3      { L' }
  movlhps  %xmm3, %xmm2             { D2v=[p2H,p0H,p2L,p0L] }
  movaps   %xmm0, %xmm1
  xorps    VDEC_SIGN_ALL(%rip), %xmm1
  pshufd   $0x1B, %xmm1, %xmm3      { D1v = 反序取负（标量同为一元取负）}
  pshufd   $0x1B, %xmm2, %xmm5      { D3v = 反序 }
  movups   %xmm0, (%rdi)
  movups   %xmm2, (%r10)
  movups   %xmm3, (%r11)
  movups   %xmm5, (%r11,%rsi,1)
  addq     $16, %rdi
  addq     $16, %r10
  subq     $16, %r11
  subq     $32, %r8
  subq     $32, %r9
  decl     %ecx
  jnz      .Ls8_iter
.Ls8_done:
  addq     $16, %rsp
{$ifdef windows}
  pop      %rsi
  pop      %rdi
{$endif}
end;

{$endif cpux86_64}

{$ifdef cpuaarch64}

{ AAPCS64：参数 x0-x3（LongInt 用 w3，Int64 用 x3 整寄存器）。只用调用
  者保存寄存器（x0-x17、v0-v7、v16-v31），无序言。FPC 内部汇编器不认
  负偏移寻址与负写回，下行游标一律先算地址再访存。位精确约束与 x86
  相同：逐元素独立复现标量 op 序，只许 fmul+fadd/fsub，禁 vfma/vfms；
  一元取负（fneg/eor 符号掩码）处处精确。 }

// ── K5 ───────────────────────────────────────────────────────────────

procedure vdec_ddr_pair_add(o0_: PSingle; o1_: PSingle; muls_: PSingle; pairs_: LongInt); assembler; nostackframe;
{ 每 4 对一块：双寄存器载入后 UZP1/UZP2 解交织偶/奇各自 fadd 到 o0_/o1_
  的 16 字节；余 2-3 对走单块半段（st1 .2s 只写低 8 字节）。
  消费 floor(pairs_/2)*2 对。x0=o0_ x1=o1_ x2=muls_ w3=pairs_ }
asm
  cbz      w3, .Ldp_done
  sxtw     x4, w3
.Ldp_blk4:
  cmp      x4, #4
  b.lo     .Ldp_half
  ld1      {v0.16b, v1.16b}, [x2], #32
  uzp1     v2.4s, v0.4s, v1.4s       // [m0,m2,m4,m6] → o0 加数
  uzp2     v3.4s, v0.4s, v1.4s       // [m1,m3,m5,m7] → o1 加数
  ld1      {v4.16b}, [x0]
  fadd     v4.4s, v4.4s, v2.4s
  st1      {v4.16b}, [x0], #16
  ld1      {v5.16b}, [x1]
  fadd     v5.4s, v5.4s, v3.4s
  st1      {v5.16b}, [x1], #16
  sub      x4, x4, #4
  cbnz     x4, .Ldp_blk4
.Ldp_half:
  cmp      x4, #2                    // 余 2-3 对：单块半段，只写低 8 字节
  b.lo     .Ldp_done
  ld1      {v0.16b}, [x2], #16
  uzp1     v2.4s, v0.4s, v0.4s       // [m0,m2,m0,m2]
  uzp2     v3.4s, v0.4s, v0.4s       // [m1,m3,m1,m3]
  ld1      {v4.8b}, [x0]
  fadd     v4.2s, v4.2s, v2.2s
  st1      {v4.2s}, [x0], #8
  ld1      {v5.8b}, [x1]
  fadd     v5.2s, v5.2s, v3.2s
  st1      {v5.2s}, [x1], #8
  sub      x4, x4, #2
  cbnz     x4, .Ldp_half
.Ldp_done:
end;

// ── step0 折叠循环 1 ─────────────────────────────────────────────────

procedure vdec_mdct_fold1(buf2_: PSingle; buffer_: PSingle; aa_: PSingle; iters_: LongInt); assembler; nostackframe;
{ 标量语义（第 j 迭代）：d[1] = e[0]*AA[0] - e[2]*AA[1]；
  d[0] = e[0]*AA[1] + e[2]*AA[0]。e = buffer_[4j]，AA = aa_[2j]，
  d 对自 buf2_[4*iters_-2] 逐迭代下落 2。4 迭代/块向量化，尾部标量。
  x0=buf2_ x1=buffer_ x2=aa_ w3=iters_ }
asm
  sxtw     x9, w3
  add      x11, x0, x9, lsl #4
  sub      x11, x11, #32             // 块游标 = float[4it-8]
  bic      w8, w3, #3                // 向量化迭代数
  lsr      w5, w8, #2                // 块数
  cbz      w5, .Lf1_tail
.Lf1_blk:
  ld1      {v0.16b, v1.16b, v2.16b, v3.16b}, [x1], #64
  trn1     v16.4s, v0.4s, v1.4s      // [E00,E10,E02,E12]
  trn1     v17.4s, v2.4s, v3.4s      // [E20,E30,E22,E32]
  zip1     v18.2d, v16.2d, v17.2d    // e0v = [E00,E10,E20,E30] 迭代序
  zip2     v19.2d, v16.2d, v17.2d    // e2v = [E02,E12,E22,E32]
  ld1      {v20.16b, v21.16b}, [x2], #32
  uzp1     v22.4s, v20.4s, v21.4s    // A0v 迭代序
  uzp2     v23.4s, v20.4s, v21.4s    // A1v
  fmul     v24.4s, v18.4s, v22.4s    // P00 = e0*A0
  fmul     v25.4s, v18.4s, v23.4s    // P01 = e0*A1
  fmul     v26.4s, v19.4s, v23.4s    // P21 = e2*A1
  fmul     v27.4s, v19.4s, v22.4s    // P20 = e2*A0
  fsub     v28.4s, v24.4s, v26.4s    // d1v（迭代序）
  fadd     v29.4s, v25.4s, v27.4s    // d0v
  rev64    v28.4s, v28.4s
  ext      v28.16b, v28.16b, v28.16b, #8   // 反转至内存升序
  rev64    v29.4s, v29.4s
  ext      v29.16b, v29.16b, v29.16b, #8
  zip1     v30.4s, v29.4s, v28.4s    // [d0(j3),d1(j3),d0(j2),d1(j2)]
  zip2     v31.4s, v29.4s, v28.4s    // [d0(j1),d1(j1),d0(j0),d1(j0)]
  st1      {v30.16b, v31.16b}, [x11]
  sub      x11, x11, #32
  subs     w5, w5, #1
  b.ne     .Lf1_blk
.Lf1_tail:
  and      w6, w3, #3
  cbz      w6, .Lf1_done
  add      x11, x11, #24             // 尾部首对 = 块游标下移 6 float
.Lf1_tloop:
  ldr      s0, [x1]                  // e[0]
  ldr      s1, [x1, #8]              // e[2]
  ldr      s2, [x2]                  // AA[0]
  ldr      s3, [x2, #4]              // AA[1]
  fmul     s4, s0, s2
  fmul     s5, s1, s3
  fsub     s4, s4, s5                // d[1]
  fmul     s5, s0, s3
  fmul     s6, s1, s2
  fadd     s5, s5, s6                // d[0]
  str      s5, [x11]
  str      s4, [x11, #4]
  add      x1, x1, #16
  add      x2, x2, #8
  sub      x11, x11, #8
  subs     w6, w6, #1
  b.ne     .Lf1_tloop
.Lf1_done:
end;

// ── step0 折叠循环 2（取负分支） ─────────────────────────────────────

procedure vdec_mdct_fold2(buf2_: PSingle; buffer_: PSingle; aa_: PSingle; iters_: LongInt); assembler; nostackframe;
{ 标量语义：d[1] = (-e[2])*AA[0] - (-e[0])*AA[1]；
  d[0] = (-e[2])*AA[1] + (-e[0])*AA[0]。窗口下行，AA 续接升序，
  d 对续接下落。输入先整体取负再走同型公式（符号位翻转精确）。
  x 向量按内存序（lane0 ↔ 最高 j）构造，AA 反转对齐后免反转存储。
  x0=buf2_ x1=buffer_ x2=aa_ w3=iters_ }
asm
  sxtw     x9, w3
  add      x11, x0, x9, lsl #3
  sub      x11, x11, #32             // 块游标 = float[2it-8]
  add      x10, x1, x9, lsl #4
  sub      x10, x10, #64             // 首块窗口低址 = float[4it-16]
  bic      w8, w3, #3
  lsr      w5, w8, #2                // 块数
  cbz      w5, .Lf2_tail
.Lf2_blk:
  ld1      {v0.16b, v1.16b, v2.16b, v3.16b}, [x10]
  sub      x10, x10, #64             // 窗口随迭代下行
  trn2     v16.4s, v0.4s, v1.4s      // [w1,w5,w3,w7]
  trn2     v17.4s, v2.4s, v3.4s      // [w9,w13,w11,w15]
  zip1     v18.2d, v16.2d, v17.2d    // x0v 内存序 = [e0(j3),e0(j2),e0(j1),e0(j0)]
  zip2     v19.2d, v16.2d, v17.2d    // x2v 内存序
  fneg     v18.4s, v18.4s
  fneg     v19.4s, v19.4s
  ld1      {v20.16b, v21.16b}, [x2], #32
  uzp1     v22.4s, v20.4s, v21.4s    // A0v 升序
  uzp2     v23.4s, v20.4s, v21.4s    // A1v
  rev64    v22.4s, v22.4s
  ext      v22.16b, v22.16b, v22.16b, #8   // 反转 → 与 x 向量内存序对齐
  rev64    v23.4s, v23.4s
  ext      v23.16b, v23.16b, v23.16b, #8
  fmul     v24.4s, v19.4s, v22.4s    // P20 = x2n*A0v
  fmul     v25.4s, v19.4s, v23.4s    // P21 = x2n*A1v
  fmul     v26.4s, v18.4s, v23.4s    // P01 = x0n*A1v
  fmul     v27.4s, v18.4s, v22.4s    // P00 = x0n*A0v
  fsub     v28.4s, v24.4s, v26.4s    // d1v = (−e2)AA0 − (−e0)AA1
  fadd     v29.4s, v25.4s, v27.4s    // d0v = (−e2)AA1 + (−e0)AA0
  zip1     v30.4s, v29.4s, v28.4s    // 内存序已就绪，直接交织存储
  zip2     v31.4s, v29.4s, v28.4s
  st1      {v30.16b, v31.16b}, [x11]
  sub      x11, x11, #32
  subs     w5, w5, #1
  b.ne     .Lf2_blk
.Lf2_tail:
  and      w6, w3, #3
  cbz      w6, .Lf2_done
  add      x11, x11, #24             // 尾部首对 = 块游标下移 6 float
  add      x12, x10, #52             // 尾迭代 e[0] = 窗口低址 + 13 float
.Lf2_tloop:
  ldr      s0, [x12]                 // e[0]
  ldr      s1, [x12, #8]             // e[2]
  fneg     s0, s0                    // (−e0)
  fneg     s1, s1                    // (−e2)
  ldr      s2, [x2]                  // AA[0]
  ldr      s3, [x2, #4]              // AA[1]
  fmul     s4, s1, s2
  fmul     s5, s0, s3
  fsub     s4, s4, s5                // d[1]
  fmul     s5, s1, s3
  fmul     s6, s0, s2
  fadd     s5, s5, s6                // d[0]
  str      s5, [x11]
  str      s4, [x11, #4]
  sub      x12, x12, #16
  add      x2, x2, #8
  sub      x11, x11, #8
  subs     w6, w6, #1
  b.ne     .Lf2_tloop
.Lf2_done:
end;

// ── step2 ────────────────────────────────────────────────────────────

procedure vdec_mdct_step2(u_: PSingle; v_: PSingle; aastart_: PSingle; meta_: Int64); assembler; nostackframe;
{ 标量语义（每体 4 输出，AA 体间降 8）：
  d0[k]=e0[k]+e1[k]；
  d1[0]=v40*AA[4]+v41*AA[5]；d1[1]=v41*AA[4]-v40*AA[5]；
  d1[2]=v42*AA[0]+v43*AA[1]；d1[3]=v43*AA[0]-v42*AA[1]。
  其中 vk0=e0[k]-e1[k]。每体自含 4 宽，全部迭代走同一向量体，
  无组/尾之分。meta 低 32 位 = n4（e0/d0 起始 float 偏移，有符号扩展），
  高 32 位 = 迭代数。
  x0=u_ x1=v_ x2=aastart_ x3=meta_ }
asm
  mov      w8, w3
  sxtw     x8, w8                    // sext(n4)
  add      x4, x1, x8, lsl #2        // e0 = v+n4
  mov      x5, x1                    // e1 = v
  add      x6, x0, x8, lsl #2        // d0 = u+n4
  mov      x7, x0                    // d1 = u
  lsr      x9, x3, #32               // 迭代数
  cbz      x9, .Ls2_done
.Ls2_iter:
  ld1      {v0.16b}, [x4]
  ld1      {v1.16b}, [x5]
  fadd     v2.4s, v0.4s, v1.4s
  st1      {v2.16b}, [x6]            // d0
  fsub     v0.4s, v0.4s, v1.4s       // dif = [v40,v41,v42,v43]
  rev64    v1.4s, v0.4s              // dvs = $B1(dif)：rev64 单独即成对
                                     // 交换（[v41,v40,v43,v42]）；再加 ext
                                     // 会变成全反转，语义错误
  ld1      {v3.16b}, [x2]            // Z=[AA0..AA3]
  add      x8, x2, #16
  ld1      {v4.16b}, [x8]            // Y=[AA4..AA7]
  zip1     v5.2d, v4.2d, v3.2d       // X=[AA4,AA5,AA0,AA1]
  fmul     v6.4s, v0.4s, v5.4s       // T=[v40AA4,v41AA5,v42AA0,v43AA1]
  fmul     v7.4s, v1.4s, v5.4s       // U=[v41AA4,v40AA5,v43AA0,v42AA1]
  rev64    v0.4s, v6.4s              // 暂存走 v0/v1：v8–v15 低 64 位 callee-saved，
                                     // nostackframe 下无处保存，禁用（AAPCS64）
  fadd     v6.4s, v6.4s, v0.4s       // S=T+$B1(T)：偶 lane=d1_0/d1_2（对内和）
  rev64    v1.4s, v7.4s
  fsub     v7.4s, v7.4s, v1.4s       // D=U−$B1(U)：偶 lane=d1_1/d1_3（真减保序）
  uzp1     v0.4s, v6.4s, v6.4s       // [d1_0,d1_2,·,·]——必须从和寄存器 v6 取
  uzp1     v1.4s, v7.4s, v7.4s       // [d1_1,d1_3,·,·]——同 v7
  zip1     v0.4s, v0.4s, v1.4s       // [d1_0,d1_1,d1_2,d1_3]
  st1      {v0.16b}, [x7]
  add      x4, x4, #16
  add      x5, x5, #16
  add      x6, x6, #16
  add      x7, x7, #16
  sub      x2, x2, #32
  subs     x9, x9, #1
  b.ne     .Ls2_iter
.Ls2_done:
end;

// ── step3 蝶形（iter0 / r_loop 共用，astride 可变） ──────────────────

procedure vdec_mdct_bfly_r(ee0_: PSingle; ee2_: PSingle; a_: PSingle; meta_: Int64); assembler; nostackframe;
{ 每外层迭代 2 块×4 蝶形，第 k 蝶形用 A[stride*k]、A[stride*k+1]，
  完后 ee0_/ee2_ 各降 8 float、a_ 升 4*stride。复数乘核与 x86 版逐
  op 对应：rev64 ≙ pshufd $B1、eor 符号掩码 ≙ xorps、uzp1+zip1 ≙
  $D8 双重洗牌归位。尾部无（调用方保证 iters 为 lim shr 2）。
  meta 低 32 位 = stride（float 数），高 32 位 = 迭代数。
  x0=ee0_ x1=ee2_ x2=a_ x3=meta_ }
asm
  lsr      x9, x3, #32               // 迭代数
  sxtw     x8, w3
  lsl      x8, x8, #2                // stride 字节数
  cbz      x9, .Lbr_done
  movz     w6, #0x8000, lsl #16
  movi     v28.2d, #0
  ins      v28.s[1], w6              // SIGN_ODD = [0,-0,0,-0]
  ins      v28.s[3], w6
.Lbr_iter:
  // ── 块 B：窗口 ee[-3..0]（=基址 -12 字节），蝶(A_s)在前、蝶(A_0)在后
  sub      x4, x0, #12               // -12 字节（x86 -12(%rdi) 是字节！）
  sub      x5, x1, #12
  add      x6, x2, x8
  ld1      {v2.16b}, [x6]            // As
  ld1      {v3.16b}, [x2]            // A0
  zip1     v4.2d, v2.2d, v3.2d       // T=[A_s0,A_s1,A00,A01]
  rev64    v5.4s, v4.4s              // Ts = $B1(T)：rev64 单独即成对交换，
                                     // 加 ext 会成全反转（语义错误）
  ld1      {v0.16b}, [x4]
  ld1      {v1.16b}, [x5]
  fadd     v2.4s, v0.4s, v1.4s
  st1      {v2.16b}, [x4]            // sum 回存 ee0
  fsub     v0.4s, v0.4s, v1.4s       // dif
  mov      v1.16b, v0.16b
  rev64    v1.4s, v1.4s              // dvs = $B1(dif)，同上不加 ext
  fmul     v2.4s, v1.4s, v4.4s       // M3 = dvs*T
  fmul     v3.4s, v0.4s, v4.4s       // M1 = dif*T
  fmul     v0.4s, v1.4s, v5.4s       // M2 = dvs*Ts
  fadd     v3.4s, v3.4s, v0.4s       // PL（偶 lane 有效）
  eor      v2.16b, v2.16b, v28.16b   // M3 奇 lane 取负
  rev64    v0.4s, v2.4s              // PH = M3+$B1(M3)（rev64 单独）
  fadd     v2.4s, v2.4s, v0.4s       // 偶 lane 有效，对内复制
  uzp1     v3.4s, v3.4s, v3.4s       // [oL_A,oL_B,·,·]
  uzp1     v2.4s, v2.4s, v2.4s       // [oH_A,oH_B,·,·]
  zip1     v0.4s, v3.4s, v2.4s       // [oL_A,oH_A,oL_B,oH_B] 内存序
  st1      {v0.16b}, [x5]
  // ── 块 A：窗口 ee[-7..-4]（=基址 -28 字节），蝶(A_3s)在前、蝶(A_2s)在后
  sub      x4, x0, #28               // -28 字节
  sub      x5, x1, #28
  add      x6, x2, x8
  add      x6, x6, x8, lsl #1        // &A_3s
  ld1      {v2.16b}, [x6]
  add      x6, x2, x8, lsl #1        // &A_2s
  ld1      {v3.16b}, [x6]
  zip1     v4.2d, v2.2d, v3.2d       // T=[A_3s0,A_3s1,A_2s0,A_2s1]
  rev64    v5.4s, v4.4s              // Ts = $B1(T)：rev64 单独即成对交换，
                                     // 加 ext 会成全反转（语义错误）
  ld1      {v0.16b}, [x4]
  ld1      {v1.16b}, [x5]
  fadd     v2.4s, v0.4s, v1.4s
  st1      {v2.16b}, [x4]
  fsub     v0.4s, v0.4s, v1.4s
  mov      v1.16b, v0.16b
  rev64    v1.4s, v1.4s              // dvs = $B1(dif)，同上不加 ext
  fmul     v2.4s, v1.4s, v4.4s
  fmul     v3.4s, v0.4s, v4.4s
  fmul     v0.4s, v1.4s, v5.4s
  fadd     v3.4s, v3.4s, v0.4s
  eor      v2.16b, v2.16b, v28.16b
  rev64    v0.4s, v2.4s              // PH = M3+$B1(M3)（rev64 单独）
  fadd     v2.4s, v2.4s, v0.4s
  uzp1     v3.4s, v3.4s, v3.4s
  uzp1     v2.4s, v2.4s, v2.4s
  zip1     v0.4s, v3.4s, v2.4s
  st1      {v0.16b}, [x5]
  add      x2, x2, x8, lsl #2        // A += 4*stride
  sub      x0, x0, #32               // ee 各降 8 float
  sub      x1, x1, #32
  subs     x9, x9, #1
  b.ne     .Lbr_iter
.Lbr_done:
end;

// ── step3 蝶形（s_loop，twiddle 固定广播） ───────────────────────────

procedure vdec_mdct_bfly_s(ee0_: PSingle; ee2_: PSingle; a_: PSingle; meta_: Int64); assembler; nostackframe;
{ 同 bfly_r 但 twiddle 基址固定（生产调用里 a_ 随外层 r 迭代由调用方
  推进），蝶形间距 a_off 独立于指针步进 k0。meta 打包：
    bit  0-15 = k0（ee 每 float 步进）
    bit 16-31 = a_off（相邻蝶形的 A 下标间距）
    bit 32-63 = 迭代数
  块 B：对 (-3,-2) tw A[a_off]，(-1,0) tw A[0]；
  块 A：对 (-7,-6) tw A[3a_off]，(-5,-4) tw A[2a_off]。
  x0=ee0_ x1=ee2_ x2=a_ x3=meta_ }
asm
  lsr      x9, x3, #32               // 迭代数
  uxth     w10, w3
  lsl      x10, x10, #2              // k0 字节数（ee 步进）
  lsr      w11, w3, #16
  lsl      x11, x11, #2              // a_off 字节数（twiddle 间距）
  cbz      x9, .Lbs_done
  movz     w6, #0x8000, lsl #16
  movi     v28.2d, #0
  ins      v28.s[1], w6
  ins      v28.s[3], w6              // SIGN_ODD
.Lbs_iter:
  // ── 块 B
  sub      x4, x0, #12               // 块 B：ee[-3..0] = -12 字节
  sub      x5, x1, #12
  add      x6, x2, x11
  ld1      {v2.16b}, [x6]            // A_a
  ld1      {v3.16b}, [x2]            // A0
  zip1     v4.2d, v2.2d, v3.2d       // T=[A_a0,A_a1,A00,A01]
  rev64    v5.4s, v4.4s              // Ts = $B1(T)：rev64 单独即成对交换，
                                     // 加 ext 会成全反转（语义错误）
  ld1      {v0.16b}, [x4]
  ld1      {v1.16b}, [x5]
  fadd     v2.4s, v0.4s, v1.4s
  st1      {v2.16b}, [x4]
  fsub     v0.4s, v0.4s, v1.4s
  mov      v1.16b, v0.16b
  rev64    v1.4s, v1.4s              // dvs = $B1(dif)，同上不加 ext
  fmul     v2.4s, v1.4s, v4.4s
  fmul     v3.4s, v0.4s, v4.4s
  fmul     v0.4s, v1.4s, v5.4s
  fadd     v3.4s, v3.4s, v0.4s
  eor      v2.16b, v2.16b, v28.16b
  rev64    v0.4s, v2.4s              // PH = M3+$B1(M3)（rev64 单独）
  fadd     v2.4s, v2.4s, v0.4s
  uzp1     v3.4s, v3.4s, v3.4s
  uzp1     v2.4s, v2.4s, v2.4s
  zip1     v0.4s, v3.4s, v2.4s
  st1      {v0.16b}, [x5]
  // ── 块 A：twiddle 在 a_+2a_off 与 a_+3a_off
  sub      x4, x0, #28               // 块 A：ee[-7..-4] = -28 字节
  sub      x5, x1, #28
  add      x6, x2, x11
  add      x6, x6, x11, lsl #1       // &A_3a
  ld1      {v2.16b}, [x6]
  add      x6, x2, x11, lsl #1       // &A_2a
  ld1      {v3.16b}, [x6]
  zip1     v4.2d, v2.2d, v3.2d       // T=[A_3a0,A_3a1,A_2a0,A_2a1]
  rev64    v5.4s, v4.4s              // Ts = $B1(T)：rev64 单独即成对交换，
                                     // 加 ext 会成全反转（语义错误）
  ld1      {v0.16b}, [x4]
  ld1      {v1.16b}, [x5]
  fadd     v2.4s, v0.4s, v1.4s
  st1      {v2.16b}, [x4]
  fsub     v0.4s, v0.4s, v1.4s
  mov      v1.16b, v0.16b
  rev64    v1.4s, v1.4s              // dvs = $B1(dif)，同上不加 ext
  fmul     v2.4s, v1.4s, v4.4s
  fmul     v3.4s, v0.4s, v4.4s
  fmul     v0.4s, v1.4s, v5.4s
  fadd     v3.4s, v3.4s, v0.4s
  eor      v2.16b, v2.16b, v28.16b
  rev64    v0.4s, v2.4s              // PH = M3+$B1(M3)（rev64 单独）
  fadd     v2.4s, v2.4s, v0.4s
  uzp1     v3.4s, v3.4s, v3.4s
  uzp1     v2.4s, v2.4s, v2.4s
  zip1     v0.4s, v3.4s, v2.4s
  st1      {v0.16b}, [x5]
  sub      x0, x0, x10
  sub      x1, x1, x10
  subs     x9, x9, #1
  b.ne     .Lbs_iter
.Lbs_done:
end;

// ── step3 合并迭代（ld654） ──────────────────────────────────────────

procedure vdec_mdct_ld654(z_: PSingle; a2_: PSingle; iters_: LongInt); assembler; nostackframe;
{ 标量语义：组1 X=[z-3..0]/Y=[z-11..-8]，组2 X2=[z-7..-4]/Y2=[z-15..-12]
  （含 ±A2 缩放与符号交换），随后 iter54(z)、iter54(z-8)，z 每轮降
  16 float。x86 的洗牌链逐一映射：$B1→REV64+EXT、$E1→INS 低对互换、
  $1B→REV64、$E4/$movlhps/movhlps→INS（对内复制向量上 $B1 ≡ $1B）。
  x0=z_ x1=a2_ w2=iters_ }
asm
  ld1r     {v30.4s}, [x1]            // A2 广播
  movz     w6, #0x8000, lsl #16
  mov      w7, #0
  dup      v29.4s, w6
  ins      v29.s[1], w7              // SIGN_EVEN = [-0,0,-0,0]
  ins      v29.s[3], w7
  movi     v27.2d, #0
  ins      v27.s[2], w6              // SIGN_HI = [0,0,-0,-0]
  ins      v27.s[3], w6
  movi     v26.2d, #0
  ins      v26.s[1], w6              // SIGN_LO = [0,-0,-0,0]
  ins      v26.s[2], w6
  eor      v31.16b, v30.16b, v29.16b // [-A2,A2,-A2,A2] 全程常驻
  sxtw     x9, w2
  cbz      x9, .Lld_done
.Lld_iter:
  // ── 组1：X=[z-3..0]，Y=[z-11..-8]
  sub      x4, x0, #12               // 组1 X=[z-3..0] = -12 字节
  sub      x5, x0, #44               // Y=[z-11..-8] = -44 字节
  ld1      {v2.16b}, [x4]
  ld1      {v3.16b}, [x5]
  fadd     v4.4s, v2.4s, v3.4s
  st1      {v4.16b}, [x4]            // z[-3..0] = 和
  fsub     v5.4s, v2.4s, v3.4s       // Df
  mov      v2.16b, v5.16b            // 副本供合并
  rev64    v3.4s, v5.4s              // $B1(dif)：rev64 单独，不加 ext
  eor      v3.16b, v3.16b, v29.16b   // 偶 lane 取负的交换
  fadd     v5.4s, v5.4s, v3.4s       // [l11-l00,l00+l11,k11-k00,k00+k11]
  fmul     v5.4s, v5.4s, v30.4s      // ×A2（仅 lane0/1 有效）
  ins      v2.d[0], v5.d[0]          // [P0,P1,k11,k00] = z[-11..-8] 新值
  st1      {v2.16b}, [x5]
  // ── 组2：X2=[z-7..-4]，Y2=[z-15..-12]
  sub      x4, x0, #28               // 组2 X2=[z-7..-4] = -28 字节
  sub      x5, x0, #60               // Y2=[z-15..-12] = -60 字节
  ld1      {v2.16b}, [x4]
  ld1      {v3.16b}, [x5]
  fadd     v4.4s, v2.4s, v3.4s
  st1      {v4.16b}, [x4]            // z[-7..-4] = 和
  fsub     v5.4s, v2.4s, v3.4s       // D2 = E
  mov      v2.16b, v5.16b            // 副本供 kp
  rev64    v3.4s, v5.4s              // $B1(D2)：rev64 单独，不加 ext
  eor      v3.16b, v3.16b, v29.16b
  fadd     v5.4s, v5.4s, v3.4s       // SD2=[E0-E1,E0+E1,·,·]
  mov      v3.16b, v5.16b            // $E1 低对交换（INS 双拍，源不受污染）
  ins      v3.s[0], v5.s[1]
  ins      v3.s[1], v5.s[0]
  fmul     v3.4s, v3.4s, v31.4s      // [-(E0+E1)A2,(E0-E1)A2,·,·]
  mov      v6.16b, v2.16b            // $B8+[0,0,-0,0]：[E0,E2,-E3,E2]
  ins      v6.s[1], v2.s[2]
  ins      v6.s[3], v2.s[2]
  fneg     v7.4s, v2.4s
  ins      v6.s[2], v7.s[3]
  ins      v6.d[0], v3.d[0]          // [P0,P1,-k00',k11'] = z[-15..-12] 新值
  st1      {v6.16b}, [x5]
  // ── iter54 两趟：Hi 起点 z-48 与 z-176，Lo 恒为 Hi-64
  sub      x5, x0, #12               // iter54 Hi=[z-3..0] = -12 字节
  mov      w13, #2
.Llld_i54:
  sub      x4, x5, #16               // Lo = Hi - 16 字节（[-7..-4]）
  ld1      {v2.16b}, [x4]            // Lo
  ld1      {v3.16b}, [x5]            // Hi
  rev64    v4.4s, v3.4s                    // X = $1B(Hi) 全反转
  ext      v4.16b, v4.16b, v4.16b, #8      //（$1B 需 rev64+ext 两步）
  rev64    v2.4s, v2.4s                    // Lo 反转配对（$1B）
  ext      v2.16b, v2.16b, v2.16b, #8
  mov      v5.16b, v4.16b
  fadd     v5.4s, v5.4s, v2.4s             // sum
  fsub     v4.4s, v4.4s, v2.4s             // dif
  mov      v2.16b, v5.16b
  ins      v2.s[2], v5.s[0]                // [y0,y1,y0,y1]
  ins      v2.s[3], v5.s[1]
  mov      v3.16b, v5.16b
  ins      v3.s[0], v5.s[2]                // [y2,y3,y2,y3]
  ins      v3.s[1], v5.s[3]
  eor      v3.16b, v3.16b, v27.16b         // SIGN_HI
  fadd     v2.4s, v2.4s, v3.4s             // Hi 新值
  rev64    v2.4s, v2.4s                    // $1B 输出反转
  ext      v2.16b, v2.16b, v2.16b, #8
  st1      {v2.16b}, [x5]
  mov      v2.16b, v4.16b
  ins      v2.s[2], v4.s[0]                // [k00,k11,k00,k11]
  ins      v2.s[3], v4.s[1]
  mov      v3.16b, v4.16b
  ins      v3.s[0], v4.s[2]                // [k22,k33,k22,k33]
  ins      v3.s[1], v4.s[3]
  rev64    v3.4s, v3.4s                    // [k33,k22,k33,k22]
  eor      v3.16b, v3.16b, v26.16b         // SIGN_LO
  fadd     v2.4s, v2.4s, v3.4s             // Lo 新值
  rev64    v2.4s, v2.4s                    // $1B 输出反转
  ext      v2.16b, v2.16b, v2.16b, #8
  st1      {v2.16b}, [x4]
  sub      x5, x5, #32               // 第二趟：z-8 float = 再降 32 字节
  subs     w13, w13, #1
  b.ne     .Llld_i54
  sub      x0, x0, #64
  subs     x9, x9, #1
  b.ne     .Lld_iter
.Lld_done:
end;

// ── step7（C twiddle） ───────────────────────────────────────────────

procedure vdec_mdct_step7(v_: PSingle; c_: PSingle; n2_: LongInt); assembler; nostackframe;
{ 标量语义（d=v 起，e=v+n2-4 起）：a02=d[k]-e[k+2]，a11=d[k+1]+e[k+3]；
  b0=C[k+1]*a02+C[k]*a11，b1=C[k+1]*a11-C[k]*a02；b2=d[k]+e[k+2]，
  b3=d[k+1]-e[k+3]；d[k]=b2+b0，d[k+1]=b3+b1，e[k+2]=b2-b0，
  e[k+3]=b1-b3。d 升 4、e 降 4、C 升 4。迭代数 =(n2+3) div 8。
  $F5/$A0 广播用 UZP2/UZP1+ZIP1 实现（zip1 自身 =[v0,v0,v1,v1]）。
  x0=v_ x1=c_ w2=n2_ }
asm
  sxtw     x9, w2
  add      x9, x9, #3
  lsr      x9, x9, #3                // 迭代数 = (n2+3)>>3
  cbz      x9, .Lv7_done
  mov      x4, x0                    // d 游标
  sxtw     x10, w2
  add      x5, x0, x10, lsl #2
  sub      x5, x5, #16               // e 起点 = v+4*n2-16 字节
  mov      x6, x1                    // C 游标
  movz     w7, #0x8000, lsl #16
  mov      w8, #0
  movi     v29.2d, #0
  ins      v29.s[0], w7              // SIGN_EVEN = [-0,0,-0,0]（偶 lane 负，
  ins      v29.s[2], w7              // 与 x86 VDEC_SIGN_EVEN 对齐）
  movi     v28.2d, #0
  ins      v28.s[1], w7              // SIGN_ODD = [0,-0,0,-0]
  ins      v28.s[3], w7
.Lv7_iter:
  ld1      {v0.16b}, [x4]            // D
  ld1      {v1.16b}, [x5]            // E
  ld1      {v2.16b}, [x6]            // Cv
  ext      v3.16b, v1.16b, v1.16b, #8      // Erot=[e2,e3,e0,e1]
  mov      v4.16b, v3.16b
  eor      v4.16b, v4.16b, v29.16b
  fadd     v4.4s, v4.4s, v0.4s       // a02v=[a02A,a11A,a02B,a11B]
  eor      v3.16b, v3.16b, v28.16b
  fadd     v3.4s, v3.4s, v0.4s       // b2v=[b2A,b3A,b2B,b3B]
  mov      v5.16b, v4.16b
  rev64    v5.4s, v5.4s              // a02s = $B1(a02v)：rev64 单独即成对交换
  uzp2     v1.4s, v2.4s, v2.4s       // [C1,C3,C1,C3]
  zip1     v1.4s, v1.4s, v1.4s       // Cp=[C1,C1,C3,C3] ≙ pshufd $F5（zip1 自身
                                     // =[v0,v0,v1,v1]；trn1 自身会塌缩成全 C1）
  fmul     v4.4s, v4.4s, v1.4s       // P = a02v*Cp
  uzp1     v1.4s, v2.4s, v2.4s       // [C0,C2,C0,C2]
  zip1     v1.4s, v1.4s, v1.4s       // Co=[C0,C0,C2,C2] ≙ pshufd $A0
  fmul     v5.4s, v5.4s, v1.4s       // Q = a02s*Co
  eor      v5.16b, v5.16b, v28.16b   // Q 奇 lane 取负
  fadd     v4.4s, v4.4s, v5.4s       // b0v=[b0A,b1A,b0B,b1B]
  fadd     v1.4s, v3.4s, v4.4s       // Dout = b2v+b0v
  st1      {v1.16b}, [x4]
  fsub     v1.4s, v4.4s, v3.4s       // U = b0v-b2v：奇位真差 b1-b3
  fsub     v0.4s, v3.4s, v4.4s       // T = b2v-b0v：偶位真差 b2-b0
  uzp1     v0.4s, v0.4s, v0.4s       // T 偶位 [e2A,e2B]
  uzp2     v1.4s, v1.4s, v1.4s       // U 奇位 [e3A,e3B]（uzp1 会取到偶位的负值）
  zip1     v0.4s, v0.4s, v1.4s       // [e2A,e3A,e2B,e3B]
  ext      v0.16b, v0.16b, v0.16b, #8      // 窗口序 [e0,e1,e2,e3]
  st1      {v0.16b}, [x5]
  add      x4, x4, #16
  sub      x5, x5, #16
  add      x6, x6, #16
  subs     x9, x9, #1
  b.ne     .Lv7_iter
.Lv7_done:
end;

// ── step8（B kernel，散写已归并为连续 16B 存储） ──────────────────────

procedure vdec_mdct_step8(buffer_: PSingle; v_: PSingle; bstart_: PSingle; n2_: LongInt); assembler; nostackframe;
{ 每外层迭代两块（e/B 各 32B 降序），块内 PN=(−Dg)+(−swapDg)
  （双操作数取负再加）、SN=An−swapAn（真减），PV=[p1,p0,p3,p2] 由
  UZP1+ZIP1 归并；四路输出经 INS 组装（$02/$77/movlhps 的等价式），
  D1v=反序取负、D3v=反序。寄存器充裕，无需 x86 版的栈槽中转。
  x0=buffer_ x1=v_ x2=bstart_ w3=n2_ }
asm
  sxtw     x9, w3
  add      x4, x1, x9, lsl #2
  sub      x4, x4, #32               // e = buf2+n2-8 float，降序
  mov      x5, x2                    // B，降序
  add      x6, x0, x9, lsl #2        // d2 = buffer+n2，升序
  add      x7, x0, x9, lsl #2
  sub      x7, x7, #16               // d1 = buffer+n2-4，降序
  mov      x11, x0                   // d0 = buffer 基址，升序
  lsl      x10, x9, #2               // 4*n2 字节（d3 相对 d1 偏移）
  lsr      w12, w3, #3               // 迭代数
  cbz      w12, .Ls8_done
.Ls8_iter:
  // ── 低址块 L → PVc
  ld1      {v0.16b}, [x4]
  ld1      {v1.16b}, [x5]
  rev64    v2.4s, v1.4s              // W = $B1(Bv)：rev64 单独，不加 ext
  fmul     v3.4s, v0.4s, v1.4s       // Dg = Ev*Bv
  fmul     v4.4s, v0.4s, v2.4s       // An = Ev*W
  mov      v5.16b, v3.16b
  rev64    v5.4s, v5.4s              // $B1(Dg)：rev64 单独
  fneg     v3.4s, v3.4s
  fneg     v5.4s, v5.4s
  fadd     v3.4s, v3.4s, v5.4s       // PN=[p0,p0,p2,p2]
  mov      v5.16b, v4.16b
  rev64    v5.4s, v5.4s              // $B1(An)：rev64 单独
  fsub     v4.4s, v4.4s, v5.4s       // SN=[p1,-p1,p3,-p3]
  uzp1     v3.4s, v3.4s, v3.4s       // [p0,p2,·,·]
  uzp1     v4.4s, v4.4s, v4.4s       // [p1,p3,·,·]
  zip1     v16.4s, v4.4s, v3.4s      // PVc=[p1,p0,p3,p2]
  // ── 高址块 H → PVd
  add      x13, x4, #16
  add      x14, x5, #16
  ld1      {v0.16b}, [x13]
  ld1      {v1.16b}, [x14]
  rev64    v2.4s, v1.4s              // W = $B1(Bv)：rev64 单独，不加 ext
  fmul     v3.4s, v0.4s, v1.4s
  fmul     v4.4s, v0.4s, v2.4s
  mov      v5.16b, v3.16b
  rev64    v5.4s, v5.4s              // $B1(Dg)：rev64 单独
  fneg     v3.4s, v3.4s
  fneg     v5.4s, v5.4s
  fadd     v3.4s, v3.4s, v5.4s
  mov      v5.16b, v4.16b
  rev64    v5.4s, v5.4s              // $B1(An)：rev64 单独
  fsub     v4.4s, v4.4s, v5.4s
  uzp1     v3.4s, v3.4s, v3.4s
  uzp1     v4.4s, v4.4s, v4.4s
  zip1     v17.4s, v4.4s, v3.4s      // PVd=[p1,p0,p3,p2]
  // ── 四路输出组装与存储：H 块落 d 输出高对，L 块落低对
  ins      v0.s[0], v17.s[2]         // D0v=[p3H,p1H,p3L,p1L]
  ins      v0.s[1], v17.s[0]
  ins      v0.s[2], v16.s[2]
  ins      v0.s[3], v16.s[0]
  ins      v2.s[0], v17.s[3]         // D2v=[p2H,p0H,p2L,p0L]
  ins      v2.s[1], v17.s[1]
  ins      v2.s[2], v16.s[3]
  ins      v2.s[3], v16.s[1]
  fneg     v1.4s, v0.4s              // D1v = 反序取负（一元取负精确）
  rev64    v1.4s, v1.4s              // $1B 全反转 = rev64+ext
  ext      v1.16b, v1.16b, v1.16b, #8
  rev64    v3.4s, v2.4s              // D3v = 反序（$1B）
  ext      v3.16b, v3.16b, v3.16b, #8
  st1      {v0.16b}, [x11]
  st1      {v2.16b}, [x6]
  st1      {v1.16b}, [x7]
  add      x8, x7, x10
  st1      {v3.16b}, [x8]
  add      x11, x11, #16
  add      x6, x6, #16
  sub      x7, x7, #16
  sub      x4, x4, #32
  sub      x5, x5, #32
  subs     w12, w12, #1
  b.ne     .Ls8_iter
.Ls8_done:
end;

{$endif cpuaarch64}

end.
