unit nextpas.core.tui.widget.virtual_list;

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
  nextpas.core.tui.widget.intf;

type
  TItemProviderFunc = function(Index: Integer): AnsiString;

  TVirtualListState = record
    TotalItems: Integer;
    Offset: Integer;
    Selected: Integer;

    class function Create(ATotal: Integer): TVirtualListState; static;
    procedure SelectNext;
    procedure SelectPrev;
    procedure PageDown(ViewH: Integer);
    procedure PageUp(ViewH: Integer);
    procedure SelectFirst;
    procedure SelectLast;
  end;

  IVirtualList = interface(IWidget)
    ['{C3D4E5F6-A7B8-9012-3456-789ABCDEF012}']
    function WithStyle(const AStyle: TStyle): IVirtualList;
    function WithSelectedStyle(const AStyle: TStyle): IVirtualList;
    function WithBlock(ABlock: IBlock): IVirtualList;
    function WithShowIndex(AValue: Boolean): IVirtualList;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TVirtualListState);
  end;

  TVirtualList = class(TInterfacedObject, IWidget, IVirtualList)
  private
    FItemProvider: TItemProviderFunc;
    FStyle: TStyle;
    FSelectedStyle: TStyle;
    FBlock: IBlock;
    FShowIndex: Boolean;
  public
    class function New(AProvider: TItemProviderFunc): IVirtualList; static;

    { IVirtualList builder }
    function WithStyle(const AStyle: TStyle): IVirtualList;
    function WithSelectedStyle(const AStyle: TStyle): IVirtualList;
    function WithBlock(ABlock: IBlock): IVirtualList;
    function WithShowIndex(AValue: Boolean): IVirtualList;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    { IVirtualList stateful }
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TVirtualListState);
  end;

implementation

{ TVirtualListState }

class function TVirtualListState.Create(ATotal: Integer): TVirtualListState;
begin
  Result.TotalItems := ATotal;
  Result.Offset := 0;
  Result.Selected := 0;
end;

procedure TVirtualListState.SelectNext;
begin
  if Selected < TotalItems - 1 then Inc(Selected);
end;

procedure TVirtualListState.SelectPrev;
begin
  if Selected > 0 then Dec(Selected);
end;

procedure TVirtualListState.PageDown(ViewH: Integer);
begin
  Inc(Selected, ViewH);
  if Selected >= TotalItems then Selected := TotalItems - 1;
  if Selected < 0 then Selected := 0;
end;

procedure TVirtualListState.PageUp(ViewH: Integer);
begin
  Dec(Selected, ViewH);
  if Selected < 0 then Selected := 0;
end;

procedure TVirtualListState.SelectFirst;
begin
  Selected := 0;
end;

procedure TVirtualListState.SelectLast;
begin
  Selected := TotalItems - 1;
  if Selected < 0 then Selected := 0;
end;

{ TVirtualList }

class function TVirtualList.New(AProvider: TItemProviderFunc): IVirtualList;
var
  LObj: TVirtualList;
begin
  LObj := TVirtualList.Create;
  LObj.FItemProvider := AProvider;
  LObj.FStyle := TStyle.Default;
  LObj.FSelectedStyle := TStyle.Default.WithModifier([mbReversed]);
  LObj.FBlock := nil;
  LObj.FShowIndex := False;
  Result := LObj;
end;

function TVirtualList.WithStyle(const AStyle: TStyle): IVirtualList;
begin FStyle := AStyle; Result := Self; end;

function TVirtualList.WithSelectedStyle(const AStyle: TStyle): IVirtualList;
begin FSelectedStyle := AStyle; Result := Self; end;

function TVirtualList.WithBlock(ABlock: IBlock): IVirtualList;
begin FBlock := ABlock; Result := Self; end;

function TVirtualList.WithShowIndex(AValue: Boolean): IVirtualList;
begin FShowIndex := AValue; Result := Self; end;

procedure TVirtualList.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LState: TVirtualListState;
begin
  LState := TVirtualListState.Create(0);
  RenderStateful(AArea, ABuffer, LState);
end;

procedure TVirtualList.RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TVirtualListState);
var
  Inner: TRect;
  ViewH, I, Row, GutterW, TextX, TextW: Integer;
  ItemText: AnsiString;
  LineSty: TStyle;
  IdxBuf: array[0..11] of Byte;
  IdxLen, J, V, D: Integer;
  IdxStr: AnsiString;
begin
  if AArea.IsEmpty then Exit;

  ABuffer.SetStyle(AArea, FStyle);

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;

  ViewH := Inner.Height;

  // Clamp state
  if AState.TotalItems <= 0 then Exit;
  if AState.Selected >= AState.TotalItems then
    AState.Selected := AState.TotalItems - 1;
  if AState.Selected < 0 then AState.Selected := 0;

  // Ensure selected is visible
  if AState.Selected < AState.Offset then
    AState.Offset := AState.Selected;
  if AState.Selected >= AState.Offset + ViewH then
    AState.Offset := AState.Selected - ViewH + 1;
  if AState.Offset < 0 then AState.Offset := 0;

  // Gutter for index — compute digit count without IntToStr
  GutterW := 0;
  if FShowIndex then
  begin
    V := AState.TotalItems;
    GutterW := 1;
    while V >= 10 do begin Inc(GutterW); V := V div 10; end;
    Inc(GutterW); // trailing space
    if GutterW < 4 then GutterW := 4;
  end;

  TextX := Inner.X + GutterW;
  TextW := Inner.Width - GutterW;
  if TextW < 1 then TextW := 1;

  if FShowIndex then
  begin
    SetLength(IdxStr, GutterW);
    for J := 1 to GutterW do IdxStr[J] := ' ';
  end;

  for I := 0 to ViewH - 1 do
  begin
    Row := AState.Offset + I;
    if Row >= AState.TotalItems then Break;

    if Row = AState.Selected then
      LineSty := FSelectedStyle
    else
      LineSty := FStyle;

    // Index gutter — itoa without heap allocation
    if FShowIndex then
    begin
      V := Row + 1;
      IdxLen := 0;
      repeat
        IdxBuf[IdxLen] := Byte(Ord('0') + (V mod 10));
        V := V div 10;
        Inc(IdxLen);
      until V = 0;
      for J := 1 to GutterW do IdxStr[J] := ' ';
      D := GutterW - 1;
      for J := 0 to IdxLen - 1 do
      begin
        IdxStr[D] := Chr(IdxBuf[J]);
        Dec(D);
      end;
      ABuffer.SetStringN(Inner.X, Inner.Y + I, IdxStr, GutterW, FStyle);
    end;

    // Item content via provider
    if Assigned(FItemProvider) then
      ItemText := FItemProvider(Row)
    else
      ItemText := '';

    ABuffer.SetStringN(TextX, Inner.Y + I, ItemText, TextW, LineSty);
  end;
end;

end.
