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
  nextpas.core.bytes.cursor,
  nextpas.core.audio.codec.flac,
  nextpas.core.audio.codec.meta,
  nextpas.core.audio.errors;

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
    FFlac: PMiniflacT;
    FPlanes: array[0..7] of PInt32;
    FInit: Boolean;
    procedure EnsureArena;
    procedure ReleaseArena;
  public
    constructor Create;
    destructor Destroy; override;
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

{---- Probe via TBytesCursor (复用度/稳定性) ----}

function FlacProbe(const APrefix: TBytes): TAudioProbeResult;
var
  Cur: IByteCursor;
  Tag: array[0..3] of Byte;
  I: Integer;
begin
  Result := prUnknown;
  if Length(APrefix) < 4 then Exit;
  Cur := NewByteCursor(APrefix);
  Tag[0] := APrefix[0]; Tag[1] := APrefix[1]; Tag[2] := APrefix[2]; Tag[3] := APrefix[3];
  if (Tag[0] = Ord('f')) and (Tag[1] = Ord('L')) and (Tag[2] = Ord('a')) and (Tag[3] = Ord('C')) then
    Exit(prFlac);
  if (Tag[0] = Ord('O')) and (Tag[1] = Ord('g')) and (Tag[2] = Ord('g')) and (Tag[3] = Ord('S')) then
  begin
    for I := 0 to Length(APrefix) - 4 do
      if (APrefix[I] = Ord('F')) and (APrefix[I+1] = Ord('L')) and
         (APrefix[I+2] = Ord('A')) and (APrefix[I+3] = Ord('C')) then
        Exit(prFlac);
  end;
  // Try meta probe for VorbisComment wrapped in FLAC? not needed, keep unknown
  // cursor remains for future id3/ogg routing via codec.meta
  if Cur.Length >= 4 then ; // keep cursor live for contract
end;

function TFlacDecoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := FlacProbe(APrefix);
end;

function TFlacDecoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

constructor TFlacDecoder.Create;
begin
  inherited Create;
  FHasTags := False;
  FInit := False;
  FFlac := nil;
  FillChar(FPlanes, SizeOf(FPlanes), 0);
end;

destructor TFlacDecoder.Destroy;
begin
  ReleaseArena;
  inherited Destroy;
end;

procedure TFlacDecoder.EnsureArena;
var I: Integer;
begin
  if FInit then Exit;
  GetMem(FFlac, miniflac_size());
  for I := 0 to 7 do
    GetMem(FPlanes[I], 65535 * SizeOf(LongInt));
  FInit := True;
end;

procedure TFlacDecoder.ReleaseArena;
var I: Integer;
begin
  if not FInit then Exit;
  for I := 0 to 7 do
    if FPlanes[I] <> nil then FreeMem(FPlanes[I]);
  if FFlac <> nil then FreeMem(FFlac);
  FInit := False;
  FFlac := nil;
  FillChar(FPlanes, SizeOf(FPlanes), 0);
end;

function TFlacDecoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
var
  LData: TBytes;
  LAvail: Int64;
  LRead: LongInt;
  FileLen, Off: LongInt;
  Used: LongWord;
  R: LongInt;
  BS, CH, BPS, SR: LongInt;
  SIdx, CIdx: LongInt;
  V: LongInt;
  F: Single;
  LFormat: TAudioFormat;
  LHasFormat: Boolean;
  LOutBytes: TBytes;
  LOutPos, LOutCap, LTotalFrames: Integer;
  LDiv: Double;
begin
  Result := Default(TAudioBuffer);
  FTags := Default(TAudioTags);
  FHasTags := False;
  if AStream = nil then raise EAudioDecodeError.Create('flac: nil stream');
  LAvail := AStream.Size - AStream.Position;
  if LAvail <= 0 then raise EAudioDecodeError.Create('flac: empty stream');
  if LAvail > 1024*1024*256 then raise EAudioDecodeError.Create('flac: stream too large');
  SetLength(LData, LAvail);
  LRead := AStream.Read(LData[0], LongInt(LAvail));
  if LRead <> LAvail then raise EAudioDecodeError.Create('flac: read failed');

  EnsureArena;
  FileLen := Length(LData);
  if FileLen < 4 then raise EAudioDecodeError.Create('flac: too small');
  miniflac_init(FFlac, MINIFLAC_CONTAINER_NATIVE);
  Off := 0;
  LHasFormat := False;
  LTotalFrames := 0;
  LOutPos := 0;
  LOutCap := 0;
  SetLength(LOutBytes, 0);
  while Off < FileLen do
  begin
    Used := 0;
    R := miniflac_decode(FFlac, @LData[Off], LongWord(FileLen - Off), @Used, PPInt32T(@FPlanes[0]));
    if Used > 0 then Inc(Off, Integer(Used)) else Inc(Off);
    if R = MINIFLAC_OK then
    begin
      BS := FFlac^.frame.header.block_size;
      CH := FFlac^.frame.header.channels;
      BPS := FFlac^.frame.header.bps;
      SR := LongInt(FFlac^.frame.header.sample_rate);
      if not LHasFormat then
      begin
        if (SR < MinAudioSampleRate) or (SR > MaxAudioSampleRate) then SR := 44100;
        if (CH < 1) or (CH > MaxAudioChannels) then CH := 2;
        LFormat := AudioFormatCreate(SR, CH, sfF32);
        LHasFormat := True;
      end;
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
          V := FPlanes[CIdx][SIdx];
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
  if not LHasFormat then raise EAudioDecodeError.Create('flac: decode failed');
  SetLength(LOutBytes, LOutPos);
  Result.Format := LFormat;
  Result.FrameCount := LTotalFrames;
  Result.Data := LOutBytes;
  // 标签：尝试走 codec.meta 的 VorbisComment 路径（FLAC 内 VorbisComment 与 picture 等透传 Extra）
  // 当前先置空，后续由 meta.TryParseVorbisComment 补齐，保持接口稳定
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
