unit nextpas.core.audio.codec.opus.base;

{$I nextpas.core.settings.inc}

interface

// L0 only: pure constants, no L1+ uses — four-piece base (aligned with wav.base/flac.base)
const
  COpusProbeLimit = 4096;
  COpusMaxDecodeBytes = 8 * 1024 * 1024;
  COpusOggMinHeader = 27;
  COpusDefaultSampleRate = 48000;
  COpusDefaultChannels = 2;

implementation

end.
