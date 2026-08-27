unit nextpas.core.audio.codec.registry;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.intf;

type
  TDecoderFactory = function: IAudioDecoder;
  TDecoderFactoryArray = array of TDecoderFactory;

procedure AudioRegisterDecoder(AFactory: TDecoderFactory);
function AudioDetectProbe(const APrefix: TBytes): TAudioProbeResult;
function AudioDetectProbeFromStream(const AStream: IStream): TAudioProbeResult;
function TryDecodeWhole(ADecoder: IAudioDecoder; const AStream: IStream;
  out ABuffer: TAudioBuffer): Boolean;
function TryDecodeWholeFile(const APath: string; out ABuffer: TAudioBuffer;
  out ATags: TAudioTags): Boolean;
function AudioOpenFileStreaming(const APath: string): IAudioSource;

implementation

uses
  nextpas.core.audio.codec.wav,
  nextpas.core.audio.codec.aiff,
  nextpas.core.audio.codec.flac.decoder,
  nextpas.core.audio.codec.mp3.decoder,
  nextpas.core.audio.codec.vorbis.decoder,
  nextpas.core.audio.errors,
  nextpas.core.exception,
  nextpas.core.fs;

var
  GFactories: array of TDecoderFactory;
  GLock: TRTLCriticalSection;
  GInited: Boolean;

procedure EnsureInited;
begin
  if GInited then Exit;
  InitCriticalSection(GLock);
  GInited := True;
  AudioRegisterDecoder(@CreateWavDecoder);
  AudioRegisterDecoder(@CreateAiffDecoder);
  AudioRegisterDecoder(@CreateFlacDecoder);
  AudioRegisterDecoder(@CreateMp3Decoder);
  AudioRegisterDecoder(@CreateVorbisDecoder);
end;

procedure AudioRegisterDecoder(AFactory: TDecoderFactory);
var
  L: Integer;
begin
  if not Assigned(AFactory) then
    raise EInvalidArgument.Create('AudioRegisterDecoder: factory is nil');
  EnsureInited;
  EnterCriticalSection(GLock);
  try
    L := Length(GFactories);
    SetLength(GFactories, L + 1);
    if L > 0 then
      Move(GFactories[0], GFactories[1], L * SizeOf(TDecoderFactory));
    GFactories[0] := AFactory;
  finally
    LeaveCriticalSection(GLock);
  end;
end;

function SnapshotFactories: TDecoderFactoryArray;
begin
  EnsureInited;
  EnterCriticalSection(GLock);
  try
    Result := Copy(GFactories);
  finally
    LeaveCriticalSection(GLock);
  end;
end;

function AudioDetectProbe(const APrefix: TBytes): TAudioProbeResult;
var
  LFactories: TDecoderFactoryArray;
  LDec: IAudioDecoder;
  LRes: TAudioProbeResult;
  I: Integer;
begin
  Result := prUnknown;
  if Length(APrefix) = 0 then Exit;
  LFactories := SnapshotFactories;
  for I := 0 to High(LFactories) do
  begin
    try
      LDec := LFactories[I]();
      if not Assigned(LDec) then Continue;
      LRes := LDec.Probe(APrefix);
      if LRes <> prUnknown then Exit(LRes);
    except
      Continue;
    end;
  end;
end;

function AudioDetectProbeFromStream(const AStream: IStream): TAudioProbeResult;
var
  LPos: Int64;
  LPrefix: TBytes;
  LToRead: Integer;
begin
  Result := prUnknown;
  if AStream = nil then Exit;
  LPos := AStream.Position;
  try
    LToRead := 4096;
    if AStream.Size - LPos < LToRead then
      LToRead := Integer(AStream.Size - LPos);
    if LToRead < 0 then LToRead := 0;
    SetLength(LPrefix, LToRead);
    if LToRead > 0 then
    begin
      if AStream.Read(LPrefix[0], LToRead) <> LToRead then
      begin
        SetLength(LPrefix, 0);
        Exit;
      end;
    end;
    Result := AudioDetectProbe(LPrefix);
  finally
    AStream.Position := LPos;
  end;
end;

function TryDecodeWhole(ADecoder: IAudioDecoder; const AStream: IStream;
  out ABuffer: TAudioBuffer): Boolean;
begin
  Result := False;
  ABuffer := Default(TAudioBuffer);
  if (ADecoder = nil) or (AStream = nil) then Exit;
  try
    ABuffer := ADecoder.DecodeWhole(AStream);
    Result := True;
  except
    on E: EAudioDecodeError do
      Result := False;
    else
      Result := False;
  end;
end;

function TryDecodeWholeFile(const APath: string; out ABuffer: TAudioBuffer;
  out ATags: TAudioTags): Boolean;
var
  LStream: IStream;
  LPrefix: TBytes;
  LProbe: TAudioProbeResult;
  LFactories: TDecoderFactoryArray;
  LDec: IAudioDecoder;
  I: Integer;
  LRead: Integer;
begin
  Result := False;
  ABuffer := Default(TAudioBuffer);
  ATags := Default(TAudioTags);
  try
    LStream := nextpas.core.fs.Open(APath, [fmRead]);
  except
    Exit;
  end;
  if LStream = nil then Exit;
  SetLength(LPrefix, 4096);
  LRead := Integer(LStream.Read(LPrefix[0], 4096));
  SetLength(LPrefix, LRead);
  LProbe := AudioDetectProbe(LPrefix);
  if LProbe = prUnknown then Exit;
  LStream.Position := 0;
  LFactories := SnapshotFactories;
  for I := 0 to High(LFactories) do
  begin
    LDec := LFactories[I]();
    if LDec = nil then Continue;
    if LDec.Probe(LPrefix) <> LProbe then Continue;
    LStream.Position := 0;
    try
      ABuffer := LDec.DecodeWhole(LStream);
      ATags := LDec.Tags;
      Result := True;
      Exit;
    except
      on E: EAudioDecodeError do Continue;
      else Continue;
    end;
  end;
end;

function AudioOpenFileStreaming(const APath: string): IAudioSource;
var
  LStream: IStream;
  LPrefix: TBytes;
  LProbe: TAudioProbeResult;
  LFactories: TDecoderFactoryArray;
  LDec: IAudioDecoder;
  I: Integer;
  LRead: Integer;
begin
  Result := nil;
  try
    LStream := nextpas.core.fs.Open(APath, [fmRead]);
  except
    on E: EAudioError do
      raise EAudioDecodeError.CreateFmt('AudioOpenFileStreaming: cannot open %s: %s', [APath, E.Message]);
    else
      raise EAudioDecodeError.CreateFmt('AudioOpenFileStreaming: cannot open %s', [APath]);
  end;
  if LStream = nil then
    raise EAudioDecodeError.CreateFmt('AudioOpenFileStreaming: nil stream for %s', [APath]);
  SetLength(LPrefix, 4096);
  LRead := Integer(LStream.Read(LPrefix[0], 4096));
  SetLength(LPrefix, LRead);
  LProbe := AudioDetectProbe(LPrefix);
  if LProbe = prUnknown then
    raise EAudioDecodeError.CreateFmt('AudioOpenFileStreaming: unknown format %s', [APath]);
  LStream.Position := 0;
  LFactories := SnapshotFactories;
  for I := 0 to High(LFactories) do
  begin
    LDec := LFactories[I]();
    if LDec = nil then Continue;
    if LDec.Probe(LPrefix) <> LProbe then Continue;
    LStream.Position := 0;
    try
      Result := LDec.OpenStreaming(LStream);
      if Assigned(Result) then Exit;
    except
      on E: EAudioDecodeError do Continue;
      else Continue;
    end;
  end;
  raise EAudioDecodeError.CreateFmt('AudioOpenFileStreaming: no decoder succeeded for %s', [APath]);
end;

initialization
  GInited := False;

finalization
  if GInited then
    DoneCriticalSection(GLock);

end.
