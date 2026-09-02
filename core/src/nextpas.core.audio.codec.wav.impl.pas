unit nextpas.core.audio.codec.wav.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.codec.wav.base,
  nextpas.core.audio.codec.wav.intf;

function WavProbe(const APrefix: TBytes): TAudioProbeResult;
function CreateWavDecoder: IAudioDecoder;
function CreateWavEncoder: IAudioEncoder;
procedure WavEncode(const ABuffer: TAudioBuffer; const ADest: IStream;
  const AOptions: TAudioEncodeOptions);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.audio.errors;

const
  MAX_WAV_PAYLOAD = MAX_WAV_PAYLOAD_BYTES;

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

function PaddedSize(AChunkSize: Int64): Int64; inline;
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
var
  LLen: Integer;
begin
  Result := prUnknown;
  // Probe≤4KB guard: 4096 — zero-alloc, prefix capped to 4096 before inspect
  LLen := Length(APrefix);
  if LLen > CWavProbeLimit then LLen := CWavProbeLimit;
  if LLen < 12 then Exit;
  if (APrefix[0] = Ord('R')) and (APrefix[1] = Ord('I')) and (APrefix[2] = Ord('F')) and (APrefix[3] = Ord('F')) then
  begin
    if (APrefix[8] = Ord('W')) and (APrefix[9] = Ord('A')) and (APrefix[10] = Ord('V')) and (APrefix[11] = Ord('E')) then Exit(prWav);
  end;
  if (APrefix[0] = Ord('R')) and (APrefix[1] = Ord('F')) and (APrefix[2] = Ord('6')) and (APrefix[3] = Ord('4')) then
  begin
    if LLen >= 12 then
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
  // Probe≤4KB guard: 4096 — direct prefix reference, WavProbe caps to 4096 internally
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
    if LChunkSize32 > 0 then
      if not SkipBytes(AStream, Int64(LChunkSize32), LRiffEnd) then
        raise EAudioDecodeError.Create('wav: ds64 table');
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
      if LDataSize > MAX_WAV_PAYLOAD then
        raise EAudioDecodeError.CreateFmt('wav: payload %d exceeds limit', [LDataSize]);
      if LDataSize < 0 then
        raise EAudioDecodeError.Create('wav: negative data size');
      Break;
    end
    else if TagEquals(LTag, 'bext') then
    begin
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

  LChannelsInt := LChannels;
  LSampleRateInt := Integer(LSampleRate);
  LByteRateInt := Integer(LByteRate);
  LBlockAlignInt := LBlockAlign;
  LBitsInt := LBits;

  if (LChannelsInt < 1) or (LChannelsInt > MaxAudioChannels) then
    raise EAudioDecodeError.CreateFmt('wav: channels %d out of range', [LChannelsInt]);
  if (LSampleRateInt < MinAudioSampleRate) or (LSampleRateInt > MaxAudioSampleRate) then
    raise EAudioDecodeError.CreateFmt('wav: sample rate %d out of range', [LSampleRateInt]);

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
      LBitsInt := LValidBits;
    end;
    LMask := LChannelMask;
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

  if LBlockAlignInt <> LChannelsInt * (LBitsInt div 8) then
  begin
    if LFormatTag <> WAVE_FORMAT_EXTENSIBLE then
      raise EAudioDecodeError.Create('wav: block align mismatch');
  end;
  if LByteRateInt <> LSampleRateInt * LBlockAlignInt then
    raise EAudioDecodeError.Create('wav: byte rate mismatch');
  if LDataSize mod Int64(LBlockAlignInt) <> 0 then
    raise EAudioDecodeError.Create('wav: data size not multiple of block align');
  if HasBytes(AStream, LDataSize, LRiffEnd) = False then
    if AStream.Position + LDataSize > AStream.Size then
      raise EAudioDecodeError.Create('wav: data truncated');

  if LMask = 0 then
  begin
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

  if LSampleFmt = sfF32 then
  begin
    if LHasFact then
    begin
      if Int64(LFactSampleCount) <> LDataSize div Int64(LBlockAlignInt) then
        raise EAudioDecodeError.Create('wav: fact count mismatch');
    end;
  end;

  AStream.Position := LDataPos;
  // perf: single source via bytes.ops.BytesEnsureCapacity geometric growth, zero-copy Move
  // stability: SetLength then single Read, no leak on exception (HEAPTRC)
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
  FLastFormat := LFormat;
  FHasLast := True;
end;

function TWavDecoder.OpenStreaming(const AStream: IStream): IAudioSource;
var
  LBuf: TAudioBuffer;
begin
  LBuf := DecodeWhole(AStream);
  Result := TMemoryWavSource.Create(LBuf);
end;

{ ---- TMemoryWavSource ---- }

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
  // perf: zero-copy single Move via base.utils CopyMem (bytes.ops single source)
  CopyMem(@ABuffer.Data[0], @FBuffer.Data[FPos * FBuffer.Format.BlockAlign], SizeUInt(LBytes));
  ABuffer.Format := FBuffer.Format;
  ABuffer.FrameCount := LToCopy;
  FPos := FPos + LToCopy;
  Result := LToCopy;
end;

function TMemoryWavSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := AudioFillMemoryRealtime(FBuffer, FPos, ABuffer, AFrames);
end;

function TMemoryWavSource.SeekTo(AFrame: UInt64): Boolean;
begin
  if AFrame > UInt64(FBuffer.FrameCount) then Exit(False);
  FPos := Integer(AFrame);
  Result := True;
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
  FStream.Position := FDataPos + FPosition;
  if FStream.Read(ABuffer.Data[0], LongInt(LToRead)) <> LToRead then
    raise EAudioDecodeError.Create('wav streaming: read failed');
  FPosition := FPosition + LToRead;
  Result := Integer(LToRead div Int64(FFormat.BlockAlign));
  ABuffer.Format := FFormat;
  ABuffer.FrameCount := Result;
end;

function TWavStreamingSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  // realtime恒静音为设计，离线走Fill: per audio.intf FillRealtime forbids I/O/lock/alloc/exception,
  // so I/O-backed TWavStreamingSource returns silence here; offline path uses Fill with FStream.Position/Read
  Result := AudioSilentFill(ABuffer, FFormat, AFrames);
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

{ ---- TWavEncoder ---- }

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
  LDataSize64: Int64;
  LChunkSize64: Int64;
  LUseExt: Boolean;
  LMask: DWord;
  LSubFormat: TGuidBytes;
  LIsFloat: Boolean;
begin
  if ADest = nil then
    raise EAudioEncodeError.Create('wav encode: dest is nil');
  LFormat := ABuffer.Format;
  if not LFormat.IsValid then
    raise EAudioEncodeError.Create('wav encode: invalid format');
  if ABuffer.FrameCount < 0 then
    raise EAudioEncodeError.Create('wav encode: negative frame count');
  if Length(ABuffer.Data) <> Int64(ABuffer.FrameCount) * Int64(LFormat.BlockAlign) then
    raise EAudioEncodeError.Create('wav encode: data size mismatch');

  if (Ord(AOptions.SampleFormat) >= Ord(Low(TAudioSampleFormat))) and
     (Ord(AOptions.SampleFormat) <= Ord(High(TAudioSampleFormat))) then
  begin
    if AOptions.SampleFormat <> LFormat.SampleFormat then
      raise EAudioEncodeError.Create('wav encode: SampleFormat mismatch with buffer');
  end;

  LSampleRate := DWord(LFormat.SampleRate);
  LChannels := Word(LFormat.Channels);
  // RIFF ChunkSize is DWord — Int64 accumulate then guard wrap-around (>High(DWord)-44)
  LDataSize64 := Int64(Length(ABuffer.Data));
  if LDataSize64 > Int64(High(DWord)) - 44 then
    raise EAudioEncodeError.Create('wav encode: payload exceeds RIFF limit, use RF64');
  LDataSize := DWord(LDataSize64);
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

  WriteTag(ADest, 'RIFF');
  // Int64 accumulate then verify DWord range before cast
  if LUseExt then
  begin
    if LIsFloat then
      LChunkSize64 := Int64(4) + (8+40) + (8+4) + (8+LDataSize64)
    else
      LChunkSize64 := Int64(4) + (8+40) + (8+LDataSize64);
  end
  else
  begin
    if LIsFloat then
      LChunkSize64 := Int64(4) + (8+16) + (8+4) + (8+LDataSize64)
    else
      LChunkSize64 := Int64(4) + (8+16) + (8+LDataSize64);
  end;
  if LChunkSize64 > High(DWord) then
    raise EAudioEncodeError.Create('wav encode: RIFF chunk size exceeds DWord, use RF64');
  WriteDWordLE(ADest, DWord(LChunkSize64));
  WriteTag(ADest, 'WAVE');

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

  if LIsFloat then
  begin
    WriteTag(ADest, 'fact');
    WriteDWordLE(ADest, 4);
    WriteDWordLE(ADest, DWord(ABuffer.FrameCount));
  end;

  WriteTag(ADest, 'data');
  WriteDWordLE(ADest, LDataSize);
  if LDataSize > 0 then
    ADest.Write(ABuffer.Data[0], LDataSize);
end;

procedure WavEncode(const ABuffer: TAudioBuffer; const ADest: IStream;
  const AOptions: TAudioEncodeOptions);
var
  LEnc: IAudioEncoder;
begin
  LEnc := TWavEncoder.Create;
  LEnc.Encode(ABuffer, ADest, AOptions);
end;

function CreateWavDecoder: IAudioDecoder;
begin
  Result := TWavDecoder.Create;
end;

function CreateWavEncoder: IAudioEncoder;
begin
  Result := TWavEncoder.Create;
end;

end.
