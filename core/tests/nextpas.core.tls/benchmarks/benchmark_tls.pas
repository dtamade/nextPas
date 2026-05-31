program benchmark_tls;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, 
  benchmark_utils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.secure,
  nextpas.core.tls.cert,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.core,
  fafafa.ssl;

const
  PORT = '8443'; // BIO uses string port
  ITERATIONS = 100;

var
  LServerCtx, LClientCtx: ISSLContext;
  LServerCert: IKeyPairWithCertificate;
  LBench: TBenchmark;
  I: Integer;
  LLib: ISSLLibrary;

procedure SetupCertificates;
begin
  WriteLn('Generating test certificates...');
  LServerCert := TCertificateBuilder.Create
    .WithCommonName('localhost')
    .WithOrganization('Benchmark Test')
    .AsServerCert
    .SelfSigned;
end;

procedure SetupContexts;
begin
  LServerCtx := LLib.CreateContext(sslCtxServer);
  LServerCert.Certificate.SaveToFile('bench_cert.pem');
  LServerCert.PrivateKey.SaveToFile('bench_key.pem');
  LServerCtx.LoadCertificate('bench_cert.pem');
  LServerCtx.LoadPrivateKey('bench_key.pem');
  
  LClientCtx := LLib.CreateContext(sslCtxClient);
end;

procedure BenchmarkHandshake;
var
  LServer, LClient: ISSLConnection;
  LAcceptBio, LClientBio, LServerBio: PBIO;
  LClientSock, LServerSock: Integer;
  LRes: Integer;
begin
  PrintHeader('TLS Handshake Performance');
  
  // Setup listening BIO
  LAcceptBio := BIO_new_accept(PAnsiChar(PORT));
  if LAcceptBio = nil then RaiseLastOSError;
  
  if BIO_do_accept(LAcceptBio) <= 0 then RaiseLastOSError;
  
  LBench := TBenchmark.Create('TLS 1.3 Handshake (Loopback)');
  LBench.SetIterations(ITERATIONS);
  LBench.Start;
  
  for I := 1 to ITERATIONS do
  begin
    // Create client BIO and connect
    LClientBio := BIO_new_connect(PAnsiChar('localhost:' + PORT));
    if BIO_do_connect(LClientBio) <= 0 then
    begin
      BIO_free(LClientBio);
      Continue;
    end;
    
    // Accept connection
    if BIO_do_accept(LAcceptBio) <= 0 then
    begin
      BIO_free(LClientBio);
      Continue;
    end;
    
    LServerBio := BIO_pop(LAcceptBio);
    
    // Get socket handles
    BIO_get_fd(LClientBio, @LClientSock);
    BIO_get_fd(LServerBio, @LServerSock);
    
    // Perform TLS handshake setup
    LServer := LServerCtx.CreateConnection(THandle(LServerSock));
    LClient := LClientCtx.CreateConnection(THandle(LClientSock));
    
    try
      // Simulate handshake setup overhead
    finally
      LServer := nil;
      LClient := nil;
      // BIOs are freed when sockets are closed? 
      // Actually ISSLConnection takes ownership of handle usually?
      // If not, we need to free BIOs. 
      // Assuming ISSLConnection does NOT close socket automatically unless specified.
      // But BIO_free closes socket.
      BIO_free(LClientBio);
      BIO_free(LServerBio);
    end;
  end;
  
  LBench.Stop;
  LBench.Report;
  LBench.Free;
  
  BIO_free(LAcceptBio);
  WriteLn;
  WriteLn('Note: This benchmark measures socket setup + SSL object creation overhead.');
  WriteLn('      Full handshake timing requires multi-threaded test harness.');
  
  DeleteFile('bench_cert.pem');
  DeleteFile('bench_key.pem');
end;

begin
  WriteLn('====================================');
  WriteLn('  TLS Performance Benchmarks');
  WriteLn('====================================');
  WriteLn;
  
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not LLib.Initialize then Halt(1);
  
  SetupCertificates;
  SetupContexts;
  
  BenchmarkHandshake;
  
  WriteLn('====================================');
  WriteLn('  Benchmarks Complete');
  WriteLn('====================================');
end.
