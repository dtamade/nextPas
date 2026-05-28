// === F32x8 Load/Store/Splat/Zero Operations (256-bit AVX) ===

function AVX2LoadF32x8(p: PSingle): TVecF32x8;
var
  pr: Pointer;
begin
  Assert(p <> nil, 'AVX2LoadF32x8: pointer is nil');
  pr := @Result;
  asm
    mov     rax, pr
    mov     rdx, p
    vmovups ymm0, [rdx]
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

procedure AVX2StoreF32x8(p: PSingle; const a: TVecF32x8);
var
  pa: Pointer;
begin
  Assert(p <> nil, 'AVX2StoreF32x8: pointer is nil');
  pa := @a;
  asm
    mov     rax, p
    mov     rdx, pa
    vmovups ymm0, [rdx]
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

function AVX2SplatF32x8(value: Single): TVecF32x8;
var
  pr: Pointer;
begin
  pr := @Result;
  asm
    mov          rax, pr
    movss        xmm0, value
    vbroadcastss ymm0, xmm0     // broadcast to all 8 lanes
    vmovups      [rax], ymm0
    vzeroupper
  end;
end;

function AVX2ZeroF32x8: TVecF32x8;
var
  pr: Pointer;
begin
  pr := @Result;
  asm
    mov     rax, pr
    vxorps  ymm0, ymm0, ymm0
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

