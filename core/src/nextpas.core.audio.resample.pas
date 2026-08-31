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
  private
    FScratchSrc: TAudioPlaneArray;
    FScratchDst: TAudioPlaneArray;
    procedure EnsureScratchPlanes(var APlanes: TAudioPlaneArray; AChannels, AFrames: Integer); inline;
  public
    function Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
  end;

function AudioResampleLinear(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
function CreateLinearResampler: IAudioResampler;

implementation

uses
  nextpas.core.audio.errors;

threadvar
  GLinearSrc: TAudioPlaneArray;
  GLinearDst: TAudioPlaneArray;

procedure EnsureLinearPlanes(var APlanes: TAudioPlaneArray; AChannels, AFrames: Integer); inline;
var
  LNeed, LCap, I: Integer;
begin
  LNeed := AFrames * SizeOf(Single);
  if Length(APlanes) < AChannels then
    SetLength(APlanes, AChannels);
  for I := 0 to AChannels - 1 do
  begin
    if Length(APlanes[I]) >= LNeed then Continue;
    LCap := Length(APlanes[I]);
    if LCap < 256 then LCap := 256;
    while LCap < LNeed do LCap := LCap * 2;
    SetLength(APlanes[I], LCap);
  end;
end;

procedure TAudioLinearResampler.EnsureScratchPlanes(var APlanes: TAudioPlaneArray; AChannels, AFrames: Integer);
var
  LNeed, LCap, I: Integer;
begin
  LNeed := AFrames * SizeOf(Single);
  if Length(APlanes) < AChannels then
    SetLength(APlanes, AChannels);
  for I := 0 to AChannels - 1 do
  begin
    if Length(APlanes[I]) >= LNeed then Continue;
    LCap := Length(APlanes[I]);
    if LCap < 256 then LCap := 256;
    while LCap < LNeed do LCap := LCap * 2;
    SetLength(APlanes[I], LCap);
  end;
end;

function ResampleLinearCore(const AInput: TAudioBuffer; ANewRate: Integer;
  var VSrcPlanes, VDstPlanes: TAudioPlaneArray): TAudioBuffer;
var
  LChannels: Integer;
  LSrcFrames: Integer;
  LSrcRate: Integer;
  LSrcFormat: TAudioSampleFormat;
  LSrcBytes: Integer;
  LDstFrames: Integer;
  LNum: Int64;
  LTmp: Double;
  LDstFormat: TAudioFormat;
  LCh, LFrame: Integer;
  LSrcOff: Integer;
  LF: Single;
  LS16: SmallInt;
  LS24: Integer;
  LS32: LongInt;
  LStep: Double;
  LPos: Double;
  LS0Idx: Integer;
  LFrac: Double;
  LS0, LS1, LOut: Single;
  LSrcPtrF32: PSingle;
  LDstPtrF32: PSingle;
  LInterleavedF32: PSingle;
  LInterleavedS16: PSmallInt;
  LOutPtr: PSingle;
  LChanDst: PSingle;
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

  // Ensure scratch planes reuse (EnsureScratch discipline: exponential growth, steady zero alloc)
  EnsureLinearPlanes(VSrcPlanes, LChannels, LSrcFrames);
  EnsureLinearPlanes(VDstPlanes, LChannels, LDstFrames);

  // Convert to F32 planar - batch per format, pointer deref, no per-sample Move
  if LSrcFormat = sfF32 then
  begin
    // fast deinterleave: planar = deinterleaved F32, batch per channel
    if Length(AInput.Data) >= LSrcFrames * LChannels * SizeOf(Single) then
    begin
      LInterleavedF32 := PSingle(@AInput.Data[0]);
      for LCh := 0 to LChannels - 1 do
      begin
        LDstPtrF32 := PSingle(@VSrcPlanes[LCh][0]);
        for LFrame := 0 to LSrcFrames - 1 do
          LDstPtrF32[LFrame] := LInterleavedF32[LFrame * LChannels + LCh];
      end;
    end
    else
    begin
      // fallback with bounds zero-fill (should not happen for valid buffer)
      for LCh := 0 to LChannels - 1 do
        for LFrame := 0 to LSrcFrames - 1 do
          PSingle(@VSrcPlanes[LCh][LFrame * SizeOf(Single)])^ := 0;
    end;
  end
  else if LSrcFormat = sfS16 then
  begin
    // fast S16 -> F32 batch, no per-sample case dispatch
    if Length(AInput.Data) >= LSrcFrames * LChannels * 2 then
    begin
      LInterleavedS16 := PSmallInt(@AInput.Data[0]);
      for LCh := 0 to LChannels - 1 do
      begin
        LDstPtrF32 := PSingle(@VSrcPlanes[LCh][0]);
        for LFrame := 0 to LSrcFrames - 1 do
        begin
          LS16 := LInterleavedS16[LFrame * LChannels + LCh];
          if LS16 = -32768 then
            LDstPtrF32[LFrame] := -1.0
          else
            LDstPtrF32[LFrame] := LS16 / 32767.0;
        end;
      end;
    end
    else
    begin
      for LCh := 0 to LChannels - 1 do
        for LFrame := 0 to LSrcFrames - 1 do
        begin
          LSrcOff := (LFrame * LChannels + LCh) * 2;
          if (LSrcOff + 1 < Length(AInput.Data)) then
          begin
            LS16 := SmallInt(Word(AInput.Data[LSrcOff]) or (Word(AInput.Data[LSrcOff + 1]) shl 8));
            if LS16 = -32768 then LF := -1.0 else LF := LS16 / 32767.0;
          end else LF := 0;
          PSingle(@VSrcPlanes[LCh][LFrame * SizeOf(Single)])^ := LF;
        end;
    end;
  end
  else
  begin
    // generic path for sfU8/sfS24/sfS32/sfF32(already handled) - keep correctness, per-frame case but pointer dest
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
          else
            LF := 0;
          end;
        end;
        PSingle(@VSrcPlanes[LCh][LFrame * SizeOf(Single)])^ := LF;
      end;
  end;

  // per-channel linear interpolation - incremental LPos, pointer deref, no Move/Trunc per mul
  LStep := Double(LSrcRate) / Double(ANewRate);
  for LCh := 0 to LChannels - 1 do
  begin
    LSrcPtrF32 := PSingle(@VSrcPlanes[LCh][0]);
    LDstPtrF32 := PSingle(@VDstPlanes[LCh][0]);
    LPos := 0.0;
    for LFrame := 0 to LDstFrames - 1 do
    begin
      LS0Idx := Trunc(LPos);
      LFrac := LPos - Double(LS0Idx);
      if LFrac < 0 then LFrac := 0
      else if LFrac > 1 then LFrac := 1;

      if (LS0Idx >= 0) and (LS0Idx < LSrcFrames) then
        LS0 := LSrcPtrF32[LS0Idx]
      else
        LS0 := 0;

      if (LS0Idx + 1 >= 0) and (LS0Idx + 1 < LSrcFrames) then
        LS1 := LSrcPtrF32[LS0Idx + 1]
      else
        LS1 := 0;

      // branchless lerp when frac near 0/1
      if LFrac < 1e-12 then
        LOut := LS0
      else if LFrac > 1 - 1e-12 then
        LOut := LS1
      else
        LOut := LS0 * Single(1.0 - LFrac) + LS1 * Single(LFrac);
      LDstPtrF32[LFrame] := LOut;
      LPos := LPos + LStep;
    end;
  end;

  LDstFormat := AudioFormatCreate(ANewRate, LChannels, sfF32);
  LDstFormat.ChannelMask := AInput.Format.ChannelMask;
  LDstFormat.ChannelLayout := AInput.Format.ChannelLayout;

  Result.Format := LDstFormat;
  Result.FrameCount := LDstFrames;
  // direct interleave from scratch dst planes - batch, no PcmInterleave/Move
  SetLength(Result.Data, LDstFrames * LChannels * SizeOf(Single));
  if LDstFrames > 0 then
  begin
    LOutPtr := PSingle(@Result.Data[0]);
    for LFrame := 0 to LDstFrames - 1 do
      for LCh := 0 to LChannels - 1 do
      begin
        LChanDst := PSingle(@VDstPlanes[LCh][0]);
        LOutPtr[LFrame * LChannels + LCh] := LChanDst[LFrame];
      end;
  end;
end;

function AudioResampleLinear(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
begin
  Result := ResampleLinearCore(AInput, ANewRate, GLinearSrc, GLinearDst);
end;

function TAudioLinearResampler.Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
begin
  Result := ResampleLinearCore(AInput, ANewRate, FScratchSrc, FScratchDst);
end;

function CreateLinearResampler: IAudioResampler;
begin
  Result := TAudioLinearResampler.Create;
end;

end.
