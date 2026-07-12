program test_tui_error;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.tui.error,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestHierarchy;
begin
  Check(ETui.InheritsFrom(ENextPasError), 'ETui is ENextPasError');
  Check(ETui.InheritsFrom(ECore), 'ETui remains ECore-compatible');
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

procedure TestCatchAsFrameworkRoot;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise ETuiBackend.Create('write failed');
  except
    on E: ENextPasError do
      LCaught := True;
  end;
  Check(LCaught, 'caught ETuiBackend as ENextPasError');
end;

procedure TestCatchAsCoreCompatibility;
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
  T := TTestSuite.Create('nextpas.core.tui.error');
  T.Test('hierarchy', @TestHierarchy);
  T.Test('catch as base ETui', @TestCatchAsBase);
  T.Test('catch as ENextPasError', @TestCatchAsFrameworkRoot);
  T.Test('catch as ECore compatibility', @TestCatchAsCoreCompatibility);
  if not T.Run then Halt(1);
end.
