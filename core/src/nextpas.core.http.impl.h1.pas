unit nextpas.core.http.impl.h1;
{**
 * @desc Default HTTP/1.x transport implementations for client and server.
 *       Owns single-request round trips, connection reuse, and per-connection
 *       request/response handling for the shared HTTP facade layer.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH1ClientTransportOptions = record
    Timeout: Int64;
  end;

  TH1ServerTransportOptions = record
    ReadTimeout: Int64;
    WriteTimeout: Int64;
    IdleTimeout: Int64;
    MaxHeaderSize: Int32;
    MaxBodySize: Int64;
  end;

function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;

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
  nextpas.core.http.impl.h1.parser,
  nextpas.core.http.impl.h1.writer;

type
  TPoolEntry = record
    Host: string;
    Port: UInt16;
    Conn: ITcpStream;
  end;

  TH1ClientTransport = class(TInterfacedObject, IHttpTransport)
  private
    FOptions: TH1ClientTransportOptions;
    FPool: array of TPoolEntry;
    FPoolCount: Int32;
    function PoolGet(const AHost: string; const APort: UInt16): ITcpStream;
    procedure PoolPut(const AHost: string; const APort: UInt16; const AConn: ITcpStream);
    function WriteRequest(const AWriter: IWriter; const AReq: IHttpRequest): Boolean;
    function ReadResponse(const AReader: IReader; out AKeepAlive: Boolean): IHttpResponse;
  public
    constructor Create(const AOptions: TH1ClientTransportOptions);
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  TH1ServerTransport = class(TInterfacedObject, IHttpServerTransport)
  private
    FOptions: TH1ServerTransportOptions;
    function HandleConnection(const AConn: ITcpStream; const AHandler: IHttpHandler): Boolean;
  public
    constructor Create(const AOptions: TH1ServerTransportOptions);
    procedure ServeConn(const AConn: ITcpStream; const AHandler: IHttpHandler);
  end;

function StrToBytes(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

function ShouldKeepAlive(const AParser: IH1Parser): Boolean;
var
  LConn: string;
begin
  LConn := AParser.GetHeaders.Get('connection');
  if AParser.GetHttpVersion = hvHttp10 then
    Result := (LConn = 'keep-alive')
  else
    Result := (LConn <> 'close');
end;

procedure WriteErrorResponse(const AConn: ITcpStream; const AStatus: THttpStatus);
var
  LW: IHttpResponseWriter;
  LBody: string;
begin
  try
    LW := TH1ResponseWriter.Create(AConn as IWriter);
    LBody := HttpStatusText(AStatus);
    LW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    LW.GetHeaders.Set_('connection', 'close');
    LW.WriteHeader(AStatus);
    if Length(LBody) > 0 then
      LW.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    { Ignore secondary write failures while sending an error response. }
  end;
end;

{ TH1ClientTransport }

constructor TH1ClientTransport.Create(const AOptions: TH1ClientTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FPoolCount := 0;
end;

function TH1ClientTransport.PoolGet(const AHost: string; const APort: UInt16): ITcpStream;
var
  LI: Int32;
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

procedure TH1ClientTransport.PoolPut(const AHost: string; const APort: UInt16;
  const AConn: ITcpStream);
begin
  if FPoolCount >= Length(FPool) then
    SetLength(FPool, FPoolCount + 4);
  FPool[FPoolCount].Host := AHost;
  FPool[FPoolCount].Port := APort;
  FPool[FPoolCount].Conn := AConn;
  Inc(FPoolCount);
end;

function TH1ClientTransport.WriteRequest(const AWriter: IWriter;
  const AReq: IHttpRequest): Boolean;
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
  if not (AReq.Version in [hvHttp10, hvHttp11]) then
    raise EHttpError.Create('h1 transport only supports HTTP/1.x requests');

  LBuf := CreateBufferedWriter(AWriter, 4096);

  LStr := HttpMethodToStr(AReq.Method);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(PAnsiChar(' ')^, 1);

  LPath := AReq.Url.Path;
  if LPath = '' then
    LPath := '/';
  if AReq.Url.RawQuery <> '' then
    LPath := LPath + '?' + AReq.Url.RawQuery;
  LBuf.Write(LPath[1], SizeUInt(Length(LPath)));

  LStr := ' ' + HttpVersionToStr(AReq.Version);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(CRLF[0], 2);

  AReq.Headers.ForEach(procedure(const AName, AValue: string)
  var
    LHeader: string;
  begin
    LHeader := AName + ': ' + AValue;
    LBuf.Write(LHeader[1], SizeUInt(Length(LHeader)));
    LBuf.Write(CRLF[0], 2);
  end);

  LBuf.Write(CRLF[0], 2);

  if AReq.Body <> nil then
  begin
    repeat
      LN := AReq.Body.Read(LTmp[0], 4096);
      if LN > 0 then
        LBuf.Write(LTmp[0], LN);
    until LN = 0;
  end;

  if Supports(LBuf, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

function TH1ClientTransport.ReadResponse(const AReader: IReader;
  out AKeepAlive: Boolean): IHttpResponse;
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

  if (not LParser.IsComplete) and (not LParser.HasError) then
    LParser.Finish;

  if LParser.HasError then
    raise EHttpError.Create('HTTP parse error: ' + LParser.ErrorMessage);
  if not LParser.IsComplete then
    raise EHttpError.Create('HTTP response incomplete: connection closed');

  AKeepAlive := LParser.ShouldKeepAlive;

  LBodyStr := LParser.GetBody;
  if LBodyStr <> '' then
  begin
    LBodyStream := CreateBytesStreamFrom(StrToBytes(LBodyStr));
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders,
      LBodyStream as IReader);
  end
  else
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders, nil);
end;

function TH1ClientTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LUrl: TUrl;
  LHost: string;
  LPort: UInt16;
  LConn: ITcpStream;
  LResp: IHttpResponse;
  LPooled: Boolean;
  LKeepAlive: Boolean;
begin
  LUrl := AReq.Url;
  LHost := LUrl.Host;
  LPort := LUrl.Port;
  if LPort = 0 then
  begin
    if LUrl.Scheme = 'https' then
      LPort := 443
    else
      LPort := 80;
  end;

  LConn := PoolGet(LHost, LPort);
  LPooled := LConn <> nil;
  if not LPooled then
    LConn := TcpConnect(LHost, LPort);

  if FOptions.Timeout > 0 then
  begin
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
    LConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
  end;

  if not AReq.Headers.Has('host') then
    AReq.Headers.Set_('host', LUrl.HostPort);

  try
    WriteRequest(LConn as IWriter, AReq);
    LResp := ReadResponse(LConn as IReader, LKeepAlive);
  except
    if LPooled then
    begin
      LConn.Close;
      LConn := TcpConnect(LHost, LPort);
      if FOptions.Timeout > 0 then
      begin
        LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
        LConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
      end;
      WriteRequest(LConn as IWriter, AReq);
      LResp := ReadResponse(LConn as IReader, LKeepAlive);
    end
    else
    begin
      LConn.Close;
      raise;
    end;
  end;

  if LKeepAlive then
    PoolPut(LHost, LPort, LConn)
  else
    LConn.Close;

  Result := LResp;
end;

{ TH1ServerTransport }

constructor TH1ServerTransport.Create(const AOptions: TH1ServerTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

function TH1ServerTransport.HandleConnection(const AConn: ITcpStream;
  const AHandler: IHttpHandler): Boolean;
var
  LParser: IH1Parser;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LUrl: TUrl;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LKeepAlive: Boolean;
  LIdleMs: Int64;
  LBufWriter: IWriter;
  LBodyStr: string;
  LBodyReader: IReader;
  LContentLen: Int64;
  LTotalRead: SizeUInt;
  LHeadersDone: Boolean;
  LRejected: Boolean;
begin
  Result := True;
  LParser := NewH1RequestParser;
  LBufWriter := CreateBufferedWriter(AConn as IWriter, 4096);
  LKeepAlive := True;
  if FOptions.IdleTimeout > 0 then
    LIdleMs := FOptions.IdleTimeout
  else
    LIdleMs := 30000;

  while LKeepAlive do
  begin
    try
      AConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(LIdleMs)));
      if FOptions.WriteTimeout > 0 then
        AConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.WriteTimeout)));

      LParser.Reset;
      LTotalRead := 0;
      LHeadersDone := False;
      LRejected := False;
      repeat
        LN := AConn.Read(LBuf[0], 4096);
        if LN = 0 then
        begin
          LKeepAlive := False;
          if (LTotalRead > 0) and (not LParser.IsComplete) and (not LParser.HasError) then
            LParser.Finish;
          Break;
        end;
        Inc(LTotalRead, LN);
        LParser.Execute(@LBuf[0], LN);
        if (not LHeadersDone) and ((LParser.GetUrl <> '') or LParser.IsComplete) then
        begin
          LHeadersDone := True;
          if (FOptions.MaxHeaderSize > 0) and
             (Int64(LTotalRead) - Int64(Length(LParser.GetBody)) >
              Int64(FOptions.MaxHeaderSize)) then
          begin
            WriteErrorResponse(AConn, HTTP_STATUS_HEADER_TOO_LARGE);
            LRejected := True;
            LKeepAlive := False;
            Break;
          end;
        end;
        if LHeadersDone and (FOptions.MaxHeaderSize > 0) and
           (LParser.GetTrailerBytes > Int64(FOptions.MaxHeaderSize)) then
        begin
          WriteErrorResponse(AConn, HTTP_STATUS_HEADER_TOO_LARGE);
          LRejected := True;
          LKeepAlive := False;
          Break;
        end;
      until LParser.IsComplete or LParser.HasError;

      if LRejected then
        Break;

      if not LParser.IsComplete then
      begin
        if LParser.HasError then
          WriteErrorResponse(AConn, HTTP_STATUS_BAD_REQUEST);
        Break;
      end;

      if FOptions.MaxBodySize > 0 then
      begin
        LBodyStr := LParser.GetBody;
        if Int64(Length(LBodyStr)) > FOptions.MaxBodySize then
        begin
          WriteErrorResponse(AConn, HTTP_STATUS_PAYLOAD_TOO_LARGE);
          LKeepAlive := False;
          Continue;
        end;
      end;

      LKeepAlive := ShouldKeepAlive(LParser);

      if (LParser.GetHttpVersion = hvHttp11) and
         (LParser.GetHeaders.Get('host') = '') then
      begin
        WriteErrorResponse(AConn, HTTP_STATUS_BAD_REQUEST);
        LKeepAlive := False;
        Continue;
      end;

      LUrl := TUrl.Parse(LParser.GetUrl);
      LBodyStr := LParser.GetBody;
      if LBodyStr <> '' then
      begin
        LBodyReader := CreateBytesStreamFrom(StrToBytes(LBodyStr)) as IReader;
        LContentLen := Int64(Length(LBodyStr));
      end
      else
      begin
        LBodyReader := nil;
        LContentLen := 0;
      end;
      LReq := THttpRequest.Create(LParser.GetMethod, LUrl, LParser.GetHttpVersion,
        LParser.GetHeaders, LBodyReader, LContentLen);

      (LReq as THttpRequest).SetRemoteAddr(AConn.RemoteAddr.ToString);

      LW := TH1ResponseWriter.Create(LBufWriter, AConn);
      if LKeepAlive and (LParser.GetHttpVersion = hvHttp10) then
        LW.GetHeaders.Set_('connection', 'keep-alive');
      if not LKeepAlive then
        LW.GetHeaders.Set_('connection', 'close');

      AHandler.ServeHTTP(LReq, LW);

      if (LW as TH1ResponseWriter).IsHijacked then
      begin
        Result := False;
        LKeepAlive := False;
        Continue;
      end;

      LW.Flush;
      (LBufWriter as IFlusher).Flush;

      if LW.GetHeaders.Get('connection') = 'close' then
        LKeepAlive := False;
    except
      on E: Exception do
      begin
        if (LW <> nil) and (LW as TH1ResponseWriter).IsHijacked then
          Result := False
        else
          WriteErrorResponse(AConn, HTTP_STATUS_INTERNAL_SERVER_ERROR);
        LKeepAlive := False;
      end;
    end;
  end;
end;

procedure TH1ServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler);
var
  LServerOwnsConn: Boolean;
begin
  LServerOwnsConn := True;
  try
    LServerOwnsConn := HandleConnection(AConn, AHandler);
  finally
    if LServerOwnsConn then
    begin
      AConn.Shutdown;
      AConn.Close;
    end;
  end;
end;

function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
begin
  Result := TH1ClientTransport.Create(AOptions);
end;

function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;
begin
  Result := TH1ServerTransport.Create(AOptions);
end;

end.
