program bench_simd_optimization_verify;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init, BaseUnix, Unix,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  nextpas.core.text.conv, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.scalar,
  nextpas.core.simd.dispatch;

const
  WARMUP = 100;
  ITERS = 5000;
  // 测试不同大小：小、中、大、超大
  SIZES: array[0..7] of SizeUInt = (64, 256, 1024, 4096, 16384, 65536, 131072, 262144);

var
  g_Dispatch: PSimdDispatchTable;

function GetNanoTime: Int64;
{$IFDEF UNIX}
var tv: TTimeVal;
begin
  fpgettimeofday(@tv, nil);
  Result := Int64(tv.tv_sec) * 1000000000 + Int64(tv.tv_usec) * 1000;
end;
{$ELSE}
var f, c: Int64;
begin
  QueryPerformanceFrequency(f);
  QueryPerformanceCounter(c);
  Result := c * 1000000000 div f;
end;
{$ENDIF}

procedure PrintResult(const aName: string; aSize: SizeUInt; aNsPerElem: Double);
var
  LMBps: Double;
begin
  // 3 streams: 2 reads + 1 write
  LMBps := (aSize * 4 * 3) / (aNsPerElem * 1e9) * 1e6;
  WriteLn(Format('  %-25s %8d elements: %8.2f ns/elem, %8.2f MB/s',
    [aName, aSize, aNsPerElem, LMBps]));
end;

// === Test SSE2 8x Unroll ===
procedure TestArrayAddF32_8xUnroll;
var
  LA, LB, LD: array of Single;
  i, j, warm, sizeIdx: Integer;
  t0, t1: Int64;
  nsPerElem: Double;
begin
  WriteLn('=== Test ArrayAddF32 8x Unroll ===');
  for sizeIdx := Low(SIZES) to High(SIZES) do
  begin
    SetLength(LA, SIZES[sizeIdx]);
    SetLength(LB, SIZES[sizeIdx]);
    SetLength(LD, SIZES[sizeIdx]);

    // 填充数据
    for i := 0 to SIZES[sizeIdx] - 1 do
    begin
      LA[i] := Sin(i * 0.7) * 50.0;
      LB[i] := Cos(i * 1.1) * 30.0 + 1.0;
    end;

    // Warmup
    for warm := 0 to WARMUP - 1 do
      g_Dispatch^.ArrayAddF32(@LA[0], @LB[0], @LD[0], SIZES[sizeIdx]);

    // Benchmark
    t0 := GetNanoTime;
    for j := 0 to ITERS - 1 do
      g_Dispatch^.ArrayAddF32(@LA[0], @LB[0], @LD[0], SIZES[sizeIdx]);
    t1 := GetNanoTime;

    nsPerElem := (t1 - t0) / ITERS / SIZES[sizeIdx];
    PrintResult('ArrayAddF32', SIZES[sizeIdx], nsPerElem);
  end;
  WriteLn;
end;

// === Test ArrayMulF32 8x Unroll ===
procedure TestArrayMulF32_8xUnroll;
var
  LA, LB, LD: array of Single;
  i, j, warm, sizeIdx: Integer;
  t0, t1: Int64;
  nsPerElem: Double;
begin
  WriteLn('=== Test ArrayMulF32 8x Unroll ===');
  for sizeIdx := Low(SIZES) to High(SIZES) do
  begin
    SetLength(LA, SIZES[sizeIdx]);
    SetLength(LB, SIZES[sizeIdx]);
    SetLength(LD, SIZES[sizeIdx]);

    for i := 0 to SIZES[sizeIdx] - 1 do
    begin
      LA[i] := Sin(i * 0.7) * 50.0;
      LB[i] := Cos(i * 1.1) * 30.0 + 1.0;
    end;

    for warm := 0 to WARMUP - 1 do
      g_Dispatch^.ArrayMulF32(@LA[0], @LB[0], @LD[0], SIZES[sizeIdx]);

    t0 := GetNanoTime;
    for j := 0 to ITERS - 1 do
      g_Dispatch^.ArrayMulF32(@LA[0], @LB[0], @LD[0], SIZES[sizeIdx]);
    t1 := GetNanoTime;

    nsPerElem := (t1 - t0) / ITERS / SIZES[sizeIdx];
    PrintResult('ArrayMulF32', SIZES[sizeIdx], nsPerElem);
  end;
  WriteLn;
end;

// === Test MemEqual 64-byte Batch ===
procedure TestMemEqual_64ByteBatch;
var
  LA, LB: array of Byte;
  i, j, warm, sizeIdx: Integer;
  t0, t1: Int64;
  nsPerElem: Double;
  match: Boolean;
begin
  WriteLn('=== Test MemEqual 64-byte Batch ===');
  for sizeIdx := Low(SIZES) to High(SIZES) do
  begin
    SetLength(LA, SIZES[sizeIdx]);
    SetLength(LB, SIZES[sizeIdx]);

    // 填充相同数据
    for i := 0 to SIZES[sizeIdx] - 1 do
    begin
      LA[i] := i mod 256;
      LB[i] := i mod 256;
    end;

    // Warmup
    for warm := 0 to WARMUP - 1 do
      match := g_Dispatch^.MemEqual(@LA[0], @LB[0], SIZES[sizeIdx]);

    // Benchmark
    t0 := GetNanoTime;
    for j := 0 to ITERS - 1 do
      match := g_Dispatch^.MemEqual(@LA[0], @LB[0], SIZES[sizeIdx]);
    t1 := GetNanoTime;

    nsPerElem := (t1 - t0) / ITERS / SIZES[sizeIdx];
    PrintResult('MemEqual', SIZES[sizeIdx], nsPerElem);
  end;
  WriteLn;
end;

// === Test ReduceMaxF32 ===
procedure TestReduceMaxF32;
var
  LA: array of Single;
  i, j, warm, sizeIdx: Integer;
  t0, t1: Int64;
  nsPerElem: Double;
  maxVal: Single;
begin
  WriteLn('=== Test ReduceMaxF32 ===');
  for sizeIdx := Low(SIZES) to High(SIZES) do
  begin
    SetLength(LA, SIZES[sizeIdx]);

    for i := 0 to SIZES[sizeIdx] - 1 do
      LA[i] := Sin(i * 0.7) * 50.0;

    for warm := 0 to WARMUP - 1 do
      maxVal := g_Dispatch^.ReduceMaxF32(@LA[0], SIZES[sizeIdx]);

    t0 := GetNanoTime;
    for j := 0 to ITERS - 1 do
      maxVal := g_Dispatch^.ReduceMaxF32(@LA[0], SIZES[sizeIdx]);
    t1 := GetNanoTime;

    nsPerElem := (t1 - t0) / ITERS / SIZES[sizeIdx];
    PrintResult('ReduceMaxF32', SIZES[sizeIdx], nsPerElem);
  end;
  WriteLn;
end;

// === Test U32 Batch Operations ===
procedure TestU32BatchOps;
var
  LA, LB, LD: array of UInt32;
  i, j, warm, sizeIdx: Integer;
  t0, t1: Int64;
  nsPerElem: Double;
begin
  WriteLn('=== Test U32 Batch Operations ===');
  for sizeIdx := Low(SIZES) to High(SIZES) do
  begin
    SetLength(LA, SIZES[sizeIdx]);
    SetLength(LB, SIZES[sizeIdx]);
    SetLength(LD, SIZES[sizeIdx]);

    for i := 0 to SIZES[sizeIdx] - 1 do
    begin
      LA[i] := i * 7 + 3;
      LB[i] := i * 13 + 5;
    end;

    // Test ArrayAddU32
    for warm := 0 to WARMUP - 1 do
      g_Dispatch^.ArrayAddU32(@LA[0], @LB[0], @LD[0], SIZES[sizeIdx]);

    t0 := GetNanoTime;
    for j := 0 to ITERS - 1 do
      g_Dispatch^.ArrayAddU32(@LA[0], @LB[0], @LD[0], SIZES[sizeIdx]);
    t1 := GetNanoTime;

    nsPerElem := (t1 - t0) / ITERS / SIZES[sizeIdx];
    PrintResult('ArrayAddU32', SIZES[sizeIdx], nsPerElem);

    // Test ArrayMulU32
    for warm := 0 to WARMUP - 1 do
      g_Dispatch^.ArrayMulU32(@LA[0], @LB[0], @LD[0], SIZES[sizeIdx]);

    t0 := GetNanoTime;
    for j := 0 to ITERS - 1 do
      g_Dispatch^.ArrayMulU32(@LA[0], @LB[0], @LD[0], SIZES[sizeIdx]);
    t1 := GetNanoTime;

    nsPerElem := (t1 - t0) / ITERS / SIZES[sizeIdx];
    PrintResult('ArrayMulU32', SIZES[sizeIdx], nsPerElem);
  end;
  WriteLn;
end;

// === Test Non-Temporal Store (Smart) ===
procedure TestNonTemporalStore;
var
  LA, LB, LD: array of Single;
  i, j, warm, sizeIdx: Integer;
  t0, t1: Int64;
  nsPerElem: Double;
  // 只测试大数组 (>64KB)
  largeSizes: array[0..3] of SizeUInt = (16384, 65536, 131072, 262144);
begin
  WriteLn('=== Test Non-Temporal Store (Smart) ===');
  for sizeIdx := Low(largeSizes) to High(largeSizes) do
  begin
    SetLength(LA, largeSizes[sizeIdx]);
    SetLength(LB, largeSizes[sizeIdx]);
    SetLength(LD, largeSizes[sizeIdx]);

    for i := 0 to largeSizes[sizeIdx] - 1 do
    begin
      LA[i] := Sin(i * 0.7) * 50.0;
      LB[i] := Cos(i * 1.1) * 30.0 + 1.0;
    end;

    // Test Smart dispatch (should use NT for large arrays)
    for warm := 0 to WARMUP - 1 do
      g_Dispatch^.ArrayAddF32(@LA[0], @LB[0], @LD[0], largeSizes[sizeIdx]);

    t0 := GetNanoTime;
    for j := 0 to ITERS - 1 do
      g_Dispatch^.ArrayAddF32(@LA[0], @LB[0], @LD[0], largeSizes[sizeIdx]);
    t1 := GetNanoTime;

    nsPerElem := (t1 - t0) / ITERS / largeSizes[sizeIdx];
    PrintResult('ArrayAddF32 (Smart)', largeSizes[sizeIdx], nsPerElem);
  end;
  WriteLn;
end;

// === Main ===
begin
  WriteLn('=== SIMD Optimization Verification Benchmark ===');
  WriteLn('Testing: 8x Unroll, Prefetch, Non-Temporal Store, 64-byte Batch');
  WriteLn;

  // 获取 dispatch table
  g_Dispatch := GetDispatchTable;

  // 运行所有测试
  TestArrayAddF32_8xUnroll;
  TestArrayMulF32_8xUnroll;
  TestMemEqual_64ByteBatch;
  TestReduceMaxF32;
  TestU32BatchOps;
  TestNonTemporalStore;

  WriteLn('=== Benchmark Complete ===');
end.
