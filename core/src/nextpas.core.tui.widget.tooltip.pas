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

  TTooltip = record
    Text: AnsiString;
    Position: TTooltipPosition;
    Style: TStyle;
    BorderStyle: TStyle;
    MaxWidth: Integer;

    class function Create(const AText: AnsiString): TTooltip; static;
    function WithPosition(P: TTooltipPosition): TTooltip;
    function WithStyle(const S: TStyle): TTooltip;
    function WithBorderStyle(const S: TStyle): TTooltip;
    function WithMaxWidth(W: Integer): TTooltip;
    procedure Render(const Anchor: TRect; const Bounds: TRect; ABuf: TBuffer);
  end;

implementation

uses
  SysUtils, nextpas.core.text.width, nextpas.core.text.utf8;

class function TTooltip.Create(const AText: AnsiString): TTooltip;
begin
  Result.Text := AText;
  Result.Position := ttpAbove;
  Result.Style := TStyle.Default;
  Result.BorderStyle := TStyle.Default.WithFg(TUI_WHITE);
  Result.MaxWidth := 40;
end;

function TTooltip.WithPosition(P: TTooltipPosition): TTooltip;
begin Result := Self; Result.Position := P; end;

function TTooltip.WithStyle(const S: TStyle): TTooltip;
begin Result := Self; Result.Style := S; end;

function TTooltip.WithBorderStyle(const S: TStyle): TTooltip;
begin Result := Self; Result.BorderStyle := S; end;

function TTooltip.WithMaxWidth(W: Integer): TTooltip;
begin Result := Self; Result.MaxWidth := W; end;

procedure TTooltip.Render(const Anchor: TRect; const Bounds: TRect; ABuf: TBuffer);
var
  TipW, TipH, TipX, TipY: Integer;
  TipArea: TRect;
begin
  if Length(Text) = 0 then Exit;

  TipW := Integer(StringDisplayWidth(Text)) + 2;
  if TipW > MaxWidth then TipW := MaxWidth;
  TipH := 3; // border + text + border

  // Position relative to anchor
  case Position of
    ttpAbove:
    begin
      TipX := Anchor.X;
      TipY := Anchor.Y - TipH;
    end;
    ttpBelow:
    begin
      TipX := Anchor.X;
      TipY := Anchor.Y + Anchor.Height;
    end;
    ttpLeft:
    begin
      TipX := Anchor.X - TipW;
      TipY := Anchor.Y;
    end;
    ttpRight:
    begin
      TipX := Anchor.X + Anchor.Width;
      TipY := Anchor.Y;
    end;
  end;

  // Clamp to bounds (upper first, then lower wins if too small)
  if TipX + TipW > Bounds.X + Bounds.Width then
    TipX := Bounds.X + Bounds.Width - TipW;
  if TipY + TipH > Bounds.Y + Bounds.Height then
    TipY := Bounds.Y + Bounds.Height - TipH;
  if TipX < Bounds.X then TipX := Bounds.X;
  if TipY < Bounds.Y then TipY := Bounds.Y;

  // Clamp width if tooltip wider than bounds
  if TipW > Bounds.Width then TipW := Bounds.Width;
  if TipH > Bounds.Height then TipH := Bounds.Height;

  TipArea := TRect.Make(TipX, TipY, TipW, TipH);
  if TipArea.IsEmpty then Exit;

  // Render bordered tooltip
  ABuf.SetStyle(TipArea, Style);
  TBlock.New.WithBorders(BORDERS_ALL)
    .WithBorderStyle(BorderStyle)
    .Render(TipArea, ABuf);

  // Text inside
  ABuf.SetStringN(TipX + 1, TipY + 1, Text, TipW - 2, Style);
end;

end.
