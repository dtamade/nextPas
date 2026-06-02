unit nextpas.core.tui.widget.tabs;

{**
 * @desc TTabsWidget — 水平 tab 栏（stateful）。
 *
 * 渲染 tab 标题，用可配置分隔符分隔。选中 tab 用 ActiveStyle，
 * 其余用 InactiveStyle。超出 Area.Width 时截断。
 *}

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
  TTabsState = record
    Selected: Integer;
  end;

  ITabsWidget = interface(IWidget)
    ['{F3A4B5C6-D7E8-9F0A-1B2C-3D4E5F6A7B8C}']
    function WithActiveStyle(const AStyle: TStyle): ITabsWidget;
    function WithInactiveStyle(const AStyle: TStyle): ITabsWidget;
    function WithSeparator(const ASep: AnsiString): ITabsWidget;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TTabsState);
  end;

  TTabsWidget = class(TInterfacedObject, IWidget, ITabsWidget)
  private
    FTitles: array of AnsiString;
    FActiveStyle: TStyle;
    FInactiveStyle: TStyle;
    FSeparator: AnsiString;
  public
    class function New(const ATitles: array of AnsiString): ITabsWidget; static;

    function WithActiveStyle(const AStyle: TStyle): ITabsWidget;
    function WithInactiveStyle(const AStyle: TStyle): ITabsWidget;
    function WithSeparator(const ASep: AnsiString): ITabsWidget;

    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TTabsState);
  end;

implementation

uses
  nextpas.core.text.width;

{ TTabsWidget }

class function TTabsWidget.New(const ATitles: array of AnsiString): ITabsWidget;
var
  LT: TTabsWidget;
  LI: Integer;
begin
  LT := TTabsWidget.Create;
  SetLength(LT.FTitles, System.Length(ATitles));
  for LI := 0 to System.High(ATitles) do
    LT.FTitles[LI] := ATitles[LI];
  LT.FActiveStyle := TStyle.Default;
  LT.FInactiveStyle := TStyle.Default;
  LT.FSeparator := ' | ';
  Result := LT;
end;

function TTabsWidget.WithActiveStyle(const AStyle: TStyle): ITabsWidget;
begin FActiveStyle := AStyle; Result := Self; end;

function TTabsWidget.WithInactiveStyle(const AStyle: TStyle): ITabsWidget;
begin FInactiveStyle := AStyle; Result := Self; end;

function TTabsWidget.WithSeparator(const ASep: AnsiString): ITabsWidget;
begin FSeparator := ASep; Result := Self; end;

procedure TTabsWidget.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LState: TTabsState;
begin
  LState.Selected := 0;
  RenderStateful(AArea, ABuffer, LState);
end;

procedure TTabsWidget.RenderStateful(const AArea: TRect; ABuffer: TBuffer;
  var AState: TTabsState);
var
  LN, LI, LCursor, LMaxX, LTitleW, LSepW, LWritten: Integer;
  LY: Integer;
  LSty: TStyle;
begin
  if AArea.IsEmpty then Exit;
  LN := System.Length(FTitles);
  if LN = 0 then Exit;

  LY := AArea.Y;
  LMaxX := AArea.X + AArea.Width;
  LCursor := AArea.X;
  LSepW := Integer(StringDisplayWidth(FSeparator));

  for LI := 0 to LN - 1 do
  begin
    if LCursor >= LMaxX then Break;

    if LI > 0 then
    begin
      if LCursor + LSepW > LMaxX then
      begin
        LWritten := ABuffer.SetStringN(LCursor, LY, FSeparator, LMaxX - LCursor, FInactiveStyle);
        Inc(LCursor, LWritten);
        Break;
      end;
      LWritten := ABuffer.SetStringN(LCursor, LY, FSeparator, LSepW, FInactiveStyle);
      Inc(LCursor, LWritten);
      if LCursor >= LMaxX then Break;
    end;

    if LI = AState.Selected then
      LSty := FActiveStyle
    else
      LSty := FInactiveStyle;

    LTitleW := LMaxX - LCursor;
    LWritten := ABuffer.SetStringN(LCursor, LY, FTitles[LI], LTitleW, LSty);
    Inc(LCursor, LWritten);
  end;
end;

end.
