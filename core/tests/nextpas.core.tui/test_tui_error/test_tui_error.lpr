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

procedure TestETuiLayoutMessage;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise ETuiLayout.Create('constraint unsatisfiable');
  except
    on E: ETuiLayout do
    begin
      LCaught := True;
      CheckEqual('constraint unsatisfiable', E.Message, 'layout message');
    end;
  end;
  Check(LCaught, 'caught ETuiLayout');
end;

procedure TestETuiInputHierarchy;
begin
  Check(ETuiInput.InheritsFrom(ETui), 'ETuiInput is ETui');
  Check(ETuiInput.InheritsFrom(ENextPasError), 'ETuiInput is framework root');
end;

procedure TestETuiBufferCatchSpecific;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise ETuiBuffer.Create('oob');
  except
    on E: ETuiBuffer do
      LCaught := True;
  end;
  Check(LCaught, 'specific ETuiBuffer');
end;

procedure TestNestedRaisePreservesType;
var
  LName: string;
begin
  LName := '';
  try
    raise ETuiInput.Create('parse');
  except
    on E: ETui do
      LName := E.ClassName;
  end;
  CheckEqual('ETuiInput', LName, 'class name preserved');
end;

procedure TestEmptyMessageAllowed;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise ETui.Create('');
  except
    on E: ETui do
    begin
      LCaught := True;
      CheckEqual('', E.Message, 'empty message');
    end;
  end;
  Check(LCaught, 'empty message raise');
end;

procedure TestETuiBufferIsNotLayout;
begin
  Check(not ETuiBuffer.InheritsFrom(ETuiLayout), 'buffer not layout');
  Check(not ETuiLayout.InheritsFrom(ETuiBuffer), 'layout not buffer');
end;

procedure TestMultipleRaiseCatchOrder;
var
  LHit: string;
begin
  LHit := '';
  try
    raise ETuiBackend.Create('io');
  except
    on E: ETuiBuffer do LHit := 'buffer';
    on E: ETuiBackend do LHit := 'backend';
    on E: ETui do LHit := 'tui';
  end;
  CheckEqual('backend', LHit, 'most specific catch');
end;

procedure TestETuiBaseClassName;
begin
  Check(ETui.ClassName = 'ETui', 'base class name');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.error');
  T.Test('hierarchy', @TestHierarchy);
  T.Test('catch as base ETui', @TestCatchAsBase);
  T.Test('catch as ENextPasError', @TestCatchAsFrameworkRoot);
  T.Test('catch as ECore compatibility', @TestCatchAsCoreCompatibility);
  T.Test('ETuiLayout message', @TestETuiLayoutMessage);
  T.Test('ETuiInput hierarchy', @TestETuiInputHierarchy);
  T.Test('ETuiBuffer specific catch', @TestETuiBufferCatchSpecific);
  T.Test('nested raise class name', @TestNestedRaisePreservesType);
  T.Test('empty message allowed', @TestEmptyMessageAllowed);
  T.Test('buffer is not layout', @TestETuiBufferIsNotLayout);
  T.Test('multiple raise catch order', @TestMultipleRaiseCatchOrder);
  T.Test('ETui base class name', @TestETuiBaseClassName);
  if not T.Run then Halt(1);
end.
