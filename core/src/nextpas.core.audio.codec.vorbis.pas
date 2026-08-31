unit nextpas.core.audio.codec.vorbis;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf;

function VorbisProbe(const APrefix: TBytes): TAudioProbeResult;
function CreateVorbisDecoder: IAudioDecoder;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.codec.vorbis.decoder;

type
  TVorbisDecoder = class(TInterfacedObject, IAudioDecoder)
  private
    FTags: TAudioTags;
  public
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

function VorbisProbe(const APrefix: TBytes): TAudioProbeResult;
begin
  if Length(APrefix) > 4096 then
    Result := VorbisProbeBytes(Copy(APrefix, 0, 4096))
  else
    Result := VorbisProbeBytes(APrefix);
end;

function TVorbisDecoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := VorbisProbe(APrefix);
end;

function TVorbisDecoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
begin
  if AStream = nil then
    raise EAudioDecodeError.Create('vorbis DecodeWhole: nil');
  Result := VorbisDecodeWholeViaStream(AStream);
  FTags := Default(TAudioTags);
end;

function TVorbisDecoder.OpenStreaming(const AStream: IStream): IAudioSource;
begin
  Result := nil;
  raise EAudioDecodeError.Create('vorbis OpenStreaming: not implemented');
end;

function TVorbisDecoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

function CreateVorbisDecoder: IAudioDecoder;
begin
  Result := TVorbisDecoder.Create;
end;

end.
