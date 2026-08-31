unit nextpas.core.audio.pcm_wav;

{**
 * @desc PCM WAV 兼容壳：转发到 nextpas.core.audio.codec.wav，保留 Boolean 旧契约。
 *  PR2 重构：全部读路径经 TWavDecoder.DecodeWhole 回填旧 record，异常转 False；
 *  写路径经 TWavEncoder（16-bit PCM 兼容）。
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

function TryLoadPcmWav(const AFilePath: string; out AData: TPcmWavData): Boolean;
function TryParsePcmWav(const AStream: IStream; out AData: TPcmWavData): Boolean;
procedure WritePcmWav(const AFilePath: string; ASampleRate, AChannels: Integer; const ASamples: array of SmallInt);
procedure WritePcmWavStream(const AStream: IStream; ASampleRate, AChannels: Integer; const ASamples: array of SmallInt);
procedure WriteSilencePcmWav(const AFilePath: string; ASampleRate, AChannels, ADurationMs: Integer);
procedure WriteSilencePcmWavStream(const AStream: IStream; ASampleRate, AChannels, ADurationMs: Integer);

implementation

{$PUSH}
{$WARNINGS OFF}
{$HINTS OFF}

uses
  nextpas.core.exception,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.wav,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.errors;

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

function FillFromBuffer(const ABuf: TAudioBuffer; out AData: TPcmWavData): Boolean;
var
  LBits: Integer;
begin
  Result := False;
  { Old API only supports PCM 8/16 mono/stereo — enforce compatibility }
  if not (ABuf.Format.SampleFormat in [sfU8, sfS16]) then Exit;
  if not (ABuf.Format.Channels in [1, 2]) then Exit;
  case ABuf.Format.SampleFormat of
    sfU8: LBits := 8;
    sfS16: LBits := 16;
  else
    Exit;
  end;
  { Validate PCM-only (not float) }
  if ABuf.Format.SampleFormat = sfF32 then Exit;
  AData.SampleRate := ABuf.Format.SampleRate;
  AData.Channels := ABuf.Format.Channels;
  AData.BitsPerSample := LBits;
  AData.BlockAlign := ABuf.Format.BlockAlign;
  AData.ByteRate := Integer(ABuf.Format.ByteRate);
  if ABuf.Format.SampleRate > 0 then
    AData.DurationSeconds := ABuf.FrameCount / ABuf.Format.SampleRate
  else
    AData.DurationSeconds := 0;
  SetLength(AData.Bytes, Length(ABuf.Data));
  if Length(ABuf.Data) > 0 then
    Move(ABuf.Data[0], AData.Bytes[0], Length(ABuf.Data));
  Result := True;
end;

function TryParsePcmWav(const AStream: IStream; out AData: TPcmWavData): Boolean;
var
  LDec: IAudioDecoder;
  LBuf: TAudioBuffer;
begin
  Result := False;
  ClearPcmWavData(AData);
  if AStream = nil then Exit;
  try
    LDec := CreateWavDecoder;
    LBuf := LDec.DecodeWhole(AStream);
    if not FillFromBuffer(LBuf, AData) then
    begin
      ClearPcmWavData(AData);
      Exit(False);
    end;
    Result := True;
  except
    on E: EAudioDecodeError do
    begin
      ClearPcmWavData(AData);
      Result := False;
    end;
    else raise;
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

procedure WritePcmWavStream(const AStream: IStream; ASampleRate, AChannels: Integer;
  const ASamples: array of SmallInt);
var
  LBuf: TAudioBuffer;
  LBytes: Integer;
begin
  if ASampleRate <= 0 then ASampleRate := DefaultPcmWavSampleRate;
  if AChannels <= 0 then AChannels := DefaultPcmWavChannels;
  if not (AChannels in [1, 2]) then AChannels := DefaultPcmWavChannels;
  LBuf.Format := AudioFormatCreate(ASampleRate, AChannels, sfS16);
  LBytes := Length(ASamples) * SizeOf(SmallInt);
  SetLength(LBuf.Data, LBytes);
  if LBytes > 0 then
    Move(ASamples[0], LBuf.Data[0], LBytes);
  LBuf.FrameCount := Length(ASamples) div AChannels;
  AudioEncodeWav(LBuf, AStream);
end;

procedure WriteSilencePcmWavStream(const AStream: IStream; ASampleRate, AChannels, ADurationMs: Integer);
var
  LBuf: TAudioBuffer;
  LBlockAlign: Integer;
  LFrames: Integer;
  LBytes: Integer;
begin
  if ASampleRate <= 0 then ASampleRate := DefaultPcmWavSampleRate;
  if AChannels <= 0 then AChannels := DefaultPcmWavChannels;
  if not (AChannels in [1, 2]) then AChannels := DefaultPcmWavChannels;
  if ADurationMs <= 0 then ADurationMs := DefaultPcmWavSilenceMs;
  LBuf.Format := AudioFormatCreate(ASampleRate, AChannels, sfS16);
  LBlockAlign := LBuf.Format.BlockAlign;
  LFrames := (ASampleRate * ADurationMs) div 1000;
  LBytes := LFrames * LBlockAlign;
  SetLength(LBuf.Data, LBytes);
  if LBytes > 0 then
    FillChar(LBuf.Data[0], LBytes, 0);
  LBuf.FrameCount := LFrames;
  AudioEncodeWav(LBuf, AStream);
end;

procedure WritePcmWav(const AFilePath: string; ASampleRate, AChannels: Integer;
  const ASamples: array of SmallInt);
var
  LFile: IFile;
begin
  LFile := nextpas.core.fs.Create(AFilePath);
  WritePcmWavStream(LFile, ASampleRate, AChannels, ASamples);
end;

procedure WriteSilencePcmWav(const AFilePath: string; ASampleRate, AChannels, ADurationMs: Integer);
var
  LFile: IFile;
begin
  LFile := nextpas.core.fs.Create(AFilePath);
  WriteSilencePcmWavStream(LFile, ASampleRate, AChannels, ADurationMs);
end;

{$POP}

end.
