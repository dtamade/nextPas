unit nextpas.core.audio.pcm_wav.impl;

{**
 * @desc PCM WAV 兼容实现：经 TWavDecoder/WavEncoder 薄封装，旧 Boolean 契约。
 *  复用 bytes.ops 单源，热点 inline 零拷贝；IStream refcounted 自动释放不丢。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.pcm_wav.base;

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
  nextpas.core.audio.codec.registry,
  nextpas.core.audio.errors,
  nextpas.core.bytes.ops;

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
    // perf: inline + single source via bytes.ops.BytesCopy — single Move zero-copy, exception-safe, no dual source
    BytesCopy(@AData.Bytes[0], @ABuf.Data[0], SizeUInt(Length(ABuf.Data)));
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
  LBuf: TAudioBuffer;
  LTags: TAudioTags;
begin
  Result := False;
  ClearPcmWavData(AData);
  // registry薄封装：经 TryDecodeWholeFile 薄封装复用 Probe≤4KB + fs owner，零直引 fs，不自写重复 Open；稳定性：IStream refcounted 自动释放，不丢
  if not TryDecodeWholeFile(AFilePath, LBuf, LTags) then Exit;
  if not FillFromBuffer(LBuf, AData) then
  begin
    ClearPcmWavData(AData);
    Exit(False);
  end;
  Result := True;
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
  // perf: inline + single source via bytes.ops.BytesAppend — single SetLength+Move zero-copy, amortized O(1), exception-safe
  LBuf.Data := nil;
  if LBytes > 0 then
    BytesAppend(LBuf.Data, PByte(@ASamples[0]), SizeUInt(LBytes));
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
    // perf: inline + single source via bytes.ops.BytesZero — single FillChar zero-copy, no dual source
    BytesZero(@LBuf.Data[0], SizeUInt(LBytes));
  LBuf.FrameCount := LFrames;
  AudioEncodeWav(LBuf, AStream);
end;

procedure WritePcmWav(const AFilePath: string; ASampleRate, AChannels: Integer;
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
  // perf: inline + single source via bytes.ops.BytesAppend — single SetLength+Move zero-copy, amortized O(1), exception-safe
  LBuf.Data := nil;
  if LBytes > 0 then
    BytesAppend(LBuf.Data, PByte(@ASamples[0]), SizeUInt(LBytes));
  LBuf.FrameCount := Length(ASamples) div AChannels;
  // registry/wav薄封装：经 AudioEncodeWav(ABuffer, AFilePath) 薄封装复用 fs.Create owner，零直引 fs；稳定性：IFile refcounted 自动释放，不丢
  AudioEncodeWav(LBuf, AFilePath);
end;

procedure WriteSilencePcmWav(const AFilePath: string; ASampleRate, AChannels, ADurationMs: Integer);
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
    BytesZero(@LBuf.Data[0], SizeUInt(LBytes));
  LBuf.FrameCount := LFrames;
  // registry/wav薄封装：经 AudioEncodeWav 薄封装复用 fs owner，零直引 fs
  AudioEncodeWav(LBuf, AFilePath);
end;

{$POP}

end.
