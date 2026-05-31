program benchmark_tls_handshake_diagnostic;

{$mode objfpc}{$H+}

{**
 * TLS Handshake Diagnostic Benchmark
 *
 * Enhanced version with detailed timing breakdown:
 * - Separate timing for DNS, TCP, TLS handshake
 * - Timeout and failure tracking
 * - Local vs network comparison
 * - Context creation overhead measurement
 *
 * Run: ./benchmark_tls_handshake_diagnostic [iterations] [host:port]
 * Default: 100 iterations, www.example.com:443
 *
 * Examples:
 *   ./benchmark_tls_handshake_diagnostic 50
 *   ./benchmark_tls_handshake_diagnostic 50 localhost:44330
 *}

uses
  SysUtils, Classes, Sockets,
  benchmark_framework,
  fafafa.ssl,
  nextpas.core.tls.context.builder,
  fafafa.examples.tcp;

const
  DEFAULT_HOST = 'www.example.com';
  DEFAULT_PORT = 443;
  HANDSHAKE_TIMEOUT_MS = 10000;

type
  TTimingBreakdown = record
    DNSTime: Int64;        // DNS resolution time (ms)
    TCPTime: Int64;        // TCP connection time (ms)
    TLSTime: Int64;        // TLS handshake time (ms)
    TotalTime: Int64;      // Total time (ms)
    Success: Boolean;      // Whether handshake succeeded
    ErrorMsg: string;      // Error message if failed
  end;

  TDiagnosticStats = record
    Timings: array of TTimingBreakdown;
    SuccessCount: Integer;
    TimeoutCount: Integer;
    FailureCount: Integer;
    AvgDNS: Double;
    AvgTCP: Double;
    AvgTLS: Double;
    AvgTotal: Double;
  end;

var
  GBenchmark: TBenchmark;
  GIterations: Integer;
  GTestHost: string;
  GTestPort: Word;

  { Diagnostic statistics }
  GTLSStats: TDiagnosticStats;

  { Reusable context for overhead comparison }
  GSharedContext: ISSLContext;

{ ============================================================================ }
{ Timing Utilities                                                             }
{ ============================================================================ }

function GetTickCount64MS: Int64;
begin
  Result := GetTickCount64;
end;

{ ============================================================================ }
{ Enhanced Connection with Timing Breakdown                                    }
{ ============================================================================ }

function ConnectAndHandshakeWithTiming(const AHost: string; APort: Word;
  AContext: ISSLContext; out Timing: TTimingBreakdown): Boolean;
var
  Sock: TSocketHandle;
  Connector: TSSLConnector;
  TLS: TSSLStream;
  NetErr: string;
  StartTime, DNSEnd, TCPEnd, TLSEnd: Int64;
begin
  Result := False;
  Sock := INVALID_SOCKET;
  TLS := nil;

  FillChar(Timing, SizeOf(Timing), 0);
  StartTime := GetTickCount64MS;

  try
    // Initialize network
    if not InitNetwork(NetErr) then
    begin
      Timing.ErrorMsg := 'Network init failed: ' + NetErr;
      Exit;
    end;

    // DNS Resolution + TCP Connection
    // Note: ConnectTCP combines DNS and TCP, we can't separate them easily
    // without modifying the underlying code
    Sock := ConnectTCP(AHost, APort);
    TCPEnd := GetTickCount64MS;
    Timing.DNSTime := 0;  // Combined with TCP
    Timing.TCPTime := TCPEnd - StartTime;

    if Sock = INVALID_SOCKET then
    begin
      Timing.ErrorMsg := 'TCP connection failed';
      Exit;
    end;

    // TLS Handshake
    Connector := TSSLConnector.FromContext(AContext)
      .WithTimeout(HANDSHAKE_TIMEOUT_MS);

    TLS := Connector.ConnectSocket(THandle(Sock), AHost);
    TLSEnd := GetTickCount64MS;
    Timing.TLSTime := TLSEnd - TCPEnd;

    Timing.TotalTime := TLSEnd - StartTime;
    Timing.Success := (TLS <> nil) and (TLS.Connection <> nil);
    Result := Timing.Success;

  except
    on E: Exception do
    begin
      Timing.ErrorMsg := E.Message;
      Timing.TotalTime := GetTickCount64MS - StartTime;

      // Check if it's a timeout
      if (Timing.TotalTime >= HANDSHAKE_TIMEOUT_MS) or
         (Pos('timeout', LowerCase(E.Message)) > 0) then
        Timing.ErrorMsg := 'TIMEOUT: ' + E.Message;
    end;
  end;

  // Cleanup
  if TLS <> nil then
    TLS.Free;
  if Sock <> INVALID_SOCKET then
    CloseSocket(Sock);
end;

{ ============================================================================ }
{ Diagnostic Test: TLS 1.3 with Detailed Timing                               }
{ ============================================================================ }

procedure DiagnosticTLS13Test;
var
  Ctx: ISSLContext;
  Timing: TTimingBreakdown;
  Idx: Integer;
begin
  // Create context (this overhead is included in first iteration)
  // For localhost testing, disable certificate verification
  if (GTestHost = 'localhost') or (GTestHost = '127.0.0.1') then
    Ctx := TSSLContextBuilder.Create
      .WithTLS13
      .WithVerifyNone  // Disable verification for localhost
      .BuildClient
  else
    Ctx := TSSLContextBuilder.Create
      .WithTLS13
      .WithVerifyPeer
      .WithSystemRoots
      .BuildClient;

  Idx := Length(GTLSStats.Timings);
  SetLength(GTLSStats.Timings, Idx + 1);

  ConnectAndHandshakeWithTiming(GTestHost, GTestPort, Ctx, Timing);

  GTLSStats.Timings[Idx] := Timing;

  if Timing.Success then
    Inc(GTLSStats.SuccessCount)
  else if Pos('TIMEOUT', Timing.ErrorMsg) > 0 then
    Inc(GTLSStats.TimeoutCount)
  else
    Inc(GTLSStats.FailureCount);
end;

{ ============================================================================ }
{ Diagnostic Test: TLS 1.3 with Shared Context                                }
{ ============================================================================ }

procedure DiagnosticTLS13SharedContext;
var
  Timing: TTimingBreakdown;
  Idx: Integer;
begin
  Idx := Length(GTLSStats.Timings);
  SetLength(GTLSStats.Timings, Idx + 1);

  ConnectAndHandshakeWithTiming(GTestHost, GTestPort, GSharedContext, Timing);

  GTLSStats.Timings[Idx] := Timing;

  if Timing.Success then
    Inc(GTLSStats.SuccessCount)
  else if Pos('TIMEOUT', Timing.ErrorMsg) > 0 then
    Inc(GTLSStats.TimeoutCount)
  else
    Inc(GTLSStats.FailureCount);
end;

{ ============================================================================ }
{ Statistics Calculation                                                       }
{ ============================================================================ }

procedure CalculateStats(var Stats: TDiagnosticStats);
var
  I: Integer;
  TotalDNS, TotalTCP, TotalTLS, TotalTime: Int64;
  SuccessfulSamples: Integer;
begin
  TotalDNS := 0;
  TotalTCP := 0;
  TotalTLS := 0;
  TotalTime := 0;
  SuccessfulSamples := 0;

  for I := 0 to High(Stats.Timings) do
  begin
    if Stats.Timings[I].Success then
    begin
      TotalDNS := TotalDNS + Stats.Timings[I].DNSTime;
      TotalTCP := TotalTCP + Stats.Timings[I].TCPTime;
      TotalTLS := TotalTLS + Stats.Timings[I].TLSTime;
      TotalTime := TotalTime + Stats.Timings[I].TotalTime;
      Inc(SuccessfulSamples);
    end;
  end;

  if SuccessfulSamples > 0 then
  begin
    Stats.AvgDNS := TotalDNS / SuccessfulSamples;
    Stats.AvgTCP := TotalTCP / SuccessfulSamples;
    Stats.AvgTLS := TotalTLS / SuccessfulSamples;
    Stats.AvgTotal := TotalTime / SuccessfulSamples;
  end;
end;

procedure PrintDiagnosticReport;
var
  I, J: Integer;
  P50, P95, P99: Int64;
  SortedTimes: array of Int64;
  ValidCount: Integer;
  Temp: Int64;
begin
  WriteLn;
  WriteLn('================================================================');
  WriteLn('DIAGNOSTIC REPORT: TLS 1.3 Handshake Analysis');
  WriteLn('================================================================');
  WriteLn;
  WriteLn('Test Configuration:');
  WriteLn('  Target: ', GTestHost, ':', GTestPort);
  WriteLn('  Iterations: ', Length(GTLSStats.Timings));
  WriteLn('  Timeout: ', HANDSHAKE_TIMEOUT_MS, 'ms');
  WriteLn;

  CalculateStats(GTLSStats);

  WriteLn('Summary:');
  WriteLn('  Successful: ', GTLSStats.SuccessCount);
  WriteLn('  Timeouts:   ', GTLSStats.TimeoutCount);
  WriteLn('  Failures:   ', GTLSStats.FailureCount);
  WriteLn;

  if GTLSStats.SuccessCount > 0 then
  begin
    WriteLn('Average Timing Breakdown (successful samples only):');
    WriteLn('  DNS + TCP:  ', GTLSStats.AvgTCP:0:2, ' ms');
    WriteLn('  TLS:        ', GTLSStats.AvgTLS:0:2, ' ms');
    WriteLn('  Total:      ', GTLSStats.AvgTotal:0:2, ' ms');
    WriteLn;

    // Calculate percentiles
    SetLength(SortedTimes, GTLSStats.SuccessCount);
    ValidCount := 0;
    for I := 0 to High(GTLSStats.Timings) do
    begin
      if GTLSStats.Timings[I].Success then
      begin
        SortedTimes[ValidCount] := GTLSStats.Timings[I].TotalTime;
        Inc(ValidCount);
      end;
    end;

    // Simple bubble sort for percentiles
    for I := 0 to ValidCount - 2 do
    begin
      for J := I + 1 to ValidCount - 1 do
      begin
        if SortedTimes[J] < SortedTimes[I] then
        begin
          Temp := SortedTimes[I];
          SortedTimes[I] := SortedTimes[J];
          SortedTimes[J] := Temp;
        end;
      end;
    end;

    P50 := SortedTimes[ValidCount div 2];
    P95 := SortedTimes[Round(ValidCount * 0.95)];
    P99 := SortedTimes[Round(ValidCount * 0.99)];

    WriteLn('Percentiles (total time):');
    WriteLn('  P50: ', P50, ' ms');
    WriteLn('  P95: ', P95, ' ms');
    WriteLn('  P99: ', P99, ' ms');
    WriteLn;
  end;

  // Show failed/timeout samples
  if (GTLSStats.TimeoutCount > 0) or (GTLSStats.FailureCount > 0) then
  begin
    WriteLn('Failed/Timeout Samples:');
    for I := 0 to High(GTLSStats.Timings) do
    begin
      if not GTLSStats.Timings[I].Success then
      begin
        WriteLn('  [', I + 1, '] ', GTLSStats.Timings[I].TotalTime, 'ms - ',
                GTLSStats.Timings[I].ErrorMsg);
      end;
    end;
    WriteLn;
  end;

  WriteLn('================================================================');
end;

{ ============================================================================ }
{ Main Program                                                                 }
{ ============================================================================ }

procedure ParseCommandLine;
var
  HostPort: string;
  ColonPos: Integer;
begin
  GIterations := 100;
  GTestHost := DEFAULT_HOST;
  GTestPort := DEFAULT_PORT;

  if ParamCount >= 1 then
  begin
    if (ParamStr(1) = '-h') or (ParamStr(1) = '--help') then
    begin
      WriteLn('Usage: ', ExtractFileName(ParamStr(0)), ' [iterations] [host:port]');
      WriteLn;
      WriteLn('Examples:');
      WriteLn('  ', ExtractFileName(ParamStr(0)), ' 50');
      WriteLn('  ', ExtractFileName(ParamStr(0)), ' 50 localhost:44330');
      WriteLn('  ', ExtractFileName(ParamStr(0)), ' 100 www.example.com:443');
      Halt(0);
    end;

    GIterations := StrToIntDef(ParamStr(1), 100);
  end;

  if ParamCount >= 2 then
  begin
    HostPort := ParamStr(2);
    ColonPos := Pos(':', HostPort);
    if ColonPos > 0 then
    begin
      GTestHost := Copy(HostPort, 1, ColonPos - 1);
      GTestPort := StrToIntDef(Copy(HostPort, ColonPos + 1, Length(HostPort)), DEFAULT_PORT);
    end
    else
      GTestHost := HostPort;
  end;
end;

begin
  WriteLn('================================================================');
  WriteLn('TLS Handshake Diagnostic Benchmark');
  WriteLn('================================================================');
  WriteLn;

  ParseCommandLine;

  WriteLn('Configuration:');
  WriteLn('  Iterations: ', GIterations);
  WriteLn('  Target: ', GTestHost, ':', GTestPort);
  WriteLn;

  // Initialize shared context for comparison
  WriteLn('Initializing shared context...');
  if (GTestHost = 'localhost') or (GTestHost = '127.0.0.1') then
    GSharedContext := TSSLContextBuilder.Create
      .WithTLS13
      .WithVerifyNone  // Disable verification for localhost
      .BuildClient
  else
    GSharedContext := TSSLContextBuilder.Create
      .WithTLS13
      .WithVerifyPeer
      .WithSystemRoots
      .BuildClient;
  WriteLn('Shared context initialized');
  WriteLn;

  // Initialize stats
  FillChar(GTLSStats, SizeOf(GTLSStats), 0);
  SetLength(GTLSStats.Timings, 0);

  // Create benchmark instance
  GBenchmark := TBenchmark.Create;
  try
    GBenchmark.WarmupIterations := 5;
    GBenchmark.RegressionThreshold := 0.30;

    WriteLn('Running diagnostic tests...');
    WriteLn('Test 1: TLS 1.3 with new context per iteration');
    WriteLn('================================================================');

    GBenchmark.RegisterTest('tls13_new_context', @DiagnosticTLS13Test);
    GBenchmark.Run(GIterations);

    PrintDiagnosticReport;

    // Reset for second test
    FillChar(GTLSStats, SizeOf(GTLSStats), 0);
    SetLength(GTLSStats.Timings, 0);

    WriteLn;
    WriteLn('Test 2: TLS 1.3 with shared context (reused)');
    WriteLn('================================================================');

    GBenchmark.RegisterTest('tls13_shared_context', @DiagnosticTLS13SharedContext);
    GBenchmark.Run(GIterations);

    PrintDiagnosticReport;

    WriteLn;
    WriteLn('================================================================');
    WriteLn('Diagnostic completed');
    WriteLn('================================================================');
  finally
    GBenchmark.Free;
  end;
end.
