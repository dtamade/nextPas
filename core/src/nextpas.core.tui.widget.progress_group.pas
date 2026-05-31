unit nextpas.core.tui.widget.progress_group;

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
  TProgressItem = record
    Label_: AnsiString;
    Ratio: Double;
    FilledStyle: TStyle;
    class function Make(const ALabel: AnsiString; ARatio: Double): TProgressItem; static;
    function WithStyle(const S: TStyle): TProgressItem;
  end;

  TProgressGroup = record
    Items: array of TProgressItem;
    LabelWidth: Integer;
    ShowPercent: Boolean;
    Style: TStyle;
    EmptyStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;

    class function Create(const AItems: array of TProgressItem): TProgressGroup; static;
    function WithLabelWidth(W: Integer): TProgressGroup;
    function WithShowPercent(V: Boolean): TProgressGroup;
    function WithStyle(const S: TStyle): TProgressGroup;
    function WithEmptyStyle(const S: TStyle): TProgressGroup;
    function WithBlock(const B: TBlock): TProgressGroup;
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

implementation

uses
  SysUtils;

const
  BlockChars: array[0..7] of AnsiString = (
    ' ', #$E2#$96#$8F, #$E2#$96#$8E, #$E2#$96#$8D,
    #$E2#$96#$8C, #$E2#$96#$8B, #$E2#$96#$8A, #$E2#$96#$89
  );
  FullBlock: AnsiString = #$E2#$96#$88;

{ TProgressItem }

class function TProgressItem.Make(const ALabel: AnsiString; ARatio: Double): TProgressItem;
begin
  Result.Label_ := ALabel;
  if ARatio < 0.0 then ARatio := 0.0;
  if ARatio > 1.0 then ARatio := 1.0;
  Result.Ratio := ARatio;
  Result.FilledStyle := TStyle.Default.WithFg(TUI_GREEN);
end;

function TProgressItem.WithStyle(const S: TStyle): TProgressItem;
begin
  Result := Self;
  Result.FilledStyle := S;
end;

{ TProgressGroup }

class function TProgressGroup.Create(const AItems: array of TProgressItem): TProgressGroup;
var I: Integer;
begin
  SetLength(Result.Items, Length(AItems));
  for I := 0 to High(AItems) do
    Result.Items[I] := AItems[I];
  Result.LabelWidth := 0;
  Result.ShowPercent := True;
  Result.Style := TStyle.Default;
  Result.EmptyStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  Result.HasBlock := False;
  Result.Block := nil;
end;

function TProgressGroup.WithLabelWidth(W: Integer): TProgressGroup;
begin Result := Self; Result.LabelWidth := W; end;

function TProgressGroup.WithShowPercent(V: Boolean): TProgressGroup;
begin Result := Self; Result.ShowPercent := V; end;

function TProgressGroup.WithStyle(const S: TStyle): TProgressGroup;
begin Result := Self; Result.Style := S; end;

function TProgressGroup.WithEmptyStyle(const S: TStyle): TProgressGroup;
begin Result := Self; Result.EmptyStyle := S; end;

function TProgressGroup.WithBlock(const B: TBlock): TProgressGroup;
begin Result := Self; Result.HasBlock := True; Result.Block := B; end;

procedure TProgressGroup.Render(const Area: TRect; ABuf: TBuffer);
var
  Inner: TRect;
  I, J, Y, LW, BarW, PctW, FilledCells, Frac, StartX: Integer;
  PctStr: AnsiString;
  EffLabelW: Integer;
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

  // Auto-detect label width if not set
  EffLabelW := LabelWidth;
  if EffLabelW = 0 then
  begin
    for I := 0 to High(Items) do
      if Length(Items[I].Label_) > EffLabelW then
        EffLabelW := Length(Items[I].Label_);
    Inc(EffLabelW);
  end;

  PctW := 0;
  if ShowPercent then PctW := 5;

  BarW := Inner.Width - EffLabelW - PctW;
  if BarW < 1 then BarW := 1;

  for I := 0 to High(Items) do
  begin
    Y := Inner.Y + I;
    if Y >= Inner.Y + Inner.Height then Break;

    // Label
    ABuf.SetStringN(Inner.X, Y, Items[I].Label_, EffLabelW, Style);

    // Bar
    FilledCells := Trunc(Items[I].Ratio * BarW);
    Frac := Trunc((Items[I].Ratio * BarW - FilledCells) * 8);
    if FilledCells > BarW then FilledCells := BarW;

    // Full block characters
    for J := 0 to FilledCells - 1 do
      ABuf.SetStringN(Inner.X + EffLabelW + J, Y, FullBlock, 1, Items[I].FilledStyle);

    // Fractional cell
    if (FilledCells < BarW) and (Frac > 0) then
      ABuf.SetStringN(Inner.X + EffLabelW + FilledCells, Y, BlockChars[Frac], 1, Items[I].FilledStyle);

    // Empty cells
    StartX := FilledCells;
    if Frac > 0 then Inc(StartX);
    for J := StartX to BarW - 1 do
      ABuf.SetStringN(Inner.X + EffLabelW + J, Y, #$E2#$96#$91, 1, EmptyStyle);

    // Percentage
    if ShowPercent then
    begin
      PctStr := Format('%3d%%', [Round(Items[I].Ratio * 100)]);
      ABuf.SetStringN(Inner.X + EffLabelW + BarW, Y, PctStr, PctW, Style);
    end;
  end;
end;

end.
