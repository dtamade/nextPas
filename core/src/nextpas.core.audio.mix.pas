unit nextpas.core.audio.mix;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.pcm;

type
  TPointF = record X, Y: Single; end;

procedure MixInto(var ADst: TAudioBuffer; const ASrc: TAudioBuffer; AGain: Single; AOffset: Integer);
procedure ApplyGain(var ABuf: TAudioBuffer; AGain: Single);
procedure ApplyGainRamp(var ABuf: TAudioBuffer; AStartGain, AEndGain: Single);
function NormalizePeak(var ABuf: TAudioBuffer; ATarget: Single): Single;
function NormalizeRMS(var ABuf: TAudioBuffer; ATarget: Single): Single;
function PanLawGains(APan: Single; ALawDB: Single = -3.0): TPointF;

implementation

uses Math;

procedure EnsureF32(var ABuf: TAudioBuffer);
var LNew: TBytes; LExpected: Integer;
begin
  if not ABuf.Format.IsValid then raise EInvalidArgument.Create('audio.mix: invalid format');
  if ABuf.Format.SampleFormat = sfF32 then
  begin
    if ABuf.FrameCount < 0 then raise EInvalidArgument.Create('audio.mix: negative FrameCount');
    LExpected := ABuf.FrameCount * ABuf.Format.BlockAlign;
    if Length(ABuf.Data) < LExpected then raise EInvalidArgument.Create('audio.mix: data too small');
    Exit;
  end;
  if ABuf.FrameCount < 0 then raise EInvalidArgument.Create('audio.mix: negative FrameCount');
  LExpected := ABuf.FrameCount * ABuf.Format.BlockAlign;
  if Length(ABuf.Data) < LExpected then raise EInvalidArgument.Create('audio.mix: data too small for source format');
  if ABuf.FrameCount = 0 then begin ABuf.Format.SampleFormat := sfF32; SetLength(ABuf.Data, 0); Exit; end;
  LNew := PcmConvert(ABuf.Data, ABuf.Format.SampleFormat, sfF32, ABuf.FrameCount, ABuf.Format.Channels, False);
  ABuf.Data := LNew; ABuf.Format.SampleFormat := sfF32;
end;

procedure MixInto(var ADst: TAudioBuffer; const ASrc: TAudioBuffer; AGain: Single; AOffset: Integer);
var
  LSrcF32, LSrcData: TBytes;
  LDstPtr, LSrcPtr: PSingle;
  LSamples, LDstOffset, LI: Integer;
begin
  if not ADst.Format.IsValid then raise EInvalidArgument.Create('MixInto: dst invalid format');
  if ADst.Format.SampleFormat <> sfF32 then raise EInvalidArgument.Create('MixInto: dst must be sfF32');
  if ADst.FrameCount < 0 then raise EInvalidArgument.Create('MixInto: dst negative FrameCount');
  if Length(ADst.Data) < ADst.FrameCount * ADst.Format.BlockAlign then raise EInvalidArgument.Create('MixInto: dst data too small');
  if not ASrc.Format.IsValid then raise EInvalidArgument.Create('MixInto: src invalid format');
  if (ASrc.Format.SampleRate <> ADst.Format.SampleRate) or (ASrc.Format.Channels <> ADst.Format.Channels) then
    raise EInvalidArgument.Create('MixInto: rate/channels mismatch');
  if AOffset < 0 then raise EInvalidArgument.Create('MixInto: negative offset');
  if ASrc.FrameCount < 0 then raise EInvalidArgument.Create('MixInto: src negative FrameCount');
  if AOffset + ASrc.FrameCount > ADst.FrameCount then raise EInvalidArgument.Create('MixInto: dst too small for offset+src');
  if ASrc.FrameCount = 0 then Exit;
  if ASrc.Format.SampleFormat <> sfF32 then
  begin
    if Length(ASrc.Data) < ASrc.FrameCount * ASrc.Format.BlockAlign then raise EInvalidArgument.Create('MixInto: src data too small');
    LSrcF32 := PcmConvert(ASrc.Data, ASrc.Format.SampleFormat, sfF32, ASrc.FrameCount, ASrc.Format.Channels, False);
    LSrcData := LSrcF32;
  end
  else
  begin
    if Length(ASrc.Data) < ASrc.FrameCount * ASrc.Format.BlockAlign then raise EInvalidArgument.Create('MixInto: src data too small');
    LSrcData := ASrc.Data;
  end;
  LSamples := ASrc.FrameCount * ASrc.Format.Channels;
  LDstOffset := AOffset * ADst.Format.Channels;
  if LSamples = 0 then Exit;
  if Length(LSrcData) < LSamples * SizeOf(Single) then raise EInvalidArgument.Create('MixInto: src F32 data too small');
  if Length(ADst.Data) < (LDstOffset + LSamples) * SizeOf(Single) then raise EInvalidArgument.Create('MixInto: dst F32 data too small');
  // 性能：增益门控 + 快路径（gain≈0 跳过，gain≈1 省乘法），稳态热路径内联
  if Abs(AGain) < 1e-6 then Exit;
  LDstPtr := PSingle(@ADst.Data[0]); LSrcPtr := PSingle(@LSrcData[0]);
  if Abs(AGain - 1.0) < 1e-6 then
  begin
    for LI := 0 to LSamples - 1 do
      LDstPtr[LDstOffset + LI] := LDstPtr[LDstOffset + LI] + LSrcPtr[LI];
  end
  else
  begin
    for LI := 0 to LSamples - 1 do
      LDstPtr[LDstOffset + LI] := LDstPtr[LDstOffset + LI] + LSrcPtr[LI] * AGain;
  end;
end;

procedure ApplyGain(var ABuf: TAudioBuffer; AGain: Single);
var NSamples, LI: Integer; P: PSingle;
begin
  EnsureF32(ABuf); NSamples := ABuf.FrameCount * ABuf.Format.Channels;
  if NSamples <= 0 then Exit;
  if Abs(AGain - 1.0) < 1e-6 then Exit;
  if Abs(AGain) < 1e-6 then
  begin
    if Length(ABuf.Data) < NSamples * SizeOf(Single) then raise EInvalidArgument.Create('ApplyGain: data too small');
    FillChar(ABuf.Data[0], NSamples * SizeOf(Single), 0);
    Exit;
  end;
  if Length(ABuf.Data) < NSamples * SizeOf(Single) then raise EInvalidArgument.Create('ApplyGain: data too small');
  P := PSingle(@ABuf.Data[0]);
  for LI := 0 to NSamples - 1 do P[LI] := P[LI] * AGain;
end;

procedure ApplyGainRamp(var ABuf: TAudioBuffer; AStartGain, AEndGain: Single);
var NSamples, LI: Integer; P: PSingle; LDelta, LDenom, LGain: Single;
begin
  EnsureF32(ABuf); NSamples := ABuf.FrameCount * ABuf.Format.Channels;
  if NSamples <= 0 then Exit;
  if Length(ABuf.Data) < NSamples * SizeOf(Single) then raise EInvalidArgument.Create('ApplyGainRamp: data too small');
  P := PSingle(@ABuf.Data[0]);
  if NSamples = 1 then begin P[0] := P[0] * AStartGain; Exit; end;
  LDelta := AEndGain - AStartGain; LDenom := NSamples - 1;
  for LI := 0 to NSamples - 1 do begin LGain := AStartGain + LDelta * (LI / LDenom); P[LI] := P[LI] * LGain; end;
end;

function NormalizePeak(var ABuf: TAudioBuffer; ATarget: Single): Single;
var NSamples, LI: Integer; P: PSingle; LPeak, LAbs, LGain: Single;
begin
  EnsureF32(ABuf); NSamples := ABuf.FrameCount * ABuf.Format.Channels;
  if NSamples <= 0 then Exit(0);
  if Length(ABuf.Data) < NSamples * SizeOf(Single) then raise EInvalidArgument.Create('NormalizePeak: data too small');
  P := PSingle(@ABuf.Data[0]); LPeak := 0;
  for LI := 0 to NSamples - 1 do begin LAbs := P[LI]; if LAbs < 0 then LAbs := -LAbs; if LAbs > LPeak then LPeak := LAbs; end;
  Result := LPeak;
  if LPeak = 0 then LGain := 1 else LGain := ATarget / LPeak;
  ApplyGain(ABuf, LGain);
end;

function NormalizeRMS(var ABuf: TAudioBuffer; ATarget: Single): Single;
var NSamples, LI: Integer; P: PSingle; LSum: Double; LRms, LGain: Single;
begin
  EnsureF32(ABuf); NSamples := ABuf.FrameCount * ABuf.Format.Channels;
  if NSamples <= 0 then Exit(0);
  if Length(ABuf.Data) < NSamples * SizeOf(Single) then raise EInvalidArgument.Create('NormalizeRMS: data too small');
  P := PSingle(@ABuf.Data[0]); LSum := 0;
  for LI := 0 to NSamples - 1 do LSum := LSum + P[LI] * P[LI];
  LRms := Single(Sqrt(LSum / NSamples)); Result := LRms;
  if LRms = 0 then LGain := 1 else LGain := ATarget / LRms;
  ApplyGain(ABuf, LGain);
end;

function PanLawGains(APan: Single; ALawDB: Single = -3.0): TPointF;
var LPan, LAngle: Single;
begin
  LPan := APan; if LPan < -1 then LPan := -1 else if LPan > 1 then LPan := 1;
  if Abs(ALawDB + 6.0) < 0.001 then begin Result.X := (1 - LPan) * 0.5; Result.Y := (1 + LPan) * 0.5; end
  else begin LAngle := (LPan + 1) * Pi / 4.0; Result.X := Cos(LAngle); Result.Y := Sin(LAngle); end;
end;

end.
