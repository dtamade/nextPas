program test_tui_core_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui,
  nextpas.core.test;

var
  T: TTestSuite;

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

procedure TestCoreBufferSetString;
var
  LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  try
    LBuf.SetString(0, 0, 'hello', StyleDefault);
    Check(Pos('hello', LBuf.AsLines[0]) > 0, 'setstring via core');
  finally
    LBuf.Free;
  end;
end;

procedure TestCoreParagraphRender;
var
  LBuf: TBuffer;
  LP: IParagraph;
begin
  LP := TParagraph.FromString('hi');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    LP.Render(TRect.Make(0, 0, 10, 2), LBuf);
    Check(Pos('hi', LBuf.AsLines[0]) > 0, 'paragraph render');
  finally
    LBuf.Free;
  end;
end;

procedure TestCoreLayoutSplit;
var
  LArea: TRect;
  LRects: TRectArray;
  Sum, I: Integer;
begin
  LArea := TRect.Make(0, 0, 20, 10);
  LRects := VerticalSplit(LArea, [LengthConstraint(2), MinConstraint(0)]);
  Sum := 0;
  for I := 0 to High(LRects) do
    Inc(Sum, LRects[I].Width * LRects[I].Height);
  CheckEqual(Int64(LArea.Width * LArea.Height), Int64(Sum), 'vsplit area');
end;

procedure TestCoreFocusHelpers;
var
  LEv: TEvent;
begin
  LEv := FocusEvent(fkIn);
  Check(IsFocus(LEv), 'IsFocus');
  Check(IsFocusIn(LEv), 'IsFocusIn');
  Check(LEv.Kind = evFocus, 'evFocus');
end;

procedure TestCoreColorStyle;
var
  C: TColor;
  S: TStyle;
begin
  C := RgbColor(1, 2, 3);
  S := StyleDefault.WithFg(C);
  Check(ColorEquals(S.Fg, C), 'style fg');
  Check(ColorIsSet(C), 'color set');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.core_facade');
  T.Test('core surface', @TestCoreSurface);
  T.Test('core buffer setstring', @TestCoreBufferSetString);
  T.Test('core paragraph render', @TestCoreParagraphRender);
  T.Test('core layout split', @TestCoreLayoutSplit);
  T.Test('core focus helpers', @TestCoreFocusHelpers);
  T.Test('core color style', @TestCoreColorStyle);
  if not T.Run then Halt(1);
end.
