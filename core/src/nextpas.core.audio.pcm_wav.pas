unit nextpas.core.audio.pcm_wav;

{**
 * @desc PCM WAV container codec: RIFF/WAVE parse and write for 8/16-bit mono/stereo.
 *
 * Reader accepts a file path (TryLoadPcmWav) or any IStream (TryParsePcmWav);
 * writer produces a standard 44-byte-header PCM WAV from a file path or stream.
 * Parsing is defensive: every chunk read is bounded by the RIFF size, padding
 * bytes are skipped, and the fmt/data layout is validated before payload load.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.fs;

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

{ Read: file path entry; False on any parse or open failure, AData cleared. }
function TryLoadPcmWav(const AFilePath: string; out AData: TPcmWavData): Boolean;

{ Read: parse a RIFF/WAVE stream from the current position; AData cleared on failure. }
function TryParsePcmWav(const AStream: IStream; out AData: TPcmWavData): Boolean;

{ Write: create/replace a PCM WAV file from 16-bit samples. }
procedure WritePcmWav(const AFilePath: string;
  ASampleRate, AChannels: Integer;
  const ASamples: array of SmallInt);

{ Write: append a PCM WAV stream (header + samples) to AStream. }
procedure WritePcmWavStream(const AStream: IStream;
  ASampleRate, AChannels: Integer;
  const ASamples: array of SmallInt);

{ Write: create/replace a PCM WAV file of zero samples for the given duration. }
procedure WriteSilencePcmWav(const AFilePath: string;
  ASampleRate, AChannels, ADurationMs: Integer);

{ Write: append a zero-sample PCM WAV stream for the given duration. }
procedure WriteSilencePcmWavStream(const AStream: IStream;
  ASampleRate, AChannels, ADurationMs: Integer);

implementation

const
  PcmAudioFormat = 1;
  MaxPcmWavPayloadBytes = 256 * 1024 * 1024;

type
  TChunkTag = array[0..3] of AnsiChar;

procedure ClearPcmWavData(out AData: TPcmWavData);
begin
  AData.SampleRate := 0;
  AData.Channels := 0;
  AData.BitsPerSample := 0;
  AData.ByteRate := 0;
  AData.BlockAlign := 0;
  AData.DurationSeconds := 0;
  AData.Bytes := nil;
end;

function HasBytesAvailable(const AStream: IStream; ACount, ALimit: Int64): Boolean;
begin
  Result := (ACount >= 0) and (ALimit >= 0) and (ALimit <= AStream.Size) and
    (AStream.Position <= ALimit) and (ALimit - AStream.Position >= ACount);
end;

function ReadExact(const AStream: IStream; var ABuffer; ACount: Int64;
  ALimit: Int64): Boolean;
begin
  Result := ACount <= 0;
  if ACount > 0 then
  begin
    if ACount > High(LongInt) then
      Exit(False);
    if not HasBytesAvailable(AStream, ACount, ALimit) then
      Exit(False);
    Result := AStream.Read(ABuffer, LongInt(ACount)) = ACount;
  end;
end;

function ReadTag(const AStream: IStream; out ATag: TChunkTag;
  ALimit: Int64): Boolean;
begin
  Result := ReadExact(AStream, ATag, SizeOf(ATag), ALimit);
end;

function ReadWordLE(const AStream: IStream; out AValue: Word;
  ALimit: Int64): Boolean;
var
  LBytes: array[0..1] of Byte;
begin
  Result := ReadExact(AStream, LBytes, SizeOf(LBytes), ALimit);
  if Result then
    AValue := Word(LBytes[0]) or (Word(LBytes[1]) shl 8);
end;

function ReadDWordLE(const AStream: IStream; out AValue: DWord;
  ALimit: Int64): Boolean;
var
  LBytes: array[0..3] of Byte;
begin
  Result := ReadExact(AStream, LBytes, SizeOf(LBytes), ALimit);
  if Result then
    AValue := DWord(LBytes[0]) or (DWord(LBytes[1]) shl 8) or
      (DWord(LBytes[2]) shl 16) or (DWord(LBytes[3]) shl 24);
end;

function TagEquals(const ATag: TChunkTag; const AExpected: string): Boolean;
begin
  Result := (Length(AExpected) = 4) and
    (ATag[0] = AExpected[1]) and
    (ATag[1] = AExpected[2]) and
    (ATag[2] = AExpected[3]) and
    (ATag[3] = AExpected[4]);
end;

function PaddedChunkSize(AChunkSize: Int64): Int64;
begin
  Result := AChunkSize;
  if (Result mod 2) <> 0 then
    Inc(Result);
end;

function SkipBytes(const AStream: IStream; ACount, ALimit: Int64): Boolean;
var
  LNewPosition: Int64;
begin
  Result := HasBytesAvailable(AStream, PaddedChunkSize(ACount), ALimit);
  if not Result then
    Exit;

  LNewPosition := AStream.Position + ACount;
  if (ACount mod 2) <> 0 then
    Inc(LNewPosition);
  AStream.Position := LNewPosition;
end;

function ValidatePcmFormat(AAudioFormat, AChannels, ASampleRate, ABitsPerSample,
  AByteRate, ABlockAlign: Integer): Boolean;
var
  LExpectedBlockAlign: Integer;
  LExpectedByteRate: Int64;
begin
  Result := False;
  if (AAudioFormat <> PcmAudioFormat) or (ASampleRate <= 0) or
    (AByteRate <= 0) or (ABlockAlign <= 0) then
    Exit;
  if not ((AChannels = 1) or (AChannels = 2)) then
    Exit;
  if not ((ABitsPerSample = 8) or (ABitsPerSample = 16)) then
    Exit;

  LExpectedBlockAlign := AChannels * (ABitsPerSample div 8);
  LExpectedByteRate := Int64(ASampleRate) * Int64(LExpectedBlockAlign);
  Result := (ABlockAlign = LExpectedBlockAlign) and
    (LExpectedByteRate <= High(Integer)) and
    (AByteRate = Integer(LExpectedByteRate));
end;

function ReadFmtChunk(const AStream: IStream; AChunkSize: DWord; ARiffEnd: Int64;
  out AAudioFormat, AChannels, ASampleRate, AByteRate, ABlockAlign,
  ABitsPerSample: Integer): Boolean;
var
  LFormatWord, LChannelsWord, LBlockAlignWord, LBitsWord: Word;
  LSampleRateDWord, LByteRateDWord: DWord;
begin
  Result := False;
  if AChunkSize < 16 then
    Exit;
  if not HasBytesAvailable(AStream, AChunkSize, ARiffEnd) then
    Exit;

  if not ReadWordLE(AStream, LFormatWord, ARiffEnd) then Exit;
  if not ReadWordLE(AStream, LChannelsWord, ARiffEnd) then Exit;
  if not ReadDWordLE(AStream, LSampleRateDWord, ARiffEnd) then Exit;
  if not ReadDWordLE(AStream, LByteRateDWord, ARiffEnd) then Exit;
  if not ReadWordLE(AStream, LBlockAlignWord, ARiffEnd) then Exit;
  if not ReadWordLE(AStream, LBitsWord, ARiffEnd) then Exit;

  if (LSampleRateDWord > DWord(High(Integer))) or
    (LByteRateDWord > DWord(High(Integer))) then
    Exit;

  AAudioFormat := LFormatWord;
  AChannels := LChannelsWord;
  ASampleRate := Integer(LSampleRateDWord);
  AByteRate := Integer(LByteRateDWord);
  ABlockAlign := LBlockAlignWord;
  ABitsPerSample := LBitsWord;

  if AChunkSize > 16 then
    Result := SkipBytes(AStream, AChunkSize - 16, ARiffEnd)
  else
    Result := True;
end;

function LoadDataChunk(const AStream: IStream; AChunkSize: DWord; ARiffEnd: Int64;
  ASampleRate, AChannels, ABitsPerSample, AByteRate, ABlockAlign: Integer;
  out AData: TPcmWavData): Boolean;
begin
  Result := False;
  if AChunkSize > MaxPcmWavPayloadBytes then
    Exit;
  if (ABlockAlign <= 0) or ((AChunkSize mod DWord(ABlockAlign)) <> 0) then
    Exit;
  if not HasBytesAvailable(AStream, PaddedChunkSize(AChunkSize), ARiffEnd) then
    Exit;

  AData.SampleRate := ASampleRate;
  AData.Channels := AChannels;
  AData.BitsPerSample := ABitsPerSample;
  AData.ByteRate := AByteRate;
  AData.BlockAlign := ABlockAlign;
  AData.DurationSeconds := AChunkSize / AByteRate;
  SetLength(AData.Bytes, AChunkSize);
  if AChunkSize > 0 then
  begin
    if not ReadExact(AStream, AData.Bytes[0], AChunkSize, ARiffEnd) then
      Exit;
  end;
  Result := True;
end;

function TryParsePcmWav(const AStream: IStream; out AData: TPcmWavData): Boolean;
var
  LTag: TChunkTag;
  LChunkSize: DWord;
  LAudioFormat, LChannels, LSampleRate, LByteRate, LBlockAlign, LBitsPerSample:
    Integer;
  LRiffEnd: Int64;
  LHasFmt: Boolean;
begin
  Result := False;
  ClearPcmWavData(AData);

  if not ReadTag(AStream, LTag, AStream.Size) then Exit;
  if not TagEquals(LTag, 'RIFF') then Exit;
  if not ReadDWordLE(AStream, LChunkSize, AStream.Size) then Exit;
  if LChunkSize < 4 then Exit;
  LRiffEnd := Int64(8) + Int64(LChunkSize);
  if LRiffEnd <> AStream.Size then Exit;
  if not ReadTag(AStream, LTag, LRiffEnd) then Exit;
  if not TagEquals(LTag, 'WAVE') then Exit;

  LHasFmt := False;
  LAudioFormat := 0;
  LChannels := 0;
  LSampleRate := 0;
  LByteRate := 0;
  LBlockAlign := 0;
  LBitsPerSample := 0;

  while HasBytesAvailable(AStream, 8, LRiffEnd) do
  begin
    if not ReadTag(AStream, LTag, LRiffEnd) then Exit;
    if not ReadDWordLE(AStream, LChunkSize, LRiffEnd) then Exit;

    if TagEquals(LTag, 'fmt ') then
    begin
      if not ReadFmtChunk(AStream, LChunkSize, LRiffEnd, LAudioFormat, LChannels,
        LSampleRate, LByteRate, LBlockAlign, LBitsPerSample) then
        Exit;
      LHasFmt := True;
    end
    else if TagEquals(LTag, 'data') then
    begin
      if not LHasFmt then
        Exit;
      if not ValidatePcmFormat(LAudioFormat, LChannels, LSampleRate,
        LBitsPerSample, LByteRate, LBlockAlign) then
        Exit;
      Result := LoadDataChunk(AStream, LChunkSize, LRiffEnd, LSampleRate, LChannels,
        LBitsPerSample, LByteRate, LBlockAlign, AData);
      if not Result then
        ClearPcmWavData(AData);
      Exit;
    end
    else if not SkipBytes(AStream, LChunkSize, LRiffEnd) then
      Exit;
  end;
end;

function TryLoadPcmWav(const AFilePath: string; out AData: TPcmWavData): Boolean;
var
  LStream: IFile;
begin
  Result := False;
  ClearPcmWavData(AData);
  try
    LStream := nextpas.core.fs.Open(AFilePath, [fmRead]);
  except
    Exit;
  end;
  Result := TryParsePcmWav(LStream, AData);
end;

procedure WriteWordLE(const AStream: IStream; AValue: Word);
begin
  AStream.Write(AValue, 2);
end;

procedure WriteDWordLE(const AStream: IStream; AValue: DWord);
begin
  AStream.Write(AValue, 4);
end;

procedure WriteTag4(const AStream: IStream; const ATag: string);
begin
  AStream.Write(PAnsiChar(ATag)^, 4);
end;

procedure WriteHeader(const AStream: IStream;
  ASampleRate: DWord; AChannels: Word; ADataSize: DWord);
var
  LBlockAlign: Word;
  LByteRate: DWord;
begin
  LBlockAlign := AChannels * (PcmWavBitsPerSample div 8);
  LByteRate := ASampleRate * DWord(LBlockAlign);

  WriteTag4(AStream, 'RIFF');
  WriteDWordLE(AStream, 36 + ADataSize);
  WriteTag4(AStream, 'WAVE');

  WriteTag4(AStream, 'fmt ');
  WriteDWordLE(AStream, 16);
  WriteWordLE(AStream, 1);
  WriteWordLE(AStream, AChannels);
  WriteDWordLE(AStream, ASampleRate);
  WriteDWordLE(AStream, LByteRate);
  WriteWordLE(AStream, LBlockAlign);
  WriteWordLE(AStream, PcmWavBitsPerSample);

  WriteTag4(AStream, 'data');
  WriteDWordLE(AStream, ADataSize);
end;

procedure ClampDefaults(var ASampleRate, AChannels: Integer);
begin
  if ASampleRate <= 0 then
    ASampleRate := DefaultPcmWavSampleRate;
  if AChannels <= 0 then
    AChannels := DefaultPcmWavChannels;
end;

procedure WritePcmWavStream(const AStream: IStream;
  ASampleRate, AChannels: Integer;
  const ASamples: array of SmallInt);
var
  LDataSize: DWord;
  LSampleCount: Integer;
begin
  ClampDefaults(ASampleRate, AChannels);
  LSampleCount := Length(ASamples);
  LDataSize := DWord(LSampleCount * SizeOf(SmallInt));

  WriteHeader(AStream, DWord(ASampleRate), Word(AChannels), LDataSize);
  if LSampleCount > 0 then
    AStream.Write(ASamples[0], LDataSize);
end;

procedure WriteSilencePcmWavStream(const AStream: IStream;
  ASampleRate, AChannels, ADurationMs: Integer);
var
  LBlockAlign: DWord;
  LSampleCount: DWord;
  LDataSize: DWord;
  LZeros: TBytes;
begin
  ClampDefaults(ASampleRate, AChannels);
  if ADurationMs <= 0 then
    ADurationMs := DefaultPcmWavSilenceMs;

  LBlockAlign := DWord(AChannels) * (PcmWavBitsPerSample div 8);
  LSampleCount := (DWord(ASampleRate) * DWord(ADurationMs)) div 1000;
  LDataSize := LSampleCount * LBlockAlign;

  WriteHeader(AStream, DWord(ASampleRate), Word(AChannels), LDataSize);
  if LDataSize > 0 then
  begin
    SetLength(LZeros, LDataSize);
    FillChar(LZeros[0], LDataSize, 0);
    AStream.Write(LZeros[0], LDataSize);
  end;
end;

procedure WritePcmWav(const AFilePath: string;
  ASampleRate, AChannels: Integer;
  const ASamples: array of SmallInt);
var
  LFile: IFile;
begin
  LFile := nextpas.core.fs.Create(AFilePath);
  WritePcmWavStream(LFile, ASampleRate, AChannels, ASamples);
end;

procedure WriteSilencePcmWav(const AFilePath: string;
  ASampleRate, AChannels, ADurationMs: Integer);
var
  LFile: IFile;
begin
  LFile := nextpas.core.fs.Create(AFilePath);
  WriteSilencePcmWavStream(LFile, ASampleRate, AChannels, ADurationMs);
end;

end.
