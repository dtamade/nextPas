unit nextpas.core.audio.codec.flac.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  IByteCursor = interface
    ['{A1B2C3D4-E5F6-7890-1234-B00000000001}']
    function Remaining: Integer;
    function ReadByte(out AByte: Byte): Boolean;
    function PeekBytes(AOffset, ACount: Integer; out ABytes: TBytes): Boolean;
  end;

function NewByteCursor(const AData: TBytes): IByteCursor;
function FlacProbeBytes(const APrefix: TBytes): TAudioProbeResult;
function FlacDecodeWholeViaCursor(const ACursor: IByteCursor; const AStream: IStream): TAudioBuffer;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.codec.flac.sse;

type
  TByteCursor = class(TInterfacedObject, IByteCursor)
  private
    FData: TBytes;
    FPos: Integer;
  public
    constructor Create(const AData: TBytes);
    function Remaining: Integer;
    function ReadByte(out AByte: Byte): Boolean;
    function PeekBytes(AOffset, ACount: Integer; out ABytes: TBytes): Boolean;
  end;

constructor TByteCursor.Create(const AData: TBytes);
begin
  inherited Create;
  FData := Copy(AData, 0, Length(AData));
  FPos := 0;
end;

function TByteCursor.Remaining: Integer;
begin
  Result := Length(FData) - FPos;
end;

function TByteCursor.ReadByte(out AByte: Byte): Boolean;
begin
  if FPos >= Length(FData) then Exit(False);
  AByte := FData[FPos];
  Inc(FPos);
  Result := True;
end;

function TByteCursor.PeekBytes(AOffset, ACount: Integer; out ABytes: TBytes): Boolean;
var I: Integer;
begin
  Result := False;
  ABytes := nil;
  if (ACount <= 0) or (AOffset < 0) then Exit;
  if AOffset + ACount > Length(FData) then Exit;
  SetLength(ABytes, ACount);
  for I := 0 to ACount - 1 do
    ABytes[I] := FData[AOffset + I];
  Result := True;
end;

function NewByteCursor(const AData: TBytes): IByteCursor;
begin
  Result := TByteCursor.Create(AData);
end;

function FlacProbeBytes(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := prUnknown;
  if Length(APrefix) < 4 then Exit;
  if (APrefix[0] = $66) and (APrefix[1] = $4C) and (APrefix[2] = $61) and (APrefix[3] = $43) then
    Result := prFlac
  else if (Length(APrefix) >= 4) and (APrefix[0] = Ord('f')) and (APrefix[1] = Ord('L')) and (APrefix[2] = Ord('a')) and (APrefix[3] = Ord('C')) then
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
