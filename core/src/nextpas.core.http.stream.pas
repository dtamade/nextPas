unit nextpas.core.http.stream;
{**
 * @desc Streaming response helpers. Allows sending large bodies without
 *       buffering the entire content in memory.
 *       Uses chunked transfer-encoding when no Content-Length is declared.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

{ Copy data from AReader to the response writer in chunks.
  The response must not have been committed yet (no WriteHeader/Write called).
  Sets transfer-encoding: chunked if no Content-Length is declared.
  Returns total bytes written.
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
  nextpas.core.errors,
  nextpas.core.text.conv;

function HttpWriteStream(const AW: IHttpResponseWriter;
  const AReader: IReader; const ABufSize: SizeUInt): Int64;
var
  LBuf: TBytes;
  LN: SizeUInt;
begin
  if AW = nil then
    raise EArgumentError.Create('HttpWriteStream: response writer is nil');
  if AReader = nil then
    raise EArgumentError.Create('HttpWriteStream: reader is nil');

  SetLength(LBuf, ABufSize);
  Result := 0;
  repeat
    LN := AReader.Read(LBuf[0], ABufSize);
    if LN > 0 then
    begin
      AW.Write(LBuf[0], LN);
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
    raise EArgumentError.Create('HttpWriteStreamWithLength: response writer is nil');
  if AReader = nil then
    raise EArgumentError.Create('HttpWriteStreamWithLength: reader is nil');
  if AContentLength < 0 then
    raise EArgumentError.Create('HttpWriteStreamWithLength: negative content length');

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
    AW.Write(LBuf[0], LN);
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
    raise EArgumentError.Create('HttpRequestReadChunks: body reader is nil');
  if not Assigned(AOnChunk) then
    raise EArgumentError.Create('HttpRequestReadChunks: callback is nil');

  SetLength(LBuf, ABufSize);
  Result := 0;
  repeat
    LN := ABody.Read(LBuf[0], ABufSize);
    if LN > 0 then
    begin
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
    raise EArgumentError.Create('HttpRequestReadBody: body reader is nil');
  if AMaxBytes < 0 then
    raise EArgumentError.Create('HttpRequestReadBody: negative max bytes');

  SetLength(LBuf, ABufSize);
  LResultLen := 0;
  LResultCap := 0;
  SetLength(LResult, 0);
  LTotal := 0;

  repeat
    LN := ABody.Read(LBuf[0], ABufSize);
    if LN > 0 then
    begin
      Inc(LTotal, Int64(LN));
      if LTotal > AMaxBytes then
        raise EHttpError.CreateFmt(
          'Request body exceeds maximum allowed size (%d bytes)', [AMaxBytes]);

      { Grow result buffer }
      if LResultLen + LN > LResultCap then
      begin
        if LResultCap = 0 then
          LResultCap := ABufSize * 2
        else
          LResultCap := LResultCap * 2;
        if LResultCap < LResultLen + LN then
          LResultCap := LResultLen + LN;
        SetLength(LResult, LResultCap);
      end;

      Move(LBuf[0], LResult[LResultLen], LN);
      Inc(LResultLen, LN);
    end;
  until LN = 0;

  SetLength(LResult, LResultLen);
  Result := LResult;
end;

end.
