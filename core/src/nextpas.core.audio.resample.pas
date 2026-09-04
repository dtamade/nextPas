unit nextpas.core.audio.resample;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.pcm;

type
  TAudioLinearResampler = class(TInterfacedObject, IAudioResampler)
  public
    function Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
  end;

function AudioResampleLinear(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
function CreateLinearResampler: IAudioResampler;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.simd;

function AudioResampleLinear(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
var
  LChannels: Integer;
  LSrcFrames: Integer;
  LSrcRate: Integer;
  LSrcFormat: TAudioSampleFormat;
  LDstFrames: Integer;
  LNum: Int64;
  LTmp: Double;
  LPlanes: TAudioPlaneArray;
  LDstPlanes: TAudioPlaneArray;
  LDstFormat: TAudioFormat;
  LCh, LFrame: Integer;
  LPos: Double;
  LStep: Single;
  LS0Idx: Integer;
  LFrac: Single;
  LF32Interleaved: TBytes;
  LSrcPtr: PSingle;
  LDstPtr: PSingle;
  LChunk: Integer;
  LJ: Integer;
  LS0Buf: array[0..7] of Single;
  LS1Buf: array[0..7] of Single;
  LFracBuf: array[0..7] of Single;
begin
  Result := Default(TAudioBuffer);
  if (ANewRate < MinAudioSampleRate) or (ANewRate > MaxAudioSampleRate) then
    raise EInvalidArgument.Create('AudioResampleLinear: ANewRate out of range [8000..192000]');
  if not AInput.Format.IsValid then
    raise EAudioError.Create('AudioResampleLinear: invalid input format');

  if (AInput.FrameCount = 0) or (Length(AInput.Data) = 0) then
  begin
    LDstFormat := AudioFormatCreate(ANewRate, AInput.Format.Channels, sfF32);
    LDstFormat.ChannelMask := AInput.Format.ChannelMask;
    LDstFormat.ChannelLayout := AInput.Format.ChannelLayout;
    Result.Format := LDstFormat;
    Result.FrameCount := 0;
    Result.Data := nil;
    Exit;
  end;

  LChannels := AInput.Format.Channels;
  LSrcFrames := AInput.FrameCount;
  LSrcRate := AInput.Format.SampleRate;
  LSrcFormat := AInput.Format.SampleFormat;

  // dstFrames = Round(srcFrames * dstRate / srcRate) using Int64
  LNum := Int64(LSrcFrames) * Int64(ANewRate);
  LTmp := LNum / Double(LSrcRate);
  LDstFrames := Round(LTmp);
  if LDstFrames < 0 then
    LDstFrames := 0;

  if LDstFrames = 0 then
  begin
    LDstFormat := AudioFormatCreate(ANewRate, LChannels, sfF32);
    LDstFormat.ChannelMask := AInput.Format.ChannelMask;
    LDstFormat.ChannelLayout := AInput.Format.ChannelLayout;
    Result.Format := LDstFormat;
    Result.FrameCount := 0;
    Result.Data := nil;
    Exit;
  end;

  // convert to F32 planar — reuse pcm.pas PcmConvert bulk F32 intermediate (single source, batched outer-branch)
  // perf: PcmConvert bulk converts interleaved -> interleaved F32 via batched loops + threadvar scratch; PcmDeinterleave then splits planar with bytes.ops single-source BytesCopy (inline, zero-copy)
  if LSrcFormat = sfF32 then
    PcmDeinterleave(AInput.Data, LSrcFrames, LChannels, 4, LPlanes)
  else
  begin
    LF32Interleaved := PcmConvert(AInput.Data, LSrcFormat, sfF32, LSrcFrames, LChannels, False);
    PcmDeinterleave(LF32Interleaved, LSrcFrames, LChannels, 4, LPlanes);
  end;

  // per-channel linear interpolation
  SetLength(LDstPlanes, LChannels);
  for LCh := 0 to LChannels - 1 do
    SetLength(LDstPlanes[LCh], LDstFrames * SizeOf(Single));

  // perf: precomputed Single LStep avoids per-frame float division in hotspot; typed PSingle window zero-copy, no per-sample CopyMem/PSingle(@bytes)^
  // perf: 8-wide SIMD batch via audio.simd SimdLerpF32 (AVX2 8-wide + SSE2 4-wide, single source owner dispatch, inline, vzeroupper); gather S0/S1/Frac scalar, lerp vectorized, no per-frame branch/div
  LStep := Single(LSrcRate) / Single(ANewRate);
  for LCh := 0 to LChannels - 1 do
  begin
    if (Length(LPlanes[LCh]) < LSrcFrames * SizeOf(Single)) or (Length(LDstPlanes[LCh]) < LDstFrames * SizeOf(Single)) then
      Continue;
    if (LSrcFrames = 0) or (LDstFrames = 0) then
      Continue;
    LSrcPtr := PSingle(@LPlanes[LCh][0]);
    LDstPtr := PSingle(@LDstPlanes[LCh][0]);
    LPos := 0;
    LFrame := 0;
    while LFrame < LDstFrames do
    begin
      if LDstFrames - LFrame >= 8 then LChunk := 8
      else LChunk := LDstFrames - LFrame;
      for LJ := 0 to LChunk - 1 do
      begin
        LS0Idx := Trunc(LPos);
        LFrac := Single(LPos - LS0Idx);
        // branchless frac already in [0,1) by construction; no clamp branch
        if (LS0Idx >= 0) and (LS0Idx < LSrcFrames) then
          LS0Buf[LJ] := LSrcPtr[LS0Idx]
        else
          LS0Buf[LJ] := 0;
        if (LS0Idx + 1 >= 0) and (LS0Idx + 1 < LSrcFrames) then
          LS1Buf[LJ] := LSrcPtr[LS0Idx + 1]
        else
          LS1Buf[LJ] := 0;
        LFracBuf[LJ] := LFrac;
        LPos := LPos + LStep;
      end;
      SimdLerpF32(@LS0Buf[0], @LS1Buf[0], @LFracBuf[0], @LDstPtr[LFrame], LChunk);
      Inc(LFrame, LChunk);
    end;
  end;

  LDstFormat := AudioFormatCreate(ANewRate, LChannels, sfF32);
  LDstFormat.ChannelMask := AInput.Format.ChannelMask;
  LDstFormat.ChannelLayout := AInput.Format.ChannelLayout;

  Result.Format := LDstFormat;
  Result.FrameCount := LDstFrames;
  PcmInterleave(LDstPlanes, LDstFrames, LChannels, SizeOf(Single), Result.Data);
end;

function TAudioLinearResampler.Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
begin
  Result := AudioResampleLinear(AInput, ANewRate);
end;

function CreateLinearResampler: IAudioResampler;
begin
  Result := TAudioLinearResampler.Create;
end;

end.
