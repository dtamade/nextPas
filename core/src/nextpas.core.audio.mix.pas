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

uses Math, nextpas.core.audio.simd;

procedure EnsureF32(var ABuf: TAudioBuffer);
var LNew: TBytes;
begin
  AudioValidateBuffer(ABuf, 'audio.mix');
  if ABuf.Format.SampleFormat = sfF32 then Exit;
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
  AudioValidateBuffer(ADst, 'MixInto: dst', True);
  AudioValidateBuffer(ASrc, 'MixInto: src');
  if (ASrc.Format.SampleRate <> ADst.Format.SampleRate) or (ASrc.Format.Channels <> ADst.Format.Channels) then
    raise EInvalidArgument.Create('MixInto: rate/channels mismatch');
  if AOffset < 0 then raise EInvalidArgument.Create('MixInto: negative offset');
  if AOffset + ASrc.FrameCount > ADst.FrameCount then raise EInvalidArgument.Create('MixInto: dst too small for offset+src');
  if ASrc.FrameCount = 0 then Exit;
  if ASrc.Format.SampleFormat <> sfF32 then
  begin
    LSrcF32 := PcmConvert(ASrc.Data, ASrc.Format.SampleFormat, sfF32, ASrc.FrameCount, ASrc.Format.Channels, False);
    LSrcData := LSrcF32;
  end
  else
    LSrcData := ASrc.Data;
  LSamples := ASrc.FrameCount * ASrc.Format.Channels;
  LDstOffset := AOffset * ADst.Format.Channels;
  if LSamples = 0 then Exit;
  if Length(LSrcData) < LSamples * SizeOf(Single) then raise EInvalidArgument.Create('MixInto: src F32 data too small');
  if Length(ADst.Data) < (LDstOffset + LSamples) * SizeOf(Single) then raise EInvalidArgument.Create('MixInto: dst F32 data too small');
  LDstPtr := PSingle(@ADst.Data[0]); LSrcPtr := PSingle(@LSrcData[0]);
  SimdAddF32(LSrcPtr, @LDstPtr[LDstOffset], LSamples, AGain);
end;

procedure ApplyGain(var ABuf: TAudioBuffer; AGain: Single);
var NSamples: Integer; P: PSingle;
begin
  EnsureF32(ABuf); NSamples := ABuf.FrameCount * ABuf.Format.Channels;
  if NSamples <= 0 then Exit;
  if Length(ABuf.Data) < NSamples * SizeOf(Single) then raise EInvalidArgument.Create('ApplyGain: data too small');
  P := PSingle(@ABuf.Data[0]);
  SimdMulF32(P, P, NSamples, AGain);
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
var NSamples: Integer; P: PSingle; LPeak, LGain: Single;
begin
  EnsureF32(ABuf); NSamples := ABuf.FrameCount * ABuf.Format.Channels;
  if NSamples <= 0 then Exit(0);
  if Length(ABuf.Data) < NSamples * SizeOf(Single) then raise EInvalidArgument.Create('NormalizePeak: data too small');
  P := PSingle(@ABuf.Data[0]); LPeak := SimdPeakF32(P, NSamples);
  Result := LPeak;
  if LPeak = 0 then LGain := 1 else LGain := ATarget / LPeak;
  ApplyGain(ABuf, LGain);
end;

function NormalizeRMS(var ABuf: TAudioBuffer; ATarget: Single): Single;
var NSamples: Integer; P: PSingle; LSum: Double; LRms, LGain: Single;
begin
  EnsureF32(ABuf); NSamples := ABuf.FrameCount * ABuf.Format.Channels;
  if NSamples <= 0 then Exit(0);
  if Length(ABuf.Data) < NSamples * SizeOf(Single) then raise EInvalidArgument.Create('NormalizeRMS: data too small');
  P := PSingle(@ABuf.Data[0]); LSum := SimdSumSquaresF32(P, NSamples);
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
