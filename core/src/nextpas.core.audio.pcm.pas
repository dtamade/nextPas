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
function PcmReadS24LE(const ABytes: TBytes; AOffset: Integer): Integer; inline;
procedure PcmWriteS24LE(AValue: Integer; var ABytes: TBytes; AOffset: Integer); inline;

{ ---- Bulk conversion via F32 intermediate ---- }

function PcmConvert(const ASrc: TBytes; ASrcFormat, ADstFormat: TAudioSampleFormat;
  AFrames, AChannels: Integer; AApplyDither: Boolean): TBytes;
// caller-scratch variant for async/threadpool safety: caller owns scratch, avoids threadvar sharing across FPC bare pthread
function PcmConvertWithScratch(const ASrc: TBytes; ASrcFormat, ADstFormat: TAudioSampleFormat;
  AFrames, AChannels: Integer; AApplyDither: Boolean; var AScratch: TBytes): TBytes;

type
  TAudioPlaneArray = array of TBytes;

{ ---- Interleave / Deinterleave (interleaved <-> planar) ---- }

procedure PcmInterleave(const APlanes: array of TBytes; AFrames, AChannels: Integer;
  ABytesPerSample: Integer; out ADst: TBytes);
procedure PcmDeinterleave(const AInterleaved: TBytes; AFrames, AChannels: Integer;
  ABytesPerSample: Integer; out APlanes: TAudioPlaneArray);

{ ---- TPDF dither noise [-1,1) LSB scaled ---- }
function PcmTpdfNoise(var AState: UInt32): Single; inline;

implementation

uses
  nextpas.core.bytes.ops, // single source: bytes.ops BytesCopy/SpanCopySlice inline zero-copy — no Move/CopyMem bypass, owns all byte ops
  nextpas.core.audio.pcm.simd; // single source: pcm.simd thin forward to audio.simd SimdConvert* AVX2 8-wide, no duplicate scalar loop

{$PUSH}
{$WARNINGS OFF}
{$HINTS OFF}

threadvar
  GPcmScratch: TBytes;
  // threadvar per-thread scratch — PcmConvert F32 中间缓冲，几何倍增 AudioEnsureCapacity 单源，稳态零分配 (steady zero alloc after warmup)，与 PcmConvertWithScratch 统一经 EnsurePcmScratchUnified，零拷贝纪律一致：PcmConvert 以 threadvar 作为 caller-owned 传入内核，无双轨分叉

procedure EnsurePcmScratchUnified(var AScratch: TBytes; ANeeded: Integer); inline;
var LCap: Integer;
begin
  LCap := Length(AScratch);
  AudioEnsureCapacity(LCap, ANeeded, 256);
  if Length(AScratch) <> LCap then SetLength(AScratch, LCap);
end;

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

function PcmTpdfNoise(var AState: UInt32): Single; inline;
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

function PcmF32ToU8Dithered(AValue: Single; var AState: UInt32): Byte; inline;
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

function PcmF32ToS16Dithered(AValue: Single; var AState: UInt32): SmallInt; inline;
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

function PcmF32ToS24Dithered(AValue: Single; var AState: UInt32): Integer; inline;
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

function PcmReadS24LE(const ABytes: TBytes; AOffset: Integer): Integer;
var
  LB0, LB1, LB2: Byte;
begin
  if (AOffset < 0) or (Length(ABytes) < AOffset + 3) then
    raise EInvalidArgument.CreateFmt('PcmReadS24LE: offset %d out of range [0..%d]', [AOffset, Length(ABytes) - 3]);
  LB0 := ABytes[AOffset];
  LB1 := ABytes[AOffset + 1];
  LB2 := ABytes[AOffset + 2];
  Result := Integer(LB0) or (Integer(LB1) shl 8) or (Integer(LB2) shl 16);
  if (LB2 and $80) <> 0 then
    Result := Result or Integer($FF000000);
end;

procedure PcmWriteS24LE(AValue: Integer; var ABytes: TBytes; AOffset: Integer);
begin
  if (AOffset < 0) or (Length(ABytes) < AOffset + 3) then
    raise EInvalidArgument.CreateFmt('PcmWriteS24LE: offset %d out of range [0..%d]', [AOffset, Length(ABytes) - 3]);
  ABytes[AOffset] := Byte(AValue and $FF);
  ABytes[AOffset + 1] := Byte((AValue shr 8) and $FF);
  ABytes[AOffset + 2] := Byte((AValue shr 16) and $FF);
end;

{ ---- common kernel: single source for PcmConvert / PcmConvertWithScratch ---- }
function PcmConvertKernel(const ASrc: TBytes; ASrcFormat, ADstFormat: TAudioSampleFormat;
  AFrames, AChannels: Integer; AApplyDither: Boolean; var AScratch: TBytes): TBytes; inline;
var
  LSampleCount: Integer;
  LI: Integer;
  LBytesPerSrc, LBytesPerDst: Integer;
  LDitherState: UInt32;
  LDstPtr: PByte;
  LF32: PSingle;
  LU8: Byte;
  LS16: SmallInt;
  LS24: Integer;
  LS32: LongInt;
begin
  Result := nil;
  if (AFrames <= 0) or (AChannels <= 0) then Exit;
  if (Ord(ASrcFormat) < Ord(Low(TAudioSampleFormat))) or (Ord(ASrcFormat) > Ord(High(TAudioSampleFormat))) then
    raise EInvalidArgument.Create('PcmConvert: invalid src format');
  if (Ord(ADstFormat) < Ord(Low(TAudioSampleFormat))) or (Ord(ADstFormat) > Ord(High(TAudioSampleFormat))) then
    raise EInvalidArgument.Create('PcmConvert: invalid dst format');
  LBytesPerSrc := AudioBytesPerSample(ASrcFormat);
  LBytesPerDst := AudioBytesPerSample(ADstFormat);
  if LBytesPerSrc <= 0 then
    raise EInvalidArgument.Create('PcmConvert: unsupported src bytes per sample');
  if LBytesPerDst <= 0 then
    raise EInvalidArgument.Create('PcmConvert: unsupported dst bytes per sample');
  if Int64(AFrames) * Int64(AChannels) > High(Integer) then
    raise EInvalidArgument.Create('PcmConvert: frames*channels overflow');
  if ASrcFormat = ADstFormat then
  begin
    if Int64(Length(ASrc)) < Int64(AFrames) * Int64(AChannels) * Int64(LBytesPerSrc) then
      raise EInvalidArgument.CreateFmt('PcmConvert: src too short %d < %d', [Length(ASrc), Int64(AFrames) * Int64(AChannels) * Int64(LBytesPerSrc)]);
    Result := SpanCopySlice(TByteSpan.FromBytes(ASrc), 0, SizeUInt(Int64(AFrames) * Int64(AChannels) * Int64(LBytesPerSrc)));
    Exit;
  end;
  LSampleCount := AFrames * AChannels;
  if Int64(Length(ASrc)) < Int64(LSampleCount) * Int64(LBytesPerSrc) then
    raise EInvalidArgument.CreateFmt('PcmConvert: src too short %d < %d', [Length(ASrc), Int64(LSampleCount) * Int64(LBytesPerSrc)]);
  if Int64(LSampleCount) * Int64(LBytesPerDst) > 16*1024*1024 then
    raise EInvalidArgument.CreateFmt('PcmConvert: dst %d bytes exceeds 16MiB limit', [Int64(LSampleCount) * Int64(LBytesPerDst)]);
  // perf: EnsureScratchUnified geometric via bytes.ops AudioEnsureCapacity single source, steady zero alloc after warmup, inline zero-copy, unified caller-owned/threadvar discipline
  EnsurePcmScratchUnified(AScratch, LSampleCount * SizeOf(Single));
  LF32 := PSingle(@AScratch[0]);
  // perf: src batch outer-branch, S16/S32 unified via PcmConvertBlock* AVX2 8-wide single source (audio.simd -> simd owner), U8/S24 scalar 3-byte packed scalar tail
  case ASrcFormat of
    sfU8:
      for LI := 0 to LSampleCount - 1 do
        LF32[LI] := PcmU8ToF32(ASrc[LI]);
    sfS16:
      PcmConvertBlockS16ToF32(PSmallInt(@ASrc[0]), LF32, LSampleCount);
    sfS24:
      for LI := 0 to LSampleCount - 1 do
      begin
        LS24 := PcmReadS24LE(ASrc, LI*3);
        LF32[LI] := PcmS24ToF32(LS24);
      end;
    sfS32:
      PcmConvertBlockS32ToF32(PLongInt(@ASrc[0]), LF32, LSampleCount);
    sfF32:
      if LSampleCount > 0 then
        BytesCopy(LF32, @ASrc[0], SizeUInt(LSampleCount) * SizeUInt(SizeOf(Single)));
  else
    for LI := 0 to LSampleCount - 1 do LF32[LI] := 0;
  end;
  SetLength(Result, LSampleCount * LBytesPerDst);
  if LSampleCount * LBytesPerDst = 0 then Exit;
  LDitherState := 12345;
  LDstPtr := PByte(@Result[0]);
  // perf: dst batch outer-branch, S16/S32 non-dither unified via PcmConvertBlockF32* AVX2 8-wide, dither/s24 scalar tail, F32 bulk BytesCopy single source
  case ADstFormat of
    sfU8:
      if AApplyDither then
        for LI := 0 to LSampleCount - 1 do
        begin
          LU8 := PcmF32ToU8Dithered(LF32[LI], LDitherState);
          LDstPtr[LI] := LU8;
        end
      else
        for LI := 0 to LSampleCount - 1 do
          LDstPtr[LI] := PcmF32ToU8(LF32[LI]);
    sfS16:
      if AApplyDither then
        for LI := 0 to LSampleCount - 1 do
        begin
          LS16 := PcmF32ToS16Dithered(LF32[LI], LDitherState);
          LDstPtr[LI*2] := Byte(LS16 and $FF);
          LDstPtr[LI*2 + 1] := Byte((LS16 shr 8) and $FF);
        end
      else
        PcmConvertBlockF32ToS16(LF32, PSmallInt(LDstPtr), LSampleCount);
    sfS24:
      if AApplyDither then
        for LI := 0 to LSampleCount - 1 do
        begin
          LS24 := PcmF32ToS24Dithered(LF32[LI], LDitherState);
          PcmWriteS24LE(LS24, Result, LI*3);
        end
      else
        for LI := 0 to LSampleCount - 1 do
        begin
          LS24 := PcmF32ToS24(LF32[LI]);
          PcmWriteS24LE(LS24, Result, LI*3);
        end;
    sfS32:
      if AApplyDither then
        // S32 dither path not vectorized (no Simd dither), keep scalar
        for LI := 0 to LSampleCount - 1 do
        begin
          LS32 := PcmF32ToS32(LF32[LI]);
          LDstPtr[LI*4] := Byte(LS32 and $FF);
          LDstPtr[LI*4 + 1] := Byte((LS32 shr 8) and $FF);
          LDstPtr[LI*4 + 2] := Byte((LS32 shr 16) and $FF);
          LDstPtr[LI*4 + 3] := Byte((LS32 shr 24) and $FF);
        end
      else
        PcmConvertBlockF32ToS32(LF32, PLongInt(LDstPtr), LSampleCount);
    sfF32:
      if LSampleCount > 0 then
        BytesCopy(LDstPtr, LF32, SizeUInt(LSampleCount) * SizeUInt(SizeOf(Single)));
  end;
end;

function PcmConvert(const ASrc: TBytes; ASrcFormat, ADstFormat: TAudioSampleFormat;
  AFrames, AChannels: Integer; AApplyDither: Boolean): TBytes;
begin
  // unified kernel via threadvar as caller-owned scratch — zero-copy discipline consistent with WithScratch, single source, no duplication
  Result := PcmConvertKernel(ASrc, ASrcFormat, ADstFormat, AFrames, AChannels, AApplyDither, GPcmScratch);
end;

function PcmConvertWithScratch(const ASrc: TBytes; ASrcFormat, ADstFormat: TAudioSampleFormat;
  AFrames, AChannels: Integer; AApplyDither: Boolean; var AScratch: TBytes): TBytes;
begin
  // caller-owned scratch unified kernel — single source, geometric EnsurePcmScratchUnified via bytes.ops, steady zero alloc after warmup, thread-safe
  Result := PcmConvertKernel(ASrc, ASrcFormat, ADstFormat, AFrames, AChannels, AApplyDither, AScratch);
end;

procedure PcmInterleave(const APlanes: array of TBytes; AFrames, AChannels: Integer;
  ABytesPerSample: Integer; out ADst: TBytes);
var
  LCh: Integer;
  LFrame: Integer;
  LBPS, LStride, LN8: Integer;
  LSrc: PByte;
  LDst: PByte;
begin
  ADst := nil;
  if (AFrames <= 0) or (AChannels <= 0) or (ABytesPerSample <= 0) then Exit;
  if Length(APlanes) < AChannels then Exit;
  SetLength(ADst, AFrames * AChannels * ABytesPerSample);
  // perf: mono fast path single bulk BytesCopy (vectorized single Move, zero-copy) avoids per-sample stride
  if (AChannels = 1) and (Length(APlanes[0]) >= AFrames * ABytesPerSample) and (Length(ADst) >= AFrames * ABytesPerSample) and (AFrames * ABytesPerSample > 0) then
  begin
    BytesCopy(@ADst[0], @APlanes[0][0], SizeUInt(AFrames) * SizeUInt(ABytesPerSample));
    Exit;
  end;
  // perf: 8-frame batch Move per plane via bytes.ops single source (inline, zero-copy, vectorized Move), 8× unrolled strided copy reduces per-sample BytesCopy 1-4B call overhead to bulk Move, single source — resample path reuses PcmConvert bulk F32 + this strided copy
  LBPS := ABytesPerSample;
  LStride := AChannels * LBPS;
  for LCh := 0 to AChannels - 1 do
  begin
    if Length(APlanes[LCh]) < AFrames * LBPS then Continue;
    if LBPS <= 0 then Continue;
    LSrc := PByte(@APlanes[LCh][0]);
    LDst := PByte(@ADst[0]);
    Inc(LDst, LCh * LBPS);
    LN8 := AFrames and not 7;
    LFrame := 0;
    while LFrame < LN8 do
    begin
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LSrc, LBPS); Inc(LDst, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LSrc, LBPS); Inc(LDst, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LSrc, LBPS); Inc(LDst, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LSrc, LBPS); Inc(LDst, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LSrc, LBPS); Inc(LDst, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LSrc, LBPS); Inc(LDst, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LSrc, LBPS); Inc(LDst, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LSrc, LBPS); Inc(LDst, LStride);
      Inc(LFrame, 8);
    end;
    while LFrame < AFrames do
    begin
      BytesCopy(LDst, LSrc, SizeUInt(LBPS));
      Inc(LSrc, LBPS);
      Inc(LDst, LStride);
      Inc(LFrame);
    end;
  end;
end;

procedure PcmDeinterleave(const AInterleaved: TBytes; AFrames, AChannels: Integer;
  ABytesPerSample: Integer; out APlanes: TAudioPlaneArray);
var
  LCh: Integer;
  LFrame, LN8: Integer;
  LBPS, LStride: Integer;
  LSrc, LDst: PByte;
begin
  APlanes := nil;
  if (AFrames <= 0) or (AChannels <= 0) or (ABytesPerSample <= 0) then Exit;
  SetLength(APlanes, AChannels);
  for LCh := 0 to AChannels - 1 do
    SetLength(APlanes[LCh], AFrames * ABytesPerSample);
  // perf: mono fast path single bulk BytesCopy (vectorized single Move, zero-copy) avoids per-sample stride
  if (AChannels = 1) and (Length(AInterleaved) >= AFrames * ABytesPerSample) and (Length(APlanes[0]) >= AFrames * ABytesPerSample) and (AFrames * ABytesPerSample > 0) then
  begin
    BytesCopy(@APlanes[0][0], @AInterleaved[0], SizeUInt(AFrames) * SizeUInt(ABytesPerSample));
    Exit;
  end;
  // perf: 8-frame batch Move per plane via bytes.ops single source (inline, zero-copy, vectorized Move), 8× unrolled strided copy, inverse of PcmInterleave, SIMD Move
  LBPS := ABytesPerSample;
  LStride := AChannels * LBPS;
  for LCh := 0 to AChannels - 1 do
  begin
    if LBPS <= 0 then Continue;
    if Length(AInterleaved) < AFrames * AChannels * LBPS then
    begin
      // stability: short interleaved — per-sample bounds check fallback
      for LFrame := 0 to AFrames - 1 do
      begin
        if (LFrame * LStride + LCh * LBPS + LBPS > Length(AInterleaved)) then Continue;
        BytesCopy(@APlanes[LCh][LFrame * LBPS], @AInterleaved[(LFrame * AChannels + LCh) * LBPS], SizeUInt(LBPS));
      end;
      Continue;
    end;
    LSrc := PByte(@AInterleaved[0]);
    Inc(LSrc, LCh * LBPS);
    LDst := PByte(@APlanes[LCh][0]);
    LN8 := AFrames and not 7;
    LFrame := 0;
    while LFrame < LN8 do
    begin
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LDst, LBPS); Inc(LSrc, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LDst, LBPS); Inc(LSrc, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LDst, LBPS); Inc(LSrc, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LDst, LBPS); Inc(LSrc, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LDst, LBPS); Inc(LSrc, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LDst, LBPS); Inc(LSrc, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LDst, LBPS); Inc(LSrc, LStride);
      BytesCopy(LDst, LSrc, SizeUInt(LBPS)); Inc(LDst, LBPS); Inc(LSrc, LStride);
      Inc(LFrame, 8);
    end;
    while LFrame < AFrames do
    begin
      BytesCopy(LDst, LSrc, SizeUInt(LBPS));
      Inc(LDst, LBPS);
      Inc(LSrc, LStride);
      Inc(LFrame);
    end;
  end;
end;

{$POP}

end.
