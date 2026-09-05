{**
 * nextpas.core.tui.canvas.clipboard - 字符画布应用内剪贴板
 *
 * 单槽字符快照（不跨进程、不持久化）。
 * CopyFrom 抓取指定层矩形快照（裁剪到文档边界），记录选区原点;
 * PasteAt 以 (AX,AY) 为左上角经 builder 落回文档，越界部分整体裁剪，
 * 增量并入同一个撤销栈。
 *}

unit nextpas.core.tui.canvas.clipboard;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.edit;

type
  {** @desc 单槽剪贴板：快照是纯 TCanvasCell 值数组（无托管字段），整块 Move 安全 *}
  TCanvasClipboard = class
  private
    FWidth: Integer;
    FHeight: Integer;
    FCells: array of TCanvasCell;
    FAnchorX: Integer;
    FAnchorY: Integer;
  public
    { 剪贴板无内容 }
    function Empty: Boolean;
    { 复制指定层矩形快照(含锚点 X0,Y0); 空/越界选区返回 False }
    function CopyFrom(ADoc: TCanvasDoc; ALayer, X0, Y0, X1, Y1: Integer): Boolean;
    { 以 (AX,AY) 为左上角粘贴快照, 经 builder 记录增量; 越界部分裁剪; 空剪贴板返回 False }
    function PasteAt(ADoc: TCanvasDoc; ALayer, AX, AY: Integer;
      ABuilder: TCanvasEditBuilder): Boolean;
    { 复制时选区原点 }
    property AnchorX: Integer read FAnchorX;
    property AnchorY: Integer read FAnchorY;
  end;

{** @desc 选区规范化为闭区间（覆盖任意拖拽顺序）；供笔画/选区调用方共用 *}
procedure NormalizeRect(AX0, AY0, AX1, AY1: Integer;
  out NX0, NY0, NX1, NY1: Integer);

implementation

procedure NormalizeRect(AX0, AY0, AX1, AY1: Integer;
  out NX0, NY0, NX1, NY1: Integer);
begin
  if AX0 <= AX1 then
  begin
    NX0 := AX0;
    NX1 := AX1;
  end
  else
  begin
    NX0 := AX1;
    NX1 := AX0;
  end;
  if AY0 <= AY1 then
  begin
    NY0 := AY0;
    NY1 := AY1;
  end
  else
  begin
    NY0 := AY1;
    NY1 := AY0;
  end;
end;

function TCanvasClipboard.Empty: Boolean;
begin
  Result := Length(FCells) = 0;
end;

function TCanvasClipboard.CopyFrom(ADoc: TCanvasDoc; ALayer, X0, Y0, X1,
  Y1: Integer): Boolean;
var
  NX0, NY0, NX1, NY1: Integer;   { 规范化选区 }
  CX0, CY0, CX1, CY1: Integer;   { 裁剪后仍在文档内的区域 }
  FW, FH: Integer;
  R: Integer;
  P: PCanvasCell;
begin
  Result := False;
  if ADoc = nil then
    Exit;
  NormalizeRect(X0, Y0, X1, Y1, NX0, NY0, NX1, NY1);
  { 裁剪出与文档重叠部分; 无重叠格 = 空/越界选区, 复制失败且旧快照保留 }
  CX0 := NX0;
  if CX0 < 0 then CX0 := 0;
  CY0 := NY0;
  if CY0 < 0 then CY0 := 0;
  CX1 := NX1;
  if CX1 > ADoc.Width - 1 then CX1 := ADoc.Width - 1;
  CY1 := NY1;
  if CY1 > ADoc.Height - 1 then CY1 := ADoc.Height - 1;
  if (CX0 > CX1) or (CY0 > CY1) then
    Exit;
  FW := CX1 - CX0 + 1;
  FH := CY1 - CY0 + 1;
  SetLength(FCells, FW * FH);
  { 逐行搬入, 行内整块 Move; 非法层/空层 RowPtr 为 nil, 该行记空白 }
  for R := 0 to FH - 1 do
  begin
    P := ADoc.RowPtr(ALayer, CY0 + R);
    if P <> nil then
      Move(P[CX0], FCells[R * FW], FW * SizeOf(TCanvasCell))
    else
      FillChar(FCells[R * FW], FW * SizeOf(TCanvasCell), 0);
  end;
  FWidth := FW;
  FHeight := FH;
  FAnchorX := NX0;
  FAnchorY := NY0;
  Result := True;
end;

function TCanvasClipboard.PasteAt(ADoc: TCanvasDoc; ALayer, AX, AY: Integer;
  ABuilder: TCanvasEditBuilder): Boolean;
var
  R, C: Integer;
begin
  Result := False;
  if ADoc = nil then
    Exit;
  if (ALayer < 0) or (ALayer >= ADoc.LayerCount) then
    Exit;                       { 目标层不存在, 拒绝而不是静默乱贴 }
  if (ABuilder = nil) or Empty then
    Exit;
  { 快照左上角对齐 (AX,AY); 越界格由 builder 的 SetCell 静默裁剪 }
  for R := 0 to FHeight - 1 do
    for C := 0 to FWidth - 1 do
      ABuilder.SetPixel(AX + C, AY + R, FCells[R * FWidth + C]);
  Result := True;
end;

end.
