unit nextpas.core.tui.widget.gauge;

// Horizontal progress bar widget.
//
// Renders a filled/empty bar across a single row of the given Area.
// Sub-cell precision uses Unicode block characters (U+2588..U+258F)
// for the fractional column at the boundary between filled and empty.
//
// Optional centered label text overlays the bar; characters over the
// filled portion use FilledStyle, those over the empty portion use
// EmptyStyle.

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
  nextpas.core.tui.widget.intf;

type
  TGaugeThreshold = record
    Limit: Double;
    Style: TStyle;
  end;

  TGauge = record
    Ratio: Double;
    Label_: AnsiString;
    FilledStyle: TStyle;
    EmptyStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;
    Thresholds: array of TGaugeThreshold;

    class function Default: TGauge; static;
    function WithRatio(R: Double): TGauge;
    function WithPercent(APercent: Integer): TGauge;
    function WithLabel(const S: AnsiString): TGauge;
    function WithFilledStyle(const S: TStyle): TGauge;
    function WithEmptyStyle(const S: TStyle): TGauge;
    function WithBlock(ABlock: IBlock): TGauge;
    function WithThreshold(Limit: Double; const S: TStyle): TGauge;
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

implementation

uses
  nextpas.core.text.utf8,
  nextpas.core.text.width;

type
  TGaugeAdv = record ByteLen, Width: Integer; end;

function GaugeGraphemeAt(const ABuf: AnsiString; ALen, AOffset: Integer): TGaugeAdv; inline;
var LDec: TUTF8DecodeResult;
begin
  LDec := UTF8Decode(@PByte(Pointer(ABuf))[AOffset], ALen - AOffset);
  if LDec.ByteLen = 0 then begin Result.ByteLen := 1; Result.Width := 1; end
  else begin Result.ByteLen := LDec.ByteLen; Result.Width := CodepointWidth(LDec.CodePoint); end;
end;

// Unicode block characters for sub-cell precision.
// BLOCK_EIGHTHS[1] = 1/8, ..., BLOCK_EIGHTHS[7] = 7/8.
// Full block (8/8) is handled by the filled-column loop.
const
  BLOCK_EIGHTHS: array[1..7] of AnsiString = (
    #$E2#$96#$8F,   // U+258F LEFT ONE EIGHTH BLOCK
    #$E2#$96#$8E,   // U+258E LEFT ONE QUARTER BLOCK
    #$E2#$96#$8D,   // U+258D LEFT THREE EIGHTHS BLOCK
    #$E2#$96#$8C,   // U+258C LEFT HALF BLOCK
    #$E2#$96#$8B,   // U+258B LEFT FIVE EIGHTHS BLOCK
    #$E2#$96#$8A,   // U+258A LEFT THREE QUARTERS BLOCK
    #$E2#$96#$89    // U+2589 LEFT SEVEN EIGHTHS BLOCK
  );
  BLOCK_FULL: AnsiString = #$E2#$96#$88;  // U+2588 FULL BLOCK

{ TGauge }

class function TGauge.Default: TGauge;
begin
  Result.Ratio := 0.0;
  Result.Label_ := '';
  Result.FilledStyle := TStyle.Default;
  Result.EmptyStyle := TStyle.Default;
  Result.HasBlock := False;
  Result.Block := nil;
  SetLength(Result.Thresholds, 0);
end;

function TGauge.WithRatio(R: Double): TGauge;
begin
  Result := Self;
  if R < 0.0 then R := 0.0;
  if R > 1.0 then R := 1.0;
  Result.Ratio := R;
end;

function TGauge.WithPercent(APercent: Integer): TGauge;
begin
  Result := WithRatio(APercent / 100.0);
end;

function TGauge.WithLabel(const S: AnsiString): TGauge;
begin
  Result := Self;
  Result.Label_ := S;
end;

function TGauge.WithFilledStyle(const S: TStyle): TGauge;
begin
  Result := Self;
  Result.FilledStyle := S;
end;

function TGauge.WithEmptyStyle(const S: TStyle): TGauge;
begin
  Result := Self;
  Result.EmptyStyle := S;
end;

function TGauge.WithBlock(ABlock: IBlock): TGauge;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := ABlock;
end;

function TGauge.WithThreshold(Limit: Double; const S: TStyle): TGauge;
var N: Integer;
begin
  Result := Self;
  N := Length(Result.Thresholds);
  SetLength(Result.Thresholds, N + 1);
  Result.Thresholds[N].Limit := Limit;
  Result.Thresholds[N].Style := S;
end;

procedure TGauge.Render(const Area: TRect; ABuf: TBuffer);
var
  W: Integer;
  FilledF: Double;
  FilledCols, Eighths: Integer;
  X, Col, LabelW, LabelStart, LabelCol: Integer;
  Y, I: Integer;
  Sty, EffFilled: TStyle;
  BestLimit: Double;
  LabelIdx, LabelLen: Integer;
  Adv: TGaugeAdv;
  CP: PCell;
  Inner: TRect;
begin
  if Area.IsEmpty then Exit;

  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;
  W := Inner.Width;
  Y := Inner.Y;

  // Clamp ratio
  FilledF := Ratio;
  if FilledF < 0.0 then FilledF := 0.0;
  if FilledF > 1.0 then FilledF := 1.0;

  // Resolve threshold: highest limit where ratio >= limit wins
  EffFilled := FilledStyle;
  BestLimit := -1.0;
  for I := 0 to High(Thresholds) do
    if (FilledF >= Thresholds[I].Limit) and (Thresholds[I].Limit > BestLimit) then
    begin
      BestLimit := Thresholds[I].Limit;
      EffFilled := Thresholds[I].Style;
    end;

  // Calculate filled columns and sub-cell eighths
  FilledF := FilledF * W * 8.0;
  FilledCols := Trunc(FilledF) div 8;
  Eighths := Trunc(FilledF) mod 8;

  // Step 1: Fill the bar background
  // Filled portion: full block characters
  for Col := 0 to FilledCols - 1 do
  begin
    X := Inner.X + Col;
    ABuf.SetStringN(X, Y, BLOCK_FULL, 1, EffFilled);
  end;

  // Fractional column (if any)
  if (Eighths > 0) and (FilledCols < W) then
  begin
    X := Inner.X + FilledCols;
    ABuf.SetStringN(X, Y, BLOCK_EIGHTHS[Eighths], 1, EffFilled);
  end;

  // Empty portion: apply EmptyStyle to remaining cells (already spaces)
  Col := FilledCols;
  if Eighths > 0 then Inc(Col);
  while Col < W do
  begin
    X := Inner.X + Col;
    CP := ABuf.CellAt(X, Y);
    if CP <> nil then
      CellApplyStyle(CP^, EmptyStyle);
    Inc(Col);
  end;

  // Step 2: Overlay label if set
  if Label_ = '' then Exit;

  LabelW := Integer(StringDisplayWidth(Label_));
  if LabelW = 0 then Exit;

  // Center the label within the bar width
  LabelStart := (W - LabelW) div 2;
  if LabelStart < 0 then LabelStart := 0;

  // Walk through label graphemes and write them at the correct positions
  LabelIdx := 0;
  LabelLen := Length(Label_);
  LabelCol := LabelStart;

  while (LabelIdx < LabelLen) and (LabelCol < W) do
  begin
    Adv := GaugeGraphemeAt(Label_, LabelLen, LabelIdx);
    if Adv.Width = 0 then
    begin
      Inc(LabelIdx, Adv.ByteLen);
      Continue;
    end;

    // Determine style based on position relative to filled area
    if LabelCol < FilledCols then
      Sty := EffFilled
    else
      Sty := EmptyStyle;

    X := Inner.X + LabelCol;
    // Write the single grapheme
    ABuf.SetStringN(X, Y, Copy(Label_, LabelIdx + 1, Adv.ByteLen), Adv.Width, Sty);

    Inc(LabelCol, Adv.Width);
    Inc(LabelIdx, Adv.ByteLen);
  end;
end;

end.
