unit nextpas.core.tui.widget.dialog;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.text.width, nextpas.core.text.utf8,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.paragraph,
  nextpas.core.tui.widget.intf;

type
  TDialogButton = record
    Label_: AnsiString;
    Style: TStyle;
  end;

  IDialog = interface(IWidget)
    ['{B8C9D0E1-F2A3-4567-BCDE-F01234567890}']
    function WithButtons(const ALabels: array of AnsiString): IDialog;
    function WithWidth(W: Integer): IDialog;
    function WithHeight(H: Integer): IDialog;
    function WithStyle(const S: TStyle): IDialog;
    function WithBorderStyle(const S: TStyle): IDialog;
    function WithButtonStyle(const S: TStyle): IDialog;
    function WithActiveButtonStyle(const S: TStyle): IDialog;
    function WithDimBackground(Dim: Boolean): IDialog;
    function WithSelected(Idx: Integer): IDialog;
    function CenteredArea(const AContainer: TRect): TRect;
  end;

  TDialog = class(TInterfacedObject, IWidget, IDialog)
  private
    FTitle: AnsiString;
    FBody: AnsiString;
    FButtons: array of TDialogButton;
    FSelectedButton: Integer;
    FWidth: Integer;
    FHeight: Integer;
    FStyle: TStyle;
    FBorderStyle: TStyle;
    FButtonStyle: TStyle;
    FActiveButtonStyle: TStyle;
    FDimBackground: Boolean;
  public
    class function New(const ATitle, ABody: AnsiString): IDialog; static;

    function WithButtons(const ALabels: array of AnsiString): IDialog;
    function WithWidth(W: Integer): IDialog;
    function WithHeight(H: Integer): IDialog;
    function WithStyle(const S: TStyle): IDialog;
    function WithBorderStyle(const S: TStyle): IDialog;
    function WithButtonStyle(const S: TStyle): IDialog;
    function WithActiveButtonStyle(const S: TStyle): IDialog;
    function WithDimBackground(Dim: Boolean): IDialog;
    function WithSelected(Idx: Integer): IDialog;
    function CenteredArea(const AContainer: TRect): TRect;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

{ TDialog }

class function TDialog.New(const ATitle, ABody: AnsiString): IDialog;
var LSelf: TDialog;
begin
  LSelf := TDialog.Create;
  LSelf.FTitle := ATitle;
  LSelf.FBody := ABody;
  LSelf.FButtons := nil;
  LSelf.FSelectedButton := 0;
  LSelf.FWidth := 40;
  LSelf.FHeight := 10;
  LSelf.FStyle := TStyle.Default;
  LSelf.FBorderStyle := TStyle.Default;
  LSelf.FButtonStyle := TStyle.Default;
  LSelf.FActiveButtonStyle := TStyle.Default.WithModifier([mbReversed]);
  LSelf.FDimBackground := True;
  Result := LSelf;
end;

function TDialog.WithButtons(const ALabels: array of AnsiString): IDialog;
var I: Integer;
begin
  SetLength(FButtons, Length(ALabels));
  for I := 0 to High(ALabels) do
  begin
    FButtons[I].Label_ := ALabels[I];
    FButtons[I].Style := TStyle.Default;
  end;
  Result := Self;
end;

function TDialog.WithWidth(W: Integer): IDialog;
begin FWidth := W; Result := Self; end;

function TDialog.WithHeight(H: Integer): IDialog;
begin FHeight := H; Result := Self; end;

function TDialog.WithStyle(const S: TStyle): IDialog;
begin FStyle := S; Result := Self; end;

function TDialog.WithBorderStyle(const S: TStyle): IDialog;
begin FBorderStyle := S; Result := Self; end;

function TDialog.WithButtonStyle(const S: TStyle): IDialog;
begin FButtonStyle := S; Result := Self; end;

function TDialog.WithActiveButtonStyle(const S: TStyle): IDialog;
begin FActiveButtonStyle := S; Result := Self; end;

function TDialog.WithDimBackground(Dim: Boolean): IDialog;
begin FDimBackground := Dim; Result := Self; end;

function TDialog.WithSelected(Idx: Integer): IDialog;
begin FSelectedButton := Idx; Result := Self; end;

function TDialog.CenteredArea(const AContainer: TRect): TRect;
var W, H, X, Y: Integer;
begin
  W := FWidth; H := FHeight;
  if W > AContainer.Width then W := AContainer.Width;
  if H > AContainer.Height then H := AContainer.Height;
  X := AContainer.X + (AContainer.Width - W) div 2;
  Y := AContainer.Y + (AContainer.Height - H) div 2;
  Result := TRect.Make(X, Y, W, H);
end;

procedure TDialog.Render(const AArea: TRect; ABuffer: TBuffer);
var
  DialogArea, Inner, BodyArea, ButtonArea: TRect;
  Blk: IBlock;
  BodyPara: IParagraph;
  I, BtnX, BtnW, TotalBtnW, Spacing: Integer;
  BtnText: AnsiString;
  Sty: TStyle;
begin
  if AArea.IsEmpty then Exit;

  if FDimBackground then
    ABuffer.SetStyle(AArea, TStyle.Default.WithModifier([mbDim]));

  DialogArea := CenteredArea(AArea);
  if DialogArea.IsEmpty then Exit;

  ABuffer.SetStyle(DialogArea, FStyle);

  Blk := TBlock.New
    .WithBorders(BORDERS_ALL)
    .WithTitle(FTitle)
    .WithBorderStyle(FBorderStyle);
  Blk.Render(DialogArea, ABuffer);
  Inner := Blk.Inner(DialogArea);
  if Inner.IsEmpty then Exit;

  if Length(FButtons) > 0 then
  begin
    BodyArea := TRect.Make(Inner.X, Inner.Y, Inner.Width, Inner.Height - 2);
    ButtonArea := TRect.Make(Inner.X, Inner.Y + Inner.Height - 1, Inner.Width, 1);
  end
  else
  begin
    BodyArea := Inner;
    ButtonArea := TRect.Make(0, 0, 0, 0);
  end;

  if not BodyArea.IsEmpty then
  begin
    BodyPara := TParagraph.FromString(FBody).WithStyle(FStyle);
    BodyPara.Render(BodyArea, ABuffer);
  end;

  if (Length(FButtons) > 0) and (not ButtonArea.IsEmpty) then
  begin
    TotalBtnW := 0;
    for I := 0 to High(FButtons) do
      Inc(TotalBtnW, Integer(StringDisplayWidth(FButtons[I].Label_) + 4));
    Spacing := 2;
    Inc(TotalBtnW, (Length(FButtons) - 1) * Spacing);

    BtnX := ButtonArea.X + (ButtonArea.Width - TotalBtnW) div 2;
    if BtnX < ButtonArea.X then BtnX := ButtonArea.X;

    for I := 0 to High(FButtons) do
    begin
      if I = FSelectedButton then
        Sty := FButtonStyle.Patch(FActiveButtonStyle)
      else
        Sty := FButtonStyle;

      BtnText := '[ ' + FButtons[I].Label_ + ' ]';
      BtnW := Integer(StringDisplayWidth(BtnText));
      ABuffer.SetStringN(BtnX, ButtonArea.Y, BtnText, BtnW, Sty);
      Inc(BtnX, BtnW + Spacing);
    end;
  end;
end;

end.
