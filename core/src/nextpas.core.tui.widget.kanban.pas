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
  nextpas.core.tui.layout,
  nextpas.core.tui.widget.intf;

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

  IKanban = interface(IWidget)
    ['{B2C3D4E5-F6A7-8901-2345-6789ABCDEF01}']
    function WithStyle(const AStyle: TStyle): IKanban;
    function WithHeaderStyle(const AStyle: TStyle): IKanban;
    function WithCardStyle(const AStyle: TStyle): IKanban;
    function WithActiveCardStyle(const AStyle: TStyle): IKanban;
    function WithBlock(ABlock: IBlock): IKanban;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TKanbanState);
  end;

  TKanban = class(TInterfacedObject, IWidget, IKanban)
  private
    FColumns: array of TKanbanColumn;
    FStyle: TStyle;
    FHeaderStyle: TStyle;
    FCardStyle: TStyle;
    FActiveCardStyle: TStyle;
    FBlock: IBlock;
  public
    class function New(const ACols: array of TKanbanColumn): IKanban; static;

    { IKanban builder }
    function WithStyle(const AStyle: TStyle): IKanban;
    function WithHeaderStyle(const AStyle: TStyle): IKanban;
    function WithCardStyle(const AStyle: TStyle): IKanban;
    function WithActiveCardStyle(const AStyle: TStyle): IKanban;
    function WithBlock(ABlock: IBlock): IKanban;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    { IKanban stateful }
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TKanbanState);
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

class function TKanban.New(const ACols: array of TKanbanColumn): IKanban;
var
  LObj: TKanban;
  I: Integer;
begin
  LObj := TKanban.Create;
  SetLength(LObj.FColumns, Length(ACols));
  for I := 0 to High(ACols) do
    LObj.FColumns[I] := ACols[I];
  LObj.FStyle := TStyle.Default;
  LObj.FHeaderStyle := TStyle.Default.WithModifier([mbBold]);
  LObj.FCardStyle := TStyle.Default;
  LObj.FActiveCardStyle := TStyle.Default.WithModifier([mbReversed]);
  LObj.FBlock := nil;
  Result := LObj;
end;

function TKanban.WithStyle(const AStyle: TStyle): IKanban;
begin FStyle := AStyle; Result := Self; end;

function TKanban.WithHeaderStyle(const AStyle: TStyle): IKanban;
begin FHeaderStyle := AStyle; Result := Self; end;

function TKanban.WithCardStyle(const AStyle: TStyle): IKanban;
begin FCardStyle := AStyle; Result := Self; end;

function TKanban.WithActiveCardStyle(const AStyle: TStyle): IKanban;
begin FActiveCardStyle := AStyle; Result := Self; end;

function TKanban.WithBlock(ABlock: IBlock): IKanban;
begin FBlock := ABlock; Result := Self; end;

procedure TKanban.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LState: TKanbanState;
begin
  LState := TKanbanState.Empty;
  RenderStateful(AArea, ABuffer, LState);
end;

procedure TKanban.RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TKanbanState);
var
  Inner: TRect;
  ColRects: TRectArray;
  Constraints: array of TConstraint;
  I, J, Y, ColW: Integer;
  CSty: TStyle;
  CardText: AnsiString;
begin
  if AArea.IsEmpty or (Length(FColumns) = 0) then Exit;

  // Clamp state indices
  if AState.ActiveCol < 0 then AState.ActiveCol := 0;
  if AState.ActiveCol >= Length(FColumns) then AState.ActiveCol := Length(FColumns) - 1;
  if Length(FColumns[AState.ActiveCol].Cards) > 0 then
  begin
    if AState.ActiveCard < 0 then AState.ActiveCard := 0;
    if AState.ActiveCard >= Length(FColumns[AState.ActiveCol].Cards) then
      AState.ActiveCard := Length(FColumns[AState.ActiveCol].Cards) - 1;
  end
  else
    AState.ActiveCard := 0;

  ABuffer.SetStyle(AArea, FStyle);

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;

  // Equal-width columns
  SetLength(Constraints, Length(FColumns));
  for I := 0 to High(FColumns) do
    Constraints[I] := FillConstraint(1);

  ColRects := HorizontalSplit(Inner, Constraints);

  for I := 0 to High(FColumns) do
  begin
    if I >= Length(ColRects) then Break;

    ColW := ColRects[I].Width;
    Y := ColRects[I].Y;

    // Column header
    ABuffer.SetStringN(ColRects[I].X, Y, FColumns[I].Title, ColW, FHeaderStyle);
    Inc(Y);
    // Separator
    ABuffer.SetStringN(ColRects[I].X, Y, StringOfChar('-', ColW), ColW, FStyle);
    Inc(Y);

    // Cards
    for J := 0 to High(FColumns[I].Cards) do
    begin
      if Y >= ColRects[I].Y + ColRects[I].Height then Break;

      if (I = AState.ActiveCol) and (J = AState.ActiveCard) then
        CSty := FActiveCardStyle
      else
        CSty := FCardStyle;

      CardText := FColumns[I].Cards[J].Title;
      if FColumns[I].Cards[J].Tag <> '' then
        CardText := '[' + FColumns[I].Cards[J].Tag + '] ' + CardText;

      ABuffer.SetStringN(ColRects[I].X, Y, CardText, ColW, CSty);
      Inc(Y);
    end;
  end;
end;

end.
