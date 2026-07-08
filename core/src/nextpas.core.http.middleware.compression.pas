unit nextpas.core.http.middleware.compression;
{**
 * @desc Response compression middleware. Compresses response bodies using
 *       gzip or deflate based on the client's Accept-Encoding header.
 *       Only compresses text-based content types (JSON, HTML, CSS, JS, XML, text).
 *       Skips small responses (< MIN_COMPRESS_SIZE bytes) and already-compressed
 *       content types (images, video, audio, application/zip, etc).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{** @desc Create compression middleware with default settings.
   Compresses responses >= 1024 bytes using gzip or deflate. }
function CompressionMiddleware: IHttpMiddleware;

{** @desc Create compression middleware with custom minimum size.
   AMinSize: minimum body size in bytes to trigger compression (0 = always compress). }
function CompressionMiddlewareWith(AMinSize: SizeUInt): IHttpMiddleware;

implementation

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.compress,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.message;

const
  DEFAULT_MIN_COMPRESS_SIZE = 1024;

type
  { Buffered response writer that captures body in memory.
    Forwards header operations to the real writer, but buffers Write calls.
    On Flush, writes the (optionally compressed) body to the real writer. }
  TBufferedResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FReal: IHttpResponseWriter;
    FBody: TBytes;
    FBodyLen: SizeUInt;
    FStatus: THttpStatus;
    FHeadersWritten: Boolean;
    procedure EnsureCapacity(AExtra: SizeUInt);
  public
    constructor Create(const AReal: IHttpResponseWriter);
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    { Write buffered body to real writer, optionally compressed }
    procedure FlushToReal(const AEncoding: string);
    property BodyLen: SizeUInt read FBodyLen;
    function GetBody: TBytes;
  end;

function IsCompressible(const AContentType: string): Boolean;
var
  LLower: string;
begin
  LLower := LowerCase(AContentType);
  { Text-based types that benefit from compression }
  if Pos('json', LLower) > 0 then Exit(True);
  if Pos('html', LLower) > 0 then Exit(True);
  if Pos('css', LLower) > 0 then Exit(True);
  if Pos('javascript', LLower) > 0 then Exit(True);
  if Pos('xml', LLower) > 0 then Exit(True);
  if Pos('text/', LLower) > 0 then Exit(True);
  if Pos('svg', LLower) > 0 then Exit(True);
  if Pos('font/woff', LLower) > 0 then Exit(True);
  if Pos('application/x-font', LLower) > 0 then Exit(True);
  { Already compressed types — skip }
  Result := False;
end;

function ParseAcceptEncoding(const AAcceptEncoding: string): string;
var
  LLower: string;
begin
  LLower := LowerCase(AAcceptEncoding);
  { Prefer gzip over deflate — better compression ratio }
  if Pos('gzip', LLower) > 0 then
    Exit('gzip');
  if Pos('deflate', LLower) > 0 then
    Exit('deflate');
  Result := '';
end;

{ TBufferedResponseWriter }

constructor TBufferedResponseWriter.Create(const AReal: IHttpResponseWriter);
begin
  inherited Create;
  FReal := AReal;
  FBody := nil;
  FBodyLen := 0;
  FStatus := HTTP_STATUS_OK;
  FHeadersWritten := False;
end;

procedure TBufferedResponseWriter.EnsureCapacity(AExtra: SizeUInt);
var
  LNewCap: SizeUInt;
begin
  if FBodyLen + AExtra > SizeUInt(Length(FBody)) then
  begin
    LNewCap := SizeUInt(Length(FBody)) * 2;
    if LNewCap < 4096 then
      LNewCap := 4096;
    while LNewCap < FBodyLen + AExtra do
      LNewCap := LNewCap * 2;
    SetLength(FBody, LNewCap);
  end;
end;

procedure TBufferedResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
  FHeadersWritten := True;
end;

function TBufferedResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TBufferedResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FReal.GetHeaders;
end;

function TBufferedResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  EnsureCapacity(ACount);
  Move(ABuf, FBody[FBodyLen], ACount);
  Inc(FBodyLen, ACount);
  Result := ACount;
end;

procedure TBufferedResponseWriter.Flush;
begin
  { No-op — we flush everything in FlushToReal }
end;

procedure TBufferedResponseWriter.FlushToReal(const AEncoding: string);
var
  LCompressed: TBytes;
  LBodyBytes: TBytes;
begin
  if not FHeadersWritten then
    FReal.WriteHeader(FStatus)
  else
    FReal.WriteHeader(FStatus);

  if FBodyLen = 0 then
    Exit;

  if AEncoding <> '' then
  begin
    { SetLength the body to actual size before compressing }
    LBodyBytes := Copy(FBody, 0, FBodyLen);
    try
      if AEncoding = 'gzip' then
        LCompressed := GzipCompress(LBodyBytes)
      else
        LCompressed := DeflateCompress(LBodyBytes);

      { Only use compressed version if actually smaller }
      if Length(LCompressed) < FBodyLen then
      begin
        FReal.GetHeaders.SetHeader('content-encoding', AEncoding);
        FReal.GetHeaders.SetHeader('content-length', IntToStr(Length(LCompressed)));
        FReal.GetHeaders.SetHeader('vary', 'Accept-Encoding');
        FReal.Write(LCompressed[0], Length(LCompressed));
      end
      else
      begin
        { Compression didn't help — write uncompressed }
        FReal.GetHeaders.SetHeader('content-length', IntToStr(FBodyLen));
        FReal.Write(FBody[0], FBodyLen);
      end;
    except
      { Compression failed — write uncompressed }
      FReal.GetHeaders.SetHeader('content-length', IntToStr(FBodyLen));
      FReal.Write(FBody[0], FBodyLen);
    end;
  end
  else
  begin
    FReal.GetHeaders.SetHeader('content-length', IntToStr(FBodyLen));
    FReal.Write(FBody[0], FBodyLen);
  end;
end;

function TBufferedResponseWriter.GetBody: TBytes;
begin
  SetLength(Result, FBodyLen);
  if FBodyLen > 0 then
    Move(FBody[0], Result[0], FBodyLen);
end;

{ CompressionMiddleware }

function CompressionMiddleware: IHttpMiddleware;
begin
  Result := CompressionMiddlewareWith(DEFAULT_MIN_COMPRESS_SIZE);
end;

function CompressionMiddlewareWith(AMinSize: SizeUInt): IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBuf: TBufferedResponseWriter;
      LAcceptEncoding, LEncoding: string;
      LContentType: string;
      LUseCompression: Boolean;
    begin
      LAcceptEncoding := AReq.GetHeaders.Get('accept-encoding');
      LEncoding := ParseAcceptEncoding(LAcceptEncoding);

      { Create buffered writer — always buffer to check content type and size }
      LBuf := TBufferedResponseWriter.Create(AW);
      ANext.ServeHTTP(AReq, LBuf);

      { Decide whether to compress }
      LUseCompression := False;
      if LEncoding <> '' then
      begin
        if LBuf.BodyLen >= AMinSize then
        begin
          LContentType := AW.GetHeaders.Get('content-type');
          if IsCompressible(LContentType) then
            LUseCompression := True;
        end;
      end;

      if LUseCompression then
        LBuf.FlushToReal(LEncoding)
      else
        LBuf.FlushToReal('');
    end);
  end);
end;

end.
