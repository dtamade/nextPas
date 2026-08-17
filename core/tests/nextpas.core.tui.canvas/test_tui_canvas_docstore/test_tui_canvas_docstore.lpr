program test_tui_canvas_docstore;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.docstore,
  nextpas.core.test;

procedure AssertCellEq(const Name: AnsiString; D1, D2: TCanvasDoc; ALayer, AX, AY: Integer);
var
  C1, C2: TCanvasCell;
begin
  C1 := D1.GetCell(ALayer, AX, AY);
  C2 := D2.GetCell(ALayer, AX, AY);
  Check(CanvasCellEquals(C1, C2), Name);
end;

{ ── 空文档 roundtrip ── }
procedure TestEmptyDoc;
var
  D, D2: TCanvasDoc;
  Json: AnsiString;
begin
  D := TCanvasDoc.Create(10, 8);
  try
    Check(CanvasDocSaveToJson(D, Json), 'save empty');
    Check(Pos('"width":10', Json) > 0, 'json has width');
    D2 := CanvasDocLoadFromJson(Json);
    Check(D2 <> nil, 'load empty');
    if D2 <> nil then
    begin
      Check((D2.Width = 10) and (D2.Height = 8), 'empty dims');
      Check(D2.LayerName(0) = D.LayerName(0), 'empty layer name');
      D2.Free;
    end;
  finally
    D.Free;
  end;
end;

{ ── 多层多格 roundtrip ── }
procedure TestMultiLayer;
var
  D, D2: TCanvasDoc;
  Json: AnsiString;
  Red, Blue, White: TColor;
begin
  Red := Rgb($FF, $11, $22);
  Blue := Rgb($33, $44, $FF);
  White := Rgb($FF, $FF, $FF);
  D := TCanvasDoc.Create(6, 4);
  try
    D.SetCell(0, 3, 2, CanvasMakeCell(65, Red, Blue));          { 'A' }
    D.SetCell(0, 0, 0, CanvasMakeCell(66, White, Red));         { 'B' }
    D.SetCell(0, 5, 3, CanvasMakeCell(67, Blue, White));        { 'C' }
    D.NewLayer('图层2');
    D.SetCell(1, 1, 1, CanvasMakeCell($4F60, Red, White));      { 宽字 '你' }
    D.SetLayerVisible(1, False);
    Check(CanvasDocSaveToJson(D, Json), 'save multi');
    Check(Pos('图层2', Json) > 0, 'json has layer2');
    Check(Pos('"palette"', Json) > 0, 'json has palette');
    D2 := CanvasDocLoadFromJson(Json);
    Check(D2 <> nil, 'load multi');
    if D2 <> nil then
    begin
      Check((D2.Width = 6) and (D2.Height = 4), 'multi dims');
      Check(D2.LayerCount = 2, 'multi layers');
      Check(D2.LayerName(1) = '图层2', 'multi layer2 name');
      Check(not D2.LayerVisible(1), 'multi layer2 hidden');
      AssertCellEq('cell A', D, D2, 0, 3, 2);
      AssertCellEq('cell B', D, D2, 0, 0, 0);
      AssertCellEq('cell C', D, D2, 0, 5, 3);
      AssertCellEq('wide char', D, D2, 1, 1, 1);
      Check(D2.GetCell(1, 4, 1).Ch = 0, 'cell 1,1 empty');
      D2.Free;
    end;
  finally
    D.Free;
  end;
end;

{ ── 长 run(>255 连续同值) ── }
procedure TestLongRun;
var
  D, D2: TCanvasDoc;
  Json: AnsiString;
  X: Integer;
  Red, Blue: TColor;
begin
  Red := Rgb($FF, $11, $22);
  Blue := Rgb($33, $44, $FF);
  D := TCanvasDoc.Create(600, 2);
  try
    for X := 0 to 599 do
      D.SetCell(0, X, 0, CanvasMakeCell(65, Red, Blue));
    D.SetCell(0, 300, 1, CanvasMakeCell(66, Red, Blue));
    Check(CanvasDocSaveToJson(D, Json), 'save long run');
    D2 := CanvasDocLoadFromJson(Json);
    Check(D2 <> nil, 'load long run');
    if D2 <> nil then
    begin
      for X := 0 to 599 do
        AssertCellEq('long run ' + IntToStr(X), D, D2, 0, X, 0);
      AssertCellEq('row1', D, D2, 0, 300, 1);
      D2.Free;
    end;
  finally
    D.Free;
  end;
end;

{ ── 空格背景格(Ch=32) roundtrip ── }
procedure TestSpaceCell;
var
  D, D2: TCanvasDoc;
  Json: AnsiString;
  Red, White: TColor;
begin
  Red := Rgb($FF, $11, $22);
  White := Rgb($FF, $FF, $FF);
  D := TCanvasDoc.Create(4, 1);
  try
    D.SetCell(0, 2, 0, CanvasMakeCell(32, Red, White));
    Check(CanvasDocSaveToJson(D, Json), 'save space cell');
    D2 := CanvasDocLoadFromJson(Json);
    Check(D2 <> nil, 'load space cell');
    if D2 <> nil then
    begin
      AssertCellEq('space cell', D, D2, 0, 2, 0);
      Check(D2.GetCell(0, 2, 0).Ch = 32, 'space ch kept');
      D2.Free;
    end;
  finally
    D.Free;
  end;
end;

{ ── 颜色归一: indexed → rgb ── }
procedure TestIndexedNormalize;
var
  D, D2: TCanvasDoc;
  Json: AnsiString;
begin
  D := TCanvasDoc.Create(2, 1);
  try
    D.SetCell(0, 0, 0, CanvasMakeCell(65, TUI_RED, TUI_BLUE));
    Check(CanvasDocSaveToJson(D, Json), 'save indexed');
    D2 := CanvasDocLoadFromJson(Json);
    Check(D2 <> nil, 'load indexed');
    if D2 <> nil then
    begin
      Check(D2.GetCell(0, 0, 0).Fg.Kind = ckRgb, 'indexed->rgb');
      Check(D2.GetCell(0, 0, 0).Fg.R = $80, 'indexed red rgb');
      Check(D2.GetCell(0, 0, 0).Bg.B = $80, 'indexed blue rgb');
      D2.Free;
    end;
  finally
    D.Free;
  end;
end;

{ ── 坏输入 ── }
procedure TestBadInput;
begin
  Check(CanvasDocLoadFromJson('not json at all') = nil, 'bad json nil');
  Check(CanvasDocLoadFromJson('{"version":99}') = nil, 'bad version nil');
  Check(CanvasDocLoadFromJson(
    '{"version":1,"width":0,"height":10,"palette":[],"layers":[{"name":"a","visible":true,"rows":[]}]}') = nil,
    'bad dims nil');
  Check(CanvasDocLoadFromJson(
    '{"version":1,"width":4,"height":4,"palette":[],"layers":[]}') = nil,
    'empty layers nil');
end;

{ ── 坏 run 不崩(解析停止, 不抛异常) ── }
procedure TestBadRuns;
var
  D: TCanvasDoc;
begin
  D := CanvasDocLoadFromJson(
    '{"version":1,"width":4,"height":4,"palette":["#ff0000"],"layers":[{"name":"a","visible":true,"rows":["ff:zz:00:00"]}]}');
  Check(D <> nil, 'bad row not nil');
  D.Free;
  D := CanvasDocLoadFromJson(
    '{"version":1,"width":4,"height":4,"palette":["#ff0000"],"layers":[{"name":"a","visible":true,"rows":["01:41:09:09"]}]}');
  Check(D <> nil, 'bad row color idx not nil');
  D.Free;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.tui.canvas.docstore');
  T.Test('empty doc', @TestEmptyDoc);
  T.Test('multi layer', @TestMultiLayer);
  T.Test('long run', @TestLongRun);
  T.Test('space cell', @TestSpaceCell);
  T.Test('indexed normalize', @TestIndexedNormalize);
  T.Test('bad input', @TestBadInput);
  T.Test('bad runs', @TestBadRuns);
  if not T.Run then Halt(1);
end.
