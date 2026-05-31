unit nextpas.core.tui.widget.modal;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer;

type
  TModalSize = record
    Width: Integer;
    Height: Integer;
    WidthPct: Integer;
    HeightPct: Integer;
    UsePercent: Boolean;
  end;

  TModal = record
    Visible: Boolean;
    Size: TModalSize;
    DimBackground: Boolean;
    Style: TStyle;

    class function Create: TModal; static;
    function WithSize(W, H: Integer): TModal;
    function WithSizePercent(WPct, HPct: Integer): TModal;
    function WithDimBackground(Dim: Boolean): TModal;
    function WithStyle(const S: TStyle): TModal;
    function ContentArea(const Container: TRect): TRect;
    procedure RenderBackground(const Container: TRect; ABuf: TBuffer);
  end;

implementation

class function TModal.Create: TModal;
begin
  Result.Visible := False;
  Result.Size.Width := 40;
  Result.Size.Height := 12;
  Result.Size.WidthPct := 60;
  Result.Size.HeightPct := 60;
  Result.Size.UsePercent := False;
  Result.DimBackground := True;
  Result.Style := TStyle.Default;
end;

function TModal.WithSize(W, H: Integer): TModal;
begin
  Result := Self;
  Result.Size.Width := W;
  Result.Size.Height := H;
  Result.Size.UsePercent := False;
end;

function TModal.WithSizePercent(WPct, HPct: Integer): TModal;
begin
  Result := Self;
  Result.Size.WidthPct := WPct;
  Result.Size.HeightPct := HPct;
  Result.Size.UsePercent := True;
end;

function TModal.WithDimBackground(Dim: Boolean): TModal;
begin
  Result := Self;
  Result.DimBackground := Dim;
end;

function TModal.WithStyle(const S: TStyle): TModal;
begin
  Result := Self;
  Result.Style := S;
end;

function TModal.ContentArea(const Container: TRect): TRect;
var W, H, X, Y: Integer;
begin
  if Size.UsePercent then
  begin
    W := (Container.Width * Size.WidthPct) div 100;
    H := (Container.Height * Size.HeightPct) div 100;
  end
  else
  begin
    W := Size.Width;
    H := Size.Height;
  end;
  if W > Container.Width then W := Container.Width;
  if H > Container.Height then H := Container.Height;
  if W < 1 then W := 1;
  if H < 1 then H := 1;
  X := Container.X + (Container.Width - W) div 2;
  Y := Container.Y + (Container.Height - H) div 2;
  Result := TRect.Make(X, Y, W, H);
end;

procedure TModal.RenderBackground(const Container: TRect; ABuf: TBuffer);
begin
  if not Visible then Exit;
  if DimBackground then
    ABuf.SetStyle(Container, TStyle.Default.WithModifier([mbDim]));
  ABuf.SetStyle(ContentArea(Container), Style);
end;

end.
