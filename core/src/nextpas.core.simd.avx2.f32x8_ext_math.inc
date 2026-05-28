// === F32x8 Extended Math Operations (256-bit AVX) ===

function AVX2FmaF32x8(const a, b, c: TVecF32x8): TVecF32x8;
var
  pa, pb, pc, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  pb := @b;
  pc := @c;
  if HasFeature(gfFMA) then
  begin
    asm
      mov     rax, pr
      mov     rdx, pa
      mov     rcx, pb
      mov     r8, pc
      vmovups ymm0, [r8]            // ymm0 = c
      vmovups ymm1, [rdx]           // ymm1 = a
      vfmadd231ps ymm0, ymm1, [rcx] // ymm0 = a*b + c (fused)
      vmovups [rax], ymm0
      vzeroupper
    end;
  end
  else
    Result := ScalarFmaF32x8(a, b, c);
end;

function AVX2FloorF32x8(const a: TVecF32x8): TVecF32x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  if HasSSE41 then
  begin
    asm
      mov      rax, pr
      mov      rdx, pa
      vmovups  ymm0, [rdx]
      vroundps ymm0, ymm0, 1   // floor = round toward -inf
      vmovups  [rax], ymm0
      vzeroupper
    end;
  end
  else
    Result := ScalarFloorF32x8(a);
end;

function AVX2CeilF32x8(const a: TVecF32x8): TVecF32x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  if HasSSE41 then
  begin
    asm
      mov      rax, pr
      mov      rdx, pa
      vmovups  ymm0, [rdx]
      vroundps ymm0, ymm0, 2   // ceil = round toward +inf
      vmovups  [rax], ymm0
      vzeroupper
    end;
  end
  else
    Result := ScalarCeilF32x8(a);
end;

function AVX2RoundF32x8(const a: TVecF32x8): TVecF32x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  if HasSSE41 then
  begin
    asm
      mov      rax, pr
      mov      rdx, pa
      vmovups  ymm0, [rdx]
      vroundps ymm0, ymm0, 0   // round to nearest even
      vmovups  [rax], ymm0
      vzeroupper
    end;
  end
  else
    Result := ScalarRoundF32x8(a);
end;

function AVX2TruncF32x8(const a: TVecF32x8): TVecF32x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  if HasSSE41 then
  begin
    asm
      mov      rax, pr
      mov      rdx, pa
      vmovups  ymm0, [rdx]
      vroundps ymm0, ymm0, 3   // truncate = round toward zero
      vmovups  [rax], ymm0
      vzeroupper
    end;
  end
  else
    Result := ScalarTruncF32x8(a);
end;

