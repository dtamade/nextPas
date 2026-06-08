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
  nextpas.core.tui.widget.input,
  nextpas.core.tui.widget.intf;

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

  ICommandPalette = interface(IWidget)
    ['{D4E5F6A7-B8C9-0123-4567-89ABCDEF0123}']
    function WithStyle(const AStyle: TStyle): ICommandPalette;
    function WithSelectedStyle(const AStyle: TStyle): ICommandPalette;
    function WithWidth(AWidth: Integer): ICommandPalette;
    function WithMaxVisible(AMax: Integer): ICommandPalette;
    procedure UpdateFilter(var AState: TCommandPaletteState);
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TCommandPaletteState);
    function SelectedItem(const AState: TCommandPaletteState): Integer;
  end;

  TCommandPalette = class(TInterfacedObject, IWidget, ICommandPalette)
  private
    FItems: array of TCommandItem;
    FStyle: TStyle;
    FSelectedStyle: TStyle;
    FInputStyle: TStyle;
    FWidth: Integer;
    FMaxVisible: Integer;
  public
    class function New(const AItems: array of TCommandItem): ICommandPalette; static;

    { ICommandPalette builder }
    function WithStyle(const AStyle: TStyle): ICommandPalette;
    function WithSelectedStyle(const AStyle: TStyle): ICommandPalette;
    function WithWidth(AWidth: Integer): ICommandPalette;
    function WithMaxVisible(AMax: Integer): ICommandPalette;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    { ICommandPalette stateful }
    procedure UpdateFilter(var AState: TCommandPaletteState);
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TCommandPaletteState);
    function SelectedItem(const AState: TCommandPaletteState): Integer;
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

class function TCommandPalette.New(const AItems: array of TCommandItem): ICommandPalette;
var
  LObj: TCommandPalette;
  I: Integer;
begin
  LObj := TCommandPalette.Create;
  SetLength(LObj.FItems, Length(AItems));
  for I := 0 to High(AItems) do
    LObj.FItems[I] := AItems[I];
  LObj.FStyle := TStyle.Default;
  LObj.FSelectedStyle := TStyle.Default.WithModifier([mbReversed]);
  LObj.FInputStyle := TStyle.Default;
  LObj.FWidth := 50;
  LObj.FMaxVisible := 10;
  Result := LObj;
end;

function TCommandPalette.WithStyle(const AStyle: TStyle): ICommandPalette;
begin FStyle := AStyle; Result := Self; end;

function TCommandPalette.WithSelectedStyle(const AStyle: TStyle): ICommandPalette;
begin FSelectedStyle := AStyle; Result := Self; end;

function TCommandPalette.WithWidth(AWidth: Integer): ICommandPalette;
begin FWidth := AWidth; Result := Self; end;

function TCommandPalette.WithMaxVisible(AMax: Integer): ICommandPalette;
begin FMaxVisible := AMax; Result := Self; end;

procedure TCommandPalette.UpdateFilter(var AState: TCommandPaletteState);
var
  I, Count: Integer;
  Query: AnsiString;
begin
  Query := AState.Input.Text;
  Count := 0;
  SetLength(AState.FilteredIndices, Length(FItems));

  for I := 0 to High(FItems) do
  begin
    if FuzzyMatch(Query, FItems[I].Name) then
    begin
      AState.FilteredIndices[Count] := I;
      Inc(Count);
    end;
  end;

  SetLength(AState.FilteredIndices, Count);
  if AState.Selected >= Count then
    AState.Selected := Count - 1;
  if AState.Selected < 0 then AState.Selected := 0;
end;

function TCommandPalette.SelectedItem(const AState: TCommandPaletteState): Integer;
begin
  if (AState.Selected >= 0) and (AState.Selected < Length(AState.FilteredIndices)) then
    Result := AState.FilteredIndices[AState.Selected]
  else
    Result := -1;
end;

procedure TCommandPalette.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LState: TCommandPaletteState;
begin
  LState := TCommandPaletteState.Empty;
  LState.Visible := True;
  RenderStateful(AArea, ABuffer, LState);
end;

procedure TCommandPalette.RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TCommandPaletteState);
var
  PalW, PalH, PalX, PalY, I, Row, ItemIdx, VisCount: Integer;
  PalArea, InputArea: TRect;
  Inp: IInput;
  LineSty: TStyle;
  DisplayStr: AnsiString;
begin
  if not AState.Visible then Exit;
  if AArea.IsEmpty then Exit;

  UpdateFilter(AState);

  VisCount := Length(AState.FilteredIndices);
  if VisCount > FMaxVisible then VisCount := FMaxVisible;

  PalW := FWidth;
  if PalW > AArea.Width - 4 then PalW := AArea.Width - 4;
  if PalW <= 0 then Exit;
  PalH := VisCount + 3; // border top + input + items + border bottom
  if PalH > AArea.Height - 2 then PalH := AArea.Height - 2;
  if PalH <= 0 then Exit;

  PalX := AArea.X + (AArea.Width - PalW) div 2;
  PalY := AArea.Y + 2;

  PalArea := TRect.Make(PalX, PalY, PalW, PalH);

  // Draw block frame
  TBlock.New.WithBorders(BORDERS_ALL)
    .WithTitle(' Command Palette ')
    .WithBorderStyle(FStyle)
    .Render(PalArea, ABuffer);

  if (PalW <= 2) or (PalH <= 2) then Exit;

  // Input area (first row inside block)
  InputArea := TRect.Make(PalX + 1, PalY + 1, PalW - 2, 1);
  Inp := TInput.New.WithPlaceholder('Search...');
  Inp.RenderStateful(InputArea, ABuffer, AState.Input);

  // List area
  for I := 0 to VisCount - 1 do
  begin
    Row := PalY + 2 + I;
    if Row >= PalY + PalH - 1 then Break;

    ItemIdx := AState.FilteredIndices[I];
    if I = AState.Selected then
      LineSty := FSelectedStyle
    else
      LineSty := FStyle;

    DisplayStr := FItems[ItemIdx].Name;
    if FItems[ItemIdx].Description <> '' then
      DisplayStr := DisplayStr + ' - ' + FItems[ItemIdx].Description;

    ABuffer.SetStringN(PalX + 1, Row, DisplayStr, PalW - 2, LineSty);
  end;
end;

end.
