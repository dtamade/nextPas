{
  bench_bitops.lpr

  Benchmark: bitops native instructions vs pure Pascal loop fallback.
  Uses nextpas.core.bench framework.
}
{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
program bench_bitops;

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.simd.bitops,
  nextpas.core.platform.time;

{ --- Pure Pascal reference implementations (loop-based) --- }

function PascalClz32(AValue: UInt32): UInt32;
var
  LMask: UInt32;
begin
  Result := 0;
  LMask := UInt32($80000000);
  while (LMask <> 0) and ((AValue and LMask) = 0) do
  begin
    Inc(Result);
    LMask := LMask shr 1;
  end;
end;

function PascalClz64(AValue: UInt64): UInt32;
var
  LMask: UInt64;
begin
  Result := 0;
  LMask := UInt64($8000000000000000);
  while (LMask <> 0) and ((AValue and LMask) = 0) do
  begin
    Inc(Result);
    LMask := LMask shr 1;
  end;
end;

function PascalCtz32(AValue: UInt32): UInt32;
var
  LMask: UInt32;
begin
  Result := 0;
  LMask := 1;
  while (LMask <> 0) and ((AValue and LMask) = 0) do
  begin
    Inc(Result);
    LMask := LMask shl 1;
  end;
end;

function PascalCtz64(AValue: UInt64): UInt32;
var
  LMask: UInt64;
begin
  Result := 0;
  LMask := 1;
  while (LMask <> 0) and ((AValue and LMask) = 0) do
  begin
    Inc(Result);
    LMask := LMask shl 1;
  end;
end;

function PascalPopCount32(AValue: UInt32): UInt32;
begin
  AValue := AValue - ((AValue shr 1) and $55555555);
  AValue := (AValue and $33333333) + ((AValue shr 2) and $33333333);
  AValue := (AValue + (AValue shr 4)) and $0F0F0F0F;
  Result := (AValue * $01010101) shr 24;
end;

function PascalPopCount64(AValue: UInt64): UInt32;
begin
  AValue := AValue - ((AValue shr 1) and $5555555555555555);
  AValue := (AValue and $3333333333333333) + ((AValue shr 2) and $3333333333333333);
  AValue := (AValue + (AValue shr 4)) and $0F0F0F0F0F0F0F0F;
  Result := UInt32((AValue * $0101010101010101) shr 56);
end;

function PascalLog2Floor32(AValue: UInt32): UInt32;
begin
  if AValue = 0 then Exit(0);
  Result := 0;
  while AValue > 1 do
  begin
    Inc(Result);
    AValue := AValue shr 1;
  end;
end;

function PascalBsr32(AValue: UInt32): UInt32;
begin
  if AValue = 0 then Exit(0);
  Result := 0;
  while AValue > 1 do
  begin
    Inc(Result);
    AValue := AValue shr 1;
  end;
end;

{ --- Benchmark input values (spread across bit widths) --- }
const
  VAL32: array[0..7] of UInt32 = (
    1, 42, 255, 1024, 65535, $00FF0000, $80000000, $FFFFFFFF
  );
  VAL64: array[0..7] of UInt64 = (
    1, 42, 255, 65535, $00000000FFFFFFFF, $00FF000000000000,
    $8000000000000000, $FFFFFFFFFFFFFFFF
  );

var
  GSink32: UInt32;
  GSink64: UInt32;

{ --- Bitops (native asm) benchmarks --- }

procedure BenchClz32_ASM(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink32 := Clz32(VAL32[I]);
end;

procedure BenchClz32_Pascal(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink32 := PascalClz32(VAL32[I]);
end;

procedure BenchClz64_ASM(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink64 := Clz64(VAL64[I]);
end;

procedure BenchClz64_Pascal(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink64 := PascalClz64(VAL64[I]);
end;

procedure BenchCtz32_ASM(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink32 := Ctz32(VAL32[I]);
end;

procedure BenchCtz32_Pascal(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink32 := PascalCtz32(VAL32[I]);
end;

procedure BenchCtz64_ASM(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink64 := Ctz64(VAL64[I]);
end;

procedure BenchCtz64_Pascal(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink64 := PascalCtz64(VAL64[I]);
end;

procedure BenchPopCount32_ASM(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink32 := PopCount32(VAL32[I]);
end;

procedure BenchPopCount32_Pascal(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink32 := PascalPopCount32(VAL32[I]);
end;

procedure BenchPopCount64_ASM(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink64 := PopCount64(VAL64[I]);
end;

procedure BenchPopCount64_Pascal(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink64 := PascalPopCount64(VAL64[I]);
end;

procedure BenchLog2Floor32_ASM(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink32 := Log2Floor32(VAL32[I]);
end;

procedure BenchLog2Floor32_Pascal(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to 7 do
    GSink32 := PascalLog2Floor32(VAL32[I]);
end;

{ --- Main --- }

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
  I: Integer;
  LAsmNs, LPascalNs, LSpeedup: Double;
begin
  LSuite := TBenchSuite.Create('bitops')
    .SetMinDuration(TDuration.FromMilliseconds(200))
    .SetMaxIterations(1000000)
    .SetMinSamples(8)
    .SetWarmupIters(5000);

  { Each benchmark processes 8 values per call for amortized timing. }
  LSuite.Add('clz32/asm',     @BenchClz32_ASM);
  LSuite.Add('clz32/pascal',  @BenchClz32_Pascal);
  LSuite.Add('clz64/asm',     @BenchClz64_ASM);
  LSuite.Add('clz64/pascal',  @BenchClz64_Pascal);
  LSuite.Add('ctz32/asm',     @BenchCtz32_ASM);
  LSuite.Add('ctz32/pascal',  @BenchCtz32_Pascal);
  LSuite.Add('ctz64/asm',     @BenchCtz64_ASM);
  LSuite.Add('ctz64/pascal',  @BenchCtz64_Pascal);
  LSuite.Add('popcnt32/asm',  @BenchPopCount32_ASM);
  LSuite.Add('popcnt32/pascal', @BenchPopCount32_Pascal);
  LSuite.Add('popcnt64/asm',  @BenchPopCount64_ASM);
  LSuite.Add('popcnt64/pascal', @BenchPopCount64_Pascal);
  LSuite.Add('log2_32/asm',   @BenchLog2Floor32_ASM);
  LSuite.Add('log2_32/pascal', @BenchLog2Floor32_Pascal);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== Bitops Benchmark: Native ASM vs Pure Pascal ===');
  WriteLn;
  WriteLn('Each call processes 8 values (amortized per-value timing).');
  WriteLn;

  LAll := LResults.GetAll;
  for I := 0 to Length(LAll) - 1 do
  begin
    WriteLn(LAll[I].Name: 25,
      '  ns/op=', FormatFloat('0.00', LAll[I].NsPerOp): 10,
      '  Mops/s=', FormatFloat('0.00', LAll[I].OpsPerSec / 1e6): 8,
      '  iters=', LAll[I].Iterations: 8);
  end;

  { Print speedup summary. }
  WriteLn;
  WriteLn('=== Speedup Summary (Pascal / ASM) ===');
  WriteLn;

  for I := 0 to Length(LAll) - 2 do
  begin
    if (I mod 2 = 0) and (I + 1 < Length(LAll)) then
    begin
      LAsmNs := LAll[I].NsPerOp;
      LPascalNs := LAll[I + 1].NsPerOp;
      if LAsmNs > 0 then
        LSpeedup := LPascalNs / LAsmNs
      else
        LSpeedup := 0;
      WriteLn(LAll[I].Name: 25,
        '  asm=', FormatFloat('0.00', LAsmNs): 8, ' ns',
        '  pascal=', FormatFloat('0.00', LPascalNs): 8, ' ns',
        '  speedup=', FormatFloat('0.00x', LSpeedup): 8);
    end;
  end;

  WriteLn;
  WriteLn('Done.');
end.
