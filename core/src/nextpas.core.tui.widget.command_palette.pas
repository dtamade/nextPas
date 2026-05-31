unit nextpas.core.tui.widget.command_palette;

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
  nextpas.core.tui.widget.input;

type
  TCommandItem = record
    Name: AnsiString;
    Description: AnsiString;
    class function Make(const AName, ADesc: AnsiString): TCommandItem; static;
  end;

  TCommandPaletteState = record
    Input: TInputState;
    Selected: Integer;
    Visible: Boolean;
    FilteredIndices: array of Integer;

    class function Empty: TCommandPaletteState; static;
    procedure Open;
    procedure Close;
    procedure Toggle;
    procedure SelectNext;
    procedure SelectPrev;
  end;

  TCommandPalette = record
    Items: array of TCommandItem;
    Style: TStyle;
    SelectedStyle: TStyle;
    InputStyle: TStyle;
    Width: Integer;
    MaxVisible: Integer;

    class function Create(const AItems: array of TCommandItem): TCommandPalette; static;
    function WithStyle(const S: TStyle): TCommandPalette;
    function WithSelectedStyle(const S: TStyle): TCommandPalette;
    function WithWidth(W: Integer): TCommandPalette;
    function WithMaxVisible(N: Integer): TCommandPalette;
    procedure UpdateFilter(var State: TCommandPaletteState);
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TCommandPaletteState);
    function SelectedItem(const State: TCommandPaletteState): Integer;
  end;

function FuzzyMatch(const Pattern, Text: AnsiString): Boolean;
function FuzzyScore(const Pattern, Text: AnsiString): Integer;

implementation

uses
  SysUtils;

{ TCommandItem }

class function TCommandItem.Make(const AName, ADesc: AnsiString): TCommandItem;
begin
  Result.Name := AName;
  Result.Description := ADesc;
end;

{ TCommandPaletteState }

class function TCommandPaletteState.Empty: TCommandPaletteState;
begin
  Result.Input := TInputState.Empty;
  Result.Selected := 0;
  Result.Visible := False;
  Result.FilteredIndices := nil;
end;

procedure TCommandPaletteState.Open;
begin
  Visible := True;
  Input := TInputState.Empty;
  Selected := 0;
end;

procedure TCommandPaletteState.Close;
begin
  Visible := False;
end;

procedure TCommandPaletteState.Toggle;
begin
  if Visible then Close else Open;
end;

procedure TCommandPaletteState.SelectNext;
begin
  if Selected < Length(FilteredIndices) - 1 then Inc(Selected);
end;

procedure TCommandPaletteState.SelectPrev;
begin
  if Selected > 0 then Dec(Selected);
end;

{ Fuzzy matching }

function FuzzyMatch(const Pattern, Text: AnsiString): Boolean;
var
  PI, TI: Integer;
  LP, LT: AnsiString;
begin
  if Length(Pattern) = 0 then Exit(True);
  LP := LowerCase(Pattern);
  LT := LowerCase(Text);
  PI := 1;
  for TI := 1 to Length(LT) do
  begin
    if LT[TI] = LP[PI] then
    begin
      Inc(PI);
      if PI > Length(LP) then Exit(True);
    end;
  end;
  Result := False;
end;

function FuzzyScore(const Pattern, Text: AnsiString): Integer;
var
  PI, TI, Score, Consecutive: Integer;
  LP, LT: AnsiString;
begin
  if Length(Pattern) = 0 then Exit(1000);
  LP := LowerCase(Pattern);
  LT := LowerCase(Text);
  PI := 1;
  Score := 0;
  Consecutive := 0;
  for TI := 1 to Length(LT) do
  begin
    if PI > Length(LP) then Break;
    if LT[TI] = LP[PI] then
    begin
      Inc(PI);
      Inc(Consecutive);
      Inc(Score, Consecutive * 10);
      if TI = 1 then Inc(Score, 50); // prefix bonus
    end
    else
      Consecutive := 0;
  end;
  if PI <= Length(LP) then
    Result := 0
  else
    Result := Score;
end;

{ TCommandPalette }

class function TCommandPalette.Create(const AItems: array of TCommandItem): TCommandPalette;
var I: Integer;
begin
  SetLength(Result.Items, Length(AItems));
  for I := 0 to High(AItems) do
    Result.Items[I] := AItems[I];
  Result.Style := TStyle.Default;
  Result.SelectedStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.InputStyle := TStyle.Default;
  Result.Width := 50;
  Result.MaxVisible := 10;
end;

function TCommandPalette.WithStyle(const S: TStyle): TCommandPalette;
begin Result := Self; Result.Style := S; end;

function TCommandPalette.WithSelectedStyle(const S: TStyle): TCommandPalette;
begin Result := Self; Result.SelectedStyle := S; end;

function TCommandPalette.WithWidth(W: Integer): TCommandPalette;
begin Result := Self; Result.Width := W; end;

function TCommandPalette.WithMaxVisible(N: Integer): TCommandPalette;
begin Result := Self; Result.MaxVisible := N; end;

procedure TCommandPalette.UpdateFilter(var State: TCommandPaletteState);
var
  I, Count: Integer;
  Query: AnsiString;
begin
  Query := State.Input.Text;
  Count := 0;
  SetLength(State.FilteredIndices, Length(Items));

  for I := 0 to High(Items) do
  begin
    if FuzzyMatch(Query, Items[I].Name) then
    begin
      State.FilteredIndices[Count] := I;
      Inc(Count);
    end;
  end;

  SetLength(State.FilteredIndices, Count);
  if State.Selected >= Count then
    State.Selected := Count - 1;
  if State.Selected < 0 then State.Selected := 0;
end;

function TCommandPalette.SelectedItem(const State: TCommandPaletteState): Integer;
begin
  if (State.Selected >= 0) and (State.Selected < Length(State.FilteredIndices)) then
    Result := State.FilteredIndices[State.Selected]
  else
    Result := -1;
end;

procedure TCommandPalette.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TCommandPaletteState);
var
  PalW, PalH, PalX, PalY, I, Row, ItemIdx, VisCount: Integer;
  PalArea, InputArea, ListArea: TRect;
  Inp: IInput;
  LineSty: TStyle;
  DisplayStr: AnsiString;
begin
  if not State.Visible then Exit;
  if Area.IsEmpty then Exit;

  UpdateFilter(State);

  VisCount := Length(State.FilteredIndices);
  if VisCount > MaxVisible then VisCount := MaxVisible;

  PalW := Width;
  if PalW > Area.Width - 4 then PalW := Area.Width - 4;
  PalH := VisCount + 3; // border top + input + items + border bottom
  if PalH > Area.Height - 2 then PalH := Area.Height - 2;

  PalX := Area.X + (Area.Width - PalW) div 2;
  PalY := Area.Y + 2;

  PalArea := TRect.Make(PalX, PalY, PalW, PalH);

  // Draw block frame
  TBlock.New.WithBorders(BORDERS_ALL)
    .WithTitle(' Command Palette ')
    .WithBorderStyle(Style)
    .Render(PalArea, ABuf);

  // Input area (first row inside block)
  InputArea := TRect.Make(PalX + 1, PalY + 1, PalW - 2, 1);
  Inp := TInput.New.WithPlaceholder('Search...');
  Inp.RenderStateful(InputArea, ABuf, State.Input);

  // List area
  for I := 0 to VisCount - 1 do
  begin
    Row := PalY + 2 + I;
    if Row >= PalY + PalH - 1 then Break;

    ItemIdx := State.FilteredIndices[I];
    if I = State.Selected then
      LineSty := SelectedStyle
    else
      LineSty := Style;

    DisplayStr := Items[ItemIdx].Name;
    if Items[ItemIdx].Description <> '' then
      DisplayStr := DisplayStr + ' - ' + Items[ItemIdx].Description;

    ABuf.SetStringN(PalX + 1, Row, DisplayStr, PalW - 2, LineSty);
  end;
end;

end.
