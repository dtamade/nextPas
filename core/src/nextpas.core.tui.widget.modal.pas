unit nextpas.core.tui.widget.modal;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf;

type
  TModalSize = record
    Width: Integer;
    Height: Integer;
    WidthPct: Integer;
    HeightPct: Integer;
    UsePercent: Boolean;
  end;

  IModal = interface(IWidget)
    ['{E1F2A3B4-C5D6-7890-EFAB-123456789012}']
    function WithSize(W, H: Integer): IModal;
    function WithSizePercent(WPct, HPct: Integer): IModal;
    function WithDimBackground(Dim: Boolean): IModal;
    function WithStyle(const S: TStyle): IModal;
    function WithVisible(V: Boolean): IModal;
    function ContentArea(const AContainer: TRect): TRect;
  end;

  TModal = class(TInterfacedObject, IWidget, IModal)
  private
    FVisible: Boolean;
    FSize: TModalSize;
    FDimBackground: Boolean;
    FStyle: TStyle;
  public
    class function New: IModal; static;

    function WithSize(W, H: Integer): IModal;
    function WithSizePercent(WPct, HPct: Integer): IModal;
    function WithDimBackground(Dim: Boolean): IModal;
    function WithStyle(const S: TStyle): IModal;
    function WithVisible(V: Boolean): IModal;
    function ContentArea(const AContainer: TRect): TRect;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

class function TModal.New: IModal;
var LSelf: TModal;
begin
  LSelf := TModal.Create;
  LSelf.FVisible := False;
  LSelf.FSize.Width := 40;
  LSelf.FSize.Height := 12;
  LSelf.FSize.WidthPct := 60;
  LSelf.FSize.HeightPct := 60;
  LSelf.FSize.UsePercent := False;
  LSelf.FDimBackground := True;
  LSelf.FStyle := TStyle.Default;
  Result := LSelf;
end;

function TModal.WithSize(W, H: Integer): IModal;
begin
  FSize.Width := W; FSize.Height := H;
  FSize.UsePercent := False;
  Result := Self;
end;

function TModal.WithSizePercent(WPct, HPct: Integer): IModal;
begin
  FSize.WidthPct := WPct; FSize.HeightPct := HPct;
  FSize.UsePercent := True;
  Result := Self;
end;

function TModal.WithDimBackground(Dim: Boolean): IModal;
begin FDimBackground := Dim; Result := Self; end;

function TModal.WithStyle(const S: TStyle): IModal;
begin FStyle := S; Result := Self; end;

function TModal.WithVisible(V: Boolean): IModal;
begin FVisible := V; Result := Self; end;

function TModal.ContentArea(const AContainer: TRect): TRect;
var W, H, X, Y: Integer;
begin
  if FSize.UsePercent then
  begin
    W := (AContainer.Width * FSize.WidthPct) div 100;
    H := (AContainer.Height * FSize.HeightPct) div 100;
  end
  else
  begin
    W := FSize.Width;
    H := FSize.Height;
  end;
  if W > AContainer.Width then W := AContainer.Width;
  if H > AContainer.Height then H := AContainer.Height;
  if W < 1 then W := 1;
  if H < 1 then H := 1;
  X := AContainer.X + (AContainer.Width - W) div 2;
  Y := AContainer.Y + (AContainer.Height - H) div 2;
  Result := TRect.Make(X, Y, W, H);
end;

procedure TModal.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  if not FVisible then Exit;
  if AArea.IsEmpty then Exit;
  if FDimBackground then
    ABuffer.SetStyle(AArea, TStyle.Default.WithModifier([mbDim]));
  ABuffer.SetStyle(ContentArea(AArea), FStyle);
end;

end.
