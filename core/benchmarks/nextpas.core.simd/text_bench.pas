program text_bench;

{$mode objfpc}{$H+}
{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.time.cpu,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.base,
  nextpas.core.simd.runtime,
  nextpas.core.simd.api.v2;

const
  BUF_SIZE = 1024 * 1024;
  WARMUP = 3;
  ITERS = 10;
  REPS = 10;

function GetTimeMs: Int64;
begin
  Result := GetTickCount64;
end;

function MedianOf(const aTimes: array of Int64; aCount: Integer): Double;
var i, j: Integer; LTmp: Int64; LSorted: array[0..31] of Int64;
begin
  for i := 0 to aCount - 1 do LSorted[i] := aTimes[i];
  for i := 0 to aCount - 2 do
    for j := i + 1 to aCount - 1 do
      if LSorted[j] < LSorted[i] then
      begin LTmp := LSorted[i]; LSorted[i] := LSorted[j]; LSorted[j] := LTmp; end;
  Result := LSorted[aCount div 2];
end;

var
  LAscii, LMixed, LDst: PByte;
  i: Integer;
  LTimes: array[0..31] of Int64;
  t0: Int64;
  r: Integer;
  LDummy: Boolean;
  b: Integer;
  LBackends: array[0..2] of TSimdBackend;
  LNames: array[0..2] of string;
  LAsciiMs, LMixedMs, LCopyMs: array[0..2] of Double;
begin
  LBackends[0] := sbScalar; LBackends[1] := sbSSE2; LBackends[2] := sbAVX2;
  LNames[0] := 'Scalar'; LNames[1] := 'SSE2'; LNames[2] := 'AVX2';

  WriteLn('=== Text/Memory SIMD Benchmark (1MB buffers) ===');
  WriteLn;

  LAscii := PByte(SimdAlloc(BUF_SIZE));
  LMixed := PByte(SimdAlloc(BUF_SIZE));
  LDst := PByte(SimdAlloc(BUF_SIZE));

  for i := 0 to BUF_SIZE - 1 do
    LAscii[i] := 32 + (i mod 95);

  for i := 0 to BUF_SIZE - 1 do
    LMixed[i] := 32 + (i mod 95);
  // Insert Chinese characters every 100 bytes
  i := 0;
  while i + 2 < BUF_SIZE do
  begin
    LMixed[i] := $E4; LMixed[i+1] := $B8; LMixed[i+2] := $AD;
    Inc(i, 100);
  end;

  for b := 0 to 2 do
  begin
    if not TrySetCurrentBackend(LBackends[b]) then
    begin
      LAsciiMs[b] := -1; LMixedMs[b] := -1;
      Continue;
    end;
    WriteLn('--- Backend: ', LNames[b], ' ---');

    // Bench Utf8Validate on pure ASCII
    for i := 0 to WARMUP - 1 do LDummy := Utf8Validate(LAscii, BUF_SIZE);
    for i := 0 to ITERS - 1 do
    begin
      t0 := GetTimeMs;
      for r := 0 to REPS - 1 do LDummy := Utf8Validate(LAscii, BUF_SIZE);
      LTimes[i] := GetTimeMs - t0;
    end;
    LAsciiMs[b] := MedianOf(LTimes, ITERS) / REPS;
    WriteLn(Format('  Utf8Validate ASCII 1MB:  %6.2f ms  (%5.1f GB/s)', [
      LAsciiMs[b], (BUF_SIZE / (1024*1024*1024)) / (LAsciiMs[b] / 1000)]));

    // Bench Utf8Validate on mixed UTF-8
    for i := 0 to WARMUP - 1 do LDummy := Utf8Validate(LMixed, BUF_SIZE);
    for i := 0 to ITERS - 1 do
    begin
      t0 := GetTimeMs;
      for r := 0 to REPS - 1 do LDummy := Utf8Validate(LMixed, BUF_SIZE);
      LTimes[i] := GetTimeMs - t0;
    end;
    LMixedMs[b] := MedianOf(LTimes, ITERS) / REPS;
    WriteLn(Format('  Utf8Validate Mixed 1MB:  %6.2f ms  (%5.1f GB/s)', [
      LMixedMs[b], (BUF_SIZE / (1024*1024*1024)) / (LMixedMs[b] / 1000)]));

    // Bench MemCopy 1MB
    for i := 0 to WARMUP - 1 do MemCopy(LAscii, LDst, BUF_SIZE);
    for i := 0 to ITERS - 1 do
    begin
      t0 := GetTimeMs;
      for r := 0 to REPS - 1 do MemCopy(LAscii, LDst, BUF_SIZE);
      LTimes[i] := GetTimeMs - t0;
    end;
    LCopyMs[b] := MedianOf(LTimes, ITERS) / REPS;
    WriteLn(Format('  MemCopy 1MB:             %6.2f ms  (%5.1f GB/s)', [
      LCopyMs[b], (BUF_SIZE / (1024*1024*1024)) / (LCopyMs[b] / 1000)]));
    WriteLn;
  end;

  ResetCurrentBackendSelection;
  if LDummy then ;

  WriteLn('=== Summary ===');
  WriteLn(Format('%-25s %10s %10s %10s %10s', ['Operation', 'Scalar', 'SSE2', 'AVX2', 'Speedup']));
  WriteLn(StringOfChar('-', 67));
  if (LAsciiMs[0] > 0) and (LAsciiMs[2] > 0) then
    WriteLn(Format('%-25s %8.2fms %8.2fms %8.2fms %8.1fx', [
      'Utf8Validate ASCII', LAsciiMs[0], LAsciiMs[1], LAsciiMs[2], LAsciiMs[0]/LAsciiMs[2]]));
  if (LMixedMs[0] > 0) and (LMixedMs[2] > 0) then
    WriteLn(Format('%-25s %8.2fms %8.2fms %8.2fms %8.1fx', [
      'Utf8Validate Mixed', LMixedMs[0], LMixedMs[1], LMixedMs[2], LMixedMs[0]/LMixedMs[2]]));
  if (LCopyMs[0] > 0) and (LCopyMs[2] > 0) then
    WriteLn(Format('%-25s %8.2fms %8.2fms %8.2fms %8.1fx', [
      'MemCopy 1MB', LCopyMs[0], LCopyMs[1], LCopyMs[2], LCopyMs[0]/LCopyMs[2]]));

  SimdFree(LAscii);
  SimdFree(LMixed);
  SimdFree(LDst);
end.
