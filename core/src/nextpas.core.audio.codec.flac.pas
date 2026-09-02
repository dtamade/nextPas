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
  Result := FlacProbeBytes(APrefix);
end;

function TFlacDecoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  if Length(APrefix) > 4096 then
    Result := FlacProbeBytes(Copy(APrefix, 0, 4096))
  else
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
