program test_tui_canvas_doc;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestSize;
begin
  CheckEqual(Int64(4), Int64(SizeOf(TColor)), 'TColor 4 bytes');
  CheckEqual(Int64(12), Int64(SizeOf(TCanvasCell)), 'TCanvasCell 12 bytes');
end;

procedure TestCreate;
var
  LD: TCanvasDoc;
begin
  LD := TCanvasDoc.Create(3, 4);
  try
    CheckEqual(Int64(3), Int64(LD.Width), 'width');
    CheckEqual(Int64(4), Int64(LD.Height), 'height');
    CheckEqual(Int64(1), Int64(LD.LayerCount), 'one default layer');
    CheckEqual(Int64(0), Int64(LD.ActiveIndex), 'active layer 0');
    Check(LD.LayerName(0) = CANVAS_DEFAULT_LAYER_NAME, 'default layer name');
    Check(LD.LayerVisible(0), 'default layer visible');
    Check(CanvasCellEquals(LD.GetCell(0, 0, 0), CANVAS_CELL_EMPTY), 'fresh cells empty');
    Check(LD.IsDirty, 'new doc marked dirty');
  finally
    LD.Free;
  end;
end;

procedure TestCreateClamps;
var
  LD: TCanvasDoc;
begin
  LD := TCanvasDoc.Create(0, -5);
  try
    CheckEqual(Int64(1), Int64(LD.Width), 'width clamped to 1');
    CheckEqual(Int64(1), Int64(LD.Height), 'height clamped to 1');
  finally
    LD.Free;
  end;
end;

procedure TestCellAccess;
var
  LD: TCanvasDoc;
  LC: TCanvasCell;
  LP: PCanvasCell;
begin
  LD := TCanvasDoc.Create(4, 3);
  try
    LC := CanvasMakeCell(Ord('A'), TUI_RED, TUI_BLUE);
    LD.SetCell(0, 2, 1, LC);
    Check(CanvasCellEquals(LD.GetCell(0, 2, 1), LC), 'set/get roundtrip');
    LP := LD.CellPtr(0, 2, 1);
    Check(LP <> nil, 'cell ptr valid');
    Check(CanvasCellEquals(LP^, LC), 'cell ptr contents');
    Check(LD.GetCell(0, 4, 1).Ch = 0, 'x out of range -> empty');
    Check(LD.GetCell(0, 2, 3).Ch = 0, 'y out of range -> empty');
    Check(LD.GetCell(0, -1, 0).Ch = 0, 'negative x -> empty');
    Check(LD.CellPtr(0, 4, 0) = nil, 'cell ptr out of range nil');
    Check(LD.CellPtr(0, 0, 3) = nil, 'cell ptr y out of range nil');
    Check(LD.CellPtr(5, 0, 0) = nil, 'cell ptr bad layer nil');
    Check(LD.RowPtr(0, 2) <> nil, 'row ptr valid');
    Check(LD.RowPtr(0, 3) = nil, 'row ptr out of range nil');
    Check(LD.RowPtr(5, 0) = nil, 'row ptr bad layer nil');
  finally
    LD.Free;
  end;
end;

procedure TestDirty;
var
  LD: TCanvasDoc;
  LX0, LY0, LX1, LY1: Integer;
begin
  LD := TCanvasDoc.Create(8, 6);
  try
    LD.ConsumeDirtyRect(LX0, LY0, LX1, LY1);
    CheckEqual(Int64(0), Int64(LX0), 'initial dirty x0');
    CheckEqual(Int64(0), Int64(LY0), 'initial dirty y0');
    CheckEqual(Int64(7), Int64(LX1), 'initial dirty x1');
    CheckEqual(Int64(5), Int64(LY1), 'initial dirty y1');
    Check(not LD.IsDirty, 'consume clears dirty flag');

    LD.SetCell(0, 3, 2, CanvasMakeCell(1, TUI_WHITE, TUI_BLACK));
    LD.ConsumeDirtyRect(LX0, LY0, LX1, LY1);
    CheckEqual(Int64(3), Int64(LX0), 'single cell dirty x0');
    CheckEqual(Int64(2), Int64(LY0), 'single cell dirty y0');
    CheckEqual(Int64(3), Int64(LX1), 'single cell dirty x1');
    CheckEqual(Int64(2), Int64(LY1), 'single cell dirty y1');

    LD.SetCell(0, 6, 4, CanvasMakeCell(1, TUI_WHITE, TUI_BLACK));
    LD.SetCell(0, 1, 1, CanvasMakeCell(1, TUI_WHITE, TUI_BLACK));
    LD.ConsumeDirtyRect(LX0, LY0, LX1, LY1);
    CheckEqual(Int64(1), Int64(LX0), 'merge dirty x0');
    CheckEqual(Int64(1), Int64(LY0), 'merge dirty y0');
    CheckEqual(Int64(6), Int64(LX1), 'merge dirty x1');
    CheckEqual(Int64(4), Int64(LY1), 'merge dirty y1');

    { 逆序输入按实现语义折叠为单点(不交换): X1<X0 时取 X0 }
    LD.ClearDirty;
    LD.MarkDirtyRect(5, 4, 2, 1);
    LD.ConsumeDirtyRect(LX0, LY0, LX1, LY1);
    CheckEqual(Int64(5), Int64(LX0), 'inverted input collapses to x0');
    CheckEqual(Int64(4), Int64(LY0), 'inverted input collapses to y0');
    CheckEqual(Int64(5), Int64(LX1), 'inverted input collapses to x1');
    CheckEqual(Int64(4), Int64(LY1), 'inverted input collapses to y1');

    LD.ClearDirty;
    Check(not LD.IsDirty, 'clear dirty');
  finally
    LD.Free;
  end;
end;

procedure TestLayers;
var
  LD: TCanvasDoc;
  LI: Integer;
begin
  LD := TCanvasDoc.Create(2, 2);
  try
    LI := LD.NewLayer('L2');
    CheckEqual(Int64(1), Int64(LI), 'new layer index');
    CheckEqual(Int64(2), Int64(LD.LayerCount), 'two layers');
    CheckEqual(Int64(1), Int64(LD.ActiveIndex), 'new layer becomes active');
    Check(LD.LayerName(1) = 'L2', 'new layer name');

    LD.SetActive(0);
    CheckEqual(Int64(0), Int64(LD.ActiveIndex), 'set active back');
    LD.SetActive(9);
    CheckEqual(Int64(0), Int64(LD.ActiveIndex), 'set active ignores out of range');

    Check(LD.DeleteLayer(1), 'delete top layer');
    CheckEqual(Int64(1), Int64(LD.LayerCount), 'back to one layer');
    Check(not LD.DeleteLayer(0), 'refuse deleting last layer');

    LD.SetLayerName(0, 'Renamed');
    Check(LD.LayerName(0) = 'Renamed', 'rename layer');
    LD.SetLayerName(9, 'x');
    Check(not (LD.LayerName(9) = 'x'), 'rename out of range ignored');
    Check(LD.LayerName(9) = '', 'layer name out of range empty');
  finally
    LD.Free;
  end;
end;

procedure TestLayerLimit;
var
  LD: TCanvasDoc;
  LI: Integer;
begin
  LD := TCanvasDoc.Create(1, 1);
  try
    for LI := 1 to CANVAS_MAX_LAYERS - 1 do
      Check(LD.NewLayer('L') >= 0, 'layer within limit');
    CheckEqual(Int64(-1), Int64(LD.NewLayer('Over')), 'layer over limit rejected');
    CheckEqual(Int64(CANVAS_MAX_LAYERS), Int64(LD.LayerCount), 'layer count at cap');
  finally
    LD.Free;
  end;
end;

procedure TestLayerVisibility;
var
  LD: TCanvasDoc;
begin
  LD := TCanvasDoc.Create(2, 2);
  try
    LD.NewLayer('L2');
    Check(LD.LayerVisible(1), 'new layer visible');
    LD.SetLayerVisible(1, False);
    Check(not LD.LayerVisible(1), 'layer hidden');
    LD.ToggleLayerVisible(1);
    Check(LD.LayerVisible(1), 'toggle back to visible');
    LD.SetLayerVisible(9, False);
    Check(not (LD.LayerVisible(9)), 'visibility out of range safe');
  finally
    LD.Free;
  end;
end;

procedure TestLayerContentIndependence;
var
  LD: TCanvasDoc;
begin
  LD := TCanvasDoc.Create(2, 2);
  try
    LD.NewLayer('L2');
    LD.SetCell(0, 1, 1, CanvasMakeCell(Ord('A'), TUI_RED, TUI_BLACK));
    LD.SetCell(1, 0, 0, CanvasMakeCell(Ord('B'), TUI_GREEN, TUI_BLACK));
    Check(LD.GetCell(1, 1, 1).Ch = 0, 'layer 1 untouched by layer 0 write');
    Check(LD.GetCell(0, 0, 0).Ch = 0, 'layer 0 untouched by layer 1 write');
    Check(LD.GetCell(0, 1, 1).Ch = Ord('A'), 'layer 0 write kept');
    Check(LD.GetCell(1, 0, 0).Ch = Ord('B'), 'layer 1 write kept');
  finally
    LD.Free;
  end;
end;

procedure TestClear;
var
  LD: TCanvasDoc;
begin
  LD := TCanvasDoc.Create(2, 2);
  try
    LD.NewLayer('L2');
    LD.SetCell(0, 0, 0, CanvasMakeCell(Ord('A'), TUI_RED, TUI_BLACK));
    LD.SetCell(1, 1, 1, CanvasMakeCell(Ord('B'), TUI_GREEN, TUI_BLACK));
    LD.ClearLayer(1);
    Check(LD.GetCell(1, 1, 1).Ch = 0, 'clear layer empties it');
    Check(LD.GetCell(0, 0, 0).Ch = Ord('A'), 'other layer untouched by clear layer');
    LD.ClearLayer(9);
    Check(LD.GetCell(0, 0, 0).Ch = Ord('A'), 'clear layer out of range ignored');
    LD.ClearAll;
    Check(LD.GetCell(0, 0, 0).Ch = 0, 'clear all empties layer 0');
  finally
    LD.Free;
  end;
end;

procedure TestResize;
var
  LD: TCanvasDoc;
begin
  LD := TCanvasDoc.Create(8, 4);
  try
    LD.SetCell(0, 5, 3, CanvasMakeCell(Ord('X'), TUI_RED, TUI_BLACK));
    LD.Resize(16, 8);
    CheckEqual(Int64(16), Int64(LD.Width), 'resize width');
    CheckEqual(Int64(8), Int64(LD.Height), 'resize height');
    Check(LD.GetCell(0, 5, 3).Ch = Ord('X'), 'resize keeps overlapping cell');
    Check(LD.GetCell(0, 15, 7).Ch = 0, 'resize new area empty');
  finally
    LD.Free;
  end;
end;

procedure TestResizeShrink;
var
  LD: TCanvasDoc;
begin
  LD := TCanvasDoc.Create(6, 4);
  try
    LD.SetCell(0, 2, 1, CanvasMakeCell(Ord('K'), TUI_CYAN, TUI_BLACK));
    LD.SetCell(0, 5, 3, CanvasMakeCell(Ord('Z'), TUI_MAGENTA, TUI_BLACK));
    LD.Resize(3, 2);
    Check(LD.GetCell(0, 2, 1).Ch = Ord('K'), 'shrink keeps inside cell');
    Check(LD.GetCell(0, 5, 3).Ch = 0, 'shrink drops outside cell');
    CheckEqual(Int64(3), Int64(LD.Width), 'shrink width');
    CheckEqual(Int64(2), Int64(LD.Height), 'shrink height');
  finally
    LD.Free;
  end;
end;

procedure TestResizeMultiLayer;
var
  LD: TCanvasDoc;
begin
  LD := TCanvasDoc.Create(2, 2);
  try
    LD.NewLayer('L2');
    LD.SetCell(0, 1, 1, CanvasMakeCell(Ord('A'), TUI_RED, TUI_BLACK));
    LD.SetCell(1, 0, 0, CanvasMakeCell(Ord('B'), TUI_GREEN, TUI_BLACK));
    LD.Resize(4, 4);
    Check(LD.GetCell(0, 1, 1).Ch = Ord('A'), 'layer 0 kept after multi-layer resize');
    Check(LD.GetCell(1, 0, 0).Ch = Ord('B'), 'layer 1 kept after multi-layer resize');
    Check(LD.GetCell(1, 1, 1).Ch = 0, 'layers not aliased after resize');
    LD.SetCell(1, 1, 1, CanvasMakeCell(Ord('C'), TUI_BLUE, TUI_BLACK));
    Check(LD.GetCell(0, 1, 1).Ch = Ord('A'), 'layer 0 unaffected by late layer 1 write');
  finally
    LD.Free;
  end;
end;

procedure TestResizeSameSize;
var
  LD: TCanvasDoc;
begin
  LD := TCanvasDoc.Create(3, 3);
  try
    LD.ClearDirty;
    LD.Resize(3, 3);
    Check(not LD.IsDirty, 'same-size resize is no-op (dirty untouched)');
  finally
    LD.Free;
  end;
end;

procedure TestResizeClamp;
var
  LD: TCanvasDoc;
begin
  LD := TCanvasDoc.Create(4, 4);
  try
    LD.Resize(0, -2);
    CheckEqual(Int64(1), Int64(LD.Width), 'resize clamps width');
    CheckEqual(Int64(1), Int64(LD.Height), 'resize clamps height');
  finally
    LD.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.canvas.base');
  T.Test('size', @TestSize);
  T.Test('create', @TestCreate);
  T.Test('create clamps size', @TestCreateClamps);
  T.Test('cell access', @TestCellAccess);
  T.Test('dirty rects', @TestDirty);
  T.Test('layers', @TestLayers);
  T.Test('layer limit', @TestLayerLimit);
  T.Test('layer visibility', @TestLayerVisibility);
  T.Test('layer content independence', @TestLayerContentIndependence);
  T.Test('clear', @TestClear);
  T.Test('resize', @TestResize);
  T.Test('resize shrink', @TestResizeShrink);
  T.Test('resize multi-layer', @TestResizeMultiLayer);
  T.Test('resize same size no-op', @TestResizeSameSize);
  T.Test('resize clamps', @TestResizeClamp);
  if not T.Run then Halt(1);
end.