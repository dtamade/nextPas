program bench_process_spawn;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.process;

const
  WARMUP_ITERS = 50;
  DUR = 2000;

{$IFDEF LINUX}
function ClockGetTimeNs: Int64;
var
  LBuf: array[0..1] of Int64;
  LPtr: Pointer;
begin
  LBuf[0] := 0; LBuf[1] := 0;
  LPtr := @LBuf[0];
  asm
    movq $1, %rdi
    movq LPtr, %rsi
    movq $228, %rax
    syscall
  end ['rax', 'rdi', 'rsi', 'rdx', 'rcx', 'r11'];
  Result := LBuf[0] * 1000000000 + LBuf[1];
end;
{$ELSE}
function ClockGetTimeNs: Int64;
var
  LTs: TTimeStamp;
begin
  LTs := DateTimeToTimeStamp(Now);
  Result := (Int64(LTs.Date) * 86400000 + LTs.Time) * 1000000;
end;
{$ENDIF}

procedure PrintResult(const AName: string; const AIterations: UInt64;
  const AElapsedNs: Int64; const ABytes: UInt64);
var
  LNsPerOp: Double;
  LMBps: Double;
begin
  if AIterations > 0 then
    LNsPerOp := AElapsedNs / AIterations
  else
    LNsPerOp := 0;
  if (ABytes > 0) and (AElapsedNs > 0) then
  begin
    LMBps := (ABytes / 1048576.0) / (AElapsedNs / 1000000000.0);
    WriteLn(Format('  %-40s %8d iters  %8.2f ms  %10.1f ns/op  %10.1f MB/s',
      [AName, AIterations, AElapsedNs / 1000000.0, LNsPerOp, LMBps]));
  end
  else
    WriteLn(Format('  %-40s %8d iters  %8.2f ms  %10.1f ns/op',
      [AName, AIterations, AElapsedNs / 1000000.0, LNsPerOp]));
end;

{ T20: BenchSpawnWait — spawn /bin/true + wait }
procedure BenchSpawnWait(ADurationMs: Integer);
var
  LOutput: TProcessOutput;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  I: Integer;
begin
  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
    LOutput := Run('/bin/true', []);

  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    LOutput := Run('/bin/true', []);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintResult('SpawnWait /bin/true', LIters, LElapsedNs, 0);
  if LOutput.ExitCode <> 0 then;
end;

{ T21: BenchPipeThroughput — pipe stdout 吞吐量 }
procedure BenchPipeThroughput(ASize: Integer; ADurationMs: Integer);
var
  LOutput: TProcessOutput;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  LBytes: UInt64;
  LSizeArg: string;
  I: Integer;
begin
  LSizeArg := IntToStr(ASize);

  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
    LOutput := Run('/bin/dd', ['if=/dev/zero', 'bs=' + LSizeArg,
      'count=1', 'status=none']);

  LBytes := 0;
  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    LOutput := Run('/bin/dd', ['if=/dev/zero', 'bs=' + LSizeArg,
      'count=1', 'status=none']);
    Inc(LBytes, ASize);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintResult('PipeThroughput dd bs=' + LSizeArg, LIters, LElapsedNs, LBytes);
  if LOutput.ExitCode <> 0 then;
end;

{ T22: BenchCaptureSize — Capture 不同大小输出 }
procedure BenchCaptureSize(ASize: Integer; ADurationMs: Integer);
var
  LOutput: string;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  LBytes: UInt64;
  LSizeArg: string;
  I: Integer;
begin
  LSizeArg := IntToStr(ASize);

  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
    LOutput := Capture('/bin/dd', ['if=/dev/zero', 'bs=' + LSizeArg,
      'count=1', 'status=none']);

  LBytes := 0;
  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    LOutput := Capture('/bin/dd', ['if=/dev/zero', 'bs=' + LSizeArg,
      'count=1', 'status=none']);
    Inc(LBytes, ASize);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintResult('CaptureSize dd bs=' + LSizeArg, LIters, LElapsedNs, LBytes);
  if Length(LOutput) = 0 then;
end;

{ T23: BenchRun100Sequential — 连续 100 次 Run /bin/true }
procedure BenchRun100Sequential(ADurationMs: Integer);
var
  LOutput: TProcessOutput;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  LRounds: UInt64;
  I, J: Integer;
begin
  { 预热 }
  for I := 0 to 2 do
    for J := 0 to 99 do
      LOutput := Run('/bin/true', []);

  LRounds := 0;
  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    for J := 0 to 99 do
      LOutput := Run('/bin/true', []);
    Inc(LIters, 100);
    Inc(LRounds);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintResult('Run100Sequential /bin/true (x100)', LIters, LElapsedNs, 0);
  if LOutput.ExitCode <> 0 then;
end;

const
  DURATION = 2000;

begin
  WriteLn('=== nextpas.core.process Benchmarks ===');
  WriteLn;

  WriteLn('--- SpawnWait ---');
  BenchSpawnWait(DURATION);

  WriteLn;
  WriteLn('--- PipeThroughput ---');
  BenchPipeThroughput(1024, DURATION);
  BenchPipeThroughput(65536, DURATION);
  BenchPipeThroughput(1048576, DURATION);

  WriteLn;
  WriteLn('--- CaptureSize ---');
  BenchCaptureSize(1024, DURATION);
  BenchCaptureSize(65536, DURATION);
  BenchCaptureSize(1048576, DURATION);

  WriteLn;
  WriteLn('--- Run100Sequential ---');
  BenchRun100Sequential(DURATION);

  WriteLn;
  WriteLn('Done.');
end.
