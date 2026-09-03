unit nextpas.core.audio.codec.vorbis.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.codec.intf;

type
  // intf 仅别名 — reuse codec.intf GUID 0001 (IAudioDecoder), no new GUID, four-piece intf
  IVorbisDecoder = IAudioDecoder;

implementation

end.
