unit nextpas.core.audio.resample.sinc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  TResampleQuality = (rsDraft, rsGood, rsBest);

  TSincResampler = class(TInterfacedObject, IAudioResampler)
  private
    FQuality: TResampleQuality;
    FTaps: Integer;
    FBeta: Double;
    function BesselI0(AX: Double): Double;
    function KaiserWindow(AIdx: Integer): Double;
    function Sinc(AX: Double): Double; inline;
  public
    constructor Create(AQuality: TResampleQuality = rsGood);
    function Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
    function LatencyFrames: Integer;
  end;

function CreateSincResampler(AQuality: TResampleQuality = rsGood): IAudioResampler;

implementation

uses
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig,
  nextpas.core.audio.pcm,
  nextpas.core.audio.errors;

constructor TSincResampler.Create(AQuality: TResampleQuality);
begin
  inherited Create;
  FQuality := AQuality;
  case AQuality of
    rsDraft: begin FTaps := 16; FBeta := 6.0; end;
    rsGood:  begin FTaps := 64; FBeta := 8.0; end;
    rsBest:  begin FTaps := 128; FBeta := 10.0; end;
  end;
  if (FTaps and 1) <> 0 then Inc(FTaps);
end;

function TSincResampler.LatencyFrames: Integer;
begin
  Result := FTaps div 2;
end;

function TSincResampler.BesselI0(AX: Double): Double;
var
  D, DS, S: Double;
  K: Integer;
begin
  // Abramowitz & Stegun 9.8.1 series: I0(x)= sum (x/2)^{2k}/(k!^2)
  // Converges quickly for x<=10 (our beta<=10). Use 25 terms.
  S := 1.0;
  D := 1.0;
  DS := 1.0;
  for K := 1 to 25 do
  begin
    DS := DS * (AX * AX) / (4.0 * K * K);
    S := S + DS;
    if DS < 1e-14 * S then Break;
  end;
  Result := S;
end;

function TSincResampler.KaiserWindow(AIdx: Integer): Double;
var
  R, Arg, Num, Den: Double;
begin
  // w[n] = I0(beta * sqrt(1 - (2n/(N-1)-1)^2)) / I0(beta)
  if FTaps <= 1 then Exit(1.0);
  R := (2.0 * AIdx / (FTaps - 1) - 1.0);
  R := 1.0 - R * R;
  if R < 0 then R := 0;
  R := Sqrt(R);
  Arg := FBeta * R;
  Num := BesselI0(Arg);
  Den := BesselI0(FBeta);
  if Den = 0 then Exit(0);
  Result := Num / Den;
end;

function TSincResampler.Sinc(AX: Double): Double;
begin
  if Abs(AX) < 1e-12 then Exit(1.0);
  Result := Sin(PI_VALUE * AX) / (PI_VALUE * AX);
end;

function TSincResampler.Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
var
  LRatio: Double;
  LOutFrames: Integer;
  LCh, LOutFrame, LTap, LSrcIdx: Integer;
  LSrcPos, LX, LW, LSum, LWsum: Double;
  LInF32: array of Single;
  LPlanesIn, LPlanesOut: TAudioPlaneArray;
  I, LBlock: Integer;
begin
  if (ANewRate < MinAudioSampleRate) or (ANewRate > MaxAudioSampleRate) then
    raise EInvalidArgument.CreateFmt('SincResample: rate %d out of range', [ANewRate]);
  if not AInput.Format.IsValid then
    raise EAudioError.Create('SincResample: invalid input format');
  if AInput.IsEmpty then
  begin
    Result.Format := AudioFormatCreate(ANewRate, AInput.Format.Channels, sfF32);
    Result.Format.ChannelMask := AInput.Format.ChannelMask;
    Result.Format.ChannelLayout := AInput.Format.ChannelLayout;
    Result.FrameCount := 0;
    Result.Data := nil;
    Exit;
  end;
  LRatio := AInput.Format.SampleRate / ANewRate;
  // Int64 guard for Frame*Rate overflow (INV-8)
  if Int64(AInput.FrameCount) * Int64(ANewRate) > Int64(High(Integer)) * Int64(AInput.Format.SampleRate) then
    LOutFrames := High(Integer)
  else
    LOutFrames := Integer(Int64(AInput.FrameCount) * Int64(ANewRate) div Int64(AInput.Format.SampleRate));
  if LOutFrames < 0 then LOutFrames := 0;
  Result.Format := AudioFormatCreate(ANewRate, AInput.Format.Channels, sfF32);
  Result.Format.ChannelMask := AInput.Format.ChannelMask;
  Result.Format.ChannelLayout := AInput.Format.ChannelLayout;
  Result.FrameCount := LOutFrames;
  // output buffer guard: 16MiB limit (INV-8 style)
  if Int64(LOutFrames) * Int64(Result.Format.BlockAlign) > 16*1024*1024 then
    raise EInvalidArgument.CreateFmt('SincResample: output %d bytes exceeds 16MiB limit', [Int64(LOutFrames) * Int64(Result.Format.BlockAlign)]);
  SetLength(Result.Data, LOutFrames * Result.Format.BlockAlign);
  if LOutFrames = 0 then Exit;

  SetLength(LInF32, AInput.FrameCount * AInput.Format.Channels);
  if AInput.Format.SampleFormat = sfF32 then
    Move(AInput.Data[0], LInF32[0], Length(AInput.Data))
  else
  begin
    for I := 0 to AInput.FrameCount * AInput.Format.Channels - 1 do
    begin
      case AInput.Format.SampleFormat of
        sfS16: PSingle(@LInF32[I])^ := PcmS16ToF32(PSmallInt(@AInput.Data[I * 2])^);
        sfS32: PSingle(@LInF32[I])^ := PcmS32ToF32(PLongInt(@AInput.Data[I * 4])^);
        sfU8:  PSingle(@LInF32[I])^ := PcmU8ToF32(AInput.Data[I]);
        sfS24: PSingle(@LInF32[I])^ := PcmS24ToF32(PcmReadS24LE(AInput.Data, I * 3));
      else
        LInF32[I] := 0;
      end;
    end;
  end;

  SetLength(LPlanesIn, AInput.Format.Channels);
  SetLength(LPlanesOut, AInput.Format.Channels);
  for LCh := 0 to AInput.Format.Channels - 1 do
  begin
    SetLength(LPlanesIn[LCh], AInput.FrameCount * SizeOf(Single));
    for I := 0 to AInput.FrameCount - 1 do
      PSingle(@LPlanesIn[LCh][I * SizeOf(Single)])^ := LInF32[I * AInput.Format.Channels + LCh];
  end;
  for LCh := 0 to AInput.Format.Channels - 1 do
    SetLength(LPlanesOut[LCh], LOutFrames * SizeOf(Single));

  for LCh := 0 to AInput.Format.Channels - 1 do
    for LOutFrame := 0 to LOutFrames - 1 do
    begin
      LSrcPos := LOutFrame * LRatio;
      LSum := 0; LWsum := 0;
      for LTap := 0 to FTaps - 1 do
      begin
        LSrcIdx := Trunc(LSrcPos) - FTaps div 2 + LTap + 1;
        if (LSrcIdx < 0) or (LSrcIdx >= AInput.FrameCount) then Continue;
        LX := LTap - FTaps / 2 - (LSrcPos - Trunc(LSrcPos)) + 0.5;
        LW := Sinc(LX) * KaiserWindow(LTap);
        LSum := LSum + PSingle(@LPlanesIn[LCh][LSrcIdx * SizeOf(Single)])^ * LW;
        LWsum := LWsum + LW;
      end;
      if LWsum <> 0 then LSum := LSum / LWsum;
      if LSum > 1 then LSum := 1 else if LSum < -1 then LSum := -1;
      PSingle(@LPlanesOut[LCh][LOutFrame * SizeOf(Single)])^ := Single(LSum);
    end;

  for I := 0 to LOutFrames - 1 do
    for LCh := 0 to AInput.Format.Channels - 1 do
      PSingle(@Result.Data[(I * AInput.Format.Channels + LCh) * SizeOf(Single)])^ :=
        PSingle(@LPlanesOut[LCh][I * SizeOf(Single)])^;
end;

function CreateSincResampler(AQuality: TResampleQuality): IAudioResampler;
begin
  Result := TSincResampler.Create(AQuality);
end;

end.
