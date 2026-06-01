unit nextpas.core.tui.widget.breadcrumb;

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
  nextpas.core.tui.widget.intf;

type
  IBreadcrumb = interface(IWidget)
    ['{D0E1F2A3-B4C5-6789-DEFA-012345678901}']
    function WithSeparator(const S: AnsiString): IBreadcrumb;
    function WithStyle(const S: TStyle): IBreadcrumb;
    function WithActiveStyle(const S: TStyle): IBreadcrumb;
    function WithSepStyle(const S: TStyle): IBreadcrumb;
    function WithActive(I: Integer): IBreadcrumb;
    function TotalWidth: Integer;
  end;

  TBreadcrumb = class(TInterfacedObject, IWidget, IBreadcrumb)
  private
    FItems: array of AnsiString;
    FSeparator: AnsiString;
    FStyle: TStyle;
    FActiveStyle: TStyle;
    FSepStyle: TStyle;
    FActiveIndex: Integer;
  public
    class function New(const AItems: array of AnsiString): IBreadcrumb; static;

    function WithSeparator(const S: AnsiString): IBreadcrumb;
    function WithStyle(const S: TStyle): IBreadcrumb;
    function WithActiveStyle(const S: TStyle): IBreadcrumb;
    function WithSepStyle(const S: TStyle): IBreadcrumb;
    function WithActive(I: Integer): IBreadcrumb;
    function TotalWidth: Integer;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

uses
  SysUtils, nextpas.core.text.width;

class function TBreadcrumb.New(const AItems: array of AnsiString): IBreadcrumb;
var LSelf: TBreadcrumb; I: Integer;
begin
  LSelf := TBreadcrumb.Create;
  SetLength(LSelf.FItems, Length(AItems));
  for I := 0 to High(AItems) do LSelf.FItems[I] := AItems[I];
  LSelf.FSeparator := ' > ';
  LSelf.FStyle := TStyle.Default;
  LSelf.FActiveStyle := TStyle.Default.WithModifier([mbBold]);
  LSelf.FSepStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  LSelf.FActiveIndex := Length(AItems) - 1;
  Result := LSelf;
end;

function TBreadcrumb.WithSeparator(const S: AnsiString): IBreadcrumb;
begin FSeparator := S; Result := Self; end;

function TBreadcrumb.WithStyle(const S: TStyle): IBreadcrumb;
begin FStyle := S; Result := Self; end;

function TBreadcrumb.WithActiveStyle(const S: TStyle): IBreadcrumb;
begin FActiveStyle := S; Result := Self; end;

function TBreadcrumb.WithSepStyle(const S: TStyle): IBreadcrumb;
begin FSepStyle := S; Result := Self; end;

function TBreadcrumb.WithActive(I: Integer): IBreadcrumb;
begin FActiveIndex := I; Result := Self; end;

function TBreadcrumb.TotalWidth: Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to High(FItems) do
  begin
    Inc(Result, Integer(StringDisplayWidth(FItems[I])));
    if I < High(FItems) then
      Inc(Result, Integer(StringDisplayWidth(FSeparator)));
  end;
end;

procedure TBreadcrumb.Render(const AArea: TRect; ABuffer: TBuffer);
var
  I, X: Integer;
  ItemSty: TStyle;
begin
  if AArea.IsEmpty or (Length(FItems) = 0) then Exit;
  X := AArea.X;
  for I := 0 to High(FItems) do
  begin
    if X >= AArea.X + AArea.Width then Break;
    if I = FActiveIndex then ItemSty := FActiveStyle
    else ItemSty := FStyle;
    ABuffer.SetStringN(X, AArea.Y, FItems[I], AArea.X + AArea.Width - X, ItemSty);
    Inc(X, Integer(StringDisplayWidth(FItems[I])));
    if (I < High(FItems)) and (X < AArea.X + AArea.Width) then
    begin
      ABuffer.SetStringN(X, AArea.Y, FSeparator, AArea.X + AArea.Width - X, FSepStyle);
      Inc(X, Integer(StringDisplayWidth(FSeparator)));
    end;
  end;
end;

end.
