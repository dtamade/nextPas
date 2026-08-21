program test_pcm_wav;

{$mode objfpc}{$H+}

uses
  nextpas.core.test,
  nextpas.core.io,
  nextpas.core.fs,
  nextpas.core.time,
  nextpas.core.system.sysutils,
  nextpas.core.audio.pcm_wav;

type
  TByteArray = array of Byte;

  T = class
    procedure RoundTripMono16;
    procedure ManualMono8;
    procedure SilenceStream;
    procedure FileRoundTrip;
    procedure RejectsNonRiff;
    procedure RejectsSizeMismatch;
    procedure RejectsDataWithoutFmt;
    procedure RejectsFloatFormat;
    procedure Rejects24Bit;
    procedure RejectsMisalignedData;
    procedure RejectsTruncatedPayload;
    procedure RejectsHugeDeclaredSize;
  end;

function StreamFromBytes(const ABytes: array of Byte): IStream;
var
  LStream: IStream;
begin
  LStream := BytesStream(0);
  if Length(ABytes) > 0 then
    LStream.Write(ABytes[0], Length(ABytes));
  LStream.Position := 0;
  Result := LStream;
end;

procedure AppendTag(var ABytes: TByteArray; const ATag: string);
var
  LOld: Integer;
begin
  LOld := Length(ABytes);
  SetLength(ABytes, LOld + 4);
  ABytes[LOld] := Ord(ATag[1]);
  ABytes[LOld + 1] := Ord(ATag[2]);
  ABytes[LOld + 2] := Ord(ATag[3]);
  ABytes[LOld + 3] := Ord(ATag[4]);
end;

procedure AppendWordLE(var ABytes: TByteArray; AValue: Word);
var
  LOld: Integer;
begin
  LOld := Length(ABytes);
  SetLength(ABytes, LOld + 2);
  ABytes[LOld] := AValue and $FF;
  ABytes[LOld + 1] := (AValue shr 8) and $FF;
end;

procedure AppendDWordLE(var ABytes: TByteArray; AValue: DWord);
var
  LOld: Integer;
begin
  LOld := Length(ABytes);
  SetLength(ABytes, LOld + 4);
  ABytes[LOld] := AValue and $FF;
  ABytes[LOld + 1] := (AValue shr 8) and $FF;
  ABytes[LOld + 2] := (AValue shr 16) and $FF;
  ABytes[LOld + 3] := (AValue shr 24) and $FF;
end;

{ 44-byte header + mono 8-bit payload, standard layout }
function BuildMono8Wav(const APayload: array of Byte): TByteArray;
var
  LResult: TByteArray;
  LPayload: TByteArray;
  LPayloadLen: Integer;
  LBase: Integer;
begin
  LResult := nil;
  AppendTag(LResult, 'RIFF');
  AppendDWordLE(LResult, 36 + DWord(Length(APayload)));
  AppendTag(LResult, 'WAVE');
  AppendTag(LResult, 'fmt ');
  AppendDWordLE(LResult, 16);
  AppendWordLE(LResult, 1);                  { PCM }
  AppendWordLE(LResult, 1);                  { channels }
  AppendDWordLE(LResult, 8000);              { sample rate }
  AppendDWordLE(LResult, 8000);              { byte rate }
  AppendWordLE(LResult, 1);                  { block align }
  AppendWordLE(LResult, 8);                  { bits per sample }
  AppendTag(LResult, 'data');
  AppendDWordLE(LResult, DWord(Length(APayload)));
  if Length(APayload) > 0 then
  begin
    LPayloadLen := Length(APayload);
    SetLength(LPayload, LPayloadLen);
    Move(APayload[0], LPayload[0], LPayloadLen);
    LBase := Length(LResult);
    SetLength(LResult, LBase + LPayloadLen);
    Move(LPayload[0], LResult[LBase], LPayloadLen);
  end;
  Result := LResult;
end;

procedure T.RoundTripMono16;
var
  LStream: IStream;
  LData: TPcmWavData;
  LExpected: array of SmallInt;
begin
  LStream := BytesStream(0);
  LExpected := [0, 100, -100, 32767, -32768];
  WritePcmWavStream(LStream, 44100, 1, LExpected);
  LStream.Position := 0;

  Check(TryParsePcmWav(LStream, LData), 'round-trip parse should succeed');
  CheckEqual(44100, LData.SampleRate, 'sample rate');
  CheckEqual(1, LData.Channels, 'channels');
  CheckEqual(16, LData.BitsPerSample, 'bits per sample');
  CheckEqual(88200, LData.ByteRate, 'byte rate');
  CheckEqual(2, LData.BlockAlign, 'block align');
  CheckEqual(10, Length(LData.Bytes), 'payload bytes (5 samples x 2)');
  CheckEqual(0, SmallInt(PWord(@LData.Bytes[0])^), 'first sample value');
  CheckEqual(100, SmallInt(PWord(@LData.Bytes[2])^), 'second sample value');
  CheckEqual(-32768, SmallInt(PWord(@LData.Bytes[8])^), 'last sample value');
  CheckEqual(5, Length(LData.Bytes) div LData.BlockAlign,
    'duration frames');
end;

procedure T.ManualMono8;
var
  LStream: IStream;
  LData: TPcmWavData;
begin
  LStream := StreamFromBytes(BuildMono8Wav([0, 127, 255, 64]));
  Check(TryParsePcmWav(LStream, LData), 'manual 8-bit WAV should parse');
  CheckEqual(8000, LData.SampleRate, '8-bit sample rate');
  CheckEqual(1, LData.Channels, '8-bit channels');
  CheckEqual(8, LData.BitsPerSample, '8-bit depth');
  CheckEqual(1, LData.BlockAlign, '8-bit block align');
  CheckEqual(4, Length(LData.Bytes), '8-bit payload length');
  CheckEqual(255, LData.Bytes[2], '8-bit sample value');
end;

procedure T.SilenceStream;
var
  LStream: IStream;
  LData: TPcmWavData;
  LIdx: Integer;
begin
  LStream := BytesStream(0);
  WriteSilencePcmWavStream(LStream, 44100, 1, 1000);
  LStream.Position := 0;

  Check(TryParsePcmWav(LStream, LData), 'silence WAV should parse');
  CheckEqual(44100, LData.SampleRate, 'silence sample rate');
  CheckEqual(44100, Length(LData.Bytes) div LData.BlockAlign,
    'silence duration frames (1000 ms @ 44100 Hz)');
  for LIdx := 0 to Length(LData.Bytes) - 1 do
    if LData.Bytes[LIdx] <> 0 then
    begin
      Check(False, 'silence payload must be all zeros at byte ' +
        IntToStr(LIdx));
      Exit;
    end;
end;

procedure T.FileRoundTrip;
var
  LPath: string;
  LData: TPcmWavData;
begin
  LPath := IncludeTrailingPathDelimiter(GetTempDir) + 'nextpas_pcm_wav_test_' +
    IntToStr(TInstant.Now.Elapsed.AsMilliseconds) + '.wav';
  try
    WritePcmWav(LPath, 22050, 2, [1, 2, 3, 4]);
    Check(TryLoadPcmWav(LPath, LData), 'file round-trip should load');
    CheckEqual(22050, LData.SampleRate, 'file sample rate');
    CheckEqual(2, LData.Channels, 'file channels');
    CheckEqual(8, Length(LData.Bytes), 'file payload bytes (4 samples x 2)');
  finally
    DeleteFile(LPath);
  end;
end;

procedure T.RejectsNonRiff;
var
  LData: TPcmWavData;
begin
  Check(not TryParsePcmWav(StreamFromBytes([Ord('N'), Ord('O'), Ord('T'),
    Ord('W'), Ord('A'), Ord('V'), Ord('E')]), LData),
    'non-RIFF stream must be rejected');
end;

procedure T.RejectsSizeMismatch;
var
  LStream: IStream;
  LData: TPcmWavData;
  LCorrupt: Word;
begin
  LStream := StreamFromBytes(BuildMono8Wav([0, 1, 2, 3]));
  LStream.Position := 8;                       { RIFF size field }
  LCorrupt := $1234;
  LStream.Write(LCorrupt, 2);                  { corrupt size }
  LStream.Position := 8;
  LStream.Read(LCorrupt, 2);                   { verify corruption landed }
  CheckEqual($1234, LCorrupt, 'size field should be corrupted');
  LStream.Position := 0;
  Check(not TryParsePcmWav(LStream, LData),
    'RIFF size mismatch must be rejected');
end;

procedure T.RejectsDataWithoutFmt;
var
  LBytes: TByteArray;
  LData: TPcmWavData;
begin
  LBytes := nil;
  AppendTag(LBytes, 'RIFF');
  AppendDWordLE(LBytes, 36 + 4);
  AppendTag(LBytes, 'WAVE');
  AppendTag(LBytes, 'data');
  AppendDWordLE(LBytes, 4);
  AppendDWordLE(LBytes, 0);
  Check(not TryParsePcmWav(StreamFromBytes(LBytes), LData),
    'data chunk before fmt must be rejected');
end;

procedure T.RejectsFloatFormat;
var
  LBytes: TByteArray;
  LData: TPcmWavData;
begin
  LBytes := nil;
  AppendTag(LBytes, 'RIFF');
  AppendDWordLE(LBytes, 36 + 4);
  AppendTag(LBytes, 'WAVE');
  AppendTag(LBytes, 'fmt ');
  AppendDWordLE(LBytes, 16);
  AppendWordLE(LBytes, 3);                     { IEEE float, not PCM }
  AppendWordLE(LBytes, 1);
  AppendDWordLE(LBytes, 8000);
  AppendDWordLE(LBytes, 32000);
  AppendWordLE(LBytes, 4);
  AppendWordLE(LBytes, 32);
  AppendTag(LBytes, 'data');
  AppendDWordLE(LBytes, 4);
  AppendDWordLE(LBytes, 0);
  Check(not TryParsePcmWav(StreamFromBytes(LBytes), LData),
    'float format must be rejected');
end;

procedure T.Rejects24Bit;
var
  LBytes: TByteArray;
  LData: TPcmWavData;
begin
  LBytes := nil;
  AppendTag(LBytes, 'RIFF');
  AppendDWordLE(LBytes, 36 + 6);
  AppendTag(LBytes, 'WAVE');
  AppendTag(LBytes, 'fmt ');
  AppendDWordLE(LBytes, 16);
  AppendWordLE(LBytes, 1);
  AppendWordLE(LBytes, 1);
  AppendDWordLE(LBytes, 48000);
  AppendDWordLE(LBytes, 144000);
  AppendWordLE(LBytes, 3);
  AppendWordLE(LBytes, 24);
  AppendTag(LBytes, 'data');
  AppendDWordLE(LBytes, 6);
  AppendDWordLE(LBytes, 0);
  AppendWordLE(LBytes, 0);
  Check(not TryParsePcmWav(StreamFromBytes(LBytes), LData),
    '24-bit depth must be rejected');
end;

procedure T.RejectsMisalignedData;
var
  LBytes: TByteArray;
  LData: TPcmWavData;
begin
  LBytes := nil;
  AppendTag(LBytes, 'RIFF');
  AppendDWordLE(LBytes, 36 + 5);               { odd payload }
  AppendTag(LBytes, 'WAVE');
  AppendTag(LBytes, 'fmt ');
  AppendDWordLE(LBytes, 16);
  AppendWordLE(LBytes, 1);
  AppendWordLE(LBytes, 1);
  AppendDWordLE(LBytes, 8000);
  AppendDWordLE(LBytes, 8000);
  AppendWordLE(LBytes, 1);
  AppendWordLE(LBytes, 8);
  AppendTag(LBytes, 'data');
  AppendDWordLE(LBytes, 5);
  AppendDWordLE(LBytes, 0);
  AppendWordLE(LBytes, 0);
  Check(not TryParsePcmWav(StreamFromBytes(LBytes), LData),
    'payload not multiple of block align must be rejected');
end;

procedure T.RejectsTruncatedPayload;
var
  LBytes: TByteArray;
  LData: TPcmWavData;
begin
  LBytes := nil;
  AppendTag(LBytes, 'RIFF');
  AppendDWordLE(LBytes, 36 + 100);
  AppendTag(LBytes, 'WAVE');
  AppendTag(LBytes, 'fmt ');
  AppendDWordLE(LBytes, 16);
  AppendWordLE(LBytes, 1);
  AppendWordLE(LBytes, 1);
  AppendDWordLE(LBytes, 8000);
  AppendDWordLE(LBytes, 8000);
  AppendWordLE(LBytes, 1);
  AppendWordLE(LBytes, 8);
  AppendTag(LBytes, 'data');
  AppendDWordLE(LBytes, 100);
  AppendDWordLE(LBytes, 0);                    { only 4 payload bytes }
  Check(not TryParsePcmWav(StreamFromBytes(LBytes), LData),
    'truncated payload must be rejected');
end;

procedure T.RejectsHugeDeclaredSize;
var
  LBytes: TByteArray;
  LData: TPcmWavData;
begin
  { RIFF size claims ~2 GiB while the stream is tiny: the declared payload
    cannot be honored, so the container must be rejected up front. }
  LBytes := nil;
  AppendTag(LBytes, 'RIFF');
  AppendDWordLE(LBytes, $7FFFFFF0);
  AppendTag(LBytes, 'WAVE');
  AppendTag(LBytes, 'fmt ');
  AppendDWordLE(LBytes, 16);
  AppendWordLE(LBytes, 1);
  AppendWordLE(LBytes, 1);
  AppendDWordLE(LBytes, 8000);
  AppendDWordLE(LBytes, 8000);
  AppendWordLE(LBytes, 1);
  AppendWordLE(LBytes, 8);
  AppendTag(LBytes, 'data');
  AppendDWordLE(LBytes, 300);
  AppendDWordLE(LBytes, 0);
  AppendDWordLE(LBytes, 0);
  AppendDWordLE(LBytes, 0);
  Check(not TryParsePcmWav(StreamFromBytes(LBytes), LData),
    'huge declared RIFF size must be rejected');
end;

var
  LSuite: TTestSuite;
  LCase: T;

begin
  LCase := T.Create;
  LSuite := TTestSuite.Create('nextpas.core.audio.pcm_wav');
  LSuite.Test('round-trip mono 16-bit', @LCase.RoundTripMono16);
  LSuite.Test('manual mono 8-bit', @LCase.ManualMono8);
  LSuite.Test('silence stream', @LCase.SilenceStream);
  LSuite.Test('file round-trip', @LCase.FileRoundTrip);
  LSuite.Test('rejects non-RIFF', @LCase.RejectsNonRiff);
  LSuite.Test('rejects size mismatch', @LCase.RejectsSizeMismatch);
  LSuite.Test('rejects data without fmt', @LCase.RejectsDataWithoutFmt);
  LSuite.Test('rejects float format', @LCase.RejectsFloatFormat);
  LSuite.Test('rejects 24-bit', @LCase.Rejects24Bit);
  LSuite.Test('rejects misaligned data', @LCase.RejectsMisalignedData);
  LSuite.Test('rejects truncated payload', @LCase.RejectsTruncatedPayload);
  LSuite.Test('rejects huge declared size', @LCase.RejectsHugeDeclaredSize);
  LCase.Free;
  if not LSuite.Run then Halt(1);
end.
