unit nextpas.core.audio.codec.wav.base;

{$I nextpas.core.settings.inc}

interface

const
  CWavProbeLimit = 4096;
  WAVE_FORMAT_PCM = 1;
  WAVE_FORMAT_IEEE_FLOAT = 3;
  WAVE_FORMAT_EXTENSIBLE = $FFFE;
  MAX_WAV_PAYLOAD_BYTES = 1024 * 1024 * 1024;
  GUID_PCM_DATA1 = $00000001;
  GUID_FLOAT_DATA1 = $00000003;

implementation

end.
