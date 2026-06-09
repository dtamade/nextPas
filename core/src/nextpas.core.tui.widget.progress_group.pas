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
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.intf;

type
  TProgressItem = record
    Label_: AnsiString;
    Ratio: Double;
    FilledStyle: TStyle;
    class function Make(const ALabel: AnsiString; ARatio: Double): TProgressItem; static;
    function WithStyle(const S: TStyle): TProgressItem;
  end;

  IProgressGroup = interface(IWidget)
    ['{C5D6E7F8-A9B0-1234-CDEF-567890123456}']
    function WithLabelWidth(W: Integer): IProgressGroup;
    function WithShowPercent(V: Boolean): IProgressGroup;
    function WithStyle(const S: TStyle): IProgressGroup;
    function WithEmptyStyle(const S: TStyle): IProgressGroup;
    function WithBlock(ABlock: IBlock): IProgressGroup;
  end;

  TProgressGroup = class(TInterfacedObject, IWidget, IProgressGroup)
  private
    FItems: array of TProgressItem;
    FLabelWidth: Integer;
    FShowPercent: Boolean;
    FStyle: TStyle;
    FEmptyStyle: TStyle;
    FBlock: IBlock;
  public
    class function New(const AItems: array of TProgressItem): IProgressGroup; static;

    function WithLabelWidth(W: Integer): IProgressGroup;
    function WithShowPercent(V: Boolean): IProgressGroup;
    function WithStyle(const S: TStyle): IProgressGroup;
    function WithEmptyStyle(const S: TStyle): IProgressGroup;
    function WithBlock(ABlock: IBlock): IProgressGroup;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
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
begin Result := Self; Result.FilledStyle := S; end;

{ TProgressGroup }

class function TProgressGroup.New(const AItems: array of TProgressItem): IProgressGroup;
var LSelf: TProgressGroup; I: Integer;
begin
  LSelf := TProgressGroup.Create;
  SetLength(LSelf.FItems, Length(AItems));
  for I := 0 to High(AItems) do LSelf.FItems[I] := AItems[I];
  LSelf.FLabelWidth := 0;
  LSelf.FShowPercent := True;
  LSelf.FStyle := TStyle.Default;
  LSelf.FEmptyStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  LSelf.FBlock := nil;
  Result := LSelf;
end;

function TProgressGroup.WithLabelWidth(W: Integer): IProgressGroup;
begin FLabelWidth := W; Result := Self; end;

function TProgressGroup.WithShowPercent(V: Boolean): IProgressGroup;
begin FShowPercent := V; Result := Self; end;

function TProgressGroup.WithStyle(const S: TStyle): IProgressGroup;
begin FStyle := S; Result := Self; end;

function TProgressGroup.WithEmptyStyle(const S: TStyle): IProgressGroup;
begin FEmptyStyle := S; Result := Self; end;

function TProgressGroup.WithBlock(ABlock: IBlock): IProgressGroup;
begin FBlock := ABlock; Result := Self; end;

procedure TProgressGroup.Render(const AArea: TRect; ABuffer: TBuffer);
var
  Inner: TRect;
  I, J, Y, BarW, PctW, FilledCells, Frac, StartX: Integer;
  LCursorX, LRight, LRemaining: Integer;
  PctStr: AnsiString;
  EffLabelW: Integer;

  procedure WriteSegment(const AText: AnsiString; AMaxWidth: Integer; const AStyle: TStyle);
  var
    LWriteWidth, LWritten: Integer;
  begin
    if (AMaxWidth <= 0) or (LRemaining <= 0) then Exit;
    LWriteWidth := AMaxWidth;
    if LWriteWidth > LRemaining then LWriteWidth := LRemaining;
    LWritten := ABuffer.SetStringN(LCursorX, Y, AText, LWriteWidth, AStyle);
    Inc(LCursorX, LWritten);
    Dec(LRemaining, LWritten);
  end;
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

  EffLabelW := FLabelWidth;
  if EffLabelW = 0 then
  begin
    for I := 0 to High(FItems) do
      if Length(FItems[I].Label_) > EffLabelW then
        EffLabelW := Length(FItems[I].Label_);
    Inc(EffLabelW);
  end;

  PctW := 0;
  if FShowPercent then PctW := 5;

  BarW := Inner.Width - EffLabelW - PctW;
  if BarW < 1 then BarW := 1;

  for I := 0 to High(FItems) do
  begin
    Y := Inner.Y + I;
    if Y >= Inner.Y + Inner.Height then Break;

    LCursorX := Inner.X;
    LRight := Inner.X + Inner.Width;
    LRemaining := LRight - LCursorX;
    if LRemaining <= 0 then Continue;

    WriteSegment(FItems[I].Label_, EffLabelW, FStyle);
    if LRemaining <= 0 then Continue;

    FilledCells := Trunc(FItems[I].Ratio * BarW);
    Frac := Trunc((FItems[I].Ratio * BarW - FilledCells) * 8);
    if FilledCells > BarW then FilledCells := BarW;

    for J := 0 to FilledCells - 1 do
      WriteSegment(FullBlock, 1, FItems[I].FilledStyle);

    if (FilledCells < BarW) and (Frac > 0) then
      WriteSegment(BlockChars[Frac], 1, FItems[I].FilledStyle);

    StartX := FilledCells;
    if Frac > 0 then Inc(StartX);
    for J := StartX to BarW - 1 do
      WriteSegment(#$E2#$96#$91, 1, FEmptyStyle);

    if FShowPercent then
    begin
      PctStr := Format('%3d%%', [Round(FItems[I].Ratio * 100)]);
      WriteSegment(PctStr, PctW, FStyle);
    end;
  end;
end;

end.
