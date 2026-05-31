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
  nextpas.core.tui.widget.block;

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

  TVirtualList = class(TInterfacedObject)
    ItemProvider: TItemProviderFunc;
    Style: TStyle;
    SelectedStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;
    ShowIndex: Boolean;

    class function Create(Provider: TItemProviderFunc): TVirtualList; static;
    function WithStyle(const S: TStyle): TVirtualList;
    function WithSelectedStyle(const S: TStyle): TVirtualList;
    function WithBlock(const B: TBlock): TVirtualList;
    function WithShowIndex(V: Boolean): TVirtualList;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TVirtualListState);
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

class function TVirtualList.Create(Provider: TItemProviderFunc): TVirtualList;
begin
  Result.ItemProvider := Provider;
  Result.Style := TStyle.Default;
  Result.SelectedStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.HasBlock := False;
  Result.Block := nil;
  Result.ShowIndex := False;
end;

function TVirtualList.WithStyle(const S: TStyle): TVirtualList;
begin Result := Self; Result.Style := S; end;

function TVirtualList.WithSelectedStyle(const S: TStyle): TVirtualList;
begin Result := Self; Result.SelectedStyle := S; end;

function TVirtualList.WithBlock(const B: TBlock): TVirtualList;
begin Result := Self; Result.HasBlock := True; Result.Block := B; end;

function TVirtualList.WithShowIndex(V: Boolean): TVirtualList;
begin Result := Self; Result.ShowIndex := V; end;

procedure TVirtualList.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TVirtualListState);
var
  Inner: TRect;
  ViewH, I, Row, GutterW, TextX, TextW: Integer;
  ItemText: AnsiString;
  LineSty: TStyle;
  IdxBuf: array[0..11] of Byte;
  IdxLen, J, V, D: Integer;
  IdxStr: AnsiString;
begin
  if Area.IsEmpty then Exit;

  ABuf.SetStyle(Area, Style);

  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;

  ViewH := Inner.Height;

  // Clamp state
  if State.TotalItems <= 0 then Exit;
  if State.Selected >= State.TotalItems then
    State.Selected := State.TotalItems - 1;
  if State.Selected < 0 then State.Selected := 0;

  // Ensure selected is visible
  if State.Selected < State.Offset then
    State.Offset := State.Selected;
  if State.Selected >= State.Offset + ViewH then
    State.Offset := State.Selected - ViewH + 1;
  if State.Offset < 0 then State.Offset := 0;

  // Gutter for index — compute digit count without IntToStr
  GutterW := 0;
  if ShowIndex then
  begin
    V := State.TotalItems;
    GutterW := 1;
    while V >= 10 do begin Inc(GutterW); V := V div 10; end;
    Inc(GutterW); // trailing space
    if GutterW < 4 then GutterW := 4;
  end;

  TextX := Inner.X + GutterW;
  TextW := Inner.Width - GutterW;
  if TextW < 1 then TextW := 1;

  if ShowIndex then
  begin
    SetLength(IdxStr, GutterW);
    for J := 1 to GutterW do IdxStr[J] := ' ';
  end;

  for I := 0 to ViewH - 1 do
  begin
    Row := State.Offset + I;
    if Row >= State.TotalItems then Break;

    if Row = State.Selected then
      LineSty := SelectedStyle
    else
      LineSty := Style;

    // Index gutter — itoa without heap allocation
    if ShowIndex then
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
      ABuf.SetStringN(Inner.X, Inner.Y + I, IdxStr, GutterW, Style);
    end;

    // Item content via provider
    if Assigned(ItemProvider) then
      ItemText := ItemProvider(Row)
    else
      ItemText := '';

    ABuf.SetStringN(TextX, Inner.Y + I, ItemText, TextW, LineSty);
  end;
end;

end.
