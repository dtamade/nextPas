unit nextpas.core.tui.canvas.view;

{**
 * @desc 画布视图变换：文档坐标 ↔ 屏幕坐标，缩放（1..4）/平移/裁剪。
 *
 * 纯数学（无 TUI 依赖），供画布渲染器与事件命中测试使用。缩放时保持
 * 中心文档点不动；ScreenToDoc 用向下取整除法，平移可为负（视口可位于
 * 文档左上之外）。
 *
 * 另含屏幕行脏标记，供渲染器逐行增量重绘：文档矩形脏区映射到其覆盖的
 * 所有屏幕行，有全量脏标记可越过行粒度。
 *}

{$I nextpas.core.settings.inc}

interface

type
  TCanvasView = class
  private
    FZoom: Integer;             { 1..4 }
    FX, FY: Integer;            { 视口左上角对应的文档坐标（可负） }
    FScreenX, FScreenY: Integer;
    FScreenW, FScreenH: Integer;
    FDocW, FDocH: Integer;
    FFullDirty: Boolean;
    FDirty: array of Boolean;
    function FloorDiv(A, B: Integer): Integer;
  public
    constructor Create;

    procedure SetScreenRect(AX, AY, AWidth, AHeight: Integer);
    procedure SetDocSize(AWidth, AHeight: Integer);

    property Zoom: Integer read FZoom;
    property OriginX: Integer read FX;
    property OriginY: Integer read FY;
    property ScreenX: Integer read FScreenX;
    property ScreenY: Integer read FScreenY;
    property ScreenW: Integer read FScreenW;
    property ScreenH: Integer read FScreenH;

    { 缩放：保持中心文档点不动；限制 1..4。 }
    procedure SetZoom(AZoom: Integer; ACenterDocX, ACenterDocY: Integer);
    { 平移（屏幕格数）。 }
    procedure Pan(ADX, ADY: Integer);
    { 居中某文档点（把该点放到视口中心）。 }
    procedure CenterOn(ADocX, ADocY: Integer);

    { 映射。DocToScreen 返回该文档格左上角屏幕坐标。 }
    function DocToScreenX(AX: Integer): Integer;
    function DocToScreenY(AY: Integer): Integer;
    { ScreenToDoc 用向下取整，平移可负。 }
    function ScreenToDocX(ASX: Integer): Integer;
    function ScreenToDocY(ASY: Integer): Integer;

    { 可见文档窗口（裁剪到 [0,DocW)x[0,DocH)）；False = 无可见区。 }
    function VisibleDocRect(out X0, Y0, X1, Y1: Integer): Boolean;

    { 行脏标记（屏幕行） }
    procedure MarkAllDirty;
    procedure MarkDocRectDirty(X0, Y0, X1, Y1: Integer);
    procedure MarkScreenRectDirty(SX0, SY0, SX1, SY1: Integer);
    function IsFullDirty: Boolean;
    function IsRowDirty(ARow: Integer): Boolean;
    function AnyDirty: Boolean;
    procedure ConsumeDirty(out AFull: Boolean);
    { 标记脏行是否覆盖画布全部行。 }
    function AllRowsDirty: Boolean;
  end;

implementation

constructor TCanvasView.Create;
begin
  inherited Create;
  FZoom := 1;
  FX := 0;
  FY := 0;
  FDocW := 1;
  FDocH := 1;
  FFullDirty := False;
end;

function TCanvasView.FloorDiv(A, B: Integer): Integer;
begin
  if B <= 0 then
    Result := 0
  else if A >= 0 then
    Result := A div B
  else
    Result := -((B - 1 - A) div B);
end;

procedure TCanvasView.SetScreenRect(AX, AY, AWidth, AHeight: Integer);
begin
  FScreenX := AX;
  FScreenY := AY;
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FScreenW := AWidth;
  FScreenH := AHeight;
  SetLength(FDirty, FScreenH);
  if FScreenH > 0 then
    FillChar(FDirty[0], Length(FDirty), 0);
  MarkAllDirty;
end;

procedure TCanvasView.SetDocSize(AWidth, AHeight: Integer);
begin
  if AWidth < 1 then AWidth := 1;
  if AHeight < 1 then AHeight := 1;
  FDocW := AWidth;
  FDocH := AHeight;
  MarkAllDirty;
end;

procedure TCanvasView.SetZoom(AZoom: Integer; ACenterDocX, ACenterDocY: Integer);
var
  NewX, NewY: Integer;
begin
  if AZoom < 1 then AZoom := 1;
  if AZoom > 4 then AZoom := 4;
  if AZoom = FZoom then
  begin
    MarkAllDirty;
    Exit;
  end;
  { 保持中心点不动：中心屏幕位置对应的文档坐标不变 }
  NewX := ACenterDocX - FloorDiv(FScreenW div 2, AZoom);
  NewY := ACenterDocY - FloorDiv(FScreenH div 2, AZoom);
  FZoom := AZoom;
  FX := NewX;
  FY := NewY;
  MarkAllDirty;
end;

procedure TCanvasView.Pan(ADX, ADY: Integer);
begin
  Inc(FX, ADX);
  Inc(FY, ADY);
  MarkAllDirty;
end;

procedure TCanvasView.CenterOn(ADocX, ADocY: Integer);
begin
  FX := ADocX - FloorDiv(FScreenW div 2, FZoom);
  FY := ADocY - FloorDiv(FScreenH div 2, FZoom);
  MarkAllDirty;
end;

function TCanvasView.DocToScreenX(AX: Integer): Integer;
begin
  Result := FScreenX + (AX - FX) * FZoom;
end;

function TCanvasView.DocToScreenY(AY: Integer): Integer;
begin
  Result := FScreenY + (AY - FY) * FZoom;
end;

function TCanvasView.ScreenToDocX(ASX: Integer): Integer;
begin
  Result := FX + FloorDiv(ASX - FScreenX, FZoom);
end;

function TCanvasView.ScreenToDocY(ASY: Integer): Integer;
begin
  Result := FY + FloorDiv(ASY - FScreenY, FZoom);
end;

function TCanvasView.VisibleDocRect(out X0, Y0, X1, Y1: Integer): Boolean;
var
  DX0, DY0, DX1, DY1: Integer;
begin
  Result := (FScreenW > 0) and (FScreenH > 0);
  if not Result then
    Exit;
  { 视口左上/右下角的文档坐标 }
  DX0 := ScreenToDocX(FScreenX);
  DY0 := ScreenToDocY(FScreenY);
  DX1 := ScreenToDocX(FScreenX + FScreenW - 1);
  DY1 := ScreenToDocY(FScreenY + FScreenH - 1);
  X0 := DX0;
  Y0 := DY0;
  X1 := DX1;
  Y1 := DY1;
  if X0 < 0 then X0 := 0;
  if Y0 < 0 then Y0 := 0;
  if X1 > FDocW - 1 then X1 := FDocW - 1;
  if Y1 > FDocH - 1 then Y1 := FDocH - 1;
  Result := (X0 <= X1) and (Y0 <= Y1);
end;

procedure TCanvasView.MarkAllDirty;
begin
  FFullDirty := True;
end;

procedure TCanvasView.MarkScreenRectDirty(SX0, SY0, SX1, SY1: Integer);
var
  R: Integer;
begin
  if FFullDirty then
    Exit;
  if SX1 < SX0 then SX1 := SX0;
  if SY1 < SY0 then SY1 := SY0;
  for R := SY0 to SY1 do
    if (R >= 0) and (R < FScreenH) then
      FDirty[R] := True;
end;

procedure TCanvasView.MarkDocRectDirty(X0, Y0, X1, Y1: Integer);
begin
  if FFullDirty then
    Exit;
  { 文档矩形 → 其覆盖的屏幕行（每文档格占 Zoom 屏行） }
  MarkScreenRectDirty(DocToScreenX(X0), DocToScreenY(Y0),
    DocToScreenX(X1) + FZoom - 1, DocToScreenY(Y1) + FZoom - 1);
end;

function TCanvasView.IsFullDirty: Boolean;
begin
  Result := FFullDirty;
end;

function TCanvasView.IsRowDirty(ARow: Integer): Boolean;
begin
  if (ARow < 0) or (ARow >= FScreenH) then
    Exit(False);
  Result := FFullDirty or FDirty[ARow];
end;

function TCanvasView.AnyDirty: Boolean;
var
  I: Integer;
begin
  if FFullDirty then
    Exit(True);
  for I := 0 to FScreenH - 1 do
    if FDirty[I] then
      Exit(True);
  Result := False;
end;

procedure TCanvasView.ConsumeDirty(out AFull: Boolean);
var
  I: Integer;
begin
  AFull := FFullDirty;
  FFullDirty := False;
  for I := 0 to FScreenH - 1 do
    FDirty[I] := False;
end;

function TCanvasView.AllRowsDirty: Boolean;
var
  I: Integer;
begin
  for I := 0 to FScreenH - 1 do
    if not (FFullDirty or FDirty[I]) then
      Exit(False);
  Result := True;
end;

end.