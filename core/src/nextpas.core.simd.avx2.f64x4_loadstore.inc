// === F64x4 Load/Store/Splat/Zero Operations (256-bit AVX) ===

function AVX2LoadF64x4(p: PDouble): TVecF64x4;
var
  pr: Pointer;
begin
  Assert(p <> nil, 'AVX2LoadF64x4: pointer is nil');
  pr := @Result;
  asm
    mov     rax, pr
    mov     rdx, p
    vmovupd ymm0, [rdx]
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

procedure AVX2StoreF64x4(p: PDouble; const a: TVecF64x4);
var
  pa: Pointer;
begin
  Assert(p <> nil, 'AVX2StoreF64x4: pointer is nil');
  pa := @a;
  asm
    mov     rax, p
    mov     rdx, pa
    vmovupd ymm0, [rdx]
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

function AVX2SplatF64x4(value: Double): TVecF64x4;
var
  pr: Pointer;
  LValuePtr: PDouble;
begin
  pr := @Result;
  LValuePtr := @value;
  asm
    mov          rax, pr
    mov          rdx, LValuePtr
    vbroadcastsd ymm0, [rdx]    // broadcast scalar from memory to all 4 lanes
    vmovupd      [rax], ymm0
    vzeroupper
  end;
end;

function AVX2ZeroF64x4: TVecF64x4;
var
  pr: Pointer;
begin
  pr := @Result;
  asm
    mov     rax, pr
    vxorpd  ymm0, ymm0, ymm0
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

