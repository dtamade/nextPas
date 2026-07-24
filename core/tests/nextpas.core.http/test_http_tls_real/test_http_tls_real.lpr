program test_http_tls_real;

{**
 * @desc Real TLS runtime proof test (low-level + HTTP TLS stream wrapper).
 *       Self-signed cert, concurrent TLS handshake via platform threads
 *       (no Classes.TThread — dual-compiler hygiene).
 *
 * Full H2+TLS facade e2e: test_http_h2_tls_alpn (H2P-3).
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.openssl.backed,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h2.client,
  nextpas.core.http.impl.h2.types,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.tls.http2.alpn,
  nextpas.core.platform.thread;

type
  PHandshakeCtx = ^THandshakeCtx;
  THandshakeCtx = record
    TlsServer: ISSLConnection;
    AcceptResult: Boolean;
  end;

  PStreamAcceptCtx = ^TStreamAcceptCtx;
  TStreamAcceptCtx = record
    Conn: ITcpStream;
    Ctx: ISSLContext;
    ResultStream: ITcpStream;
    Error: string;
  end;

var
  T: TTestSuite;

function HandshakeServerThread(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PHandshakeCtx;
begin
  Result := nil;
  LCtx := PHandshakeCtx(AArg);
  try
    LCtx^.AcceptResult := LCtx^.TlsServer.Accept;
  except
    LCtx^.AcceptResult := False;
  end;
end;

function StreamServerThread(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PStreamAcceptCtx;
begin
  Result := nil;
  LCtx := PStreamAcceptCtx(AArg);
  try
    LCtx^.ResultStream := NewTlsServerTcpStream(LCtx^.Conn, LCtx^.Ctx);
    LCtx^.Error := '';
  except
    on E: Exception do
    begin
      LCtx^.ResultStream := nil;
      LCtx^.Error := E.Message;
    end;
  end;
end;

procedure TestSelfSignedCertCreation;
var
  LKeyPair: IKeyPairWithCertificate;
  LCertPEM, LKeyPEM: string;
begin
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('localhost')
    .WithOrganization('Test Org')
    .SelfSigned;
  Check(LKeyPair <> nil, 'self-signed cert created');
  Check(LKeyPair.Certificate <> nil, 'certificate exists');
  Check(LKeyPair.PrivateKey <> nil, 'private key exists');
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);
  Check(LCertPEM <> '', 'cert PEM not empty');
  Check(LKeyPEM <> '', 'key PEM not empty');
  Check(Pos('BEGIN CERTIFICATE', LCertPEM) > 0, 'cert PEM has correct header');
  Check(Pos('BEGIN PRIVATE KEY', LKeyPEM) > 0, 'key PEM has correct header');
  Check(Pos('localhost', LKeyPair.Certificate.GetSubject) > 0,
    'certificate subject contains localhost');
end;

procedure TestTlsContextCreation;
var
  LKeyPair: IKeyPairWithCertificate;
  LCertPEM, LKeyPEM: string;
  LServerCtx: ISSLContext;
  LClientCtx: ISSLContext;
begin
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('localhost')
    .WithOrganization('Test Org')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);

  LServerCtx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithVerifyNone
    .BuildServer;
  Check(LServerCtx <> nil, 'server TLS context created');
  Check(LServerCtx.IsValid, 'server TLS context is valid');

  LClientCtx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyNone
    .BuildClient;
  Check(LClientCtx <> nil, 'client TLS context created');
  Check(LClientCtx.IsValid, 'client TLS context is valid');
end;

procedure TestTlsHandshakeWithLocalServer;
var
  LKeyPair: IKeyPairWithCertificate;
  LCertPEM, LKeyPEM: string;
  LServerCtx, LClientCtx: ISSLContext;
  LListener: ITcpListener;
  LClientConn, LServerConn: ITcpStream;
  LTlsClient, LTlsServer: ISSLConnection;
  LAddr: TNetAddress;
  LPort: UInt16;
  LBuf: array[0..255] of Byte;
  LRead: SizeUInt;
  LTestData: AnsiString;
  LSock: PtrUInt;
  LRuntime: ITcpSocketRuntime;
  LHs: PHandshakeCtx;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
begin
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('localhost')
    .WithOrganization('Test Org')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);

  LServerCtx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithVerifyNone
    .BuildServer;
  LClientCtx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyNone
    .BuildClient;

  LListener := NetTcpListen('127.0.0.1', 0);
  Check(LListener <> nil, 'TCP listener created');
  LAddr := LListener.LocalAddr;
  LPort := LAddr.Port;
  Check(LPort > 0, 'listener has valid port');

  LClientConn := TcpConnect('127.0.0.1', LPort);
  Check(LClientConn <> nil, 'client TCP connected');

  LServerConn := LListener.Accept;
  Check(LServerConn <> nil, 'server accepted connection');

  Check(Supports(LClientConn, ITcpSocketRuntime, LRuntime),
    'client supports ITcpSocketRuntime');
  LSock := LRuntime.NativeSocketHandle;
  LTlsClient := LClientCtx.CreateConnection(THandle(LSock));
  Check(LTlsClient <> nil, 'client TLS connection created');
  LRuntime := nil;

  Check(Supports(LServerConn, ITcpSocketRuntime, LRuntime),
    'server supports ITcpSocketRuntime');
  LSock := LRuntime.NativeSocketHandle;
  LTlsServer := LServerCtx.CreateConnection(THandle(LSock));
  Check(LTlsServer <> nil, 'server TLS connection created');
  LRuntime := nil;

  { Concurrent handshake: Accept on worker, Connect on main. }
  New(LHs);
  LHs^.TlsServer := LTlsServer;
  LHs^.AcceptResult := False;
  platform_thread_create(LHandle, @HandshakeServerThread, LHs);
  try
    Check(LTlsClient.Connect, 'client TLS connect succeeded');
  finally
    platform_thread_join(LHandle, LRet);
  end;
  Check(LHs^.AcceptResult, 'server TLS accept succeeded');
  Dispose(LHs);

  Check(LTlsServer.GetState <> '', 'server TLS state not empty');
  Check(LTlsClient.GetState <> '', 'client TLS state not empty');

  LTestData := 'Hello TLS!';
  LTlsClient.Write(LTestData[1], Length(LTestData));

  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := LTlsServer.Read(LBuf[0], SizeOf(LBuf));
  Check(LRead = SizeUInt(Length(LTestData)), 'server received correct data length');
  Check(CompareMem(@LBuf[0], @LTestData[1], LRead), 'server received correct data');

  LTestData := 'TLS OK!';
  LTlsServer.Write(LTestData[1], Length(LTestData));

  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := LTlsClient.Read(LBuf[0], SizeOf(LBuf));
  Check(LRead = SizeUInt(Length(LTestData)), 'client received correct data length');
  Check(CompareMem(@LBuf[0], @LTestData[1], LRead), 'client received correct data');

  LTlsClient := nil;
  LTlsServer := nil;
  LClientConn := nil;
  LServerConn := nil;
  LListener := nil;
end;

procedure TestTlsStreamWrapper;
var
  LKeyPair: IKeyPairWithCertificate;
  LCertPEM, LKeyPEM: string;
  LServerCtx, LClientCtx: ISSLContext;
  LListener: ITcpListener;
  LClientConn, LServerConn: ITcpStream;
  LClientStream, LServerStream: ITcpStream;
  LAddr: TNetAddress;
  LPort: UInt16;
  LBuf: array[0..255] of Byte;
  LRead: SizeUInt;
  LTestData: AnsiString;
  LSx: PStreamAcceptCtx;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
begin
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('localhost')
    .WithOrganization('Test Org')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);

  LServerCtx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithVerifyNone
    .BuildServer;
  LClientCtx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyNone
    .BuildClient;

  LListener := NetTcpListen('127.0.0.1', 0);
  Check(LListener <> nil, 'TCP listener created');
  LAddr := LListener.LocalAddr;
  LPort := LAddr.Port;

  LClientConn := TcpConnect('127.0.0.1', LPort);
  LServerConn := LListener.Accept;

  New(LSx);
  LSx^.Conn := LServerConn;
  LSx^.Ctx := LServerCtx;
  LSx^.ResultStream := nil;
  LSx^.Error := '';
  platform_thread_create(LHandle, @StreamServerThread, LSx);
  try
    LClientStream := NewTlsClientTcpStream(LClientConn, LClientCtx, 'localhost',
      HTTP2_ALPN_PROTOCOL);
    Check(LClientStream <> nil, 'client TLS stream created');
  finally
    platform_thread_join(LHandle, LRet);
  end;
  Check(LSx^.Error = '', 'server TLS stream: ' + LSx^.Error);
  LServerStream := LSx^.ResultStream;
  Check(LServerStream <> nil, 'server TLS stream created');
  Dispose(LSx);

  LTestData := 'TLS Stream Test!';
  LClientStream.Write(LTestData[1], Length(LTestData));

  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := LServerStream.Read(LBuf[0], SizeOf(LBuf));
  Check(LRead = SizeUInt(Length(LTestData)), 'TLS stream data received');
  Check(CompareMem(@LBuf[0], @LTestData[1], LRead), 'TLS stream data matches');

  LClientStream := nil;
  LServerStream := nil;
  LClientConn := nil;
  LServerConn := nil;
  LListener := nil;
end;

procedure TestH2TransportOverRealTls;
var
  LKeyPair: IKeyPairWithCertificate;
  LCertPEM, LKeyPEM: string;
  LServerCtx, LClientCtx: ISSLContext;
  LTransport: IHttpTransport;
  LOptions: TH2ClientTransportOptions;
begin
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('localhost')
    .WithOrganization('Test Org')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);

  LServerCtx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithVerifyNone
    .BuildServer;
  LClientCtx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyNone
    .BuildClient;

  LOptions := TH2ClientTransportOptions.Default;
  LOptions.TLSContext := LClientCtx;
  LTransport := NewH2ClientTransport(LOptions);
  Check(LTransport <> nil, 'H2 transport created');
  Check(LClientCtx.IsValid, 'client TLS context is valid');
  Check(LServerCtx.IsValid, 'server TLS context is valid');
  { Full H2+TLS request path: test_http_h2_tls_alpn. }
  LTransport := nil;
end;

begin
  T := TTestSuite.Create('test_http_tls_real');
  T.Test('Self-signed certificate creation', @TestSelfSignedCertCreation);
  T.Test('TLS context creation', @TestTlsContextCreation);
  T.Test('TLS handshake with local server', @TestTlsHandshakeWithLocalServer);
  T.Test('TLS stream wrapper', @TestTlsStreamWrapper);
  T.Test('H2 transport over real TLS', @TestH2TransportOverRealTls);
  if not T.Run then
    Halt(1);
end.
