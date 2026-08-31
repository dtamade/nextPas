unit nextpas.core.tui.widget.scrollbar;

{$I nextpas.core.settings.inc}
{$packenum 1}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf;

type
  TScrollbarHit = (shNone, shAbove, shThumb, shBelow);

  IScrollbar = interface(IWidget)
    ['{B1C2D3E4-F5A6-7890-BCDE-F1A2B3C4D5E6}']
    function WithTotal(N: Integer): IScrollbar;
    function WithVisible(N: Integer): IScrollbar;
    function WithOffset(N: Integer): IScrollbar;
    { 符号收 AnsiString:块字符 █/▓ 等多字节字形是滚动条常态
      (单字节 AsciiChar 装不下,消费方被迫绕开 Render 手绘);
      单字符入参源码兼容,行为不变。符号须为单格宽字形,
      宽字形属调用方错误,按宽度 1 写入保网格一致 }
    function WithTrackChar(const ASymbol: AnsiString): IScrollbar;
    function WithThumbChar(const ASymbol: AnsiString): IScrollbar;
    function WithTrackStyle(const S: TStyle): IScrollbar;
    function WithThumbStyle(const S: TStyle): IScrollbar;
    function ThumbStart(ATrackHeight: Integer): Integer;
    function ThumbSize(ATrackHeight: Integer): Integer;
    function HitAt(const ATrackArea: TRect; AY: Integer): TScrollbarHit;
    function OffsetFromDragY(const ATrackArea: TRect; ADragY: Integer): Integer;
    function DragThumbTop(const ATrackArea: TRect;
      ADragY, AGrabY, AGrabThumbTop: Integer): Integer;
    function PageUp: Integer;
    function PageDown: Integer;
    function Clamped: Integer;
  end;

  TScrollbar = class(TInterfacedObject, IWidget, IScrollbar)
  private
    FTotalItems: Integer;
    FVisibleItems: Integer;
    FScrollOffset: Integer;
    FTrackChar: AnsiString;
    FThumbChar: AnsiString;
    FTrackStyle: TStyle;
    FThumbStyle: TStyle;
  public
    class function New: IScrollbar; static;

    function WithTotal(N: Integer): IScrollbar;
    function WithVisible(N: Integer): IScrollbar;
    function WithOffset(N: Integer): IScrollbar;
    function WithTrackChar(const ASymbol: AnsiString): IScrollbar;
    function WithThumbChar(const ASymbol: AnsiString): IScrollbar;
    function WithTrackStyle(const S: TStyle): IScrollbar;
    function WithThumbStyle(const S: TStyle): IScrollbar;
    function ThumbStart(ATrackHeight: Integer): Integer;
    function ThumbSize(ATrackHeight: Integer): Integer;
    function HitAt(const ATrackArea: TRect; AY: Integer): TScrollbarHit;
    function OffsetFromDragY(const ATrackArea: TRect; ADragY: Integer): Integer;
    function DragThumbTop(const ATrackArea: TRect;
      ADragY, AGrabY, AGrabThumbTop: Integer): Integer;
    function PageUp: Integer;
    function PageDown: Integer;
    function Clamped: Integer;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

class function TScrollbar.New: IScrollbar;
var LSelf: TScrollbar;
begin
  LSelf := TScrollbar.Create;
  LSelf.FTotalItems := 0;
  LSelf.FVisibleItems := 0;
  LSelf.FScrollOffset := 0;
  LSelf.FTrackChar := ' ';
  LSelf.FThumbChar := ' ';
  LSelf.FTrackStyle := TStyle.Default.WithBg(IndexedColor(236));
  LSelf.FThumbStyle := TStyle.Default.WithBg(IndexedColor(245));
  Result := LSelf;
end;

function TScrollbar.WithTotal(N: Integer): IScrollbar;
begin FTotalItems := N; Result := Self; end;

function TScrollbar.WithVisible(N: Integer): IScrollbar;
begin FVisibleItems := N; Result := Self; end;

function TScrollbar.WithOffset(N: Integer): IScrollbar;
begin FScrollOffset := N; Result := Self; end;

function TScrollbar.WithTrackChar(const ASymbol: AnsiString): IScrollbar;
begin FTrackChar := ASymbol; Result := Self; end;

function TScrollbar.WithThumbChar(const ASymbol: AnsiString): IScrollbar;
begin FThumbChar := ASymbol; Result := Self; end;

function TScrollbar.WithTrackStyle(const S: TStyle): IScrollbar;
begin FTrackStyle := S; Result := Self; end;

function TScrollbar.WithThumbStyle(const S: TStyle): IScrollbar;
begin FThumbStyle := S; Result := Self; end;

function TScrollbar.ThumbStart(ATrackHeight: Integer): Integer;
begin
  if FTotalItems <= FVisibleItems then Exit(0);
  Result := (Clamped * (ATrackHeight - ThumbSize(ATrackHeight)))
    div (FTotalItems - FVisibleItems);
  if Result < 0 then Result := 0;
end;

function TScrollbar.ThumbSize(ATrackHeight: Integer): Integer;
begin
  if FTotalItems <= 0 then Exit(ATrackHeight);
  Result := (FVisibleItems * ATrackHeight) div FTotalItems;
  if Result < 1 then Result := 1;
  if Result > ATrackHeight then Result := ATrackHeight;
end;

function TScrollbar.HitAt(const ATrackArea: TRect; AY: Integer): TScrollbarHit;
var LRelY, LTS, LTSz: Integer;
begin
  Result := shNone;
  { 未溢出(无滚动条)时整列无命中:退化态 ThumbSize 铺满整轨,
    不拦会把「点沟槽」误判成 shThumb(调用方渲染侧本就不画,
    命中/渲染同条件是消费方纪律,此处再兜一层底) }
  if FTotalItems <= FVisibleItems then Exit;
  if (AY < ATrackArea.Y) or (AY >= ATrackArea.Y + ATrackArea.Height) then Exit;
  LRelY := AY - ATrackArea.Y;
  LTS := ThumbStart(ATrackArea.Height);
  LTSz := ThumbSize(ATrackArea.Height);
  if LRelY < LTS then Result := shAbove
  else if LRelY < LTS + LTSz then Result := shThumb
  else Result := shBelow;
end;

function TScrollbar.OffsetFromDragY(const ATrackArea: TRect; ADragY: Integer): Integer;
var LRelY, LTrackH, LTSz, LMaxOffset, LAvailTrack: Integer;
begin
  LTrackH := ATrackArea.Height;
  LTSz := ThumbSize(LTrackH);
  LAvailTrack := LTrackH - LTSz;
  if LAvailTrack <= 0 then Exit(0);
  LMaxOffset := FTotalItems - FVisibleItems;
  if LMaxOffset <= 0 then Exit(0);
  LRelY := ADragY - ATrackArea.Y;
  if LRelY < 0 then LRelY := 0;
  if LRelY > LAvailTrack then LRelY := LAvailTrack;
  Result := (LRelY * LMaxOffset) div LAvailTrack;
end;

{ 拖动不跳变：指针 Y 减抓取基线（AGrabY-AGrabThumbTop）得拇指顶，再钳制到轨道内。
  直接映射指针会因「按下点不在拇指顶」产生首帧跳动 }
function TScrollbar.DragThumbTop(const ATrackArea: TRect;
  ADragY, AGrabY, AGrabThumbTop: Integer): Integer;
var LThumbH, LMax: Integer;
begin
  LThumbH := ThumbSize(ATrackArea.Height);
  Result := ADragY - (AGrabY - AGrabThumbTop);
  if Result < ATrackArea.Y then Result := ATrackArea.Y;
  LMax := ATrackArea.Y + ATrackArea.Height - LThumbH;
  if Result > LMax then Result := LMax;
end;

function TScrollbar.PageUp: Integer;
begin
  Result := FScrollOffset - FVisibleItems;
  if Result < 0 then Result := 0;
end;

function TScrollbar.PageDown: Integer;
var LMax: Integer;
begin
  LMax := FTotalItems - FVisibleItems;
  if LMax < 0 then LMax := 0;
  Result := FScrollOffset + FVisibleItems;
  if Result > LMax then Result := LMax;
end;

function TScrollbar.Clamped: Integer;
var LMax: Integer;
begin
  LMax := FTotalItems - FVisibleItems;
  if LMax < 0 then LMax := 0;
  Result := FScrollOffset;
  if Result < 0 then Result := 0;
  if Result > LMax then Result := LMax;
end;

procedure TScrollbar.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LY, LTS, LTSz: Integer;
  LC: TCell;
  LP: PCell;
begin
  if AArea.IsEmpty or (AArea.Width < 1) then Exit;
  LTS := ThumbStart(AArea.Height);
  LTSz := ThumbSize(AArea.Height);
  for LY := 0 to AArea.Height - 1 do
  begin
    LC := CELL_EMPTY;
    if (LY >= LTS) and (LY < LTS + LTSz) then
    begin
      { 多字节符号走字节通路(█ 等块字符);>255 属病态入参,
        静默跳过防 Byte 截断回绕;空符号留空格底 }
      if (Length(FThumbChar) > 0) and (Length(FThumbChar) <= 255) then
        CellSetSymbolBytes(LC, PAnsiChar(FThumbChar)^, Length(FThumbChar), 1);
      CellApplyStyle(LC, FThumbStyle);
    end
    else
    begin
      if (Length(FTrackChar) > 0) and (Length(FTrackChar) <= 255) then
        CellSetSymbolBytes(LC, PAnsiChar(FTrackChar)^, Length(FTrackChar), 1);
      CellApplyStyle(LC, FTrackStyle);
    end;
    LP := ABuffer.CellAt(AArea.X, AArea.Y + LY);
    if LP <> nil then LP^ := LC;
  end;
end;

end.
