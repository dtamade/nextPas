program bench_alloc;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem,
  nextpas.core.text.conv,
  nextpas.core.text.format,
  nextpas.core.platform.time;

const
  WARMUP_ITERS = 1000;
  BENCH_ITERS  = 100000;

var
  GSink: Pointer;

procedure Report(const AName: string; AIterations: Integer;
  AElapsedNs: TPlatformTimeNanoseconds);
var
  LNsPerOp: Double;
  LOpsPerSec: Double;
begin
  LNsPerOp := AElapsedNs / AIterations;
  LOpsPerSec := AIterations / (AElapsedNs / 1e9);
  WriteLn(TextFormat('  %-40s %10.1f ns/op  %12.0f ops/s',
    [AName, LNsPerOp, LOpsPerSec]));
end;

procedure BenchAllocator_GetMem(ASize: SizeUInt);
var
  LA: IAllocator;
  LStart, LEnd: TPlatformTimeNanoseconds;
  LP: Pointer;
  I: Integer;
  LName: string;
begin
  LA := DefaultAllocator;

  { Warmup }
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    LP := LA.GetMem(ASize);
    LA.FreeMem(LP);
  end;

  LStart := platform_monotonic_ns;
  for I := 0 to BENCH_ITERS - 1 do
  begin
    LP := LA.GetMem(ASize);
    LA.FreeMem(LP);
  end;
  LEnd := platform_monotonic_ns;
  GSink := LP;

  LName := 'IAllocator.GetMem(' + IntToStr(ASize) + ')';
  Report(LName, BENCH_ITERS, LEnd - LStart);
end;

procedure BenchRaw_GetMem(ASize: SizeUInt);
var
  LStart, LEnd: TPlatformTimeNanoseconds;
  LP: Pointer;
  I: Integer;
  LName: string;
begin
  { Warmup }
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    LP := GetMem(ASize);
    FreeMem(LP);
  end;

  LStart := platform_monotonic_ns;
  for I := 0 to BENCH_ITERS - 1 do
  begin
    LP := GetMem(ASize);
    FreeMem(LP);
  end;
  LEnd := platform_monotonic_ns;
  GSink := LP;

  LName := 'Raw GetMem(' + IntToStr(ASize) + ') baseline';
  Report(LName, BENCH_ITERS, LEnd - LStart);
end;

procedure BenchAllocator_AllocZeroed(ASize: SizeUInt);
var
  LA: IAllocator;
  LStart, LEnd: TPlatformTimeNanoseconds;
  LP: Pointer;
  I: Integer;
  LName: string;
begin
  LA := DefaultAllocator;

  { Warmup }
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    LP := AllocZeroed(LA, ASize);
    LA.FreeMem(LP);
  end;

  LStart := platform_monotonic_ns;
  for I := 0 to BENCH_ITERS - 1 do
  begin
    LP := AllocZeroed(LA, ASize);
    LA.FreeMem(LP);
  end;
  LEnd := platform_monotonic_ns;
  GSink := LP;

  LName := 'AllocZeroed(' + IntToStr(ASize) + ')';
  Report(LName, BENCH_ITERS, LEnd - LStart);
end;

begin
  WriteLn('=== nextpas.core.mem allocator benchmark ===');
  WriteLn;

  BenchAllocator_GetMem(64);
  BenchAllocator_GetMem(256);
  BenchAllocator_GetMem(4096);
  WriteLn;
  BenchAllocator_AllocZeroed(64);
  WriteLn;
  BenchRaw_GetMem(64);
  BenchRaw_GetMem(4096);

  WriteLn;
  WriteLn('Done.');
end.
