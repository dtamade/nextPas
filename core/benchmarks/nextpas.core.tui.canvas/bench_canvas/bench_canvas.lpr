program bench_canvas;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.raster,
  nextpas.core.tui.canvas.edit,
  nextpas.core.tui.canvas.view,
  nextpas.core.bench;

type
  TNullCollector = record
    N: Integer;
    procedure OnPoint(AX, AY: Integer);
  end;

procedure TNullCollector.OnPoint(AX, AY: Integer);
begin
  Inc(N);
end;

var
  D: TCanvasDoc;
  Log: TCanvasUndoLog;
  View: TCanvasView;
  Collector: TNullCollector;
  Stroke: TCanvasCell;

const
  DW = 200;
  DH = 100;

procedure BenchSetCell(AIters: Int64);
var
  LI: Int64;
begin
  for LI := 1 to AIters do
    D.SetCell(0, Integer(LI mod DW), Integer((LI div DW) mod DH), Stroke);
end;

procedure BenchCellPtrWrite(AIters: Int64);
var
  LI: Int64;
  P: PCanvasCell;
begin
  for LI := 1 to AIters do
  begin
    P := D.CellPtr(0, Integer(LI mod DW), Integer((LI div DW) mod DH));
    P^ := Stroke;
  end;
end;

procedure BenchDirtyConsume(AIters: Int64);
var
  LI: Int64;
  X0, Y0, X1, Y1: Integer;
begin
  for LI := 1 to AIters do
  begin
    D.ClearDirty;
    D.MarkDirtyRect(0, 0, DW - 1, DH - 1);
    D.ConsumeDirtyRect(X0, Y0, X1, Y1);
  end;
end;

procedure BenchRasterLine(AIters: Int64);
var
  LI: Int64;
begin
  for LI := 1 to AIters do
    RasterLine(0, 0, DW - 1, DH - 1, @Collector.OnPoint);
end;

procedure BenchRasterRectFill(AIters: Int64);
var
  LI: Int64;
begin
  for LI := 1 to AIters do
    RasterRectFill(0, 0, DW - 1, DH - 1, @Collector.OnPoint);
end;

procedure BenchRasterEllipseFill(AIters: Int64);
var
  LI: Int64;
begin
  for LI := 1 to AIters do
    RasterEllipseFill(0, 0, DW - 1, DH - 1, @Collector.OnPoint);
end;

procedure BenchUndoPush(AIters: Int64);
var
  LI: Int64;
  I: Integer;
  Op: TCanvasEditOp;
begin
  for LI := 1 to AIters do
  begin
    Op.Layer := 0;
    SetLength(Op.Deltas, 8);
    for I := 0 to 7 do
    begin
      Op.Deltas[I].X := Integer(LI) + I;
      Op.Deltas[I].Y := Integer(LI);
      Op.Deltas[I].New := Stroke;
    end;
    Log.Push(Op);
  end;
end;

procedure BenchViewMap(AIters: Int64);
var
  LI: Int64;
  S: Integer;
begin
  for LI := 1 to AIters do
  begin
    S := View.ScreenToDocX(Integer(LI mod 100));
    S := View.ScreenToDocY(S);
    S := View.DocToScreenX(S);
    View.MarkDocRectDirty(S, 0, S + 1, 3);
  end;
end;

var
  LResults: IBenchResults;
begin
  D := TCanvasDoc.Create(DW, DH);
  Log := TCanvasUndoLog.Create;
  View := TCanvasView.Create;
  try
    View.SetScreenRect(0, 0, 100, 60);
    View.SetDocSize(DW, DH);
    View.SetZoom(2, 50, 30);
    Stroke := CanvasMakeCell(Ord('A'), TUI_WHITE, TUI_BLACK);

    LResults := TBenchSuite.Create('nextpas.core.tui.canvas')
      .AddLoop('doc SetCell + dirty (200x100)', @BenchSetCell)
      .AddLoop('doc CellPtr direct write', @BenchCellPtrWrite)
      .AddLoop('doc dirty consume', @BenchDirtyConsume)
      .AddLoop('raster line 200x100', @BenchRasterLine)
      .AddLoop('raster rect fill 200x100', @BenchRasterRectFill)
      .AddLoop('raster ellipse fill 200x100', @BenchRasterEllipseFill)
      .AddLoop('undo log push (8 deltas)', @BenchUndoPush)
      .AddLoop('view map + dirty rows', @BenchViewMap)
      .Run;
    WriteLn(LResults.PrintToConsole);
    Write('sanity: collector hinted ');
    WriteLn(Collector.N, ' points');
  finally
    View.Free;
    Log.Free;
    D.Free;
  end;
end.