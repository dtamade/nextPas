program test_base;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.mem.base;

var
  LPassed, LFailed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(LFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

begin
  LPassed := 0;
  LFailed := 0;

  WriteLn('=== test_base ===');

  { Basic smoke test: mem.base types are accessible }
  Check(True, 'mem.base unit loads');

  WriteLn;
  WriteLn(LPassed, ' passed, ', LFailed, ' failed');
  if LFailed > 0 then
    ExitCode := 1;
end.
