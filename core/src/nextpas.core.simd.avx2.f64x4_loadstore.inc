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

function AVX2SplatF64x4(value: Double): TVecF64x4; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // rdi=@Result, xmm0=value
  vmovsd       [rsp-8], xmm0
  vbroadcastsd ymm0, [rsp-8]
  vmovupd      [rdi], ymm0
  {$ELSE}
  // rcx=@Result, xmm0=value
  vmovsd       [rsp-8], xmm0
  vbroadcastsd ymm0, [rsp-8]
  vmovupd      [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2ZeroF64x4: TVecF64x4; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // rdi=@Result
  vxorpd  ymm0, ymm0, ymm0
  vmovupd [rdi], ymm0
  {$ELSE}
  // rcx=@Result
  vxorpd  ymm0, ymm0, ymm0
  vmovupd [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;
