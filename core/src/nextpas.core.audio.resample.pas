unit nextpas.core.audio.resample;

{$I nextpas.core.settings.inc}
{$IF 0}
{$mode objfpc}{$H+}
{$ENDIF}

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
  nextpas.core.audio.errors;

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
  LStep: Double;
  LS0Idx: Integer;
  LFrac: Double;
  LS0, LS1, LOut: Single;
  LF32Interleaved: TBytes;
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
  // perf: PcmConvert bulk converts interleaved -> interleaved F32 via batched loops + threadvar scratch; PcmDeinterleave then splits planar with bytes.ops single-source CopyMem (inline, zero-copy)
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

  // perf: precomputed LStep avoids per-frame float division in hotspot; inline PSingle direct access zero-copy, no per-sample CopyMem
  LStep := LSrcRate / ANewRate;
  for LCh := 0 to LChannels - 1 do
  begin
    LPos := 0;
    for LFrame := 0 to LDstFrames - 1 do
    begin
      LS0Idx := Trunc(LPos);
      LFrac := LPos - LS0Idx;
      if LFrac < 0 then LFrac := 0 else if LFrac > 1 then LFrac := 1;
      if (LS0Idx >= 0) and (LS0Idx < LSrcFrames) then
        LS0 := PSingle(@LPlanes[LCh][LS0Idx * SizeOf(Single)])^
      else LS0 := 0;
      if (LS0Idx + 1 >= 0) and (LS0Idx + 1 < LSrcFrames) then
        LS1 := PSingle(@LPlanes[LCh][(LS0Idx + 1) * SizeOf(Single)])^
      else LS1 := 0;
      LOut := LS0 * Single(1.0 - LFrac) + LS1 * Single(LFrac);
      PSingle(@LDstPlanes[LCh][LFrame * SizeOf(Single)])^ := LOut;
      LPos := LPos + LStep;
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
