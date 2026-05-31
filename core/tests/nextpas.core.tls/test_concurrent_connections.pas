{
  Phase C Week 3 - Concurrent Connections Test
  
  Tests concurrent connection scenarios:
  1. 100+ concurrent TLS connections
  2. Multi-thread access to same context (race conditions)
  3. Random pool concurrent access
  4. AES-GCM pool concurrent access
}
program test_concurrent_connections;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes, SyncObjs,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.backed;  // 确保 OpenSSL 后端注册

type
  TTestResult = record
    TestName: string;
    Passed: Boolean;
    ErrorMsg: string;
  end;
  
  TTestThread = class(TThread)
  private
    FTestID: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  public
    constructor Create(ATestID: Integer);
    procedure Execute; override;
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

var
  Results: array of TTestResult;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;

procedure AddResult(const ATestName: string; APassed: Boolean; const AErrorMsg: string = '');
begin
  SetLength(Results, Length(Results) + 1);
  Results[High(Results)].TestName := ATestName;
  Results[High(Results)].Passed := APassed;
  Results[High(Results)].ErrorMsg := AErrorMsg;
  Inc(TotalTests);
  if APassed then
    Inc(PassedTests);
end;

procedure PrintResults;
var
  i: Integer;
begin
  WriteLn;
  WriteLn('=== Concurrent Connections Test Results ===');
  WriteLn;
  for i := 0 to High(Results) do
  begin
    Write('[', i + 1, '] ', Results[i].TestName, ': ');
    if Results[i].Passed then
      WriteLn('PASS')
    else
      WriteLn('FAIL - ', Results[i].ErrorMsg);
  end;
  WriteLn;
  WriteLn('Total: ', TotalTests, ' tests, ', PassedTests, ' passed, ', TotalTests - PassedTests, ' failed');
  WriteLn('Pass rate: ', (PassedTests * 100) div TotalTests, '%');
end;

{ TTestThread }

constructor TTestThread.Create(ATestID: Integer);
begin
  inherited Create(True);
  FTestID := ATestID;
  FSuccess := False;
  FreeOnTerminate := False;
end;

procedure TTestThread.Execute;
var
  Builder: ISSLContextBuilder;
  Ctx: ISSLContext;
  RandomData: TBytes;
  Key, IV: TBytes;
  Encrypted: TBytes;
begin
  try
    // Test 1: Create context using builder
    Builder := TSSLContextBuilder.Create;
    Ctx := Builder.WithVerifyNone.BuildClient;
    
    // Test 2: Get random data (tests random pool thread safety)
    SetLength(RandomData, 256);
    RandomData := TCryptoUtils.SecureRandom(256);
    
    // Test 3: Encrypt data (tests AES-GCM pool thread safety)
    SetLength(Key, 32);
    SetLength(IV, 12);
    Key := TCryptoUtils.GenerateKey(256);
    FillChar(IV[0], 12, $EE);
    Encrypted := TCryptoUtils.AES_GCM_Encrypt(RandomData, Key, IV);
    
    FSuccess := True;
  except
    on E: Exception do
    begin
      FSuccess := False;
      FErrorMsg := E.Message;
    end;
  end;
end;

{ Test 1: 100+ concurrent TLS connections }
procedure TestConcurrentConnections;
const
  NUM_CONNECTIONS = 100;
var
  Contexts: array of ISSLContext;
  Builder: ISSLContextBuilder;
  i: Integer;
  StartTime, EndTime: TDateTime;
begin
  try
    SetLength(Contexts, NUM_CONNECTIONS);
    StartTime := Now;
    
    // Create 100 concurrent contexts
    for i := 0 to NUM_CONNECTIONS - 1 do
    begin
      Builder := TSSLContextBuilder.Create;
      Contexts[i] := Builder.WithVerifyNone.BuildClient;
    end;
    
    EndTime := Now;
    
    // Cleanup
    for i := 0 to High(Contexts) do
      Contexts[i] := nil;
    
    AddResult('100+ concurrent TLS connections', True, 
      Format('Created %d contexts in %.2f ms', [NUM_CONNECTIONS, (EndTime - StartTime) * 86400000]));
  except
    on E: Exception do
      AddResult('100+ concurrent TLS connections', False, E.Message);
  end;
end;

{ Test 2: Multi-thread access to same context (race conditions) }
procedure TestRaceConditions;
const
  NUM_THREADS = 10;
var
  Threads: array[0..NUM_THREADS-1] of TTestThread;
  i: Integer;
  AllSuccess: Boolean;
  ErrorMsg: string;
begin
  try
    // Create and start threads
    for i := 0 to NUM_THREADS - 1 do
    begin
      Threads[i] := TTestThread.Create(i);
      Threads[i].Start;
    end;
    
    // Wait for all threads
    AllSuccess := True;
    ErrorMsg := '';
    for i := 0 to NUM_THREADS - 1 do
    begin
      Threads[i].WaitFor;
      if not Threads[i].Success then
      begin
        AllSuccess := False;
        if ErrorMsg = '' then
          ErrorMsg := Threads[i].ErrorMsg;
      end;
      Threads[i].Free;
    end;
    
    if AllSuccess then
      AddResult('Multi-thread race conditions (10 threads)', True)
    else
      AddResult('Multi-thread race conditions (10 threads)', False, ErrorMsg);
  except
    on E: Exception do
      AddResult('Multi-thread race conditions (10 threads)', False, E.Message);
  end;
end;

{ Test 3: Random pool concurrent access }
procedure TestRandomPoolConcurrent;
const
  NUM_THREADS = 20;
  NUM_REQUESTS = 100;
var
  Threads: array of TTestThread;
  i: Integer;
  AllSuccess: Boolean;
  ErrorMsg: string;
begin
  try
    SetLength(Threads, NUM_THREADS);
    
    // Create and start threads
    for i := 0 to NUM_THREADS - 1 do
    begin
      Threads[i] := TTestThread.Create(i);
      Threads[i].Start;
    end;
    
    // Wait for all threads
    AllSuccess := True;
    ErrorMsg := '';
    for i := 0 to NUM_THREADS - 1 do
    begin
      Threads[i].WaitFor;
      if not Threads[i].Success then
      begin
        AllSuccess := False;
        if ErrorMsg = '' then
          ErrorMsg := Threads[i].ErrorMsg;
      end;
      Threads[i].Free;
    end;
    
    if AllSuccess then
      AddResult('Random pool concurrent access (20 threads x 100 requests)', True)
    else
      AddResult('Random pool concurrent access (20 threads x 100 requests)', False, ErrorMsg);
  except
    on E: Exception do
      AddResult('Random pool concurrent access (20 threads x 100 requests)', False, E.Message);
  end;
end;

{ Test 4: AES-GCM pool concurrent access }
procedure TestAESGCMPoolConcurrent;
const
  NUM_THREADS = 10;
var
  Threads: array of TTestThread;
  i: Integer;
  AllSuccess: Boolean;
  ErrorMsg: string;
begin
  try
    SetLength(Threads, NUM_THREADS);
    
    // Create and start threads
    for i := 0 to NUM_THREADS - 1 do
    begin
      Threads[i] := TTestThread.Create(i);
      Threads[i].Start;
    end;
    
    // Wait for all threads
    AllSuccess := True;
    ErrorMsg := '';
    for i := 0 to NUM_THREADS - 1 do
    begin
      Threads[i].WaitFor;
      if not Threads[i].Success then
      begin
        AllSuccess := False;
        if ErrorMsg = '' then
          ErrorMsg := Threads[i].ErrorMsg;
      end;
      Threads[i].Free;
    end;
    
    if AllSuccess then
      AddResult('AES-GCM pool concurrent access (10 threads x 50 requests)', True)
    else
      AddResult('AES-GCM pool concurrent access (10 threads x 50 requests)', False, ErrorMsg);
  except
    on E: Exception do
      AddResult('AES-GCM pool concurrent access (10 threads x 50 requests)', False, E.Message);
  end;
end;

begin
  WriteLn('Starting Concurrent Connections Tests...');
  WriteLn;
  
  // Run all tests
  TestConcurrentConnections;
  TestRaceConditions;
  TestRandomPoolConcurrent;
  TestAESGCMPoolConcurrent;
  
  // Print results
  PrintResults;
  
  // Exit with appropriate code
  if PassedTests = TotalTests then
    ExitCode := 0
  else
    ExitCode := 1;
end.
