unit nextpas.core.testing;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

type
  TTestProc = procedure;

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

procedure Check(const ACondition: Boolean; const AMessage: string = '');
procedure CheckEqual(const AExpected, AActual: string; const AMessage: string = ''); overload;
procedure CheckEqual(const AExpected, AActual: Int64; const AMessage: string = ''); overload;
procedure CheckEqual(const AExpected, AActual: Boolean; const AMessage: string = ''); overload;
procedure Fail(const AMessage: string);

implementation

var
  GCurrentTest: string = '';

procedure Check(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    if AMessage <> '' then
      raise EAssertionFailed.Create(AMessage)
    else
      raise EAssertionFailed.Create('Check failed');
  end;
end;

procedure CheckEqual(const AExpected, AActual: string; const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    if AMessage <> '' then
      raise EAssertionFailed.CreateFmt('%s: expected "%s", got "%s"', [AMessage, AExpected, AActual])
    else
      raise EAssertionFailed.CreateFmt('expected "%s", got "%s"', [AExpected, AActual]);
  end;
end;

procedure CheckEqual(const AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    if AMessage <> '' then
      raise EAssertionFailed.CreateFmt('%s: expected %d, got %d', [AMessage, AExpected, AActual])
    else
      raise EAssertionFailed.CreateFmt('expected %d, got %d', [AExpected, AActual]);
  end;
end;

procedure CheckEqual(const AExpected, AActual: Boolean; const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    if AMessage <> '' then
      raise EAssertionFailed.CreateFmt('%s: expected %s, got %s',
        [AMessage, BoolToStr(AExpected, True), BoolToStr(AActual, True)])
    else
      raise EAssertionFailed.CreateFmt('expected %s, got %s',
        [BoolToStr(AExpected, True), BoolToStr(AActual, True)]);
  end;
end;

procedure Fail(const AMessage: string);
begin
  raise EAssertionFailed.Create(AMessage);
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
  GCurrentTest := AName;
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
