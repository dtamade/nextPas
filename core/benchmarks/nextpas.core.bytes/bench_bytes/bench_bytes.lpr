program bench_bytes;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.builder;

const
  ITERS_SMALL = 1000000;
  ITERS_LARGE = 1000;
  SIZE_1MB = 1024 * 1024;

procedure Bench(const AName: string; const AIters: Int64; const AElapsed: TDuration);
var
  LNs: Int64;
  LNsPerOp: Double;
begin
  LNs := AElapsed.AsNanoseconds;
  if AIters > 0 then
    LNsPerOp := LNs / AIters
  else
    LNsPerOp := 0;
  WriteLn(Format('  %-35s %10d iters  %8.2f ms  %8.1f ns/op',
    [AName, AIters, LNs / 1000000.0, LNsPerOp]));
end;

procedure BenchThroughput(const AName: string; const ABytes: Int64; const AElapsed: TDuration);
var
  LNs: Int64;
  LMBps: Double;
begin
  LNs := AElapsed.AsNanoseconds;
  if LNs > 0 then
    LMBps := (ABytes / (1024.0 * 1024.0)) / (LNs / 1000000000.0)
  else
    LMBps := 0;
  WriteLn(Format('  %-35s %10d bytes  %8.2f ms  %8.1f MB/s',
    [AName, ABytes, LNs / 1000000.0, LMBps]));
end;

procedure BenchSpanEqual;
var
  LA, LB: TBytes;
  LSA, LSB: TByteSpan;
  LI: Integer;
  LStart: TInstant;
  LDummy: Boolean;
begin
  SetLength(LA, 1024);
  SetLength(LB, 1024);
  for LI := 0 to 1023 do
  begin
    LA[LI] := Byte(LI and $FF);
    LB[LI] := Byte(LI and $FF);
  end;
  LSA := TByteSpan.FromBytes(LA);
  LSB := TByteSpan.FromBytes(LB);
  LStart := TInstant.Now;
  for LI := 1 to ITERS_SMALL do
    LDummy := SpanEqual(LSA, LSB);
  Bench('SpanEqual 1KB', ITERS_SMALL, LStart.Elapsed);
end;

procedure BenchSpanIndexOf;
var
  LD: TBytes;
  LS: TByteSpan;
  LI: Integer;
  LStart: TInstant;
  LDummy: SizeInt;
begin
  SetLength(LD, 4096);
  for LI := 0 to 4095 do
    LD[LI] := Byte(LI and $FF);
  LD[4095] := $FE;
  LS := TByteSpan.FromBytes(LD);
  LStart := TInstant.Now;
  for LI := 1 to ITERS_SMALL do
    LDummy := SpanIndexOf(LS, $FE);
  Bench('SpanIndexOf 4KB (worst)', ITERS_SMALL, LStart.Elapsed);
end;

procedure BenchSwapUInt64;
var
  LI: Integer;
  LStart: TInstant;
  LVal: UInt64;
begin
  LVal := $0102030405060708;
  LStart := TInstant.Now;
  for LI := 1 to ITERS_SMALL * 10 do
    LVal := SwapUInt64(LVal);
  Bench('SwapUInt64', ITERS_SMALL * 10, LStart.Elapsed);
end;

procedure BenchReadUInt32LE;
var
  LBuf: array[0..1023] of Byte;
  LI: Integer;
  LStart: TInstant;
  LDummy: UInt32;
begin
  for LI := 0 to 1023 do
    LBuf[LI] := Byte(LI);
  LStart := TInstant.Now;
  for LI := 1 to ITERS_SMALL * 10 do
    LDummy := ReadUInt32LE(@LBuf[(LI * 4) and 1020]);
  Bench('ReadUInt32LE', ITERS_SMALL * 10, LStart.Elapsed);
end;

procedure BenchBuilderAppend1MB;
var
  LB: IBytesBuilder;
  LData: array[0..4095] of Byte;
  LI: Integer;
  LStart: TInstant;
begin
  for LI := 0 to 4095 do
    LData[LI] := Byte(LI and $FF);
  LStart := TInstant.Now;
  for LI := 1 to ITERS_LARGE do
  begin
    LB := CreateBytesBuilder(SIZE_1MB);
    while LB.Length < SIZE_1MB do
      LB.AppendBytes(@LData[0], 4096);
  end;
  BenchThroughput('Builder append 4KB chunks x1MB', Int64(ITERS_LARGE) * SIZE_1MB, LStart.Elapsed);
end;

procedure BenchBuilderAppendByte;
var
  LB: IBytesBuilder;
  LI, LJ: Integer;
  LStart: TInstant;
begin
  LStart := TInstant.Now;
  for LI := 1 to 100 do
  begin
    LB := CreateBytesBuilder(65536);
    for LJ := 0 to 65535 do
      LB.AppendByte(Byte(LJ));
  end;
  BenchThroughput('Builder AppendByte 64KB', Int64(100) * 65536, LStart.Elapsed);
end;

procedure BenchTryReadCursor;
var
  LD: TBytes;
  LS: TByteSpan;
  LI: Integer;
  LStart: TInstant;
  LVal: UInt32;
  LCount: Int64;
begin
  SetLength(LD, 4096);
  for LI := 0 to 4095 do
    LD[LI] := Byte(LI);
  LCount := 0;
  LStart := TInstant.Now;
  for LI := 1 to ITERS_SMALL do
  begin
    LS := TByteSpan.FromBytes(LD);
    while TryReadUInt32LE(LS, LVal) do
      Inc(LCount);
  end;
  Bench(Format('TryReadUInt32LE cursor 4KB (%d reads)', [LCount]), ITERS_SMALL, LStart.Elapsed);
end;

begin
  WriteLn('=== nextpas.core.bytes benchmarks ===');
  WriteLn('');

  BenchSpanEqual;
  BenchSpanIndexOf;
  BenchSwapUInt64;
  BenchReadUInt32LE;
  BenchBuilderAppend1MB;
  BenchBuilderAppendByte;
  BenchTryReadCursor;

  WriteLn('');
  WriteLn('Done.');
end.
