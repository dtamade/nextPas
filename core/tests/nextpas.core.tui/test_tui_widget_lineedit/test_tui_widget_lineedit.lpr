program test_tui_widget_lineedit;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.event,
  nextpas.core.tui.widget.lineedit,
  nextpas.core.test, nextpas.core.text.conv;

var T: TTestSuite;

{ === TLineEdit.HandleMouse:单击锚定 / 拖选 / 多击 === }

procedure TestMouseClickAnchorDrag;
var E: TLineEdit;
begin
  E.Init('hello world');
  Check(E.HandleMouse(3, 20, 1000, mkDown), 'click consumed');
  Check(not E.HasSelection, 'single click no visible selection yet');
  Check(E.HandleMouse(7, 20, 1100, mkDrag), 'drag consumed');
  Check(E.HasSelection, 'drag makes selection');
  CheckEqual('lo w', E.SelectedText, 'cols 3..7 selected');
  Check(E.HandleMouse(7, 20, 1200, mkUp), 'up consumed');
  { 收尾后再拖:未重新按下不接受(防跨组件误拖) }
  Check(not E.HandleMouse(2, 20, 1300, mkDrag), 'drag without down rejected');
end;

procedure TestMouseDoubleClickWord;
var E: TLineEdit;
begin
  { 列不同 = 重新起手单击(不构成双击),仅锚定无选区 }
  E.Init('foo bar baz');
  E.HandleMouse(1, 20, 1000, mkDown);
  E.HandleMouse(6, 20, 1100, mkDown);
  Check(not E.HasSelection, 'different-col second press is a fresh click');
end;

procedure TestMouseDoubleClickSameColWord;
var E: TLineEdit;
begin
  E.Init('foo bar baz');
  E.HandleMouse(5, 20, 1000, mkDown);
  E.HandleMouse(5, 20, 1100, mkDown);
  Check(E.HasSelection, 'same-col double click selects word');
  CheckEqual('bar', E.SelectedText, 'second word selected');
end;

procedure TestMouseTripleSelectAll;
var E: TLineEdit;
begin
  E.Init('foo bar');
  E.HandleMouse(2, 20, 1000, mkDown);
  E.HandleMouse(2, 20, 1050, mkDown);
  E.HandleMouse(2, 20, 1100, mkDown);
  CheckEqual('foo bar', E.SelectedText, 'triple click selects all');
end;

procedure TestMouseDoubleClickBlank;
var E: TLineEdit;
begin
  E.Init('ab c');                       { 空格在列 2 }
  E.HandleMouse(2, 20, 1000, mkDown);
  E.HandleMouse(2, 20, 1100, mkDown);   { 双击空白 }
  Check(not E.HasSelection, 'blank double click no selection');
end;

procedure TestMouseDragEdgeExtends;
var E: TLineEdit;
begin
  { 左缘 = 钉在首字符,不启动自动扩展(左侧无隐藏内容可推进) }
  E.Init('abcdef');
  E.HandleMouse(2, 4, 1000, mkDown);
  E.HandleMouse(-1, 4, 1100, mkDrag);   { 拖进提示词区(RelX<0) }
  CheckEqual('ab', E.SelectedText, 'left edge pins head at first char');
  Check(not E.AutoActive, 'no left auto extend');
  E.HandleMouse(-1, 4, 1200, mkDrag);
  CheckEqual('ab', E.SelectedText, 'stays pinned on repeat events');
end;

procedure TestMouseRightToLeftCrossing;
var E: TLineEdit;
begin
  { 从右往左拖选:头越过锚点后反向归一化,穿越首字符再折返不乱 }
  E.Init('abcdef');
  E.HandleMouse(4, 10, 1000, mkDown);   { 锚在 col4='e' 前 }
  Check(not E.HasSelection, 'anchor only');
  E.HandleMouse(1, 10, 1100, mkDrag);
  CheckEqual('bcd', E.SelectedText, 'reversed range [1..4)');
  E.HandleMouse(0, 10, 1150, mkDrag);
  CheckEqual('abcd', E.SelectedText, 'head at first char');
  E.HandleMouse(-3, 10, 1200, mkDrag);  { 越过首字符(负列) }
  CheckEqual('abcd', E.SelectedText, 'pinned, no chaos past first char');
  Check(not E.AutoActive, 'no auto on the left flank');
  E.HandleMouse(2, 10, 1300, mkDrag);   { 折返回行内 }
  CheckEqual('cd', E.SelectedText, 'folds back cleanly [2..4)');
end;

procedure TestMouseWheelNotConsumed;
var E: TLineEdit;
begin
  E.Init('abc');
  Check(not E.HandleMouse(1, 10, 1000, mkScrollUp), 'scroll up passes through');
  Check(not E.HandleMouse(1, 10, 1000, mkScrollDown), 'scroll down passes through');
  Check(not E.HandleMouse(1, 10, 1000, mkMoved), 'move passes through');
end;

procedure TestMouseRightEdgeAutoExtend;
var E: TLineEdit;
begin
  { 终端把鼠标 X 钳到视口宽:最右可见列即「顶边」信号 }
  E.Init('abcdefghijkl');
  E.HandleMouse(0, 4, 1000, mkDown);
  Check(not E.AutoActive, 'no auto after down');
  Check(E.HandleMouse(3, 4, 1100, mkDrag), 'drag at last visible column');
  Check(E.AutoActive, 'right edge starts auto extend');
  CheckEqual('a', E.SelectedText, 'pushed one grapheme past edge');
  Check(not E.TickExtend(1140), 'slow tier waits 80ms');
  Check(E.TickExtend(1190), 'slow tier tick advances');
  CheckEqual('ab', E.SelectedText, 'advanced one more');
  Check(E.TickExtend(1350), 'slow tier advances again');
  CheckEqual('abc', E.SelectedText, 'three graphemes');
  Check(not E.TickExtend(1400), 'slow tier waits again');
  { 按住超过 600ms 切快档(35ms/图素) }
  Check(E.TickExtend(1740), 'fast tier after 600ms held');
  CheckEqual('abcd', E.SelectedText, 'four graphemes');
  Check(not E.TickExtend(1760), 'fast tier waits 35ms');
  Check(E.TickExtend(1800), 'fast tier advances');
  CheckEqual('abcde', E.SelectedText, 'five graphemes total');
  Check(E.HandleMouse(3, 4, 1600, mkUp), 'up consumed');
  Check(not E.AutoActive, 'auto stops on up');
end;

procedure TestMouseRightEdgeShortTextNoAuto;
var E: TLineEdit;
begin
  { 文本短于视口:最右列只是普通映射目标,不触发自动扩展 }
  E.Init('abc');
  E.HandleMouse(0, 10, 1000, mkDown);
  E.HandleMouse(9, 10, 1100, mkDrag);
  Check(not E.AutoActive, 'no auto when tail reachable');
  CheckEqual('abc', E.SelectedText, 'mapped straight to end');
end;

procedure TestAutoStopClears;
var E: TLineEdit;
begin
  E.Init('abcdef');
  E.HandleMouse(2, 3, 1000, mkDown);
  E.HandleMouse(2, 3, 1100, mkDrag);
  Check(E.AutoActive, 'auto on');
  E.AutoStop;
  Check(not E.AutoActive, 'auto stopped');
  Check(not E.TickExtend(50000), 'tick noop after stop');
end;

{ === 选区与编辑语义 === }

procedure TestShiftKeyExtendViaCore;
var E: TLineEdit; WP, WC: Boolean;
begin
  E.Init('abc');
  E.HandleKey(KeyCodeEvent(kcLeft, [kmShift]).Key, WP, WC);
  Check(E.HasSelection, 'shift+left extends in line edit');
  CheckEqual('c', E.SelectedText, 'one char from end');
end;

procedure TestCtrlShiftAliasTolerated;
var E: TLineEdit; WP, WC: Boolean;
begin
  { kitty 协议终端(kitty/Ghostty/WezTerm 等)把 Ctrl+Shift+C/V 解码为
    kcChar+c/v+[kmCtrl,kmShift] 的独立事件。处理路径只判 kmCtrl 成员、
    不排斥 kmShift,故这些终端上 Ctrl+Shift+C/V 天然可用——测试锁定,
    防止将来有人加 kmShift 排除条件破坏兼容。多数主流终端(GNOME/Konsole/
    Windows Terminal)自行拦截这对组合键,事件到不了程序,属预期外情况 }
  E.Init('hello');
  E.HandleKey(KeyCharEvent(Ord('c'), [kmCtrl, kmShift]).Key, WP, WC);
  Check(WC, 'ctrl+shift+c requests copy');
  WP := False;
  E.HandleKey(KeyCharEvent(Ord('v'), [kmCtrl, kmShift]).Key, WP, WC);
  Check(WP, 'ctrl+shift+v requests paste');
  { 无 Ctrl 的 Shift 组合仍是普通字符输入,不受影响 }
  E.HandleKey(KeyCharEvent(Ord('C'), [kmShift]).Key, WP, WC);
  CheckEqual('helloC', E.Text, 'plain shifted char still types');
end;

procedure TestTypeReplacesSelectionRespectsCapacity;
var E: TLineEdit; WP, WC: Boolean; KE: TKeyEvent;
begin
  { 满员 + 有选区:输入替换选区不被容量守卫吞键 }
  E.Init('abcdef', 6);
  KE := KeyCharEvent(Ord('X'), []).Key;
  E.HandleMouse(1, 20, 1000, mkDown);
  E.HandleMouse(4, 20, 1100, mkDrag);   { 选 bcd }
  Check(E.HandleKey(KE, WP, WC), 'typing with selection consumed at capacity');
  CheckEqual('aXef', E.Text, 'selection replaced by X');
end;

procedure TestSelVisibleColsCjk;
var E: TLineEdit; F, TT: Integer;
begin
  E.Init('你好');                       { 2 图素 × 2 列 }
  E.HandleMouse(0, 20, 1000, mkDown);
  E.HandleMouse(9, 20, 1100, mkDrag);   { 全选(超尾夹到末) }
  Check(E.SelVisibleCols(10, F, TT), 'visible cols for full select');
  Check((F = 0) and (TT = 4), 'full range 0..4');
  Check(E.SelVisibleCols(2, F, TT), 'clipped to viewport');
  Check((F = 0) and (TT = 2), 'clamped to 0..2');
  { 半开区间:只选第二个字 }
  E.ClearSelection;
  E.HandleMouse(3, 20, 2000, mkDown);
  E.HandleMouse(9, 20, 2100, mkDrag);
  Check(E.SelVisibleCols(10, F, TT), 'second char visible cols');
  Check((F = 2) and (TT = 4), 'range 2..4 (wide grapheme snaps)');
end;

procedure TestDrawSelectionOverlay;
var E: TLineEdit; B: TBuffer; I: Integer; LC: PCell;
begin
  E.Init('abcd');
  E.HandleMouse(1, 20, 1000, mkDown);
  E.HandleMouse(3, 20, 1100, mkDrag);   { 选 bc → 列 1..3 }
  B := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    B.SetStringN(0, 0, 'abcd', 10, TStyle.Default);
    E.DrawSelection(B, 2, 0, 8, TStyle.Default.WithBg(IndexedColor(5)));
    for I := 0 to 9 do
    begin
      LC := B.CellAt(I, 0);
      if (I >= 3) and (I <= 4) then
        Check((LC^.Bg.Kind = ckIndexed) and (LC^.Bg.Index = 5),
          'cell ' + IntToStr(I) + ' highlighted')
      else
        Check(not ((LC^.Bg.Kind = ckIndexed) and (LC^.Bg.Index = 5)),
          'cell ' + IntToStr(I) + ' not highlighted');
    end;
  finally B.Free; end;
end;

begin
  T := TTestSuite.Create('test_tui_widget_lineedit');
  try
    T.Test('Mouse ClickAnchorDrag', @TestMouseClickAnchorDrag);
    T.Test('Mouse DragEdgeExtends', @TestMouseDragEdgeExtends);
    T.Test('Mouse RightToLeftCrossing', @TestMouseRightToLeftCrossing);
    T.Test('Mouse DoubleClickWord', @TestMouseDoubleClickWord);
    T.Test('Mouse DoubleClickSameColWord', @TestMouseDoubleClickSameColWord);
    T.Test('Mouse TripleSelectAll', @TestMouseTripleSelectAll);
    T.Test('Mouse DoubleClickBlank', @TestMouseDoubleClickBlank);
    T.Test('Mouse WheelNotConsumed', @TestMouseWheelNotConsumed);
    T.Test('Mouse RightEdgeAutoExtend', @TestMouseRightEdgeAutoExtend);
    T.Test('Mouse RightEdgeShortTextNoAuto', @TestMouseRightEdgeShortTextNoAuto);
    T.Test('AutoStop Clears', @TestAutoStopClears);
    T.Test('ShiftKey ExtendViaCore', @TestShiftKeyExtendViaCore);
    T.Test('CtrlShift AliasTolerated', @TestCtrlShiftAliasTolerated);
    T.Test('TypeReplaces RespectsCapacity', @TestTypeReplacesSelectionRespectsCapacity);
    T.Test('SelVisibleCols Cjk', @TestSelVisibleColsCjk);
    T.Test('DrawSelection Overlay', @TestDrawSelectionOverlay);
    WriteLn;
  if not T.Run then Halt(1);
  finally
  end;
end.
