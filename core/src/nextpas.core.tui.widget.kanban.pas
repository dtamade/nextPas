unit nextpas.core.tui.widget.kanban;

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
  nextpas.core.tui.borders,
  nextpas.core.tui.layout;

type
  TKanbanCard = record
    Title: AnsiString;
    Tag: AnsiString;
    class function Make(const ATitle: AnsiString): TKanbanCard; static;
    function WithTag(const T: AnsiString): TKanbanCard;
  end;

  TKanbanColumn = record
    Title: AnsiString;
    Cards: array of TKanbanCard;
  end;

  TKanbanState = record
    ActiveCol: Integer;
    ActiveCard: Integer;
    class function Empty: TKanbanState; static;
    procedure MoveRight(ColCount: Integer);
    procedure MoveLeft;
    procedure MoveDown(CardCount: Integer);
    procedure MoveUp;
  end;

  TKanban = record
    Columns: array of TKanbanColumn;
    Style: TStyle;
    HeaderStyle: TStyle;
    CardStyle: TStyle;
    ActiveCardStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;

    class function Create(const ACols: array of TKanbanColumn): TKanban; static;
    function WithStyle(const S: TStyle): TKanban;
    function WithHeaderStyle(const S: TStyle): TKanban;
    function WithCardStyle(const S: TStyle): TKanban;
    function WithActiveCardStyle(const S: TStyle): TKanban;
    function WithBlock(const B: TBlock): TKanban;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TKanbanState);
  end;

function MakeColumn(const ATitle: AnsiString; const ACards: array of TKanbanCard): TKanbanColumn;

implementation

uses
  SysUtils;

{ TKanbanCard }

class function TKanbanCard.Make(const ATitle: AnsiString): TKanbanCard;
begin
  Result.Title := ATitle;
  Result.Tag := '';
end;

function TKanbanCard.WithTag(const T: AnsiString): TKanbanCard;
begin Result := Self; Result.Tag := T; end;

{ TKanbanState }

class function TKanbanState.Empty: TKanbanState;
begin
  Result.ActiveCol := 0;
  Result.ActiveCard := 0;
end;

procedure TKanbanState.MoveRight(ColCount: Integer);
begin
  if ActiveCol < ColCount - 1 then begin Inc(ActiveCol); ActiveCard := 0; end;
end;

procedure TKanbanState.MoveLeft;
begin
  if ActiveCol > 0 then begin Dec(ActiveCol); ActiveCard := 0; end;
end;

procedure TKanbanState.MoveDown(CardCount: Integer);
begin
  if ActiveCard < CardCount - 1 then Inc(ActiveCard);
end;

procedure TKanbanState.MoveUp;
begin
  if ActiveCard > 0 then Dec(ActiveCard);
end;

{ Helper }

function MakeColumn(const ATitle: AnsiString; const ACards: array of TKanbanCard): TKanbanColumn;
var I: Integer;
begin
  Result.Title := ATitle;
  SetLength(Result.Cards, Length(ACards));
  for I := 0 to High(ACards) do
    Result.Cards[I] := ACards[I];
end;

{ TKanban }

class function TKanban.Create(const ACols: array of TKanbanColumn): TKanban;
var I: Integer;
begin
  SetLength(Result.Columns, Length(ACols));
  for I := 0 to High(ACols) do
    Result.Columns[I] := ACols[I];
  Result.Style := TStyle.Default;
  Result.HeaderStyle := TStyle.Default.WithModifier([mbBold]);
  Result.CardStyle := TStyle.Default;
  Result.ActiveCardStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.HasBlock := False;
  Result.Block := nil;
end;

function TKanban.WithStyle(const S: TStyle): TKanban;
begin Result := Self; Result.Style := S; end;

function TKanban.WithHeaderStyle(const S: TStyle): TKanban;
begin Result := Self; Result.HeaderStyle := S; end;

function TKanban.WithCardStyle(const S: TStyle): TKanban;
begin Result := Self; Result.CardStyle := S; end;

function TKanban.WithActiveCardStyle(const S: TStyle): TKanban;
begin Result := Self; Result.ActiveCardStyle := S; end;

function TKanban.WithBlock(const B: TBlock): TKanban;
begin Result := Self; Result.HasBlock := True; Result.Block := B; end;

procedure TKanban.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TKanbanState);
var
  Inner: TRect;
  ColRects: TRectArray;
  Constraints: array of TConstraint;
  I, J, Y, ColW: Integer;
  CSty: TStyle;
  CardText: AnsiString;
begin
  if Area.IsEmpty or (Length(Columns) = 0) then Exit;

  // Clamp state indices
  if State.ActiveCol < 0 then State.ActiveCol := 0;
  if State.ActiveCol >= Length(Columns) then State.ActiveCol := Length(Columns) - 1;
  if Length(Columns[State.ActiveCol].Cards) > 0 then
  begin
    if State.ActiveCard < 0 then State.ActiveCard := 0;
    if State.ActiveCard >= Length(Columns[State.ActiveCol].Cards) then
      State.ActiveCard := Length(Columns[State.ActiveCol].Cards) - 1;
  end
  else
    State.ActiveCard := 0;

  ABuf.SetStyle(Area, Style);

  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;

  // Equal-width columns
  SetLength(Constraints, Length(Columns));
  for I := 0 to High(Columns) do
    Constraints[I] := FillConstraint(1);

  ColRects := HorizontalSplit(Inner, Constraints);

  for I := 0 to High(Columns) do
  begin
    if I >= Length(ColRects) then Break;

    ColW := ColRects[I].Width;
    Y := ColRects[I].Y;

    // Column header
    ABuf.SetStringN(ColRects[I].X, Y, Columns[I].Title, ColW, HeaderStyle);
    Inc(Y);
    // Separator
    ABuf.SetStringN(ColRects[I].X, Y, StringOfChar('-', ColW), ColW, Style);
    Inc(Y);

    // Cards
    for J := 0 to High(Columns[I].Cards) do
    begin
      if Y >= ColRects[I].Y + ColRects[I].Height then Break;

      if (I = State.ActiveCol) and (J = State.ActiveCard) then
        CSty := ActiveCardStyle
      else
        CSty := CardStyle;

      CardText := Columns[I].Cards[J].Title;
      if Columns[I].Cards[J].Tag <> '' then
        CardText := '[' + Columns[I].Cards[J].Tag + '] ' + CardText;

      ABuf.SetStringN(ColRects[I].X, Y, CardText, ColW, CSty);
      Inc(Y);
    end;
  end;
end;

end.
