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
  nextpas.core.tui.buffer;

type
  TBreadcrumb = record
    Items: array of AnsiString;
    Separator: AnsiString;
    Style: TStyle;
    ActiveStyle: TStyle;
    SepStyle: TStyle;
    ActiveIndex: Integer;

    class function Create(const AItems: array of AnsiString): TBreadcrumb; static;
    function WithSeparator(const S: AnsiString): TBreadcrumb;
    function WithStyle(const S: TStyle): TBreadcrumb;
    function WithActiveStyle(const S: TStyle): TBreadcrumb;
    function WithSepStyle(const S: TStyle): TBreadcrumb;
    function WithActive(I: Integer): TBreadcrumb;
    procedure Render(const Area: TRect; ABuf: TBuffer);
    function TotalWidth: Integer;
  end;

implementation

uses
  SysUtils, nextpas.core.text.width, nextpas.core.text.utf8;

class function TBreadcrumb.Create(const AItems: array of AnsiString): TBreadcrumb;
var I: Integer;
begin
  SetLength(Result.Items, Length(AItems));
  for I := 0 to High(AItems) do
    Result.Items[I] := AItems[I];
  Result.Separator := ' > ';
  Result.Style := TStyle.Default;
  Result.ActiveStyle := TStyle.Default.WithModifier([mbBold]);
  Result.SepStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  Result.ActiveIndex := Length(AItems) - 1;
end;

function TBreadcrumb.WithSeparator(const S: AnsiString): TBreadcrumb;
begin Result := Self; Result.Separator := S; end;

function TBreadcrumb.WithStyle(const S: TStyle): TBreadcrumb;
begin Result := Self; Result.Style := S; end;

function TBreadcrumb.WithActiveStyle(const S: TStyle): TBreadcrumb;
begin Result := Self; Result.ActiveStyle := S; end;

function TBreadcrumb.WithSepStyle(const S: TStyle): TBreadcrumb;
begin Result := Self; Result.SepStyle := S; end;

function TBreadcrumb.WithActive(I: Integer): TBreadcrumb;
begin Result := Self; Result.ActiveIndex := I; end;

function TBreadcrumb.TotalWidth: Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to High(Items) do
  begin
    Inc(Result, Integer(StringDisplayWidth(Items[I])));
    if I < High(Items) then
      Inc(Result, Integer(StringDisplayWidth(Separator)));
  end;
end;

procedure TBreadcrumb.Render(const Area: TRect; ABuf: TBuffer);
var
  I, X: Integer;
  ItemSty: TStyle;
begin
  if Area.IsEmpty or (Length(Items) = 0) then Exit;

  X := Area.X;
  for I := 0 to High(Items) do
  begin
    if X >= Area.X + Area.Width then Break;

    if I = ActiveIndex then
      ItemSty := ActiveStyle
    else
      ItemSty := Style;

    ABuf.SetStringN(X, Area.Y, Items[I], Area.X + Area.Width - X, ItemSty);
    Inc(X, Integer(StringDisplayWidth(Items[I])));

    if (I < High(Items)) and (X < Area.X + Area.Width) then
    begin
      ABuf.SetStringN(X, Area.Y, Separator, Area.X + Area.Width - X, SepStyle);
      Inc(X, Integer(StringDisplayWidth(Separator)));
    end;
  end;
end;

end.
