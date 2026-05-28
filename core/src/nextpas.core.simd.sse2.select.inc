// === ✅ P4: SelectF64x2 SIMD Implementation ===
// 使用 andpd/andnpd/orpd 实现手动混合 (blendvpd 需要 SSE4.1)
// mask 位 0 控制元素 0，位 1 控制元素 1
// 位为 1 时选择 a，位为 0 时选择 b
function SSE2SelectF64x2(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;
var
  pa, pb, pm, pr: Pointer;
  expandedMask: TVecI64x2;
begin
  // 将 mask 扩展为 64-bit 掉码
  if (mask and 1) <> 0 then expandedMask.i[0] := Int64(-1) else expandedMask.i[0] := 0;
  if (mask and 2) <> 0 then expandedMask.i[1] := Int64(-1) else expandedMask.i[1] := 0;

  pa := @a;
  pb := @b;
  pm := @expandedMask;
  pr := @Result;

  // result = (a AND mask) OR (b AND NOT mask)
  asm
    mov   rax, pa
    mov   rdx, pb
    mov   rcx, pm
    mov   r8, pr

    movupd xmm0, [rax]     // a
    movupd xmm1, [rdx]     // b
    movdqu xmm2, [rcx]     // mask (expanded to 128-bit)

    andpd  xmm0, xmm2      // a AND mask
    andnpd xmm2, xmm1      // b AND (NOT mask)  (andnpd: ~src1 AND src2)
    orpd   xmm0, xmm2      // combine

    movupd [r8], xmm0
  end;
end;
