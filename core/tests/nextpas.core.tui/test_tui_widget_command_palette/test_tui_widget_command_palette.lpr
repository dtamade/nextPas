program test_tui_widget_command_palette;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.input,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.command_palette,
  nextpas.core.test;

var
  T: TTestSuite;

{ === CommandItem Tests === }

procedure TestCommandItemMake;
var
  Item: TCommandItem;
begin
  Item := TCommandItem.Make('open', 'Open a file');
  CheckEqual('open', Item.Name, 'item name');
  CheckEqual('Open a file', Item.Description, 'item description');
end;

{ === FuzzyMatch Tests === }

procedure TestFuzzyMatchEmpty;
begin
  Check(FuzzyMatch('', 'anything'), 'empty pattern matches anything');
end;

procedure TestFuzzyMatchExact;
begin
  Check(FuzzyMatch('open', 'open'), 'exact match');
end;

procedure TestFuzzyMatchPrefix;
begin
  Check(FuzzyMatch('op', 'open'), 'prefix match');
end;

procedure TestFuzzyMatchSubsequence;
begin
  Check(FuzzyMatch('oe', 'open'), 'subsequence match');
  Check(not FuzzyMatch('eo', 'open'), 'wrong order no match');
end;

procedure TestFuzzyMatchCaseInsensitive;
begin
  Check(FuzzyMatch('OP', 'open'), 'case insensitive match');
end;

procedure TestFuzzyMatchNoMatch;
begin
  Check(not FuzzyMatch('xyz', 'open'), 'no match');
end;

{ === FuzzyScore Tests === }

procedure TestFuzzyScoreEmpty;
begin
  CheckEqual(1000, FuzzyScore('', 'anything'), 'empty pattern high score');
end;

procedure TestFuzzyScorePrefix;
var
  S1, S2: Integer;
begin
  S1 := FuzzyScore('op', 'open');
  S2 := FuzzyScore('op', 'reopen');
  Check(S1 > S2, 'prefix scores higher');
end;

procedure TestFuzzyScoreConsecutive;
var
  S1, S2: Integer;
begin
  S1 := FuzzyScore('ope', 'open');
  S2 := FuzzyScore('ope', 'oxpxex');
  Check(S1 > S2, 'consecutive scores higher');
end;

procedure TestFuzzyScoreNoMatch;
begin
  CheckEqual(0, FuzzyScore('xyz', 'open'), 'no match scores 0');
end;

{ === CommandPaletteState Tests === }

procedure TestCommandPaletteStateEmpty;
var
  State: TCommandPaletteState;
begin
  State := TCommandPaletteState.Empty;
  Check(not State.Visible, 'initially hidden');
  CheckEqual(0, State.Selected, 'initial selected');
end;

procedure TestCommandPaletteStateToggle;
var
  State: TCommandPaletteState;
begin
  State := TCommandPaletteState.Empty;
  State.Toggle;
  Check(State.Visible, 'toggle opens');
  State.Toggle;
  Check(not State.Visible, 'toggle closes');
end;

procedure TestCommandPaletteStateOpenClose;
var
  State: TCommandPaletteState;
begin
  State := TCommandPaletteState.Empty;
  State.Open;
  Check(State.Visible, 'open shows');
  State.Close;
  Check(not State.Visible, 'close hides');
end;

procedure TestCommandPaletteStateSelectNext;
var
  State: TCommandPaletteState;
begin
  State := TCommandPaletteState.Empty;
  SetLength(State.FilteredIndices, 3);
  State.SelectNext;
  CheckEqual(1, State.Selected, 'select next');
  State.SelectNext;
  CheckEqual(2, State.Selected, 'select next again');
  State.SelectNext;
  CheckEqual(2, State.Selected, 'clamped at max');
end;

procedure TestCommandPaletteStateSelectPrev;
var
  State: TCommandPaletteState;
begin
  State := TCommandPaletteState.Empty;
  SetLength(State.FilteredIndices, 3);
  State.Selected := 2;
  State.SelectPrev;
  CheckEqual(1, State.Selected, 'select prev');
  State.SelectPrev;
  CheckEqual(0, State.Selected, 'select prev again');
  State.SelectPrev;
  CheckEqual(0, State.Selected, 'clamped at 0');
end;

{ === CommandPalette Widget Tests === }

procedure TestCommandPaletteRenderEmpty;
var
  CP: ICommandPalette;
  Buf: TBuffer;
  State: TCommandPaletteState;
begin
  CP := TCommandPalette.New([]);
  State := TCommandPaletteState.Empty;
  State.Open;
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 60, 20));
  try
    CP.RenderStateful(TRect.Make(0, 0, 60, 20), Buf, State);
    Check(True, 'empty palette renders without error');
  finally
    Buf.Free;
  end;
end;

procedure TestCommandPaletteRenderWithItems;
var
  CP: ICommandPalette;
  Buf: TBuffer;
  State: TCommandPaletteState;
begin
  CP := TCommandPalette.New([
    TCommandItem.Make('open', 'Open a file'),
    TCommandItem.Make('save', 'Save current file'),
    TCommandItem.Make('quit', 'Quit application')
  ]);
  State := TCommandPaletteState.Empty;
  State.Open;
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 60, 20));
  try
    CP.RenderStateful(TRect.Make(0, 0, 60, 20), Buf, State);
    Check(True, 'palette with items renders without error');
  finally
    Buf.Free;
  end;
end;

{ PH29：极小区 sweep——1..6×1..6 全组合渲染不抛异常（修复前
  PalW := AArea.Width - 4 在窄区 Word 下溢 65533 绕过 <=0 检查） }
procedure TestCommandPaletteRenderTinyAreas;
var
  CP: ICommandPalette;
  Buf: TBuffer;
  State: TCommandPaletteState;
  LW, LH: Integer;
begin
  CP := TCommandPalette.New([TCommandItem.Make('open', 'Open a file')]);
  for LW := 1 to 6 do
    for LH := 1 to 6 do
    begin
      State := TCommandPaletteState.Empty;
      State.Open;
      Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, LW, LH));
      try
        CP.RenderStateful(TRect.Make(0, 0, LW, LH), Buf, State);
        Check(True, 'render in tiny area');
      finally
        Buf.Free;
      end;
    end;
end;

procedure TestCommandPaletteUpdateFilter;
var
  CP: ICommandPalette;
  State: TCommandPaletteState;
begin
  CP := TCommandPalette.New([
    TCommandItem.Make('open', 'Open a file'),
    TCommandItem.Make('save', 'Save current file'),
    TCommandItem.Make('quit', 'Quit application')
  ]);
  State := TCommandPaletteState.Empty;
  State.Open;
  State.Input.Text := 'sa';
  CP.UpdateFilter(State);
  Check(Length(State.FilteredIndices) > 0, 'filter produces results');
end;

{ PH33 P1：过滤结果按 FuzzyScore 降序排名（此前 Score 只算不用）。
  query='sa' 手算：'sa'=前缀50+连续(10+20)=80 > 'sta'=60+10=70 >
  'xsa'=10+20=30（'as' 非 'sa' 子序列不入集）；空查询全 1000 同分 →
  插入排序稳定保持原序 }
procedure TestCommandPaletteFilterRanking;
var
  CP: ICommandPalette;
  State: TCommandPaletteState;
begin
  CP := TCommandPalette.New([
    TCommandItem.Make('xsa', 'C'),
    TCommandItem.Make('sa', 'A'),
    TCommandItem.Make('sta', 'B')
  ]);
  State := TCommandPaletteState.Empty;
  State.Open;
  State.Input.Text := 'sa';
  CP.UpdateFilter(State);
  Check(Length(State.FilteredIndices) = 3, 'all three match as subsequence');
  Check((State.FilteredIndices[0] = 1) and
        (State.FilteredIndices[1] = 2) and
        (State.FilteredIndices[2] = 0),
        'filter results ranked by FuzzyScore descending');

  State.Input.Text := '';
  CP.UpdateFilter(State);
  Check((State.FilteredIndices[0] = 0) and
        (State.FilteredIndices[1] = 1) and
        (State.FilteredIndices[2] = 2),
        'empty query keeps original order (stable sort)');
end;

procedure TestCommandPaletteSelectedItem;
var
  CP: ICommandPalette;
  State: TCommandPaletteState;
  Idx: Integer;
begin
  CP := TCommandPalette.New([
    TCommandItem.Make('open', 'Open a file'),
    TCommandItem.Make('save', 'Save current file')
  ]);
  State := TCommandPaletteState.Empty;
  State.Open;
  CP.UpdateFilter(State);
  Idx := CP.SelectedItem(State);
  Check(Idx >= 0, 'selected item returns valid index');
end;

procedure TestCommandPaletteBuilderChaining;
var
  CP: ICommandPalette;
begin
  CP := TCommandPalette.New([TCommandItem.Make('test', 'test')])
    .WithStyle(TStyle.Default)
    .WithSelectedStyle(TStyle.Default.WithModifier([mbBold]))
    .WithWidth(40)
    .WithMaxVisible(5);
  Check(CP <> nil, 'builder chaining returns non-nil');
end;

procedure TestCommandPaletteHidden;
var
  CP: ICommandPalette;
  Buf: TBuffer;
  State: TCommandPaletteState;
begin
  CP := TCommandPalette.New([TCommandItem.Make('test', 'test')]);
  State := TCommandPaletteState.Empty;
  { Not opened - should not render }
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 60, 20));
  try
    CP.RenderStateful(TRect.Make(0, 0, 60, 20), Buf, State);
    Check(True, 'hidden palette renders without error');
  finally
    Buf.Free;
  end;
end;

{ PH33 P2b：布局配置面——WithBlock 块包装（浮层在块内容区内定位，项仍可见） }
procedure TestPaletteWithBlock;
var CP: ICommandPalette; Buf: TBuffer; State: TCommandPaletteState;
    LAll: AnsiString; I: Integer;
begin
  CP := TCommandPalette.New([TCommandItem.Make('open-file', 'Open')])
    .WithBlock(TBlock.Bordered('T'));
  State := TCommandPaletteState.Empty;
  State.Open;
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 60, 20));
  try
    CP.RenderStateful(TRect.Make(0, 0, 60, 20), Buf, State);
    LAll := '';
    for I := 0 to 19 do LAll := LAll + Buf.RowAsString(I);
    Check(Pos(#$E2#$94#$8C, Buf.RowAsString(0)) > 0, 'block border drawn');
    Check(Pos('open-file', LAll) > 0, 'item visible inside block');
  finally
    Buf.Free;
  end;
end;

procedure TestPaletteWithBlockChaining;
var CP: ICommandPalette;
begin
  CP := TCommandPalette.New([]).WithBlock(TBlock.Bordered('x'));
  Check(CP <> nil, 'WithBlock chains and returns interface');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.command_palette');

  { CommandItem tests }
  T.Test('command item make', @TestCommandItemMake);

  { FuzzyMatch tests }
  T.Test('fuzzy match empty', @TestFuzzyMatchEmpty);
  T.Test('fuzzy match exact', @TestFuzzyMatchExact);
  T.Test('fuzzy match prefix', @TestFuzzyMatchPrefix);
  T.Test('fuzzy match subsequence', @TestFuzzyMatchSubsequence);
  T.Test('fuzzy match case insensitive', @TestFuzzyMatchCaseInsensitive);
  T.Test('fuzzy match no match', @TestFuzzyMatchNoMatch);

  { FuzzyScore tests }
  T.Test('fuzzy score empty', @TestFuzzyScoreEmpty);
  T.Test('fuzzy score prefix', @TestFuzzyScorePrefix);
  T.Test('fuzzy score consecutive', @TestFuzzyScoreConsecutive);
  T.Test('fuzzy score no match', @TestFuzzyScoreNoMatch);

  { CommandPaletteState tests }
  T.Test('state empty', @TestCommandPaletteStateEmpty);
  T.Test('state toggle', @TestCommandPaletteStateToggle);
  T.Test('state open close', @TestCommandPaletteStateOpenClose);
  T.Test('state select next', @TestCommandPaletteStateSelectNext);
  T.Test('state select prev', @TestCommandPaletteStateSelectPrev);

  { CommandPalette widget tests }
  T.Test('render empty', @TestCommandPaletteRenderEmpty);
  T.Test('render with items', @TestCommandPaletteRenderWithItems);
  T.Test('render tiny areas', @TestCommandPaletteRenderTinyAreas);
  T.Test('update filter', @TestCommandPaletteUpdateFilter);
  T.Test('filter ranking by score (PH33 P1)', @TestCommandPaletteFilterRanking);
  T.Test('selected item', @TestCommandPaletteSelectedItem);
  T.Test('builder chaining', @TestCommandPaletteBuilderChaining);
  T.Test('hidden palette', @TestCommandPaletteHidden);
  T.Test('WithBlock render (PH33 P2b)', @TestPaletteWithBlock);
  T.Test('WithBlock chaining (PH33 P2b)', @TestPaletteWithBlockChaining);

  if not T.Run then Halt(1);
end.
