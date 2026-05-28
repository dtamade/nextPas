program nextpas.core.simd.ulp_exhaustive;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

const
  BATCH = 4096;
  NUM_SAMPLES = 10000000;

var
  Src, Dst: array[0..BATCH-1] of Single;

type
  TSimdBatchProc = procedure(s, d: PSingle; c: SizeUInt);
  TRefFunc = function(x: Single): Single;

function FloatBitsToInt(f: Single): Int32; inline;
begin
  Move(f, Result, 4);
end;

function ULPError(got, expected: Single): UInt32;
var gi, ei: Int32;
begin
  if IsNan(got) and IsNan(expected) then Exit(0);
  if IsNan(got) or IsNan(expected) then Exit($FFFFFFFF);
  if got = expected then Exit(0);
  gi := FloatBitsToInt(got);
  ei := FloatBitsToInt(expected);
  if gi < 0 then gi := Int32($80000000) - gi;
  if ei < 0 then ei := Int32($80000000) - ei;
  Result := UInt32(Abs(Int64(gi) - Int64(ei)));
end;

procedure TestFunction(const aName: string; aLo, aHi: Single;
  aSimdProc: TSimdBatchProc;
  aRefFunc: TRefFunc);
var
  i, j, idx: Integer;
  maxULP: UInt32;
  totalULP: UInt64;
  count: UInt64;
  ulp: UInt32;
  expected, x: Single;
  step: Single;
  maxULP_x, maxULP_got, maxULP_exp: Single;
begin
  WriteLn(Format('--- %s exhaustive ULP test ---', [aName]));
  WriteLn(Format('  Range: [%.4g, %.4g], Samples: %d', [Double(aLo), Double(aHi), NUM_SAMPLES]));

  maxULP := 0;
  totalULP := 0;
  count := 0;
  maxULP_x := 0;
  maxULP_got := 0;
  maxULP_exp := 0;
  step := (aHi - aLo) / NUM_SAMPLES;

  idx := 0;
  x := aLo;
  while x <= aHi do
  begin
    Src[idx] := x;
    Inc(idx);

    if idx = BATCH then
    begin
      aSimdProc(@Src[0], @Dst[0], idx);
      for j := 0 to idx - 1 do
      begin
        expected := aRefFunc(Src[j]);
        ulp := ULPError(Dst[j], expected);
        if ulp < $FFFFFFF then
        begin
          if ulp > maxULP then
          begin
            maxULP := ulp;
            maxULP_x := Src[j];
            maxULP_got := Dst[j];
            maxULP_exp := expected;
          end;
          totalULP := totalULP + ulp;
          Inc(count);
        end;
      end;
      idx := 0;
    end;

    x := x + step;
  end;

  // Flush remaining
  if idx > 0 then
  begin
    aSimdProc(@Src[0], @Dst[0], idx);
    for j := 0 to idx - 1 do
    begin
      expected := aRefFunc(Src[j]);
      ulp := ULPError(Dst[j], expected);
      if ulp < $FFFFFFF then
      begin
        if ulp > maxULP then
        begin
          maxULP := ulp;
          maxULP_x := Src[j];
          maxULP_got := Dst[j];
          maxULP_exp := expected;
        end;
        totalULP := totalULP + ulp;
        Inc(count);
      end;
    end;
  end;

  WriteLn(Format('  Tested: %d values', [count]));
  WriteLn(Format('  Max ULP: %d', [maxULP]));
  if count > 0 then
    WriteLn(Format('  Avg ULP: %.3f', [totalULP / count]));
  if maxULP > 0 then
    WriteLn(Format('  Worst at x=%.8g: got=%.8g expected=%.8g',
      [Double(maxULP_x), Double(maxULP_got), Double(maxULP_exp)]));
  if maxULP <= 4 then
    WriteLn('  Verdict: EXCELLENT (<= 4 ULP)')
  else if maxULP <= 16 then
    WriteLn('  Verdict: GOOD (<= 16 ULP)')
  else
    WriteLn('  Verdict: NEEDS IMPROVEMENT');
  WriteLn('');
end;

procedure DoExp(s, d: PSingle; c: SizeUInt);
begin ArrayExpF32(s, d, c); end;

procedure DoLog(s, d: PSingle; c: SizeUInt);
begin ArrayLogF32(s, d, c); end;

procedure DoSin(s, d: PSingle; c: SizeUInt);
begin ArraySinF32(s, d, c); end;

procedure DoCos(s, d: PSingle; c: SizeUInt);
begin ArrayCosF32(s, d, c); end;

function RefExp(x: Single): Single;
begin Result := Single(System.Exp(x)); end;

function RefLog(x: Single): Single;
begin Result := Single(System.Ln(x)); end;

function RefSin(x: Single): Single;
begin Result := Single(System.Sin(x)); end;

function RefCos(x: Single): Single;
begin Result := Single(System.Cos(x)); end;

begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);

  WriteLn('=== Exhaustive ULP Precision Test ===');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestFunction('ArrayExpF32', -87.0, 88.0, @DoExp, @RefExp);
  TestFunction('ArrayLogF32', 0.001, 1e30, @DoLog, @RefLog);
  TestFunction('ArraySinF32 |x|<pi', -3.15, 3.15, @DoSin, @RefSin);
  TestFunction('ArraySinF32 |x|<25', -25.0, 25.0, @DoSin, @RefSin);
  TestFunction('ArrayCosF32 |x|<pi', -3.15, 3.15, @DoCos, @RefCos);
  TestFunction('ArrayCosF32 |x|<25', -25.0, 25.0, @DoCos, @RefCos);

  WriteLn('=== Done ===');
end.
