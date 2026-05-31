program bench_instant;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.time.base;

var
  B: TBenchRunner;
  GSink: UInt64;

procedure BenchInstantNow(aIters: Int64);
var
  LIt: Int64;
  LInst: TInstant;
begin
  for LIt := 1 to aIters do
    LInst := TInstant.Now;
  GSink := UInt64(LInst.Elapsed.AsNanoseconds);
end;

procedure BenchInstantElapsed(aIters: Int64);
var
  LIt: Int64;
  LStart: TInstant;
  LDur: TDuration;
begin
  LStart := TInstant.Now;
  for LIt := 1 to aIters do
    LDur := LStart.Elapsed;
  GSink := UInt64(LDur.AsNanoseconds);
end;

procedure BenchDurationAdd(aIters: Int64);
var
  LIt: Int64;
  LD: TDuration;
begin
  LD := TDuration.FromNanoseconds(0);
  for LIt := 1 to aIters do
    LD := TDuration.FromNanoseconds(LD.AsNanoseconds + 1);
  GSink := UInt64(LD.AsNanoseconds);
end;

procedure BenchDurationFromMs(aIters: Int64);
var
  LIt: Int64;
  LD: TDuration;
begin
  for LIt := 1 to aIters do
    LD := TDuration.FromMilliseconds(LIt);
  GSink := UInt64(LD.AsNanoseconds);
end;

procedure BenchDeadlineCheck(aIters: Int64);
var
  LIt: Int64;
  LDeadline: TInstant;
  LNow: TInstant;
  LExpired: Boolean;
begin
  LDeadline := TInstant.Now.Add(TDuration.FromSeconds(60));
  for LIt := 1 to aIters do
  begin
    LNow := TInstant.Now;
    LExpired := LNow.DurationSince(LDeadline).AsNanoseconds > 0;
  end;
  GSink := Ord(LExpired);
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.time benchmark ===');
  WriteLn;
  B.Run('TInstant.Now', @BenchInstantNow);
  B.Run('TInstant.Elapsed', @BenchInstantElapsed);
  B.Run('TDuration arithmetic', @BenchDurationAdd);
  B.Run('TDuration.FromMilliseconds', @BenchDurationFromMs);
  B.Run('Deadline check (Now + compare)', @BenchDeadlineCheck);
  WriteLn;
  B.Summary;
  B.Free;
end.
