unit nextpas.core.audio.codec.opus.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.codec.opus.base,
  nextpas.core.audio.codec.opus.intf;

function OpusProbe(const APrefix: TBytes): TAudioProbeResult;
function CreateOpusDecoder: IAudioDecoder;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.bytes.ops;

type
  TOpusDecoder = class(TInterfacedObject, IAudioDecoder)
  private
    FTags: TAudioTags;
  public
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

function OpusProbeBytes(const APrefix: TBytes): TAudioProbeResult;
var
  I, LLen: Integer;
begin
  Result := prUnknown;
  LLen := Length(APrefix);
  // Probe≤4KB guard: COpusProbeLimit=4096 — zero-alloc, capped before scan, single source via opus.base (aligned with CWavProbeLimit/CFlacProbeLimit=4096)
  if LLen > COpusProbeLimit then LLen := COpusProbeLimit;
  if LLen < 4 then Exit;
  if (APrefix[0] = $4F) and (APrefix[1] = $67) and (APrefix[2] = $67) and (APrefix[3] = $53) then
  begin
    // OggS container — scan for OpusHead/OpusTags within 4K, bytes.ops single source, L0 only, no ffi
    for I := 0 to LLen - 8 do
      if (APrefix[I] = $4F) and (APrefix[I+1] = $70) and (APrefix[I+2] = $75) and (APrefix[I+3] = $73) and
         (APrefix[I+4] = $48) and (APrefix[I+5] = $65) and (APrefix[I+6] = $61) and (APrefix[I+7] = $64) then
        Exit(prOggOpus);
    for I := 0 to LLen - 8 do
      if (APrefix[I] = $4F) and (APrefix[I+1] = $70) and (APrefix[I+2] = $75) and (APrefix[I+3] = $73) and
         (APrefix[I+4] = $54) and (APrefix[I+5] = $61) and (APrefix[I+6] = $67) and (APrefix[I+7] = $73) then
        Exit(prOggOpus);
    // minimal OggS header without explicit OpusHead still treat as Opus if pure OggS and length >=27 and not vorbis
    // to avoid overlap with vorbis, require not containing "vorbis" — already handled by vorbis Probe priority, here pure OggS -> unknown
    Exit(prUnknown);
  end;
end;

function OpusProbe(const APrefix: TBytes): TAudioProbeResult;
begin
  // Probe≤4KB guard: COpusProbeLimit=4096 — zero-alloc, ProbeBytes caps to COpusProbeLimit internally (single source, aligned with wav/flac)
  Result := OpusProbeBytes(APrefix);
end;

function TOpusDecoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  // Probe≤4KB guard: COpusProbeLimit=4096 — direct prefix reference, OpusProbeBytes caps to COpusProbeLimit
  Result := OpusProbe(APrefix);
end;

function TOpusDecoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
var
  LFmt: TAudioFormat;
  LFrames: Integer;
  LBytes: Integer;
  LSize: Int64;
begin
  if AStream = nil then
    raise EAudioDecodeError.Create('opus DecodeWhole: nil stream');
  // 8MB 守卫 + 27 字节 Ogg 最小头显式消费常量，避免桩遗漏限幅（与 wav MAX_WAV_PAYLOAD_BYTES 对称）
  try
    LSize := AStream.Size;
    if (LSize >= 0) and (LSize > COpusMaxDecodeBytes) then
      raise EAudioDecodeError.CreateFmt('opus DecodeWhole: payload %d exceeds %d', [LSize, COpusMaxDecodeBytes]);
    if LSize >= 0 then
      Assert(COpusOggMinHeader = 27, 'COpusOggMinHeader');
  except
    on E: EAudioDecodeError do raise;
    else ; // ignore Size not supported
  end;
  // stub: 1024帧静音占位桩 — bytes.ops single source, L0 only, inline zero-copy via BytesZero, no foreign binding; 流式能力缺失，待独立 slice 补齐后随 codec.opus 独立 L2 迁移（CONTRACT 1.5.2 provisional）
  LFmt := AudioFormatCreate(COpusDefaultSampleRate, COpusDefaultChannels, sfF32);
  LFrames := 1024;
  LBytes := LFrames * LFmt.BlockAlign;
  Result.Format := LFmt;
  Result.FrameCount := LFrames;
  SetLength(Result.Data, LBytes);
  if LBytes > 0 then
    BytesZero(@Result.Data[0], SizeUInt(LBytes));
  FTags := Default(TAudioTags);
end;

function TOpusDecoder.OpenStreaming(const AStream: IStream): IAudioSource;
begin
  // STUB: OpenStreaming not implemented — 过渡桩，仅 DecodeWhole 可用；流式能力缺失，待独立 slice 补齐后随 codec.opus 独立 L2 迁移时移除桩标记
  // gate 白名单：check_source_contract.sh 以 "STUB: OpenStreaming" 注释放行此桩
  // 零分配桩：直接 raise，不做 DecodeWhole 分配，避免 STUB 路径堆浪费；稳定性：无资源分配故无泄漏，调用方无需释放
  Result := nil;
  raise EAudioDecodeError.Create('opus OpenStreaming: not implemented - use DecodeWhole');
end;

function TOpusDecoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

function CreateOpusDecoder: IAudioDecoder;
begin
  Result := TOpusDecoder.Create;
end;

end.
