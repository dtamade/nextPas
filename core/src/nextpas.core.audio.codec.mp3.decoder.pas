unit nextpas.core.audio.codec.mp3.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf;

function Mp3Probe(const APrefix: TBytes): TAudioProbeResult;
function Mp3DecodeBytes(const AData: TBytes): TAudioBuffer;
function CreateMp3Decoder: IAudioDecoder;

implementation

uses
  nextpas.core.bytes.cursor,
  nextpas.core.audio.codec.mp3,
  nextpas.core.audio.codec.meta,
  nextpas.core.audio.errors,
  nextpas.core.audio.pcm.simd;

type
  TMemoryMp3Source = class(TInterfacedObject, IAudioSource, IRealtimeAudioSource)
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

  TMp3Decoder = class(TInterfacedObject, IAudioDecoder)
  private
    FTags: TAudioTags;
    FDec: TMp3decT;
    FInit: Boolean;
    FOut: TBytes;
    FOutCap: Integer;
    procedure EnsureArena;
    function DecodeBytesInternal(const AData: TBytes): TAudioBuffer;
  public
    constructor Create;
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function DecodeBytes(const AData: TBytes): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

threadvar
  GReuseMp3: TMp3Decoder;

constructor TMemoryMp3Source.Create(const ABuffer: TAudioBuffer);
begin
  inherited Create;
  FBuffer := ABuffer;
  FPos := 0;
end;

function TMemoryMp3Source.GetFormat: TAudioFormat;
begin
  Result := FBuffer.Format;
end;

function TMemoryMp3Source.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LAvail, LToCopy, LBytes: Integer;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  if Length(ABuffer.Data) < AFrames * FBuffer.Format.BlockAlign then
    raise EInvalidArgument.Create('mp3 streaming: buffer too small');
  LAvail := FBuffer.FrameCount - FPos;
  if LAvail <= 0 then Exit(0);
  LToCopy := AFrames;
  if LToCopy > LAvail then LToCopy := LAvail;
  LBytes := LToCopy * FBuffer.Format.BlockAlign;
  if LBytes > 0 then Move(FBuffer.Data[FPos * FBuffer.Format.BlockAlign], ABuffer.Data[0], LBytes);
  ABuffer.Format := FBuffer.Format;
  ABuffer.FrameCount := LToCopy;
  SetLength(ABuffer.Data, LBytes);
  FPos := FPos + LToCopy;
  Result := LToCopy;
end;

function TMemoryMp3Source.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
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

function TMemoryMp3Source.SeekTo(AFrame: UInt64): Boolean;
begin
  if AFrame > UInt64(FBuffer.FrameCount) then Exit(False);
  FPos := Integer(AFrame);
  Result := True;
end;

function Mp3Probe(const APrefix: TBytes): TAudioProbeResult;
var
  Cur: IByteCursor;
  Skipped: Integer;
  Tags: TAudioTags;
begin
  Result := prUnknown;
  if Length(APrefix) < 2 then Exit;
  Cur := NewByteCursor(APrefix);
  if TryParseID3v2(APrefix, Tags, Skipped) then Exit(prMp3);
  if Cur.Remaining >= 3 then
    if (APrefix[0]=Ord('I')) and (APrefix[1]=Ord('D')) and (APrefix[2]=Ord('3')) then Exit(prMp3);
  // MP3 sync word: 0xFFE0 via cursor length guard
  if Cur.Remaining >= 2 then
    if (APrefix[0] = $FF) and ((APrefix[1] and $E0) = $E0) then Exit(prMp3);
end;

function TMp3Decoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := Mp3Probe(APrefix);
end;

function TMp3Decoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

constructor TMp3Decoder.Create;
begin
  inherited Create;
  FInit := False;
  FillChar(FDec, SizeOf(FDec), 0);
end;

procedure TMp3Decoder.EnsureArena;
begin
  if FInit then Exit;
  mp3dec_init(@FDec);
  FInit := True;
end;

function TMp3Decoder.DecodeBytesInternal(const AData: TBytes): TAudioBuffer;
var
  Len, Off: LongInt;
  N, CH, SR: LongInt;
  Info: TMp3decFrameInfoT;
  Pcm: array[0..2304*2-1] of SmallInt;
  LOutPos, LTotalFrames: Integer;
  LFormat: TAudioFormat;
  LHasFormat: Boolean;
  Skipped: Integer;
  TmpTags: TAudioTags;
begin
  Result := Default(TAudioBuffer);
  FTags := Default(TAudioTags);
  if TryParseID3v2(AData, TmpTags, Skipped) then FTags := TmpTags else Skipped := 0;
  EnsureArena;
  mp3dec_init(@FDec);
  Len := Length(AData);
  Off := Skipped;
  if Off < 0 then Off := 0;
  if Off >= Len then raise EAudioDecodeError.Create('mp3: no audio after ID3');
  LHasFormat := False;
  LTotalFrames := 0;
  LOutPos := 0;
  // 复用 FOut：首跑分配 ~Len*11（41KB→460KB），后 420 次零分配
  if FOutCap < Len * 11 then
  begin
    FOutCap := Len * 11;
    if FOutCap < 4096 * 4 then FOutCap := 4096 * 4;
    if FOutCap > 1024*1024*32 then FOutCap := 1024*1024*32;
    SetLength(FOut, FOutCap);
  end;
  while Off < Len do
  begin
    N := mp3dec_decode_frame(@FDec, @AData[Off], Len - Off, @Pcm[0], @Info);
    if Info.frame_bytes > 0 then Inc(Off, Info.frame_bytes) else Inc(Off);
    if N > 0 then
    begin
      CH := Info.channels;
      SR := Info.hz;
      if not LHasFormat then
      begin
        if (SR < MinAudioSampleRate) or (SR > MaxAudioSampleRate) then SR := 44100;
        if (CH < 1) or (CH > MaxAudioChannels) then CH := 2;
        LFormat := AudioFormatCreate(SR, CH, sfF32);
        LHasFormat := True;
      end;
      if LOutPos + N * CH * 4 > FOutCap then
      begin
        while LOutPos + N * CH * 4 > FOutCap do FOutCap := FOutCap * 2;
        SetLength(FOut, FOutCap);
      end;
      PcmConvertS16BlockToF32(@Pcm[0], 1.0/32768.0, PSingle(@FOut[LOutPos]), LongWord(N * CH));
      Inc(LOutPos, N * CH * 4);
      Inc(LTotalFrames, N);
    end
    else if N = 0 then
    begin
      if Info.frame_bytes = 0 then Break;
      Continue;
    end else Break;
  end;
  if not LHasFormat then raise EAudioDecodeError.Create('mp3: decode failed');
  SetLength(Result.Data, LOutPos);
  if LOutPos > 0 then Move(FOut[0], Result.Data[0], LOutPos);
  Result.Format := LFormat;
  Result.FrameCount := LTotalFrames;
end;

function TMp3Decoder.DecodeBytes(const AData: TBytes): TAudioBuffer;
begin
  Result := DecodeBytesInternal(AData);
end;

function Mp3DecodeBytes(const AData: TBytes): TAudioBuffer;
begin
  if GReuseMp3 = nil then GReuseMp3 := TMp3Decoder.Create;
  Result := GReuseMp3.DecodeBytesInternal(AData);
end;

function TMp3Decoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
var
  LData: TBytes;
  LAvail: Int64;
  LRead: LongInt;
begin
  if AStream = nil then raise EAudioDecodeError.Create('mp3: nil stream');
  LAvail := AStream.Size - AStream.Position;
  if LAvail <= 0 then raise EAudioDecodeError.Create('mp3: empty stream');
  if LAvail > 1024*1024*256 then raise EAudioDecodeError.Create('mp3: stream too large');
  SetLength(LData, LAvail);
  LRead := AStream.Read(LData[0], LongInt(LAvail));
  if LRead <> LAvail then raise EAudioDecodeError.Create('mp3: read failed');
  Result := DecodeBytesInternal(LData);
end;

function TMp3Decoder.OpenStreaming(const AStream: IStream): IAudioSource;
var
  LBuf: TAudioBuffer;
begin
  LBuf := DecodeWhole(AStream);
  Result := TMemoryMp3Source.Create(LBuf);
end;

function CreateMp3Decoder: IAudioDecoder;
begin
  Result := TMp3Decoder.Create;
end;

end.
