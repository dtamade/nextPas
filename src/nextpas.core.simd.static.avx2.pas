unit nextpas.core.simd.static.avx2;

{$mode objfpc}
{$I nextpas.core.settings.inc}
{$asmmode intel}

{$IFNDEF CPUX86_64}
  {$FATAL nextpas.core.simd.static.avx2 requires x86_64 target}
{$ENDIF}

interface

uses
  nextpas.core.simd.base;

function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4;
function VecF32x4Sub(const a, b: TVecF32x4): TVecF32x4;
function VecF32x4Mul(const a, b: TVecF32x4): TVecF32x4;
function VecF32x4Div(const a, b: TVecF32x4): TVecF32x4;
function VecF32x4Min(const a, b: TVecF32x4): TVecF32x4;
function VecF32x4Max(const a, b: TVecF32x4): TVecF32x4;
function VecF32x4Sqrt(const a: TVecF32x4): TVecF32x4;

function VecF32x8Add(const a, b: TVecF32x8): TVecF32x8;
function VecF32x8Sub(const a, b: TVecF32x8): TVecF32x8;
function VecF32x8Mul(const a, b: TVecF32x8): TVecF32x8;

function VecF64x2Add(const a, b: TVecF64x2): TVecF64x2;
function VecF64x2Sub(const a, b: TVecF64x2): TVecF64x2;
function VecF64x2Mul(const a, b: TVecF64x2): TVecF64x2;
function VecF64x2Div(const a, b: TVecF64x2): TVecF64x2;

implementation

uses
  SysUtils,
  nextpas.core.simd.cpuinfo;

procedure RequireStaticAVX2Target;
begin
  if not GetCPUInfo.X86.HasAVX2 then
    raise Exception.Create('nextpas.core.simd.static.avx2: CPU does not support AVX2');
end;

// === F32x4 ===

function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovups xmm0, [rax]
    vaddps xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function VecF32x4Sub(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovups xmm0, [rax]
    vsubps xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function VecF32x4Mul(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovups xmm0, [rax]
    vmulps xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function VecF32x4Div(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovups xmm0, [rax]
    vdivps xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function VecF32x4Min(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovups xmm0, [rax]
    vminps xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function VecF32x4Max(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovups xmm0, [rax]
    vmaxps xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function VecF32x4Sqrt(const a: TVecF32x4): TVecF32x4;
begin
  asm
    lea rax, a
    vmovups xmm0, [rax]
    vsqrtps xmm0, xmm0
    vmovups [result], xmm0
  end;
end;

// === F32x8 ===

function VecF32x8Add(const a, b: TVecF32x8): TVecF32x8;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    vmovups ymm0, [rax]
    vaddps ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vzeroupper
  end;
end;

function VecF32x8Sub(const a, b: TVecF32x8): TVecF32x8;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    vmovups ymm0, [rax]
    vsubps ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vzeroupper
  end;
end;

function VecF32x8Mul(const a, b: TVecF32x8): TVecF32x8;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    vmovups ymm0, [rax]
    vmulps ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vzeroupper
  end;
end;

// === F64x2 ===

function VecF64x2Add(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovupd xmm0, [rax]
    vaddpd xmm0, xmm0, [rdx]
    vmovupd [result], xmm0
  end;
end;

function VecF64x2Sub(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovupd xmm0, [rax]
    vsubpd xmm0, xmm0, [rdx]
    vmovupd [result], xmm0
  end;
end;

function VecF64x2Mul(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovupd xmm0, [rax]
    vmulpd xmm0, xmm0, [rdx]
    vmovupd [result], xmm0
  end;
end;

function VecF64x2Div(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovupd xmm0, [rax]
    vdivpd xmm0, xmm0, [rdx]
    vmovupd [result], xmm0
  end;
end;

initialization
  RequireStaticAVX2Target;

end.