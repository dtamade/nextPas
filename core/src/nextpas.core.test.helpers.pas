{ nextpas.core.test.helpers — Shared test helpers for failure-path testing
  =========================================================
  Depends on: nextpas.core.test.base, nextpas.core.test.check }

unit nextpas.core.test.helpers;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.test.base,
  nextpas.core.test.check;

{ Call AProc, expecting EAssertionFailed.
  If AContains <> '', verify the message contains that substring.
  Fails the test if no exception was raised. }
procedure ExpectFail(AProc: TTestClosure;
  const AContains: string = '');

implementation

procedure ExpectFail(AProc: TTestClosure;
  const AContains: string);
begin
  try
    AProc;
    Fail('expected assertion failure');
  except
    on E: EAssertionFailed do
      if AContains <> '' then
        Check(Pos(AContains, E.Message) > 0,
          'expected "' + AContains + '" in "' + E.Message + '"');
  end;
end;

end.
