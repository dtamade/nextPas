{ nextpas.core.test.helpers — shared test helpers
  =========================================================
  Reusable helpers for test programs.
  Import explicitly: uses nextpas.core.test.helpers;

  ExpectFail       — verify that a closure raises EAssertionFailed
  WithMock         — create+run+free a TMock in one call
  ExpectFailWithMock — mock lifecycle + assertion-failure check }
unit nextpas.core.test.helpers;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.test.base,
  nextpas.core.test.check,
  nextpas.core.test.config,
  nextpas.core.test.mock;

type
  TMockProc = procedure(AMock: TMock);

{ Verify closure raises EAssertionFailed.
  Optional AContains: substring check on the message. }
procedure ExpectFail(AProc: TTestClosure;
  const AContains: string = '');

{ Create TMock, run AProc, free mock — even on exception. }
procedure WithMock(AProc: TMockProc);

{ Create TMock, run AProc inside ExpectFail, free mock.
  Combines mock lifecycle with assertion-failure verification. }
procedure ExpectFailWithMock(AProc: TMockProc;
  const AContains: string = '');

{ Create a TTestConfig with a fresh TBufferSink as OutSink and AnsiMode=amOff.
  Returns the sink so the caller can read captured output. }
function MakeBufferConfig(out ASink: TBufferSink): TTestConfig;

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

procedure WithMock(AProc: TMockProc);
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    AProc(LM);
  finally
    LM.Free;
  end;
end;

procedure ExpectFailWithMock(AProc: TMockProc;
  const AContains: string);
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    ExpectFail(procedure
    begin
      AProc(LM);
    end, AContains);
  finally
    LM.Free;
  end;
end;

function MakeBufferConfig(out ASink: TBufferSink): TTestConfig;
begin
  ASink := TBufferSink.Create;
  Result := DefaultConfig;
  Result.OutSink := ASink;
  Result.ErrSink := ASink;
  Result.AnsiMode := amOff;
end;

end.
