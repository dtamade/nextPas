unit nextpas.core.audio.codec.flac.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf;

function FlacProbe(const APrefix: TBytes): TAudioProbeResult;
function CreateFlacDecoder: IAudioDecoder;

implementation

uses
  nextpas.core.audio.codec.flac,
  nextpas.core.audio.errors,
  nextpas.core.audio.pcm;

type
  TMemoryFlacSource = class(TInterfacedObject, IAudioSource, IRealtimeAudioSource)
  private
    FBuffer: TAudioBuffer;
    FPos: Integer;
  public
    constructor Create(const ABuffer: TAudioBuffer);
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
  end;

  TFlacDecoder = class(TInterfacedObject, IAudioDecoder)
  private
    FTags: TAudioTags;
    FHasTags: Boolean;
  public
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

constructor TMemoryFlacSource.Create(const ABuffer: TAudioBuffer);
begin
  inherited Create;
  FBuffer := ABuffer;
  FPos := 0;
end;

function TMemoryFlacSource.GetFormat: TAudioFormat;
begin
  Result := FBuffer.Format;
end;

function TMemoryFlacSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LAvail, LToCopy, LBytes: Integer;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  if Length(ABuffer.Data) < AFrames * FBuffer.Format.BlockAlign then
    raise EInvalidArgument.Create('flac streaming: buffer too small');
  LAvail := FBuffer.FrameCount - FPos;
  if LAvail <= 0 then Exit(0);
  LToCopy := AFrames;
  if LToCopy > LAvail then LToCopy := LAvail;
  LBytes := LToCopy * FBuffer.Format.BlockAlign;
  if LBytes > 0 then
    Move(FBuffer.Data[FPos * FBuffer.Format.BlockAlign], ABuffer.Data[0], LBytes);
  ABuffer.Format := FBuffer.Format;
  ABuffer.FrameCount := LToCopy;
  SetLength(ABuffer.Data, LBytes);
  FPos := FPos + LToCopy;
  Result := LToCopy;
end;

function TMemoryFlacSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := Fill(ABuffer, AFrames);
  if Result < AFrames then
  begin
    if Length(ABuffer.Data) < AFrames * FBuffer.Format.BlockAlign then
      SetLength(ABuffer.Data, AFrames * FBuffer.Format.BlockAlign);
    if Result * FBuffer.Format.BlockAlign < Length(ABuffer.Data) then
      FillChar(ABuffer.Data[Result * FBuffer.Format.BlockAlign],
        (AFrames - Result) * FBuffer.Format.BlockAlign, 0);
    ABuffer.Format := FBuffer.Format;
    ABuffer.FrameCount := AFrames;
    Result := AFrames;
  end;
end;

function TMemoryFlacSource.SeekTo(AFrame: UInt64): Boolean;
begin
  if AFrame > UInt64(FBuffer.FrameCount) then Exit(False);
  FPos := Integer(AFrame);
  Result := True;
end;

function FlacProbe(const APrefix: TBytes): TAudioProbeResult;
var
  I: Integer;
  HasFlac: Boolean;
begin
  Result := prUnknown;
  if Length(APrefix) < 4 then Exit;
  if (APrefix[0] = Ord('f')) and (APrefix[1] = Ord('L')) and
     (APrefix[2] = Ord('a')) and (APrefix[3] = Ord('C')) then
    Exit(prFlac);
  if Length(APrefix) >= 4 then
    if (APrefix[0] = Ord('O')) and (APrefix[1] = Ord('g')) and
       (APrefix[2] = Ord('g')) and (APrefix[3] = Ord('S')) then
    begin
      HasFlac := False;
      for I := 0 to Length(APrefix) - 4 do
        if (APrefix[I] = Ord('F')) and (APrefix[I+1] = Ord('L')) and
           (APrefix[I+2] = Ord('A')) and (APrefix[I+3] = Ord('C')) then
        begin HasFlac := True; Break; end;
      if HasFlac then Exit(prFlac);
      // Ogg without FLAC marker is not FLAC
    end;
end;

function TFlacDecoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := FlacProbe(APrefix);
end;

function TFlacDecoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

function DecodeFlacBytes(const AData: TBytes; out AOut: TAudioBuffer; out ATags: TAudioTags): Boolean;
var
  Flac: PMiniflacT;
  Planes: array[0..7] of PInt32;
  I: Integer;
  Off, FileLen: LongInt;
  Used: LongWord;
  R: LongInt;
  BS, CH, BPS: LongInt;
  SR: LongInt;
  SIdx, CIdx: LongInt;
  V: LongInt;
  F: Single;
  LFormat: TAudioFormat;
  LHasFormat: Boolean;
  LOutBytes: TBytes;
  LOutPos: Integer;
  LOutCap: Integer;
  LDiv: Double;
  LTotalFrames: Integer;
begin
  Result := False;
  AOut := Default(TAudioBuffer);
  ATags := Default(TAudioTags);
  FileLen := Length(AData);
  if FileLen < 4 then Exit;
  GetMem(Flac, miniflac_size());
  try
    for I := 0 to 7 do
      GetMem(Planes[I], 65535 * SizeOf(LongInt));
    try
      miniflac_init(Flac, MINIFLAC_CONTAINER_NATIVE);
      Off := 0;
      LHasFormat := False;
      LTotalFrames := 0;
      LOutPos := 0;
      LOutCap := 0;
      SetLength(LOutBytes, 0);
      while Off < FileLen do
      begin
        Used := 0;
        R := miniflac_decode(Flac, @AData[Off], LongWord(FileLen - Off), @Used, PPInt32T(@Planes[0]));
        if Used > 0 then Inc(Off, Integer(Used)) else Inc(Off);
        if R = MINIFLAC_OK then
        begin
          BS := Flac^.frame.header.block_size;
          CH := Flac^.frame.header.channels;
          BPS := Flac^.frame.header.bps;
          SR := LongInt(Flac^.frame.header.sample_rate);
          if not LHasFormat then
          begin
            if (SR < MinAudioSampleRate) or (SR > MaxAudioSampleRate) then SR := 44100;
            if (CH < 1) or (CH > MaxAudioChannels) then CH := 2;
            LFormat := AudioFormatCreate(SR, CH, sfF32);
            LHasFormat := True;
          end;
          // Ensure capacity for BS*CH floats
          if LOutPos + BS * CH * 4 > LOutCap then
          begin
            if LOutCap = 0 then LOutCap := 4096 * CH * 4;
            while LOutPos + BS * CH * 4 > LOutCap do LOutCap := LOutCap * 2;
            SetLength(LOutBytes, LOutCap);
          end;
          case BPS of
            8:  LDiv := 128.0;
            16: LDiv := 32768.0;
            24: LDiv := 8388608.0;
            32: LDiv := 2147483648.0;
          else LDiv := 32768.0;
          end;
          for SIdx := 0 to BS - 1 do
            for CIdx := 0 to CH - 1 do
            begin
              V := Planes[CIdx][SIdx];
              F := Single(V / LDiv);
              if F > 1.0 then F := 1.0 else if F < -1.0 then F := -1.0;
              PSingle(@LOutBytes[LOutPos])^ := F;
              Inc(LOutPos, 4);
            end;
          Inc(LTotalFrames, BS);
        end
        else if R = MINIFLAC_CONTINUE then Continue
        else if R < 0 then Continue
        else Continue;
      end;
      if not LHasFormat then Exit(False);
      SetLength(LOutBytes, LOutPos);
      AOut.Format := LFormat;
      AOut.FrameCount := LTotalFrames;
      AOut.Data := LOutBytes;
      Result := True;
    finally
      for I := 0 to 7 do FreeMem(Planes[I]);
    end;
  finally
    FreeMem(Flac);
  end;
end;

function TFlacDecoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
var
  LData: TBytes;
  LSize, LPos, LAvail: Int64;
  LRead: LongInt;
begin
  Result := Default(TAudioBuffer);
  FTags := Default(TAudioTags);
  FHasTags := False;
  if AStream = nil then
    raise EAudioDecodeError.Create('flac: nil stream');
  LPos := AStream.Position;
  LSize := AStream.Size;
  LAvail := LSize - LPos;
  if LAvail <= 0 then
    raise EAudioDecodeError.Create('flac: empty stream');
  if LAvail > 1024*1024*256 then
    raise EAudioDecodeError.Create('flac: stream too large');
  SetLength(LData, LAvail);
  LRead := AStream.Read(LData[0], LongInt(LAvail));
  if LRead <> LAvail then
    raise EAudioDecodeError.Create('flac: read failed');
  if not DecodeFlacBytes(LData, Result, FTags) then
    raise EAudioDecodeError.Create('flac: decode failed');
  FHasTags := True;
end;

function TFlacDecoder.OpenStreaming(const AStream: IStream): IAudioSource;
var
  LBuf: TAudioBuffer;
begin
  LBuf := DecodeWhole(AStream);
  Result := TMemoryFlacSource.Create(LBuf);
end;

function CreateFlacDecoder: IAudioDecoder;
begin
  Result := TFlacDecoder.Create;
end;

end.
