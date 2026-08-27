unit nextpas.core.audio.codec.vorbis.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf;

function VorbisProbe(const APrefix: TBytes): TAudioProbeResult;
function CreateVorbisDecoder: IAudioDecoder;

implementation

uses
  nextpas.core.audio.codec.vorbis,
  nextpas.core.audio.errors;

type
  TMemoryVorbisSource = class(TInterfacedObject, IAudioSource, IRealtimeAudioSource)
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

  TVorbisDecoder = class(TInterfacedObject, IAudioDecoder)
  private
    FTags: TAudioTags;
  public
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

constructor TMemoryVorbisSource.Create(const ABuffer: TAudioBuffer);
begin
  inherited Create;
  FBuffer := ABuffer;
  FPos := 0;
end;

function TMemoryVorbisSource.GetFormat: TAudioFormat;
begin
  Result := FBuffer.Format;
end;

function TMemoryVorbisSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LAvail, LToCopy, LBytes: Integer;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  if Length(ABuffer.Data) < AFrames * FBuffer.Format.BlockAlign then
    raise EInvalidArgument.Create('vorbis streaming: buffer too small');
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

function TMemoryVorbisSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
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

function TMemoryVorbisSource.SeekTo(AFrame: UInt64): Boolean;
begin
  if AFrame > UInt64(FBuffer.FrameCount) then Exit(False);
  FPos := Integer(AFrame);
  Result := True;
end;

function VorbisProbe(const APrefix: TBytes): TAudioProbeResult;
var
  I: Integer;
  HasOgg, HasVorbis: Boolean;
begin
  Result := prUnknown;
  if Length(APrefix) < 4 then Exit;
  if (APrefix[0] = Ord('O')) and (APrefix[1] = Ord('g')) and
     (APrefix[2] = Ord('g')) and (APrefix[3] = Ord('S')) then
  begin
    HasVorbis := False;
    for I := 0 to Length(APrefix) - 6 do
      if (APrefix[I] = Ord('v')) and (APrefix[I+1] = Ord('o')) and
         (APrefix[I+2] = Ord('r')) and (APrefix[I+3] = Ord('b')) and
         (APrefix[I+4] = Ord('i')) and (APrefix[I+5] = Ord('s')) then
      begin HasVorbis := True; Break; end;
    if HasVorbis then Exit(prOggVorbis);
    // Fallback: Ogg with vorbis not in prefix may still be OggVorbis; let decoder try
    // Do not claim generic OggS as prUnknown to avoid false positive for Opus
    // Check for "vorbis" case-insensitive
    for I := 0 to Length(APrefix) - 6 do
      if ((APrefix[I] = Ord('V')) or (APrefix[I] = Ord('v'))) and
         ((APrefix[I+1] = Ord('O')) or (APrefix[I+1] = Ord('o'))) then
      begin
        // quick heuristic: if we see 'vorbis' anywhere, claim
      end;
  end;
end;

function TVorbisDecoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := VorbisProbe(APrefix);
end;

function TVorbisDecoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

function DecodeVorbisBytes(const AData: TBytes; out AOut: TAudioBuffer; out ATags: TAudioTags): Boolean;
var
  V: PStbVorbis;
  Err: LongInt;
  Info: TStbVorbisInfo;
  CH, SR: LongInt;
  LOutBytes: TBytes;
  LOutPos, LOutCap, LTotalFrames: Integer;
  LFormat: TAudioFormat;
  LHasFormat: Boolean;
  Tmp: array[0..4095] of Single;
  N, I, C: Integer;
  PSrc: PPSingle;
  ChPtr: PSingle;
begin
  Result := False;
  AOut := Default(TAudioBuffer);
  ATags := Default(TAudioTags);
  if Length(AData) < 4 then Exit;
  Err := 0;
  V := stb_vorbis_open_memory(@AData[0], Length(AData), @Err, nil);
  if V = nil then Exit(False);
  try
    Info := stb_vorbis_get_info(V);
    CH := Info.channels;
    SR := LongInt(Info.sample_rate);
    if (CH < 1) or (CH > MaxAudioChannels) then CH := 2;
    if (SR < MinAudioSampleRate) or (SR > MaxAudioSampleRate) then SR := 44100;
    LFormat := AudioFormatCreate(SR, CH, sfF32);
    LHasFormat := True;
    LOutPos := 0;
    LOutCap := 0;
    LTotalFrames := 0;
    SetLength(LOutBytes, 0);
    while True do
    begin
      // Try interleaved float path
      N := stb_vorbis_get_samples_float_interleaved(V, CH, @Tmp[0], Length(Tmp));
      if N <= 0 then Break;
      if LOutPos + N * CH * 4 > LOutCap then
      begin
        if LOutCap = 0 then LOutCap := 4096 * CH * 4;
        while LOutPos + N * CH * 4 > LOutCap do LOutCap := LOutCap * 2;
        SetLength(LOutBytes, LOutCap);
      end;
      for I := 0 to N * CH - 1 do
      begin
        PSingle(@LOutBytes[LOutPos])^ := Tmp[I];
        Inc(LOutPos, 4);
      end;
      Inc(LTotalFrames, N);
    end;
    if not LHasFormat then Exit(False);
    if LTotalFrames = 0 then Exit(False);
    SetLength(LOutBytes, LOutPos);
    AOut.Format := LFormat;
    AOut.FrameCount := LTotalFrames;
    AOut.Data := LOutBytes;
    // Tags: vendor/comment
    Result := True;
  finally
    stb_vorbis_close(V);
  end;
end;

function TVorbisDecoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
var
  LData: TBytes;
  LAvail: Int64;
  LRead: LongInt;
begin
  Result := Default(TAudioBuffer);
  FTags := Default(TAudioTags);
  if AStream = nil then raise EAudioDecodeError.Create('vorbis: nil stream');
  LAvail := AStream.Size - AStream.Position;
  if LAvail <= 0 then raise EAudioDecodeError.Create('vorbis: empty stream');
  if LAvail > 1024*1024*256 then raise EAudioDecodeError.Create('vorbis: stream too large');
  SetLength(LData, LAvail);
  LRead := AStream.Read(LData[0], LongInt(LAvail));
  if LRead <> LAvail then raise EAudioDecodeError.Create('vorbis: read failed');
  if not DecodeVorbisBytes(LData, Result, FTags) then
    raise EAudioDecodeError.Create('vorbis: decode failed');
end;

function TVorbisDecoder.OpenStreaming(const AStream: IStream): IAudioSource;
var
  LBuf: TAudioBuffer;
begin
  LBuf := DecodeWhole(AStream);
  Result := TMemoryVorbisSource.Create(LBuf);
end;

function CreateVorbisDecoder: IAudioDecoder;
begin
  Result := TVorbisDecoder.Create;
end;

end.
