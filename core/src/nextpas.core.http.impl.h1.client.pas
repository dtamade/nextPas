unit nextpas.core.http.impl.h1.client;
{**
 * @desc H1 client transport (STRUCT residual extract from impl.h1).
 *       Owns RoundTrip, idle pool use, proxy CONNECT, cancel/deadline arming.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.platform.io.base,
  nextpas.core.tls.base,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH1ClientTransportOptions = record
    Timeout: Int64;
    { OS dial + post-dial first-write budget for newly opened sockets (ms).
      0 = dial uses Timeout when Timeout > 0; post-dial first-write uses Timeout. }
    ConnectTimeout: Int64;
    { Max idle connections retained per pool authority key (host/port, with
      scheme/proxy variants encoded in the host key). Not a global pool cap. }
    MaxPoolSize: Int32;
    { Wall-clock idle TTL (ms). 0 = no TTL. Default comes from client options. }
    IdleTTL: Int64;
    { Plain HTTP forward proxy URL (http://[user:pass@]host:port). Empty = direct.
      For https targets, client dials proxy and opens a CONNECT tunnel, then
      TLS-wraps the tunneled stream (SNI = origin host). Plain http targets
      keep absolute-form forwarding (no CONNECT). When UserInfo is present,
      injects Proxy-Authorization: Basic (raw userinfo, no percent-decode)
      on CONNECT and on absolute-form when the request lacks that header.
      Wave I freeze: Basic only — no Digest/NTLM/Negotiate challenge retry. }
    ProxyUrl: string;
    { Custom transport dial (see THttpClientOptions.DialFunc). When assigned,
      every fresh connection is established through it instead of the built-in
      TcpConnect; ProxyUrl takes precedence when both are set. }
    DialFunc: THttpDialFunc;
    { Optional client TLS context for direct H1 https and https-over-CONNECT.
      Nil uses TSSLQuick.SecureClient. }
    TLSContext: ISSLContext;
  end;


function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;

implementation

uses
  nextpas.core.base, nextpas.core.base.utils, nextpas.core.errors,
  nextpas.core.io.base, nextpas.core.io.buffer, nextpas.core.io.memory,
  nextpas.core.net,
  nextpas.core.time.base, nextpas.core.time.deadline, nextpas.core.time,
  nextpas.core.text.conv,
  nextpas.core.encoding,
  nextpas.core.http.headers, nextpas.core.http.message,
  nextpas.core.http.impl.cancel.adapter,
  nextpas.core.http.impl.h1.pool,
  nextpas.core.http.impl.h1.wire,
  nextpas.core.http.impl.h1.parser,
  nextpas.core.http.impl.h1.chunked,
  nextpas.core.http.impl.h1.prepend,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.tls.quick;

type
  TH1ClientTransport = class(TInterfacedObject, IHttpTransport,
    IHttpTransportIdleConnections)
  private
    FOptions: TH1ClientTransportOptions;
    FPool: TH1IdleConnectionPool;
    FDefaultTLSContext: ISSLContext;
    function SecureClientContext: ISSLContext;
    function WriteRequest(const AWriter: IWriter; const AReq: IHttpRequest;
      const AAutoHost: string; const AAbsoluteForm: Boolean;
      const AProxyAuthorization: string): Boolean;
    function ReadResponse(const AReader: IReader;
      const ARequestMethod: THttpMethod; out AKeepAlive: Boolean;
      out AResponseStarted: Boolean; var APending: string;
      const AOnBodyChunk: THttpResponseBodyChunkProc = nil;
      const AOnResponseStatus: THttpResponseStatusProc = nil;
      const ASkipBodyBuffer: Boolean = False): IHttpResponse;
    procedure EstablishHttpsConnectTunnel(var AConn: ITcpStream;
      const ATargetHost: string; const ATargetPort: UInt16;
      const AProxyAuthorization: string);
  public
    constructor Create(const AOptions: TH1ClientTransportOptions);
    destructor Destroy; override;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    procedure CloseIdleConnections;
  end;


function IsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
begin
  Result := HttpIsRetryableMethod(AMethod);
end;

function HasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean; inline;
begin
  Result := HttpHasRetryIdempotencyKey(AReq);
end;

function IsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;
begin
  Result := HttpIsRetrySafeRequest(AReq);
end;

function IsSkippableInformationalResponse(const AStatus: THttpStatus): Boolean; inline;
begin
  Result := HttpStatusIsInformational(AStatus) and
    (AStatus <> HTTP_STATUS_SWITCHING_PROTOCOLS);
end;

function CaptureRetryBodyPosition(const AReq: IHttpRequest;
  out ABodyStream: IStream; out AStartPosition: Int64): Boolean;
begin
  ABodyStream := nil;
  AStartPosition := 0;
  { ContentLength = 0 means no body bytes; < 0 is chunked unknown-length. }
  if (AReq = nil) or (AReq.Body = nil) or (AReq.ContentLength = 0) then
    Exit(True);
  Result := Supports(AReq.Body, IStream, ABodyStream);
  if Result then
    AStartPosition := ABodyStream.Position;
end;

procedure RewindRetryBody(const AReq: IHttpRequest; const ABodyStream: IStream;
  const AStartPosition: Int64);
begin
  if (AReq = nil) or (AReq.Body = nil) or (AReq.ContentLength = 0) then
    Exit;
  if ABodyStream = nil then
    raise EHttpError.CreateOp(hekProtocol, 'transport',
      'pooled retry request body is not replayable');
  ABodyStream.Position := AStartPosition;
end;

function ClientRequestDeadline(const ATimeoutMs: Int64): TDeadline;
begin
  if ATimeoutMs > 0 then
    Result := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs))
  else
    Result := TDeadline.Infinite;
end;

procedure ApplyClientDeadline(const AConn: ITcpStream;
  const ADeadline: TDeadline);
begin
  if ADeadline.IsInfinite then
    Exit;
  AConn.SetReadDeadline(ADeadline);
  AConn.SetWriteDeadline(ADeadline);
end;

procedure ApplyClientCancelToken(const AConn: ITcpStream;
  const AToken: IHttpCancelToken);
begin
  ApplyHttpCancelToken(AConn, AToken);
end;

function H1ClientDial(const AHost: string; const APort: UInt16;
  const AConnectTimeoutMs, ATimeoutMs: Int64): ITcpStream;
var
  LDialMs: Int64;
begin
  if AConnectTimeoutMs > 0 then
    LDialMs := AConnectTimeoutMs
  else
    LDialMs := ATimeoutMs;
  if LDialMs > 0 then
    Result := TcpConnect(AHost, APort, LDialMs)
  else
    Result := TcpConnect(AHost, APort);
end;


{ TH1ClientTransport }

constructor TH1ClientTransport.Create(const AOptions: TH1ClientTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
  if FOptions.MaxPoolSize <= 0 then
    FOptions.MaxPoolSize := 64;
  FPool := TH1IdleConnectionPool.Create(FOptions.MaxPoolSize, FOptions.IdleTTL);
  FDefaultTLSContext := nil;
end;

destructor TH1ClientTransport.Destroy;
begin
  FPool.Free;
  FPool := nil;
  FDefaultTLSContext := nil;
  inherited Destroy;
end;

function TH1ClientTransport.SecureClientContext: ISSLContext;
begin
  if FOptions.TLSContext <> nil then
    Exit(FOptions.TLSContext);
  if FDefaultTLSContext = nil then
    FDefaultTLSContext := TSSLQuick.SecureClient;
  Result := FDefaultTLSContext;
end;

procedure TH1ClientTransport.EstablishHttpsConnectTunnel(var AConn: ITcpStream;
  const ATargetHost: string; const ATargetPort: UInt16;
  const AProxyAuthorization: string);
const
  CRLF: AnsiString = #13#10;
var
  LAuthority: string;
  LRequest: string;
  LResp: IHttpResponse;
  LKeepAlive: Boolean;
  LResponseStarted: Boolean;
  LBody: IReader;
  LTmp: array[0..255] of Byte;
  LN: SizeUInt;
  LTunnelPending: string;
begin
  if AConn = nil then
    raise EHttpError.Create(hekArgument, 'proxy CONNECT requires connection');
  if ATargetHost = '' then
    raise EHttpError.Create(hekArgument, 'proxy CONNECT target host is empty');

  LAuthority := ConnectAuthority(ATargetHost, ATargetPort);
  ValidateWireRequestTarget(LAuthority);
  ValidateWireHeaderValue(LAuthority);
  if AProxyAuthorization <> '' then
    ValidateWireHeaderValue(AProxyAuthorization);

  LRequest := 'CONNECT ' + LAuthority + ' HTTP/1.1' + CRLF +
    'Host: ' + LAuthority + CRLF +
    'Proxy-Connection: keep-alive' + CRLF;
  if AProxyAuthorization <> '' then
    LRequest := LRequest +
      'Proxy-Authorization: ' + AProxyAuthorization + CRLF;
  LRequest := LRequest + CRLF;
  AConn.Write(LRequest[1], SizeUInt(Length(LRequest)));

  { CONNECT responses have no payload; any leftover bytes belong to the tunnel. }
  LTunnelPending := '';
  LResp := ReadResponse(AConn as IReader, hmHead, LKeepAlive, LResponseStarted,
    LTunnelPending);
  if (LResp.StatusCode < 200) or (LResp.StatusCode > 299) then
  begin
    { 407 is not auto-retried with Digest/NTLM. Supported path is preemptive
      Basic from ProxyUrl UserInfo only (Wave I freeze). }
    if LResp.StatusCode = HTTP_STATUS_PROXY_AUTH_REQUIRED then
      raise EHttpError.CreateOp(hekConnect, 'connect',
        'proxy CONNECT failed: HTTP 407 Proxy Authentication Required ' +
        '(supported: ProxyUrl UserInfo → Proxy-Authorization Basic only)')
    else
      raise EHttpError.CreateOp(hekConnect, 'connect',
        'proxy CONNECT failed: HTTP ' + IntToStr(Int64(LResp.StatusCode)));
  end;

  LBody := LResp.Body;
  if LBody <> nil then
  begin
    repeat
      LN := LBody.Read(LTmp[0], SizeUInt(SizeOf(LTmp)));
    until LN = 0;
  end;

  if LTunnelPending <> '' then
    AConn := TReadPrependTcpStream.Create(AConn, LTunnelPending);
end;

function TH1ClientTransport.WriteRequest(const AWriter: IWriter;
  const AReq: IHttpRequest; const AAutoHost: string;
  const AAbsoluteForm: Boolean; const AProxyAuthorization: string): Boolean;
const
  CRLF: AnsiString = #13#10;
var
  LPath: string;
  LUrl: TUrl;
  LBuf: IWriter;
  LChunked: IWriter;
  LChunkedFlusher: IFlusher;
  LFlusher: IFlusher;
  LN: SizeUInt;
  LRemaining: Int64;
  LReadSize: SizeUInt;
  LTmp: array[0..4095] of Byte;
  LStr: string;
  LUseChunked: Boolean;
begin
  Result := True;
  if not (AReq.Version in [hvHttp10, hvHttp11]) then
    raise EHttpError.CreateOp(hekProtocol, 'transport',
      'h1 transport only supports HTTP/1.x requests');

  LUrl := AReq.Url;
  if AAbsoluteForm then
  begin
    { Proxy absolute-form request-target: scheme://host[:port]/path[?query] }
    LPath := LUrl.ToString;
    if LUrl.Fragment <> '' then
    begin
      { Fragment is never sent on the wire. }
      if Pos('#', LPath) > 0 then
        LPath := System.Copy(LPath, 1, Pos('#', LPath) - 1);
    end;
  end
  else
  begin
    LPath := AReq.Path;
    if LPath = '' then
      LPath := '/';
    if AReq.RawQuery <> '' then
      LPath := LPath + '?' + AReq.RawQuery;
  end;
  ValidateWireRequestTarget(LPath);

  LBuf := CreateBufferedWriter(AWriter, 4096);

  LStr := HttpMethodToStr(AReq.Method);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(PAnsiChar(' ')^, 1);
  LBuf.Write(LPath[1], SizeUInt(Length(LPath)));

  LStr := ' ' + HttpVersionToStr(AReq.Version);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(CRLF[1], 2);

  AReq.Headers.ForEach(procedure(const AName, AValue: string)
  var
    LHeader: string;
  begin
    ValidateWireHeaderName(AName);
    ValidateWireHeaderValue(AValue);
    LHeader := AName + ': ' + AValue;
    LBuf.Write(LHeader[1], SizeUInt(Length(LHeader)));
    LBuf.Write(CRLF[1], 2);
  end);

  LUseChunked := (AReq.Body <> nil) and (AReq.ContentLength < 0);

  if (AReq.ContentLength > 0) and (not AReq.Headers.Has('content-length')) then
  begin
    LStr := 'content-length: ' + IntToStr(AReq.ContentLength);
    LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
    LBuf.Write(CRLF[1], 2);
  end;

  if LUseChunked and (not AReq.Headers.Has('transfer-encoding')) then
  begin
    LStr := 'transfer-encoding: chunked';
    LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
    LBuf.Write(CRLF[1], 2);
  end;

  if (AAutoHost <> '') and (not AReq.Headers.Has('host')) then
  begin
    LStr := 'host: ' + AAutoHost;
    LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
    LBuf.Write(CRLF[1], 2);
  end;

  if not AReq.Headers.Has('user-agent') then
  begin
    LStr := 'user-agent: nextpas-http/1.0';
    LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
    LBuf.Write(CRLF[1], 2);
  end;

  { Absolute-form proxy only: inject Basic from ProxyUrl UserInfo when the
    request did not already set Proxy-Authorization. }
  if AAbsoluteForm and (AProxyAuthorization <> '') and
     (not AReq.Headers.Has('proxy-authorization')) then
  begin
    ValidateWireHeaderValue(AProxyAuthorization);
    LStr := 'proxy-authorization: ' + AProxyAuthorization;
    LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
    LBuf.Write(CRLF[1], 2);
  end;

  LBuf.Write(CRLF[1], 2);

  if (AReq.Body <> nil) and (AReq.ContentLength > 0) then
  begin
    LRemaining := AReq.ContentLength;
    while LRemaining > 0 do
    begin
      LReadSize := SizeUInt(SizeOf(LTmp));
      if LRemaining < Int64(LReadSize) then
        LReadSize := SizeUInt(LRemaining);
      try
        LN := AReq.Body.Read(LTmp[0], LReadSize);
      except
        on E: Exception do
        begin
          if E is ETimeoutError then
            raise EHttpError.CreateOp(hekTimeout, 'transport',
              'HTTP request body read failed: ' + E.Message);
          if E is EHttpError then
            raise;
          raise EHttpError.CreateOp(hekProtocol, 'transport',
            'HTTP request body read failed: ' + E.Message);
        end;
      end;
      if LN > 0 then
      begin
        if Int64(LN) > LRemaining then
          LN := SizeUInt(LRemaining);
        LBuf.Write(LTmp[0], LN);
        Dec(LRemaining, Int64(LN));
      end;
      if LN = 0 then
      begin
        if Supports(LBuf, IFlusher, LFlusher) then
          LFlusher.Flush;
        raise EHttpError.CreateOp(hekBody, 'transport',
          'HTTP request body shorter than declared content-length');
      end;
    end;
  end
  else if LUseChunked then
  begin
    LChunked := TChunkedWriter.Create(LBuf);
    while True do
    begin
      try
        LN := AReq.Body.Read(LTmp[0], SizeUInt(SizeOf(LTmp)));
      except
        on E: Exception do
        begin
          if E is ETimeoutError then
            raise EHttpError.CreateOp(hekTimeout, 'transport',
              'HTTP request body read failed: ' + E.Message);
          if E is EHttpError then
            raise;
          raise EHttpError.CreateOp(hekProtocol, 'transport',
            'HTTP request body read failed: ' + E.Message);
        end;
      end;
      if LN = 0 then
        Break;
      LChunked.Write(LTmp[0], LN);
    end;
    if Supports(LChunked, IFlusher, LChunkedFlusher) then
      LChunkedFlusher.Flush;
  end;

  if Supports(LBuf, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

function TH1ClientTransport.ReadResponse(const AReader: IReader;
  const ARequestMethod: THttpMethod; out AKeepAlive: Boolean;
  out AResponseStarted: Boolean; var APending: string;
  const AOnBodyChunk: THttpResponseBodyChunkProc = nil;
  const AOnResponseStatus: THttpResponseStatusProc = nil;
  const ASkipBodyBuffer: Boolean = False): IHttpResponse;
var
  LParser: IH1Parser;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LConsumed: SizeUInt;
  LPending: string;
  LHasResponseTail: Boolean;
  LBodyReader: IReader;
  LSkippedInformational: Boolean;
  LCurrentResponseStarted: Boolean;
  LHeadersNotified: Boolean;
begin
  AResponseStarted := False;
  LHasResponseTail := False;
  LSkippedInformational := False;
  LCurrentResponseStarted := False;
  LHeadersNotified := False;
  LPending := APending;
  APending := '';
  LParser := NewH1ResponseParser(ARequestMethod = hmHead, ASkipBodyBuffer);
  if Assigned(AOnBodyChunk) then
    LParser.SetOnBodyChunk(AOnBodyChunk);
  if Assigned(AOnResponseStatus) then
    LParser.SetPauseAtHeaders(True);
  repeat
    if LPending <> '' then
    begin
      LN := SizeUInt(Length(LPending));
      LCurrentResponseStarted := True;
      LConsumed := LParser.Execute(PAnsiChar(LPending), LN);
      if LConsumed < LN then
        LPending := System.Copy(LPending, SizeInt(LConsumed) + 1,
          SizeInt(LN - LConsumed))
      else
        LPending := '';
    end
    else
    begin
      LN := AReader.Read(LBuf[0], 4096);
      if LN = 0 then
        Break;
      AResponseStarted := True;
      LCurrentResponseStarted := True;
      LConsumed := LParser.Execute(@LBuf[0], LN);
      if LConsumed < LN then
      begin
        SetLength(LPending, Int32(LN - LConsumed));
        Move(LBuf[Int32(LConsumed)], LPending[1], LN - LConsumed);
      end;
    end;

    { Response-headers-ready notification: fires once per final response,
      before any body chunk is dispatched. Informational (1xx) responses are
      skipped so the callback reports the status that decides the response
      body semantics. Runs in Pascal context (may raise). }
    if (not LHeadersNotified) and LParser.HeadersComplete and
       (not IsSkippableInformationalResponse(LParser.GetStatusCode)) then
    begin
      LHeadersNotified := True;
      if Assigned(AOnResponseStatus) then
        AOnResponseStatus(LParser.GetStatusCode);
    end;

    if LParser.IsComplete and
      IsSkippableInformationalResponse(LParser.GetStatusCode) then
    begin
      LSkippedInformational := True;
      LCurrentResponseStarted := False;
      LHeadersNotified := False;
      LParser := NewH1ResponseParser(ARequestMethod = hmHead, ASkipBodyBuffer);
      if Assigned(AOnBodyChunk) then
        LParser.SetOnBodyChunk(AOnBodyChunk);
      if Assigned(AOnResponseStatus) then
        LParser.SetPauseAtHeaders(True);
      Continue;
    end;
  until LParser.IsComplete or LParser.HasError;

  if (not LParser.IsComplete) and (not LParser.HasError) then
    LParser.Finish;

  if LParser.IsComplete and
    IsSkippableInformationalResponse(LParser.GetStatusCode) then
    raise EHttpError.CreateOp(hekProtocol, 'transport',
      'HTTP response incomplete: missing final response');

  if LSkippedInformational and (not LCurrentResponseStarted) then
    raise EHttpError.CreateOp(hekProtocol, 'transport',
      'HTTP response incomplete: missing final response');

  if LParser.HasError then
    raise EHttpError.CreateOp(hekParse, 'transport',
      'HTTP parse error: ' + LParser.ErrorMessage);
  if not LParser.IsComplete then
    raise EHttpError.CreateOp(hekConnect, 'transport',
      'HTTP response incomplete: connection closed');

  APending := LPending;
  LHasResponseTail := APending <> '';
  AKeepAlive := LParser.ShouldKeepAlive and (not LHasResponseTail) and
    (LParser.GetStatusCode <> HTTP_STATUS_SWITCHING_PROTOCOLS);

  LBodyReader := LParser.NewBodyReader;
  { F8（pascn backfeed）：无体响应（204/304/HEAD/Content-Length:0）的 Body
    语义是「空」而非「无」——补空读取器，IHttpResponse.Body 恒非 nil，
    消费方 ReadAll(Body) 无需 nil 防御。流式 sink 模式（ASkipBodyBuffer）
    体已分派、Body=nil 契约不变；错误/未完成路径交上层异常处理，不补。 }
  if (LBodyReader = nil) and (not ASkipBodyBuffer) and
     LParser.IsComplete and (not LParser.HasError) and (LParser.GetBodySize = 0) then
    LBodyReader := CreateBytesStreamFrom(nil) as IReader;
  if LBodyReader <> nil then
  begin
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders,
      LBodyReader, LParser.GetHttpVersion);
  end
  else
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders, nil,
      LParser.GetHttpVersion);
end;

function TH1ClientTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LUrl: TUrl;
  LHost: string;
  LPoolHostKey: string;
  LAutoHost: string;
  LPort: UInt16;
  LConnectHost: string;
  LConnectPort: UInt16;
  LProxyUrl: TUrl;
  LProxyAuthorization: string;
  LUseAbsoluteForm: Boolean;
  LUseConnectTunnel: Boolean;
  LSecure: Boolean;
  LConn: ITcpStream;
  LResp: IHttpResponse;
  LPooled: Boolean;
  LKeepAlive: Boolean;
  LRequestClose: Boolean;
  LResponseStarted: Boolean;
  LRequestWriteComplete: Boolean;
  LBodyStream: IStream;
  LBodyStartPosition: Int64;
  LRequestDeadline: TDeadline;
  LTimeoutMs: Int64;
  LReqOpts: IHttpRequestWithOptions;
  LWrapped: Exception;
  LPendingTail: string;
  LBodyChunkProc: THttpResponseBodyChunkProc;
  LResponseStatusProc: THttpResponseStatusProc;
  LSkipBodyBuffer: Boolean;

  procedure WrapConnectionWithTls;
  begin
    { Bound TLS handshake I/O with ConnectTimeout when set. }
    if FOptions.ConnectTimeout > 0 then
      ApplyClientDeadline(LConn, ClientRequestDeadline(FOptions.ConnectTimeout))
    else
      ApplyClientDeadline(LConn, LRequestDeadline);
    LConn := NewTlsClientTcpStream(LConn, SecureClientContext, LHost,
      'http/1.1');
    if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
      ApplyClientCancelToken(LConn,
        LReqOpts.RequestOptions.EffectiveCancelToken)
    else
      ApplyClientCancelToken(LConn, nil);
  end;

  procedure PrepareFreshConnection;
  begin
    { ConnectTimeout (or Timeout when ConnectTimeout=0) bounds OS dial.
      Custom dial func (SOCKS5 tunnels etc.) replaces the built-in TcpConnect;
      it receives the same deadline budget and must raise on failure. WithProxyUrl
      strictly takes precedence: a proxied request always dials the proxy host. }
    if (FOptions.ProxyUrl = '') and Assigned(FOptions.DialFunc) then
      LConn := FOptions.DialFunc(LConnectHost, LConnectPort,
        FOptions.ConnectTimeout, LTimeoutMs)
    else
      LConn := H1ClientDial(LConnectHost, LConnectPort, FOptions.ConnectTimeout,
        LTimeoutMs);
    { New dial: ConnectTimeout also bounds post-dial first write / CONNECT. }
    if FOptions.ConnectTimeout > 0 then
      ApplyClientDeadline(LConn, ClientRequestDeadline(FOptions.ConnectTimeout))
    else
      ApplyClientDeadline(LConn, LRequestDeadline);
    if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
      ApplyClientCancelToken(LConn, LReqOpts.RequestOptions.EffectiveCancelToken)
    else
      ApplyClientCancelToken(LConn, nil);

    if LUseConnectTunnel then
    begin
      EstablishHttpsConnectTunnel(LConn, LHost, LPort, LProxyAuthorization);
      WrapConnectionWithTls;
    end
    else if LSecure then
      { Direct https: TLS-wrap the origin socket (SNI = origin host). }
      WrapConnectionWithTls;
  end;

begin
  if AReq = nil then
    raise EHttpError.Create(hekArgument, 'h1 client transport requires request');
  if AReq.Headers = nil then
    raise EHttpError.Create(hekArgument, 'h1 client transport requires request headers');

  // Per-request timeout override: check request options first, fall back to transport default
  LTimeoutMs := FOptions.Timeout;
  if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
  begin
    LTimeoutMs := LReqOpts.RequestOptions.EffectiveTimeout(FOptions.Timeout);
    HttpThrowIfCanceled(LReqOpts.RequestOptions.EffectiveCancelToken);
  end;

  LUrl := AReq.Url;
  ValidatePlainHttpClientUrlScheme(LUrl);
  LHost := LUrl.Host;
  LSecure := LowerCase(LUrl.Scheme) = 'https';
  LAutoHost := '';
  if not AReq.Headers.Has('host') then
  begin
    LAutoHost := LUrl.HostPort;
    ValidateWireHeaderValue(LAutoHost);
  end;
  LRequestClose := HeadersHaveConnectionCloseToken(AReq.Headers);
  LPort := LUrl.Port;
  if LPort = 0 then
    LPort := DefaultPortForHttpScheme(LUrl.Scheme);

  LUseAbsoluteForm := False;
  LUseConnectTunnel := False;
  LProxyAuthorization := '';
  LConnectHost := LHost;
  LConnectPort := LPort;
  LPoolHostKey := CanonicalPoolHostKey(LHost);
  if LSecure then
    { Keep plain and TLS idle sockets in separate pools. }
    LPoolHostKey := 'https|' + LPoolHostKey;
  if FOptions.ProxyUrl <> '' then
  begin
    LProxyUrl := TUrl.Parse(FOptions.ProxyUrl);
    if LowerCase(LProxyUrl.Scheme) <> 'http' then
      raise EHttpError.Create(hekArgument,
        'HTTP client proxy must use http:// scheme');
    if LProxyUrl.Host = '' then
      raise EHttpError.Create(hekArgument, 'HTTP client proxy host is empty');
    LProxyAuthorization := ProxyBasicAuthorizationValue(LProxyUrl.UserInfo);
    LConnectHost := LProxyUrl.Host;
    LConnectPort := LProxyUrl.Port;
    if LConnectPort = 0 then
      LConnectPort := 80;
    if LSecure then
    begin
      { https through plain HTTP proxy: CONNECT host:port, then TLS. }
      LUseConnectTunnel := True;
      LUseAbsoluteForm := False;
      LPoolHostKey := 'connect|' + CanonicalPoolHostKey(LConnectHost) + '|' +
        CanonicalPoolHostKey(LHost) + ':' + IntToStr(Int64(LPort));
    end
    else
    begin
      LUseAbsoluteForm := True;
      { Pool by proxy + target so different targets do not share a proxy socket. }
      LPoolHostKey := CanonicalPoolHostKey(LConnectHost) + '|' +
        CanonicalPoolHostKey(LHost) + ':' + IntToStr(Int64(LPort));
    end;
  end;

  CaptureRetryBodyPosition(AReq, LBodyStream, LBodyStartPosition);
  LRequestDeadline := ClientRequestDeadline(LTimeoutMs);
  LPendingTail := '';
  if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
    HttpThrowIfCanceled(LReqOpts.RequestOptions.EffectiveCancelToken);
  LConn := FPool.Get(LPoolHostKey, LConnectPort);
  LPooled := LConn <> nil;
  if not LPooled then
  begin
    { 拨号阶段（DNS/connect/TLS/CONNECT 隧道）与写读阶段同一传输异常契约：
      ENetworkError/ETimeoutError 经 HttpWrapTransportException 包装为
      EHttpError，裸网络异常不穿透 RoundTrip。 }
    try
      PrepareFreshConnection;
    except
      on E: Exception do
      begin
        LWrapped := HttpWrapTransportException(E);
        if LWrapped <> nil then
          raise LWrapped;
        raise;
      end;
    end;
  end
  else
  begin
    ApplyClientDeadline(LConn, LRequestDeadline);
    if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
      ApplyClientCancelToken(LConn, LReqOpts.RequestOptions.EffectiveCancelToken)
    else
      ApplyClientCancelToken(LConn, nil);
  end;

  LResponseStarted := False;
  LRequestWriteComplete := False;
  try
    WriteRequest(LConn as IWriter, AReq, LAutoHost, LUseAbsoluteForm,
      LProxyAuthorization);
    LRequestWriteComplete := True;
    if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
      HttpThrowIfCanceled(LReqOpts.RequestOptions.EffectiveCancelToken);
    { Re-arm request deadline for response read (after connect-write budget). }
    ApplyClientDeadline(LConn, LRequestDeadline);
    LBodyChunkProc := nil;
    LResponseStatusProc := nil;
    LSkipBodyBuffer := False;
    if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
    begin
      LBodyChunkProc := LReqOpts.RequestOptions.ResponseBodyChunk;
      LResponseStatusProc := LReqOpts.RequestOptions.ResponseStatus;
      LSkipBodyBuffer := LReqOpts.RequestOptions.SkipBodyBuffer;
    end;
    LResp := ReadResponse(LConn as IReader, AReq.Method, LKeepAlive,
      LResponseStarted, LPendingTail, LBodyChunkProc, LResponseStatusProc,
      LSkipBodyBuffer);
  except
    on E: Exception do
    begin
      if LPooled then
      begin
        LConn.Close;
        if (not LRequestWriteComplete) or LResponseStarted or
           (not IsRetrySafeRequest(AReq)) or
           ((AReq.Body <> nil) and (AReq.ContentLength <> 0) and
            (LBodyStream = nil)) then
        begin
          LWrapped := HttpWrapTransportException(E);
          if LWrapped <> nil then
            raise LWrapped;
          raise;
        end;
        RewindRetryBody(AReq, LBodyStream, LBodyStartPosition);
        if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
          HttpThrowIfCanceled(LReqOpts.RequestOptions.EffectiveCancelToken);
        try
          PrepareFreshConnection;
          LRequestWriteComplete := False;
          WriteRequest(LConn as IWriter, AReq, LAutoHost, LUseAbsoluteForm,
            LProxyAuthorization);
          LRequestWriteComplete := True;
          if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
            HttpThrowIfCanceled(LReqOpts.RequestOptions.EffectiveCancelToken);
          ApplyClientDeadline(LConn, LRequestDeadline);
          LResp := ReadResponse(LConn as IReader, AReq.Method, LKeepAlive,
            LResponseStarted, LPendingTail, LBodyChunkProc,
            LResponseStatusProc, LSkipBodyBuffer);
        except
          on E2: Exception do
          begin
            LConn.Close;
            LWrapped := HttpWrapTransportException(E2);
            if LWrapped <> nil then
              raise LWrapped;
            raise;
          end;
        end;
      end
      else
      begin
        LConn.Close;
        LWrapped := HttpWrapTransportException(E);
        if LWrapped <> nil then
          raise LWrapped;
        raise;
      end;
    end;
  end;

  if LKeepAlive and (not LRequestClose) then
    FPool.Put(LPoolHostKey, LConnectPort, LConn)
  else
    LConn.Close;

  Result := LResp;
end;

procedure TH1ClientTransport.CloseIdleConnections;
begin
  FPool.Clear;
end;



function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
begin
  Result := TH1ClientTransport.Create(AOptions);
end;

end.
