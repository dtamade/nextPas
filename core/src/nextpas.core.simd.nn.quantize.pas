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
      LAccum := 0;
      for LP := 0 to AK - 1 do
        LAccum := LAccum + Int32(AA[LI * AK + LP]) * Int32(AB[LP * AN + LJ]);
      AC[LI * AN + LJ] := LAccum * LScale;
    end;
end;

end.
