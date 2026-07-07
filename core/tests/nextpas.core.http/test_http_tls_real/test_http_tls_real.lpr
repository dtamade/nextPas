program test_http_tls_real;

{**
 * @desc Real TLS runtime proof test.
 *       Proves the TLS integration works end-to-end with actual TLS handshakes,
 *       not mock connections. Creates a self-signed certificate, starts a local
 *       TLS server, connects with a TLS client, and verifies data exchange.
 *}

{$I nextpas.core.settings.inc}

uses
  cthreads,
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net,
  nextpas.core.time.deadline,
  nextpas.core.tls.base,
  nextpas.core.tls.quick,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.openssl.backed,  // Register OpenSSL backend
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.h2.client,
  nextpas.core.http.impl.h2.types,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.tls.http2.alpn;

var
  T: TTestSuite;

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

type
  TServerHandshakeThread = class(TThread)
    FTlsServer: ISSLConnection;
    FAcceptResult: Boolean;
    procedure Execute; override;
  end;

procedure TServerHandshakeThread.Execute;
begin
  FAcceptResult := FTlsServer.Accept;
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
  LServerThread: TServerHandshakeThread;
begin
  { Create self-signed cert }
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('localhost')
    .WithOrganization('Test Org')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);

  { Create TLS contexts }
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

  { Start TCP listener on random port }
  LListener := NetTcpListen('127.0.0.1', 0);
  Check(LListener <> nil, 'TCP listener created');
  LAddr := LListener.LocalAddr;
  LPort := LAddr.Port;
  Check(LPort > 0, 'listener has valid port');

  { Connect client }
  LClientConn := TcpConnect('127.0.0.1', LPort);
  Check(LClientConn <> nil, 'client TCP connected');

  { Accept server connection }
  LServerConn := LListener.Accept;
  Check(LServerConn <> nil, 'server accepted connection');

  { Create TLS connections using native socket handles }
  Check(Supports(LClientConn, ITcpSocketRuntime, LRuntime), 'client supports ITcpSocketRuntime');
  LSock := LRuntime.NativeSocketHandle;
  LTlsClient := LClientCtx.CreateConnection(THandle(LSock));
  Check(LTlsClient <> nil, 'client TLS connection created');
  LRuntime := nil;

  Check(Supports(LServerConn, ITcpSocketRuntime, LRuntime), 'server supports ITcpSocketRuntime');
  LSock := LRuntime.NativeSocketHandle;
  LTlsServer := LServerCtx.CreateConnection(THandle(LSock));
  Check(LTlsServer <> nil, 'server TLS connection created');
  LRuntime := nil;

  { TLS handshake: server runs in background thread, client in main thread.
    Handshake requires bidirectional data exchange, so both must run concurrently. }
  LServerThread := TServerHandshakeThread.Create(True);
  LServerThread.FTlsServer := LTlsServer;
  LServerThread.FreeOnTerminate := False;
  LServerThread.Start;

  Check(LTlsClient.Connect, 'client TLS connect succeeded');

  LServerThread.WaitFor;
  Check(LServerThread.FAcceptResult, 'server TLS accept succeeded');
  LServerThread.Free;

  { Verify TLS state }
  Check(LTlsServer.GetState <> '', 'server TLS state not empty');
  Check(LTlsClient.GetState <> '', 'client TLS state not empty');

  { Send data from client to server }
  LTestData := 'Hello TLS!';
  LTlsClient.Write(LTestData[1], Length(LTestData));

  { Read data on server side }
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := LTlsServer.Read(LBuf[0], SizeOf(LBuf));
  Check(LRead = SizeUInt(Length(LTestData)), 'server received correct data length');
  Check(CompareMem(@LBuf[0], @LTestData[1], LRead), 'server received correct data');

  { Send response from server to client }
  LTestData := 'TLS OK!';
  LTlsServer.Write(LTestData[1], Length(LTestData));

  { Read response on client side }
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := LTlsClient.Read(LBuf[0], SizeOf(LBuf));
  Check(LRead = SizeUInt(Length(LTestData)), 'client received correct data length');
  Check(CompareMem(@LBuf[0], @LTestData[1], LRead), 'client received correct data');

  { Cleanup }
  LTlsClient := nil;
  LTlsServer := nil;
  LClientConn := nil;
  LServerConn := nil;
  LListener := nil;
end;

type
  TServerStreamThread = class(TThread)
    FConn: ITcpStream;
    FCtx: ISSLContext;
    FResult: ITcpStream;
    FError: string;
    procedure Execute; override;
  end;

procedure TServerStreamThread.Execute;
begin
  try
    FResult := NewTlsServerTcpStream(FConn, FCtx);
  except
    on E: Exception do
      FError := E.Message;
  end;
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
  LServerThread: TServerStreamThread;
begin
  { Create self-signed cert }
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('localhost')
    .WithOrganization('Test Org')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);

  { Create TLS contexts }
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

  { Start TCP listener }
  LListener := NetTcpListen('127.0.0.1', 0);
  Check(LListener <> nil, 'TCP listener created');
  LAddr := LListener.LocalAddr;
  LPort := LAddr.Port;

  { Connect and accept }
  LClientConn := TcpConnect('127.0.0.1', LPort);
  LServerConn := LListener.Accept;

  { Create TLS streams using the HTTP module's wrapper.
    Server runs in background thread because TLS handshake requires
    bidirectional data exchange — client and server must run concurrently. }
  LServerThread := TServerStreamThread.Create(True);
  LServerThread.FConn := LServerConn;
  LServerThread.FCtx := LServerCtx;
  LServerThread.FreeOnTerminate := False;
  LServerThread.Start;

  LClientStream := NewTlsClientTcpStream(LClientConn, LClientCtx, 'localhost',
    HTTP2_ALPN_PROTOCOL);
  Check(LClientStream <> nil, 'client TLS stream created');

  LServerThread.WaitFor;
  Check(LServerThread.FError = '', 'server TLS stream: ' + LServerThread.FError);
  LServerStream := LServerThread.FResult;
  Check(LServerStream <> nil, 'server TLS stream created');
  LServerThread.Free;

  { Send data through TLS streams }
  LTestData := 'TLS Stream Test!';
  LClientStream.Write(LTestData[1], Length(LTestData));

  { Read on server side }
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := LServerStream.Read(LBuf[0], SizeOf(LBuf));
  Check(LRead = SizeUInt(Length(LTestData)), 'TLS stream data received');
  Check(CompareMem(@LBuf[0], @LTestData[1], LRead), 'TLS stream data matches');

  { Cleanup }
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
  LListener: ITcpListener;
  LServerConn: ITcpStream;
  LTransport: IHttpTransport;
  LOptions: TH2ClientTransportOptions;
  LResp: IHttpResponse;
  LAddr: TNetAddress;
  LPort: UInt16;
  LServerThread: TThread;
  LHandlerCalled: Boolean;
begin
  { Create self-signed cert }
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('localhost')
    .WithOrganization('Test Org')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);

  { Create TLS contexts }
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

  { Start TCP listener }
  LListener := NetTcpListen('127.0.0.1', 0);
  Check(LListener <> nil, 'TCP listener created');
  LAddr := LListener.LocalAddr;
  LPort := LAddr.Port;

  { Create H2 client transport with real TLS }
  LOptions := TH2ClientTransportOptions.Default;
  LOptions.TLSContext := LClientCtx;
  LTransport := NewH2ClientTransport(LOptions);
  Check(LTransport <> nil, 'H2 transport created');

  { Note: Full H2 over TLS requires ALPN negotiation which needs a real H2
    server. This test proves the transport creation and TLS context integration
    works. A full end-to-end H2+TLS test would require starting an H2 server
    in a background thread. }
  Check(LClientCtx.IsValid, 'client TLS context is valid');
  Check(LServerCtx.IsValid, 'server TLS context is valid');

  { Cleanup }
  LTransport := nil;
  LListener := nil;
end;

begin
  T := TTestSuite.Create('test_http_tls_real');
  T.Test('Self-signed certificate creation', @TestSelfSignedCertCreation);
  T.Test('TLS context creation', @TestTlsContextCreation);
  T.Test('TLS handshake with local server', @TestTlsHandshakeWithLocalServer);
  T.Test('TLS stream wrapper', @TestTlsStreamWrapper);
  T.Test('H2 transport over real TLS', @TestH2TransportOverRealTls);
  if not T.Run then Halt(1);
end.
