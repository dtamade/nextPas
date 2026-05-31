program test_process;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.process;

var
  LResult: TProcessResult;
  LPassed, LFailed: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  PASS: ', AName);
    Inc(LPassed);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Inc(LFailed);
  end;
end;

begin
  LPassed := 0;
  LFailed := 0;

  WriteLn('--- nextpas.core.process tests ---');

  LResult := Execute('/bin/echo', ['hello', 'world']);
  Check('echo exits 0', LResult.Success);
  Check('echo stdout', Pos('hello world', LResult.StdOut) > 0);
  Check('echo exitcode', LResult.ExitCode = 0);

  LResult := Execute('/bin/false', []);
  Check('false exits non-zero', not LResult.Success);
  Check('false exitcode', LResult.ExitCode <> 0);

  LResult := Execute('/bin/ls', ['/nonexistent_path_xyz']);
  Check('ls bad path fails', not LResult.Success);
  Check('ls stderr not empty', Length(LResult.StdErr) > 0);

  LResult := Execute('/bin/pwd', [], '/tmp');
  Check('pwd with workdir', Pos('/tmp', LResult.StdOut) > 0);

  WriteLn('');
  WriteLn('--- ', LPassed, ' passed, ', LFailed, ' failed ---');
  if LFailed > 0 then
    Halt(1);
end.
