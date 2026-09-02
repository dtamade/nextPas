unit nextpas.core.audio.codec.aiff;

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
  TAiffDecoder = class(TInterfacedObject, IAudioDecoder)
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

function CreateAiffDecoder: IAudioDecoder;
function AiffProbe(const APrefix: TBytes): TAudioProbeResult;

implementation

uses
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig,
  nextpas.core.bytes.ops,
  nextpas.core.audio.pcm;

const
  MAX_AIFF_PAYLOAD_BYTES = 1024 * 1024 * 1024;

type
  TChunkTag = array[0..3] of AnsiChar;

  TMemoryAiffSource = class(TInterfacedObject, IAudioSource, IRealtimeAudioSource)
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

{ ---- Helpers ---- }

function TagEquals(const ATag: TChunkTag; const AExpected: string): Boolean; inline;
begin
  Result := (Length(AExpected) = 4) and
    (ATag[0] = AExpected[1]) and (ATag[1] = AExpected[2]) and
    (ATag[2] = AExpected[3]) and (ATag[3] = AExpected[4]);
end;

function TagToString(const ATag: TChunkTag): string; inline;
begin
  SetLength(Result, 4);
  Result[1] := ATag[0];
  Result[2] := ATag[1];
  Result[3] := ATag[2];
  Result[4] := ATag[3];
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

function ReadU16BE(const AStream: IStream; out AValue: Word; ALimit: Int64): Boolean;
var
  B: array[0..1] of Byte;
begin
  Result := ReadExact(AStream, B, 2, ALimit);
  if Result then AValue := (Word(B[0]) shl 8) or Word(B[1]);
end;

function ReadU32BE(const AStream: IStream; out AValue: DWord; ALimit: Int64): Boolean;
var
  B: array[0..3] of Byte;
begin
  Result := ReadExact(AStream, B, 4, ALimit);
  if Result then AValue := (DWord(B[0]) shl 24) or (DWord(B[1]) shl 16) or (DWord(B[2]) shl 8) or DWord(B[3]);
end;

function PaddedSize(AChunkSize: Int64): Int64;
begin
  Result := AChunkSize;
  if (Result and 1) <> 0 then Inc(Result);
end;

function HasBytes(const AStream: IStream; ACount, ALimit: Int64): Boolean;
begin
  Result := (ACount >= 0) and ((ALimit < 0) or (AStream.Position + ACount <= ALimit)) and
    (AStream.Position + ACount <= AStream.Size);
end;

function Extended80ToRate(const AExt: array of Byte): Integer;
const
  KnownRates: array[0..9] of Integer = (8000,11025,16000,22050,44100,48000,88200,96000,176400,192000);
var
  B0, B1: Byte;
  Sign: Integer;
  Exp: Integer;
  Mantissa: QWord;
  LI: Integer;
  DMan, DRate: Double;
  LRounded: Int64;
  LK: Integer;
begin
  Result := 0;
  if Length(AExt) < 10 then Exit(0);
  B0 := AExt[0];
  B1 := AExt[1];
  Sign := (B0 shr 7) and 1;
  if Sign <> 0 then Exit(0);
  Exp := ((B0 and $7F) shl 8) or B1;
  Mantissa := 0;
  for LI := 0 to 7 do
    Mantissa := (Mantissa shl 8) or QWord(AExt[2 + LI]);
  if (Exp = 0) and (Mantissa = 0) then Exit(0);
  if Exp = 32767 then Exit(0);
  if Exp = 0 then
  begin
    DMan := Double(Mantissa);
    DRate := DMan * Power(2.0, -16382 - 63);
  end
  else
  begin
    DMan := Double(Mantissa);
    DRate := DMan * Power(2.0, Exp - 16383 - 63);
  end;
  if (DRate < 0) or IsNan(DRate) or IsInfinite(DRate) then Exit(0);
  LRounded := Round(DRate);
  if (LRounded < 1) or (LRounded > 1000000) then Exit(0);
  for LK := 0 to High(KnownRates) do
  begin
    if Abs(LRounded - KnownRates[LK]) <= 1 then Exit(KnownRates[LK]);
    if (KnownRates[LK] > 0) and (Abs(DRate - KnownRates[LK]) < 1.0) then Exit(KnownRates[LK]);
  end;
  Result := Integer(LRounded);
end;

procedure Swap16Buf(var AData: TBytes; AByteCount: Integer);
var
  LI: Integer;
  B0, B1: Byte;
begin
  LI := 0;
  while LI + 1 < AByteCount do
  begin
    B0 := AData[LI];
    B1 := AData[LI + 1];
    AData[LI] := B1;
    AData[LI + 1] := B0;
    Inc(LI, 2);
  end;
end;

procedure Swap32Buf(var AData: TBytes; AByteCount: Integer);
var
  LI: Integer;
  B0, B1, B2, B3: Byte;
begin
  LI := 0;
  while LI + 3 < AByteCount do
  begin
    B0 := AData[LI];
    B1 := AData[LI + 1];
    B2 := AData[LI + 2];
    B3 := AData[LI + 3];
    AData[LI] := B3;
    AData[LI + 1] := B2;
    AData[LI + 2] := B1;
    AData[LI + 3] := B0;
    Inc(LI, 4);
  end;
end;

procedure Swap24Buf(var AData: TBytes; AByteCount: Integer);
var
  LI: Integer;
  B0, B2: Byte;
begin
  LI := 0;
  while LI + 2 < AByteCount do
  begin
    B0 := AData[LI];
    B2 := AData[LI + 2];
    AData[LI] := B2;
    AData[LI + 2] := B0;
    Inc(LI, 3);
  end;
end;

{ ---- Probe ---- }

function AiffProbe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := prUnknown;
  if Length(APrefix) < 12 then Exit;
  if (APrefix[0] = Ord('F')) and (APrefix[1] = Ord('O')) and (APrefix[2] = Ord('R')) and (APrefix[3] = Ord('M')) then
  begin
    if (APrefix[8] = Ord('A')) and (APrefix[9] = Ord('I')) and (APrefix[10] = Ord('F')) and (APrefix[11] = Ord('F')) then Exit(prAiff);
    if (APrefix[8] = Ord('A')) and (APrefix[9] = Ord('I')) and (APrefix[10] = Ord('F')) and (APrefix[11] = Ord('C')) then Exit(prAiff);
  end;
end;

function TAiffDecoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  Result := AiffProbe(APrefix);
end;

function TAiffDecoder.Tags: TAudioTags;
begin
  Result := FTags;
end;

function TAiffDecoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
var
  LTag: TChunkTag;
  LFormSize: DWord;
  LFormType: TChunkTag;
  LIsAifc: Boolean;
  LRiffEnd: Int64;
  LStartPos: Int64;
  LHasComm: Boolean;
  LChannels: Word;
  LNumFrames: DWord;
  LSampleSize: Word;
  LExt: array[0..9] of Byte;
  LRate: Integer;
  LCompType: TChunkTag;
  LCompNameLen: Byte;
  LChunkSize: DWord;
  LChunkSizeI: Int64;
  LOffset: DWord;
  LBlockSize: DWord;
  LDataPos: Int64;
  LDataSize: Int64;
  LChannelsInt: Integer;
  LSampleRateInt: Integer;
  LBitsInt: Integer;
  LBlockAlignInt: Integer;
  LFormat: TAudioFormat;
  LSampleFmt: TAudioSampleFormat;
  LIsSowt: Boolean;
  LCompStr: string;
  LChunkPayloadStart: Int64;
  LChunkPayloadEnd: Int64;
  LChunkNextPos: Int64;
  LPayloadRemaining: Int64;
  LNamePad: Integer;
begin
  Result.Format := Default(TAudioFormat);
  Result.FrameCount := 0;
  Result.Data := nil;
  FTags := Default(TAudioTags);
  FHasLast := False;
  LStartPos := AStream.Position;
  if AStream.Size - LStartPos < 12 then
    raise EAudioDecodeError.Create('aiff: too small');

  if not ReadTag(AStream, LTag, AStream.Size) then
    raise EAudioDecodeError.Create('aiff: cannot read FORM tag');
  if not TagEquals(LTag, 'FORM') then
    raise EAudioDecodeError.Create('aiff: missing FORM');

  if not ReadU32BE(AStream, LFormSize, AStream.Size) then
    raise EAudioDecodeError.Create('aiff: cannot read FORM size');
  if not ReadTag(AStream, LFormType, AStream.Size) then
    raise EAudioDecodeError.Create('aiff: cannot read FORM type');

  LIsAifc := TagEquals(LFormType, 'AIFC');
  if not (TagEquals(LFormType, 'AIFF') or LIsAifc) then
    raise EAudioDecodeError.Create('aiff: unsupported FORM type');

  if LFormSize < 4 then
    raise EAudioDecodeError.Create('aiff: FORM too small');
  LRiffEnd := LStartPos + 8 + Int64(LFormSize);
  if LRiffEnd > AStream.Size then
    raise EAudioDecodeError.Create('aiff: FORM size exceeds stream');
  if (LStartPos = 0) and (LRiffEnd <> AStream.Size) and (LRiffEnd + 1 <> AStream.Size) then
    raise EAudioDecodeError.Create('aiff: FORM size mismatch');

  LHasComm := False;
  LChannels := 0;
  LNumFrames := 0;
  LSampleSize := 0;
  LRate := 0;
  LDataPos := -1;
  LDataSize := -1;
  LIsSowt := False;
  LCompStr := '';

  while HasBytes(AStream, 8, LRiffEnd) do
  begin
    if not ReadTag(AStream, LTag, LRiffEnd) then
      raise EAudioDecodeError.Create('aiff: cannot read chunk tag');
    if not ReadU32BE(AStream, LChunkSize, LRiffEnd) then
      raise EAudioDecodeError.Create('aiff: cannot read chunk size');
    LChunkSizeI := Int64(LChunkSize);
    LChunkPayloadStart := AStream.Position;
    LChunkPayloadEnd := LChunkPayloadStart + LChunkSizeI;
    LChunkNextPos := LChunkPayloadStart + PaddedSize(LChunkSizeI);
    if LChunkPayloadEnd > LRiffEnd then
      raise EAudioDecodeError.Create('aiff: chunk exceeds FORM');
    if LChunkNextPos > AStream.Size then
      raise EAudioDecodeError.Create('aiff: chunk truncated');
    if LChunkNextPos > LRiffEnd then
      LChunkNextPos := LChunkPayloadEnd; // allow final without pad check if at end

    if TagEquals(LTag, 'COMM') then
    begin
      if LHasComm then
        raise EAudioDecodeError.Create('aiff: duplicate COMM');
      if LIsAifc then
      begin
        if LChunkSizeI < 23 then
          raise EAudioDecodeError.Create('aiff: AIFC COMM too small');
      end
      else
      begin
        if LChunkSizeI < 18 then
          raise EAudioDecodeError.Create('aiff: COMM too small');
      end;
      if not ReadU16BE(AStream, LChannels, LChunkPayloadEnd) then
        raise EAudioDecodeError.Create('aiff: COMM channels');
      if not ReadU32BE(AStream, LNumFrames, LChunkPayloadEnd) then
        raise EAudioDecodeError.Create('aiff: COMM frames');
      if not ReadU16BE(AStream, LSampleSize, LChunkPayloadEnd) then
        raise EAudioDecodeError.Create('aiff: COMM sampleSize');
      if not ReadExact(AStream, LExt[0], 10, LChunkPayloadEnd) then
        raise EAudioDecodeError.Create('aiff: COMM sampleRate');
      LRate := Extended80ToRate(LExt);
      if LRate = 0 then
        raise EAudioDecodeError.Create('aiff: invalid sample rate');
      if LIsAifc then
      begin
        if not ReadTag(AStream, LCompType, LChunkPayloadEnd) then
          raise EAudioDecodeError.Create('aiff: COMM compression');
        LCompStr := TagToString(LCompType);
        if not ((LCompStr = 'NONE') or (LCompStr = 'sowt') or (LCompStr = 'twos') or (LCompStr = 'fl32')) then
          raise EAudioDecodeError.CreateFmt('aiff: unsupported compression %s', [LCompStr]);
        LIsSowt := (LCompStr = 'sowt');
        // pstring: 1 byte len + content + pad to even (inside chunk)
        if not ReadExact(AStream, LCompNameLen, 1, LChunkPayloadEnd) then
          raise EAudioDecodeError.Create('aiff: COMM comp name len');
        if LCompNameLen > 0 then
        begin
          if not HasBytes(AStream, LCompNameLen, LChunkPayloadEnd) then
            raise EAudioDecodeError.Create('aiff: COMM comp name truncated');
          AStream.Position := AStream.Position + LCompNameLen;
        end;
        // pstring pad inside chunk: if (1+len) odd, one pad byte
        LNamePad := (1 + Integer(LCompNameLen)) and 1;
        // Note: when (1+len) odd, need to skip 1 pad byte inside chunk
        if LNamePad <> 0 then
        begin
          if AStream.Position < LChunkPayloadEnd then
            AStream.Position := AStream.Position + 1
          else if AStream.Position > LChunkPayloadEnd then
            raise EAudioDecodeError.Create('aiff: COMM comp name pad overflow');
        end;
      end;
      // skip any remaining bytes in COMM payload (should be 0 for AIFF/AIFC but allow)
      LPayloadRemaining := LChunkPayloadEnd - AStream.Position;
      if LPayloadRemaining < 0 then
        raise EAudioDecodeError.Create('aiff: COMM overflow');
      if LPayloadRemaining > 0 then
        AStream.Position := LChunkPayloadEnd;
      // move to next chunk (handle outer pad)
      AStream.Position := LChunkNextPos;
      LHasComm := True;
    end
    else if TagEquals(LTag, 'SSND') then
    begin
      if not LHasComm then
        raise EAudioDecodeError.Create('aiff: SSND before COMM');
      if LChunkSizeI < 8 then
        raise EAudioDecodeError.Create('aiff: SSND too small');
      if not ReadU32BE(AStream, LOffset, LChunkPayloadEnd) then
        raise EAudioDecodeError.Create('aiff: SSND offset');
      if not ReadU32BE(AStream, LBlockSize, LChunkPayloadEnd) then
        raise EAudioDecodeError.Create('aiff: SSND blockSize');
      if Int64(LOffset) > LChunkSizeI - 8 then
        raise EAudioDecodeError.Create('aiff: SSND offset exceeds data');
      if LOffset > 0 then
      begin
        if not HasBytes(AStream, LOffset, LChunkPayloadEnd) then
          raise EAudioDecodeError.Create('aiff: SSND offset truncated');
        AStream.Position := AStream.Position + Int64(LOffset);
      end;
      LDataPos := AStream.Position;
      LDataSize := LChunkSizeI - 8 - Int64(LOffset);
      Break;
    end
    else
    begin
      // FVER/fact/other: skip to next chunk
      AStream.Position := LChunkNextPos;
    end;
  end;

  if not LHasComm then
    raise EAudioDecodeError.Create('aiff: missing COMM');
  if LDataPos < 0 then
    raise EAudioDecodeError.Create('aiff: missing SSND');

  LChannelsInt := LChannels;
  LSampleRateInt := LRate;
  LBitsInt := LSampleSize;

  if (LChannelsInt < 1) or (LChannelsInt > MaxAudioChannels) then
    raise EAudioDecodeError.CreateFmt('aiff: channels %d out of range', [LChannelsInt]);
  if (LSampleRateInt < MinAudioSampleRate) or (LSampleRateInt > MaxAudioSampleRate) then
    raise EAudioDecodeError.CreateFmt('aiff: sample rate %d out of range', [LSampleRateInt]);

  // Determine sample format
  if LIsAifc and (LCompStr = 'fl32') then
  begin
    if LBitsInt <> 32 then
      raise EAudioDecodeError.CreateFmt('aiff: fl32 bits %d unsupported', [LBitsInt]);
    LSampleFmt := sfF32;
  end
  else
  begin
    case LBitsInt of
      8: LSampleFmt := sfU8;
      16: LSampleFmt := sfS16;
      24: LSampleFmt := sfS24;
      32: LSampleFmt := sfS32;
    else
      raise EAudioDecodeError.CreateFmt('aiff: bits %d unsupported', [LBitsInt]);
    end;
  end;

  LBlockAlignInt := LChannelsInt * (LBitsInt div 8);
  if LBlockAlignInt <= 0 then
    raise EAudioDecodeError.Create('aiff: invalid block align');

  if LDataSize < 0 then
    raise EAudioDecodeError.Create('aiff: negative data size');
  if LDataSize > MAX_AIFF_PAYLOAD_BYTES then
    raise EAudioDecodeError.CreateFmt('aiff: payload %d exceeds limit', [LDataSize]);
  if LDataSize mod Int64(LBlockAlignInt) <> 0 then
    raise EAudioDecodeError.Create('aiff: data size not multiple of block align');
  // numFrames * blockAlign == dataSize (allow pad 1)
  if (Int64(LNumFrames) * Int64(LBlockAlignInt) <> LDataSize) and
     (Int64(LNumFrames) * Int64(LBlockAlignInt) + 1 <> LDataSize) and
     (Int64(LNumFrames) * Int64(LBlockAlignInt) <> LDataSize + 1) then
  begin
    // allow pad 1 difference in either direction (as spec: allow pad 1)
    if Abs(Int64(LNumFrames) * Int64(LBlockAlignInt) - LDataSize) > 1 then
      raise EAudioDecodeError.Create('aiff: frame count mismatch');
  end;
  if not HasBytes(AStream, LDataSize, AStream.Size) then
    // check truncated from DataPos
    if LDataPos + LDataSize > AStream.Size then
      raise EAudioDecodeError.Create('aiff: data truncated');
  if LDataPos + LDataSize > LRiffEnd then
    raise EAudioDecodeError.Create('aiff: data exceeds FORM');

  // Build format (ChannelMask/Layout derived)
  LFormat := AudioFormatCreate(LSampleRateInt, LChannelsInt, LSampleFmt);
  // AIFC has no mask, derived already; keep as is

  // Load data
  AStream.Position := LDataPos;
  SetLength(Result.Data, LDataSize);
  if LDataSize > 0 then
  begin
    if AStream.Read(Result.Data[0], LongInt(LDataSize)) <> LDataSize then
      raise EAudioDecodeError.Create('aiff: data read failed');
  end;

  // Sample conversion: AIFF big-endian to host little; sowt is little already
  if not LIsSowt and (LDataSize > 0) then
  begin
    case LSampleFmt of
      sfU8: ; // no swap
      sfS16: Swap16Buf(Result.Data, Integer(LDataSize));
      sfS24: Swap24Buf(Result.Data, Integer(LDataSize));
      sfS32, sfF32: Swap32Buf(Result.Data, Integer(LDataSize));
    end;
  end;

  Result.Format := LFormat;
  if LBlockAlignInt > 0 then
    Result.FrameCount := Integer(LDataSize div Int64(LBlockAlignInt))
  else
    Result.FrameCount := 0;
  // Tags empty
  FTags.Title := '';
  FTags.Artist := '';
  FTags.Album := '';
  FTags.Date := '';
  FTags.TrackNo := 0;
  SetLength(FTags.Extra, 0);
  FLastFormat := LFormat;
  FHasLast := True;
end;

function TAiffDecoder.OpenStreaming(const AStream: IStream): IAudioSource;
var
  LBuf: TAudioBuffer;
begin
  LBuf := DecodeWhole(AStream);
  Result := TMemoryAiffSource.Create(LBuf);
end;

{ ---- TMemoryAiffSource ---- }

constructor TMemoryAiffSource.Create(const ABuffer: TAudioBuffer);
begin
  inherited Create;
  FBuffer := ABuffer;
  FPos := 0;
end;

function TMemoryAiffSource.GetFormat: TAudioFormat;
begin
  Result := FBuffer.Format;
end;

function TMemoryAiffSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LAvail, LToCopy, LBytes: Integer;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  if Length(ABuffer.Data) < AFrames * FBuffer.Format.BlockAlign then
    raise EInvalidArgument.Create('aiff streaming: buffer too small');
  LAvail := FBuffer.FrameCount - FPos;
  if LAvail <= 0 then Exit(0);
  LToCopy := AFrames;
  if LToCopy > LAvail then LToCopy := LAvail;
  LBytes := LToCopy * FBuffer.Format.BlockAlign;
  // perf: zero-copy single source via bytes.ops BytesCopy inline (single Move), no duplicate impl, steady zero alloc
  BytesCopy(@ABuffer.Data[0], @FBuffer.Data[FPos * FBuffer.Format.BlockAlign], SizeUInt(LBytes));
  ABuffer.Format := FBuffer.Format;
  ABuffer.FrameCount := LToCopy;
  FPos := FPos + LToCopy;
  Result := LToCopy;
end;

function TMemoryAiffSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := AudioFillMemoryRealtime(FBuffer, FPos, ABuffer, AFrames);
end;

function TMemoryAiffSource.SeekTo(AFrame: UInt64): Boolean;
begin
  if AFrame > UInt64(FBuffer.FrameCount) then Exit(False);
  FPos := Integer(AFrame);
  Result := True;
end;

function CreateAiffDecoder: IAudioDecoder;
begin
  Result := TAiffDecoder.Create;
end;

end.
