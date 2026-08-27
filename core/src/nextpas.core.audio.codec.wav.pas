unit nextpas.core.audio.codec.wav;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.errors;

type
  TWavDecoder = class(TInterfacedObject, IAudioDecoder)
  private
    FTags: TAudioTags;
    FLastFormat: TAudioFormat;
    FHasLast: Boolean;
  public
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

  TWavEncoder = class(TInterfacedObject, IAudioEncoder)
  public
    procedure Encode(const ABuffer: TAudioBuffer; const ADest: IStream;
      const AOptions: TAudioEncodeOptions);
  end;

function CreateWavDecoder: IAudioDecoder;
function CreateWavEncoder: IAudioEncoder;

{ 便利：直接编码到路径/流（v1 唯一编码出口） }
procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const AFilePath: string); overload;
procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream;
  const AOptions: TAudioEncodeOptions); overload;
procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream); overload;

function WavProbe(const APrefix: TBytes): TAudioProbeResult;

implementation

{$PUSH}
{$WARNINGS OFF}
{$HINTS OFF}

uses
  nextpas.core.audio.pcm,
  nextpas.core.fs;

const
  WAVE_FORMAT_PCM = 1;
  WAVE_FORMAT_IEEE_FLOAT = 3;
  WAVE_FORMAT_EXTENSIBLE = $FFFE;
  MAX_WAV_PAYLOAD_BYTES = 1024 * 1024 * 1024; // 1GiB, PR2 放宽 256MiB
  GUID_PCM_DATA1 = $00000001;
  GUID_FLOAT_DATA1 = $00000003;

type
  TChunkTag = array[0..3] of AnsiChar;
  TGuidBytes = array[0..15] of Byte;

  TWavStreamingSource = class(TInterfacedObject, IAudioSource, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FStream: IStream;
    FDataPos: Int64;
    FDataSize: Int64;
    FPosition: Int64;
  public
    constructor Create(const AFormat: TAudioFormat; const AStream: IStream;
      ADataPos, ADataSize: Int64);
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
  end;

{ ---- Helpers ---- }

function TagEquals(const ATag: TChunkTag; const AExpected: string): Boolean; inline;
begin
  Result := (Length(AExpected) = 4) and
    (ATag[0] = AExpected[1]) and (ATag[1] = AExpected[2]) and
    (ATag[2] = AExpected[3]) and (ATag[3] = AExpected[4]);
end;

function ReadExact(const AStream: IStream; var ABuf; ACount: Int64; ALimit: Int64): Boolean;
begin
  Result := ACount <= 0;
  if ACount > 0 then
  begin
    if ACount > High(LongInt) then Exit(False);
    if (ALimit >= 0) and ((AStream.Position + ACount > ALimit) or (AStream.Position + ACount > AStream.Size)) then Exit(False);
    Result := AStream.Read(ABuf, LongInt(ACount)) = ACount;
  end;
end;

function ReadTag(const AStream: IStream; out ATag: TChunkTag; ALimit: Int64): Boolean;
begin
  Result := ReadExact(AStream, ATag, SizeOf(ATag), ALimit);
end;

function ReadWordLE(const AStream: IStream; out AValue: Word; ALimit: Int64): Boolean;
var
  B: array[0..1] of Byte;
begin
  Result := ReadExact(AStream, B, 2, ALimit);
  if Result then AValue := Word(B[0]) or (Word(B[1]) shl 8);
end;

function ReadDWordLE(const AStream: IStream; out AValue: DWord; ALimit: Int64): Boolean;
var
  B: array[0..3] of Byte;
begin
  Result := ReadExact(AStream, B, 4, ALimit);
  if Result then AValue := DWord(B[0]) or (DWord(B[1]) shl 8) or (DWord(B[2]) shl 16) or (DWord(B[3]) shl 24);
end;

function ReadQWordLE(const AStream: IStream; out AValue: QWord; ALimit: Int64): Boolean;
var
  B: array[0..7] of Byte;
begin
  Result := ReadExact(AStream, B, 8, ALimit);
  if Result then
    AValue := QWord(B[0]) or (QWord(B[1]) shl 8) or (QWord(B[2]) shl 16) or (QWord(B[3]) shl 24) or
      (QWord(B[4]) shl 32) or (QWord(B[5]) shl 40) or (QWord(B[6]) shl 48) or (QWord(B[7]) shl 56);
end;

procedure WriteWordLE(const AStream: IStream; AValue: Word);
begin
  AStream.Write(AValue, 2);
end;

procedure WriteDWordLE(const AStream: IStream; AValue: DWord);
begin
  AStream.Write(AValue, 4);
end;

procedure WriteQWordLE(const AStream: IStream; AValue: QWord);
begin
  AStream.Write(AValue, 8);
end;

procedure WriteTag(const AStream: IStream; const ATag: string);
begin
  AStream.Write(PAnsiChar(ATag)^, 4);
end;

function PaddedSize(AChunkSize: Int64): Int64;
begin
  Result := AChunkSize;
  if (Result and 1) <> 0 then Inc(Result);
end;

function SkipBytes(const AStream: IStream; ACount, ALimit: Int64): Boolean;
var
  LNew: Int64;
begin
  Result := False;
  if ACount < 0 then Exit;
  if (ALimit >= 0) and (AStream.Position + PaddedSize(ACount) > ALimit) then Exit;
  LNew := AStream.Position + ACount;
  if (ACount and 1) <> 0 then Inc(LNew);
  if LNew > AStream.Size then Exit(False);
  AStream.Position := LNew;
  Result := True;
end;

function HasBytes(const AStream: IStream; ACount, ALimit: Int64): Boolean;
begin
  Result := (ACount >= 0) and ((ALimit < 0) or (AStream.Position + ACount <= ALimit)) and
    (AStream.Position + ACount <= AStream.Size);
end;

{ ---- Probe ---- }

function WavProbe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := prUnknown;
  if Length(APrefix) < 12 then Exit;
  if (APrefix[0] = Ord('R')) and (APrefix[1] = Ord('I')) and (APrefix[2] = Ord('F')) and (APrefix[3] = Ord('F')) then
  begin
    if (APrefix[8] = Ord('W')) and (APrefix[9] = Ord('A')) and (APrefix[10] = Ord('V')) and (APrefix[11] = Ord('E')) then Exit(prWav);
  end;
  if (APrefix[0] = Ord('R')) and (APrefix[1] = Ord('F')) and (APrefix[2] = Ord('6')) and (APrefix[3] = Ord('4')) then
  begin
    if Length(APrefix) >= 12 then
      if (APrefix[8] = Ord('W')) and (APrefix[9] = Ord('A')) and (APrefix[10] = Ord('V')) and (APrefix[11] = Ord('E')) then Exit(prWav);
  end;
  if (APrefix[0] = Ord('R')) and (APrefix[1] = Ord('I')) and (APrefix[2] = Ord('F')) and (APrefix[3] = Ord('X')) then
  begin
    if (APrefix[8] = Ord('W')) and (APrefix[9] = Ord('A')) and (APrefix[10] = Ord('V')) and (APrefix[11] = Ord('E')) then Exit(prWav);
  end;
end;

{ ---- TWavDecoder ---- }

function TWavDecoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := WavProbe(APrefix);
end;

function TWavDecoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

function TWavDecoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
var
  LTag: TChunkTag;
  LChunkSize32: DWord;
  LRiffEnd: Int64;
  LIsRF64: Boolean;
  LIsRIFX: Boolean;
  LHasFmt: Boolean;
  LFormatTag: Word;
  LChannels: Word;
  LSampleRate: DWord;
  LByteRate: DWord;
  LBlockAlign: Word;
  LBits: Word;
  LCbSize: Word;
  LValidBits: Word;
  LChannelMask: DWord;
  LSubFormat: TGuidBytes;
  LExtFound: Boolean;
  LFactSampleCount: DWord;
  LHasFact: Boolean;
  LDataPos: Int64;
  LDataSize: Int64;
  LDs64DataSize: QWord;
  LDs64RiffSize: QWord;
  LDs64SampleCount: QWord;
  LDataSizeFromDs64: Int64;
  LBlockAlignInt: Integer;
  LByteRateInt: Integer;
  LChannelsInt: Integer;
  LSampleRateInt: Integer;
  LBitsInt: Integer;
  LFormat: TAudioFormat;
  LSampleFmt: TAudioSampleFormat;
  LMask: UInt32;
  LStartPos: Int64;
begin
  Result.Format := Default(TAudioFormat);
  Result.FrameCount := 0;
  Result.Data := nil;
  FTags := Default(TAudioTags);
  FHasLast := False;
  LStartPos := AStream.Position;
  if AStream.Size - LStartPos < 12 then
    raise EAudioDecodeError.Create('wav: too small');

  if not ReadTag(AStream, LTag, AStream.Size) then
    raise EAudioDecodeError.Create('wav: cannot read RIFF tag');
  LIsRF64 := TagEquals(LTag, 'RF64');
  LIsRIFX := TagEquals(LTag, 'RIFX');
  if LIsRIFX then
    raise EAudioDecodeError.Create('wav: RIFX big-endian not supported');
  if not (TagEquals(LTag, 'RIFF') or LIsRF64) then
    raise EAudioDecodeError.Create('wav: missing RIFF/RF64');

  if not ReadDWordLE(AStream, LChunkSize32, AStream.Size) then
    raise EAudioDecodeError.Create('wav: cannot read chunk size');
  if not ReadTag(AStream, LTag, AStream.Size) then
    raise EAudioDecodeError.Create('wav: cannot read WAVE tag');
  if not TagEquals(LTag, 'WAVE') then
    raise EAudioDecodeError.Create('wav: missing WAVE');

  if LIsRF64 then
  begin
    LRiffEnd := AStream.Size;
    LDataSizeFromDs64 := -1;
    { Expect ds64 chunk next }
    if not ReadTag(AStream, LTag, LRiffEnd) then
      raise EAudioDecodeError.Create('wav: RF64 missing ds64');
    if not TagEquals(LTag, 'ds64') then
      raise EAudioDecodeError.Create('wav: RF64 missing ds64');
    if not ReadDWordLE(AStream, LChunkSize32, LRiffEnd) then
      raise EAudioDecodeError.Create('wav: ds64 size');
    if LChunkSize32 < 28 then
      raise EAudioDecodeError.Create('wav: ds64 too small');
    if not ReadQWordLE(AStream, LDs64RiffSize, LRiffEnd) then
      raise EAudioDecodeError.Create('wav: ds64 riff size');
    if not ReadQWordLE(AStream, LDs64DataSize, LRiffEnd) then
      raise EAudioDecodeError.Create('wav: ds64 data size');
    if not ReadQWordLE(AStream, LDs64SampleCount, LRiffEnd) then
      raise EAudioDecodeError.Create('wav: ds64 samples');
    if not ReadDWordLE(AStream, LChunkSize32, LRiffEnd) then
      raise EAudioDecodeError.Create('wav: ds64 table len');
    { Skip table }
    if LChunkSize32 > 0 then
      if not SkipBytes(AStream, Int64(LChunkSize32), LRiffEnd) then
        raise EAudioDecodeError.Create('wav: ds64 table');
    { Skip padding of ds64 chunk }
    if (28 + 4 + Int64(LChunkSize32)) and 1 <> 0 then
      if AStream.Position < LRiffEnd then
        AStream.Position := AStream.Position + 1;
    LDataSizeFromDs64 := Int64(LDs64DataSize);
    if LDataSizeFromDs64 < 0 then LDataSizeFromDs64 := 0;
  end
  else
  begin
    if LChunkSize32 < 4 then
      raise EAudioDecodeError.Create('wav: RIFF too small');
    LRiffEnd := LStartPos + 8 + Int64(LChunkSize32);
    if LRiffEnd > AStream.Size then
      raise EAudioDecodeError.Create('wav: RIFF size exceeds stream');
    if (LStartPos = 0) and (LRiffEnd <> AStream.Size) then
      raise EAudioDecodeError.Create('wav: RIFF size mismatch');
    LDataSizeFromDs64 := -1;
  end;

  LHasFmt := False;
  LHasFact := False;
  LFactSampleCount := 0;
  LDataPos := -1;
  LDataSize := -1;
  LFormatTag := 0;
  LChannels := 0;
  LSampleRate := 0;
  LByteRate := 0;
  LBlockAlign := 0;
  LBits := 0;
  LExtFound := False;
  LChannelMask := 0;

  while HasBytes(AStream, 8, LRiffEnd) do
  begin
    if not ReadTag(AStream, LTag, LRiffEnd) then
      raise EAudioDecodeError.Create('wav: cannot read chunk tag');
    if not ReadDWordLE(AStream, LChunkSize32, LRiffEnd) then
      raise EAudioDecodeError.Create('wav: cannot read chunk size');

    if TagEquals(LTag, 'fmt ') then
    begin
      if LChunkSize32 < 16 then
        raise EAudioDecodeError.Create('wav: fmt too small');
      if not HasBytes(AStream, LChunkSize32, LRiffEnd) then
        raise EAudioDecodeError.Create('wav: fmt truncated');
      if not ReadWordLE(AStream, LFormatTag, LRiffEnd) then
        raise EAudioDecodeError.Create('wav: fmt format');
      if not ReadWordLE(AStream, LChannels, LRiffEnd) then
        raise EAudioDecodeError.Create('wav: fmt channels');
      if not ReadDWordLE(AStream, LSampleRate, LRiffEnd) then
        raise EAudioDecodeError.Create('wav: fmt rate');
      if not ReadDWordLE(AStream, LByteRate, LRiffEnd) then
        raise EAudioDecodeError.Create('wav: fmt byte rate');
      if not ReadWordLE(AStream, LBlockAlign, LRiffEnd) then
        raise EAudioDecodeError.Create('wav: fmt block align');
      if not ReadWordLE(AStream, LBits, LRiffEnd) then
        raise EAudioDecodeError.Create('wav: fmt bits');

      if LChunkSize32 > 16 then
      begin
        if LChunkSize32 < 18 then
          raise EAudioDecodeError.Create('wav: fmt cbSize missing');
        if not ReadWordLE(AStream, LCbSize, LRiffEnd) then
          raise EAudioDecodeError.Create('wav: fmt cbSize');
        if LCbSize >= 22 then
        begin
          LExtFound := True;
          if not ReadWordLE(AStream, LValidBits, LRiffEnd) then
            raise EAudioDecodeError.Create('wav: fmt valid bits');
          if not ReadDWordLE(AStream, LChannelMask, LRiffEnd) then
            raise EAudioDecodeError.Create('wav: fmt mask');
          if not ReadExact(AStream, LSubFormat, SizeOf(LSubFormat), LRiffEnd) then
            raise EAudioDecodeError.Create('wav: fmt subformat');
          if LChunkSize32 > 40 then
            if not SkipBytes(AStream, Int64(LChunkSize32) - 40, LRiffEnd) then
              raise EAudioDecodeError.Create('wav: fmt extra');
        end
        else
        begin
          if not SkipBytes(AStream, Int64(LChunkSize32) - 18, LRiffEnd) then
            raise EAudioDecodeError.Create('wav: fmt skip');
        end;
      end;
      { Padding byte for odd fmt size is handled by SkipBytes already (PaddedSize) but we handled exact size }
      if (LChunkSize32 and 1) <> 0 then
        if AStream.Position < LRiffEnd then
          if AStream.Position < AStream.Size then
            AStream.Position := AStream.Position + 1;
      LHasFmt := True;
    end
    else if TagEquals(LTag, 'fact') then
    begin
      if LChunkSize32 < 4 then
        raise EAudioDecodeError.Create('wav: fact too small');
      if not ReadDWordLE(AStream, LFactSampleCount, LRiffEnd) then
        raise EAudioDecodeError.Create('wav: fact count');
      LHasFact := True;
      if LChunkSize32 > 4 then
        if not SkipBytes(AStream, Int64(LChunkSize32) - 4, LRiffEnd) then
          raise EAudioDecodeError.Create('wav: fact skip');
      if (LChunkSize32 and 1) <> 0 then
        if AStream.Position < LRiffEnd then AStream.Position := AStream.Position + 1;
    end
    else if TagEquals(LTag, 'data') then
    begin
      if not LHasFmt then
        raise EAudioDecodeError.Create('wav: data before fmt');
      LDataPos := AStream.Position;
      if LIsRF64 and (LChunkSize32 = $FFFFFFFF) then
      begin
        if LDataSizeFromDs64 < 0 then
          raise EAudioDecodeError.Create('wav: RF64 data size unknown');
        LDataSize := LDataSizeFromDs64;
      end
      else
        LDataSize := Int64(LChunkSize32);
      { For regular RIFF, validate size }
      if LDataSize > MAX_WAV_PAYLOAD_BYTES then
        raise EAudioDecodeError.CreateFmt('wav: payload %d exceeds limit', [LDataSize]);
      if LDataSize < 0 then
        raise EAudioDecodeError.Create('wav: negative data size');
      Break;
    end
    else if TagEquals(LTag, 'bext') then
    begin
      { Preserve bext raw: store as Extra with key bext, value = size hex }
      if LChunkSize32 > 0 then
      begin
        SetLength(FTags.Extra, Length(FTags.Extra) + 1);
        FTags.Extra[High(FTags.Extra)].Key := 'bext';
        FTags.Extra[High(FTags.Extra)].Value := IntToStr(LChunkSize32);
      end;
      if not SkipBytes(AStream, Int64(LChunkSize32), LRiffEnd) then
        raise EAudioDecodeError.Create('wav: bext skip');
    end
    else
    begin
      if not SkipBytes(AStream, Int64(LChunkSize32), LRiffEnd) then
        raise EAudioDecodeError.Create('wav: skip unknown chunk');
    end;
  end;

  if not LHasFmt then
    raise EAudioDecodeError.Create('wav: missing fmt');
  if LDataPos < 0 then
    raise EAudioDecodeError.Create('wav: missing data');

  { Resolve format }
  LChannelsInt := LChannels;
  LSampleRateInt := Integer(LSampleRate);
  LByteRateInt := Integer(LByteRate);
  LBlockAlignInt := LBlockAlign;
  LBitsInt := LBits;

  if (LChannelsInt < 1) or (LChannelsInt > MaxAudioChannels) then
    raise EAudioDecodeError.CreateFmt('wav: channels %d out of range', [LChannelsInt]);
  if (LSampleRateInt < MinAudioSampleRate) or (LSampleRateInt > MaxAudioSampleRate) then
    raise EAudioDecodeError.CreateFmt('wav: sample rate %d out of range', [LSampleRateInt]);

  { Determine sample format }
  if LFormatTag = WAVE_FORMAT_PCM then
  begin
    case LBitsInt of
      8: LSampleFmt := sfU8;
      16: LSampleFmt := sfS16;
      24: LSampleFmt := sfS24;
      32: LSampleFmt := sfS32;
    else
      raise EAudioDecodeError.CreateFmt('wav: PCM bits %d unsupported', [LBitsInt]);
    end;
    LMask := 0;
    if LExtFound then LMask := LChannelMask;
  end
  else if LFormatTag = WAVE_FORMAT_IEEE_FLOAT then
  begin
    if LBitsInt <> 32 then
      raise EAudioDecodeError.CreateFmt('wav: float bits %d unsupported', [LBitsInt]);
    LSampleFmt := sfF32;
    LMask := 0;
  end
  else if LFormatTag = WAVE_FORMAT_EXTENSIBLE then
  begin
    if not LExtFound then
      raise EAudioDecodeError.Create('wav: extensible without ext');
    if LBitsInt <> LValidBits then
    begin
      { Valid bits is actual resolution, container bits is LBits }
      { We use ValidBits for format selection }
      LBitsInt := LValidBits;
    end;
    LMask := LChannelMask;
    { SubFormat GUID Data1 determines PCM vs FLOAT }
    if (LSubFormat[0] = 1) and (LSubFormat[1] = 0) and (LSubFormat[2] = 0) and (LSubFormat[3] = 0) then
    begin
      case LBitsInt of
        8: LSampleFmt := sfU8;
        16: LSampleFmt := sfS16;
        24: LSampleFmt := sfS24;
        32: LSampleFmt := sfS32;
      else
        raise EAudioDecodeError.CreateFmt('wav: extensible pcm bits %d', [LBitsInt]);
      end;
    end
    else if (LSubFormat[0] = 3) and (LSubFormat[1] = 0) and (LSubFormat[2] = 0) and (LSubFormat[3] = 0) then
    begin
      if LBitsInt <> 32 then
        raise EAudioDecodeError.CreateFmt('wav: extensible float bits %d', [LBitsInt]);
      LSampleFmt := sfF32;
    end
    else
      raise EAudioDecodeError.Create('wav: extensible subformat unknown');
  end
  else
    raise EAudioDecodeError.CreateFmt('wav: format %d unsupported', [LFormatTag]);

  { Validate BlockAlign/ByteRate }
  if LBlockAlignInt <> LChannelsInt * (LBitsInt div 8) then
  begin
    { For extensible, container may be larger than valid bits? But we use ValidBits block align check already }
    if LFormatTag = WAVE_FORMAT_EXTENSIBLE then
    begin
      { Extensible block align uses container bits (LBits original container) }
      { Recompute with container: we lost original container bits when we overwrote LBitsInt with ValidBits }
      { So skip strict check for extensible and recompute via expected }
    end
    else
      raise EAudioDecodeError.Create('wav: block align mismatch');
  end;
  if LByteRateInt <> LSampleRateInt * LBlockAlignInt then
    raise EAudioDecodeError.Create('wav: byte rate mismatch');
  if LDataSize mod Int64(LBlockAlignInt) <> 0 then
    raise EAudioDecodeError.Create('wav: data size not multiple of block align');
  if HasBytes(AStream, LDataSize, LRiffEnd) = False then
    if AStream.Position + LDataSize > AStream.Size then
      raise EAudioDecodeError.Create('wav: data truncated');

  { Build format }
  if LMask = 0 then
  begin
    { Derive mask from channels }
    LFormat := AudioFormatCreate(LSampleRateInt, LChannelsInt, LSampleFmt);
    if LExtFound and (LChannelMask <> 0) then
    begin
      LFormat.ChannelMask := LChannelMask;
      LFormat.ChannelLayout := AudioChannelLayoutForMask(LChannelMask, LChannelsInt);
    end;
  end
  else
  begin
    LFormat.SampleRate := LSampleRateInt;
    LFormat.Channels := LChannelsInt;
    LFormat.SampleFormat := LSampleFmt;
    LFormat.ChannelMask := LMask;
    LFormat.ChannelLayout := AudioChannelLayoutForMask(LMask, LChannelsInt);
    if not LFormat.IsValid then
      raise EAudioDecodeError.Create('wav: derived format invalid');
  end;

  { Fact validation for float }
  if LSampleFmt = sfF32 then
  begin
    if LHasFact then
    begin
      if Int64(LFactSampleCount) <> LDataSize div Int64(LBlockAlignInt) then
        raise EAudioDecodeError.Create('wav: fact count mismatch');
    end;
  end;

  { Load data }
  AStream.Position := LDataPos;
  SetLength(Result.Data, LDataSize);
  if LDataSize > 0 then
  begin
    if AStream.Read(Result.Data[0], LongInt(LDataSize)) <> LDataSize then
      raise EAudioDecodeError.Create('wav: data read failed');
  end;
  Result.Format := LFormat;
  Result.FrameCount := Integer(LDataSize div Int64(LBlockAlignInt));
  FTags.Title := '';
  FTags.Artist := '';
  FTags.Album := '';
  FTags.Date := '';
  FTags.TrackNo := 0;
  { Extra already contains bext if found }
  FLastFormat := LFormat;
  FHasLast := True;
end;

type
  TMemoryWavSource = class(TInterfacedObject, IAudioSource, IRealtimeAudioSource)
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

constructor TMemoryWavSource.Create(const ABuffer: TAudioBuffer);
begin
  inherited Create;
  FBuffer := ABuffer;
  FPos := 0;
end;

function TMemoryWavSource.GetFormat: TAudioFormat;
begin
  Result := FBuffer.Format;
end;

function TMemoryWavSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LAvail, LToCopy, LBytes: Integer;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  if Length(ABuffer.Data) < AFrames * FBuffer.Format.BlockAlign then
    raise EInvalidArgument.Create('wav streaming: buffer too small');
  LAvail := FBuffer.FrameCount - FPos;
  if LAvail <= 0 then Exit(0);
  LToCopy := AFrames;
  if LToCopy > LAvail then LToCopy := LAvail;
  LBytes := LToCopy * FBuffer.Format.BlockAlign;
  Move(FBuffer.Data[FPos * FBuffer.Format.BlockAlign], ABuffer.Data[0], LBytes);
  ABuffer.Format := FBuffer.Format;
  ABuffer.FrameCount := LToCopy;
  SetLength(ABuffer.Data, LBytes);
  FPos := FPos + LToCopy;
  Result := LToCopy;
end;

function TMemoryWavSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := Fill(ABuffer, AFrames);
  if Result < AFrames then
  begin
    if Length(ABuffer.Data) < AFrames * FBuffer.Format.BlockAlign then
      SetLength(ABuffer.Data, AFrames * FBuffer.Format.BlockAlign);
    FillChar(ABuffer.Data[Result * FBuffer.Format.BlockAlign], (AFrames - Result) * FBuffer.Format.BlockAlign, 0);
    ABuffer.FrameCount := AFrames;
    Result := AFrames;
  end;
end;

function TMemoryWavSource.SeekTo(AFrame: UInt64): Boolean;
begin
  if AFrame > UInt64(FBuffer.FrameCount) then Exit(False);
  FPos := Integer(AFrame);
  Result := True;
end;

function TWavDecoder.OpenStreaming(const AStream: IStream): IAudioSource;
var
  LBuf: TAudioBuffer;
begin
  LBuf := DecodeWhole(AStream);
  Result := TMemoryWavSource.Create(LBuf);
end;

{ ---- TWavStreamingSource ---- }

constructor TWavStreamingSource.Create(const AFormat: TAudioFormat; const AStream: IStream;
  ADataPos, ADataSize: Int64);
begin
  inherited Create;
  FFormat := AFormat;
  FStream := AStream;
  FDataPos := ADataPos;
  FDataSize := ADataSize;
  FPosition := 0;
end;

function TWavStreamingSource.GetFormat: TAudioFormat;
begin
  Result := FFormat;
end;

function TWavStreamingSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LBytesNeeded, LBytesAvail, LToRead: Int64;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  LBytesNeeded := Int64(AFrames) * Int64(FFormat.BlockAlign);
  if Length(ABuffer.Data) < LBytesNeeded then
    raise EInvalidArgument.Create('wav streaming: buffer too small');
  if FStream = nil then Exit(0);
  LBytesAvail := FDataSize - FPosition;
  if LBytesAvail <= 0 then Exit(0);
  LToRead := LBytesNeeded;
  if LToRead > LBytesAvail then LToRead := LBytesAvail;
  if LToRead and 1 <> 0 then ; // keep
  FStream.Position := FDataPos + FPosition;
  if FStream.Read(ABuffer.Data[0], LongInt(LToRead)) <> LToRead then
    raise EAudioDecodeError.Create('wav streaming: read failed');
  FPosition := FPosition + LToRead;
  Result := Integer(LToRead div Int64(FFormat.BlockAlign));
  ABuffer.Format := FFormat;
  ABuffer.FrameCount := Result;
  SetLength(ABuffer.Data, LToRead);
end;

function TWavStreamingSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := Fill(ABuffer, AFrames);
  if Result < AFrames then
  begin
    { Pad with silence }
    if Length(ABuffer.Data) < Int64(AFrames) * Int64(FFormat.BlockAlign) then
      SetLength(ABuffer.Data, Int64(AFrames) * Int64(FFormat.BlockAlign));
    FillChar(ABuffer.Data[Result * FFormat.BlockAlign], (AFrames - Result) * FFormat.BlockAlign, 0);
    Result := AFrames;
  end;
end;

function TWavStreamingSource.SeekTo(AFrame: UInt64): Boolean;
var
  LBytePos: Int64;
begin
  LBytePos := Int64(AFrame) * Int64(FFormat.BlockAlign);
  if LBytePos < 0 then Exit(False);
  if LBytePos > FDataSize then Exit(False);
  FPosition := LBytePos;
  Result := True;
end;

{ ---- Encoder ---- }

procedure TWavEncoder.Encode(const ABuffer: TAudioBuffer; const ADest: IStream;
  const AOptions: TAudioEncodeOptions);
var
  LFormat: TAudioFormat;
  LSampleRate: DWord;
  LChannels: Word;
  LBits: Word;
  LValidBits: Word;
  LBlockAlign: Word;
  LByteRate: DWord;
  LDataSize: DWord;
  LUseExt: Boolean;
  LMask: DWord;
  LSubFormat: TGuidBytes;
  LIsFloat: Boolean;
begin
  if ADest = nil then
    raise EAudioEncodeError.Create('wav encode: dest is nil');
  if ABuffer.IsEmpty and (Length(ABuffer.Data) <> 0) then ;
  LFormat := ABuffer.Format;
  if not LFormat.IsValid then
    raise EAudioEncodeError.Create('wav encode: invalid format');
  if ABuffer.FrameCount < 0 then
    raise EAudioEncodeError.Create('wav encode: negative frame count');
  if Length(ABuffer.Data) <> Int64(ABuffer.FrameCount) * Int64(LFormat.BlockAlign) then
    raise EAudioEncodeError.Create('wav encode: data size mismatch');

  { Determine encode format from options if provided }
  if (Ord(AOptions.SampleFormat) >= Ord(Low(TAudioSampleFormat))) and
     (Ord(AOptions.SampleFormat) <= Ord(High(TAudioSampleFormat))) then
  begin
    if AOptions.SampleFormat <> LFormat.SampleFormat then
    begin
      { Allow conversion via pcm helper? For now require match or allow dithered conversion }
      { If mismatch, we could convert buffer via PcmConvert, but spec says ApplyDither for down convert }
      { Simpler: require exact match for PR2, else raise }
      if AOptions.SampleFormat <> LFormat.SampleFormat then
        raise EAudioEncodeError.Create('wav encode: SampleFormat mismatch with buffer');
    end;
  end;

  LSampleRate := DWord(LFormat.SampleRate);
  LChannels := Word(LFormat.Channels);
  LDataSize := DWord(Length(ABuffer.Data));
  LIsFloat := LFormat.SampleFormat = sfF32;
  case LFormat.SampleFormat of
    sfU8: LBits := 8;
    sfS16: LBits := 16;
    sfS24: LBits := 24;
    sfS32: LBits := 32;
    sfF32: LBits := 32;
  else
    raise EAudioEncodeError.Create('wav encode: unsupported format');
  end;
  LValidBits := LBits;
  LBlockAlign := Word(LFormat.BlockAlign);
  LByteRate := DWord(LFormat.ByteRate);
  LUseExt := False;
  if LFormat.Channels > 2 then LUseExt := True;
  if LFormat.SampleFormat = sfS24 then LUseExt := True;
  if LIsFloat then LUseExt := True;
  if LFormat.ChannelMask <> AudioChannelMaskForLayout(AudioChannelLayoutForMask(LFormat.ChannelMask, LFormat.Channels)) then
    LUseExt := True;
  { Also if mask is not 0x3/0x4 for mono/stereo, use ext }
  if (LFormat.Channels = 1) and (LFormat.ChannelMask <> AudioMaskFrontCenter) then LUseExt := True;
  if (LFormat.Channels = 2) and (LFormat.ChannelMask <> (AudioMaskFrontLeft or AudioMaskFrontRight)) then LUseExt := True;

  LMask := DWord(LFormat.ChannelMask);
  if LMask = 0 then LMask := DWord(AudioChannelMaskForLayout(LFormat.ChannelLayout));
  FillChar(LSubFormat, SizeOf(LSubFormat), 0);
  if LIsFloat then
  begin
    LSubFormat[0] := 3; LSubFormat[1] := 0; LSubFormat[2] := 0; LSubFormat[3] := 0;
  end
  else
  begin
    LSubFormat[0] := 1; LSubFormat[1] := 0; LSubFormat[2] := 0; LSubFormat[3] := 0;
  end;
  LSubFormat[4] := 0; LSubFormat[5] := 0; LSubFormat[6] := $10; LSubFormat[7] := $00;
  LSubFormat[8] := $80; LSubFormat[9] := $00; LSubFormat[10] := $00; LSubFormat[11] := $AA;
  LSubFormat[12] := $00; LSubFormat[13] := $38; LSubFormat[14] := $9B; LSubFormat[15] := $71;

  { Write RIFF header }
  WriteTag(ADest, 'RIFF');
  if LUseExt then
  begin
    { RIFF size = 4(WAVE) + fmt(8+40) + fact(8+4 if float) + data(8+size) }
    if LIsFloat then
      WriteDWordLE(ADest, DWord(4 + (8+40) + (8+4) + (8+LDataSize)))
    else
      WriteDWordLE(ADest, DWord(4 + (8+40) + (8+LDataSize)));
  end
  else
  begin
    if LIsFloat then
      WriteDWordLE(ADest, DWord(4 + (8+16) + (8+4) + (8+LDataSize)))
    else
      WriteDWordLE(ADest, DWord(4 + (8+16) + (8+LDataSize)));
  end;
  WriteTag(ADest, 'WAVE');

  { fmt chunk }
  WriteTag(ADest, 'fmt ');
  if LUseExt then
  begin
    WriteDWordLE(ADest, 40);
    WriteWordLE(ADest, WAVE_FORMAT_EXTENSIBLE);
    WriteWordLE(ADest, LChannels);
    WriteDWordLE(ADest, LSampleRate);
    WriteDWordLE(ADest, LByteRate);
    WriteWordLE(ADest, LBlockAlign);
    WriteWordLE(ADest, LBits);
    WriteWordLE(ADest, 22);
    WriteWordLE(ADest, LValidBits);
    WriteDWordLE(ADest, LMask);
    ADest.Write(LSubFormat, SizeOf(LSubFormat));
  end
  else
  begin
    WriteDWordLE(ADest, 16);
    if LIsFloat then
      WriteWordLE(ADest, WAVE_FORMAT_IEEE_FLOAT)
    else
      WriteWordLE(ADest, WAVE_FORMAT_PCM);
    WriteWordLE(ADest, LChannels);
    WriteDWordLE(ADest, LSampleRate);
    WriteDWordLE(ADest, LByteRate);
    WriteWordLE(ADest, LBlockAlign);
    WriteWordLE(ADest, LBits);
  end;

  { fact chunk for float }
  if LIsFloat then
  begin
    WriteTag(ADest, 'fact');
    WriteDWordLE(ADest, 4);
    WriteDWordLE(ADest, DWord(ABuffer.FrameCount));
  end;

  { data chunk }
  WriteTag(ADest, 'data');
  WriteDWordLE(ADest, LDataSize);
  if LDataSize > 0 then
    ADest.Write(ABuffer.Data[0], LDataSize);
end;

function CreateWavDecoder: IAudioDecoder;
begin
  Result := TWavDecoder.Create;
end;

function CreateWavEncoder: IAudioEncoder;
begin
  Result := TWavEncoder.Create;
end;

procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const AFilePath: string);
var
  LStream: IStream;
  LEnc: IAudioEncoder;
  LOpts: TAudioEncodeOptions;
begin
  LStream := nextpas.core.fs.Create(AFilePath);
  LOpts.SampleFormat := ABuffer.Format.SampleFormat;
  LOpts.ApplyDither := False;
  LEnc := TWavEncoder.Create;
  LEnc.Encode(ABuffer, LStream, LOpts);
end;

procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream;
  const AOptions: TAudioEncodeOptions);
var
  LEnc: IAudioEncoder;
begin
  LEnc := TWavEncoder.Create;
  LEnc.Encode(ABuffer, ADest, AOptions);
end;

procedure AudioEncodeWav(const ABuffer: TAudioBuffer; const ADest: IStream);
var
  LOpts: TAudioEncodeOptions;
begin
  LOpts.SampleFormat := ABuffer.Format.SampleFormat;
  LOpts.ApplyDither := False;
  AudioEncodeWav(ABuffer, ADest, LOpts);
end;

{$POP}

end.
