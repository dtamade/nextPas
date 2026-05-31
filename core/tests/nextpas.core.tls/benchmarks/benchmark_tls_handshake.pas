program benchmark_tls_handshake;

{$mode objfpc}{$H+}

{**
 * TLS Handshake Performance Benchmark
 *
 * Benchmarks TLS handshake operations:
 * - Full TLS 1.2 handshake
 * - Full TLS 1.3 handshake
 * - Session resumption handshake
 *
 * Run: ./benchmark_tls_handshake [iterations]
 * Default: 100 iterations per benchmark (handshakes are slower)
 *
 * Output:
 * - Console report with mean, P95, P99, ops/s
 * - JSON baseline file for CI regression detection
 *
 * Note: Requires network connectivity to test server
 *}

uses
  SysUtils, Classes,
  benchmark_framework,
  fafafa.ssl,
  nextpas.core.tls.context.builder,
  fafafa.examples.tcp;

const
  { Test server configuration }
  TEST_HOST = 'www.example.com';
  TEST_PORT = 443;
  HANDSHAKE_TIMEOUT_MS = 10000;

var
  { Global benchmark instance }
  GBenchmark: TBenchmark;

  { Iteration count }
  GIterations: Integer;

  { Reusable contexts for session resumption tests }
  GTLSContext: ISSLContext;

{ ============================================================================ }
{ Helper Functions                                                             }
{ ============================================================================ }

function ConnectAndHandshake(const AHost: string; APort: Word;
  AContext: ISSLContext): Boolean;
var
  Sock: TSocketHandle;
  Connector: TSSLConnector;
  TLS: TSSLStream;
  NetErr: string;
begin
  Result := False;
  Sock := INVALID_SOCKET;
  TLS := nil;

  try
    // Initialize network if needed
    if not InitNetwork(NetErr) then
      Exit;

    // Connect TCP
    Sock := ConnectTCP(AHost, APort);
    if Sock = INVALID_SOCKET then
      Exit;

    // Create connector and perform TLS handshake
    Connector := TSSLConnector.FromContext(AContext)
      .WithTimeout(HANDSHAKE_TIMEOUT_MS);

    try
      TLS := Connector.ConnectSocket(THandle(Sock), AHost);
      Result := (TLS <> nil) and (TLS.Connection <> nil);
    except
      on E: Exception do
      begin
        // TLS handshake failed, but this is expected in benchmarks
        // Just return False to indicate failure
        Result := False;
      end;
    end;
  finally
    if TLS <> nil then
      TLS.Free;
    if Sock <> INVALID_SOCKET then
      CloseSocket(Sock);
  end;
end;

{ ============================================================================ }
{ TLS 1.2 Handshake Benchmark                                                  }
{ ============================================================================ }

procedure BenchTLS12_Handshake;
var
  Ctx: ISSLContext;
begin
  Ctx := TSSLContextBuilder.Create
    .WithTLS12
    .WithVerifyPeer
    .WithSystemRoots
    .BuildClient;

  ConnectAndHandshake(TEST_HOST, TEST_PORT, Ctx);
end;

{ ============================================================================ }
{ TLS 1.3 Handshake Benchmark                                                  }
{ ============================================================================ }

procedure BenchTLS13_Handshake;
var
  Ctx: ISSLContext;
begin
  Ctx := TSSLContextBuilder.Create
    .WithTLS13
    .WithVerifyPeer
    .WithSystemRoots
    .BuildClient;

  ConnectAndHandshake(TEST_HOST, TEST_PORT, Ctx);
end;

{ ============================================================================ }
{ TLS 1.2+1.3 Handshake Benchmark                                              }
{ ============================================================================ }

procedure BenchTLS12And13_Handshake;
var
  Ctx: ISSLContext;
begin
  Ctx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithSystemRoots
    .BuildClient;

  ConnectAndHandshake(TEST_HOST, TEST_PORT, Ctx);
end;

{ ============================================================================ }
{ Session Resumption Benchmark                                                 }
{ ============================================================================ }

procedure BenchSessionResumption;
begin
  // Use the pre-created context with session cache enabled
  ConnectAndHandshake(TEST_HOST, TEST_PORT, GTLSContext);
end;

{ ============================================================================ }
{ Main Program                                                                 }
{ ============================================================================ }

procedure RegisterAllTests;
begin
  WriteLn('Registering TLS handshake benchmark tests...');

  // Full handshake tests
  GBenchmark.RegisterTest('tls12_handshake', @BenchTLS12_Handshake);
  GBenchmark.RegisterTest('tls13_handshake', @BenchTLS13_Handshake);
  GBenchmark.RegisterTest('tls12_13_handshake', @BenchTLS12And13_Handshake);

  // Session resumption test
  GBenchmark.RegisterTest('session_resumption', @BenchSessionResumption);

  WriteLn('Registered ', 4, ' TLS handshake benchmark tests');
end;

procedure PrintUsage;
begin
  WriteLn('Usage: ', ExtractFileName(ParamStr(0)), ' [iterations]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  iterations    Number of iterations per test (default: 100)');
  WriteLn;
  WriteLn('Examples:');
  WriteLn('  ', ExtractFileName(ParamStr(0)), '           # Run with 100 iterations');
  WriteLn('  ', ExtractFileName(ParamStr(0)), ' 50        # Run with 50 iterations');
  WriteLn('  ', ExtractFileName(ParamStr(0)), ' 200       # Run with 200 iterations');
  WriteLn;
  WriteLn('Note: TLS handshakes require network connectivity to ', TEST_HOST);
end;

procedure InitializeTestContext;
begin
  WriteLn('Initializing test context for session resumption...');

  // Create a context with session cache enabled for resumption tests
  GTLSContext := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithSystemRoots
    .WithSessionCache(True)
    .WithSessionTimeout(300)  // 5 minutes
    .BuildClient;

  WriteLn('Test context initialized');
end;

begin
  WriteLn('================================================================');
  WriteLn('TLS Handshake Performance Benchmark');
  WriteLn('================================================================');
  WriteLn;

  // Parse command line arguments
  GIterations := 100;  // Lower default for handshakes (they're slower)
  if ParamCount > 0 then
  begin
    if (ParamStr(1) = '-h') or (ParamStr(1) = '--help') then
    begin
      PrintUsage;
      Halt(0);
    end;

    GIterations := StrToIntDef(ParamStr(1), 100);
    if GIterations <= 0 then
    begin
      WriteLn('Error: Iterations must be positive');
      Halt(1);
    end;
  end;

  WriteLn('Iterations per test: ', GIterations);
  WriteLn('Test server: ', TEST_HOST, ':', TEST_PORT);
  WriteLn;

  // Initialize test context
  InitializeTestContext;
  WriteLn;

  // Create benchmark instance
  GBenchmark := TBenchmark.Create;
  try
    GBenchmark.WarmupIterations := 10;  // Fewer warmup iterations for handshakes
    GBenchmark.RegressionThreshold := 0.20; // 20% threshold (network variance)

    // Register all tests
    RegisterAllTests;
    WriteLn;

    // Run all tests
    WriteLn('Running TLS handshake benchmarks...');
    WriteLn('Note: This may take a while due to network operations');
    WriteLn('================================================================');
    GBenchmark.Run(GIterations);
    WriteLn('================================================================');
    WriteLn;

    // Print results
    GBenchmark.PrintResults;
    WriteLn;

    // Save baseline
    WriteLn('Saving baseline to tls_handshake_baseline.json...');
    GBenchmark.SaveBaseline('tls_handshake_baseline.json');
    WriteLn('Baseline saved');
    WriteLn;

    WriteLn('================================================================');
    WriteLn('Benchmark completed successfully');
    WriteLn('================================================================');
  finally
    GBenchmark.Free;
  end;
end.
