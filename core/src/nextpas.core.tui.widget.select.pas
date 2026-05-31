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

  TSelect = class(TInterfacedObject)
    Items: array of AnsiString;
    Placeholder: AnsiString;
    Width: Integer;
    MaxDropHeight: Integer;
    Style: TStyle;
    HighlightStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;

    class function Create(const AItems: array of AnsiString): TSelect; static;
    function WithPlaceholder(const P: AnsiString): TSelect;
    function WithWidth(W: Integer): TSelect;
    function WithMaxDropHeight(H: Integer): TSelect;
    function WithStyle(const S: TStyle): TSelect;
    function WithHighlightStyle(const S: TStyle): TSelect;
    function WithBlock(const B: TBlock): TSelect;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TSelectState);
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

class function TSelect.Create(const AItems: array of AnsiString): TSelect;
var I: Integer;
begin
  SetLength(Result.Items, Length(AItems));
  for I := 0 to High(AItems) do
    Result.Items[I] := AItems[I];
  Result.Placeholder := '-- select --';
  Result.Width := 0;
  Result.MaxDropHeight := 8;
  Result.Style := TStyle.Default;
  Result.HighlightStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.HasBlock := False;
  Result.Block := nil;
end;

function TSelect.WithPlaceholder(const P: AnsiString): TSelect;
begin Result := Self; Result.Placeholder := P; end;

function TSelect.WithWidth(W: Integer): TSelect;
begin Result := Self; Result.Width := W; end;

function TSelect.WithMaxDropHeight(H: Integer): TSelect;
begin Result := Self; Result.MaxDropHeight := H; end;

function TSelect.WithStyle(const S: TStyle): TSelect;
begin Result := Self; Result.Style := S; end;

function TSelect.WithHighlightStyle(const S: TStyle): TSelect;
begin Result := Self; Result.HighlightStyle := S; end;

function TSelect.WithBlock(const B: TBlock): TSelect;
begin Result := Self; Result.HasBlock := True; Result.Block := B; end;

procedure TSelect.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TSelectState);
var
  W, DropH, DropY, I, Y: Integer;
  DisplayText: AnsiString;
  Sty: TStyle;
  DropArea: TRect;
begin
  if Area.IsEmpty then Exit;

  W := Width;
  if W <= 0 then W := Area.Width;
  if W > Area.Width then W := Area.Width;

  if (State.Selected >= 0) and (State.Selected < Length(Items)) then
    DisplayText := Items[State.Selected]
  else
    DisplayText := Placeholder;

  ABuf.SetStyle(TRect.Make(Area.X, Area.Y, W, 1), Style);
  if State.Open then
    ABuf.SetStringN(Area.X, Area.Y, DisplayText + ' [v]', W, Style.Patch(HighlightStyle))
  else
    ABuf.SetStringN(Area.X, Area.Y, DisplayText + ' [>]', W, Style);

  if not State.Open then Exit;
  if Length(Items) = 0 then Exit;

  DropH := Length(Items);
  if DropH > MaxDropHeight then DropH := MaxDropHeight;
  DropY := Area.Y + 1;

  if DropY + DropH > Area.Y + Area.Height then
    DropH := Area.Y + Area.Height - DropY;
  if DropH <= 0 then Exit;

  DropArea := TRect.Make(Area.X, DropY, W, DropH);
  ABuf.SetStyle(DropArea, Style);

  if State.HighlightIdx < 0 then State.HighlightIdx := 0;
  if State.HighlightIdx >= Length(Items) then
    State.HighlightIdx := Length(Items) - 1;

  Y := DropY;
  for I := 0 to DropH - 1 do
  begin
    if I >= Length(Items) then Break;
    if I = State.HighlightIdx then
      Sty := HighlightStyle
    else
      Sty := Style;
    ABuf.SetStringN(Area.X, Y, ' ' + Items[I], W, Sty);
    Inc(Y);
  end;
end;

end.
