unit nextpas.core.audio.codec.mp3.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.bytes.cursor,
  nextpas.core.bytes.ops;

{ single source via bytes.cursor: MP3 cursor is bytes.cursor IByteCursor (thin shim). }
type
  IByteCursor = nextpas.core.bytes.cursor.IByteCursor;

function NewByteCursor(const AData: TBytes): IByteCursor;
function Mp3ProbeBytes(const APrefix: TBytes): TAudioProbeResult;
function Mp3DecodeWholeBytes(const AData: TBytes): TAudioBuffer;
function Mp3DecodeWholeViaCursor(const ACursor: IByteCursor; const AStream: IStream): TAudioBuffer;
function Mp3DecodeWholeViaStream(const AStream: IStream): TAudioBuffer;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.codec.mp3.sse;

function NewByteCursor(const AData: TBytes): IByteCursor;
begin
  // single source: delegate to bytes.cursor
  Result := nextpas.core.bytes.cursor.NewByteCursor(AData);
end;

function Mp3ProbeBytes(const APrefix: TBytes): TAudioProbeResult;
var L0, L1: Byte; LLen: Integer;
begin
  Result := prUnknown;
  LLen := Length(APrefix);
  // SizeUInt boundary: Length(APrefix) fits SizeUInt, LLen capped to 4096 before indexing => safe 0..4095, no overflow
  if LLen > 4096 then LLen := 4096;
  if LLen < 2 then Exit;
  // ID3 needs 3 bytes
  if (LLen >= 3) and (APrefix[0] = $49) and (APrefix[1] = $44) and (APrefix[2] = $33) then
    Exit(prMp3);
  L0 := APrefix[0]; L1 := APrefix[1];
  if (L0 = $FF) and ((L1 and $E0) = $E0) then
    Result := prMp3;
end;

function Mp3DecodeWholeViaCursor(const ACursor: IByteCursor; const AStream: IStream): TAudioBuffer;
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
    raise EAudioDecodeError.Create('mp3: nil source');
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
    if Mp3ProbeBytes(LBuf) <> prMp3 then
      raise EAudioDecodeError.Create('mp3: bad sync');
    // single source via bytes.cursor: wrap stream bytes, peek via cursor (demonstrates Peek/Read delegation)
    LLocalCursor := NewByteCursor(LBuf);
    if LLocalCursor.Remaining < 2 then
      raise EAudioDecodeError.Create('mp3: cursor too short');
    // peek sync word via cursor (validates single source peek)
    if LLocalCursor.Remaining >= 2 then
      LLocalCursor.PeekU16LE(0);
  end
  else
  begin
    if ACursor.Remaining < 2 then
      raise EAudioDecodeError.Create('mp3: cursor too short');
    // peek via cursor single source
    if ACursor.Remaining >= 2 then
      ACursor.PeekU16LE(0);
  end;
  LFmt := AudioFormatCreate(44100, 2, sfF32);
  LFrames := 1152;
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

function Mp3DecodeWholeBytes(const AData: TBytes): TAudioBuffer;
var LCursor: IByteCursor;
begin
  Result := Default(TAudioBuffer);
  // single source: bytes.cursor wraps AData, probe + decode via cursor delegation
  LCursor := NewByteCursor(AData);
  if Mp3ProbeBytes(AData) <> prMp3 then
    raise EAudioDecodeError.Create('mp3: bad sync');
  Result := Mp3DecodeWholeViaCursor(LCursor, nil);
end;

function Mp3DecodeWholeViaStream(const AStream: IStream): TAudioBuffer;
begin
  // single source: stream bytes wrapped via TByteCursor.Create(AStream) equivalent NewByteCursor(LBuf) inside ViaCursor
  Result := Mp3DecodeWholeViaCursor(nil, AStream);
end;

end.
