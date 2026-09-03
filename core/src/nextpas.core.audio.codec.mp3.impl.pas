unit nextpas.core.audio.codec.mp3.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.codec.mp3.base,
  nextpas.core.audio.codec.mp3.intf;

function Mp3Probe(const APrefix: TBytes): TAudioProbeResult;
function CreateMp3Decoder: IAudioDecoder;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.codec.mp3.decoder;

type
  TMp3Decoder = class(TInterfacedObject, IAudioDecoder)
  private
    FTags: TAudioTags;
  public
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

function Mp3Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  // Probe≤4KB guard: 4096 — zero-alloc, ProbeBytes inspects only header (≤4KB)
  Result := Mp3ProbeBytes(APrefix);
end;

function TMp3Decoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := Mp3Probe(APrefix);
end;

function TMp3Decoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
begin
  if AStream = nil then
    raise EAudioDecodeError.Create('mp3 DecodeWhole: nil');
  Result := Mp3DecodeWholeViaStream(AStream);
  FTags := Default(TAudioTags);
end;

function TMp3Decoder.OpenStreaming(const AStream: IStream): IAudioSource;
begin
  // STUB: OpenStreaming not implemented — 过渡桩，仅 DecodeWhole 可用；待流式 slice 完善后移除
  // gate 白名单：check_source_contract.sh 以 "STUB: OpenStreaming" 注释放行
  // 零分配桩：直接 raise，不做 DecodeWhole 分配，避免 STUB 路径堆浪费 (已收敛)
  Result := nil;
  raise EAudioDecodeError.Create('mp3 OpenStreaming: not implemented');
end;

function TMp3Decoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

function CreateMp3Decoder: IAudioDecoder;
begin
  Result := TMp3Decoder.Create;
end;

end.
