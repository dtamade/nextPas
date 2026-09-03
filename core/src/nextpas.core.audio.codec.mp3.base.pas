unit nextpas.core.audio.codec.mp3.base;

{$I nextpas.core.settings.inc}

interface

// L0 only: pure constants, no L1+ uses — four-piece base (aligned with wav.base/flac.base/opus.base)
const
  CMp3ProbeLimit = 4096;
  CMp3MaxStreamBytes = 8 * 1024 * 1024;
  CMp3DefaultFrames = 1152;
  CMp3DefaultSampleRate = 44100;
  CMp3DefaultChannels = 2;

implementation

end.
