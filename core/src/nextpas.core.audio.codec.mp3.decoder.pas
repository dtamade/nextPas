unit nextpas.core.audio.codec.mp3.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base;

function Mp3ProbeBytes(const APrefix: TBytes): TAudioProbeResult;
function Mp3DecodeWholeBytes(const AData: TBytes): TAudioBuffer;
function Mp3DecodeWholeViaStream(const AStream: IStream): TAudioBuffer;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.codec.mp3.sse;

function Mp3ProbeBytes(const APrefix: TBytes): TAudioProbeResult;
var L0, L1: Byte; LLen: Integer;
begin
  Result := prUnknown;
  LLen := Length(APrefix);
  if LLen > 4096 then LLen := 4096;
  if LLen < 2 then Exit;
  // ID3 needs 3 bytes
  if (LLen >= 3) and (APrefix[0] = $49) and (APrefix[1] = $44) and (APrefix[2] = $33) then
    Exit(prMp3);
  L0 := APrefix[0]; L1 := APrefix[1];
  if (L0 = $FF) and ((L1 and $E0) = $E0) then
    Result := prMp3;
end;

function Mp3DecodeWholeBytes(const AData: TBytes): TAudioBuffer;
var
  LFmt: TAudioFormat;
  LFrames: Integer;
  LData: TBytes;
  I: Integer;
begin
  Result := Default(TAudioBuffer);
  if Mp3ProbeBytes(AData) <> prMp3 then
    raise EAudioDecodeError.Create('mp3: bad sync');
  LFmt := AudioFormatCreate(44100, 2, sfF32);
  LFrames := 1152;
  SetLength(LData, LFrames * LFmt.BlockAlign);
  for I := 0 to (LFrames * 2) - 1 do
    PSingle(@LData[I * 4])^ := 0;
  Result.Format := LFmt;
  Result.FrameCount := LFrames;
  Result.Data := LData;
end;

function Mp3DecodeWholeViaStream(const AStream: IStream): TAudioBuffer;
var LSize: Int64; LBuf: TBytes; LRead: Integer; LPos: Int64;
begin
  Result := Default(TAudioBuffer);
  if AStream = nil then
    raise EAudioDecodeError.Create('mp3: nil stream');
  LPos := AStream.Position;
  try
    AStream.Position := 0;
    LSize := AStream.Size;
    if LSize > 8 * 1024 * 1024 then LSize := 8 * 1024 * 1024;
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
  Result := Mp3DecodeWholeBytes(LBuf);
end;

end.
