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

  TDialog = class(TInterfacedObject, IWidget)
    Title: AnsiString;
    Body: AnsiString;
    Buttons: array of TDialogButton;
    SelectedButton: Integer;
    Width: Integer;
    Height: Integer;
    Style: TStyle;
    BorderStyle: TStyle;
    ButtonStyle: TStyle;
    ActiveButtonStyle: TStyle;
    DimBackground: Boolean;

    class function Create(const ATitle, ABody: AnsiString): TDialog; static;
    function WithButtons(const ALabels: array of AnsiString): TDialog;
    function WithWidth(W: Integer): TDialog;
    function WithHeight(H: Integer): TDialog;
    function WithStyle(const S: TStyle): TDialog;
    function WithBorderStyle(const S: TStyle): TDialog;
    function WithButtonStyle(const S: TStyle): TDialog;
    function WithActiveButtonStyle(const S: TStyle): TDialog;
    function WithDimBackground(Dim: Boolean): TDialog;
    function CenteredArea(const Container: TRect): TRect;
    procedure Render(const Container: TRect; ABuf: TBuffer);
  end;

implementation

{ TDialog }

class function TDialog.Create(const ATitle, ABody: AnsiString): TDialog;
begin
  Result.Title := ATitle;
  Result.Body := ABody;
  Result.Buttons := nil;
  Result.SelectedButton := 0;
  Result.Width := 40;
  Result.Height := 10;
  Result.Style := TStyle.Default;
  Result.BorderStyle := TStyle.Default;
  Result.ButtonStyle := TStyle.Default;
  Result.ActiveButtonStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.DimBackground := True;
end;

function TDialog.WithButtons(const ALabels: array of AnsiString): TDialog;
var I: Integer;
begin
  Result := Self;
  SetLength(Result.Buttons, Length(ALabels));
  for I := 0 to High(ALabels) do
  begin
    Result.Buttons[I].Label_ := ALabels[I];
    Result.Buttons[I].Style := TStyle.Default;
  end;
end;

function TDialog.WithWidth(W: Integer): TDialog;
begin
  Result := Self;
  Result.Width := W;
end;

function TDialog.WithHeight(H: Integer): TDialog;
begin
  Result := Self;
  Result.Height := H;
end;

function TDialog.WithStyle(const S: TStyle): TDialog;
begin
  Result := Self;
  Result.Style := S;
end;

function TDialog.WithBorderStyle(const S: TStyle): TDialog;
begin
  Result := Self;
  Result.BorderStyle := S;
end;

function TDialog.WithButtonStyle(const S: TStyle): TDialog;
begin
  Result := Self;
  Result.ButtonStyle := S;
end;

function TDialog.WithActiveButtonStyle(const S: TStyle): TDialog;
begin
  Result := Self;
  Result.ActiveButtonStyle := S;
end;

function TDialog.WithDimBackground(Dim: Boolean): TDialog;
begin
  Result := Self;
  Result.DimBackground := Dim;
end;

function TDialog.CenteredArea(const Container: TRect): TRect;
var W, H, X, Y: Integer;
begin
  W := Width;
  H := Height;
  if W > Container.Width then W := Container.Width;
  if H > Container.Height then H := Container.Height;
  X := Container.X + (Container.Width - W) div 2;
  Y := Container.Y + (Container.Height - H) div 2;
  Result := TRect.Make(X, Y, W, H);
end;

procedure TDialog.Render(const Container: TRect; ABuf: TBuffer);
var
  DialogArea, Inner, BodyArea, ButtonArea: TRect;
  Blk: IBlock;
  BodyPara: IParagraph;
  I, BtnX, BtnW, TotalBtnW, Spacing: Integer;
  BtnText: AnsiString;
  Sty: TStyle;
begin
  if Container.IsEmpty then Exit;

  // Dim background
  if DimBackground then
    ABuf.SetStyle(Container, TStyle.Default.WithModifier([mbDim]));

  DialogArea := CenteredArea(Container);
  if DialogArea.IsEmpty then Exit;

  // Clear dialog area with base style
  ABuf.SetStyle(DialogArea, Style);

  // Render bordered block
  Blk := TBlock.New
    .WithBorders(BORDERS_ALL)
    .WithTitle(Title)
    .WithBorderStyle(BorderStyle);
  Blk.Render(DialogArea, ABuf);
  Inner := Blk.Inner(DialogArea);
  if Inner.IsEmpty then Exit;

  // Body text area (leave 1 row at bottom for buttons)
  if Length(Buttons) > 0 then
  begin
    BodyArea := TRect.Make(Inner.X, Inner.Y, Inner.Width, Inner.Height - 2);
    ButtonArea := TRect.Make(Inner.X, Inner.Y + Inner.Height - 1, Inner.Width, 1);
  end
  else
  begin
    BodyArea := Inner;
    ButtonArea := TRect.Make(0, 0, 0, 0);
  end;

  // Render body
  if not BodyArea.IsEmpty then
  begin
    BodyPara := TParagraph.FromString(Body).WithStyle(Style);
    BodyPara.Render(BodyArea, ABuf);
  end;

  // Render buttons centered on button row
  if (Length(Buttons) > 0) and (not ButtonArea.IsEmpty) then
  begin
    TotalBtnW := 0;
    for I := 0 to High(Buttons) do
      Inc(TotalBtnW, Integer(StringDisplayWidth(Buttons[I].Label_) + 4));
    Spacing := 2;
    Inc(TotalBtnW, (Length(Buttons) - 1) * Spacing);

    BtnX := ButtonArea.X + (ButtonArea.Width - TotalBtnW) div 2;
    if BtnX < ButtonArea.X then BtnX := ButtonArea.X;

    for I := 0 to High(Buttons) do
    begin
      if I = SelectedButton then
        Sty := ButtonStyle.Patch(ActiveButtonStyle)
      else
        Sty := ButtonStyle;

      BtnText := '[ ' + Buttons[I].Label_ + ' ]';
      BtnW := Integer(StringDisplayWidth(BtnText));
      ABuf.SetStringN(BtnX, ButtonArea.Y, BtnText, BtnW, Sty);
      Inc(BtnX, BtnW + Spacing);
    end;
  end;
end;

end.
