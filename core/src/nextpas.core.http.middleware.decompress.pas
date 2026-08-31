unit nextpas.core.http.middleware.decompress;
{**
 * @desc Request body decompression middleware. Automatically decompresses
 *       gzip or deflate compressed request bodies when Content-Encoding
 *       header is present. Strips the Content-Encoding header and updates
 *       Content-Length after decompression.
 *
 *       Default AMaxSize = HTTP_DEFAULT_BODY_READ_MAX (4 MiB). Explicit 0 =
 *       unlimited (tests/tools only; production checklist forbids it).
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.http.base,
  nextpas.core.http.intf;
{** @desc Create decompression middleware.
   Decompresses gzip/deflate request bodies up to AMaxSize bytes
   (default HTTP_DEFAULT_BODY_READ_MAX). AMaxSize = 0 means no limit
   (tests/tools only). }
function DecompressMiddleware(
  const AMaxSize: Int64 = HTTP_DEFAULT_BODY_READ_MAX): IHttpMiddleware;

{** @desc Decompress with no size bound (tests/tools only).
   Prefer DecompressMiddleware / DecompressMiddleware(positive) in production. }
function DecompressMiddlewareUnlimited: IHttpMiddleware;
implementation
uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.text.conv,
  nextpas.core.compress,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.stream,
  nextpas.core.http.middleware;

type
  TDecompressedRequest = class(THttpRequestWrapper)
  private
    FHeaders: IHttpHeaders;
    FBody: IReader;
    FContentLength: Int64;
  protected
    function GetHeaders: IHttpHeaders; override;
    function GetBody: IReader; override;
    function GetContentLength: Int64; override;
  public
    constructor Create(const AInner: IHttpRequest; const AHeaders: IHttpHeaders;
      const ABody: IReader; const AContentLength: Int64);
  end;

constructor TDecompressedRequest.Create(const AInner: IHttpRequest;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64);
begin
  inherited Create(AInner);
  FHeaders := AHeaders;
  FBody := ABody;
  FContentLength := AContentLength;
end;

function TDecompressedRequest.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TDecompressedRequest.GetBody: IReader;
begin
  Result := FBody;
end;

function TDecompressedRequest.GetContentLength: Int64;
begin
  Result := FContentLength;
end;

function DecompressMiddleware(const AMaxSize: Int64): IHttpMiddleware;
begin
  if AMaxSize < 0 then
    raise EHttpError.Create(hekArgument, 'decompression max size must not be negative');

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LEncoding: string;
      LBodyBytes: TBytes;
      LBody: IReader;
      LDecompressed: TBytes;
      LNewReq: IHttpRequest;
      LNewHeaders: IHttpHeaders;
    begin
      LEncoding := LowerCase(Trim(AReq.Headers.Get('content-encoding')));
      if (LEncoding <> 'gzip') and (LEncoding <> 'deflate') then
      begin
        ANext.ServeHTTP(AReq, AW);
        Exit;
      end;
      { Read entire request body }
      LBody := AReq.Body;
      if LBody = nil then
      begin
        ANext.ServeHTTP(AReq, AW);
        Exit;
      end;
      LBodyBytes := HttpRequestReadBody(LBody, High(Int64), 4096);
      { Decompress }
      try
        { SizeUInt 与 SizeInt 同宽的 64 位平台上该上限恒可承载；
          仅 32 位及以下平台需要防御 SizeUInt 截断。 }
        {$IFNDEF CPU64}
        if (AMaxSize > 0) and (UInt64(AMaxSize) > UInt64(High(SizeUInt))) then
          raise EHttpError.Create(hekArgument, 'decompression max size exceeds platform capacity');
        {$ENDIF}
        if (LEncoding = 'gzip') and (AMaxSize > 0) then
          LDecompressed := GzipDecompressWithMaxOutputSize(
            LBodyBytes, SizeUInt(AMaxSize))
        else if LEncoding = 'gzip' then
          LDecompressed := GzipDecompress(LBodyBytes)
        else if AMaxSize > 0 then
          LDecompressed := DeflateDecompressWithMaxOutputSize(
            LBodyBytes, SizeUInt(AMaxSize))
        else
          LDecompressed := DeflateDecompress(LBodyBytes);
      except
        on E: EHttpError do
          if E.Kind = hekArgument then
            raise
          else
          begin
            HttpWriteErrorResponse(AW, HTTP_STATUS_BAD_REQUEST,
              'invalid_body', 'Failed to decompress request body');
            Exit;
          end;
        on E: EArgumentError do
          raise EHttpError.Create(hekArgument, E.Message);
        on E: Exception do
        begin
          HttpWriteErrorResponse(AW, HTTP_STATUS_BAD_REQUEST,
            'invalid_body', 'Failed to decompress request body');
          Exit;
        end;
      end;
      { Build new request with decompressed body }
      LNewHeaders := NewHttpHeaders;
      AReq.Headers.ForEach(procedure(const AName, AValue: string)
      begin
        if (LowerCase(AName) <> 'content-encoding') and
           (LowerCase(AName) <> 'content-length') then
          LNewHeaders.Add(AName, AValue);
      end);
      LNewHeaders.SetHeader('content-length',
        IntToStr(Int64(Length(LDecompressed))));
      LNewReq := TDecompressedRequest.Create(AReq, LNewHeaders,
        CreateBytesStreamFrom(LDecompressed), Int64(Length(LDecompressed)));
      ANext.ServeHTTP(LNewReq, AW);
    end);
  end);
end;

function DecompressMiddlewareUnlimited: IHttpMiddleware;
begin
  Result := DecompressMiddleware(0);
end;

end.
