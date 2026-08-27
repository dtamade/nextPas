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
function CreateMp3Decoder: IAudioDecoder;

implementation

uses
  nextpas.core.audio.codec.mp3,
  nextpas.core.audio.errors;

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
  public
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

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
begin
  Result := prUnknown;
  if Length(APrefix) < 2 then Exit;
  if (Length(APrefix) >= 3) and (APrefix[0] = Ord('I')) and (APrefix[1] = Ord('D')) and (APrefix[2] = Ord('3')) then
    Exit(prMp3);
  if (APrefix[0] = $FF) and ((APrefix[1] and $E0) = $E0) then
    Exit(prMp3);
end;

function TMp3Decoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := Mp3Probe(APrefix);
end;

function TMp3Decoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

function DecodeMp3Bytes(const AData: TBytes; out AOut: TAudioBuffer; out ATags: TAudioTags): Boolean;
var
  Dec: TMp3decT;
  Info: TMp3decFrameInfoT;
  Off, Len: LongInt;
  N, CH, SR: LongInt;
  Pcm: array[0..2304*2-1] of SmallInt;
  LOutBytes: TBytes;
  LOutPos, LOutCap, LTotalFrames: Integer;
  LFormat: TAudioFormat;
  LHasFormat: Boolean;
  I: Integer;
  F: Single;
begin
  Result := False;
  AOut := Default(TAudioBuffer);
  ATags := Default(TAudioTags);
  Len := Length(AData);
  if Len < 4 then Exit;
  mp3dec_init(@Dec);
  Off := 0;
  LHasFormat := False;
  LTotalFrames := 0;
  LOutPos := 0;
  LOutCap := 0;
  SetLength(LOutBytes, 0);
  while Off < Len do
  begin
    N := mp3dec_decode_frame(@Dec, @AData[Off], Len - Off, @Pcm[0], @Info);
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
      if LOutPos + N * CH * 4 > LOutCap then
      begin
        if LOutCap = 0 then LOutCap := 4096 * CH * 4;
        while LOutPos + N * CH * 4 > LOutCap do LOutCap := LOutCap * 2;
        SetLength(LOutBytes, LOutCap);
      end;
      for I := 0 to N * CH - 1 do
      begin
        F := Pcm[I] / 32768.0;
        PSingle(@LOutBytes[LOutPos])^ := F;
        Inc(LOutPos, 4);
      end;
      Inc(LTotalFrames, N);
    end
    else if N = 0 then
    begin
      if Info.frame_bytes = 0 then Break;
      Continue;
    end
    else Break;
  end;
  if not LHasFormat then Exit(False);
  SetLength(LOutBytes, LOutPos);
  AOut.Format := LFormat;
  AOut.FrameCount := LTotalFrames;
  AOut.Data := LOutBytes;
  Result := True;
end;

function TMp3Decoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
var
  LData: TBytes;
  LAvail: Int64;
  LRead: LongInt;
begin
  Result := Default(TAudioBuffer);
  FTags := Default(TAudioTags);
  if AStream = nil then raise EAudioDecodeError.Create('mp3: nil stream');
  LAvail := AStream.Size - AStream.Position;
  if LAvail <= 0 then raise EAudioDecodeError.Create('mp3: empty stream');
  if LAvail > 1024*1024*256 then raise EAudioDecodeError.Create('mp3: stream too large');
  SetLength(LData, LAvail);
  LRead := AStream.Read(LData[0], LongInt(LAvail));
  if LRead <> LAvail then raise EAudioDecodeError.Create('mp3: read failed');
  if not DecodeMp3Bytes(LData, Result, FTags) then
    raise EAudioDecodeError.Create('mp3: decode failed');
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
