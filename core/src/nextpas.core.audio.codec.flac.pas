unit nextpas.core.audio.codec.flac;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf;

function FlacProbe(const APrefix: TBytes): TAudioProbeResult;
function CreateFlacDecoder: IAudioDecoder;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.codec.flac.decoder;

type
  TFlacDecoder = class(TInterfacedObject, IAudioDecoder)
  private
    FTags: TAudioTags;
  public
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

function FlacProbe(const APrefix: TBytes): TAudioProbeResult;
begin
  // Probe≤4KB guard: 4096 — zero-alloc, ProbeBytes inspects only header (no Copy even when >4096)
  Result := FlacProbeBytes(APrefix);
end;

function TFlacDecoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  // Probe≤4KB guard: 4096 — direct prefix reference, ProbeBytes caps to 4096 internally
  Result := FlacProbeBytes(APrefix);
end;

function TFlacDecoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
var LCursor: IByteCursor;
begin
  if AStream = nil then
    raise EAudioDecodeError.Create('flac DecodeWhole: nil stream');
  LCursor := nil;
  Result := FlacDecodeWholeViaCursor(LCursor, AStream);
  FTags := Default(TAudioTags);
end;

function TFlacDecoder.OpenStreaming(const AStream: IStream): IAudioSource;
var LBuf: TAudioBuffer;
begin
  // STUB: OpenStreaming not implemented — 过渡桩，仅 DecodeWhole 可用；待流式解码 slice 完善后移除桩标记
  // gate 白名单：check_source_contract.sh 以 "STUB: OpenStreaming" 注释放行此桩
  LBuf := DecodeWhole(AStream);
  Result := nil;
  // minimal streaming via buffer source will be provided by registry fallback - return nil for now and let registry use DecodeWhole path
  // create simple memory source
  Result := nil;
  raise EAudioDecodeError.Create('flac OpenStreaming: not implemented - use DecodeWhole');
end;

function TFlacDecoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

function CreateFlacDecoder: IAudioDecoder;
begin
  Result := TFlacDecoder.Create;
end;

end.
