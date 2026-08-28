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
function CreateDeflateReaderEmbedded(const ASrc: IReader): IDecompressReader;
function CreateDeflateReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;

{ RAW DEFLATE (RFC 1951) 流式变体：windowBits=-15，与 zlib 包装版共享
  推拉语义（ICompressWriter / IDecompressReader），供 ZIP 等容器增量编解码。 }
function CreateRawDeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel = clDefault): ICompressWriter;
function CreateRawDeflateReader(const ASrc: IReader): IDecompressReader;
function CreateRawDeflateReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;

function DeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes;
function DeflateDecompress(const AData: TBytes): TBytes;
function DeflateDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;

{ RFC 7692 permessage-deflate wire helpers: raw DEFLATE (windowBits=-15),
  no zlib header; empty DEFLATE block trailer stripped on compress and
  restored on decompress. No context takeover (fresh stream per message). }
function RawDeflateMessageCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes;
function RawDeflateMessageDecompress(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;

{ RAW DEFLATE (RFC 1951) one-shot：windowBits=-15，完整终结块（Z_FINISH /
  Z_STREAM_END 语义），供 ZIP 等容器格式承载 method=8 条目。与
  RawDeflateMessage* 不同：不剥除、不补写尾部空块，不接受 SYNC_FLUSH 截断流。 }
function RawDeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes;
function RawDeflateDecompress(const AData: TBytes): TBytes;
function RawDeflateDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
{** 带期望输出尺寸的 RAW inflate：预分配一次到位（zip 等容器声明了
    未压缩尺寸时避免倍增扩容）；实际输出仍受 AMaxOutputSize 强制约束，
    声明值只是容量提示不参与正确性判定。 *}
function RawDeflateDecompressSized(const AData: TBytes;
  const AExpectedOutputSize, AMaxOutputSize: SizeUInt): TBytes;

{** RAW inflate 直写 PByte 缓冲（零分配）：将 APayload 解压到 ADst[0..ADstLen-1]，
    返回实际解压字节数；ADstLen 与 AMaxOutputSize 双重约束，超限或缓冲不足均 raise；
    无分配，调用方可栈上/堆上预分配后复用。 *}
function RawDeflateDecompressToBuffer(const AData: TBytes; const ADst: PByte;
  const ADstLen, AMaxOutputSize: SizeUInt): SizeUInt;

{ 7z 兼容别名：历史 sevenz writer 调用 DeflateRawCompress，语义同 RawDeflateCompress }
function DeflateRawCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes; inline;

implementation

uses
  zlib, nextpas.core.errors, nextpas.core.exception;

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
    procedure InitStream(const ADst: IWriter; ALevel, AWindowBits: Int32);
  public
    constructor Create(const ADst: IWriter; ALevel: Int32);
    constructor CreateRaw(const ADst: IWriter; ALevel: Int32);
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
    FRaw: Boolean;               { windowBits=-15：跳过 zlib 头预检 }
    FEmbedded: Boolean;
    FMaxOutputSize: SizeUInt;
    FOutputSize: SizeUInt;
    procedure CheckOutputLimit(const ARead: SizeUInt);
    procedure FinishStream;
    procedure ReleaseInflateState;
    procedure FinishAfterFailure;
    procedure InitStream(const ASrc: IReader; AWindowBits: Int32);
  public
    constructor Create(const ASrc: IReader); overload;
    constructor Create(const ASrc: IReader; const AMaxOutputSize: SizeUInt); overload;
    { Stops at the end of the first zlib stream and leaves trailing source
      bytes unconsumed, for embedded-stream containers (git pack, PDF, ...). }
    constructor CreateEmbedded(const ASrc: IReader);
    constructor CreateRaw(const ASrc: IReader); overload;
    constructor CreateRaw(const ASrc: IReader;
      const AMaxOutputSize: SizeUInt); overload;
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

procedure TDeflateWriter.InitStream(const ADst: IWriter;
  ALevel, AWindowBits: Int32);
begin
  FDst := ADst;
  FillChar(FStream, SizeOf(FStream), 0);
  if deflateInit2(FStream, ALevel, Z_DEFLATED, AWindowBits, 8,
    Z_DEFAULT_STRATEGY) <> Z_OK then
    raise EIOError.Create('deflateInit2 failed');
  FInitialized := True;
  FClosedSuccessfully := False;
end;

constructor TDeflateWriter.Create(const ADst: IWriter; ALevel: Int32);
begin
  inherited Create;
  InitStream(ADst, ALevel, 15);
end;

constructor TDeflateWriter.CreateRaw(const ADst: IWriter; ALevel: Int32);
begin
  inherited Create;
  InitStream(ADst, ALevel, -15);
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

procedure TDeflateReader.InitStream(const ASrc: IReader; AWindowBits: Int32);
begin
  FSrc := ASrc;
  FillChar(FStream, SizeOf(FStream), 0);
  if inflateInit2(FStream, AWindowBits) <> Z_OK then
    raise EIOError.Create('inflateInit2 failed');
  FInitialized := True;
  FDone := False;
  FPendingFinishValidation := False;
  FPendingReadError := '';
  FBounded := False;
  FEmbedded := False;
  FRaw := AWindowBits < 0;
  FMaxOutputSize := 0;
  FOutputSize := 0;
end;

constructor TDeflateReader.Create(const ASrc: IReader);
begin
  inherited Create;
  InitStream(ASrc, 15);
end;

constructor TDeflateReader.Create(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt);
begin
  Create(ASrc);
  FBounded := True;
  FMaxOutputSize := AMaxOutputSize;
end;

constructor TDeflateReader.CreateEmbedded(const ASrc: IReader);
begin
  Create(ASrc);
  FEmbedded := True;
end;

constructor TDeflateReader.CreateRaw(const ASrc: IReader);
begin
  inherited Create;
  InitStream(ASrc, -15);
end;

constructor TDeflateReader.CreateRaw(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt);
begin
  CreateRaw(ASrc);
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
  LToutBefore: SizeUInt;
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
      { 先推进解压再补源：输出缓冲恰好用满时，zlib 会把流结束检测挂起
        到下一次 inflate 调用（无需新输入），若此时先去补源会把合法的
        收尾误判为截断。仅当本轮毫无进展且源已耗尽才是真截断。 }
      LToutBefore := FStream.total_out;
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
          if FEmbedded then
          begin
            ReleaseInflateState;
            FDone := True;
            Exit(Result);
          end;
          FPendingFinishValidation := True;
          Exit(Result);
        end;
        if FEmbedded then
        begin
          ReleaseInflateState;
          FDone := True;
        end
        else
          FinishStream;
        Exit(0);
      end;
      if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) then
      begin
        if LRet = Z_NEED_DICT then
          raise EIOError.Create('deflate: preset dictionary not supported');
        if (LRet = Z_DATA_ERROR) and not FRaw and (FStream.total_in <= 2) and
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
      { 本轮无进展且输入耗尽才向源补数；源已尽则先给 inflate 一次
        空输入调用以冲掉挂起的收尾，仍无进展方判截断 }
      if (FStream.avail_in = 0) and
         not LProbeOnly and (FStream.total_out > LToutBefore) then
        Continue;
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
        if not FRaw then
        begin
          if (FStream.total_in = 0) and (LRead >= 2) and
             IsInvalidZlibHeader(FInBuf[0], FInBuf[1]) then
            raise EIOError.Create('deflate: invalid zlib header');
          if (FStream.total_in = 0) and (LRead >= 2) and
             HasPresetDictionaryZlibHeader(FInBuf[1]) then
            raise EIOError.Create('deflate: preset dictionary not supported');
        end;
        FStream.next_in := @FInBuf[0];
        FStream.avail_in := LRead;
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

function CreateDeflateReaderEmbedded(const ASrc: IReader): IDecompressReader;
begin
  if ASrc = nil then
    raise EArgumentError.Create('deflate: reader is nil');
  Result := TDeflateReader.CreateEmbedded(ASrc);
end;

function CreateRawDeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel): ICompressWriter;
begin
  if ADst = nil then
    raise EArgumentError.Create('raw deflate: writer is nil');
  Result := TDeflateWriter.CreateRaw(ADst, LevelToZlib(ALevel));
end;

function CreateRawDeflateReader(const ASrc: IReader): IDecompressReader;
begin
  if ASrc = nil then
    raise EArgumentError.Create('raw deflate: reader is nil');
  Result := TDeflateReader.CreateRaw(ASrc);
end;

function CreateRawDeflateReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;
begin
  if ASrc = nil then
    raise EArgumentError.Create('raw deflate: reader is nil');
  Result := TDeflateReader.CreateRaw(ASrc, AMaxOutputSize);
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

function RawDeflateMessageCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
var
  LStream: z_stream;
  LOut: TBytes;
  LOutLen: SizeUInt;
  LCapacity: SizeUInt;
  LRet: Int32;
  LAvailOut: LongWord;
  LEmpty: Byte;
  LInput: pBytef;
  LInputLen: LongWord;
begin
  { permessage-deflate: raw DEFLATE + strip trailing empty block (00 00 FF FF). }
  FillChar(LStream, SizeOf(LStream), 0);
  if deflateInit2(LStream, LevelToZlib(ALevel), Z_DEFLATED, -15, 8,
    Z_DEFAULT_STRATEGY) <> Z_OK then
    raise EIOError.Create('raw deflateInit2 failed');
  try
    LInputLen := ZlibInputSize(SizeUInt(Length(AData)));
    if Length(AData) = 0 then
    begin
      LEmpty := 0;
      LInput := pBytef(@LEmpty);
      LStream.avail_in := 0;
    end
    else
    begin
      LInput := pBytef(@AData[0]);
      LStream.avail_in := LInputLen;
    end;
    LStream.next_in := LInput;
    LCapacity := SizeUInt(Length(AData)) + 64;
    if LCapacity < 64 then
      LCapacity := 64;
    SetLength(LOut, LCapacity);
    LOutLen := 0;
    repeat
      if LOutLen >= LCapacity then
      begin
        if LCapacity > High(SizeUInt) div 2 then
          LCapacity := LCapacity + 65536
        else
          LCapacity := LCapacity * 2;
        SetLength(LOut, LCapacity);
      end;
      LStream.next_out := @LOut[LOutLen];
      LStream.avail_out := ZlibAvailChunk(LCapacity - LOutLen);
      LAvailOut := LStream.avail_out;
      LRet := deflate(LStream, Z_SYNC_FLUSH);
      if (LRet <> Z_OK) and (LRet <> Z_STREAM_END) and (LRet <> Z_BUF_ERROR) then
        raise EIOError.Create('raw deflate failed (' + IntToStr(LRet) + ')');
      LOutLen := LOutLen + SizeUInt(LAvailOut - LStream.avail_out);
    until (LStream.avail_in = 0) and (LStream.avail_out > 0);
    { Strip trailing empty DEFLATE block 00 00 FF FF when present. }
    if (LOutLen >= 4) and
       (LOut[LOutLen - 4] = $00) and (LOut[LOutLen - 3] = $00) and
       (LOut[LOutLen - 2] = $FF) and (LOut[LOutLen - 1] = $FF) then
      Dec(LOutLen, 4);
    SetLength(LOut, LOutLen);
    Result := LOut;
  finally
    deflateEnd(LStream);
  end;
end;

function RawDeflateMessageDecompress(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
var
  LStream: z_stream;
  LIn: TBytes;
  LInLen: SizeUInt;
  LCapacity, LOutLen: SizeUInt;
  LRet: Int32;
  LAvailOut: LongWord;
begin
  if AMaxOutputSize = 0 then
    raise EIOError.Create('raw inflate: max output size must be > 0');
  Result := nil;
  LInLen := SizeUInt(Length(AData)) + 4;
  SetLength(LIn, LInLen);
  if Length(AData) > 0 then
    Move(AData[0], LIn[0], Length(AData));
  LIn[LInLen - 4] := $00;
  LIn[LInLen - 3] := $00;
  LIn[LInLen - 2] := $FF;
  LIn[LInLen - 1] := $FF;

  FillChar(LStream, SizeOf(LStream), 0);
  if Length(LIn) > 0 then
  begin
    LStream.next_in := @LIn[0];
    LStream.avail_in := ZlibInputSize(LInLen);
  end;
  if inflateInit2(LStream, -15) <> Z_OK then
    raise EIOError.Create('raw inflateInit2 failed');
  try
    LCapacity := SizeUInt(Length(AData)) * 4;
    if LCapacity < 64 then
      LCapacity := 64;
    if LCapacity > AMaxOutputSize then
      LCapacity := AMaxOutputSize;
    SetLength(Result, LCapacity);
    LOutLen := 0;
    repeat
      if LOutLen >= LCapacity then
      begin
        if LCapacity >= AMaxOutputSize then
          raise EIOError.Create('raw inflate: decompressed size exceeds limit');
        if LCapacity > AMaxOutputSize div 2 then
          LCapacity := AMaxOutputSize
        else
          LCapacity := LCapacity * 2;
        SetLength(Result, LCapacity);
      end;
      LStream.next_out := @Result[LOutLen];
      LStream.avail_out := ZlibAvailChunk(LCapacity - LOutLen);
      LAvailOut := LStream.avail_out;
      { Z_SYNC_FLUSH wire (permessage-deflate) completes without Z_STREAM_END. }
      LRet := inflate(LStream, Z_SYNC_FLUSH);
      if (LRet <> Z_OK) and (LRet <> Z_STREAM_END) and (LRet <> Z_BUF_ERROR) then
      begin
        if LRet = Z_DATA_ERROR then
          raise EIOError.Create('raw inflate: corrupt stream');
        raise EIOError.Create('raw inflate failed (' + IntToStr(LRet) + ')');
      end;
      LOutLen := LOutLen + SizeUInt(LAvailOut - LStream.avail_out);
      if LRet = Z_STREAM_END then
        Break;
      { After SYNC_FLUSH marker + empty block: avail_in=0 and Z_BUF_ERROR means done. }
      if (LStream.avail_in = 0) and
         ((LRet = Z_BUF_ERROR) or ((LRet = Z_OK) and (LStream.avail_out > 0))) then
        Break;
      if LRet = Z_BUF_ERROR then
        raise EIOError.Create('raw inflate: truncated stream');
    until False;
    SetLength(Result, LOutLen);
  finally
    inflateEnd(LStream);
  end;
end;

function RawDeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
var
  LStream: z_stream;
  LOut: TBytes;
  LOutLen, LCapacity: SizeUInt;
  LRet: Int32;
  LAvailOut: LongWord;
  LEmpty: Byte;
  LInput: pBytef;
begin
  { 完整 raw 流：Z_FINISH 直至 Z_STREAM_END，不剥尾部空块。 }
  FillChar(LStream, SizeOf(LStream), 0);
  if deflateInit2(LStream, LevelToZlib(ALevel), Z_DEFLATED, -15, 8,
    Z_DEFAULT_STRATEGY) <> Z_OK then
    raise EIOError.Create('raw deflateInit2 failed');
  try
    if Length(AData) = 0 then
    begin
      LEmpty := 0;
      LInput := pBytef(@LEmpty);
      LStream.avail_in := 0;
    end
    else
    begin
      LInput := pBytef(@AData[0]);
      LStream.avail_in := ZlibInputSize(SizeUInt(Length(AData)));
    end;
    LStream.next_in := LInput;
    LCapacity := SizeUInt(Length(AData)) + 64;
    if LCapacity < 64 then
      LCapacity := 64;
    SetLength(LOut, LCapacity);
    LOutLen := 0;
    repeat
      if LOutLen >= LCapacity then
      begin
        if LCapacity > High(SizeUInt) div 2 then
          LCapacity := LCapacity + 65536
        else
          LCapacity := LCapacity * 2;
        SetLength(LOut, LCapacity);
      end;
      LStream.next_out := @LOut[LOutLen];
      LStream.avail_out := ZlibAvailChunk(LCapacity - LOutLen);
      LAvailOut := LStream.avail_out;
      LRet := deflate(LStream, Z_FINISH);
      LOutLen := LOutLen + SizeUInt(LAvailOut - LStream.avail_out);
      if LRet = Z_STREAM_END then
        Break;
      if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) then
        raise EIOError.Create('raw deflate failed (' + IntToStr(LRet) + ')');
    until False;
    SetLength(LOut, LOutLen);
    Result := LOut;
  finally
    deflateEnd(LStream);
  end;
end;

function RawDeflateDecompress(const AData: TBytes): TBytes;
const
  MAX_DECOMPRESS_SIZE = 256 * 1024 * 1024; // 与 DeflateDecompress 同默认上限
begin
  Result := RawDeflateDecompressWithMaxOutputSize(AData, MAX_DECOMPRESS_SIZE);
end;

function RawInflateOneShot(const AData: TBytes;
  const AMaxOutputSize, ACapacityHint: SizeUInt): TBytes; forward;

function RawDeflateDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := RawInflateOneShot(AData, AMaxOutputSize, 0);
end;

function RawDeflateDecompressSized(const AData: TBytes;
  const AExpectedOutputSize, AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := RawInflateOneShot(AData, AMaxOutputSize, AExpectedOutputSize);
end;

function RawInflateOneShot(const AData: TBytes;
  const AMaxOutputSize, ACapacityHint: SizeUInt): TBytes;
var
  LStream: z_stream;
  LCapacity, LOutLen: SizeUInt;
  LAvailOut: LongWord;
  LRet: Int32;
begin
  if AMaxOutputSize = 0 then
    raise EIOError.Create('raw inflate: max output size must be > 0');
  Result := nil;
  FillChar(LStream, SizeOf(LStream), 0);
  if Length(AData) > 0 then
  begin
    LStream.next_in := @AData[0];
    LStream.avail_in := ZlibInputSize(SizeUInt(Length(AData)));
  end;
  if inflateInit2(LStream, -15) <> Z_OK then
    raise EIOError.Create('raw inflateInit2 failed');
  try
    { 初始容量：调用方提示（如容器声明的未压缩尺寸）优先，避免反复扩容 }
    LCapacity := SizeUInt(Length(AData)) * 4;
    if ACapacityHint > LCapacity then
      LCapacity := ACapacityHint;
    if LCapacity < 64 then
      LCapacity := 64;
    if LCapacity > AMaxOutputSize then
      LCapacity := AMaxOutputSize;
    SetLength(Result, LCapacity);
    LOutLen := 0;
    repeat
      if LOutLen >= LCapacity then
      begin
        if LCapacity >= AMaxOutputSize then
          raise EIOError.Create('raw inflate: decompressed size exceeds limit');
        if LCapacity > AMaxOutputSize div 2 then
          LCapacity := AMaxOutputSize
        else
          LCapacity := LCapacity * 2;
        SetLength(Result, LCapacity);
      end;
      LStream.next_out := @Result[LOutLen];
      LStream.avail_out := ZlibAvailChunk(LCapacity - LOutLen);
      LAvailOut := LStream.avail_out;
      LRet := inflate(LStream, Z_NO_FLUSH);
      if (LRet <> Z_OK) and (LRet <> Z_STREAM_END) and (LRet <> Z_BUF_ERROR) then
      begin
        if LRet = Z_DATA_ERROR then
          raise EIOError.Create('raw inflate: corrupt stream');
        raise EIOError.Create('raw inflate failed (' + IntToStr(LRet) + ')');
      end;
      LOutLen := LOutLen + SizeUInt(LAvailOut - LStream.avail_out);
      if LRet = Z_STREAM_END then
        Break;
      if (LRet = Z_BUF_ERROR) and (LStream.avail_in = 0) and (LAvailOut > 0) then
        raise EIOError.Create('raw inflate: truncated stream');
    until False;
    if LStream.avail_in <> 0 then
      raise EIOError.Create('raw inflate: trailing bytes after stream');
    SetLength(Result, LOutLen);
  finally
    inflateEnd(LStream);
  end;
end;

function RawDeflateDecompressToBuffer(const AData: TBytes; const ADst: PByte;
  const ADstLen, AMaxOutputSize: SizeUInt): SizeUInt;
var
  LStream: z_stream;
  LRet: Int32;
begin
  if ADst = nil then
  begin
    if ADstLen <> 0 then
      raise EArgumentError.Create('raw inflate: nil dest buffer');
    if Length(AData) = 0 then
      Exit(0);
    raise EArgumentError.Create('raw inflate: dest buffer too small');
  end;
  if AMaxOutputSize = 0 then
    raise EIOError.Create('raw inflate: max output size must be > 0');
  if ADstLen > AMaxOutputSize then
    raise EIOError.Create('raw inflate: dest buffer exceeds max output limit');
  Result := 0;
  FillChar(LStream, SizeOf(LStream), 0);
  if Length(AData) > 0 then
  begin
    LStream.next_in := @AData[0];
    LStream.avail_in := ZlibInputSize(SizeUInt(Length(AData)));
  end;
  if inflateInit2(LStream, -15) <> Z_OK then
    raise EIOError.Create('raw inflateInit2 failed');
  try
    LStream.next_out := pBytef(ADst);
    LStream.avail_out := ZlibAvailChunk(ADstLen);
    repeat
      LRet := inflate(LStream, Z_NO_FLUSH);
      if LRet = Z_STREAM_END then
        Break;
      if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) then
      begin
        if LRet = Z_DATA_ERROR then
          raise EIOError.Create('raw inflate: corrupt stream');
        raise EIOError.Create('raw inflate failed (' + IntToStr(LRet) + ')');
      end;
      if (LRet = Z_BUF_ERROR) and (LStream.avail_in = 0) and (LStream.avail_out > 0) then
        raise EIOError.Create('raw inflate: truncated stream');
      if LStream.avail_out = 0 then
      begin
        if LRet = Z_OK then
          raise EIOError.Create('raw inflate: dest buffer too small');
        Break;
      end;
    until False;
    if LStream.avail_in <> 0 then
      raise EIOError.Create('raw inflate: trailing bytes after stream');
    Result := ADstLen - SizeUInt(LStream.avail_out);
    if Result > AMaxOutputSize then
      raise EIOError.Create('raw inflate: decompressed size exceeds limit');
  finally
    inflateEnd(LStream);
  end;
end;

function DeflateRawCompress(const AData: TBytes; const ALevel: TCompressionLevel): TBytes;
begin
  Result := RawDeflateCompress(AData, ALevel);
end;

end.

