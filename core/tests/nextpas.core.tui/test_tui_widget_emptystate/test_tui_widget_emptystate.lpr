program test_tui_widget_emptystate;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.text.width,
  nextpas.core.tui.widget.emptystate,
  nextpas.core.test;

var T: TTestSuite;

{ 首个非空字形格的 X(整行扫描);无字形返回 -1 }
function FirstGlyphX(ABuf: TBuffer; AY: Integer): Integer;
var X: Integer;
begin
  Result := -1;
  for X := 0 to ABuf.Width - 1 do
    if Length(CellGlyphAsString(ABuf.CellAt(X, AY)^)) > 0 then
      Exit(X);
end;

procedure TestEmptyStateTwoLineCenter;
var LBuf: TBuffer;
begin
  { 20x10,两行块顶行 Y=(10-2) div 2 = 4;'no data' 宽 7 → MX=(20-7) div 2 = 6 }
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    RenderCenteredEmptyState(LBuf, TRect.Make(0, 0, 20, 10),
      'no data', 'press a',
      TStyle.Default.WithFg(IndexedColor(250)),
      TStyle.Default.WithFg(IndexedColor(244)));
    Check(FirstGlyphX(LBuf, 4) = 6, 'main line centered at col 6');
    Check(FirstGlyphX(LBuf, 5) = 6, 'hint line centered at col 6');
    Check(CellGlyphAsString(LBuf.CellAt(6, 4)^) = 'n', 'main glyph intact');
    Check(CellGlyphAsString(LBuf.CellAt(6, 5)^) = 'p', 'hint glyph intact');
  finally LBuf.Free; end;
end;

procedure TestEmptyStateSingleRow;
var LBuf: TBuffer;
begin
  { hint 为空只画主行:Y=(10-1) div 2 = 4,提示行保持空 }
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    RenderCenteredEmptyState(LBuf, TRect.Make(0, 0, 20, 10),
      'no data', '',
      TStyle.Default, TStyle.Default);
    Check(FirstGlyphX(LBuf, 4) = 6, 'single row vertically centered');
    Check(FirstGlyphX(LBuf, 5) = -1, 'no hint row written');
    Check(FirstGlyphX(LBuf, 3) = -1, 'row above untouched');
  finally LBuf.Free; end;
end;

procedure TestEmptyStateCjkWidth;
var LBuf: TBuffer;
begin
  {'暂无' 显示宽 4:MX=(11-4) div 2 = 3;按字符数(2)会错算成 4 }
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 11, 5));
  try
    RenderCenteredEmptyState(LBuf, TRect.Make(0, 0, 11, 5),
      '暂无', '', TStyle.Default, TStyle.Default);
    Check(FirstGlyphX(LBuf, 2) = 3,
      'centering uses display width not char count');
  finally LBuf.Free; end;
end;

procedure TestEmptyStateOversizeClamp;
var LBuf: TBuffer;
begin
  { 文本宽于区域:钳到区域左缘,不越界不崩 }
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 5));
  try
    RenderCenteredEmptyState(LBuf, TRect.Make(0, 0, 8, 5),
      'way too long text', '', TStyle.Default, TStyle.Default);
    Check(FirstGlyphX(LBuf, 2) = 0, 'oversized text clamps to area left');
  finally LBuf.Free; end;
end;

procedure TestEmptyStateSubAreaOffset;
var LBuf: TBuffer;
begin
  { 区域带偏移:(X=5,Y=3,10x6);主行 'ab'(2)→MX=5+(10-2) div 2=9,Y=3+(6-1) div 2=5 }
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 20));
  try
    RenderCenteredEmptyState(LBuf, TRect.Make(5, 3, 10, 6),
      'ab', '', TStyle.Default, TStyle.Default);
    Check(CellGlyphAsString(LBuf.CellAt(9, 5)^) = 'a',
      'sub-area offset honored');
    Check(FirstGlyphX(LBuf, 4) = -1, 'nothing above sub-area main row');
  finally LBuf.Free; end;
end;

procedure TestEmptyStateStylesApplied;
var
  LBuf: TBuffer;
  LP: PCell;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    RenderCenteredEmptyState(LBuf, TRect.Make(0, 0, 20, 10),
      'main', 'hint',
      TStyle.Default.WithFg(IndexedColor(196)),
      TStyle.Default.WithFg(IndexedColor(240)));
    LP := LBuf.CellAt(FirstGlyphX(LBuf, 4), 4);
    Check((LP <> nil) and ColorIsSet(LP^.Fg), 'main style applied');
    LP := LBuf.CellAt(FirstGlyphX(LBuf, 5), 5);
    Check((LP <> nil) and ColorIsSet(LP^.Fg), 'hint style applied');
  finally LBuf.Free; end;
end;

procedure TestEmptyStateEmptyAreaNoCrash;
var LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 4));
  try
    RenderCenteredEmptyState(LBuf, TRect.Make(0, 0, 0, 0),
      'x', 'y', TStyle.Default, TStyle.Default);
    Check(True, 'empty area is a no-op');
  finally LBuf.Free; end;
end;

begin
  T := TTestSuite.Create('test_tui_widget_emptystate');
  try
    T.Test('EmptyState two-line center', @TestEmptyStateTwoLineCenter);
    T.Test('EmptyState single row', @TestEmptyStateSingleRow);
    T.Test('EmptyState CJK display width', @TestEmptyStateCjkWidth);
    T.Test('EmptyState oversize clamp', @TestEmptyStateOversizeClamp);
    T.Test('EmptyState sub-area offset', @TestEmptyStateSubAreaOffset);
    T.Test('EmptyState styles applied', @TestEmptyStateStylesApplied);
    T.Test('EmptyState empty area no crash', @TestEmptyStateEmptyAreaNoCrash);

    WriteLn;
  if not T.Run then Halt(1);
  finally
  end;
end.
