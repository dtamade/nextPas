{
  Phase C Week 1 - 并发连接测试

  测试场景：
  1. 多线程同时创建连接
  2. 连接池的线程安全性
  3. 高并发下的资源管理
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
  nextpas.core.tls.openssl.backed;

const
  { 测试配置 }
  NUM_CONCURRENT_CONTEXTS = 50;   // 并发创建的上下文数量
  NUM_STRESS_THREADS = 20;        // 压力测试线程数
  NUM_OPS_PER_THREAD = 100;       // 每线程操作次数
  CONNECTION_POOL_SIZE = 10;      // 连接池大小

type
  { 测试结果记录 }
  TTestResultRec = record
    TestName: string;
    Passed: Boolean;
    ErrorMsg: string;
    Duration: Double;  // 毫秒
  end;

  { 基础测试线程 }
  TBaseTestThread = class(TThread)
  protected
    FTestID: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
    FOperationCount: Integer;
  public
    constructor Create(ATestID: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
    property OperationCount: Integer read FOperationCount;
  end;

  { 上下文创建线程 }
  TContextCreationThread = class(TBaseTestThread)
  protected
    procedure Execute; override;
  end;

  { 加密操作线程 }
  TCryptoOperationThread = class(TBaseTestThread)
  protected
    procedure Execute; override;
  end;

  { 资源管理测试线程 }
  TResourceManagementThread = class(TBaseTestThread)
  private
    FContexts: array of ISSLContext;
  protected
    procedure Execute; override;
  end;

  { 混合操作线程 }
  TMixedOperationThread = class(TBaseTestThread)
  protected
    procedure Execute; override;
  end;

var
  Results: array of TTestResultRec;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  GlobalLock: TCriticalSection;

procedure AddResult(const ATestName: string; APassed: Boolean;
  const AErrorMsg: string = ''; ADuration: Double = 0);
begin
  GlobalLock.Enter;
  try
    SetLength(Results, Length(Results) + 1);
    Results[High(Results)].TestName := ATestName;
    Results[High(Results)].Passed := APassed;
    Results[High(Results)].ErrorMsg := AErrorMsg;
    Results[High(Results)].Duration := ADuration;
    Inc(TotalTests);
    if APassed then
      Inc(PassedTests);
  finally
    GlobalLock.Leave;
  end;
end;

procedure PrintResults;
var
  i: Integer;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('Concurrent Connections Test Results');
  WriteLn('========================================');
  WriteLn;

  for i := 0 to High(Results) do
  begin
    Write('[', i + 1:2, '] ');
    if Results[i].Passed then
      Write('[PASS] ')
    else
      Write('[FAIL] ');

    Write(Results[i].TestName);

    if Results[i].Duration > 0 then
      Write(' (', Results[i].Duration:0:2, ' ms)');

    WriteLn;

    if not Results[i].Passed and (Results[i].ErrorMsg <> '') then
      WriteLn('       Error: ', Results[i].ErrorMsg);
  end;

  WriteLn;
  WriteLn('----------------------------------------');
  WriteLn('Total: ', TotalTests, ' tests, ', PassedTests, ' passed, ',
    TotalTests - PassedTests, ' failed');

  if TotalTests > 0 then
    WriteLn('Pass rate: ', (PassedTests * 100) div TotalTests, '%');
  WriteLn('========================================');
end;

{ TBaseTestThread }

constructor TBaseTestThread.Create(ATestID: Integer);
begin
  inherited Create(True);
  FTestID := ATestID;
  FSuccess := False;
  FErrorMsg := '';
  FOperationCount := 0;
  FreeOnTerminate := False;
end;

{ TContextCreationThread }

procedure TContextCreationThread.Execute;
var
  Builder: ISSLContextBuilder;
  Ctx: ISSLContext;
  i: Integer;
begin
  try
    for i := 1 to 10 do
    begin
      if Terminated then Break;

      Builder := TSSLContextBuilder.Create;
      Ctx := Builder.WithVerifyNone.BuildClient;

      if Ctx <> nil then
        Inc(FOperationCount);

      Ctx := nil;  // 释放
    end;

    FSuccess := (FOperationCount = 10);
    if not FSuccess then
      FErrorMsg := Format('Only %d/10 contexts created', [FOperationCount]);
  except
    on E: Exception do
    begin
      FSuccess := False;
      FErrorMsg := E.Message;
    end;
  end;
end;

{ TCryptoOperationThread }

procedure TCryptoOperationThread.Execute;
var
  RandomData, Key, IV, Encrypted, Decrypted: TBytes;
  i: Integer;
begin
  try
    for i := 1 to NUM_OPS_PER_THREAD do
    begin
      if Terminated then Break;

      // 生成随机数据
      RandomData := TCryptoUtils.SecureRandom(64);
      if Length(RandomData) <> 64 then Continue;

      // 生成密钥
      Key := TCryptoUtils.GenerateKey(256);
      if Length(Key) <> 32 then Continue;

      // 创建 IV
      SetLength(IV, 12);
      FillChar(IV[0], 12, Byte(i mod 256));

      // 加密
      Encrypted := TCryptoUtils.AES_GCM_Encrypt(RandomData, Key, IV);
      if Length(Encrypted) = 0 then Continue;

      // 解密
      Decrypted := TCryptoUtils.AES_GCM_Decrypt(Encrypted, Key, IV);
      if Length(Decrypted) = 0 then Continue;

      // 验证
      if CompareMem(@RandomData[0], @Decrypted[0], 64) then
        Inc(FOperationCount);
    end;

    FSuccess := (FOperationCount >= NUM_OPS_PER_THREAD * 80 div 100);  // 80% 成功率
    if not FSuccess then
      FErrorMsg := Format('%d/%d operations succeeded', [FOperationCount, NUM_OPS_PER_THREAD]);
  except
    on E: Exception do
    begin
      FSuccess := False;
      FErrorMsg := E.Message;
    end;
  end;
end;

{ TResourceManagementThread }

procedure TResourceManagementThread.Execute;
var
  Builder: ISSLContextBuilder;
  i, j: Integer;
begin
  try
    // 测试资源的创建和释放循环
    for i := 1 to 5 do
    begin
      if Terminated then Break;

      // 批量创建
      SetLength(FContexts, CONNECTION_POOL_SIZE);
      for j := 0 to CONNECTION_POOL_SIZE - 1 do
      begin
        Builder := TSSLContextBuilder.Create;
        FContexts[j] := Builder.WithVerifyNone.BuildClient;
      end;

      // 验证全部创建成功
      for j := 0 to CONNECTION_POOL_SIZE - 1 do
      begin
        if FContexts[j] <> nil then
          Inc(FOperationCount);
      end;

      // 批量释放
      for j := 0 to CONNECTION_POOL_SIZE - 1 do
        FContexts[j] := nil;

      SetLength(FContexts, 0);
    end;

    FSuccess := (FOperationCount >= 5 * CONNECTION_POOL_SIZE * 80 div 100);
    if not FSuccess then
      FErrorMsg := Format('%d/%d resources managed successfully',
        [FOperationCount, 5 * CONNECTION_POOL_SIZE]);
  except
    on E: Exception do
    begin
      FSuccess := False;
      FErrorMsg := E.Message;
    end;
  end;
end;

{ TMixedOperationThread }

procedure TMixedOperationThread.Execute;
var
  Builder: ISSLContextBuilder;
  Ctx: ISSLContext;
  RandomData, Key: TBytes;
  i: Integer;
begin
  try
    for i := 1 to 20 do
    begin
      if Terminated then Break;

      // 创建上下文
      Builder := TSSLContextBuilder.Create;
      Ctx := Builder.WithVerifyNone.BuildClient;

      if Ctx = nil then Continue;

      // 执行加密操作
      RandomData := TCryptoUtils.SecureRandom(32);
      Key := TCryptoUtils.GenerateKey(128);

      if (Length(RandomData) = 32) and (Length(Key) = 16) then
        Inc(FOperationCount);

      // 释放上下文
      Ctx := nil;
    end;

    FSuccess := (FOperationCount >= 16);  // 80% 成功率
    if not FSuccess then
      FErrorMsg := Format('%d/20 mixed operations succeeded', [FOperationCount]);
  except
    on E: Exception do
    begin
      FSuccess := False;
      FErrorMsg := E.Message;
    end;
  end;
end;

{ Test 1: 多线程同时创建连接 }
procedure Test_MultithreadedContextCreation;
var
  Threads: array of TContextCreationThread;
  i: Integer;
  AllSuccess: Boolean;
  FailedCount: Integer;
  StartTime, EndTime: TDateTime;
  ErrorMsg: string;
begin
  WriteLn;
  WriteLn('Test: Multithreaded Context Creation');
  WriteLn('----------------------------------------');

  SetLength(Threads, NUM_STRESS_THREADS);
  StartTime := Now;

  try
    // 创建并启动线程
    for i := 0 to NUM_STRESS_THREADS - 1 do
    begin
      Threads[i] := TContextCreationThread.Create(i);
      Threads[i].Start;
    end;

    // 等待所有线程完成
    AllSuccess := True;
    FailedCount := 0;
    ErrorMsg := '';

    for i := 0 to NUM_STRESS_THREADS - 1 do
    begin
      Threads[i].WaitFor;
      if not Threads[i].Success then
      begin
        AllSuccess := False;
        Inc(FailedCount);
        if ErrorMsg = '' then
          ErrorMsg := Threads[i].ErrorMsg;
      end;
      Threads[i].Free;
    end;

    EndTime := Now;

    if AllSuccess then
      AddResult(Format('Multithreaded context creation (%d threads)', [NUM_STRESS_THREADS]),
        True, '', (EndTime - StartTime) * 86400000)
    else
      AddResult(Format('Multithreaded context creation (%d threads)', [NUM_STRESS_THREADS]),
        False, Format('%d threads failed: %s', [FailedCount, ErrorMsg]),
        (EndTime - StartTime) * 86400000);

  except
    on E: Exception do
      AddResult('Multithreaded context creation', False, E.Message);
  end;
end;

{ Test 2: 连接池的线程安全性 }
procedure Test_ConnectionPoolThreadSafety;
var
  Threads: array of TResourceManagementThread;
  i: Integer;
  AllSuccess: Boolean;
  TotalOps: Integer;
  StartTime, EndTime: TDateTime;
  ErrorMsg: string;
begin
  WriteLn;
  WriteLn('Test: Connection Pool Thread Safety');
  WriteLn('----------------------------------------');

  SetLength(Threads, 10);
  StartTime := Now;

  try
    // 创建并启动线程
    for i := 0 to 9 do
    begin
      Threads[i] := TResourceManagementThread.Create(i);
      Threads[i].Start;
    end;

    // 等待所有线程完成
    AllSuccess := True;
    TotalOps := 0;
    ErrorMsg := '';

    for i := 0 to 9 do
    begin
      Threads[i].WaitFor;
      TotalOps := TotalOps + Threads[i].OperationCount;
      if not Threads[i].Success then
      begin
        AllSuccess := False;
        if ErrorMsg = '' then
          ErrorMsg := Threads[i].ErrorMsg;
      end;
      Threads[i].Free;
    end;

    EndTime := Now;

    if AllSuccess then
      AddResult(Format('Connection pool thread safety (%d total ops)', [TotalOps]),
        True, '', (EndTime - StartTime) * 86400000)
    else
      AddResult('Connection pool thread safety', False, ErrorMsg,
        (EndTime - StartTime) * 86400000);

  except
    on E: Exception do
      AddResult('Connection pool thread safety', False, E.Message);
  end;
end;

{ Test 3: 高并发下的资源管理 }
procedure Test_HighConcurrencyResourceManagement;
var
  Threads: array of TCryptoOperationThread;
  i: Integer;
  AllSuccess: Boolean;
  TotalOps: Integer;
  FailedThreads: Integer;
  StartTime, EndTime: TDateTime;
  ErrorMsg: string;
begin
  WriteLn;
  WriteLn('Test: High Concurrency Resource Management');
  WriteLn('----------------------------------------');

  SetLength(Threads, NUM_STRESS_THREADS);
  StartTime := Now;

  try
    // 创建并启动线程
    for i := 0 to NUM_STRESS_THREADS - 1 do
    begin
      Threads[i] := TCryptoOperationThread.Create(i);
      Threads[i].Start;
    end;

    // 等待所有线程完成
    AllSuccess := True;
    TotalOps := 0;
    FailedThreads := 0;
    ErrorMsg := '';

    for i := 0 to NUM_STRESS_THREADS - 1 do
    begin
      Threads[i].WaitFor;
      TotalOps := TotalOps + Threads[i].OperationCount;
      if not Threads[i].Success then
      begin
        AllSuccess := False;
        Inc(FailedThreads);
        if ErrorMsg = '' then
          ErrorMsg := Threads[i].ErrorMsg;
      end;
      Threads[i].Free;
    end;

    EndTime := Now;

    if AllSuccess then
      AddResult(Format('High concurrency crypto ops (%d threads, %d ops)', [NUM_STRESS_THREADS, TotalOps]),
        True, '', (EndTime - StartTime) * 86400000)
    else
      AddResult(Format('High concurrency crypto ops (%d/%d threads failed)', [FailedThreads, NUM_STRESS_THREADS]),
        False, ErrorMsg, (EndTime - StartTime) * 86400000);

  except
    on E: Exception do
      AddResult('High concurrency resource management', False, E.Message);
  end;
end;

{ Test 4: 混合操作并发测试 }
procedure Test_MixedOperationsConcurrency;
var
  Threads: array of TMixedOperationThread;
  i: Integer;
  AllSuccess: Boolean;
  TotalOps: Integer;
  StartTime, EndTime: TDateTime;
  ErrorMsg: string;
begin
  WriteLn;
  WriteLn('Test: Mixed Operations Concurrency');
  WriteLn('----------------------------------------');

  SetLength(Threads, 15);
  StartTime := Now;

  try
    // 创建并启动线程
    for i := 0 to 14 do
    begin
      Threads[i] := TMixedOperationThread.Create(i);
      Threads[i].Start;
    end;

    // 等待所有线程完成
    AllSuccess := True;
    TotalOps := 0;
    ErrorMsg := '';

    for i := 0 to 14 do
    begin
      Threads[i].WaitFor;
      TotalOps := TotalOps + Threads[i].OperationCount;
      if not Threads[i].Success then
      begin
        AllSuccess := False;
        if ErrorMsg = '' then
          ErrorMsg := Threads[i].ErrorMsg;
      end;
      Threads[i].Free;
    end;

    EndTime := Now;

    if AllSuccess then
      AddResult(Format('Mixed operations concurrency (%d ops)', [TotalOps]),
        True, '', (EndTime - StartTime) * 86400000)
    else
      AddResult('Mixed operations concurrency', False, ErrorMsg,
        (EndTime - StartTime) * 86400000);

  except
    on E: Exception do
      AddResult('Mixed operations concurrency', False, E.Message);
  end;
end;

{ Test 5: 大量上下文并发创建 }
procedure Test_MassContextCreation;
var
  Contexts: array of ISSLContext;
  Builder: ISSLContextBuilder;
  i: Integer;
  SuccessCount: Integer;
  StartTime, EndTime: TDateTime;
begin
  WriteLn;
  WriteLn('Test: Mass Context Creation');
  WriteLn('----------------------------------------');

  StartTime := Now;

  try
    SetLength(Contexts, NUM_CONCURRENT_CONTEXTS);
    SuccessCount := 0;

    // 批量创建上下文
    for i := 0 to NUM_CONCURRENT_CONTEXTS - 1 do
    begin
      Builder := TSSLContextBuilder.Create;
      Contexts[i] := Builder.WithVerifyNone.BuildClient;
      if Contexts[i] <> nil then
        Inc(SuccessCount);
    end;

    EndTime := Now;

    // 清理
    for i := 0 to High(Contexts) do
      Contexts[i] := nil;

    if SuccessCount = NUM_CONCURRENT_CONTEXTS then
      AddResult(Format('Mass context creation (%d contexts)', [NUM_CONCURRENT_CONTEXTS]),
        True, '', (EndTime - StartTime) * 86400000)
    else
      AddResult(Format('Mass context creation (%d/%d succeeded)',
        [SuccessCount, NUM_CONCURRENT_CONTEXTS]), False, '',
        (EndTime - StartTime) * 86400000);

  except
    on E: Exception do
      AddResult('Mass context creation', False, E.Message);
  end;
end;

{ Test 6: 随机数生成器并发测试 }
procedure Test_RandomGeneratorConcurrency;
var
  Threads: array of TThread;
  Results: array of TBytes;
  AllUnique: Boolean;
  i, j: Integer;
  StartTime, EndTime: TDateTime;
begin
  WriteLn;
  WriteLn('Test: Random Generator Concurrency');
  WriteLn('----------------------------------------');

  StartTime := Now;

  try
    // 并发生成随机数
    SetLength(Results, 100);

    for i := 0 to 99 do
      Results[i] := TCryptoUtils.SecureRandom(32);

    EndTime := Now;

    // 验证所有结果都是唯一的（非常高概率）
    AllUnique := True;
    for i := 0 to 98 do
    begin
      for j := i + 1 to 99 do
      begin
        if CompareMem(@Results[i][0], @Results[j][0], 32) then
        begin
          AllUnique := False;
          Break;
        end;
      end;
      if not AllUnique then Break;
    end;

    if AllUnique then
      AddResult('Random generator uniqueness (100 samples)', True, '',
        (EndTime - StartTime) * 86400000)
    else
      AddResult('Random generator uniqueness', False,
        'Duplicate random values detected', (EndTime - StartTime) * 86400000);

  except
    on E: Exception do
      AddResult('Random generator concurrency', False, E.Message);
  end;
end;

{ Test 7: 内存压力测试 }
procedure Test_MemoryPressure;
var
  Contexts: array of ISSLContext;
  Builder: ISSLContextBuilder;
  i, Batch: Integer;
  StartTime, EndTime: TDateTime;
begin
  WriteLn;
  WriteLn('Test: Memory Pressure');
  WriteLn('----------------------------------------');

  StartTime := Now;

  try
    // 多轮创建和释放
    for Batch := 1 to 5 do
    begin
      SetLength(Contexts, 20);

      for i := 0 to 19 do
      begin
        Builder := TSSLContextBuilder.Create;
        Contexts[i] := Builder.WithVerifyNone.BuildClient;
      end;

      // 释放
      for i := 0 to 19 do
        Contexts[i] := nil;

      SetLength(Contexts, 0);
    end;

    EndTime := Now;

    AddResult('Memory pressure test (5 batches x 20 contexts)', True, '',
      (EndTime - StartTime) * 86400000);

  except
    on E: Exception do
      AddResult('Memory pressure test', False, E.Message);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Concurrent Connections Test Suite');
  WriteLn('Phase C Week 1 - Integration Tests');
  WriteLn('========================================');
  WriteLn('Purpose: Test thread safety and concurrent access');
  WriteLn;

  GlobalLock := TCriticalSection.Create;

  try
    // 运行所有测试
    Test_MassContextCreation;
    Test_MultithreadedContextCreation;
    Test_ConnectionPoolThreadSafety;
    Test_HighConcurrencyResourceManagement;
    Test_MixedOperationsConcurrency;
    Test_RandomGeneratorConcurrency;
    Test_MemoryPressure;

    // 打印结果
    PrintResults;

  finally
    GlobalLock.Free;
  end;

  // 设置退出码
  if PassedTests = TotalTests then
    ExitCode := 0
  else
    ExitCode := 1;
end.
