unit nextpas.core.http.client;
{**
 * @desc HTTP/1.1 client with per-host connection pooling and keep-alive.
 *       Supports automatic redirect following.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  THttpClientOptions = record
    Timeout: Int64;           // request timeout in ms, default 30000
    MaxRedirects: Int32;      // default 10, 0 = no redirects
    FollowRedirects: Boolean; // default True
    class function Default: THttpClientOptions; static;
  end;

  TPoolEntry = record
    Host: string;
    Port: UInt16;
    Conn: ITcpStream;
  end;

  THttpClient = class(TInterfacedObject, IHttpClient)
  private
    FOptions: THttpClientOptions;
    FPool: array of TPoolEntry;
    FPoolCount: Int32;
    function PoolGet(const AHost: string; const APort: UInt16): ITcpStream;
    procedure PoolPut(const AHost: string; const APort: UInt16; const AConn: ITcpStream);
    function DoRequest(const AReq: IHttpRequest; ARedirectsLeft: Int32): IHttpResponse;
    function WriteRequest(const AWriter: IWriter; const AReq: IHttpRequest): Boolean;
    function ReadResponse(const AReader: IReader): IHttpResponse;
  public
    constructor Create(const AOptions: THttpClientOptions);
    function Do_(const AReq: IHttpRequest): IHttpResponse;
    function Get(const AUrl: string): IHttpResponse;
    function Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
    function Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
    function Delete(const AUrl: string): IHttpResponse;
    function Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
    function Head(const AUrl: string): IHttpResponse;
  end;

function NewHttpClient: IHttpClient; overload;
function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient; overload;

implementation

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.io.buffer,
  nextpas.core.io.memory,
  nextpas.core.net,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.text.conv,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.h1.parser;

function StrToBytes(const S: string): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

{ THttpClientOptions }

class function THttpClientOptions.Default: THttpClientOptions;
begin
  Result.Timeout := 30000;
  Result.MaxRedirects := 10;
  Result.FollowRedirects := True;
end;

{ THttpClient }

constructor THttpClient.Create(const AOptions: THttpClientOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FPoolCount := 0;
end;

function THttpClient.PoolGet(const AHost: string; const APort: UInt16): ITcpStream;
var LI: Int32;
begin
  Result := nil;
  for LI := 0 to FPoolCount - 1 do
    if (FPool[LI].Host = AHost) and (FPool[LI].Port = APort) then
    begin
      Result := FPool[LI].Conn;
      FPool[LI] := FPool[FPoolCount - 1];
      Dec(FPoolCount);
      Exit;
    end;
end;

procedure THttpClient.PoolPut(const AHost: string; const APort: UInt16; const AConn: ITcpStream);
begin
  if FPoolCount >= Length(FPool) then
    SetLength(FPool, FPoolCount + 4);
  FPool[FPoolCount].Host := AHost;
  FPool[FPoolCount].Port := APort;
  FPool[FPoolCount].Conn := AConn;
  Inc(FPoolCount);
end;

function THttpClient.WriteRequest(const AWriter: IWriter; const AReq: IHttpRequest): Boolean;
const
  CRLF: array[0..1] of Byte = (13, 10);
var
  LPath: string;
  LBuf: IWriter;
  LFlusher: IFlusher;
  LN: SizeUInt;
  LTmp: array[0..4095] of Byte;
  LStr: string;
begin
  Result := True;
  LBuf := CreateBufferedWriter(AWriter, 4096);

  // Request line: METHOD /path HTTP/1.1\r\n
  LStr := HttpMethodToStr(AReq.Method);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(PAnsiChar(' ')^, 1);
  LPath := AReq.Url.Path;
  if LPath = '' then
    LPath := '/';
  if AReq.Url.RawQuery <> '' then
    LPath := LPath + '?' + AReq.Url.RawQuery;
  LBuf.Write(LPath[1], SizeUInt(Length(LPath)));
  LStr := ' HTTP/1.1';
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(CRLF[0], 2);

  // Headers
  AReq.Headers.ForEach(procedure(const AName, AValue: string)
  var LHdr: string;
  begin
    LHdr := AName + ': ' + AValue;
    LBuf.Write(LHdr[1], SizeUInt(Length(LHdr)));
    LBuf.Write(CRLF[0], 2);
  end);

  // End of headers
  LBuf.Write(CRLF[0], 2);

  // Body (if any)
  if AReq.Body <> nil then
  begin
    repeat
      LN := AReq.Body.Read(LTmp[0], 4096);
      if LN > 0 then
        LBuf.Write(LTmp[0], LN);
    until LN = 0;
  end;

  // Flush
  if Supports(LBuf, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

function THttpClient.ReadResponse(const AReader: IReader): IHttpResponse;
var
  LParser: IH1Parser;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LBodyStream: IStream;
  LBodyStr: string;
begin
  LParser := NewH1ResponseParser;
  repeat
    LN := AReader.Read(LBuf[0], 4096);
    if LN = 0 then
      Break;
    LParser.Execute(@LBuf[0], LN);
  until LParser.IsComplete or LParser.HasError;

  // If connection closed before message complete, signal EOF to parser
  if (not LParser.IsComplete) and (not LParser.HasError) then
    LParser.Finish;

  if LParser.HasError then
    raise EHttpError.Create('HTTP parse error: ' + LParser.ErrorMessage);
  if not LParser.IsComplete then
    raise EHttpError.Create('HTTP response incomplete: connection closed');

  // Build body reader from parser body string
  LBodyStr := LParser.GetBody;
  if LBodyStr <> '' then
  begin
    LBodyStream := CreateBytesStreamFrom(StrToBytes(LBodyStr));
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders, LBodyStream as IReader);
  end
  else
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders, nil);
end;

function ResponseKeepAlive(const AResp: IHttpResponse): Boolean;
var LConn: string;
begin
  LConn := AResp.Headers.Get('connection');
  { HTTP/1.1 default is keep-alive unless 'close' is specified }
  Result := (LConn <> 'close');
end;

function THttpClient.DoRequest(const AReq: IHttpRequest; ARedirectsLeft: Int32): IHttpResponse;
var
  LUrl: TUrl;
  LHost: string;
  LPort: UInt16;
  LConn: ITcpStream;
  LResp: IHttpResponse;
  LLocation: string;
  LNewUrl: TUrl;
  LNewReq: IHttpRequest;
  LPooled: Boolean;
begin
  LUrl := AReq.Url;

  // Determine host and port
  LHost := LUrl.Host;
  LPort := LUrl.Port;
  if LPort = 0 then
  begin
    if LUrl.Scheme = 'https' then
      LPort := 443
    else
      LPort := 80;
  end;

  // Try pooled connection first
  LConn := PoolGet(LHost, LPort);
  LPooled := (LConn <> nil);

  if not LPooled then
    LConn := TcpConnect(LHost, LPort);

  // Set deadline
  if FOptions.Timeout > 0 then
  begin
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
    LConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
  end;

  // Ensure Host header
  if not AReq.Headers.Has('host') then
    AReq.Headers.Set_('host', LUrl.HostPort);

  // Write request + read response; retry once if pooled connection is stale
  try
    WriteRequest(LConn as IWriter, AReq);
    LResp := ReadResponse(LConn as IReader);
  except
    if LPooled then
    begin
      // Stale pooled connection — discard and retry with fresh
      LConn.Close;
      LConn := TcpConnect(LHost, LPort);
      if FOptions.Timeout > 0 then
      begin
        LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
        LConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
      end;
      WriteRequest(LConn as IWriter, AReq);
      LResp := ReadResponse(LConn as IReader);
    end
    else
    begin
      LConn.Close;
      raise;
    end;
  end;

  // Determine if we can reuse the connection
  if ResponseKeepAlive(LResp) then
    PoolPut(LHost, LPort, LConn)
  else
    LConn.Close;

  // Handle redirects
  if FOptions.FollowRedirects and
     ((LResp.StatusCode = 301) or (LResp.StatusCode = 302) or
      (LResp.StatusCode = 307) or (LResp.StatusCode = 308)) then
  begin
    if ARedirectsLeft <= 0 then
      raise EHttpError.Create('too many redirects');

    LLocation := LResp.Headers.Get('location');
    if LLocation = '' then
      raise EHttpError.Create('redirect with no Location header');

    // Parse new URL (handle relative and absolute)
    if (Pos('http://', LLocation) = 1) or (Pos('https://', LLocation) = 1) then
      LNewUrl := TUrl.Parse(LLocation)
    else
    begin
      // Relative redirect
      LNewUrl := LUrl;
      LNewUrl.Path := LLocation;
      LNewUrl.RawQuery := '';
    end;

    // For 301/302, change method to GET (drop body)
    if (LResp.StatusCode = 301) or (LResp.StatusCode = 302) then
      LNewReq := THttpRequest.Create(hmGet, LNewUrl, hvHttp11, NewHttpHeaders, nil, 0)
    else
      LNewReq := THttpRequest.Create(AReq.Method, LNewUrl, hvHttp11, NewHttpHeaders, AReq.Body, AReq.ContentLength);

    Result := DoRequest(LNewReq, ARedirectsLeft - 1);
  end
  else
    Result := LResp;
end;

function THttpClient.Do_(const AReq: IHttpRequest): IHttpResponse;
begin
  Result := DoRequest(AReq, FOptions.MaxRedirects);
end;

function THttpClient.Get(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Do_(LReq);
end;

function THttpClient.Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LBodyBuf: string;
  LTmp: array[0..4095] of Byte;
  LN: SizeUInt;
  LBodyStream: IStream;
begin
  LUrl := TUrl.Parse(AUrl);
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-type', AContentType);

  // Read all body into buffer to determine content-length
  LBodyBuf := '';
  if ABody <> nil then
  begin
    repeat
      LN := ABody.Read(LTmp[0], 4096);
      if LN > 0 then
      begin
        SetLength(LBodyBuf, Length(LBodyBuf) + Int32(LN));
        Move(LTmp[0], LBodyBuf[Length(LBodyBuf) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  end;

  LHeaders.Set_('content-length', IntToStr(Int64(Length(LBodyBuf))));

  if LBodyBuf <> '' then
  begin
    LBodyStream := CreateBytesStreamFrom(StrToBytes(LBodyBuf));
    LReq := THttpRequest.Create(hmPost, LUrl, hvHttp11, LHeaders, LBodyStream as IReader, Int64(Length(LBodyBuf)));
  end
  else
    LReq := THttpRequest.Create(hmPost, LUrl, hvHttp11, LHeaders, nil, 0);

  Result := Do_(LReq);
end;

function THttpClient.Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LBodyBuf: string;
  LTmp: array[0..4095] of Byte;
  LN: SizeUInt;
  LBodyStream: IStream;
begin
  LUrl := TUrl.Parse(AUrl);
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-type', AContentType);

  LBodyBuf := '';
  if ABody <> nil then
  begin
    repeat
      LN := ABody.Read(LTmp[0], 4096);
      if LN > 0 then
      begin
        SetLength(LBodyBuf, Length(LBodyBuf) + Int32(LN));
        Move(LTmp[0], LBodyBuf[Length(LBodyBuf) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  end;

  LHeaders.Set_('content-length', IntToStr(Int64(Length(LBodyBuf))));

  if LBodyBuf <> '' then
  begin
    LBodyStream := CreateBytesStreamFrom(StrToBytes(LBodyBuf));
    LReq := THttpRequest.Create(hmPut, LUrl, hvHttp11, LHeaders, LBodyStream as IReader, Int64(Length(LBodyBuf)));
  end
  else
    LReq := THttpRequest.Create(hmPut, LUrl, hvHttp11, LHeaders, nil, 0);

  Result := Do_(LReq);
end;

function THttpClient.Delete(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmDelete, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Do_(LReq);
end;

function THttpClient.Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LBodyBuf: string;
  LTmp: array[0..4095] of Byte;
  LN: SizeUInt;
  LBodyStream: IStream;
begin
  LUrl := TUrl.Parse(AUrl);
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-type', AContentType);

  LBodyBuf := '';
  if ABody <> nil then
  begin
    repeat
      LN := ABody.Read(LTmp[0], 4096);
      if LN > 0 then
      begin
        SetLength(LBodyBuf, Length(LBodyBuf) + Int32(LN));
        Move(LTmp[0], LBodyBuf[Length(LBodyBuf) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  end;

  LHeaders.Set_('content-length', IntToStr(Int64(Length(LBodyBuf))));

  if LBodyBuf <> '' then
  begin
    LBodyStream := CreateBytesStreamFrom(StrToBytes(LBodyBuf));
    LReq := THttpRequest.Create(hmPatch, LUrl, hvHttp11, LHeaders, LBodyStream as IReader, Int64(Length(LBodyBuf)));
  end
  else
    LReq := THttpRequest.Create(hmPatch, LUrl, hvHttp11, LHeaders, nil, 0);

  Result := Do_(LReq);
end;

function THttpClient.Head(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmHead, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Do_(LReq);
end;

{ Factory functions }

function NewHttpClient: IHttpClient;
begin
  Result := THttpClient.Create(THttpClientOptions.Default);
end;

function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := THttpClient.Create(AOptions);
end;

end.
