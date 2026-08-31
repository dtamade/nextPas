unit nextpas.core.audio.mix;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.pcm;

type
  TPointF = record X, Y: Single; end;
  TAudioPanGains = TPointF;

procedure MixInto(var ADst: TAudioBuffer; const ASrc: TAudioBuffer; AGain: Single; AOffset: Integer);
procedure ApplyGain(var ABuf: TAudioBuffer; AGain: Single);
procedure ApplyGainRamp(var ABuf: TAudioBuffer; AStartGain, AEndGain: Single);
function NormalizePeak(var ABuf: TAudioBuffer; ATarget: Single): Single;
function NormalizeRMS(var ABuf: TAudioBuffer; ATarget: Single): Single;
function PanLawGains(APan: Single): TPointF; overload;
function PanLawGains(APan: Single; ALawDB: Single): TPointF; overload; deprecated 'PanLaw fixed to -3dB equal-power; prefer single-arg overload';

implementation

uses
  nextpas.core.math.base,
  nextpas.core.math.trig;

procedure EnsureF32(var ABuf: TAudioBuffer);
var LNew: TBytes; LExpected: Int64;
begin
  if not ABuf.Format.IsValid then raise EInvalidArgument.Create('audio.mix: invalid format');
  if ABuf.Format.SampleFormat = sfF32 then
  begin
    if ABuf.FrameCount < 0 then raise EInvalidArgument.Create('audio.mix: negative FrameCount');
    LExpected := Int64(ABuf.FrameCount) * Int64(ABuf.Format.BlockAlign);
    if Int64(Length(ABuf.Data)) < LExpected then raise EInvalidArgument.Create('audio.mix: data too small');
    Exit;
  end;
  if ABuf.FrameCount < 0 then raise EInvalidArgument.Create('audio.mix: negative FrameCount');
  LExpected := Int64(ABuf.FrameCount) * Int64(ABuf.Format.BlockAlign);
  if Int64(Length(ABuf.Data)) < LExpected then raise EInvalidArgument.Create('audio.mix: data too small for source format');
  if ABuf.FrameCount = 0 then begin ABuf.Format.SampleFormat := sfF32; SetLength(ABuf.Data, 0); Exit; end;
  LNew := PcmConvert(ABuf.Data, ABuf.Format.SampleFormat, sfF32, ABuf.FrameCount, ABuf.Format.Channels, False);
  ABuf.Data := LNew; ABuf.Format.SampleFormat := sfF32;
end;

procedure MixInto(var ADst: TAudioBuffer; const ASrc: TAudioBuffer; AGain: Single; AOffset: Integer);
var
  LSrcF32, LSrcData: TBytes;
  LDstPtr, LSrcPtr: PSingle;
  LSamples, LDstOffset, LI: Integer;
  LExpected: Int64;
  LStack: array[0..4095] of Single;
  LUseStack: Boolean;
  LAlias: Boolean;
  LBytesPerSample: Integer;
begin
  if not ADst.Format.IsValid then raise EInvalidArgument.Create('MixInto: dst invalid format');
  if ADst.Format.SampleFormat <> sfF32 then raise EInvalidArgument.Create('MixInto: dst must be sfF32');
  if ADst.FrameCount < 0 then raise EInvalidArgument.Create('MixInto: dst negative FrameCount');
  LExpected := Int64(ADst.FrameCount) * Int64(ADst.Format.BlockAlign);
  if Int64(Length(ADst.Data)) < LExpected then raise EInvalidArgument.Create('MixInto: dst data too small');
  if not ASrc.Format.IsValid then raise EInvalidArgument.Create('MixInto: src invalid format');
  if (ASrc.Format.SampleRate <> ADst.Format.SampleRate) or (ASrc.Format.Channels <> ADst.Format.Channels) then
    raise EInvalidArgument.Create('MixInto: rate/channels mismatch');
  if AOffset < 0 then raise EInvalidArgument.Create('MixInto: negative offset');
  if ASrc.FrameCount < 0 then raise EInvalidArgument.Create('MixInto: src negative FrameCount');
  if Int64(AOffset) + Int64(ASrc.FrameCount) > Int64(ADst.FrameCount) then raise EInvalidArgument.Create('MixInto: dst too small for offset+src');
  if ASrc.FrameCount = 0 then Exit;
  // F-05 Int64 check for src data size
  LExpected := Int64(ASrc.FrameCount) * Int64(ASrc.Format.BlockAlign);
  if Int64(Length(ASrc.Data)) < LExpected then raise EInvalidArgument.Create('MixInto: src data too small');
  // sample count Int64 guard
  LExpected := Int64(ASrc.FrameCount) * Int64(ASrc.Format.Channels);
  if LExpected > High(Integer) then raise EInvalidArgument.Create('MixInto: too many samples');
  LSamples := Integer(LExpected);
  LExpected := Int64(AOffset) * Int64(ADst.Format.Channels);
  if LExpected > High(Integer) then raise EInvalidArgument.Create('MixInto: offset overflow');
  LDstOffset := Integer(LExpected);
  if LSamples = 0 then Exit;
  LUseStack := LSamples <= Length(LStack);
  // F-36 alias detection (same backing store)
  LAlias := (ASrc.Format.SampleFormat = sfF32) and (Pointer(ADst.Data) = Pointer(ASrc.Data)) and (Length(ADst.Data) > 0);
  if ASrc.Format.SampleFormat <> sfF32 then
  begin
    LBytesPerSample := AudioBytesPerSample(ASrc.Format.SampleFormat);
    if LUseStack then
    begin
      // stack scratch conversion (F-30 small-block reuse)
      for LI := 0 to LSamples - 1 do
      begin
        case ASrc.Format.SampleFormat of
          sfU8: LStack[LI] := PcmU8ToF32(ASrc.Data[LI * LBytesPerSample]);
          sfS16: LStack[LI] := PcmS16ToF32(SmallInt(Word(ASrc.Data[LI*2]) or (Word(ASrc.Data[LI*2+1]) shl 8)));
          sfS24: LStack[LI] := PcmS24ToF32(PcmReadS24LE(ASrc.Data, LI*3));
          sfS32: LStack[LI] := PcmS32ToF32(LongInt(DWord(ASrc.Data[LI*4]) or (DWord(ASrc.Data[LI*4+1]) shl 8) or (DWord(ASrc.Data[LI*4+2]) shl 16) or (DWord(ASrc.Data[LI*4+3]) shl 24)));
        else
          LStack[LI] := 0;
        end;
      end;
      LSrcPtr := @LStack[0];
      LSrcData := nil;
    end
    else
    begin
      LSrcF32 := PcmConvert(ASrc.Data, ASrc.Format.SampleFormat, sfF32, ASrc.FrameCount, ASrc.Format.Channels, False);
      LSrcData := LSrcF32;
      LSrcPtr := PSingle(@LSrcData[0]);
    end;
  end
  else
  begin
    if LAlias then
    begin
      // F-36 overlapping alias: copy to temp to avoid read-after-write hazard
      if LUseStack then
      begin
        Move(ASrc.Data[0], LStack[0], LSamples * SizeOf(Single));
        LSrcPtr := @LStack[0];
        LSrcData := nil;
      end
      else
      begin
        SetLength(LSrcF32, LSamples * SizeOf(Single));
        Move(ASrc.Data[0], LSrcF32[0], LSamples * SizeOf(Single));
        LSrcData := LSrcF32;
        LSrcPtr := PSingle(@LSrcData[0]);
      end;
    end
    else
    begin
      LSrcData := ASrc.Data;
      LSrcPtr := PSingle(@LSrcData[0]);
    end;
  end;
  if Assigned(LSrcData) and (Int64(Length(LSrcData)) < Int64(LSamples) * SizeOf(Single)) then raise EInvalidArgument.Create('MixInto: src F32 data too small');
  if not LUseStack or (ASrc.Format.SampleFormat = sfF32) and LAlias then
  begin
    // already have LSrcPtr for heap/alias path
  end
  else if ASrc.Format.SampleFormat <> sfF32 then
  begin
    // LSrcPtr already set for stack path
  end
  else
    LSrcPtr := PSingle(@LSrcData[0]);
  if Int64(Length(ADst.Data)) < Int64(LDstOffset + LSamples) * SizeOf(Single) then raise EInvalidArgument.Create('MixInto: dst F32 data too small');
  LDstPtr := PSingle(@ADst.Data[0]);
  // re-ensure LSrcPtr valid for stack paths
  if (ASrc.Format.SampleFormat <> sfF32) and LUseStack then LSrcPtr := @LStack[0];
  if LAlias and LUseStack then LSrcPtr := @LStack[0];
  for LI := 0 to LSamples - 1 do
    LDstPtr[LDstOffset + LI] := LDstPtr[LDstOffset + LI] + LSrcPtr[LI] * AGain;
end;

procedure ApplyGain(var ABuf: TAudioBuffer; AGain: Single);
var NSamples, LI: Integer; P: PSingle;
begin
  EnsureF32(ABuf); NSamples := ABuf.FrameCount * ABuf.Format.Channels;
  if NSamples <= 0 then Exit;
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

function PanLawGains(APan: Single): TPointF;
var LPan, LAngle: Single;
begin
  LPan := APan; if LPan < -1 then LPan := -1 else if LPan > 1 then LPan := 1 else LPan := APan;
  LAngle := (LPan + 1) * PI_VALUE / 4.0;
  Result.X := Cos(LAngle);
  Result.Y := Sin(LAngle);
end;

function PanLawGains(APan: Single; ALawDB: Single): TPointF;
var LPan, LAngle: Single;
begin
  LPan := APan; if LPan < -1 then LPan := -1 else if LPan > 1 then LPan := 1 else LPan := APan;
  if Abs(ALawDB + 6.0) < 0.001 then
  begin
    Result.X := (1 - LPan) * 0.5;
    Result.Y := (1 + LPan) * 0.5;
  end
  else
  begin
    LAngle := (LPan + 1) * PI_VALUE / 4.0;
    Result.X := Cos(LAngle);
    Result.Y := Sin(LAngle);
  end;
end;

end.
