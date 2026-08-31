unit nextpas.core.audio.codec.mp3;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf;

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
  if Length(APrefix) > 4096 then
    Result := Mp3ProbeBytes(Copy(APrefix, 0, 4096))
  else
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
