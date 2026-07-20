program bench_process;

{ Minimal host process scorecard harness (LookPath / Status / Capture). }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.time.base,
  nextpas.core.process,
  nextpas.core.process.base,
  nextpas.core.process.command,
  nextpas.core.text.conv;

var
  GSink: Int64;

procedure Report(const AName: string; const AN: Integer; const ANs: Int64);
begin
  WriteLn(AName, ': n=', AN, ' total_ms=', ANs div 1000000,
    ' avg_us=', (ANs div AN) div 1000);
end;

var
  I: Integer;
  LStart: TInstant;
  LNs: Int64;
  L: string;
  O: TProcessOutput;
  S: string;
begin
  WriteLn('=== nextpas process scorecard (host-linux) ===');
  GSink := 0;

  LStart := TInstant.Now;
  for I := 1 to 200 do
  begin
    L := LookPath('sh');
    if L = '' then
      L := LookPath('true');
    GSink := GSink + Length(L);
  end;
  LNs := TInstant.Now.DurationSince(LStart).AsNanoseconds;
  Report('LookPath(sh)', 200, LNs);

  LStart := TInstant.Now;
  for I := 1 to 50 do
  begin
    O := Command('/bin/true').Status;
    GSink := GSink + O.ExitCode;
  end;
  LNs := TInstant.Now.DurationSince(LStart).AsNanoseconds;
  Report('Command(/bin/true).Status', 50, LNs);

  LStart := TInstant.Now;
  for I := 1 to 50 do
  begin
    S := Capture('/bin/echo', ['x']);
    GSink := GSink + Length(S);
  end;
  LNs := TInstant.Now.DurationSince(LStart).AsNanoseconds;
  Report('Capture(echo x)', 50, LNs);

  WriteLn('sink=', GSink);
end.
