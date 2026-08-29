unit nextpas.core.audio.pcm;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base;

{ ---- Clamp ---- }

function PcmClampF32(AValue: Single): Single; inline;
function PcmClampS16(AValue: Integer): SmallInt; inline;
function PcmClampS32(AValue: Int64): LongInt; inline;

{ ---- Per-sample format conversion (scalar, simd 加速留 PR5) ---- }

function PcmU8ToF32(AValue: Byte): Single; inline;
function PcmF32ToU8(AValue: Single): Byte; inline;
function PcmF32ToU8Dithered(AValue: Single; var AState: UInt32): Byte; inline;

function PcmS16ToF32(AValue: SmallInt): Single; inline;
function PcmF32ToS16(AValue: Single): SmallInt; inline;
function PcmF32ToS16Dithered(AValue: Single; var AState: UInt32): SmallInt; inline;

function PcmS24ToF32(AValue: Integer): Single; inline;
function PcmF32ToS24(AValue: Single): Integer; inline;
function PcmF32ToS24Dithered(AValue: Single; var AState: UInt32): Integer; inline;

function PcmS32ToF32(AValue: LongInt): Single; inline;
function PcmF32ToS32(AValue: Single): LongInt; inline;

{ 24-bit packed LE helpers (3 bytes) }
function PcmReadS16LE(const ABytes: TBytes; AOffset: Integer): SmallInt; inline;
procedure PcmWriteS16LE(AValue: SmallInt; var ABytes: TBytes; AOffset: Integer); inline;
function PcmReadS32LE(const ABytes: TBytes; AOffset: Integer): LongInt; inline;
procedure PcmWriteS32LE(AValue: LongInt; var ABytes: TBytes; AOffset: Integer); inline;
function PcmReadS24LE(const ABytes: TBytes; AOffset: Integer): Integer; inline;
procedure PcmWriteS24LE(AValue: Integer; var ABytes: TBytes; AOffset: Integer); inline;

{ ---- Bulk conversion via F32 intermediate ---- }

function PcmConvert(const ASrc: TBytes; ASrcFormat, ADstFormat: TAudioSampleFormat;
  AFrames, AChannels: Integer; AApplyDither: Boolean): TBytes;

type
  TAudioPlaneArray = array of TBytes;

{ ---- Interleave / Deinterleave (interleaved <-> planar) ---- }

procedure PcmInterleave(const APlanes: array of TBytes; AFrames, AChannels: Integer;
  ABytesPerSample: Integer; out ADst: TBytes);
procedure PcmDeinterleave(const AInterleaved: TBytes; AFrames, AChannels: Integer;
  ABytesPerSample: Integer; out APlanes: TAudioPlaneArray);

{ ---- Memory-source realtime helper (re-export from base: single truth) ---- }
function AudioFillMemoryRealtime(const ASrc: TAudioBuffer; var APos: Integer;
  var ABuffer: TAudioBuffer; AFrames: Integer): Integer; inline;
function AudioSilentFill(var ABuffer: TAudioBuffer; const AFormat: TAudioFormat;
  AFrames: Integer): Integer; inline;

{ ---- TPDF dither noise [-1,1) LSB scaled ---- }
function PcmTpdfNoise(var AState: UInt32): Single; inline;

implementation

{$PUSH}
{$WARNINGS OFF}
{$HINTS OFF}

function PcmClampF32(AValue: Single): Single;
begin
  if AValue < -1.0 then Exit(-1.0);
  if AValue > 1.0 then Exit(1.0);
  Result := AValue;
end;

function PcmClampS16(AValue: Integer): SmallInt;
begin
  if AValue < -32768 then Exit(-32768);
  if AValue > 32767 then Exit(32767);
  Result := SmallInt(AValue);
end;

function PcmClampS32(AValue: Int64): LongInt;
begin
  if AValue < Low(LongInt) then Exit(Low(LongInt));
  if AValue > High(LongInt) then Exit(High(LongInt));
  Result := LongInt(AValue);
end;

function PcmU8ToF32(AValue: Byte): Single;
begin
  Result := (Integer(AValue) - 128) / 128.0;
end;

function PcmF32ToU8(AValue: Single): Byte;
var
  LClamped: Single;
  LScaled: Integer;
begin
  LClamped := PcmClampF32(AValue);
  LScaled := Round(LClamped * 127.0) + 128;
  if LScaled < 0 then LScaled := 0;
  if LScaled > 255 then LScaled := 255;
  Result := Byte(LScaled);
end;

function PcmTpdfNoise(var AState: UInt32): Single;
var
  LR1, LR2: Single;
begin
  { Simple LCG: state = state * 1664525 + 1013904223 }
  AState := AState * 1664525 + 1013904223;
  LR1 := (AState and $FFFFFF) / Single($1000000);
  AState := AState * 1664525 + 1013904223;
  LR2 := (AState and $FFFFFF) / Single($1000000);
  Result := (LR1 - LR2);
end;

function PcmF32ToU8Dithered(AValue: Single; var AState: UInt32): Byte;
var
  LNoise: Single;
begin
  LNoise := PcmTpdfNoise(AState) / 128.0;
  Result := PcmF32ToU8(AValue + LNoise);
end;

function PcmS16ToF32(AValue: SmallInt): Single;
begin
  if AValue = -32768 then
    Result := -1.0
  else
    Result := AValue / 32767.0;
end;

function PcmF32ToS16(AValue: Single): SmallInt;
var
  LClamped: Single;
  LScaled: Integer;
begin
  LClamped := PcmClampF32(AValue);
  if LClamped <= -1.0 then Exit(-32768);
  LScaled := Round(LClamped * 32767.0);
  Result := PcmClampS16(LScaled);
end;

function PcmF32ToS16Dithered(AValue: Single; var AState: UInt32): SmallInt;
var
  LNoise: Single;
begin
  LNoise := PcmTpdfNoise(AState) / 32768.0;
  Result := PcmF32ToS16(AValue + LNoise);
end;

function PcmS24ToF32(AValue: Integer): Single;
var
  LClamped: Integer;
begin
  LClamped := AValue;
  if LClamped > 8388607 then LClamped := 8388607;
  if LClamped < -8388608 then LClamped := -8388608;
  if LClamped = -8388608 then
    Result := -1.0
  else
    Result := LClamped / 8388607.0;
end;

function PcmF32ToS24(AValue: Single): Integer;
var
  LClamped: Single;
begin
  LClamped := PcmClampF32(AValue);
  if LClamped <= -1.0 then Exit(-8388608);
  Result := Round(LClamped * 8388607.0);
  if Result > 8388607 then Result := 8388607;
  if Result < -8388608 then Result := -8388608;
end;

function PcmF32ToS24Dithered(AValue: Single; var AState: UInt32): Integer;
var
  LNoise: Single;
begin
  LNoise := PcmTpdfNoise(AState) / 8388608.0;
  Result := PcmF32ToS24(AValue + LNoise);
end;

function PcmS32ToF32(AValue: LongInt): Single;
begin
  if AValue = Low(LongInt) then
    Result := -1.0
  else
    Result := AValue / 2147483647.0;
end;

function PcmF32ToS32(AValue: Single): LongInt;
var
  LClamped: Single;
  LScaled: Int64;
begin
  LClamped := PcmClampF32(AValue);
  if LClamped <= -1.0 then Exit(Low(LongInt));
  LScaled := Round(LClamped * 2147483647.0);
  Result := PcmClampS32(LScaled);
end;

function PcmReadS16LE(const ABytes: TBytes; AOffset: Integer): SmallInt; inline;
begin
  Result := SmallInt(Word(ABytes[AOffset]) or (Word(ABytes[AOffset+1]) shl 8));
end;

procedure PcmWriteS16LE(AValue: SmallInt; var ABytes: TBytes; AOffset: Integer); inline;
begin
  ABytes[AOffset] := Byte(Word(AValue) and $FF);
  ABytes[AOffset+1] := Byte((Word(AValue) shr 8) and $FF);
end;

function PcmReadS32LE(const ABytes: TBytes; AOffset: Integer): LongInt; inline;
begin
  Result := LongInt(DWord(ABytes[AOffset]) or (DWord(ABytes[AOffset+1]) shl 8) or (DWord(ABytes[AOffset+2]) shl 16) or (DWord(ABytes[AOffset+3]) shl 24));
end;

procedure PcmWriteS32LE(AValue: LongInt; var ABytes: TBytes; AOffset: Integer); inline;
begin
  ABytes[AOffset] := Byte(DWord(AValue) and $FF);
  ABytes[AOffset+1] := Byte((DWord(AValue) shr 8) and $FF);
  ABytes[AOffset+2] := Byte((DWord(AValue) shr 16) and $FF);
  ABytes[AOffset+3] := Byte((DWord(AValue) shr 24) and $FF);
end;

function PcmReadS24LE(const ABytes: TBytes; AOffset: Integer): Integer;
var
  LB0, LB1, LB2: Byte;
begin
  LB0 := ABytes[AOffset];
  LB1 := ABytes[AOffset + 1];
  LB2 := ABytes[AOffset + 2];
  Result := Integer(LB0) or (Integer(LB1) shl 8) or (Integer(LB2) shl 16);
  if (LB2 and $80) <> 0 then
    Result := Result or Integer($FF000000);
end;

procedure PcmWriteS24LE(AValue: Integer; var ABytes: TBytes; AOffset: Integer);
begin
  ABytes[AOffset] := Byte(AValue and $FF);
  ABytes[AOffset + 1] := Byte((AValue shr 8) and $FF);
  ABytes[AOffset + 2] := Byte((AValue shr 16) and $FF);
end;

function PcmConvert(const ASrc: TBytes; ASrcFormat, ADstFormat: TAudioSampleFormat;
  AFrames, AChannels: Integer; AApplyDither: Boolean): TBytes;
var
  LSampleCount: Integer;
  LI: Integer;
  LSrcOffset, LDstOffset: Integer;
  LBytesPerSrc, LBytesPerDst: Integer;
  LF: Single;
  LDitherState: UInt32;
  LU8: Byte;
  LS16: SmallInt;
  LS24: Integer;
  LS32: LongInt;
begin
  Result := nil;
  if (AFrames <= 0) or (AChannels <= 0) then Exit;
  if ASrcFormat = ADstFormat then
  begin
    Result := Copy(ASrc, 0, Length(ASrc));
    Exit;
  end;
  LSampleCount := AFrames * AChannels;
  LBytesPerSrc := AudioBytesPerSample(ASrcFormat);
  LBytesPerDst := AudioBytesPerSample(ADstFormat);
  if LBytesPerSrc <= 0 then Exit;
  if LBytesPerDst <= 0 then Exit;
  if Length(ASrc) < LSampleCount * LBytesPerSrc then Exit;
  SetLength(Result, LSampleCount * LBytesPerDst);
  // fast 4-wide paths for dither-free S16/S32<->F32 (hotest conversions, zero branch)
  if not AApplyDither then
  begin
    if (ASrcFormat=sfS16) and (ADstFormat=sfF32) then
    begin
      LI:=0; while LI+3 < LSampleCount do
      begin
        PSingle(@Result[LI*4])^ := PcmS16ToF32(PcmReadS16LE(ASrc, LI*2));
        PSingle(@Result[(LI+1)*4])^ := PcmS16ToF32(PcmReadS16LE(ASrc, (LI+1)*2));
        PSingle(@Result[(LI+2)*4])^ := PcmS16ToF32(PcmReadS16LE(ASrc, (LI+2)*2));
        PSingle(@Result[(LI+3)*4])^ := PcmS16ToF32(PcmReadS16LE(ASrc, (LI+3)*2));
        Inc(LI,4);
      end;
      while LI < LSampleCount do
      begin PSingle(@Result[LI*4])^:=PcmS16ToF32(PcmReadS16LE(ASrc, LI*2)); Inc(LI); end;
      Exit;
    end;
    if (ASrcFormat=sfF32) and (ADstFormat=sfS16) then
    begin
      LI:=0; while LI+3 < LSampleCount do
      begin
        PcmWriteS16LE(PcmF32ToS16(PSingle(@ASrc[LI*4])^), Result, LI*2);
        PcmWriteS16LE(PcmF32ToS16(PSingle(@ASrc[(LI+1)*4])^), Result, (LI+1)*2);
        PcmWriteS16LE(PcmF32ToS16(PSingle(@ASrc[(LI+2)*4])^), Result, (LI+2)*2);
        PcmWriteS16LE(PcmF32ToS16(PSingle(@ASrc[(LI+3)*4])^), Result, (LI+3)*2);
        Inc(LI,4);
      end;
      while LI < LSampleCount do
      begin PcmWriteS16LE(PcmF32ToS16(PSingle(@ASrc[LI*4])^), Result, LI*2); Inc(LI); end;
      Exit;
    end;
    if (ASrcFormat=sfS32) and (ADstFormat=sfF32) then
    begin
      LI:=0; while LI+3 < LSampleCount do
      begin
        PSingle(@Result[LI*4])^:=PcmS32ToF32(PcmReadS32LE(ASrc, LI*4));
        PSingle(@Result[(LI+1)*4])^:=PcmS32ToF32(PcmReadS32LE(ASrc, (LI+1)*4));
        PSingle(@Result[(LI+2)*4])^:=PcmS32ToF32(PcmReadS32LE(ASrc, (LI+2)*4));
        PSingle(@Result[(LI+3)*4])^:=PcmS32ToF32(PcmReadS32LE(ASrc, (LI+3)*4));
        Inc(LI,4);
      end;
      while LI < LSampleCount do
      begin PSingle(@Result[LI*4])^:=PcmS32ToF32(PcmReadS32LE(ASrc, LI*4)); Inc(LI); end;
      Exit;
    end;
    if (ASrcFormat=sfF32) and (ADstFormat=sfS32) then
    begin
      LI:=0; while LI+3 < LSampleCount do
      begin
        PcmWriteS32LE(PcmF32ToS32(PSingle(@ASrc[LI*4])^), Result, LI*4);
        PcmWriteS32LE(PcmF32ToS32(PSingle(@ASrc[(LI+1)*4])^), Result, (LI+1)*4);
        PcmWriteS32LE(PcmF32ToS32(PSingle(@ASrc[(LI+2)*4])^), Result, (LI+2)*4);
        PcmWriteS32LE(PcmF32ToS32(PSingle(@ASrc[(LI+3)*4])^), Result, (LI+3)*4);
        Inc(LI,4);
      end;
      while LI < LSampleCount do
      begin PcmWriteS32LE(PcmF32ToS32(PSingle(@ASrc[LI*4])^), Result, LI*4); Inc(LI); end;
      Exit;
    end;
  end;
  LDitherState := 12345;
  for LI := 0 to LSampleCount - 1 do
  begin
    LSrcOffset := LI * LBytesPerSrc;
    { Src -> F32 }
    case ASrcFormat of
      sfU8: LF := PcmU8ToF32(ASrc[LSrcOffset]);
      sfS16: LF := PcmS16ToF32(PcmReadS16LE(ASrc, LSrcOffset));
      sfS24: LF := PcmS24ToF32(PcmReadS24LE(ASrc, LSrcOffset));
      sfS32: LF := PcmS32ToF32(PcmReadS32LE(ASrc, LSrcOffset));
      sfF32: Move(ASrc[LSrcOffset], LF, SizeOf(Single));
    else LF := 0;
    end;
    LDstOffset := LI * LBytesPerDst;
    case ADstFormat of
      sfU8: begin if AApplyDither then LU8:=PcmF32ToU8Dithered(LF, LDitherState) else LU8:=PcmF32ToU8(LF); Result[LDstOffset]:=LU8; end;
      sfS16: begin if AApplyDither then LS16:=PcmF32ToS16Dithered(LF, LDitherState) else LS16:=PcmF32ToS16(LF); PcmWriteS16LE(LS16, Result, LDstOffset); end;
      sfS24: begin if AApplyDither then LS24:=PcmF32ToS24Dithered(LF, LDitherState) else LS24:=PcmF32ToS24(LF); PcmWriteS24LE(LS24, Result, LDstOffset); end;
      sfS32: PcmWriteS32LE(PcmF32ToS32(LF), Result, LDstOffset);
      sfF32: Move(LF, Result[LDstOffset], SizeOf(Single));
    end;
  end;
end;

procedure PcmInterleave(const APlanes: array of TBytes; AFrames, AChannels: Integer;
  ABytesPerSample: Integer; out ADst: TBytes);
var
  LFrame, LCh: Integer;
  LSrcOffset, LDstOffset: Integer;
begin
  ADst := nil;
  if (AFrames <= 0) or (AChannels <= 0) or (ABytesPerSample <= 0) then Exit;
  if Length(APlanes) < AChannels then Exit;
  SetLength(ADst, AFrames * AChannels * ABytesPerSample);
  for LFrame := 0 to AFrames - 1 do
    for LCh := 0 to AChannels - 1 do
    begin
      LSrcOffset := LFrame * ABytesPerSample;
      LDstOffset := (LFrame * AChannels + LCh) * ABytesPerSample;
      if (LSrcOffset + ABytesPerSample > Length(APlanes[LCh])) then Continue;
      Move(APlanes[LCh][LSrcOffset], ADst[LDstOffset], ABytesPerSample);
    end;
end;

procedure PcmDeinterleave(const AInterleaved: TBytes; AFrames, AChannels: Integer;
  ABytesPerSample: Integer; out APlanes: TAudioPlaneArray);
var
  LFrame, LCh: Integer;
  LSrcOffset, LDstOffset: Integer;
begin
  APlanes := nil;
  if (AFrames <= 0) or (AChannels <= 0) or (ABytesPerSample <= 0) then Exit;
  SetLength(APlanes, AChannels);
  for LCh := 0 to AChannels - 1 do
    SetLength(APlanes[LCh], AFrames * ABytesPerSample);
  for LFrame := 0 to AFrames - 1 do
    for LCh := 0 to AChannels - 1 do
    begin
      LSrcOffset := (LFrame * AChannels + LCh) * ABytesPerSample;
      LDstOffset := LFrame * ABytesPerSample;
      if (LSrcOffset + ABytesPerSample > Length(AInterleaved)) then Continue;
      Move(AInterleaved[LSrcOffset], APlanes[LCh][LDstOffset], ABytesPerSample);
    end;
end;

function AudioFillMemoryRealtime(const ASrc: TAudioBuffer; var APos: Integer;
  var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin Result:=nextpas.core.audio.base.AudioFillMemoryRealtime(ASrc,APos,ABuffer,AFrames); end;

function AudioSilentFill(var ABuffer: TAudioBuffer; const AFormat: TAudioFormat;
  AFrames: Integer): Integer;
begin Result:=nextpas.core.audio.base.AudioSilentFill(ABuffer,AFormat,AFrames); end;

{$POP}

end.
