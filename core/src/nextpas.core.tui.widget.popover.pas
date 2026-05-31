unit nextpas.core.tui.widget.popover;

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
  nextpas.core.tui.borders;

type
  TPopoverAnchor = (paAbove, paBelow, paLeft, paRight);

  TPopoverState = record
    Visible: Boolean;
    Selected: Integer;
    class function Hidden: TPopoverState; static;
    procedure Show;
    procedure Hide;
  end;

  TPopover = record
    Items: array of AnsiString;
    Width: Integer;
    MaxHeight: Integer;
    Anchor: TPopoverAnchor;
    Style: TStyle;
    HighlightStyle: TStyle;
    HasBorder: Boolean;

    class function Create(const AItems: array of AnsiString): TPopover; static;
    function WithWidth(W: Integer): TPopover;
    function WithMaxHeight(H: Integer): TPopover;
    function WithAnchor(A: TPopoverAnchor): TPopover;
    function WithStyle(const S: TStyle): TPopover;
    function WithHighlightStyle(const S: TStyle): TPopover;
    function WithBorder(B: Boolean): TPopover;
    procedure RenderStateful(const AnchorPos: TRect; const Bounds: TRect;
      ABuf: TBuffer; var State: TPopoverState);
  end;

implementation

{ TPopoverState }

class function TPopoverState.Hidden: TPopoverState;
begin
  Result.Visible := False;
  Result.Selected := 0;
end;

procedure TPopoverState.Show;
begin
  Visible := True;
end;

procedure TPopoverState.Hide;
begin
  Visible := False;
end;

{ TPopover }

class function TPopover.Create(const AItems: array of AnsiString): TPopover;
var I: Integer;
begin
  SetLength(Result.Items, Length(AItems));
  for I := 0 to High(AItems) do
    Result.Items[I] := AItems[I];
  Result.Width := 20;
  Result.MaxHeight := 10;
  Result.Anchor := paBelow;
  Result.Style := TStyle.Default;
  Result.HighlightStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.HasBorder := True;
end;

function TPopover.WithWidth(W: Integer): TPopover;
begin Result := Self; Result.Width := W; end;

function TPopover.WithMaxHeight(H: Integer): TPopover;
begin Result := Self; Result.MaxHeight := H; end;

function TPopover.WithAnchor(A: TPopoverAnchor): TPopover;
begin Result := Self; Result.Anchor := A; end;

function TPopover.WithStyle(const S: TStyle): TPopover;
begin Result := Self; Result.Style := S; end;

function TPopover.WithHighlightStyle(const S: TStyle): TPopover;
begin Result := Self; Result.HighlightStyle := S; end;

function TPopover.WithBorder(B: Boolean): TPopover;
begin Result := Self; Result.HasBorder := B; end;

procedure TPopover.RenderStateful(const AnchorPos: TRect; const Bounds: TRect;
  ABuf: TBuffer; var State: TPopoverState);
var
  PopX, PopY, PopW, PopH: Integer;
  Inner: TRect;
  I, Y, VisH: Integer;
  Sty: TStyle;
begin
  if not State.Visible then Exit;
  if Length(Items) = 0 then Exit;

  PopW := Width;
  PopH := Length(Items);
  if PopH > MaxHeight then PopH := MaxHeight;
  if HasBorder then Inc(PopH, 2);

  case Anchor of
    paBelow:
    begin
      PopX := AnchorPos.X;
      PopY := AnchorPos.Y + AnchorPos.Height;
    end;
    paAbove:
    begin
      PopX := AnchorPos.X;
      PopY := AnchorPos.Y - PopH;
    end;
    paRight:
    begin
      PopX := AnchorPos.X + AnchorPos.Width;
      PopY := AnchorPos.Y;
    end;
    paLeft:
    begin
      PopX := AnchorPos.X - PopW;
      PopY := AnchorPos.Y;
    end;
  end;

  if PopX + PopW > Bounds.X + Bounds.Width then
    PopX := Bounds.X + Bounds.Width - PopW;
  if PopY + PopH > Bounds.Y + Bounds.Height then
    PopY := Bounds.Y + Bounds.Height - PopH;
  if PopX < Bounds.X then PopX := Bounds.X;
  if PopY < Bounds.Y then PopY := Bounds.Y;

  ABuf.SetStyle(TRect.Make(PopX, PopY, PopW, PopH), Style);

  if HasBorder then
  begin
    TBlock.New.WithBorders(BORDERS_ALL).WithBorderStyle(Style)
      .Render(TRect.Make(PopX, PopY, PopW, PopH), ABuf);
    Inner := TRect.Make(PopX + 1, PopY + 1, PopW - 2, PopH - 2);
  end
  else
    Inner := TRect.Make(PopX, PopY, PopW, PopH);

  if Inner.IsEmpty then Exit;

  if State.Selected < 0 then State.Selected := 0;
  if State.Selected >= Length(Items) then State.Selected := Length(Items) - 1;

  VisH := Inner.Height;
  Y := Inner.Y;
  for I := 0 to Length(Items) - 1 do
  begin
    if I >= VisH then Break;
    if I = State.Selected then
      Sty := HighlightStyle
    else
      Sty := Style;
    ABuf.SetStringN(Inner.X, Y, Items[I], Inner.Width, Sty);
    Inc(Y);
  end;
end;

end.
