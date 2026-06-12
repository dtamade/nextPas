unit nextpas.core.compress.gzip;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.compress.base,
  nextpas.core.compress.intf;

function CreateGzipWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel = clDefault): ICompressWriter;
function CreateGzipReader(const ASrc: IReader): IDecompressReader;
function CreateGzipReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;

function GzipCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes;
function GzipDecompress(const AData: TBytes): TBytes;
function GzipDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;

implementation

uses
  zlib, nextpas.core.errors;

{$PUSH}{$WARN 5024 OFF}
const
  GZIP_HEADER_FIELD_MAX_SIZE = 65536;
  GZIP_HDR: array[0..9] of Byte = (
    $1F, $8B, $08, $00,
    $00, $00, $00, $00,
    $00, $FF
  );
{$POP}

type
  TGzipWriter = class(TInterfacedObject, IWriter, ICompressWriter)
  private
    FDst: IWriter;
    FStream: z_stream;
    FBuf: array[0..COMPRESS_BUF_SIZE - 1] of Byte;
    FInitialized: Boolean;
    FClosedSuccessfully: Boolean;
    FCRC: UInt32;
    FSize: UInt32;
    procedure FlushOutput(AFlush: Int32);
    procedure WriteTrailer;
    procedure FinishAfterFailure;
  public
    constructor Create(const ADst: IWriter; ALevel: Int32);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    procedure Close;
  end;

  TGzipReader = class(TInterfacedObject, IReader, IDecompressReader)
  private
    FSrc: IReader;
    FStream: z_stream;
    FInBuf: array[0..COMPRESS_BUF_SIZE - 1] of Byte;
    FInitialized: Boolean;
    FDone: Boolean;
    FPendingFinishValidation: Boolean;
    FPendingReadError: string;
    FCRC: UInt32;
    FSize: UInt32;
    FBounded: Boolean;
    FMaxOutputSize: SizeUInt;
    FOutputSize: SizeUInt;
    FMemberOutputStart: SizeUInt;
    FPendingInput: TBytes;
    FPendingInputPos: SizeUInt;
    FPendingInputLen: SizeUInt;
    function ReadInput(var ABuf; const ACount: SizeUInt): SizeUInt;
    function ReadHeaderByte(var AByte: Byte): Boolean;
    procedure ReadHeaderExact(var ABuf; const ACount: SizeUInt;
      const AErrorMessage: string);
    procedure ReadHeaderField(var AHeaderCRC: UInt32;
      const ATruncatedError: string);
    procedure StartMemberWithHeaderPrefix(const AFirst, ASecond: Byte;
      const AFixedHeaderError: string);
    function StartNextMemberIfPresent: Boolean;
    procedure CheckOutputLimit(const ARead: SizeUInt);
    function FinishStream: Boolean;
    procedure FinishAfterFailure;
  public
    constructor Create(const ASrc: IReader); overload;
    constructor Create(const ASrc: IReader; const AMaxOutputSize: SizeUInt); overload;
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

procedure GzipReadExact(const ASrc: IReader; var ABuf; const ACount: SizeUInt;
  const AErrorMessage: string);
var
  LDst: PByte;
  LTotal, LRead: SizeUInt;
begin
  LDst := @ABuf;
  LTotal := 0;
  while LTotal < ACount do
  begin
    LRead := ASrc.Read(LDst^, ACount - LTotal);
    if LRead = 0 then
      raise EIOError.Create(AErrorMessage);
    Inc(LDst, LRead);
    Inc(LTotal, LRead);
  end;
end;

procedure GzipReadHeaderField(const ASrc: IReader; var AHeaderCRC: UInt32;
  const ATruncatedError: string);
var
  LByte: Byte;
  LFieldSize: SizeUInt;
begin
  LByte := 0;
  LFieldSize := 0;
  repeat
    if ASrc.Read(LByte, 1) <> 1 then
      raise EIOError.Create(ATruncatedError);
    AHeaderCRC := UInt32(crc32(ULong(AHeaderCRC), @LByte, 1));
    if LByte <> 0 then
    begin
      Inc(LFieldSize);
      if LFieldSize > GZIP_HEADER_FIELD_MAX_SIZE then
        raise EIOError.Create('gzip: header field exceeds limit');
    end;
  until LByte = 0;
end;

function GzipSkipHeaderField(const AData: TBytes; const AOffset: SizeUInt;
  const ATruncatedError: string): SizeUInt;
var
  LFieldSize: SizeUInt;
begin
  Result := AOffset;
  LFieldSize := 0;
  while (Result < SizeUInt(Length(AData))) and (AData[Result] <> 0) do
  begin
    Inc(LFieldSize);
    if LFieldSize > GZIP_HEADER_FIELD_MAX_SIZE then
      raise EIOError.Create('gzip: header field exceeds limit');
    Inc(Result);
  end;
  if Result >= SizeUInt(Length(AData)) then
    raise EIOError.Create(ATruncatedError);
  Inc(Result);
end;

function ZlibAvailChunk(const ACount: SizeUInt): LongWord; inline;
begin
  if ACount > SizeUInt(High(LongWord)) then
    Result := High(LongWord)
  else
    Result := LongWord(ACount);
end;

function ZlibInputSize(const ACount: SizeUInt): LongWord; inline;
begin
  if ACount > SizeUInt(High(LongWord)) then
    raise EIOError.Create('gzip: input size exceeds limit');
  Result := LongWord(ACount);
end;

{ TGzipWriter }

constructor TGzipWriter.Create(const ADst: IWriter; ALevel: Int32);
var
  LWritten: SizeUInt;
begin
  inherited Create;
  FDst := ADst;
  FCRC := 0;
  FSize := 0;
  LWritten := FDst.Write(GZIP_HDR[0], 10);
  if LWritten <> 10 then
    raise EIOError.Create('gzip: short write');
  FillChar(FStream, SizeOf(FStream), 0);
  if deflateInit2(FStream, ALevel, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) <> Z_OK then
    raise EIOError.Create('gzip: deflateInit2 failed');
  FInitialized := True;
  FClosedSuccessfully := False;
end;

destructor TGzipWriter.Destroy;
begin
  if FInitialized then
  begin
    FInitialized := False;
    deflateEnd(FStream);
  end;
  inherited;
end;

procedure TGzipWriter.FlushOutput(AFlush: Int32);
var
  LHave, LWritten: SizeUInt;
  LRet: Int32;
begin
  repeat
    FStream.next_out := @FBuf[0];
    FStream.avail_out := COMPRESS_BUF_SIZE;
    LRet := deflate(FStream, AFlush);
    if (LRet <> Z_OK) and (LRet <> Z_STREAM_END) and (LRet <> Z_BUF_ERROR) then
      raise EIOError.Create('gzip: deflate failed (' + IntToStr(LRet) + ')');
    LHave := COMPRESS_BUF_SIZE - FStream.avail_out;
    if LHave > 0 then
    begin
      LWritten := FDst.Write(FBuf[0], LHave);
      if LWritten <> LHave then
        raise EIOError.Create('gzip: short write');
    end;
  until FStream.avail_out <> 0;
end;

procedure TGzipWriter.FinishAfterFailure;
begin
  if FInitialized then
  begin
    FInitialized := False;
    deflateEnd(FStream);
  end;
end;

procedure TGzipWriter.WriteTrailer;
var
  LTrailer: array[0..7] of Byte;
begin
  LTrailer[0] := Byte(FCRC);
  LTrailer[1] := Byte(FCRC shr 8);
  LTrailer[2] := Byte(FCRC shr 16);
  LTrailer[3] := Byte(FCRC shr 24);
  LTrailer[4] := Byte(FSize);
  LTrailer[5] := Byte(FSize shr 8);
  LTrailer[6] := Byte(FSize shr 16);
  LTrailer[7] := Byte(FSize shr 24);
  if FDst.Write(LTrailer[0], 8) <> 8 then
    raise EIOError.Create('gzip: short write');
end;

function TGzipWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LInput: PByte;
  LChunk: LongWord;
  LConsumed: SizeUInt;
  LRemaining: SizeUInt;
begin
  if not FInitialized then
    raise EIOError.Create('gzip: write after close');
  if ACount = 0 then Exit(0);

  LInput := PByte(@ABuf);
  LRemaining := ACount;
  try
    while LRemaining > 0 do
    begin
      LChunk := ZlibAvailChunk(LRemaining);
      FStream.next_in := pBytef(LInput);
      FStream.avail_in := LChunk;
      FlushOutput(Z_NO_FLUSH);
      LConsumed := SizeUInt(LChunk) - SizeUInt(FStream.avail_in);
      if LConsumed = 0 then
        raise EIOError.Create('gzip: write made no progress');
      {$PUSH}{$Q-}{$R-}
      FCRC := UInt32(crc32(ULong(FCRC), pBytef(LInput), LConsumed));
      Inc(FSize, UInt32(LConsumed));
      {$POP}
      Inc(LInput, LConsumed);
      Dec(LRemaining, LConsumed);
    end;
  except
    FinishAfterFailure;
    raise;
  end;
  Result := ACount;
end;

procedure TGzipWriter.Flush;
begin
  if not FInitialized then
  begin
    if FClosedSuccessfully then
      raise EIOError.Create('gzip: flush after close');
    Exit;
  end;
  try
    FlushOutput(Z_SYNC_FLUSH);
  except
    FinishAfterFailure;
    raise;
  end;
end;

procedure TGzipWriter.Close;
begin
  if FInitialized then
  begin
    FInitialized := False;
    try
      FlushOutput(Z_FINISH);
      WriteTrailer;
      FClosedSuccessfully := True;
    finally
      deflateEnd(FStream);
    end;
  end;
end;

{ TGzipReader }

function TGzipReader.ReadInput(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LPending: SizeUInt;
  LDst: PByte;
begin
  if ACount = 0 then
    Exit(0);
  Result := 0;
  LDst := @ABuf;
  if FPendingInputPos < FPendingInputLen then
  begin
    LPending := FPendingInputLen - FPendingInputPos;
    if LPending > ACount then
      LPending := ACount;
    Move(FPendingInput[FPendingInputPos], LDst^, LPending);
    Inc(FPendingInputPos, LPending);
    Inc(LDst, LPending);
    Result := LPending;
    if FPendingInputPos >= FPendingInputLen then
    begin
      FPendingInput := nil;
      FPendingInputPos := 0;
      FPendingInputLen := 0;
    end;
  end;
  if Result < ACount then
    Inc(Result, FSrc.Read(LDst^, ACount - Result));
end;

function TGzipReader.ReadHeaderByte(var AByte: Byte): Boolean;
begin
  Result := ReadInput(AByte, 1) = 1;
end;

procedure TGzipReader.ReadHeaderExact(var ABuf; const ACount: SizeUInt;
  const AErrorMessage: string);
var
  LDst: PByte;
  LTotal, LRead: SizeUInt;
begin
  LDst := @ABuf;
  LTotal := 0;
  while LTotal < ACount do
  begin
    LRead := ReadInput(LDst^, ACount - LTotal);
    if LRead = 0 then
      raise EIOError.Create(AErrorMessage);
    Inc(LDst, LRead);
    Inc(LTotal, LRead);
  end;
end;

procedure TGzipReader.ReadHeaderField(var AHeaderCRC: UInt32;
  const ATruncatedError: string);
var
  LByte: Byte;
  LFieldSize: SizeUInt;
begin
  LByte := 0;
  LFieldSize := 0;
  repeat
    if not ReadHeaderByte(LByte) then
      raise EIOError.Create(ATruncatedError);
    AHeaderCRC := UInt32(crc32(ULong(AHeaderCRC), @LByte, 1));
    if LByte <> 0 then
    begin
      Inc(LFieldSize);
      if LFieldSize > GZIP_HEADER_FIELD_MAX_SIZE then
        raise EIOError.Create('gzip: header field exceeds limit');
    end;
  until LByte = 0;
end;

procedure TGzipReader.StartMemberWithHeaderPrefix(const AFirst, ASecond: Byte;
  const AFixedHeaderError: string);
var
  LHdr: array[0..9] of Byte;
  LFlags: Byte;
  LByte: Byte;
  LSkip: UInt16;
  LHeaderCRC: UInt32;
  LExpectedHeaderCRC, LActualHeaderCRC: UInt16;
begin
  LHdr[0] := AFirst;
  LHdr[1] := ASecond;
  ReadHeaderExact(LHdr[2], 8, AFixedHeaderError);
  if (LHdr[0] <> $1F) or (LHdr[1] <> $8B) then
    raise EIOError.Create('gzip: invalid magic');
  if LHdr[2] <> $08 then
    raise EIOError.Create('gzip: unsupported method');

  LFlags := LHdr[3];
  if (LFlags and $E0) <> 0 then
    raise EIOError.Create('gzip: invalid flags');
  LHeaderCRC := UInt32(crc32(0, @LHdr[0], 10));
  if (LFlags and $04) <> 0 then
  begin
    if not ReadHeaderByte(LByte) then raise EIOError.Create('gzip: truncated FEXTRA');
    LHeaderCRC := UInt32(crc32(ULong(LHeaderCRC), @LByte, 1));
    LSkip := LByte;
    if not ReadHeaderByte(LByte) then raise EIOError.Create('gzip: truncated FEXTRA');
    LHeaderCRC := UInt32(crc32(ULong(LHeaderCRC), @LByte, 1));
    LSkip := LSkip or (UInt16(LByte) shl 8);
    while LSkip > 0 do
    begin
      if not ReadHeaderByte(LByte) then raise EIOError.Create('gzip: truncated FEXTRA');
      LHeaderCRC := UInt32(crc32(ULong(LHeaderCRC), @LByte, 1));
      Dec(LSkip);
    end;
  end;
  if (LFlags and $08) <> 0 then
    ReadHeaderField(LHeaderCRC, 'gzip: truncated FNAME');
  if (LFlags and $10) <> 0 then
    ReadHeaderField(LHeaderCRC, 'gzip: truncated FCOMMENT');
  if (LFlags and $02) <> 0 then
  begin
    if not ReadHeaderByte(LByte) then raise EIOError.Create('gzip: truncated header');
    LExpectedHeaderCRC := UInt16(LByte);
    if not ReadHeaderByte(LByte) then raise EIOError.Create('gzip: truncated header');
    LExpectedHeaderCRC := LExpectedHeaderCRC or (UInt16(LByte) shl 8);
    LActualHeaderCRC := UInt16(LHeaderCRC);
    if LExpectedHeaderCRC <> LActualHeaderCRC then
      raise EIOError.Create('gzip: header CRC mismatch');
  end;

  FCRC := 0;
  FSize := 0;
  FMemberOutputStart := FOutputSize;
  FillChar(FStream, SizeOf(FStream), 0);
  if inflateInit2(FStream, -15) <> Z_OK then
    raise EIOError.Create('gzip: inflateInit2 failed');
  FInitialized := True;
  FDone := False;
  FPendingFinishValidation := False;
end;

function TGzipReader.StartNextMemberIfPresent: Boolean;
var
  LFirst, LSecond: Byte;
begin
  if not ReadHeaderByte(LFirst) then
    Exit(False);
  if not ReadHeaderByte(LSecond) then
    raise EIOError.Create('gzip: trailing bytes after trailer');
  if (LFirst <> $1F) or (LSecond <> $8B) then
    raise EIOError.Create('gzip: trailing bytes after trailer');
  StartMemberWithHeaderPrefix(LFirst, LSecond, 'gzip: header too short');
  Result := True;
end;

constructor TGzipReader.Create(const ASrc: IReader);
var
  LHdr: array[0..9] of Byte;
begin
  inherited Create;
  FSrc := ASrc;
  FCRC := 0;
  FSize := 0;
  FDone := False;
  FPendingFinishValidation := False;
  FPendingReadError := '';
  FBounded := False;
  FMaxOutputSize := 0;
  FOutputSize := 0;
  FMemberOutputStart := 0;
  FPendingInput := nil;
  FPendingInputPos := 0;
  FPendingInputLen := 0;
  ReadHeaderExact(LHdr[0], 10, 'gzip: header too short');
  SetLength(FPendingInput, 8);
  Move(LHdr[2], FPendingInput[0], 8);
  FPendingInputPos := 0;
  FPendingInputLen := 8;
  StartMemberWithHeaderPrefix(LHdr[0], LHdr[1], 'gzip: header too short');
end;

constructor TGzipReader.Create(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt);
begin
  Create(ASrc);
  FBounded := True;
  FMaxOutputSize := AMaxOutputSize;
end;

destructor TGzipReader.Destroy;
begin
  if FInitialized then
    inflateEnd(FStream);
  inherited;
end;

procedure TGzipReader.CheckOutputLimit(const ARead: SizeUInt);
begin
  if (not FBounded) or (ARead = 0) then
    Exit;
  if (ARead > FMaxOutputSize) or (FOutputSize > FMaxOutputSize - ARead) then
    raise EIOError.Create('gzip: decompressed size exceeds limit');
  Inc(FOutputSize, ARead);
end;

procedure TGzipReader.FinishAfterFailure;
begin
  if FInitialized then
  begin
    inflateEnd(FStream);
    FInitialized := False;
  end;
  FDone := True;
  FPendingFinishValidation := False;
  FPendingReadError := '';
end;

function TGzipReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRet: Int32;
  LRead: SizeUInt;
  LChunk: LongWord;
  LRemainingLimit: SizeUInt;
  LProbe: Byte;
  LProbeOnly: Boolean;
  LPendingError: string;
begin
  try
    if ACount = 0 then
      Exit(0);
    if FPendingReadError <> '' then
    begin
      LPendingError := FPendingReadError;
      FPendingReadError := '';
      FDone := True;
      raise EIOError.Create(LPendingError);
    end;
    if FDone then Exit(0);
    if FPendingFinishValidation then
    begin
      if FinishStream then
        Exit(Read(ABuf, ACount));
      Exit(0);
    end;
    LChunk := ZlibAvailChunk(ACount);
    LProbeOnly := False;
    if FBounded then
    begin
      if FOutputSize >= FMaxOutputSize then
      begin
        LProbeOnly := True;
        LChunk := SizeOf(LProbe);
      end
      else
      begin
        LRemainingLimit := FMaxOutputSize - FOutputSize;
        if SizeUInt(LChunk) > LRemainingLimit then
          LChunk := ZlibAvailChunk(LRemainingLimit);
      end;
    end;
    if LProbeOnly then
      FStream.next_out := @LProbe
    else
      FStream.next_out := @ABuf;
    FStream.avail_out := LChunk;
    while FStream.avail_out > 0 do
    begin
      if FStream.avail_in = 0 then
      begin
        LRead := ReadInput(FInBuf[0], COMPRESS_BUF_SIZE);
        if LRead = 0 then
          raise EIOError.Create('gzip: truncated stream');
        FStream.next_in := @FInBuf[0];
        FStream.avail_in := LRead;
      end;
      LRet := inflate(FStream, Z_NO_FLUSH);
      if LRet = Z_STREAM_END then
      begin
        Result := SizeUInt(LChunk) - SizeUInt(FStream.avail_out);
        CheckOutputLimit(Result);
        if Result > 0 then
        begin
          {$PUSH}{$Q-}{$R-}
          FCRC := UInt32(crc32(ULong(FCRC), @ABuf, Result));
          Inc(FSize, UInt32(Result));
          {$POP}
          FPendingFinishValidation := True;
          Exit(Result);
        end;
        if FinishStream then
        begin
          if LProbeOnly then
            FStream.next_out := @LProbe
          else
            FStream.next_out := @ABuf;
          FStream.avail_out := LChunk;
          Continue;
        end;
        Exit(0);
      end;
      if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) then
      begin
        if LRet = Z_DATA_ERROR then
        begin
          Result := SizeUInt(LChunk) - SizeUInt(FStream.avail_out);
          if Result > 0 then
          begin
            if LProbeOnly then
              raise EIOError.Create('gzip: decompressed size exceeds limit');
            CheckOutputLimit(Result);
            {$PUSH}{$Q-}{$R-}
            FCRC := UInt32(crc32(ULong(FCRC), @ABuf, Result));
            Inc(FSize, UInt32(Result));
            {$POP}
            if FInitialized then
            begin
              inflateEnd(FStream);
              FInitialized := False;
            end;
            FDone := True;
            FPendingFinishValidation := False;
            FPendingReadError := 'gzip: corrupt stream';
            Exit(Result);
          end;
          raise EIOError.Create('gzip: corrupt stream');
        end;
        raise EIOError.Create('gzip: inflate failed (' + IntToStr(LRet) + ')');
      end;
    end;
    Result := SizeUInt(LChunk) - SizeUInt(FStream.avail_out);
    if LProbeOnly then
    begin
      if Result > 0 then
        raise EIOError.Create('gzip: decompressed size exceeds limit');
      Exit(0);
    end;
    CheckOutputLimit(Result);
    if Result > 0 then
    begin
      {$PUSH}{$Q-}{$R-}
      FCRC := UInt32(crc32(ULong(FCRC), @ABuf, Result));
      Inc(FSize, UInt32(Result));
      {$POP}
    end;
  except
    FinishAfterFailure;
    raise;
  end;
end;

function TGzipReader.FinishStream: Boolean;
var
  LTrailer: array[0..7] of Byte;
  LExpectedCRC, LExpectedSize: UInt32;
  LAvail, LNeed: SizeUInt;
  LNextIn: PByte;
  LPending: PByte;
  LHasTrailingBytes: Boolean;
begin
  Result := False;
  if FInitialized then
  begin
    LAvail := FStream.avail_in;
    LNextIn := PByte(FStream.next_in);
    inflateEnd(FStream);
    FInitialized := False;
    FDone := True;
    FPendingFinishValidation := False;

    LNeed := 8;
    LHasTrailingBytes := False;
    if LAvail >= LNeed then
    begin
      LHasTrailingBytes := LAvail > LNeed;
      Move(LNextIn^, LTrailer[0], 8);
      if LHasTrailingBytes then
      begin
        FPendingInputLen := LAvail - LNeed;
        SetLength(FPendingInput, FPendingInputLen);
        LPending := LNextIn;
        Inc(LPending, LNeed);
        Move(LPending^, FPendingInput[0], FPendingInputLen);
        FPendingInputPos := 0;
      end;
    end
    else
    begin
      if LAvail > 0 then
        Move(LNextIn^, LTrailer[0], LAvail);
      LNeed := 8 - LAvail;
      ReadHeaderExact(LTrailer[LAvail], LNeed, 'gzip: truncated trailer');
    end;

    LExpectedCRC := UInt32(LTrailer[0]) or (UInt32(LTrailer[1]) shl 8) or
      (UInt32(LTrailer[2]) shl 16) or (UInt32(LTrailer[3]) shl 24);
    LExpectedSize := UInt32(LTrailer[4]) or (UInt32(LTrailer[5]) shl 8) or
      (UInt32(LTrailer[6]) shl 16) or (UInt32(LTrailer[7]) shl 24);
    if LExpectedCRC <> FCRC then
      raise EIOError.Create('gzip: CRC32 mismatch');
    if FBounded and
       ((FMemberOutputStart > FMaxOutputSize) or
        (SizeUInt(LExpectedSize) > FMaxOutputSize - FMemberOutputStart)) then
      raise EIOError.Create('gzip: decompressed size exceeds limit');
    if LExpectedSize <> FSize then
      raise EIOError.Create('gzip: size mismatch');
    if LHasTrailingBytes then
    begin
      if not StartNextMemberIfPresent then
        raise EIOError.Create('gzip: trailing bytes after trailer');
      Result := True;
      Exit;
    end;
    if StartNextMemberIfPresent then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TGzipReader.Close;
begin
  if FInitialized then
  begin
    inflateEnd(FStream);
    FInitialized := False;
  end;
  FDone := True;
  FPendingFinishValidation := False;
  FPendingReadError := '';
end;

{ Factory }

function CreateGzipWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel): ICompressWriter;
begin
  if ADst = nil then
    raise EArgumentError.Create('gzip: writer is nil');
  Result := TGzipWriter.Create(ADst, LevelToZlib(ALevel));
end;

function CreateGzipReader(const ASrc: IReader): IDecompressReader;
begin
  if ASrc = nil then
    raise EArgumentError.Create('gzip: reader is nil');
  Result := TGzipReader.Create(ASrc);
end;

function CreateGzipReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;
begin
  if ASrc = nil then
    raise EArgumentError.Create('gzip: reader is nil');
  Result := TGzipReader.Create(ASrc, AMaxOutputSize);
end;

{ One-shot }

function GzipCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
var
  LStream: z_stream;
  LOut: TBytes;
  LOutLen: SizeUInt;
  LBound: ULong;
  LCRC: UInt32;
  LSize: UInt32;
  LInputSize: LongWord;
  LRet: Int32;
begin
  Result := nil;
  if Length(AData) = 0 then
  begin
    SetLength(Result, 20);
    Move(GZIP_HDR[0], Result[0], 10);
    Result[10] := $03; Result[11] := $00;
    FillChar(Result[12], 8, 0);
    Exit;
  end;

  LInputSize := ZlibInputSize(SizeUInt(Length(AData)));
  LCRC := UInt32(crc32(0, @AData[0], LInputSize));
  LSize := UInt32(LInputSize);

  FillChar(LStream, SizeOf(LStream), 0);
  if deflateInit2(LStream, LevelToZlib(ALevel), Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) <> Z_OK then
    raise EIOError.Create('gzip: deflateInit2 failed');
  try
    LStream.next_in := @AData[0];
    LStream.avail_in := LInputSize;

    LOutLen := 0;
    LBound := compressBound(LInputSize);
    if LBound > ULong(High(UInt32)) then
      raise EIOError.Create('gzip: compressed size bound exceeds limit');
    SetLength(LOut, LBound);

    LStream.next_out := @LOut[0];
    LStream.avail_out := LBound;
    LRet := deflate(LStream, Z_FINISH);
    if LRet <> Z_STREAM_END then
      raise EIOError.Create('GzipCompress: deflate failed');
    LOutLen := LBound - LStream.avail_out;
  finally
    deflateEnd(LStream);
  end;

  SetLength(Result, 10 + LOutLen + 8);
  Move(GZIP_HDR[0], Result[0], 10);
  if LOutLen > 0 then
    Move(LOut[0], Result[10], LOutLen);
  Result[10 + LOutLen + 0] := Byte(LCRC);
  Result[10 + LOutLen + 1] := Byte(LCRC shr 8);
  Result[10 + LOutLen + 2] := Byte(LCRC shr 16);
  Result[10 + LOutLen + 3] := Byte(LCRC shr 24);
  Result[10 + LOutLen + 4] := Byte(LSize);
  Result[10 + LOutLen + 5] := Byte(LSize shr 8);
  Result[10 + LOutLen + 6] := Byte(LSize shr 16);
  Result[10 + LOutLen + 7] := Byte(LSize shr 24);
end;

function GzipDecompress(const AData: TBytes): TBytes;
const
  MAX_DECOMPRESS_SIZE = 256 * 1024 * 1024;
begin
  Result := GzipDecompressWithMaxOutputSize(AData, MAX_DECOMPRESS_SIZE);
end;

function GzipDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
var
  LStream: z_stream;
  LBuf: array[0..32767] of Byte;
  LOutLen, LHave, LCapacity, LRequiredCapacity: SizeUInt;
  LOffset: SizeUInt;
  LRet: Int32;
  LFlags: Byte;
  LExpectedCRC, LActualCRC: UInt32;
  LExpectedSize: UInt32;
  LExpectedHeaderCRC, LActualHeaderCRC: UInt16;
  LTrailer: array[0..7] of Byte;
  LExtraLen: SizeUInt;
  LTrailerAvail: SizeUInt;
  LTrailerPtr: PByte;
  LHasTrailingBytes: Boolean;
  LMemberStart: SizeUInt;
  LMemberOutStart: SizeUInt;
  LInputSize: LongWord;
begin
  Result := nil;
  LInputSize := ZlibInputSize(SizeUInt(Length(AData)));
  if LInputSize < 10 then
    raise EIOError.Create('gzip: header too short');
  LOutLen := 0;
  LCapacity := SizeUInt(Length(AData)) * 4;
  if (LCapacity < SizeUInt(Length(AData))) or (LCapacity > AMaxOutputSize) then
    LCapacity := AMaxOutputSize;
  LOffset := 0;

  repeat
  LMemberStart := LOffset;
  LMemberOutStart := LOutLen;
  if SizeUInt(Length(AData)) - LOffset < 10 then
  begin
    if LOffset = 0 then
      raise EIOError.Create('gzip: header too short');
    if (SizeUInt(Length(AData)) - LOffset >= 2) and
       (AData[LOffset] = $1F) and (AData[LOffset + 1] = $8B) then
      raise EIOError.Create('gzip: header too short');
    raise EIOError.Create('gzip: trailing bytes after trailer');
  end;
  if (AData[LOffset] <> $1F) or (AData[LOffset + 1] <> $8B) then
  begin
    if LOffset = 0 then
      raise EIOError.Create('gzip: invalid magic');
    raise EIOError.Create('gzip: trailing bytes after trailer');
  end;
  if AData[LOffset + 2] <> $08 then
    raise EIOError.Create('gzip: unsupported method');

  LFlags := AData[LOffset + 3];
  if (LFlags and $E0) <> 0 then
    raise EIOError.Create('gzip: invalid flags');
  Inc(LOffset, 10);
  if (LFlags and $04) <> 0 then
  begin
    if SizeUInt(Length(AData)) - LOffset < 2 then
      raise EIOError.Create('gzip: truncated FEXTRA');
    LExtraLen := UInt16(AData[LOffset]) +
      (UInt16(AData[LOffset + 1]) shl 8);
    Inc(LOffset, 2);
    if LExtraLen > SizeUInt(Length(AData)) - LOffset then
      raise EIOError.Create('gzip: truncated FEXTRA');
    Inc(LOffset, LExtraLen);
  end;
  if (LFlags and $08) <> 0 then
    LOffset := GzipSkipHeaderField(AData, LOffset, 'gzip: truncated FNAME');
  if (LFlags and $10) <> 0 then
    LOffset := GzipSkipHeaderField(AData, LOffset, 'gzip: truncated FCOMMENT');
  if (LFlags and $02) <> 0 then
  begin
    if SizeUInt(Length(AData)) - LOffset < 2 then
      raise EIOError.Create('gzip: truncated header');
    LActualHeaderCRC := UInt16(crc32(0, @AData[LMemberStart],
      LOffset - LMemberStart));
    LExpectedHeaderCRC := UInt16(AData[LOffset]) or
      (UInt16(AData[LOffset + 1]) shl 8);
    if LExpectedHeaderCRC <> LActualHeaderCRC then
      raise EIOError.Create('gzip: header CRC mismatch');
    Inc(LOffset, 2);
  end;

  if LOffset >= SizeUInt(Length(AData)) then
    raise EIOError.Create('gzip: truncated stream');

  if SizeUInt(Length(Result)) = 0 then
    SetLength(Result, LCapacity);

  FillChar(LStream, SizeOf(LStream), 0);
  LStream.next_in := @AData[LOffset];
  LStream.avail_in := ZlibInputSize(SizeUInt(Length(AData)) - LOffset);

  if inflateInit2(LStream, -15) <> Z_OK then
    raise EIOError.Create('gzip: inflateInit2 failed');
  try
    repeat
      LStream.next_out := @LBuf[0];
      LStream.avail_out := SizeOf(LBuf);
      LRet := inflate(LStream, Z_NO_FLUSH);
      if LRet = Z_BUF_ERROR then
        raise EIOError.Create('gzip: truncated stream');
      if (LRet <> Z_OK) and (LRet <> Z_STREAM_END) then
      begin
        if LRet = Z_DATA_ERROR then
          raise EIOError.Create('gzip: corrupt stream');
        raise EIOError.Create('gzip: inflate failed (' + IntToStr(LRet) + ')');
      end;
      LHave := SizeOf(LBuf) - LStream.avail_out;
      if LHave > AMaxOutputSize - LOutLen then
        raise EIOError.Create('gzip: decompressed size exceeds limit');
      LRequiredCapacity := LOutLen + LHave;
      if LRequiredCapacity > SizeUInt(Length(Result)) then
      begin
        LCapacity := LRequiredCapacity;
        if LCapacity > AMaxOutputSize div 2 then
          LCapacity := AMaxOutputSize
        else
          LCapacity := LCapacity * 2;
        SetLength(Result, LCapacity);
      end;
      if LHave > 0 then
        Move(LBuf[0], Result[LOutLen], LHave);
      Inc(LOutLen, LHave);
    until LRet = Z_STREAM_END;

    LTrailerAvail := LStream.avail_in;
    if LTrailerAvail < 8 then
      raise EIOError.Create('gzip: truncated trailer');
    LTrailerPtr := PByte(LStream.next_in);
    Move(LTrailerPtr^, LTrailer[0], 8);
    LOffset := SizeUInt(Length(AData)) - LTrailerAvail + 8;
    LHasTrailingBytes := LOffset < SizeUInt(Length(AData));

    LExpectedCRC := UInt32(LTrailer[0]) or (UInt32(LTrailer[1]) shl 8) or
      (UInt32(LTrailer[2]) shl 16) or (UInt32(LTrailer[3]) shl 24);
    LExpectedSize := UInt32(LTrailer[4]) or (UInt32(LTrailer[5]) shl 8) or
      (UInt32(LTrailer[6]) shl 16) or (UInt32(LTrailer[7]) shl 24);
  finally
    inflateEnd(LStream);
  end;
  if LOutLen > LMemberOutStart then
    LActualCRC := UInt32(crc32(0, @Result[LMemberOutStart],
      LOutLen - LMemberOutStart))
  else
    LActualCRC := 0;
  if LActualCRC <> LExpectedCRC then
    raise EIOError.Create('gzip: CRC32 mismatch');
  if (LMemberOutStart > AMaxOutputSize) or
     (SizeUInt(LExpectedSize) > AMaxOutputSize - LMemberOutStart) then
    raise EIOError.Create('gzip: decompressed size exceeds limit');
  if LExpectedSize <> UInt32(LOutLen - LMemberOutStart) then
    raise EIOError.Create('gzip: size mismatch');
  until not LHasTrailingBytes;

  SetLength(Result, LOutLen);
end;

end.
