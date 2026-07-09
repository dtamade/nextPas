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
  nextpas.core.io.buffer,
  nextpas.core.io.memory,
  nextpas.core.text.conv,
  nextpas.core.compress,
  nextpas.core.http.base,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.middleware;
function DecompressMiddleware(const AMaxSize: Int64): IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LEncoding: string;
      LBodyBytes: TBytes;
      LBody: IReader;
      LRead: SizeUInt;
      LDecompressed: TBytes;
      LNewReq: THttpRequest;
      LNewHeaders: IHttpHeaders;
    begin
      LEncoding := LowerCase(AReq.Headers.Get('content-encoding'));
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
      LBodyBytes := nil;
      SetLength(LBodyBytes, 4096);
      LRead := 0;
      while True do
      begin
        if LRead >= SizeUInt(Length(LBodyBytes)) then
        begin
          if (AMaxSize > 0) and (Int64(Length(LBodyBytes)) * 2 > AMaxSize) then
          begin
            SetLength(LBodyBytes, AMaxSize);
            Break;
          end;
          SetLength(LBodyBytes, Length(LBodyBytes) * 2);
        end;
        LRead := LRead + LBody.Read(LBodyBytes[LRead], SizeUInt(Length(LBodyBytes)) - LRead);
        if LRead < SizeUInt(Length(LBodyBytes)) then
        begin
          SetLength(LBodyBytes, LRead);
          Break;
        end;
      end;
      if LRead = 0 then
      begin
        ANext.ServeHTTP(AReq, AW);
        Exit;
      end;
      { Decompress }
      try
        if LEncoding = 'gzip' then
          LDecompressed := GzipDecompress(LBodyBytes)
        else
          LDecompressed := DeflateDecompress(LBodyBytes);
      except
        on E: Exception do
        begin
          HttpWriteErrorResponse(AW, HTTP_STATUS_BAD_REQUEST,
            'invalid_body', 'Failed to decompress request body: ' + E.Message);
          Exit;
        end;
      end;
      { Build new request with decompressed body }
      LNewHeaders := NewHttpHeaders;
      AReq.Headers.ForEach(procedure(const AName, AValue: string)
      begin
        if LowerCase(AName) <> 'content-encoding' then
          LNewHeaders.SetHeader(AName, AValue);
      end);
      LNewHeaders.SetHeader('content-length',
        IntToStr(Int64(Length(LDecompressed))));
      LNewReq := THttpRequest.Create(
        AReq.Method,
        AReq.GetUrl,
        AReq.Version,
        LNewHeaders,
        CreateBytesStreamFrom(LDecompressed),
        Int64(Length(LDecompressed))
      );
      ANext.ServeHTTP(LNewReq, AW);
    end);
  end);
end;
end.
