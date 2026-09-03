unit nextpas.core.audio.pcm_wav.base;

{$I nextpas.core.settings.inc}

interface

const
  DefaultPcmWavSampleRate = 44100;
  DefaultPcmWavChannels = 1;
  DefaultPcmWavSilenceMs = 50;
  PcmWavBitsPerSample = 16;

type
  TPcmWavBytes = array of Byte;

  TPcmWavData = record
    SampleRate: Integer;
    Channels: Integer;
    BitsPerSample: Integer;
    ByteRate: Integer;
    BlockAlign: Integer;
    DurationSeconds: Single;
    Bytes: TPcmWavBytes;
  end;

implementation

end.
