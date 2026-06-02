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
    function WithTrackChar(C: AnsiChar): IScrollbar;
    function WithThumbChar(C: AnsiChar): IScrollbar;
    function WithTrackStyle(const S: TStyle): IScrollbar;
    function WithThumbStyle(const S: TStyle): IScrollbar;
    function ThumbStart(ATrackHeight: Integer): Integer;
    function ThumbSize(ATrackHeight: Integer): Integer;
    function HitAt(const ATrackArea: TRect; AY: Integer): TScrollbarHit;
    function OffsetFromDragY(const ATrackArea: TRect; ADragY: Integer): Integer;
    function PageUp: Integer;
    function PageDown: Integer;
    function Clamped: Integer;
  end;

  TScrollbar = class(TInterfacedObject, IWidget, IScrollbar)
  private
    FTotalItems: Integer;
    FVisibleItems: Integer;
    FScrollOffset: Integer;
    FTrackChar: AnsiChar;
    FThumbChar: AnsiChar;
    FTrackStyle: TStyle;
    FThumbStyle: TStyle;
  public
    class function New: IScrollbar; static;

    function WithTotal(N: Integer): IScrollbar;
    function WithVisible(N: Integer): IScrollbar;
    function WithOffset(N: Integer): IScrollbar;
    function WithTrackChar(C: AnsiChar): IScrollbar;
    function WithThumbChar(C: AnsiChar): IScrollbar;
    function WithTrackStyle(const S: TStyle): IScrollbar;
    function WithThumbStyle(const S: TStyle): IScrollbar;
    function ThumbStart(ATrackHeight: Integer): Integer;
    function ThumbSize(ATrackHeight: Integer): Integer;
    function HitAt(const ATrackArea: TRect; AY: Integer): TScrollbarHit;
    function OffsetFromDragY(const ATrackArea: TRect; ADragY: Integer): Integer;
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

function TScrollbar.WithTrackChar(C: AnsiChar): IScrollbar;
begin FTrackChar := C; Result := Self; end;

function TScrollbar.WithThumbChar(C: AnsiChar): IScrollbar;
begin FThumbChar := C; Result := Self; end;

function TScrollbar.WithTrackStyle(const S: TStyle): IScrollbar;
begin FTrackStyle := S; Result := Self; end;

function TScrollbar.WithThumbStyle(const S: TStyle): IScrollbar;
begin FThumbStyle := S; Result := Self; end;

function TScrollbar.ThumbStart(ATrackHeight: Integer): Integer;
begin
  if FTotalItems <= FVisibleItems then Exit(0);
  Result := (FScrollOffset * (ATrackHeight - ThumbSize(ATrackHeight)))
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
      CellSetSymbolAscii(LC, FThumbChar);
      CellApplyStyle(LC, FThumbStyle);
    end
    else
    begin
      CellSetSymbolAscii(LC, FTrackChar);
      CellApplyStyle(LC, FTrackStyle);
    end;
    LP := ABuffer.CellAt(AArea.X, AArea.Y + LY);
    if LP <> nil then LP^ := LC;
  end;
end;

end.
