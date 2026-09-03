program test_tui_core_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.grid,
  nextpas.core.tui.layout.dsl,
  nextpas.core.tui.event,
  nextpas.core.tui.borders,
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

procedure TestCoreListRender;
var
  LBuf: TBuffer;
  LList: IListWidget;
begin
  LList := TListWidget.FromStrings(['a', 'b']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 12, 3));
  try
    LList.Render(TRect.Make(0, 0, 12, 3), LBuf);
    Check(LList <> nil, 'list via core');
    CheckEqual(12, LBuf.Area.Width, 'list buffer w');
  finally
    LBuf.Free;
  end;
end;

procedure TestCoreClearWidget;
var
  LBuf: TBuffer;
  LClear: IWidget;
begin
  LClear := TClearWidget.New;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LBuf.SetString(0, 0, 'xxxx', StyleDefault);
    LClear.Render(TRect.Make(0, 0, 4, 1), LBuf);
    Check(LClear <> nil, 'clear widget');
  finally
    LBuf.Free;
  end;
end;

procedure TestCoreHorizontalSplit;
var
  LArea: TRect;
  LRects: TRectArray;
  Sum, I: Integer;
begin
  LArea := TRect.Make(0, 0, 30, 5);
  LRects := HorizontalSplit(LArea, [LengthConstraint(5), MinConstraint(0)]);
  Sum := 0;
  for I := 0 to High(LRects) do
    Inc(Sum, LRects[I].Width * LRects[I].Height);
  CheckEqual(Int64(LArea.Width * LArea.Height), Int64(Sum), 'hsplit area');
end;

procedure TestCorePasteHelpers;
var
  LEv: TEvent;
begin
  LEv := PasteEvent;
  Check(IsPaste(LEv), 'IsPaste');
  Check(LEv.Kind = evPaste, 'evPaste');
end;

procedure TestCoreKeyCharEvent;
var
  LEv: TEvent;
begin
  LEv := KeyCharEvent(Ord('q'), []);
  Check(LEv.Kind = evKey, 'key');
  Check(LEv.Key.Code = kcChar, 'char code');
  CheckEqual(Int64(Ord('q')), Int64(LEv.Key.Ch), 'q');
end;

procedure TestCoreIndexedColor;
begin
  Check(ColorEquals(IndexedColor(7), IndexedColor(7)), 'indexed equal');
  Check(not ColorEquals(IndexedColor(1), IndexedColor(2)), 'indexed differ');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.core_facade');
  T.Test('core surface', @TestCoreSurface);
  T.Test('core buffer setstring', @TestCoreBufferSetString);
  T.Test('core paragraph render', @TestCoreParagraphRender);
  T.Test('core layout split', @TestCoreLayoutSplit);
  T.Test('core focus helpers', @TestCoreFocusHelpers);
  T.Test('core color style', @TestCoreColorStyle);
  T.Test('core list render', @TestCoreListRender);
  T.Test('core clear widget', @TestCoreClearWidget);
  T.Test('core horizontal split', @TestCoreHorizontalSplit);
  T.Test('core paste helpers', @TestCorePasteHelpers);
  T.Test('core key char event', @TestCoreKeyCharEvent);
  T.Test('core indexed color', @TestCoreIndexedColor);
  if not T.Run then Halt(1);
end.
