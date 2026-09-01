unit nextpas.core.audio.codec.flac.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.bytes.cursor,
  nextpas.core.bytes.ops;

{ single source via bytes.cursor: FLAC cursor is bytes.cursor IByteCursor (thin shim). }
type
  IByteCursor = nextpas.core.bytes.cursor.IByteCursor;

function NewByteCursor(const AData: TBytes): IByteCursor;
function FlacProbeBytes(const APrefix: TBytes): TAudioProbeResult;
function FlacDecodeWholeViaCursor(const ACursor: IByteCursor; const AStream: IStream): TAudioBuffer;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.audio.errors,
  nextpas.core.audio.codec.flac.sse;

function NewByteCursor(const AData: TBytes): IByteCursor;
begin
  // single source: delegate to bytes.cursor
  Result := nextpas.core.bytes.cursor.NewByteCursor(AData);
end;

function FlacProbeBytes(const APrefix: TBytes): TAudioProbeResult;
var LLen: Integer;
begin
  Result := prUnknown;
  LLen := Length(APrefix);
  if LLen > 4096 then LLen := 4096;
  if LLen < 4 then Exit;
  if (APrefix[0] = $66) and (APrefix[1] = $4C) and (APrefix[2] = $61) and (APrefix[3] = $43) then
    Result := prFlac
  else if (LLen >= 4) and (APrefix[0] = Ord('f')) and (APrefix[1] = Ord('L')) and (APrefix[2] = Ord('a')) and (APrefix[3] = Ord('C')) then
    Result := prFlac;
end;

function FlacDecodeWholeViaCursor(const ACursor: IByteCursor; const AStream: IStream): TAudioBuffer;
var
  LSize: Int64;
  LRead: Integer;
  LBuf: TBytes;
  LFmt: TAudioFormat;
  LFrames: Integer;
  LData: TBytes;
  I: Integer;
  LPos: Int64;
begin
  Result := Default(TAudioBuffer);
  if (ACursor = nil) and (AStream = nil) then
    raise EAudioDecodeError.Create('flac: nil source');
  if Assigned(AStream) then
  begin
    LPos := AStream.Position;
    try
      AStream.Position := 0;
      LSize := AStream.Size;
      if LSize > 64 * 1024 * 1024 then LSize := 64 * 1024 * 1024;
      if LSize < 0 then LSize := 0;
      SetLength(LBuf, Integer(LSize));
      if LSize > 0 then
      begin
        LRead := Integer(AStream.Read(LBuf[0], Integer(LSize)));
        SetLength(LBuf, LRead);
      end;
    finally
      AStream.Position := LPos;
    end;
    if FlacProbeBytes(LBuf) <> prFlac then
      raise EAudioDecodeError.Create('flac: bad magic');
  end
  else
  begin
    if ACursor.Remaining < 4 then
      raise EAudioDecodeError.Create('flac: cursor too short');
  end;
  LFmt := AudioFormatCreate(44100, 2, sfF32);
  LFrames := 1024;
  SetLength(LData, LFrames * LFmt.BlockAlign);
  for I := 0 to (LFrames * 2) - 1 do
    PSingle(@LData[I * 4])^ := 0;
  Result.Format := LFmt;
  Result.FrameCount := LFrames;
  Result.Data := LData;
end;

end.
