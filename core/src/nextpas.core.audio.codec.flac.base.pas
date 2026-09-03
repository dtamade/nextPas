unit nextpas.core.audio.codec.flac.base;

{$I nextpas.core.settings.inc}

interface

const
  CFlacProbeLimit = 4096;
  CFlacMagic0 = $66;
  CFlacMagic1 = $4C;
  CFlacMagic2 = $61;
  CFlacMagic3 = $43;
  CFlacMaxDecodeBytes = 64 * 1024 * 1024;
  CFlacDefaultSampleRate = 44100;
  CFlacDefaultChannels = 2;

type
  TFlacMagic = array[0..3] of Byte;

implementation

end.
