unit nextpas.core.tui.widget.scrollbar;

{**
 * @desc TScrollbar — 滚动条原语（track/thumb 计算 + 命中测试 + 渲染）。
 *
 * 垂直方向。消费方设置 TotalItems/VisibleItems/ScrollOffset，调 Render 绘制。
 * 鼠标交互通过 HitAt/OffsetFromDragY 计算新 offset。
 *
 * 这是一个"哑" record——不持有超出消费方传入的状态。Drag 状态由外部
 * TPointerCapture + TInteractionSession 管理。
 *
 * @note 不实现 IWidget（Render 需要额外 TScrollbarStyle 参数），
 *       作为其他 widget 的内部构建块使用。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer;

type
  TScrollbarHit = (shNone, shAbove, shThumb, shBelow);

  TScrollbarStyle = record
    TrackChar: AnsiChar;
    ThumbChar: AnsiChar;
    TrackStyle: TStyle;
    ThumbStyle: TStyle;
  end;

  TScrollbar = record
    TotalItems: Integer;
    VisibleItems: Integer;
    ScrollOffset: Integer;

    function ThumbStart(ATrackHeight: Integer): Integer;
    function ThumbSize(ATrackHeight: Integer): Integer;
    function HitAt(ATrackArea: TRect; AY: Integer): TScrollbarHit;
    function OffsetFromDragY(ATrackArea: TRect; ADragY: Integer): Integer;
    function PageUp: Integer;
    function PageDown: Integer;
    function Clamped: Integer;
    procedure Render(const ATrackArea: TRect; ABuffer: TBuffer;
      const AStyle: TScrollbarStyle);
  end;

function DefaultScrollbarStyle: TScrollbarStyle;

implementation

function DefaultScrollbarStyle: TScrollbarStyle;
begin
  Result.TrackChar := ' ';
  Result.ThumbChar := ' ';
  Result.TrackStyle := TStyle.Default.WithBg(IndexedColor(236));
  Result.ThumbStyle := TStyle.Default.WithBg(IndexedColor(245));
end;

function TScrollbar.ThumbStart(ATrackHeight: Integer): Integer;
begin
  if TotalItems <= VisibleItems then Exit(0);
  Result := (ScrollOffset * (ATrackHeight - ThumbSize(ATrackHeight))) div (TotalItems - VisibleItems);
  if Result < 0 then Result := 0;
end;

function TScrollbar.ThumbSize(ATrackHeight: Integer): Integer;
begin
  if TotalItems <= 0 then Exit(ATrackHeight);
  Result := (VisibleItems * ATrackHeight) div TotalItems;
  if Result < 1 then Result := 1;
  if Result > ATrackHeight then Result := ATrackHeight;
end;

function TScrollbar.HitAt(ATrackArea: TRect; AY: Integer): TScrollbarHit;
var
  LRelY, LTS, LTSz: Integer;
begin
  Result := shNone;
  if (AY < ATrackArea.Y) or (AY >= ATrackArea.Y + ATrackArea.Height) then Exit;
  LRelY := AY - ATrackArea.Y;
  LTS := ThumbStart(ATrackArea.Height);
  LTSz := ThumbSize(ATrackArea.Height);
  if LRelY < LTS then Result := shAbove
  else if LRelY < LTS + LTSz then Result := shThumb
  else Result := shBelow;
end;

function TScrollbar.OffsetFromDragY(ATrackArea: TRect; ADragY: Integer): Integer;
var
  LRelY, LTrackH, LTSz, LMaxOffset, LAvailTrack: Integer;
begin
  LTrackH := ATrackArea.Height;
  LTSz := ThumbSize(LTrackH);
  LAvailTrack := LTrackH - LTSz;
  if LAvailTrack <= 0 then Exit(0);
  LMaxOffset := TotalItems - VisibleItems;
  if LMaxOffset <= 0 then Exit(0);
  LRelY := ADragY - ATrackArea.Y;
  if LRelY < 0 then LRelY := 0;
  if LRelY > LAvailTrack then LRelY := LAvailTrack;
  Result := (LRelY * LMaxOffset) div LAvailTrack;
end;

function TScrollbar.PageUp: Integer;
begin
  Result := ScrollOffset - VisibleItems;
  if Result < 0 then Result := 0;
end;

function TScrollbar.PageDown: Integer;
var
  LMax: Integer;
begin
  LMax := TotalItems - VisibleItems;
  if LMax < 0 then LMax := 0;
  Result := ScrollOffset + VisibleItems;
  if Result > LMax then Result := LMax;
end;

function TScrollbar.Clamped: Integer;
var
  LMax: Integer;
begin
  LMax := TotalItems - VisibleItems;
  if LMax < 0 then LMax := 0;
  Result := ScrollOffset;
  if Result < 0 then Result := 0;
  if Result > LMax then Result := LMax;
end;

procedure TScrollbar.Render(const ATrackArea: TRect; ABuffer: TBuffer;
  const AStyle: TScrollbarStyle);
var
  LY, LTS, LTSz: Integer;
  LC: TCell;
  LP: PCell;
begin
  if ATrackArea.IsEmpty or (ATrackArea.Width < 1) then Exit;
  LTS := ThumbStart(ATrackArea.Height);
  LTSz := ThumbSize(ATrackArea.Height);
  for LY := 0 to ATrackArea.Height - 1 do
  begin
    LC := CELL_EMPTY;
    if (LY >= LTS) and (LY < LTS + LTSz) then
    begin
      CellSetSymbolAscii(LC, AStyle.ThumbChar);
      CellApplyStyle(LC, AStyle.ThumbStyle);
    end
    else
    begin
      CellSetSymbolAscii(LC, AStyle.TrackChar);
      CellApplyStyle(LC, AStyle.TrackStyle);
    end;
    LP := ABuffer.CellAt(ATrackArea.X, ATrackArea.Y + LY);
    if LP <> nil then LP^ := LC;
  end;
end;

end.
