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
  nextpas.core.tui.widget.intf,
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

  IPopover = interface(IWidget)
    ['{A1B2C3D4-5E6F-7A8B-9C0D-E1F2A3B4C5D6}']
    function WithWidth(W: Integer): IPopover;
    function WithMaxHeight(H: Integer): IPopover;
    function WithAnchor(A: TPopoverAnchor): IPopover;
    function WithStyle(const S: TStyle): IPopover;
    function WithHighlightStyle(const S: TStyle): IPopover;
    function WithBorder(B: Boolean): IPopover;
    procedure RenderStateful(const AnchorPos: TRect; const Bounds: TRect;
      ABuffer: TBuffer; var AState: TPopoverState);
  end;

  TPopover = class(TInterfacedObject, IWidget, IPopover)
  private
    FItems: array of AnsiString;
    FWidth: Integer;
    FMaxHeight: Integer;
    FAnchor: TPopoverAnchor;
    FStyle: TStyle;
    FHighlightStyle: TStyle;
    FHasBorder: Boolean;
  public
    class function New(const AItems: array of AnsiString): IPopover; static;

    { IPopover builder }
    function WithWidth(W: Integer): IPopover;
    function WithMaxHeight(H: Integer): IPopover;
    function WithAnchor(A: TPopoverAnchor): IPopover;
    function WithStyle(const S: TStyle): IPopover;
    function WithHighlightStyle(const S: TStyle): IPopover;
    function WithBorder(B: Boolean): IPopover;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);

    { IPopover }
    procedure RenderStateful(const AnchorPos: TRect; const Bounds: TRect;
      ABuffer: TBuffer; var AState: TPopoverState);
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

class function TPopover.New(const AItems: array of AnsiString): IPopover;
var
  LObj: TPopover;
  I: Integer;
begin
  LObj := TPopover.Create;
  SetLength(LObj.FItems, Length(AItems));
  for I := 0 to High(AItems) do
    LObj.FItems[I] := AItems[I];
  LObj.FWidth := 20;
  LObj.FMaxHeight := 10;
  LObj.FAnchor := paBelow;
  LObj.FStyle := TStyle.Default;
  LObj.FHighlightStyle := TStyle.Default.WithModifier([mbReversed]);
  LObj.FHasBorder := True;
  Result := LObj;
end;

function TPopover.WithWidth(W: Integer): IPopover;
begin
  FWidth := W;
  Result := Self;
end;

function TPopover.WithMaxHeight(H: Integer): IPopover;
begin
  FMaxHeight := H;
  Result := Self;
end;

function TPopover.WithAnchor(A: TPopoverAnchor): IPopover;
begin
  FAnchor := A;
  Result := Self;
end;

function TPopover.WithStyle(const S: TStyle): IPopover;
begin
  FStyle := S;
  Result := Self;
end;

function TPopover.WithHighlightStyle(const S: TStyle): IPopover;
begin
  FHighlightStyle := S;
  Result := Self;
end;

function TPopover.WithBorder(B: Boolean): IPopover;
begin
  FHasBorder := B;
  Result := Self;
end;

procedure TPopover.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  { Popover is stateful-only; Render without state is a no-op. }
end;

procedure TPopover.RenderStateful(const AnchorPos: TRect; const Bounds: TRect;
  ABuffer: TBuffer; var AState: TPopoverState);
var
  PopX, PopY, PopW, PopH: Integer;
  Inner: TRect;
  I, Y, VisH: Integer;
  Sty: TStyle;
begin
  if not AState.Visible then Exit;
  if Length(FItems) = 0 then Exit;

  PopW := FWidth;
  PopH := Length(FItems);
  if PopH > FMaxHeight then PopH := FMaxHeight;
  if FHasBorder then Inc(PopH, 2);

  case FAnchor of
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

  ABuffer.SetStyle(TRect.Make(PopX, PopY, PopW, PopH), FStyle);

  if FHasBorder then
  begin
    TBlock.New.WithBorders(BORDERS_ALL).WithBorderStyle(FStyle)
      .Render(TRect.Make(PopX, PopY, PopW, PopH), ABuffer);
    Inner := TRect.Make(PopX + 1, PopY + 1, PopW - 2, PopH - 2);
  end
  else
    Inner := TRect.Make(PopX, PopY, PopW, PopH);

  if Inner.IsEmpty then Exit;

  if AState.Selected < 0 then AState.Selected := 0;
  if AState.Selected >= Length(FItems) then AState.Selected := Length(FItems) - 1;

  VisH := Inner.Height;
  Y := Inner.Y;
  for I := 0 to Length(FItems) - 1 do
  begin
    if I >= VisH then Break;
    if I = AState.Selected then
      Sty := FHighlightStyle
    else
      Sty := FStyle;
    ABuffer.SetStringN(Inner.X, Y, FItems[I], Inner.Width, Sty);
    Inc(Y);
  end;
end;

end.
