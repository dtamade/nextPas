program test_ringbuffer;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes, DateUtils,
  nextpas.core.tls.ringbuffer;

const
  ITERATIONS = 100000;

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

{ 测试 1: 基本读写 }
procedure TestBasicReadWrite;
var
  Ring: TLockFreeRingBuffer;
  WriteData: array[0..99] of Byte;
  ReadData: array[0..99] of Byte;
  I, Written, Read: Integer;
begin
  WriteLn('=== Test 1: Basic Read/Write ===');

  Ring := TLockFreeRingBuffer.Create(1024);
  try
    // 准备数据
    for I := 0 to 99 do
      WriteData[I] := I;

    Check('Initially empty', Ring.IsEmpty);
    Check('Not full initially', not Ring.IsFull);

    // 写入
    Written := Ring.Write(WriteData, 100);
    Check('Write returns 100', Written = 100);
    Check('Not empty after write', not Ring.IsEmpty);
    Check('Read available = 100', Ring.ReadAvailable = 100);

    // 读取
    FillChar(ReadData, 100, 0);
    Read := Ring.Read(ReadData, 100);
    Check('Read returns 100', Read = 100);
    Check('Empty after read', Ring.IsEmpty);
    Check('Data matches', CompareMem(@WriteData, @ReadData, 100));

  finally
    Ring.Free;
  end;
end;

{ 测试 2: 环绕写入 }
procedure TestWrapAround;
var
  Ring: TLockFreeRingBuffer;
  Data: array[0..63] of Byte;
  I: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 2: Wrap Around ===');

  // 小缓冲区测试环绕
  Ring := TLockFreeRingBuffer.Create(128);
  try
    for I := 0 to 63 do
      Data[I] := I;

    // 写入 64 字节
    Ring.Write(Data, 64);
    // 读取 32 字节
    Ring.Read(Data, 32);
    // 再写入 64 字节（会环绕）
    Ring.Write(Data, 64);

    Check('After wrap, read available = 96', Ring.ReadAvailable = 96);

    // 读取所有数据
    Ring.Read(Data, 64);
    Ring.Read(Data, 32);
    Check('Empty after full read', Ring.IsEmpty);

  finally
    Ring.Free;
  end;
end;

{ 测试 3: 边界条件 }
procedure TestBoundaryConditions;
var
  Ring: TLockFreeRingBuffer;
  Data: array[0..255] of Byte;
  Written: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 3: Boundary Conditions ===');

  Ring := TLockFreeRingBuffer.Create(256);
  try
    // 尝试写入超过容量
    Written := Ring.Write(Data, 300);
    Check('Write limited by capacity', Written < 300);
    Check('Overflow counted', Ring.Overflows = 1);

    // 读取全部
    Ring.Read(Data, 256);

    // 空缓冲区读取
    Written := Ring.Read(Data, 100);
    Check('Read from empty returns 0', Written = 0);

    // TryWrite 测试
    Check('TryWrite succeeds when space', Ring.TryWrite(Data, 100));
    Check('TryWrite fails when no space', not Ring.TryWrite(Data, 200));

  finally
    Ring.Free;
  end;
end;

{ 测试 4: Peek 和 Skip }
procedure TestPeekAndSkip;
var
  Ring: TLockFreeRingBuffer;
  Data: array[0..15] of Byte;
  PeekData: array[0..15] of Byte;
  I: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 4: Peek and Skip ===');

  Ring := TLockFreeRingBuffer.Create(1024);
  try
    // 准备数据
    for I := 0 to 15 do
      Data[I] := I * 10;

    Ring.Write(Data, 16);

    // Peek 不消费数据
    Ring.Peek(PeekData, 8);
    Check('Peek returns data', PeekData[0] = 0);
    Check('Peek does not consume', Ring.ReadAvailable = 16);

    // Skip 消费数据
    Ring.Skip(8);
    Check('Skip consumes data', Ring.ReadAvailable = 8);

    // 读取剩余
    Ring.Read(PeekData, 8);
    Check('Read after skip correct', PeekData[0] = 80);  // 第8个元素

  finally
    Ring.Free;
  end;
end;

{ 测试 5: 零拷贝操作 }
procedure TestZeroCopy;
var
  Ring: TLockFreeRingBuffer;
  WritePtr, ReadPtr: PByte;
  Available: Integer;
  I: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 5: Zero-Copy Operations ===');

  Ring := TLockFreeRingBuffer.Create(1024);
  try
    // 直接写入
    WritePtr := Ring.GetWritePtr(Available);
    Check('Write ptr available', Available > 0);

    // 写入数据
    for I := 0 to 99 do
      WritePtr[I] := I;
    Ring.CommitWrite(100);

    Check('After commit, readable', Ring.ReadAvailable = 100);

    // 直接读取
    ReadPtr := Ring.GetReadPtr(Available);
    Check('Read ptr available = 100', Available = 100);
    Check('Direct read correct', ReadPtr[50] = 50);

    Ring.CommitRead(100);
    Check('After commit read, empty', Ring.IsEmpty);

  finally
    Ring.Free;
  end;
end;

{ 测试 6: 性能测试 }
procedure TestPerformance;
var
  Ring: TLockFreeRingBuffer;
  Data: array[0..1023] of Byte;
  I: Integer;
  StartTime, EndTime: TDateTime;
  OpsPerSec: Double;
begin
  WriteLn('');
  WriteLn('=== Test 6: Performance ===');

  Ring := TLockFreeRingBuffer.Create(65536);
  try
    StartTime := Now;

    for I := 1 to ITERATIONS do
    begin
      Ring.Write(Data, 1024);
      Ring.Read(Data, 1024);
    end;

    EndTime := Now;

    OpsPerSec := (ITERATIONS * 2) / (MilliSecondsBetween(EndTime, StartTime) / 1000);

    WriteLn('  Iterations: ', ITERATIONS);
    WriteLn('  Duration: ', MilliSecondsBetween(EndTime, StartTime), ' ms');
    WriteLn('  Operations/sec: ', OpsPerSec:0:0);
    WriteLn('  Throughput: ', (ITERATIONS * 1024 * 2 / 1024 / 1024):0:2, ' MB/s');
    WriteLn('  Total written: ', Ring.TotalWritten);
    WriteLn('  Total read: ', Ring.TotalRead);

    Check('High throughput (> 1M ops/s)', OpsPerSec > 1000000);

  finally
    Ring.Free;
  end;
end;

{ 测试 7: SPSC 并发测试 }
type
  TProducerThread = class(TThread)
  private
    FRing: TLockFreeRingBuffer;
    FCount: Integer;
    FWritten: Int64;
  protected
    procedure Execute; override;
  public
    constructor Create(ARing: TLockFreeRingBuffer; ACount: Integer);
    property Written: Int64 read FWritten;
  end;

  TConsumerThread = class(TThread)
  private
    FRing: TLockFreeRingBuffer;
    FCount: Integer;
    FRead: Int64;
    FErrors: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(ARing: TLockFreeRingBuffer; ACount: Integer);
    property TotalRead: Int64 read FRead;
    property Errors: Integer read FErrors;
  end;

constructor TProducerThread.Create(ARing: TLockFreeRingBuffer; ACount: Integer);
begin
  inherited Create(True);
  FRing := ARing;
  FCount := ACount;
  FWritten := 0;
  FreeOnTerminate := False;
end;

procedure TProducerThread.Execute;
var
  I: Integer;
  Data: array[0..63] of Byte;
begin
  for I := 0 to 63 do
    Data[I] := I;

  I := 0;
  while I < FCount do
  begin
    // 使用 TryWrite 确保完整写入 64 字节
    if FRing.TryWrite(Data, 64) then
    begin
      Inc(FWritten, 64);
      Inc(I);
    end
    else
      Sleep(0);  // 让出 CPU
  end;
end;

constructor TConsumerThread.Create(ARing: TLockFreeRingBuffer; ACount: Integer);
begin
  inherited Create(True);
  FRing := ARing;
  FCount := ACount;
  FRead := 0;
  FErrors := 0;
  FreeOnTerminate := False;
end;

procedure TConsumerThread.Execute;
var
  J: Integer;
  Data: array[0..63] of Byte;
begin
  while FRead < Int64(FCount) * 64 do
  begin
    // 使用 TryRead 确保完整读取 64 字节
    if FRing.TryRead(Data, 64) then
    begin
      // 验证数据完整性
      for J := 0 to 63 do
      begin
        if Data[J] <> J then
        begin
          Inc(FErrors);
          Break;
        end;
      end;
      Inc(FRead, 64);
    end
    else
      Sleep(0);  // 让出 CPU
  end;
end;

procedure TestSPSCConcurrency;
var
  Ring: TLockFreeRingBuffer;
  Producer: TProducerThread;
  Consumer: TConsumerThread;
  StartTime, EndTime: TDateTime;
  Count: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 7: SPSC Concurrency ===');

  Count := ITERATIONS div 10;
  Ring := TLockFreeRingBuffer.Create(8192);
  try
    Producer := TProducerThread.Create(Ring, Count);
    Consumer := TConsumerThread.Create(Ring, Count);

    StartTime := Now;

    Producer.Start;
    Consumer.Start;

    Producer.WaitFor;
    Consumer.WaitFor;

    EndTime := Now;

    WriteLn('  Messages: ', Count);
    WriteLn('  Duration: ', MilliSecondsBetween(EndTime, StartTime), ' ms');
    WriteLn('  Producer written: ', Producer.Written);
    WriteLn('  Consumer read: ', Consumer.TotalRead);
    WriteLn('  Consumer errors: ', Consumer.Errors);

    Check('No data corruption', Consumer.Errors = 0);
    Check('All data transferred', Producer.Written = Consumer.TotalRead);

    Producer.Free;
    Consumer.Free;

  finally
    Ring.Free;
  end;
end;

{ 测试 8: TBytes 接口 }
procedure TestBytesInterface;
var
  Ring: TLockFreeRingBuffer;
  WriteBytes, ReadBytes: TBytes;
  I: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 8: TBytes Interface ===');

  Ring := TLockFreeRingBuffer.Create(1024);
  try
    // 准备数据
    SetLength(WriteBytes, 100);
    for I := 0 to 99 do
      WriteBytes[I] := I;

    // 写入
    Ring.WriteBytes(WriteBytes);
    Check('WriteBytes works', Ring.ReadAvailable = 100);

    // 读取
    ReadBytes := Ring.ReadBytes(100);
    Check('ReadBytes returns correct length', Length(ReadBytes) = 100);
    Check('ReadBytes data correct', ReadBytes[50] = 50);

  finally
    Ring.Free;
  end;
end;

{ 主程序 }
begin
  WriteLn('╔════════════════════════════════════════════════════════╗');
  WriteLn('║  Lock-Free Ring Buffer Test Suite                      ║');
  WriteLn('║  Phase 2: Lock-Free Concurrency Optimization           ║');
  WriteLn('╚════════════════════════════════════════════════════════╝');
  WriteLn;

  TestBasicReadWrite;
  TestWrapAround;
  TestBoundaryConditions;
  TestPeekAndSkip;
  TestZeroCopy;
  TestPerformance;
  TestSPSCConcurrency;
  TestBytesInterface;

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
