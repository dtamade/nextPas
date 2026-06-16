program nextpas.core.simd.bench_transcendental;

{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  cthreads, Unix,
  {$ENDIF}
  nextpas.core.text.conv, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

const
  N = 4096;
  ITERS = 10000;

var
  Src, Dst: array[0..N-1] of Single;

function GetTimeUs: Int64;
var tv: timeval;
begin
  fpgettimeofday(@tv, nil);
  Result := Int64(tv.tv_sec) * 1000000 + tv.tv_usec;
end;

type
  TBatchProc = procedure(s, d: PSingle; c: SizeUInt);

procedure Bench(const aName: string; aProc: TBatchProc);
var
  i: Integer;
  t0, t1: Int64;
  ns_per_elem: Double;
begin
  // Warmup
  for i := 0 to 2 do aProc(@Src[0], @Dst[0], N);

  t0 := GetTimeUs;
  for i := 0 to ITERS - 1 do
    aProc(@Src[0], @Dst[0], N);
  t1 := GetTimeUs;

  ns_per_elem := (t1 - t0) * 1000.0 / (Int64(ITERS) * N);
  WriteLn(Format('  %-18s %6.2f ns/elem', [aName, ns_per_elem]));
end;

procedure DoExp(s, d: PSingle; c: SizeUInt);
begin ArrayExpF32(s, d, c); end;

procedure DoLog(s, d: PSingle; c: SizeUInt);
begin ArrayLogF32(s, d, c); end;

procedure DoSin(s, d: PSingle; c: SizeUInt);
begin ArraySinF32(s, d, c); end;

procedure DoCos(s, d: PSingle; c: SizeUInt);
begin ArrayCosF32(s, d, c); end;

var i: Integer;
begin
  WriteLn('[Transcendental Benchmark] N=', N, ' ITERS=', ITERS);
  WriteLn('  Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  for i := 0 to N - 1 do
    Src[i] := (i - N div 2) * 0.01;

  Bench('ArrayExpF32', @DoExp);
  Bench('ArrayLogF32', @DoLog);

  for i := 0 to N - 1 do
    Src[i] := Abs(Src[i]) + 0.01;
  Bench('ArrayLogF32(pos)', @DoLog);

  for i := 0 to N - 1 do
    Src[i] := (i - N div 2) * 0.1;
  Bench('ArraySinF32', @DoSin);
  Bench('ArrayCosF32', @DoCos);

  WriteLn('');
  WriteLn('[DONE]');
end.
