{ DEPRECATED: Use nextpas.core.test instead.
  This unit is kept for backward compatibility with existing callers.
  Check/CheckEqual/Fail delegate to nextpas.core.test.check for consistent
  error messages and behavior (StringDiff, stack traces, etc.). }

unit nextpas.core.testing;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.test.check;

type
  TTestProc = procedure;
  TTestClosure = reference to procedure;

  TTestRunner = record
  private
    FTotal: Integer;
    FPassed: Integer;
    FFailed: Integer;
    FSuiteName: string;
  public
    class function Create(const ASuiteName: string): TTestRunner; static;
    procedure Run(const AName: string; AProc: TTestProc);
    procedure Summary;
    function AllPassed: Boolean;
  end;

{ Re-exported from nextpas.core.test.check }
procedure Check(const ACondition: Boolean; const AMessage: string = '');
procedure Fail(const AMessage: string);

{ 3-arg overloads for backward compat — delegates to test.check internally }
procedure CheckEqual(const AExpected, AActual: string;
  const AMessage: string = ''); overload;
procedure CheckEqual(const AExpected, AActual: Int64;
  const AMessage: string = ''); overload;
procedure CheckEqual(const AExpected, AActual: Boolean;
  const AMessage: string = ''); overload;

implementation

{ Wraps a 2-arg CheckEqual call, prepending AMessage on assertion failure. }
procedure CheckEqualWithMsg(const AMessage: string; AProc: TTestClosure);
begin
  try
    AProc;
  except
    on E: EAssertionFailed do
      if AMessage <> '' then
        raise EAssertionFailed.Create(AMessage + ': ' + E.Message)
      else
        raise;
  end;
end;

{ Forward to nextpas.core.test.check }

procedure Check(const ACondition: Boolean; const AMessage: string);
begin nextpas.core.test.check.Check(ACondition, AMessage); end;

procedure Fail(const AMessage: string);
begin nextpas.core.test.check.Fail(AMessage); end;

procedure CheckEqual(const AExpected, AActual: string;
  const AMessage: string);
begin
  CheckEqualWithMsg(AMessage, procedure
    begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end);
end;

procedure CheckEqual(const AExpected, AActual: Int64;
  const AMessage: string);
begin
  CheckEqualWithMsg(AMessage, procedure
    begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end);
end;

procedure CheckEqual(const AExpected, AActual: Boolean;
  const AMessage: string);
begin
  CheckEqualWithMsg(AMessage, procedure
    begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end);
end;

{ TTestRunner }

class function TTestRunner.Create(const ASuiteName: string): TTestRunner;
begin
  Result.FSuiteName := ASuiteName;
  Result.FTotal := 0;
  Result.FPassed := 0;
  Result.FFailed := 0;
  WriteLn('=== ', ASuiteName, ' ===');
end;

procedure TTestRunner.Run(const AName: string; AProc: TTestProc);
begin
  Inc(FTotal);
  try
    AProc;
    Inc(FPassed);
    WriteLn('  PASS: ', AName);
  except
    on E: Exception do
    begin
      Inc(FFailed);
      WriteLn('  FAIL: ', AName, ' - ', E.Message);
    end;
  end;
end;

procedure TTestRunner.Summary;
begin
  WriteLn('');
  WriteLn('--- ', FSuiteName, ': ', FTotal, ' total, ',
    FPassed, ' passed, ', FFailed, ' failed ---');
  if FFailed > 0 then
    Halt(1);
end;

function TTestRunner.AllPassed: Boolean;
begin
  Result := FFailed = 0;
end;

end.
