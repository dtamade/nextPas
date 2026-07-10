unit nextpas.core.http.middleware.decompress;
{**
 * @desc Request body decompression middleware. Automatically decompresses
 *       gzip or deflate compressed request bodies when Content-Encoding
 *       header is present. Strips the Content-Encoding header and updates
 *       Content-Length after decompression.
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.http.intf;
{** @desc Create decompression middleware.
   Decompresses gzip/deflate request bodies up to AMaxSize bytes.
   AMaxSize = 0 means no limit (not recommended for production). }
function DecompressMiddleware(const AMaxSize: Int64 = 0): IHttpMiddleware;
implementation
uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.text.conv,
  nextpas.core.compress,
  nextpas.core.http.base,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.stream,
  nextpas.core.http.middleware;

type
  TDecompressedRequest = class(TInterfacedObject, IHttpRequest)
  private
    FInner: IHttpRequest;
    FHeaders: IHttpHeaders;
    FBody: IReader;
    FContentLength: Int64;
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetPath: string;
    function GetRawQuery: string;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetTrailers: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function GetRemoteAddr: string;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
  public
    constructor Create(const AInner: IHttpRequest; const AHeaders: IHttpHeaders;
      const ABody: IReader; const AContentLength: Int64);
  end;

constructor TDecompressedRequest.Create(const AInner: IHttpRequest;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64);
begin
  inherited Create;
  FInner := AInner;
  FHeaders := AHeaders;
  FBody := ABody;
  FContentLength := AContentLength;
end;

function TDecompressedRequest.GetMethod: THttpMethod;
begin
  Result := FInner.Method;
end;

function TDecompressedRequest.GetUrl: TUrl;
begin
  Result := FInner.Url;
end;

function TDecompressedRequest.GetPath: string;
begin
  Result := FInner.Path;
end;

function TDecompressedRequest.GetRawQuery: string;
begin
  Result := FInner.RawQuery;
end;

function TDecompressedRequest.GetVersion: THttpVersion;
begin
  Result := FInner.Version;
end;

function TDecompressedRequest.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TDecompressedRequest.GetTrailers: IHttpHeaders;
begin
  Result := FInner.Trailers;
end;

function TDecompressedRequest.GetBody: IReader;
begin
  Result := FBody;
end;

function TDecompressedRequest.GetContentLength: Int64;
begin
  Result := FContentLength;
end;

function TDecompressedRequest.GetRemoteAddr: string;
begin
  Result := FInner.RemoteAddr;
end;

function TDecompressedRequest.PathParam(const AName: string): string;
begin
  Result := FInner.PathParam(AName);
end;

function TDecompressedRequest.QueryParam(const AName: string): string;
begin
  Result := FInner.QueryParam(AName);
end;

function DecompressMiddleware(const AMaxSize: Int64): IHttpMiddleware;
begin
  if AMaxSize < 0 then
    raise EArgumentError.Create('decompression max size must not be negative');

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
        if (AMaxSize > 0) and (UInt64(AMaxSize) > UInt64(High(SizeUInt))) then
          raise EArgumentError.Create('decompression max size exceeds platform capacity');
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
        on E: EArgumentError do
          raise;
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
end.
