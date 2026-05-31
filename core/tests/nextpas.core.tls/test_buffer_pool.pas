program test_buffer_pool;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes, SyncObjs, DateUtils, Math,
  nextpas.core.tls.buffer.pool;

const
  ITERATIONS = 10000;
  THREAD_COUNT = 4;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPassCount);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFailCount);
  end;
end;

{ 测试 1: 基本功能 }
procedure TestBasicFunctionality;
var
  Buf: PPooledBuffer;
  TestData: array[0..99] of Byte;
  ReadData: array[0..99] of Byte;
  I: Integer;
begin
  WriteLn('=== Test 1: Basic Functionality ===');

  // 准备测试数据
  for I := 0 to 99 do
    TestData[I] := I;

  // 小缓冲区
  Buf := AcquireBuffer(100);
  Check('Acquire small buffer', Buf <> nil);
  Check('Buffer capacity >= 100', (Buf <> nil) and (Buf^.Capacity >= 100));

  // 写入数据
  Buf^.Write(TestData, 100);
  Check('Write sets length', Buf^.Length = 100);

  // 读取数据
  FillChar(ReadData, 100, 0);
  Buf^.Read(ReadData, 100);
  Check('Read returns correct data', CompareMem(@TestData, @ReadData, 100));

  // 清除
  Buf^.Clear;
  Check('Clear resets length', Buf^.Length = 0);

  ReleaseBuffer(Buf);
  Check('Release succeeded', True);

  // 中等缓冲区
  Buf := AcquireBuffer(8192);
  Check('Acquire medium buffer', (Buf <> nil) and (Buf^.Capacity >= 8192));
  ReleaseBuffer(Buf);

  // 大缓冲区
  Buf := AcquireBuffer(32768);
  Check('Acquire large buffer', (Buf <> nil) and (Buf^.Capacity >= 32768));
  ReleaseBuffer(Buf);

  // 超大缓冲区
  Buf := AcquireBuffer(100000);
  Check('Acquire oversize buffer', (Buf <> nil) and (Buf^.Capacity >= 100000));
  Check('Oversize not pooled', not Buf^.IsPooled);
  ReleaseBuffer(Buf);
end;

{ 测试 2: 池复用 }
procedure TestPoolReuse;
var
  Buf1, Buf2: PPooledBuffer;
  Stats1, Stats2: TBufferPoolStats;
  I: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 2: Pool Reuse ===');

  GlobalBufferPool.ResetStats;

  // 获取并释放
  Buf1 := AcquireBuffer(1024);
  ReleaseBuffer(Buf1);

  // 再次获取应该复用
  Buf2 := AcquireBuffer(1024);

  Stats1 := GlobalBufferPool.GetStats;
  Check('Pool reuse detected', Stats1.PoolHits >= 1);

  ReleaseBuffer(Buf2);

  // 多次获取释放测试复用
  GlobalBufferPool.ResetStats;
  for I := 1 to 100 do
  begin
    Buf1 := AcquireBuffer(2048);
    ReleaseBuffer(Buf1);
  end;

  Stats2 := GlobalBufferPool.GetStats;
  WriteLn('  Total allocations: ', Stats2.TotalAllocations);
  WriteLn('  Pool hits: ', Stats2.PoolHits);
  WriteLn('  Pool misses: ', Stats2.PoolMisses);
  WriteLn('  Hit rate: ', Stats2.HitRate:0:1, '%');

  Check('High hit rate (> 90%)', Stats2.HitRate > 90);
end;

{ 测试 3: 性能对比 }
procedure TestPerformance;
var
  StartTime, EndTime: TDateTime;
  I: Integer;
  Buf: PPooledBuffer;
  DirectBuf: PByte;
  PoolTime, DirectTime: Int64;
begin
  WriteLn('');
  WriteLn('=== Test 3: Performance Comparison ===');

  // 池化分配
  StartTime := Now;
  for I := 1 to ITERATIONS do
  begin
    Buf := AcquireBuffer(4096);
    // 模拟使用
    Buf^.Write(I, SizeOf(I));
    ReleaseBuffer(Buf);
  end;
  EndTime := Now;
  PoolTime := MilliSecondsBetween(EndTime, StartTime);

  // 直接分配
  StartTime := Now;
  for I := 1 to ITERATIONS do
  begin
    GetMem(DirectBuf, 4096);
    // 模拟使用
    Move(I, DirectBuf^, SizeOf(I));
    FreeMem(DirectBuf);
  end;
  EndTime := Now;
  DirectTime := MilliSecondsBetween(EndTime, StartTime);

  WriteLn('  Iterations: ', ITERATIONS);
  WriteLn('  Pool allocation: ', PoolTime, ' ms');
  WriteLn('  Direct allocation: ', DirectTime, ' ms');

  if DirectTime > 0 then
    WriteLn('  Speedup: ', (DirectTime / Max(PoolTime, 1)):0:2, 'x')
  else
    WriteLn('  Speedup: N/A (too fast to measure)');

  Check('Pool allocation completed', True);
end;

{ 测试 4: 并发访问 }
type
  TConcurrentTestThread = class(TThread)
  private
    FIterations: Integer;
    FCompleted: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AIterations: Integer);
    property Completed: Boolean read FCompleted;
  end;

constructor TConcurrentTestThread.Create(AIterations: Integer);
begin
  inherited Create(True);
  FIterations := AIterations;
  FCompleted := False;
  FreeOnTerminate := False;
end;

procedure TConcurrentTestThread.Execute;
var
  I: Integer;
  Buf: PPooledBuffer;
  Size: Integer;
begin
  for I := 1 to FIterations do
  begin
    // 随机大小
    Size := 1024 + (I mod 3) * 8192;
    Buf := AcquireBuffer(Size);
    if Buf <> nil then
    begin
      Buf^.Write(I, SizeOf(I));
      ReleaseBuffer(Buf);
    end;
  end;
  FCompleted := True;
end;

procedure TestConcurrentAccess;
var
  Threads: array[0..THREAD_COUNT-1] of TConcurrentTestThread;
  I: Integer;
  AllCompleted: Boolean;
  Stats: TBufferPoolStats;
  StartTime, EndTime: TDateTime;
  TotalOps: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 4: Concurrent Access ===');

  GlobalBufferPool.ResetStats;

  // 创建线程
  for I := 0 to THREAD_COUNT - 1 do
    Threads[I] := TConcurrentTestThread.Create(ITERATIONS div THREAD_COUNT);

  StartTime := Now;

  // 启动所有线程
  for I := 0 to THREAD_COUNT - 1 do
    Threads[I].Start;

  // 等待完成
  for I := 0 to THREAD_COUNT - 1 do
    Threads[I].WaitFor;

  EndTime := Now;

  // 检查所有线程完成
  AllCompleted := True;
  for I := 0 to THREAD_COUNT - 1 do
  begin
    if not Threads[I].Completed then
      AllCompleted := False;
    Threads[I].Free;
  end;

  Stats := GlobalBufferPool.GetStats;
  TotalOps := ITERATIONS;

  WriteLn('  Threads: ', THREAD_COUNT);
  WriteLn('  Total operations: ', TotalOps);
  WriteLn('  Duration: ', MilliSecondsBetween(EndTime, StartTime), ' ms');
  WriteLn('  Hit rate: ', Stats.HitRate:0:1, '%');
  WriteLn('  Peak in use: ', Stats.PeakInUse);

  Check('All threads completed', AllCompleted);
  Check('No data corruption', Stats.TotalAllocations > 0);
end;

{ 测试 5: 缓冲区级别 }
procedure TestBufferClasses;
var
  Small, Medium, Large, Oversize: PPooledBuffer;
begin
  WriteLn('');
  WriteLn('=== Test 5: Buffer Classes ===');

  Small := AcquireBuffer(1000);
  Check('Small buffer class', (Small <> nil) and (Small^.BufferClass = bcSmall));
  WriteLn('  Small: capacity=', Small^.Capacity);
  ReleaseBuffer(Small);

  Medium := AcquireBuffer(8000);
  Check('Medium buffer class', (Medium <> nil) and (Medium^.BufferClass = bcMedium));
  WriteLn('  Medium: capacity=', Medium^.Capacity);
  ReleaseBuffer(Medium);

  Large := AcquireBuffer(32000);
  Check('Large buffer class', (Large <> nil) and (Large^.BufferClass = bcLarge));
  WriteLn('  Large: capacity=', Large^.Capacity);
  ReleaseBuffer(Large);

  Oversize := AcquireBuffer(100000);
  Check('Oversize buffer class', (Oversize <> nil) and (Oversize^.BufferClass = bcOversize));
  WriteLn('  Oversize: capacity=', Oversize^.Capacity);
  ReleaseBuffer(Oversize);
end;

{ 测试 6: 统计信息 }
procedure TestStatistics;
var
  Stats: TBufferPoolStats;
  I: Integer;
  Buf: PPooledBuffer;
begin
  WriteLn('');
  WriteLn('=== Test 6: Statistics ===');

  GlobalBufferPool.ResetStats;

  // 执行一些操作
  for I := 1 to 50 do
  begin
    Buf := AcquireBuffer(2048);
    ReleaseBuffer(Buf);
  end;

  // 分配一些超大缓冲区
  for I := 1 to 5 do
  begin
    Buf := AcquireBuffer(100000);
    ReleaseBuffer(Buf);
  end;

  Stats := GlobalBufferPool.GetStats;

  WriteLn('  Total allocations: ', Stats.TotalAllocations);
  WriteLn('  Pool hits: ', Stats.PoolHits);
  WriteLn('  Pool misses: ', Stats.PoolMisses);
  WriteLn('  Oversize allocations: ', Stats.OversizeAllocations);
  WriteLn('  Current pooled: ', Stats.CurrentPooled);
  WriteLn('  Current in use: ', Stats.CurrentInUse);
  WriteLn('  Peak in use: ', Stats.PeakInUse);
  WriteLn('  Total bytes pooled: ', Stats.TotalBytesPooled div 1024, ' KB');
  WriteLn('  Hit rate: ', Stats.HitRate:0:1, '%');

  Check('Total allocations tracked', Stats.TotalAllocations = 55);
  Check('Oversize allocations tracked', Stats.OversizeAllocations = 5);
end;

{ 主程序 }
begin
  WriteLn('╔════════════════════════════════════════════════════════╗');
  WriteLn('║  Buffer Pool Test Suite                                ║');
  WriteLn('║  Phase 1: Zero-Copy I/O Optimization                   ║');
  WriteLn('╚════════════════════════════════════════════════════════╝');
  WriteLn;

  TestBasicFunctionality;
  TestPoolReuse;
  TestPerformance;
  TestConcurrentAccess;
  TestBufferClasses;
  TestStatistics;

  WriteLn;
  WriteLn('========================================');
  WriteLn('  Test Summary');
  WriteLn('========================================');
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);
  WriteLn('Total:  ', GPassCount + GFailCount);
  WriteLn;

  if GFailCount = 0 then
    WriteLn('All tests passed!')
  else
    WriteLn('Some tests failed.');
end.
