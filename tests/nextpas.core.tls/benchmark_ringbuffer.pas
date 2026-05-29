{******************************************************************************}
{  Ring Buffer Performance Benchmark                                           }
{  Compares locking vs lock-free implementations                               }
{******************************************************************************}

program benchmark_ringbuffer;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes, DateUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.ringbuffer,
  nextpas.core.tls.ringbuffer.lockfree;

const
  BUFFER_SIZE_POW2 = 16;  // 64KB buffer
  ITERATIONS = 1000000;
  CHUNK_SIZE = 256;

var
  TestData: array[0..CHUNK_SIZE-1] of Byte;
  ReadBuf: array[0..CHUNK_SIZE-1] of Byte;

procedure InitTestData;
var
  I: Integer;
begin
  for I := 0 to CHUNK_SIZE - 1 do
    TestData[I] := I mod 256;
end;

function BenchmarkLocking: Int64;
var
  Buffer: TLockFreeRingBuffer;
  I: Integer;
  StartTime: TDateTime;
begin
  Buffer := TLockFreeRingBuffer.Create(BUFFER_SIZE_POW2);
  try
    StartTime := Now;

    for I := 1 to ITERATIONS do
    begin
      Buffer.TryWrite(TestData, CHUNK_SIZE);
      Buffer.TryRead(ReadBuf, CHUNK_SIZE);
    end;

    Result := MilliSecondsBetween(Now, StartTime);
  finally
    Buffer.Free;
  end;
end;

function BenchmarkLockFree: Int64;
var
  Buffer: TLockFreeRingBuffer;
  I: Integer;
  StartTime: TDateTime;
begin
  Buffer := TLockFreeRingBuffer.Create(BUFFER_SIZE_POW2);
  try
    StartTime := Now;

    for I := 1 to ITERATIONS do
    begin
      Buffer.TryWrite(TestData, CHUNK_SIZE);
      Buffer.TryRead(ReadBuf, CHUNK_SIZE);
    end;

    Result := MilliSecondsBetween(Now, StartTime);
  finally
    Buffer.Free;
  end;
end;

function BenchmarkLockingZeroCopy: Int64;
var
  Buffer: TLockFreeRingBuffer;
  I: Integer;
  StartTime: TDateTime;
  WritePtr, ReadPtr: PByte;
  WriteSize, ReadSize: Integer;
begin
  Buffer := TLockFreeRingBuffer.Create(BUFFER_SIZE_POW2);
  try
    StartTime := Now;

    for I := 1 to ITERATIONS do
    begin
      Buffer.GetWriteBuffer(WritePtr, WriteSize);
      if (WritePtr <> nil) and (WriteSize >= CHUNK_SIZE) then
      begin
        Move(TestData[0], WritePtr^, CHUNK_SIZE);
        Buffer.CommitWrite(CHUNK_SIZE);
      end;

      Buffer.GetReadBuffer(ReadPtr, ReadSize);
      if (ReadPtr <> nil) and (ReadSize >= CHUNK_SIZE) then
      begin
        Move(ReadPtr^, ReadBuf[0], CHUNK_SIZE);
        Buffer.CommitRead(CHUNK_SIZE);
      end;
    end;

    Result := MilliSecondsBetween(Now, StartTime);
  finally
    Buffer.Free;
  end;
end;

function BenchmarkLockFreeZeroCopy: Int64;
var
  Buffer: TLockFreeRingBuffer;
  I: Integer;
  StartTime: TDateTime;
  WritePtr, ReadPtr: PByte;
  WriteSize, ReadSize: Integer;
begin
  Buffer := TLockFreeRingBuffer.Create(BUFFER_SIZE_POW2);
  try
    StartTime := Now;

    for I := 1 to ITERATIONS do
    begin
      Buffer.GetWriteBuffer(WritePtr, WriteSize);
      if (WritePtr <> nil) and (WriteSize >= CHUNK_SIZE) then
      begin
        Move(TestData[0], WritePtr^, CHUNK_SIZE);
        Buffer.CommitWrite(CHUNK_SIZE);
      end;

      Buffer.GetReadBuffer(ReadPtr, ReadSize);
      if (ReadPtr <> nil) and (ReadSize >= CHUNK_SIZE) then
      begin
        Move(ReadPtr^, ReadBuf[0], CHUNK_SIZE);
        Buffer.CommitRead(CHUNK_SIZE);
      end;
    end;

    Result := MilliSecondsBetween(Now, StartTime);
  finally
    Buffer.Free;
  end;
end;

var
  LockingTime, LockFreeTime: Int64;
  LockingZCTime, LockFreeZCTime: Int64;
  Speedup: Double;
begin
  WriteLn('Ring Buffer Performance Benchmark');
  WriteLn('==================================');
  WriteLn;
  WriteLn(Format('Buffer size: %d KB', [1 shl BUFFER_SIZE_POW2 div 1024]));
  WriteLn(Format('Iterations: %d', [ITERATIONS]));
  WriteLn(Format('Chunk size: %d bytes', [CHUNK_SIZE]));
  WriteLn(Format('Total data: %d MB', [Int64(ITERATIONS) * CHUNK_SIZE * 2 div 1024 div 1024]));
  WriteLn;

  InitTestData;

  // Warm up
  WriteLn('Warming up...');
  BenchmarkLocking;
  BenchmarkLockFree;

  WriteLn;
  WriteLn('=== Standard Interface (Write/Read) ===');

  Write('Locking version:   ');
  LockingTime := BenchmarkLocking;
  WriteLn(Format('%d ms', [LockingTime]));

  Write('Lock-free version: ');
  LockFreeTime := BenchmarkLockFree;
  WriteLn(Format('%d ms', [LockFreeTime]));

  if LockFreeTime > 0 then
    Speedup := LockingTime / LockFreeTime
  else
    Speedup := 0;

  WriteLn(Format('Speedup: %.2fx', [Speedup]));

  WriteLn;
  WriteLn('=== Zero-Copy Interface ===');

  Write('Locking version:   ');
  LockingZCTime := BenchmarkLockingZeroCopy;
  WriteLn(Format('%d ms', [LockingZCTime]));

  Write('Lock-free version: ');
  LockFreeZCTime := BenchmarkLockFreeZeroCopy;
  WriteLn(Format('%d ms', [LockFreeZCTime]));

  if LockFreeZCTime > 0 then
    Speedup := LockingZCTime / LockFreeZCTime
  else
    Speedup := 0;

  WriteLn(Format('Speedup: %.2fx', [Speedup]));

  WriteLn;
  WriteLn('=== Throughput ===');

  if LockingTime > 0 then
    WriteLn(Format('Locking (standard):    %.2f MB/s', [
      Int64(ITERATIONS) * CHUNK_SIZE * 2 / 1024 / 1024 / (LockingTime / 1000)]));

  if LockFreeTime > 0 then
    WriteLn(Format('Lock-free (standard):  %.2f MB/s', [
      Int64(ITERATIONS) * CHUNK_SIZE * 2 / 1024 / 1024 / (LockFreeTime / 1000)]));

  if LockingZCTime > 0 then
    WriteLn(Format('Locking (zero-copy):   %.2f MB/s', [
      Int64(ITERATIONS) * CHUNK_SIZE * 2 / 1024 / 1024 / (LockingZCTime / 1000)]));

  if LockFreeZCTime > 0 then
    WriteLn(Format('Lock-free (zero-copy): %.2f MB/s', [
      Int64(ITERATIONS) * CHUNK_SIZE * 2 / 1024 / 1024 / (LockFreeZCTime / 1000)]));

  WriteLn;
  WriteLn('Benchmark complete.');
end.
