# nextpas.core.audio

PCM WAV container codec: RIFF/WAVE parse and write for 8/16-bit mono/stereo.

## API

```pascal
uses nextpas.core.audio.pcm_wav;

var
  Data: TPcmWavData;
begin
  if TryLoadPcmWav('/path/to/sound.wav', Data) then
    PlayPcm(Data.SampleRate, Data.Channels, Data.Bytes);

  { stream-based parse (memory, network, any IStream) }
  if TryParsePcmWav(LStream, Data) then ...

  { write from 16-bit samples }
  WritePcmWav('/tmp/out.wav', 44100, 1, Samples);
  WritePcmWavStream(LStream, 44100, 1, Samples);

  { write N ms of silence }
  WriteSilencePcmWav('/tmp/silence.wav', 44100, 1, 500);
end;
```

## Entry points

| Function | Purpose |
| --- | --- |
| `TryLoadPcmWav(AFilePath, AData)` | Open + parse a WAV file; `False` on any failure, `AData` cleared. |
| `TryParsePcmWav(AStream, AData)` | Parse a RIFF/WAVE stream from the current position. |
| `WritePcmWav(AFilePath, ARate, AChannels, ASamples)` | Create/replace a 16-bit PCM WAV file. |
| `WritePcmWavStream(AStream, ARate, AChannels, ASamples)` | Append header + samples to any `IStream`. |
| `WriteSilencePcmWav(AFilePath, ARate, AChannels, ADurationMs)` | Create/replace a zero-sample WAV file. |
| `WriteSilencePcmWavStream(AStream, ARate, AChannels, ADurationMs)` | Append a zero-sample WAV to a stream. |

## Format contract

- Supported: PCM (`format = 1`), 8 or 16 bits, mono or stereo.
- Parsing is defensive: every chunk read is bounded by the declared RIFF size;
  chunk padding bytes are skipped; `data` size must be a multiple of block
  align; payload is capped at 256 MiB; any mismatch rejects the container and
  clears the output record.
- Writer emits the standard 44-byte header layout (RIFF/WAVE, `fmt `, `data`).

## Constants

`DefaultPcmWavSampleRate` (44100), `DefaultPcmWavChannels` (1),
`DefaultPcmWavSilenceMs` (50), `PcmWavBitsPerSample` (16).
