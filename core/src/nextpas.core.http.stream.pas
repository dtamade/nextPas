unit nextpas.core.http.stream;
{**
 * @desc Streaming body helpers. Copy large bodies without buffering the
 *       entire payload in a single TBytes allocation.
 *
 *       HttpWriteStream only copies bytes to IHttpResponseWriter — it does
 *       NOT set Transfer-Encoding or call WriteHeader. Wire framing (chunked
 *       vs content-length) is owned by the concrete writer (e.g. H1 writer).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

{ Copy data from AReader to the response writer in chunks.
  Does not set Transfer-Encoding or Content-Length; does not WriteHeader.
  Framing is the writer's responsibility. Returns total bytes written.
  ABufSize controls the internal buffer size (default 32KB). }
function HttpWriteStream(const AW: IHttpResponseWriter;
  const AReader: IReader; const ABufSize: SizeUInt = 32768): Int64;

{ Write a streaming response with explicit Content-Length.
  Sets Content-Length header, then copies from AReader in chunks.
  Returns total bytes written. }
function HttpWriteStreamWithLength(const AW: IHttpResponseWriter;
  const AContentLength: Int64; const AReader: IReader;
  const ABufSize: SizeUInt = 32768): Int64;

{ Read request body in chunks via a callback.
  Calls AOnChunk for each chunk read from ABody.
  Returns total bytes read. Useful for processing upload streams
  without buffering the entire body in memory.

  Example:
    HttpRequestReadChunks(AReq.Body, 32768,
      procedure(const AChunk: TBytes; ACount: SizeUInt)
      begin
        ProcessChunk(AChunk, ACount);
      end); }
type
  TChunkCallback = reference to procedure(const AChunk: TBytes; ACount: SizeUInt);

function HttpRequestReadChunks(const ABody: IReader;
  const ABufSize: SizeUInt; const AOnChunk: TChunkCallback): Int64;

{ Read request body into TBytes, up to AMaxBytes.
  Returns the body bytes. Raises EHttpError if body exceeds AMaxBytes.
  This is the safe version that prevents memory exhaustion from large uploads. }
function HttpRequestReadBody(const ABody: IReader;
  const AMaxBytes: Int64; const ABufSize: SizeUInt = 32768): TBytes;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.errors,
  nextpas.core.text.conv;

procedure ValidateBufferSize(const AContext: string; const ABufSize: SizeUInt);
begin
  if ABufSize = 0 then
    raise EHttpError.Create(hekArgument,
      AContext + ': buffer size must be positive');
  if ABufSize > SizeUInt(High(SizeInt)) then
    raise EHttpError.Create(hekArgument,
      AContext + ': buffer size exceeds platform capacity');
end;

procedure WriteAllResponse(const AW: IHttpResponseWriter; const ABuf;
  const ACount: SizeUInt);
var
  LBuffer: PByte;
  LTotal, LWritten, LRemaining: SizeUInt;
begin
  LBuffer := @ABuf;
  LTotal := 0;
  while LTotal < ACount do
  begin
    LRemaining := ACount - LTotal;
    LWritten := AW.Write(LBuffer[LTotal], LRemaining);
    if LWritten = 0 then
      raise EIOError.Create('HTTP response writer made zero progress');
    if LWritten > LRemaining then
      raise EIOError.Create('HTTP response writer over-reported progress');
    Inc(LTotal, LWritten);
  end;
end;

function HttpWriteStream(const AW: IHttpResponseWriter;
  const AReader: IReader; const ABufSize: SizeUInt): Int64;
var
  LBuf: TBytes;
  LN: SizeUInt;
begin
  if AW = nil then
    raise EHttpError.Create(hekArgument, 'HttpWriteStream: response writer is nil');
  if AReader = nil then
    raise EHttpError.Create(hekArgument, 'HttpWriteStream: reader is nil');
  ValidateBufferSize('HttpWriteStream', ABufSize);

  SetLength(LBuf, ABufSize);
  Result := 0;
  repeat
    LN := AReader.Read(LBuf[0], ABufSize);
    if LN > 0 then
    begin
      if LN > ABufSize then
        raise EIOError.Create('HttpWriteStream: reader over-reported progress');
      if Int64(LN) > High(Int64) - Result then
        raise EIOError.Create('HttpWriteStream: byte count overflow');
      WriteAllResponse(AW, LBuf[0], LN);
      Inc(Result, Int64(LN));
    end;
  until LN = 0;
end;

function HttpWriteStreamWithLength(const AW: IHttpResponseWriter;
  const AContentLength: Int64; const AReader: IReader;
  const ABufSize: SizeUInt): Int64;
var
  LBuf: TBytes;
  LRemaining: Int64;
  LToRead: SizeUInt;
  LN: SizeUInt;
begin
  if AW = nil then
    raise EHttpError.Create(hekArgument,
      'HttpWriteStreamWithLength: response writer is nil');
  if AReader = nil then
    raise EHttpError.Create(hekArgument,
      'HttpWriteStreamWithLength: reader is nil');
  if AContentLength < 0 then
    raise EHttpError.Create(hekArgument,
      'HttpWriteStreamWithLength: negative content length');
  ValidateBufferSize('HttpWriteStreamWithLength', ABufSize);

  AW.GetHeaders.SetHeader('content-length', IntToStr(AContentLength));

  SetLength(LBuf, ABufSize);
  Result := 0;
  LRemaining := AContentLength;
  while LRemaining > 0 do
  begin
    if LRemaining > Int64(ABufSize) then
      LToRead := ABufSize
    else
      LToRead := SizeUInt(LRemaining);
    LN := AReader.Read(LBuf[0], LToRead);
    if LN = 0 then
      raise EIOError.Create('HttpWriteStreamWithLength: unexpected end of stream');
    if LN > LToRead then
      raise EIOError.Create('HttpWriteStreamWithLength: reader over-reported progress');
    WriteAllResponse(AW, LBuf[0], LN);
    Inc(Result, Int64(LN));
    Dec(LRemaining, Int64(LN));
  end;
end;

function HttpRequestReadChunks(const ABody: IReader;
  const ABufSize: SizeUInt; const AOnChunk: TChunkCallback): Int64;
var
  LBuf: TBytes;
  LN: SizeUInt;
begin
  if ABody = nil then
    raise EHttpError.Create(hekArgument,
      'HttpRequestReadChunks: body reader is nil');
  if not Assigned(AOnChunk) then
    raise EHttpError.Create(hekArgument,
      'HttpRequestReadChunks: callback is nil');
  ValidateBufferSize('HttpRequestReadChunks', ABufSize);

  SetLength(LBuf, ABufSize);
  Result := 0;
  repeat
    LN := ABody.Read(LBuf[0], ABufSize);
    if LN > 0 then
    begin
      if LN > ABufSize then
        raise EIOError.Create('HttpRequestReadChunks: reader over-reported progress');
      if Int64(LN) > High(Int64) - Result then
        raise EIOError.Create('HttpRequestReadChunks: byte count overflow');
      AOnChunk(LBuf, LN);
      Inc(Result, Int64(LN));
    end;
  until LN = 0;
end;

function HttpRequestReadBody(const ABody: IReader;
  const AMaxBytes: Int64; const ABufSize: SizeUInt): TBytes;
var
  LBuf: TBytes;
  LResult: TBytes;
  LResultLen: SizeUInt;
  LResultCap: SizeUInt;
  LN: SizeUInt;
  LTotal: Int64;
begin
  if ABody = nil then
    raise EHttpError.Create(hekArgument,
      'HttpRequestReadBody: body reader is nil');
  if AMaxBytes < 0 then
    raise EHttpError.Create(hekArgument,
      'HttpRequestReadBody: negative max bytes');
  ValidateBufferSize('HttpRequestReadBody', ABufSize);

  SetLength(LBuf, ABufSize);
  LResultLen := 0;
  LResultCap := 0;
  SetLength(LResult, 0);
  LTotal := 0;

  repeat
    LN := ABody.Read(LBuf[0], ABufSize);
    if LN > 0 then
    begin
      if LN > ABufSize then
        raise EIOError.Create('HttpRequestReadBody: reader over-reported progress');
      if Int64(LN) > High(Int64) - LTotal then
        raise EIOError.Create('HttpRequestReadBody: byte count overflow');
      Inc(LTotal, Int64(LN));
      if LTotal > AMaxBytes then
        raise EHttpError.Create(hekBody,
          'Request body exceeds maximum allowed size (' +
          IntToStr(AMaxBytes) + ' bytes)');

      // perf: geometric growth single source via bytes.ops.BytesGrowCapacity (BYTES_BUILDER_MIN_GROW 0→64→2×, amortized O(1), INV-5) — not inline per red-line 2 (loop I-Cache), zero-copy via BytesCopy inline single Move single source — eliminates O(n²) Cap*2 manual churn, single SetLength+BytesCopy
      if LResultLen + LN > LResultCap then
      begin
        LResultCap := BytesGrowCapacity(LResultCap, LResultLen + LN);
        SetLength(LResult, LResultCap);
      end;
      BytesCopy(@LResult[LResultLen], @LBuf[0], LN);
      Inc(LResultLen, LN);
    end;
  until LN = 0;

  SetLength(LResult, LResultLen);
  Result := LResult;
end;

end.
