// === I8x64 Arithmetic/Bitwise/Comparison/MinMax (512-bit) ===

function AVX512AddI8x64(const a, b: TVecI8x64): TVecI8x64;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpaddb  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SubI8x64(const a, b: TVecI8x64): TVecI8x64;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpsubb  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512AndI8x64(const a, b: TVecI8x64): TVecI8x64;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpandq  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512OrI8x64(const a, b: TVecI8x64): TVecI8x64;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vporq   zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512XorI8x64(const a, b: TVecI8x64): TVecI8x64;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpxorq  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512NotI8x64(const a: TVecI8x64): TVecI8x64;
var
  LPa, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    vmovdqu64 zmm0, [rdx]
    vpternlogd zmm0, zmm0, zmm0, $55
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512AndNotI8x64(const a, b: TVecI8x64): TVecI8x64;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpandnd zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512CmpEqI8x64(const a, b: TVecI8x64): TMask64;
var
  LPa, LPb: Pointer;
  LMask: QWord;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpeqb k1, zmm0, [rcx]
    kmovq   LMask, k1
    vzeroupper
  end;

  Result := TMask64(LMask);
end;

function AVX512CmpLtI8x64(const a, b: TVecI8x64): TMask64;
var
  LPa, LPb: Pointer;
  LMask: QWord;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpb  k1, zmm0, [rcx], 1
    kmovq   LMask, k1
    vzeroupper
  end;

  Result := TMask64(LMask);
end;

function AVX512CmpGtI8x64(const a, b: TVecI8x64): TMask64;
var
  LPa, LPb: Pointer;
  LMask: QWord;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpb  k1, zmm0, [rcx], 6
    kmovq   LMask, k1
    vzeroupper
  end;

  Result := TMask64(LMask);
end;

function AVX512MinI8x64(const a, b: TVecI8x64): TVecI8x64;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpminsb zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MaxI8x64(const a, b: TVecI8x64): TVecI8x64;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpmaxsb zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

