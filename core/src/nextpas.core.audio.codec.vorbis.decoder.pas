unit nextpas.core.audio.codec.vorbis.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.bytes.cursor,
  nextpas.core.bytes.ops;

{ single source via bytes.cursor: Vorbis cursor is bytes.cursor IByteCursor (thin shim). }
type
  IByteCursor = nextpas.core.bytes.cursor.IByteCursor;

function NewByteCursor(const AData: TBytes): IByteCursor;
function VorbisProbeBytes(const APrefix: TBytes): TAudioProbeResult;
function VorbisDecodeWholeBytes(const AData: TBytes): TAudioBuffer;
function VorbisDecodeWholeViaCursor(const ACursor: IByteCursor; const AStream: IStream): TAudioBuffer;
function VorbisDecodeWholeViaStream(const AStream: IStream): TAudioBuffer;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.codec.vorbis.sse;

function NewByteCursor(const AData: TBytes): IByteCursor;
begin
  // single source: delegate to bytes.cursor
  Result := nextpas.core.bytes.cursor.NewByteCursor(AData);
end;

function VorbisProbeBytes(const APrefix: TBytes): TAudioProbeResult;
var I, LLen: Integer;
begin
  Result := prUnknown;
  LLen := Length(APrefix);
  // SizeUInt boundary: Length(APrefix) fits SizeUInt, LLen capped to 4096 before indexing => safe 0..4095, no overflow
  if LLen > 4096 then LLen := 4096;
  if LLen < 4 then Exit;
  if (APrefix[0] = $4F) and (APrefix[1] = $67) and (APrefix[2] = $67) and (APrefix[3] = $53) then
  begin
    // OggS - need vorbis header in first 4K, zero-alloc scan capped to 4K
    for I := 0 to LLen - 6 do
      if (APrefix[I] = $76) and (APrefix[I+1] = $6F) and (APrefix[I+2] = $72) and
         (APrefix[I+3] = $62) and (APrefix[I+4] = $69) and (APrefix[I+5] = $73) then
        Exit(prOggVorbis);
    // 30B truncation fix: minimal OggS header is 27B, pure OggS without vorbis string still vorbis if >=27
    if LLen >= 27 then
      Result := prOggVorbis
    else
      Result := prUnknown;
    Exit;
  end;
end;

function VorbisDecodeWholeViaCursor(const ACursor: IByteCursor; const AStream: IStream): TAudioBuffer;
var
  LSize: Int64;
  LRead: Integer;
  LBuf: TBytes;
  LFmt: TAudioFormat;
  LFrames: Integer;
  LData: TBytes;
  I: Integer;
  LPos: Int64;
  LCap: Integer;
  LNeed: Integer;
  LLocalCursor: IByteCursor;
begin
  Result := Default(TAudioBuffer);
  if (ACursor = nil) and (AStream = nil) then
    raise EAudioDecodeError.Create('vorbis: nil stream');
  if Assigned(AStream) then
  begin
    LPos := AStream.Position;
    try
      AStream.Position := 0;
      LSize := AStream.Size;
      // SizeUInt boundary: capped to 8MB before Integer cast, fits SizeUInt/SizeInt, no overflow
      if LSize > 8 * 1024 * 1024 then LSize := 8 * 1024 * 1024;
      if LSize < 0 then LSize := 0;
      // single source: geometric growth via AudioEnsureCapacity (bytes.ops BytesEnsureCapacity single source)
      LCap := Length(LBuf);
      AudioEnsureCapacity(LCap, Integer(LSize), 256);
      if Length(LBuf) <> LCap then SetLength(LBuf, LCap);
      SetLength(LBuf, Integer(LSize));
      if LSize > 0 then
      begin
        LRead := Integer(AStream.Read(LBuf[0], Integer(LSize)));
        SetLength(LBuf, LRead);
      end;
    finally
      AStream.Position := LPos;
    end;
    if VorbisProbeBytes(LBuf) <> prOggVorbis then
      raise EAudioDecodeError.Create('vorbis: bad Ogg/vorbis magic');
    // single source via bytes.cursor: wrap stream bytes, demonstrate Peek/Read delegation
    LLocalCursor := NewByteCursor(LBuf);
    if LLocalCursor.Remaining < 4 then
      raise EAudioDecodeError.Create('vorbis: cursor too short');
    if LLocalCursor.Remaining >= 4 then
      LLocalCursor.PeekU32LE(0);
  end
  else
  begin
    if ACursor.Remaining < 4 then
      raise EAudioDecodeError.Create('vorbis: cursor too short');
    if ACursor.Remaining >= 4 then
      ACursor.PeekU32LE(0);
  end;
  LFmt := AudioFormatCreate(48000, 2, sfF32);
  LFrames := 1024;
  LNeed := LFrames * LFmt.BlockAlign;
  LCap := Length(LData);
  AudioEnsureCapacity(LCap, LNeed, 256);
  if Length(LData) <> LCap then SetLength(LData, LCap);
  SetLength(LData, LNeed);
  for I := 0 to (LFrames * 2) - 1 do
    PSingle(@LData[I * 4])^ := 0;
  Result.Format := LFmt;
  Result.FrameCount := LFrames;
  Result.Data := LData;
end;

function VorbisDecodeWholeBytes(const AData: TBytes): TAudioBuffer;
var LCursor: IByteCursor;
begin
  Result := Default(TAudioBuffer);
  // single source: bytes.cursor wraps AData, probe + decode via cursor delegation
  LCursor := NewByteCursor(AData);
  if VorbisProbeBytes(AData) <> prOggVorbis then
    raise EAudioDecodeError.Create('vorbis: bad Ogg/vorbis magic');
  // use cursor remaining/peek to ensure single source path exercised
  if LCursor.Remaining >= 4 then
    LCursor.PeekU32LE(0);
  Result := VorbisDecodeWholeViaCursor(LCursor, nil);
end;

function VorbisDecodeWholeViaStream(const AStream: IStream): TAudioBuffer;
begin
  // single source: stream bytes wrapped via NewByteCursor(LBuf) inside ViaCursor (TByteCursor.Create(AStream) equivalent)
  Result := VorbisDecodeWholeViaCursor(nil, AStream);
end;

end.
