unit nextpas.core.simd.nn.quantize;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.alloc;

type
  TQuantizedTensor = record
    Data: PInt8;
    Scale: Single;
    ZeroPoint: Int8;
    Count: SizeUInt;
  end;

procedure QuantizeSymmetricF32ToI8(ASrc: PSingle; ADst: PInt8;
  ACount: SizeUInt; out AScale: Single);

procedure DequantizeI8ToF32(ASrc: PInt8; ADst: PSingle;
  ACount: SizeUInt; AScale: Single);

// Quantized GEMM: C_f32[M,N] = (A_i8[M,K] * B_i8[K,N]) * (scaleA * scaleB)
procedure GemmQuantizedI8(AA: PInt8; AB: PInt8; AC: PSingle;
  AM, AN, AK: SizeUInt; AScaleA, AScaleB: Single);

// Packed B variant: B is [N, K] row-major — enables SSE2 DotI8
procedure GemmQuantizedI8_PackedB(AA: PInt8; AB: PInt8; AC: PSingle;
  AM, AN, AK: SizeUInt; AScaleA, AScaleB: Single);

function DotI8(AA, AB: PInt8; ACount: SizeUInt): Int32;

// INT4 quantization (nibble-packed: 2 values per byte)
procedure QuantizeSymmetricF32ToI4(ASrc: PSingle; ADst: PByte;
  ACount: SizeUInt; out AScale: Single);

procedure DequantizeI4ToF32(ASrc: PByte; ADst: PSingle;
  ACount: SizeUInt; AScale: Single);

// INT4 dot product: A is INT8 (activation), B is INT4 packed (weights)
function DotI8xI4(AA: PInt8; AB: PByte; ACount: SizeUInt): Int32;

implementation

uses
  nextpas.core.simd;

procedure QuantizeSymmetricF32ToI8(ASrc: PSingle; ADst: PInt8;
  ACount: SizeUInt; out AScale: Single);
var
  LI: SizeUInt;
  LMax, LVal: Single;
  LScaled: Int32;
begin
  if ACount = 0 then begin AScale := 1.0; Exit; end;

  // Find absmax
  LMax := 0;
  for LI := 0 to ACount - 1 do
  begin
    LVal := System.Abs(ASrc[LI]);
    if LVal > LMax then LMax := LVal;
  end;

  if LMax < 1e-10 then
  begin
    AScale := 1.0;
    FillChar(ADst^, ACount, 0);
    Exit;
  end;

  AScale := LMax / 127.0;

  for LI := 0 to ACount - 1 do
  begin
    LScaled := System.Round(ASrc[LI] / AScale);
    if LScaled > 127 then LScaled := 127;
    if LScaled < -128 then LScaled := -128;
    ADst[LI] := Int8(LScaled);
  end;
end;

procedure DequantizeI8ToF32(ASrc: PInt8; ADst: PSingle;
  ACount: SizeUInt; AScale: Single);
var
  LI: SizeUInt;
begin
  for LI := 0 to ACount - 1 do
    ADst[LI] := ASrc[LI] * AScale;
end;

// INT8 dot product of two contiguous arrays, returns INT32 sum
function DotI8(AA, AB: PInt8; ACount: SizeUInt): Int32;
var
  LP: SizeUInt;
  {$IFDEF SIMD_X86_AVAILABLE}
  LCount16: SizeUInt;
  {$ENDIF}
begin
  Result := 0;
  LP := 0;
  {$IFDEF SIMD_X86_AVAILABLE}
  LCount16 := ACount and (not SizeUInt(15));
  if LCount16 > 0 then
  asm
    push rbx
    mov rax, AA
    mov rbx, AB
    xor ecx, ecx         // loop counter
    pxor xmm0, xmm0      // INT32 accumulator

  @dot_loop:
    // Load 16 INT8 from A and B
    movdqu xmm1, [rax + rcx]
    movdqu xmm2, [rbx + rcx]

    // Sign-extend low 8 bytes to INT16
    pmovsxbw xmm3, xmm1        // A[0..7] → INT16
    pmovsxbw xmm4, xmm2        // B[0..7] → INT16
    pmaddwd xmm3, xmm4         // paired mul-add → 4 INT32
    paddd xmm0, xmm3

    // Sign-extend high 8 bytes
    psrldq xmm1, 8
    psrldq xmm2, 8
    pmovsxbw xmm3, xmm1        // A[8..15] → INT16
    pmovsxbw xmm4, xmm2        // B[8..15] → INT16
    pmaddwd xmm3, xmm4
    paddd xmm0, xmm3

    add ecx, 16
    cmp ecx, dword [LCount16]
    jb @dot_loop

    // Horizontal sum
    movdqa xmm1, xmm0
    psrldq xmm1, 8
    paddd xmm0, xmm1
    movdqa xmm1, xmm0
    psrldq xmm1, 4
    paddd xmm0, xmm1
    movd eax, xmm0
    add Result, eax
    mov LP, rcx
    pop rbx
  end;
  {$ENDIF}
  while LP < ACount do
  begin
    Result := Result + Int32(AA[LP]) * Int32(AB[LP]);
    Inc(LP);
  end;
end;

procedure GemmQuantizedI8(AA: PInt8; AB: PInt8; AC: PSingle;
  AM, AN, AK: SizeUInt; AScaleA, AScaleB: Single);
var
  LI, LJ, LP: SizeUInt;
  LAccum: Int32;
  LScale: Single;
begin
  LScale := AScaleA * AScaleB;
  for LI := 0 to AM - 1 do
    for LJ := 0 to AN - 1 do
    begin
      // B column is strided — scalar fallback for now
      LAccum := 0;
      for LP := 0 to AK - 1 do
        LAccum := LAccum + Int32(AA[LI * AK + LP]) * Int32(AB[LP * AN + LJ]);
      AC[LI * AN + LJ] := LAccum * LScale;
    end;
end;

// Packed variant: B is [N, K] row-major (each row of B is contiguous)
// Use DotI8 for SIMD acceleration
procedure GemmQuantizedI8_PackedB(AA: PInt8; AB: PInt8; AC: PSingle;
  AM, AN, AK: SizeUInt; AScaleA, AScaleB: Single);
var
  LI, LJ: SizeUInt;
  LScale: Single;
begin
  LScale := AScaleA * AScaleB;
  for LI := 0 to AM - 1 do
    for LJ := 0 to AN - 1 do
      AC[LI * AN + LJ] := DotI8(@AA[LI * AK], @AB[LJ * AK], AK) * LScale;
end;

// INT4 symmetric quantization: pack 2 nibbles per byte (low=even, high=odd)
procedure QuantizeSymmetricF32ToI4(ASrc: PSingle; ADst: PByte;
  ACount: SizeUInt; out AScale: Single);
var
  LI: SizeUInt;
  LMax, LVal: Single;
  LQ0, LQ1: Int32;
  LByteCount: SizeUInt;
begin
  if ACount = 0 then begin AScale := 1.0; Exit; end;

  LMax := 0;
  for LI := 0 to ACount - 1 do
  begin
    LVal := System.Abs(ASrc[LI]);
    if LVal > LMax then LMax := LVal;
  end;

  if LMax < 1e-10 then
  begin
    AScale := 1.0;
    LByteCount := (ACount + 1) div 2;
    FillChar(ADst^, LByteCount, 0);
    Exit;
  end;

  AScale := LMax / 7.0;

  LI := 0;
  while LI + 1 < ACount do
  begin
    LQ0 := System.Round(ASrc[LI] / AScale);
    if LQ0 > 7 then LQ0 := 7;
    if LQ0 < -8 then LQ0 := -8;
    LQ1 := System.Round(ASrc[LI + 1] / AScale);
    if LQ1 > 7 then LQ1 := 7;
    if LQ1 < -8 then LQ1 := -8;
    ADst[LI div 2] := Byte((LQ0 and $0F) or ((LQ1 and $0F) shl 4));
    Inc(LI, 2);
  end;
  if LI < ACount then
  begin
    LQ0 := System.Round(ASrc[LI] / AScale);
    if LQ0 > 7 then LQ0 := 7;
    if LQ0 < -8 then LQ0 := -8;
    ADst[LI div 2] := Byte(LQ0 and $0F);
  end;
end;

procedure DequantizeI4ToF32(ASrc: PByte; ADst: PSingle;
  ACount: SizeUInt; AScale: Single);
var
  LI: SizeUInt;
  LByte: Byte;
  LNibble: Int8;
begin
  for LI := 0 to ACount - 1 do
  begin
    LByte := ASrc[LI div 2];
    if (LI and 1) = 0 then
      LNibble := Int8((LByte and $0F) or (-(LByte and $08) and $F0))
    else
      LNibble := Int8(((LByte shr 4) and $0F) or (-((LByte shr 4) and $08) and $F0));
    ADst[LI] := LNibble * AScale;
  end;
end;

function DotI8xI4(AA: PInt8; AB: PByte; ACount: SizeUInt): Int32;
var
  LI: SizeUInt;
  LByte: Byte;
  LNibble: Int32;
begin
  Result := 0;
  for LI := 0 to ACount - 1 do
  begin
    LByte := AB[LI div 2];
    if (LI and 1) = 0 then
      LNibble := Int32(Int8((LByte and $0F) or (-(LByte and $08) and $F0)))
    else
      LNibble := Int32(Int8(((LByte shr 4) and $0F) or (-((LByte shr 4) and $08) and $F0)));
    Result := Result + Int32(AA[LI]) * LNibble;
  end;
end;

end.
