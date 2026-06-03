program test_tui_core_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestCoreSurface;
var
  LArea: TRect;
  LBuffer: TBuffer;
  LBlock: IBlock;
begin
  LArea := TRect.Make(0, 0, 10, 2);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LBlock := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Core');
    LBlock.Render(LArea, LBuffer);
    Check(LBlock <> nil, 'core facade exposes basic widget contracts');
    CheckEqual(Word(10), LBuffer.Area.Width, 'core facade exposes buffer contract');
  finally
    LBuffer.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.core_facade');
  T.Run('core surface', @TestCoreSurface);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
