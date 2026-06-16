program test_quantize;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.simd.alloc,
  nextpas.core.simd.nn.quantize;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; AGot, AExpect: Single; ATol: Single = 0.05);
var
  LDiff, LScale: Single;
begin
  LDiff := System.Abs(AGot - AExpect);
  LScale := System.Abs(AExpect);
  if LScale < 1.0 then LScale := 1.0;
  if LDiff <= ATol * LScale then
    Inc(GPass)
  else
  begin
    WriteLn('  FAIL ', AName, ': got=', AGot:0:4, ' expect=', AExpect:0:4);
    Inc(GFail);
  end;
end;

procedure TestQuantizeRoundTrip;
var
  LSrc, LDst: array[0..15] of Single;
  LQ: array[0..15] of Int8;
  LScale: Single;
  LI: Integer;
begin
  for LI := 0 to 15 do
    LSrc[LI] := (LI - 8) * 0.1;

  QuantizeSymmetricF32ToI8(@LSrc[0], @LQ[0], 16, LScale);
  DequantizeI8ToF32(@LQ[0], @LDst[0], 16, LScale);

  for LI := 0 to 15 do
    Check('RT[' + IntToStr(LI) + ']', LDst[LI], LSrc[LI]);
end;

procedure TestGemmQuantized;
var
  LA: array[0..3] of Single;
  LB: array[0..3] of Single;
  LC: array[0..0] of Single;
  LAq: array[0..3] of Int8;
  LBq: array[0..3] of Int8;
  LScaleA, LScaleB: Single;
  LExpected: Single;
begin
  LA[0] := 1.0; LA[1] := 2.0; LA[2] := 3.0; LA[3] := 4.0;
  LB[0] := 0.5; LB[1] := 1.0; LB[2] := 1.5; LB[3] := 2.0;

  QuantizeSymmetricF32ToI8(@LA[0], @LAq[0], 4, LScaleA);
  QuantizeSymmetricF32ToI8(@LB[0], @LBq[0], 4, LScaleB);

  // M=1, N=1, K=4: dot product
  GemmQuantizedI8(@LAq[0], @LBq[0], @LC[0], 1, 1, 4, LScaleA, LScaleB);

  LExpected := 1.0*0.5 + 2.0*1.0 + 3.0*1.5 + 4.0*2.0; // = 15.0
  Check('GemmI8_dot', LC[0], LExpected);
end;

begin
  GPass := 0;
  GFail := 0;

  WriteLn('=== Quantization Tests ===');
  TestQuantizeRoundTrip;
  TestGemmQuantized;

  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.
