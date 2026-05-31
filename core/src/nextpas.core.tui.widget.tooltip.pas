unit nextpas.core.tui.widget.tooltip;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.borders,
  nextpas.core.tui.widget.intf;

type
  TTooltipPosition = (ttpAbove, ttpBelow, ttpLeft, ttpRight);

  ITooltip = interface(IWidget)
    ['{F2A3B4C5-D6E7-8901-FABC-234567890123}']
    function WithPosition(P: TTooltipPosition): ITooltip;
    function WithStyle(const S: TStyle): ITooltip;
    function WithBorderStyle(const S: TStyle): ITooltip;
    function WithMaxWidth(W: Integer): ITooltip;
    procedure RenderAt(const Anchor: TRect; const Bounds: TRect; ABuf: TBuffer);
  end;

  TTooltip = class(TInterfacedObject, IWidget, ITooltip)
  private
    FText: AnsiString;
    FPosition: TTooltipPosition;
    FStyle: TStyle;
    FBorderStyle: TStyle;
    FMaxWidth: Integer;
  public
    class function New(const AText: AnsiString): ITooltip; static;

    function WithPosition(P: TTooltipPosition): ITooltip;
    function WithStyle(const S: TStyle): ITooltip;
    function WithBorderStyle(const S: TStyle): ITooltip;
    function WithMaxWidth(W: Integer): ITooltip;

    { IWidget — renders tooltip at top-left of Area }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    { ITooltip — renders relative to Anchor within Bounds }
    procedure RenderAt(const Anchor: TRect; const Bounds: TRect; ABuf: TBuffer);
  end;

implementation

uses
  SysUtils, nextpas.core.text.width, nextpas.core.text.utf8;

class function TTooltip.New(const AText: AnsiString): ITooltip;
var LSelf: TTooltip;
begin
  LSelf := TTooltip.Create;
  LSelf.FText := AText;
  LSelf.FPosition := ttpAbove;
  LSelf.FStyle := TStyle.Default;
  LSelf.FBorderStyle := TStyle.Default.WithFg(TUI_WHITE);
  LSelf.FMaxWidth := 40;
  Result := LSelf;
end;

function TTooltip.WithPosition(P: TTooltipPosition): ITooltip;
begin FPosition := P; Result := Self; end;

function TTooltip.WithStyle(const S: TStyle): ITooltip;
begin FStyle := S; Result := Self; end;

function TTooltip.WithBorderStyle(const S: TStyle): ITooltip;
begin FBorderStyle := S; Result := Self; end;

function TTooltip.WithMaxWidth(W: Integer): ITooltip;
begin FMaxWidth := W; Result := Self; end;

procedure TTooltip.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  RenderAt(TRect.Make(AArea.X, AArea.Y, 1, 1), AArea, ABuffer);
end;

procedure TTooltip.RenderAt(const Anchor: TRect; const Bounds: TRect; ABuf: TBuffer);
var
  TipW, TipH, TipX, TipY: Integer;
  TipArea: TRect;
begin
  if Length(FText) = 0 then Exit;

  TipW := Integer(StringDisplayWidth(FText)) + 2;
  if TipW > FMaxWidth then TipW := FMaxWidth;
  TipH := 3;

  case FPosition of
    ttpAbove: begin TipX := Anchor.X; TipY := Anchor.Y - TipH; end;
    ttpBelow: begin TipX := Anchor.X; TipY := Anchor.Y + Anchor.Height; end;
    ttpLeft:  begin TipX := Anchor.X - TipW; TipY := Anchor.Y; end;
    ttpRight: begin TipX := Anchor.X + Anchor.Width; TipY := Anchor.Y; end;
  end;

  if TipX + TipW > Bounds.X + Bounds.Width then
    TipX := Bounds.X + Bounds.Width - TipW;
  if TipY + TipH > Bounds.Y + Bounds.Height then
    TipY := Bounds.Y + Bounds.Height - TipH;
  if TipX < Bounds.X then TipX := Bounds.X;
  if TipY < Bounds.Y then TipY := Bounds.Y;
  if TipW > Bounds.Width then TipW := Bounds.Width;
  if TipH > Bounds.Height then TipH := Bounds.Height;

  TipArea := TRect.Make(TipX, TipY, TipW, TipH);
  if TipArea.IsEmpty then Exit;

  ABuf.SetStyle(TipArea, FStyle);
  TBlock.New.WithBorders(BORDERS_ALL)
    .WithBorderStyle(FBorderStyle)
    .Render(TipArea, ABuf);
  ABuf.SetStringN(TipX + 1, TipY + 1, FText, TipW - 2, FStyle);
end;

end.
