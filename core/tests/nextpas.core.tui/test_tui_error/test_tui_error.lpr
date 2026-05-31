program test_tui_error;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.tui.error,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestHierarchy;
begin
  Check(ETui.InheritsFrom(ECore), 'ETui is ECore');
  Check(ETuiBuffer.InheritsFrom(ETui), 'ETuiBuffer is ETui');
  Check(ETuiLayout.InheritsFrom(ETui), 'ETuiLayout is ETui');
  Check(ETuiBackend.InheritsFrom(ETui), 'ETuiBackend is ETui');
  Check(ETuiInput.InheritsFrom(ETui), 'ETuiInput is ETui');
end;

procedure TestCatchAsBase;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise ETuiBuffer.Create('cell out of bounds at (5,3)');
  except
    on E: ETui do
    begin
      LCaught := True;
      CheckEqual('cell out of bounds at (5,3)', E.Message, 'message preserved');
    end;
  end;
  Check(LCaught, 'caught ETuiBuffer as ETui');
end;

procedure TestCatchAsCore;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise ETuiBackend.Create('write failed');
  except
    on E: ECore do
      LCaught := True;
  end;
  Check(LCaught, 'caught ETuiBackend as ECore');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.error');
  T.Run('hierarchy', @TestHierarchy);
  T.Run('catch as base ETui', @TestCatchAsBase);
  T.Run('catch as ECore', @TestCatchAsCore);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
