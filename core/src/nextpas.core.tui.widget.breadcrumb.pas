unit nextpas.core.tui.widget.breadcrumb;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.modifier, nextpas.core.tui.style, nextpas.core.tui.cell, nextpas.core.tui.buffer, nextpas.core.tui.widget.block, nextpas.core.tui.widget.intf;

type
  IBreadcrumb = interface(IWidget)
    ['{D0E1F2A3-B4C5-6789-DEFA-012345678901}']
    function WithSeparator(const S: AnsiString): IBreadcrumb;
    function WithStyle(const S: TStyle): IBreadcrumb;
    function WithActiveStyle(const S: TStyle): IBreadcrumb;
    function WithSepStyle(const S: TStyle): IBreadcrumb;
    function WithActive(I: Integer): IBreadcrumb;
    function TotalWidth: Integer;
    { 布局配置面（PH33 P2b，additive）：块包装 }
    function WithBlock(ABlock: IBlock): IBreadcrumb;
  end;

  TBreadcrumb = class(TInterfacedObject, IWidget, IBreadcrumb)
  private
    FItems: array of AnsiString;
    FSeparator: AnsiString;
    FStyle: TStyle;
    FActiveStyle: TStyle;
    FSepStyle: TStyle;
    FActiveIndex: Integer;
    FBlock: IBlock;
  public
    class function New(const AItems: array of AnsiString): IBreadcrumb; static;

    function WithSeparator(const S: AnsiString): IBreadcrumb;
    function WithStyle(const S: TStyle): IBreadcrumb;
    function WithActiveStyle(const S: TStyle): IBreadcrumb;
    function WithSepStyle(const S: TStyle): IBreadcrumb;
    function WithActive(I: Integer): IBreadcrumb;
    function TotalWidth: Integer;
    function WithBlock(ABlock: IBlock): IBreadcrumb;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

uses nextpas.core.text.width;

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

{ PH33 P2b：布局配置面——块包装（additive，nil 时行为不变） }
function TBreadcrumb.WithBlock(ABlock: IBlock): IBreadcrumb;
begin FBlock := ABlock; Result := Self; end;

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
  LArea: TRect;
begin
  if AArea.IsEmpty or (Length(FItems) = 0) then Exit;

  { PH33 P2b：块包装——先画块，再以块内容区为渲染区 }
  LArea := AArea;
  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    LArea := FBlock.Inner(AArea);
    if LArea.IsEmpty then Exit;
  end;

  X := LArea.X;
  for I := 0 to High(FItems) do
  begin
    if X >= LArea.X + LArea.Width then Break;
    if I = FActiveIndex then ItemSty := FActiveStyle
    else ItemSty := FStyle;
    ABuffer.SetStringN(X, LArea.Y, FItems[I], LArea.X + LArea.Width - X, ItemSty);
    Inc(X, Integer(StringDisplayWidth(FItems[I])));
    if (I < High(FItems)) and (X < LArea.X + LArea.Width) then
    begin
      ABuffer.SetStringN(X, LArea.Y, FSeparator, LArea.X + LArea.Width - X, FSepStyle);
      Inc(X, Integer(StringDisplayWidth(FSeparator)));
    end;
  end;
end;

end.
