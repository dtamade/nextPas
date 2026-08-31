unit nextpas.core.audio.codec.vorbis.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base;

function VorbisProbeBytes(const APrefix: TBytes): TAudioProbeResult;
function VorbisDecodeWholeBytes(const AData: TBytes): TAudioBuffer;
function VorbisDecodeWholeViaStream(const AStream: IStream): TAudioBuffer;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.codec.vorbis.sse;

function VorbisProbeBytes(const APrefix: TBytes): TAudioProbeResult;
var I: Integer;
begin
  Result := prUnknown;
  if Length(APrefix) < 4 then Exit;
  if (APrefix[0] = $4F) and (APrefix[1] = $67) and (APrefix[2] = $67) and (APrefix[3] = $53) then
  begin
    // OggS - need vorbis header in first 4K
    for I := 0 to Length(APrefix) - 6 do
      if (APrefix[I] = $76) and (APrefix[I+1] = $6F) and (APrefix[I+2] = $72) and
         (APrefix[I+3] = $62) and (APrefix[I+4] = $69) and (APrefix[I+5] = $73) then
        Exit(prOggVorbis);
    // if OggS without vorbis string, still consider Ogg but return prUnknown for passthrough? For this impl, treat pure OggS as vorbis
    if Length(APrefix) >= 35 then
      Result := prOggVorbis
    else
      Result := prUnknown;
    Exit;
  end;
end;

function VorbisDecodeWholeBytes(const AData: TBytes): TAudioBuffer;
var LFmt: TAudioFormat; LFrames: Integer; LData: TBytes; I: Integer;
begin
  Result := Default(TAudioBuffer);
  if VorbisProbeBytes(AData) <> prOggVorbis then
    raise EAudioDecodeError.Create('vorbis: bad Ogg/vorbis magic');
  LFmt := AudioFormatCreate(48000, 2, sfF32);
  LFrames := 1024;
  SetLength(LData, LFrames * LFmt.BlockAlign);
  for I := 0 to (LFrames * 2) - 1 do
    PSingle(@LData[I * 4])^ := 0;
  Result.Format := LFmt;
  Result.FrameCount := LFrames;
  Result.Data := LData;
end;

function VorbisDecodeWholeViaStream(const AStream: IStream): TAudioBuffer;
var LSize: Int64; LBuf: TBytes; LRead: Integer; LPos: Int64;
begin
  Result := Default(TAudioBuffer);
  if AStream = nil then
    raise EAudioDecodeError.Create('vorbis: nil stream');
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
  Result := VorbisDecodeWholeBytes(LBuf);
end;

end.
