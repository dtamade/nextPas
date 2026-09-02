unit nextpas.core.audio.dsp.filters;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.math.base,
  nextpas.core.math.trig;

type
  TBiquadType = (bqLowPass, bqHighPass, bqBandPass, bqNotch, bqPeak, bqLowShelf, bqHighShelf);

  { Transposed Direct Form II: y=b0*x+z1; z1=b1*x -a1*y + z2; z2=b2*x -a2*y }
  TBiquad = record
    B0, B1, B2, A1, A2: Single;
    Z1, Z2: Single;
    procedure Reset; inline;
    function Process(AX: Single): Single; inline;
    class function Design(AType: TBiquadType; ASampleRate: Double; AFreq, AQ, AGainDB: Double): TBiquad; static;
  end;

  TBiquadProcessor = class(TInterfacedObject, IAudioProcessor)
  private
    FBiquads: array of TBiquad;
  public
    constructor Create(AType: TBiquadType; ASampleRate: Integer; AFreq, AQ, AGainDB: Double; AChannels: Integer);
    function LatencyFrames: Integer;
    procedure Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
    procedure Reset;
  end;

implementation

procedure TBiquad.Reset;
begin
  Z1 := 0; Z2 := 0;
end;

function TBiquad.Process(AX: Single): Single;
var
  LY: Single;
begin
  LY := B0 * AX + Z1;
  Z1 := B1 * AX - A1 * LY + Z2;
  Z2 := B2 * AX - A2 * LY;
  Result := LY;
end;

class function TBiquad.Design(AType: TBiquadType; ASampleRate: Double; AFreq, AQ, AGainDB: Double): TBiquad;
var
  Lw0, Lcosw0, Lsinw0, Lalpha, LA, LsqrtA, LS, LQ: Double;
  Lb0, Lb1, Lb2, La0, La1, La2, LFs, LFreq: Double;
begin
  Result := Default(TBiquad);
  LFs := ASampleRate; if LFs < 1 then LFs := 48000;
  LFreq := AFreq; if LFreq < 1 then LFreq := 1;
  if LFreq > LFs * 0.499 then LFreq := LFs * 0.499;
  LQ := AQ; if LQ < 0.1 then LQ := 0.1;
  Lw0 := 2 * PI_VALUE * LFreq / LFs;
  Lcosw0 := Cos(Lw0); Lsinw0 := Sin(Lw0);
  Lalpha := Lsinw0 / (2 * LQ);
  LA := 1; LsqrtA := 1; LS := 1;
  if AType in [bqPeak, bqLowShelf, bqHighShelf] then
  begin
    LA := Power(10.0, AGainDB / 40.0);
    LsqrtA := Sqrt(LA);
    LS := 1; // shelf slope S=1 (RBJ default)
  end;

  case AType of
    bqLowPass:
      begin Lb0 := (1 - Lcosw0) / 2; Lb1 := 1 - Lcosw0; Lb2 := (1 - Lcosw0) / 2; La0 := 1 + Lalpha; La1 := -2 * Lcosw0; La2 := 1 - Lalpha; end;
    bqHighPass:
      begin Lb0 := (1 + Lcosw0) / 2; Lb1 := -(1 + Lcosw0); Lb2 := (1 + Lcosw0) / 2; La0 := 1 + Lalpha; La1 := -2 * Lcosw0; La2 := 1 - Lalpha; end;
    bqBandPass:
      begin Lb0 := Lalpha; Lb1 := 0; Lb2 := -Lalpha; La0 := 1 + Lalpha; La1 := -2 * Lcosw0; La2 := 1 - Lalpha; end;
    bqNotch:
      begin Lb0 := 1; Lb1 := -2 * Lcosw0; Lb2 := 1; La0 := 1 + Lalpha; La1 := -2 * Lcosw0; La2 := 1 - Lalpha; end;
    bqPeak:
      begin Lb0 := 1 + Lalpha * LA; Lb1 := -2 * Lcosw0; Lb2 := 1 - Lalpha * LA; La0 := 1 + Lalpha / LA; La1 := -2 * Lcosw0; La2 := 1 - Lalpha / LA; end;
    bqLowShelf:
      begin
        Lb0 := LA * ((LA + 1) - (LA - 1) * Lcosw0 + 2 * LsqrtA * Lalpha);
        Lb1 := 2 * LA * ((LA - 1) - (LA + 1) * Lcosw0);
        Lb2 := LA * ((LA + 1) - (LA - 1) * Lcosw0 - 2 * LsqrtA * Lalpha);
        La0 := (LA + 1) + (LA - 1) * Lcosw0 + 2 * LsqrtA * Lalpha;
        La1 := -2 * ((LA - 1) + (LA + 1) * Lcosw0);
        La2 := (LA + 1) + (LA - 1) * Lcosw0 - 2 * LsqrtA * Lalpha;
      end;
    bqHighShelf:
      begin
        Lb0 := LA * ((LA + 1) + (LA - 1) * Lcosw0 + 2 * LsqrtA * Lalpha);
        Lb1 := -2 * LA * ((LA - 1) + (LA + 1) * Lcosw0);
        Lb2 := LA * ((LA + 1) + (LA - 1) * Lcosw0 - 2 * LsqrtA * Lalpha);
        La0 := (LA + 1) - (LA - 1) * Lcosw0 + 2 * LsqrtA * Lalpha;
        La1 := 2 * ((LA - 1) - (LA + 1) * Lcosw0);
        La2 := (LA + 1) - (LA - 1) * Lcosw0 - 2 * LsqrtA * Lalpha;
      end;
  else Lb0 := 1; Lb1 := 0; Lb2 := 0; La0 := 1; La1 := 0; La2 := 0;
  end;
  if La0 <> 0 then
  begin Lb0 := Lb0 / La0; Lb1 := Lb1 / La0; Lb2 := Lb2 / La0; La1 := La1 / La0; La2 := La2 / La0; end;
  Result.B0 := Single(Lb0); Result.B1 := Single(Lb1); Result.B2 := Single(Lb2);
  Result.A1 := Single(La1); Result.A2 := Single(La2);
  Result.Z1 := 0; Result.Z2 := 0;
end;

constructor TBiquadProcessor.Create(AType: TBiquadType; ASampleRate: Integer; AFreq, AQ, AGainDB: Double; AChannels: Integer);
var
  I: Integer; D: TBiquad;
begin
  inherited Create;
  if AChannels < 1 then AChannels := 1;
  if AChannels > MaxAudioChannels then AChannels := MaxAudioChannels;
  SetLength(FBiquads, AChannels);
  D := TBiquad.Design(AType, ASampleRate, AFreq, AQ, AGainDB);
  for I := 0 to AChannels - 1 do FBiquads[I] := D;
end;

function TBiquadProcessor.LatencyFrames: Integer;
begin Result := 0; end;

procedure TBiquadProcessor.Reset;
var I: Integer;
begin for I := 0 to High(FBiquads) do FBiquads[I].Reset; end;

procedure TBiquadProcessor.Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
var
  LFrames, LChannels, LCh, LFr, LCopy, LBiquads, LBase: Integer;
  LOutPtr: PSingle;
begin
  AOutput.Format := AInput.Format;
  AOutput.FrameCount := AInput.FrameCount;
  LCopy := Length(AInput.Data);
  SetLength(AOutput.Data, LCopy);
  if LCopy > 0 then Move(AInput.Data[0], AOutput.Data[0], LCopy);
  if (AInput.FrameCount <= 0) or (Length(AInput.Data) = 0) then Exit;
  if AInput.Format.SampleFormat <> sfF32 then Exit;
  LFrames := AInput.FrameCount; LChannels := AInput.Format.Channels;
  LBiquads := Length(FBiquads);
  if (LChannels <= 0) or (LBiquads = 0) then Exit;
  if Length(AOutput.Data) < LFrames * LChannels * SizeOf(Single) then Exit;
  LOutPtr := PSingle(@AOutput.Data[0]);
  for LFr := 0 to LFrames - 1 do
  begin
    LBase := LFr * LChannels;
    for LCh := 0 to LChannels - 1 do
      if LCh < LBiquads then
        LOutPtr[LBase + LCh] := FBiquads[LCh].Process(LOutPtr[LBase + LCh])
      else
        LOutPtr[LBase + LCh] := FBiquads[LBiquads - 1].Process(LOutPtr[LBase + LCh]);
  end;
end;

end.
