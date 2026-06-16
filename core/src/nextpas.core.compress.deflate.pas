unit nextpas.core.compress.deflate;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.compress.base,
  nextpas.core.compress.intf;

function CreateDeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel = clDefault): ICompressWriter;
function CreateDeflateReader(const ASrc: IReader): IDecompressReader;
function CreateDeflateReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;

function DeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes;
function DeflateDecompress(const AData: TBytes): TBytes;
function DeflateDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;

implementation

uses
  zlib, nextpas.core.errors;

type
  TDeflateWriter = class(TInterfacedObject, IWriter, ICompressWriter)
  private
    FDst: IWriter;
    FStream: z_stream;
    FBuf: array[0..COMPRESS_BUF_SIZE - 1] of Byte;
    FInitialized: Boolean;
    FClosedSuccessfully: Boolean;
    procedure FlushOutput(AFlush: Int32);
    procedure FinishAfterFailure;
  public
    constructor Create(const ADst: IWriter; ALevel: Int32);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    procedure Close;
  end;

  TDeflateReader = class(TInterfacedObject, IReader, IDecompressReader)
  private
    FSrc: IReader;
    FStream: z_stream;
    FInBuf: array[0..COMPRESS_BUF_SIZE - 1] of Byte;
    FInitialized: Boolean;
    FDone: Boolean;
    FPendingFinishValidation: Boolean;
    FPendingReadError: string;
    FBounded: Boolean;
    FMaxOutputSize: SizeUInt;
    FOutputSize: SizeUInt;
    procedure CheckOutputLimit(const ARead: SizeUInt);
    procedure FinishStream;
    procedure ReleaseInflateState;
    procedure FinishAfterFailure;
  public
    constructor Create(const ASrc: IReader); overload;
    constructor Create(const ASrc: IReader; const AMaxOutputSize: SizeUInt); overload;
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

function IsInvalidZlibHeader(const AFirst, ASecond: Byte): Boolean; inline;
var
  LHeader: UInt16;
begin
  LHeader := (UInt16(AFirst) shl 8) or UInt16(ASecond);
  Result := ((AFirst and $0F) <> Z_DEFLATED) or
    ((AFirst shr 4) > 7) or ((LHeader mod 31) <> 0);
end;

function HasPresetDictionaryZlibHeader(const ASecond: Byte): Boolean; inline;
begin
  Result := (ASecond and $20) <> 0;
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
    raise EIOError.Create('deflate: input size exceeds limit');
  Result := LongWord(ACount);
end;

{ TDeflateWriter }

constructor TDeflateWriter.Create(const ADst: IWriter; ALevel: Int32);
begin
  inherited Create;
  FDst := ADst;
  FillChar(FStream, SizeOf(FStream), 0);
  if deflateInit(FStream, ALevel) <> Z_OK then
    raise EIOError.Create('deflateInit failed');
  FInitialized := True;
  FClosedSuccessfully := False;
end;

destructor TDeflateWriter.Destroy;
begin
  if FInitialized then
  begin
    FInitialized := False;
    deflateEnd(FStream);
  end;
  inherited;
end;

procedure TDeflateWriter.FlushOutput(AFlush: Int32);
var
  LHave, LWritten: SizeUInt;
  LRet: Int32;
begin
  repeat
    FStream.next_out := @FBuf[0];
    FStream.avail_out := COMPRESS_BUF_SIZE;
    LRet := deflate(FStream, AFlush);
    if (LRet <> Z_OK) and (LRet <> Z_STREAM_END) and (LRet <> Z_BUF_ERROR) then
      raise EIOError.Create('deflate failed (' + IntToStr(LRet) + ')');
    LHave := COMPRESS_BUF_SIZE - FStream.avail_out;
    if LHave > 0 then
    begin
      LWritten := FDst.Write(FBuf[0], LHave);
      if LWritten <> LHave then
        raise EIOError.Create('deflate: short write');
    end;
  until FStream.avail_out <> 0;
end;

procedure TDeflateWriter.FinishAfterFailure;
begin
  if FInitialized then
  begin
    FInitialized := False;
    deflateEnd(FStream);
  end;
end;

function TDeflateWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LInput: PByte;
  LChunk: LongWord;
  LConsumed: SizeUInt;
  LRemaining: SizeUInt;
begin
  if not FInitialized then
    raise EIOError.Create('deflate: write after close');
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
        raise EIOError.Create('deflate: write made no progress');
      Inc(LInput, LConsumed);
      Dec(LRemaining, LConsumed);
    end;
  except
    FinishAfterFailure;
    raise;
  end;
  Result := ACount;
end;

procedure TDeflateWriter.Flush;
begin
  if not FInitialized then
  begin
    if FClosedSuccessfully then
      raise EIOError.Create('deflate: flush after close');
    Exit;
  end;
  try
    FlushOutput(Z_SYNC_FLUSH);
  except
    FinishAfterFailure;
    raise;
  end;
end;

procedure TDeflateWriter.Close;
begin
  if FInitialized then
  begin
    FInitialized := False;
    try
      FlushOutput(Z_FINISH);
      FClosedSuccessfully := True;
    finally
      deflateEnd(FStream);
    end;
  end;
end;

{ TDeflateReader }

constructor TDeflateReader.Create(const ASrc: IReader);
begin
  inherited Create;
  FSrc := ASrc;
  FillChar(FStream, SizeOf(FStream), 0);
  if inflateInit(FStream) <> Z_OK then
    raise EIOError.Create('inflateInit failed');
  FInitialized := True;
  FDone := False;
  FPendingFinishValidation := False;
  FPendingReadError := '';
  FBounded := False;
  FMaxOutputSize := 0;
  FOutputSize := 0;
end;

constructor TDeflateReader.Create(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt);
begin
  Create(ASrc);
  FBounded := True;
  FMaxOutputSize := AMaxOutputSize;
end;

procedure TDeflateReader.CheckOutputLimit(const ARead: SizeUInt);
begin
  if (not FBounded) or (ARead = 0) then
    Exit;
  if (ARead > FMaxOutputSize) or (FOutputSize > FMaxOutputSize - ARead) then
    raise EIOError.Create('deflate: decompressed size exceeds limit');
  Inc(FOutputSize, ARead);
end;

destructor TDeflateReader.Destroy;
begin
  if FInitialized then
    inflateEnd(FStream);
  inherited;
end;

procedure TDeflateReader.FinishStream;
var
  LRead: SizeUInt;
  LHasBufferedTrailingBytes: Boolean;
begin
  LHasBufferedTrailingBytes := FStream.avail_in <> 0;
  inflateEnd(FStream);
  FInitialized := False;
  FDone := True;
  FPendingFinishValidation := False;
  FPendingReadError := '';

  if LHasBufferedTrailingBytes then
    raise EIOError.Create('deflate: trailing bytes after stream');
  LRead := FSrc.Read(FInBuf[0], COMPRESS_BUF_SIZE);
  if LRead <> 0 then
    raise EIOError.Create('deflate: trailing bytes after stream');
end;

procedure TDeflateReader.FinishAfterFailure;
begin
  ReleaseInflateState;
  FDone := True;
  FPendingFinishValidation := False;
  FPendingReadError := '';
end;

procedure TDeflateReader.ReleaseInflateState;
begin
  if FInitialized then
  begin
    inflateEnd(FStream);
    FInitialized := False;
  end;
end;

function TDeflateReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
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
      FinishStream;
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
        LRead := FSrc.Read(FInBuf[0], COMPRESS_BUF_SIZE);
        if LRead = 0 then
          raise EIOError.Create('deflate: truncated stream');
        if (FStream.total_in = 0) and (LRead = 1) then
        begin
          if FSrc.Read(FInBuf[1], 1) <> 1 then
            raise EIOError.Create('deflate: truncated stream');
          LRead := 2;
        end;
        if (FStream.total_in = 0) and (LRead >= 2) and
           IsInvalidZlibHeader(FInBuf[0], FInBuf[1]) then
          raise EIOError.Create('deflate: invalid zlib header');
        if (FStream.total_in = 0) and (LRead >= 2) and
           HasPresetDictionaryZlibHeader(FInBuf[1]) then
          raise EIOError.Create('deflate: preset dictionary not supported');
        FStream.next_in := @FInBuf[0];
        FStream.avail_in := LRead;
      end;
      LRet := inflate(FStream, Z_NO_FLUSH);
      if LRet = Z_STREAM_END then
      begin
        Result := SizeUInt(LChunk) - SizeUInt(FStream.avail_out);
        if LProbeOnly then
        begin
          if Result > 0 then
            raise EIOError.Create('deflate: decompressed size exceeds limit');
          FinishStream;
          Exit(0);
        end;
        CheckOutputLimit(Result);
        if Result > 0 then
        begin
          FPendingFinishValidation := True;
          Exit(Result);
        end;
        FinishStream;
        Exit(0);
      end;
      if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) then
      begin
        if LRet = Z_NEED_DICT then
          raise EIOError.Create('deflate: preset dictionary not supported');
        if (LRet = Z_DATA_ERROR) and (FStream.total_in <= 2) and
           (FStream.total_out = 0) then
          raise EIOError.Create('deflate: invalid zlib header');
        if LRet = Z_DATA_ERROR then
        begin
          Result := SizeUInt(LChunk) - SizeUInt(FStream.avail_out);
          if Result > 0 then
          begin
            if LProbeOnly then
              raise EIOError.Create('deflate: decompressed size exceeds limit');
            CheckOutputLimit(Result);
            ReleaseInflateState;
            FDone := True;
            FPendingFinishValidation := False;
            FPendingReadError := 'deflate: corrupt stream';
            Exit(Result);
          end;
          raise EIOError.Create('deflate: corrupt stream');
        end;
        raise EIOError.Create('inflate failed (' + IntToStr(LRet) + ')');
      end;
    end;
    Result := SizeUInt(LChunk) - SizeUInt(FStream.avail_out);
    if LProbeOnly then
    begin
      if Result > 0 then
        raise EIOError.Create('deflate: decompressed size exceeds limit');
      Exit(0);
    end;
    CheckOutputLimit(Result);
  except
    FinishAfterFailure;
    raise;
  end;
end;

procedure TDeflateReader.Close;
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

function CreateDeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel): ICompressWriter;
begin
  if ADst = nil then
    raise EArgumentError.Create('deflate: writer is nil');
  Result := TDeflateWriter.Create(ADst, LevelToZlib(ALevel));
end;

function CreateDeflateReader(const ASrc: IReader): IDecompressReader;
begin
  if ASrc = nil then
    raise EArgumentError.Create('deflate: reader is nil');
  Result := TDeflateReader.Create(ASrc);
end;

function CreateDeflateReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;
begin
  if ASrc = nil then
    raise EArgumentError.Create('deflate: reader is nil');
  Result := TDeflateReader.Create(ASrc, AMaxOutputSize);
end;

{ One-shot }

function DeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
var
  LDstLen: ULong;
  LEmptyInput: Byte;
  LInput: pBytef;
begin
  Result := nil;
  LDstLen := compressBound(ZlibInputSize(SizeUInt(Length(AData))));
  if LDstLen = 0 then
    LDstLen := COMPRESS_BUF_SIZE;
  SetLength(Result, LDstLen);
  if Length(AData) = 0 then
  begin
    LEmptyInput := 0;
    LInput := pBytef(@LEmptyInput);
  end
  else
    LInput := pBytef(@AData[0]);
  if compress2(@Result[0], @LDstLen, LInput,
    ZlibInputSize(SizeUInt(Length(AData))), LevelToZlib(ALevel)) <> Z_OK then
    raise EIOError.Create('deflate compress failed');
  SetLength(Result, LDstLen);
end;

function DeflateDecompress(const AData: TBytes): TBytes;
const
  MAX_DECOMPRESS_SIZE = 256 * 1024 * 1024; // 256 MB limit
begin
  Result := DeflateDecompressWithMaxOutputSize(AData, MAX_DECOMPRESS_SIZE);
end;

function DeflateDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
var
  LCapacity, LOutLen, LHave, LPrevAvailIn: SizeUInt;
  LAvailOut: LongWord;
  LRet: Int32;
  LStream: z_stream;
  LInputSize: LongWord;
  LByte: Byte;
begin
  if Length(AData) < 2 then
    raise EIOError.Create('deflate: truncated stream');
  if (Length(AData) >= 2) and IsInvalidZlibHeader(AData[0], AData[1]) then
    raise EIOError.Create('deflate: invalid zlib header');
  if (Length(AData) >= 2) and HasPresetDictionaryZlibHeader(AData[1]) then
    raise EIOError.Create('deflate: preset dictionary not supported');
  LInputSize := ZlibInputSize(SizeUInt(Length(AData)));
  if AMaxOutputSize = 0 then
  begin
    FillChar(LStream, SizeOf(LStream), 0);
    LStream.next_in := @AData[0];
    LStream.avail_in := LInputSize;
    if inflateInit(LStream) <> Z_OK then
      raise EIOError.Create('inflateInit failed');
    try
      repeat
        LPrevAvailIn := SizeUInt(LStream.avail_in);
        LStream.next_out := @LByte;
        LStream.avail_out := SizeOf(LByte);
        LRet := inflate(LStream, Z_NO_FLUSH);
        LHave := SizeOf(LByte) - LStream.avail_out;
        if LHave > 0 then
          raise EIOError.Create('deflate: decompressed size exceeds limit');
        if LRet = Z_STREAM_END then
          Break;
        if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) then
        begin
          if LRet = Z_NEED_DICT then
            raise EIOError.Create('deflate: preset dictionary not supported');
          if LRet = Z_DATA_ERROR then
            raise EIOError.Create('deflate: corrupt stream');
          raise EIOError.Create('deflate decompress failed (' + IntToStr(LRet) + ')');
        end;
        if (LRet = Z_BUF_ERROR) or (SizeUInt(LStream.avail_in) = LPrevAvailIn) then
          raise EIOError.Create('deflate: truncated stream');
      until False;

      if LStream.avail_in <> 0 then
        raise EIOError.Create('deflate: trailing bytes after stream');
    finally
      inflateEnd(LStream);
    end;
    Exit(nil);
  end;
  LCapacity := SizeUInt(Length(AData)) * 4;
  if (LCapacity < SizeUInt(Length(AData))) or (LCapacity > AMaxOutputSize) then
    LCapacity := AMaxOutputSize;
  SetLength(Result, LCapacity);

  FillChar(LStream, SizeOf(LStream), 0);
  LStream.next_in := @AData[0];
  LStream.avail_in := LInputSize;
  if inflateInit(LStream) <> Z_OK then
    raise EIOError.Create('inflateInit failed');

  LOutLen := 0;
  try
    repeat
    begin
      LStream.next_out := @Result[LOutLen];
      LStream.avail_out := ZlibAvailChunk(LCapacity - LOutLen);
      LAvailOut := LStream.avail_out;
      LRet := inflate(LStream, Z_NO_FLUSH);
      if (LRet <> Z_OK) and (LRet <> Z_STREAM_END) and (LRet <> Z_BUF_ERROR) then
      begin
        if LRet = Z_NEED_DICT then
          raise EIOError.Create('deflate: preset dictionary not supported');
        if LRet = Z_DATA_ERROR then
          raise EIOError.Create('deflate: corrupt stream');
        raise EIOError.Create('deflate decompress failed (' + IntToStr(LRet) + ')');
      end;

      LOutLen := LOutLen + SizeUInt(LAvailOut - LStream.avail_out);
      if LRet = Z_STREAM_END then
        Break;
      if LOutLen >= LCapacity then
      begin
        if LCapacity >= AMaxOutputSize then
          raise EIOError.Create('deflate: decompressed size exceeds limit');
        if LCapacity > AMaxOutputSize div 2 then
          LCapacity := AMaxOutputSize
        else
          LCapacity := LCapacity * 2;
        SetLength(Result, LCapacity);
      end
      else if LRet = Z_BUF_ERROR then
        raise EIOError.Create('deflate: truncated stream');
    end;
    until False;

    if LStream.avail_in <> 0 then
      raise EIOError.Create('deflate: trailing bytes after stream');
  finally
    inflateEnd(LStream);
  end;
  SetLength(Result, LOutLen);
end;

end.
