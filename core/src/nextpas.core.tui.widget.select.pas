unit nextpas.core.tui.widget.select;

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
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.borders;

type
  TSelectState = record
    Selected: Integer;
    Open: Boolean;
    HighlightIdx: Integer;

    class function Empty: TSelectState; static;
    procedure Toggle;
    procedure MoveUp;
    procedure MoveDown(ItemCount: Integer);
    procedure Confirm;
  end;

  ISelect = interface(IWidget)
    ['{D2E3F4A5-6B7C-8D9E-0F1A-2B3C4D5E6F7A}']
    function WithPlaceholder(const P: AnsiString): ISelect;
    function WithWidth(W: Integer): ISelect;
    function WithMaxDropHeight(H: Integer): ISelect;
    function WithStyle(const S: TStyle): ISelect;
    function WithHighlightStyle(const S: TStyle): ISelect;
    function WithBlock(ABlock: IBlock): ISelect;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TSelectState);
  end;

  TSelect = class(TInterfacedObject, IWidget, ISelect)
  private
    FItems: array of AnsiString;
    FPlaceholder: AnsiString;
    FWidth: Integer;
    FMaxDropHeight: Integer;
    FStyle: TStyle;
    FHighlightStyle: TStyle;
    FBlock: IBlock;
  public
    class function New(const AItems: array of AnsiString): ISelect; static;

    { ISelect builder }
    function WithPlaceholder(const P: AnsiString): ISelect;
    function WithWidth(W: Integer): ISelect;
    function WithMaxDropHeight(H: Integer): ISelect;
    function WithStyle(const S: TStyle): ISelect;
    function WithHighlightStyle(const S: TStyle): ISelect;
    function WithBlock(ABlock: IBlock): ISelect;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);

    { ISelect }
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TSelectState);
  end;

implementation

{ TSelectState }

class function TSelectState.Empty: TSelectState;
begin
  Result.Selected := -1;
  Result.Open := False;
  Result.HighlightIdx := 0;
end;

procedure TSelectState.Toggle;
begin
  Open := not Open;
  if Open then
  begin
    if Selected >= 0 then
      HighlightIdx := Selected
    else
      HighlightIdx := 0;
  end;
end;

procedure TSelectState.MoveUp;
begin
  if HighlightIdx > 0 then Dec(HighlightIdx);
end;

procedure TSelectState.MoveDown(ItemCount: Integer);
begin
  if HighlightIdx < ItemCount - 1 then Inc(HighlightIdx);
end;

procedure TSelectState.Confirm;
begin
  Selected := HighlightIdx;
  Open := False;
end;

{ TSelect }

class function TSelect.New(const AItems: array of AnsiString): ISelect;
var
  LObj: TSelect;
  I: Integer;
begin
  LObj := TSelect.Create;
  SetLength(LObj.FItems, Length(AItems));
  for I := 0 to High(AItems) do
    LObj.FItems[I] := AItems[I];
  LObj.FPlaceholder := '-- select --';
  LObj.FWidth := 0;
  LObj.FMaxDropHeight := 8;
  LObj.FStyle := TStyle.Default;
  LObj.FHighlightStyle := TStyle.Default.WithModifier([mbReversed]);
  LObj.FBlock := nil;
  Result := LObj;
end;

function TSelect.WithPlaceholder(const P: AnsiString): ISelect;
begin
  FPlaceholder := P;
  Result := Self;
end;

function TSelect.WithWidth(W: Integer): ISelect;
begin
  FWidth := W;
  Result := Self;
end;

function TSelect.WithMaxDropHeight(H: Integer): ISelect;
begin
  FMaxDropHeight := H;
  Result := Self;
end;

function TSelect.WithStyle(const S: TStyle): ISelect;
begin
  FStyle := S;
  Result := Self;
end;

function TSelect.WithHighlightStyle(const S: TStyle): ISelect;
begin
  FHighlightStyle := S;
  Result := Self;
end;

function TSelect.WithBlock(ABlock: IBlock): ISelect;
begin
  FBlock := ABlock;
  Result := Self;
end;

procedure TSelect.Render(const AArea: TRect; ABuffer: TBuffer);
var LState: TSelectState;
begin
  LState.Selected := 0;
  LState.Open := False;
  LState.HighlightIdx := 0;
  RenderStateful(AArea, ABuffer, LState);
end;

procedure TSelect.RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TSelectState);
var
  W, DropH, DropY, I, Y, LFirstItem, LItemIdx: Integer;
  DisplayText: AnsiString;
  Sty: TStyle;
  DropArea: TRect;
begin
  if AArea.IsEmpty then Exit;

  W := FWidth;
  if W <= 0 then W := AArea.Width;
  if W > AArea.Width then W := AArea.Width;

  if (AState.Selected >= 0) and (AState.Selected < Length(FItems)) then
    DisplayText := FItems[AState.Selected]
  else
    DisplayText := FPlaceholder;

  ABuffer.SetStyle(TRect.Make(AArea.X, AArea.Y, W, 1), FStyle);
  if AState.Open then
    ABuffer.SetStringN(AArea.X, AArea.Y, DisplayText + ' [v]', W, FStyle.Patch(FHighlightStyle))
  else
    ABuffer.SetStringN(AArea.X, AArea.Y, DisplayText + ' [>]', W, FStyle);

  if not AState.Open then Exit;
  if Length(FItems) = 0 then Exit;

  DropH := Length(FItems);
  if DropH > FMaxDropHeight then DropH := FMaxDropHeight;
  DropY := AArea.Y + 1;

  if DropY + DropH > AArea.Y + AArea.Height then
    DropH := AArea.Y + AArea.Height - DropY;
  if DropH <= 0 then Exit;

  DropArea := TRect.Make(AArea.X, DropY, W, DropH);
  ABuffer.SetStyle(DropArea, FStyle);

  if AState.HighlightIdx < 0 then AState.HighlightIdx := 0;
  if AState.HighlightIdx >= Length(FItems) then
    AState.HighlightIdx := Length(FItems) - 1;

  LFirstItem := 0;
  if AState.HighlightIdx >= DropH then
    LFirstItem := AState.HighlightIdx - DropH + 1;
  if LFirstItem > Length(FItems) - DropH then
    LFirstItem := Length(FItems) - DropH;
  if LFirstItem < 0 then
    LFirstItem := 0;

  Y := DropY;
  for I := 0 to DropH - 1 do
  begin
    LItemIdx := LFirstItem + I;
    if LItemIdx >= Length(FItems) then Break;
    if LItemIdx = AState.HighlightIdx then
      Sty := FHighlightStyle
    else
      Sty := FStyle;
    ABuffer.SetStringN(AArea.X, Y, ' ' + FItems[LItemIdx], W, Sty);
    Inc(Y);
  end;
end;

end.
