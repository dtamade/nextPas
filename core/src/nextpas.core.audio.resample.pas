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
  LSrcBytes: Integer;
  LDstFrames: Integer;
  LNum: Int64;
  LTmp: Double;
  LPlanes: TAudioPlaneArray;
  LDstPlanes: TAudioPlaneArray;
  LDstFormat: TAudioFormat;
  LCh, LFrame: Integer;
  LSrcOff: Integer;
  LF: Single;
  LS16: SmallInt;
  LS24: Integer;
  LS32: LongInt;
  LPos: Double;
  LS0Idx: Integer;
  LFrac: Double;
  LS0, LS1, LOut: Single;
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
  LSrcBytes := AudioBytesPerSample(LSrcFormat);

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

  // convert to F32 planar
  if LSrcFormat = sfF32 then
  begin
    PcmDeinterleave(AInput.Data, LSrcFrames, LChannels, 4, LPlanes);
  end
  else
  begin
    SetLength(LPlanes, LChannels);
    for LCh := 0 to LChannels - 1 do
      SetLength(LPlanes[LCh], LSrcFrames * SizeOf(Single));
    for LFrame := 0 to LSrcFrames - 1 do
      for LCh := 0 to LChannels - 1 do
      begin
        LSrcOff := (LFrame * LChannels + LCh) * LSrcBytes;
        if (LSrcOff < 0) or (LSrcOff + LSrcBytes > Length(AInput.Data)) then
          LF := 0
        else
        begin
          case LSrcFormat of
            sfU8:
              LF := PcmU8ToF32(AInput.Data[LSrcOff]);
            sfS16:
              begin
                LS16 := SmallInt(Word(AInput.Data[LSrcOff]) or (Word(AInput.Data[LSrcOff + 1]) shl 8));
                LF := PcmS16ToF32(LS16);
              end;
            sfS24:
              begin
                LS24 := PcmReadS24LE(AInput.Data, LSrcOff);
                LF := PcmS24ToF32(LS24);
              end;
            sfS32:
              begin
                LS32 := LongInt(DWord(AInput.Data[LSrcOff]) or (DWord(AInput.Data[LSrcOff + 1]) shl 8) or
                  (DWord(AInput.Data[LSrcOff + 2]) shl 16) or (DWord(AInput.Data[LSrcOff + 3]) shl 24));
                LF := PcmS32ToF32(LS32);
              end;
            sfF32:
              begin
                Move(AInput.Data[LSrcOff], LF, SizeOf(Single));
              end;
          else
            LF := 0;
          end;
        end;
        Move(LF, LPlanes[LCh][LFrame * SizeOf(Single)], SizeOf(Single));
      end;
  end;

  // per-channel linear interpolation
  SetLength(LDstPlanes, LChannels);
  for LCh := 0 to LChannels - 1 do
    SetLength(LDstPlanes[LCh], LDstFrames * SizeOf(Single));

  for LCh := 0 to LChannels - 1 do
  begin
    for LFrame := 0 to LDstFrames - 1 do
    begin
      LPos := LFrame * Double(LSrcRate) / Double(ANewRate);
      LS0Idx := Trunc(LPos);
      LFrac := LPos - Double(LS0Idx);
      if LFrac < 0 then LFrac := 0;
      if LFrac > 1 then LFrac := 1;

      if (LS0Idx >= 0) and (LS0Idx < LSrcFrames) then
        Move(LPlanes[LCh][LS0Idx * SizeOf(Single)], LS0, SizeOf(Single))
      else
        LS0 := 0;

      if (LS0Idx + 1 >= 0) and (LS0Idx + 1 < LSrcFrames) then
        Move(LPlanes[LCh][(LS0Idx + 1) * SizeOf(Single)], LS1, SizeOf(Single))
      else
        LS1 := 0;

      LOut := LS0 * Single(1.0 - LFrac) + LS1 * Single(LFrac);
      Move(LOut, LDstPlanes[LCh][LFrame * SizeOf(Single)], SizeOf(Single));
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
