// === F64x4 Extended Math Operations (256-bit AVX) ===

function AVX2FmaF64x4(const a, b, c: TVecF64x4): TVecF64x4;
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
      vmovupd ymm0, [r8]            // ymm0 = c
      vmovupd ymm1, [rdx]           // ymm1 = a
      vfmadd231pd ymm0, ymm1, [rcx] // ymm0 = a*b + c (fused)
      vmovupd [rax], ymm0
      vzeroupper
    end;
  end
  else
    Result := ScalarFmaF64x4(a, b, c);
end;

function AVX2FloorF64x4(const a: TVecF64x4): TVecF64x4;
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
      vmovupd  ymm0, [rdx]
      vroundpd ymm0, ymm0, 1   // floor = round toward -inf
      vmovupd  [rax], ymm0
      vzeroupper
    end;
  end
  else
    Result := ScalarFloorF64x4(a);
end;

function AVX2CeilF64x4(const a: TVecF64x4): TVecF64x4;
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
      vmovupd  ymm0, [rdx]
      vroundpd ymm0, ymm0, 2   // ceil = round toward +inf
      vmovupd  [rax], ymm0
      vzeroupper
    end;
  end
  else
    Result := ScalarCeilF64x4(a);
end;

function AVX2RoundF64x4(const a: TVecF64x4): TVecF64x4;
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
      vmovupd  ymm0, [rdx]
      vroundpd ymm0, ymm0, 0   // round to nearest even
      vmovupd  [rax], ymm0
      vzeroupper
    end;
  end
  else
    Result := ScalarRoundF64x4(a);
end;

function AVX2TruncF64x4(const a: TVecF64x4): TVecF64x4;
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
      vmovupd  ymm0, [rdx]
      vroundpd ymm0, ymm0, 3   // truncate = round toward zero
      vmovupd  [rax], ymm0
      vzeroupper
    end;
  end
  else
    Result := ScalarTruncF64x4(a);
end;

