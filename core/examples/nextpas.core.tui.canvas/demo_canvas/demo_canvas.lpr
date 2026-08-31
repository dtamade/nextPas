program demo_canvas;

{**
 * 字符像素画布演示：画一栋小房子（矩形墙 + 三角屋顶线 + 椭圆窗），
 * 演示增量撤销/重做、视图缩放与 ASCII 快照输出。
 *
 * 运行: make run  (构建目录下直接执行亦可)
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.raster,
  nextpas.core.tui.canvas.edit,
  nextpas.core.tui.canvas.view,
  nextpas.core.text.format,
  nextpas.core.text.conv;

type
  { 光栅化回调适配器: 每点经 TCanvasEditBuilder.SetPixel 写入文档并记录增量 }
  TStrokeWriter = class
  private
    FBuilder: TCanvasEditBuilder;
    FCell: TCanvasCell;
  public
    constructor Create(ABuilder: TCanvasEditBuilder; const ACell: TCanvasCell);
    procedure OnPoint(AX, AY: Integer);
  end;

constructor TStrokeWriter.Create(ABuilder: TCanvasEditBuilder; const ACell: TCanvasCell);
begin
  inherited Create;
  FBuilder := ABuilder;
  FCell := ACell;
end;

procedure TStrokeWriter.OnPoint(AX, AY: Integer);
begin
  FBuilder.SetPixel(AX, AY, FCell);
end;

procedure PrintDoc(ADoc: TCanvasDoc; const ATitle: string);
var
  Y, X: Integer;
  LC: TCanvasCell;
begin
  WriteLn('--- ' + ATitle + ' ---');
  for Y := 0 to ADoc.Height - 1 do
  begin
    for X := 0 to ADoc.Width - 1 do
    begin
      LC := ADoc.GetCell(0, X, Y);
      if LC.Ch = 0 then
        Write(' ')
      else if LC.Ch < 128 then
        Write(Chr(LC.Ch))
      else
        Write('#');
    end;
    WriteLn;
  end;
end;

var
  D: TCanvasDoc;
  LBuilder: TCanvasEditBuilder;
  LWriter: TStrokeWriter;
  LLog: TCanvasUndoLog;
  LView: TCanvasView;
  LOp: TCanvasEditOp;
  LRoom, LRoof, LWindow: TCanvasCell;
  LFull: Boolean;
begin
  D := TCanvasDoc.Create(28, 14);
  LLog := TCanvasUndoLog.Create;
  LBuilder := TCanvasEditBuilder.Create(D, 0);
  try
    LRoom := CanvasMakeCell(Ord('#'), TUI_YELLOW, TUI_BLUE);
    LRoof := CanvasMakeCell(Ord('A'), TUI_RED, TUI_BLACK);
    LWindow := CanvasMakeCell(Ord('o'), TUI_CYAN, TUI_BLACK);

    { 第一笔: 墙 }
    LWriter := TStrokeWriter.Create(LBuilder, LRoom);
    try
      RasterRectOutline(2, 8, 25, 13, @LWriter.OnPoint);
    finally
      LWriter.Free;
    end;
    LLog.Push(LBuilder.ToOp);
    LBuilder.Clear;

    { 第二笔: 屋顶 }
    LWriter := TStrokeWriter.Create(LBuilder, LRoof);
    try
      RasterLine(1, 8, 13, 1, @LWriter.OnPoint);
      RasterLine(13, 1, 26, 8, @LWriter.OnPoint);
    finally
      LWriter.Free;
    end;
    LLog.Push(LBuilder.ToOp);
    LBuilder.Clear;

    { 第三笔: 椭圆窗 }
    LWriter := TStrokeWriter.Create(LBuilder, LWindow);
    try
      RasterEllipseFill(10, 5, 16, 10, @LWriter.OnPoint);
    finally
      LWriter.Free;
    end;
    LLog.Push(LBuilder.ToOp);
    LBuilder.Clear;

    PrintDoc(D, 'house (3 strokes in undo stack)');

    { 撤销最后一笔(窗消失), 再重做(窗回来) }
    LOp := LLog.Undo;
    CanvasApplyOpInverse(D, LOp);
    PrintDoc(D, 'after undo (window erased)');

    LOp := LLog.Redo;
    CanvasApplyOp(D, LOp);
    PrintDoc(D, 'after redo (window back)');

    { 视图: 缩放 2 倍并居中, 显示映射与行脏信息 }
    LView := TCanvasView.Create;
    try
      LView.SetScreenRect(0, 0, 56, 28);
      LView.SetDocSize(D.Width, D.Height);
      LView.SetZoom(2, 14, 7);
      WriteLn(TextFormat('view: zoom=%d origin=(%d,%d) doc(14,7)->screen(%d,%d)',
        [LView.Zoom, LView.OriginX, LView.OriginY,
         LView.DocToScreenX(14), LView.DocToScreenY(7)]));
      LView.ConsumeDirty(LFull);
      WriteLn(TextFormat('view dirty consumed: full=%s', [BoolToStr(LFull)]));
      D.SetCell(0, 14, 7, CanvasMakeCell(Ord('*'), TUI_GREEN, TUI_BLACK));
      LView.MarkDocRectDirty(14, 7, 14, 7);
      WriteLn(TextFormat('doc(14,7) mark -> screen rows %d..%d dirty (zoom %d)',
        [LView.DocToScreenY(7), LView.DocToScreenY(7) + LView.Zoom - 1, LView.Zoom]));
    finally
      LView.Free;
    end;

    WriteLn('demo done (layers=', D.LayerCount, ', undo=', LLog.UndoCount,
      ', redo=', LLog.RedoCount, ')');
  finally
    LBuilder.Free;
    LLog.Free;
    D.Free;
  end;
end.