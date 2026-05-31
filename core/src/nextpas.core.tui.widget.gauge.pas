unit nextpas.core.tui.widget.gauge;

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

  IGauge = interface(IWidget)
    ['{B2C3D4E5-F6A7-8901-BCDE-F23456789012}']
    function WithRatio(R: Double): IGauge;
    function WithPercent(APercent: Integer): IGauge;
    function WithLabel(const S: AnsiString): IGauge;
    function WithFilledStyle(const S: TStyle): IGauge;
    function WithEmptyStyle(const S: TStyle): IGauge;
    function WithBlock(ABlock: IBlock): IGauge;
    function WithThreshold(Limit: Double; const S: TStyle): IGauge;
  end;

  TGauge = class(TInterfacedObject, IWidget, IGauge)
  private
    FRatio: Double;
    FLabel: AnsiString;
    FFilledStyle: TStyle;
    FEmptyStyle: TStyle;
    FBlock: IBlock;
    FThresholds: array of TGaugeThreshold;
  public
    class function New: IGauge; static;

    function WithRatio(R: Double): IGauge;
    function WithPercent(APercent: Integer): IGauge;
    function WithLabel(const S: AnsiString): IGauge;
    function WithFilledStyle(const S: TStyle): IGauge;
    function WithEmptyStyle(const S: TStyle): IGauge;
    function WithBlock(ABlock: IBlock): IGauge;
    function WithThreshold(Limit: Double; const S: TStyle): IGauge;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
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

const
  BLOCK_EIGHTHS: array[1..7] of AnsiString = (
    #$E2#$96#$8F,
    #$E2#$96#$8E,
    #$E2#$96#$8D,
    #$E2#$96#$8C,
    #$E2#$96#$8B,
    #$E2#$96#$8A,
    #$E2#$96#$89
  );
  BLOCK_FULL: AnsiString = #$E2#$96#$88;

{ TGauge }

class function TGauge.New: IGauge;
var LSelf: TGauge;
begin
  LSelf := TGauge.Create;
  LSelf.FRatio := 0.0;
  LSelf.FLabel := '';
  LSelf.FFilledStyle := TStyle.Default;
  LSelf.FEmptyStyle := TStyle.Default;
  LSelf.FBlock := nil;
  SetLength(LSelf.FThresholds, 0);
  Result := LSelf;
end;

function TGauge.WithRatio(R: Double): IGauge;
begin
  if R < 0.0 then R := 0.0;
  if R > 1.0 then R := 1.0;
  FRatio := R;
  Result := Self;
end;

function TGauge.WithPercent(APercent: Integer): IGauge;
begin
  Result := WithRatio(APercent / 100.0);
end;

function TGauge.WithLabel(const S: AnsiString): IGauge;
begin
  FLabel := S;
  Result := Self;
end;

function TGauge.WithFilledStyle(const S: TStyle): IGauge;
begin
  FFilledStyle := S;
  Result := Self;
end;

function TGauge.WithEmptyStyle(const S: TStyle): IGauge;
begin
  FEmptyStyle := S;
  Result := Self;
end;

function TGauge.WithBlock(ABlock: IBlock): IGauge;
begin
  FBlock := ABlock;
  Result := Self;
end;

function TGauge.WithThreshold(Limit: Double; const S: TStyle): IGauge;
var N: Integer;
begin
  N := Length(FThresholds);
  SetLength(FThresholds, N + 1);
  FThresholds[N].Limit := Limit;
  FThresholds[N].Style := S;
  Result := Self;
end;

procedure TGauge.Render(const AArea: TRect; ABuffer: TBuffer);
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
  if AArea.IsEmpty then Exit;

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;
  W := Inner.Width;
  Y := Inner.Y;

  FilledF := FRatio;
  if FilledF < 0.0 then FilledF := 0.0;
  if FilledF > 1.0 then FilledF := 1.0;

  EffFilled := FFilledStyle;
  BestLimit := -1.0;
  for I := 0 to High(FThresholds) do
    if (FilledF >= FThresholds[I].Limit) and (FThresholds[I].Limit > BestLimit) then
    begin
      BestLimit := FThresholds[I].Limit;
      EffFilled := FThresholds[I].Style;
    end;

  FilledF := FilledF * W * 8.0;
  FilledCols := Trunc(FilledF) div 8;
  Eighths := Trunc(FilledF) mod 8;

  for Col := 0 to FilledCols - 1 do
  begin
    X := Inner.X + Col;
    ABuffer.SetStringN(X, Y, BLOCK_FULL, 1, EffFilled);
  end;

  if (Eighths > 0) and (FilledCols < W) then
  begin
    X := Inner.X + FilledCols;
    ABuffer.SetStringN(X, Y, BLOCK_EIGHTHS[Eighths], 1, EffFilled);
  end;

  Col := FilledCols;
  if Eighths > 0 then Inc(Col);
  while Col < W do
  begin
    X := Inner.X + Col;
    CP := ABuffer.CellAt(X, Y);
    if CP <> nil then
      CellApplyStyle(CP^, FEmptyStyle);
    Inc(Col);
  end;

  if FLabel = '' then Exit;

  LabelW := Integer(StringDisplayWidth(FLabel));
  if LabelW = 0 then Exit;

  LabelStart := (W - LabelW) div 2;
  if LabelStart < 0 then LabelStart := 0;

  LabelIdx := 0;
  LabelLen := Length(FLabel);
  LabelCol := LabelStart;

  while (LabelIdx < LabelLen) and (LabelCol < W) do
  begin
    Adv := GaugeGraphemeAt(FLabel, LabelLen, LabelIdx);
    if Adv.Width = 0 then
    begin
      Inc(LabelIdx, Adv.ByteLen);
      Continue;
    end;

    if LabelCol < FilledCols then
      Sty := EffFilled
    else
      Sty := FEmptyStyle;

    X := Inner.X + LabelCol;
    ABuffer.SetStringN(X, Y, Copy(FLabel, LabelIdx + 1, Adv.ByteLen), Adv.Width, Sty);

    Inc(LabelCol, Adv.Width);
    Inc(LabelIdx, Adv.ByteLen);
  end;
end;

end.
