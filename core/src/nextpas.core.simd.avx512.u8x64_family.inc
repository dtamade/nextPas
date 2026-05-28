// === U8x64 Arithmetic/Bitwise/Comparison/MinMax (512-bit) ===

function AVX512AddU8x64(const a, b: TVecU8x64): TVecU8x64;
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

function AVX512SubU8x64(const a, b: TVecU8x64): TVecU8x64;
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

function AVX512AndU8x64(const a, b: TVecU8x64): TVecU8x64;
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

function AVX512OrU8x64(const a, b: TVecU8x64): TVecU8x64;
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

function AVX512XorU8x64(const a, b: TVecU8x64): TVecU8x64;
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

function AVX512NotU8x64(const a: TVecU8x64): TVecU8x64;
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

function AVX512CmpEqU8x64(const a, b: TVecU8x64): TMask64;
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

function AVX512CmpLtU8x64(const a, b: TVecU8x64): TMask64;
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
    vpcmpub k1, zmm0, [rcx], 1
    kmovq   LMask, k1
    vzeroupper
  end;

  Result := TMask64(LMask);
end;

function AVX512CmpGtU8x64(const a, b: TVecU8x64): TMask64;
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
    vpcmpub k1, zmm0, [rcx], 6
    kmovq   LMask, k1
    vzeroupper
  end;

  Result := TMask64(LMask);
end;

function AVX512MinU8x64(const a, b: TVecU8x64): TVecU8x64;
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
    vpminub zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MaxU8x64(const a, b: TVecU8x64): TVecU8x64;
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
    vpmaxub zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

