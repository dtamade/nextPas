unit nextpas.core.audio.codec.vorbis.base;

{$I nextpas.core.settings.inc}

interface

// L0 only: pure constants, no L1+ uses — four-piece base (aligned with wav.base/flac.base/opus.base)
const
  CVorbisProbeLimit = 4096;
  CVorbisMaxDecodeBytes = 8 * 1024 * 1024;
  CVorbisOggMinHeader = 27;

implementation

end.
