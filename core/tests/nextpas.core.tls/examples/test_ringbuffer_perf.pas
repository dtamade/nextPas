program test_ringbuffer_perf;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  nextpas.core.tls.ringbuffer;

const
  TEST_SIZE = 1024 * 1024 * 10;  // 10MB
  CHUNK_SIZE = 4096;              // 4KB chunks

procedure TestDynamicArray;
var
  Buffer: TBytes;
  WriteData, ReadData: array[0..CHUNK_SIZE-1] of Byte;
  StartTime, EndTime: TDateTime;
  i, Written, Read: Integer;
  TotalWritten, TotalRead: Integer;
begin
  WriteLn('=== Dynamic Array Test ===');
  
  // Initialize
  SetLength(Buffer, 0);
  for i := 0 to CHUNK_SIZE-1 do
    WriteData[i] := Byte(i mod 256);
  
  StartTime := Now;
  TotalWritten := 0;
  
  // Write phase
  while TotalWritten < TEST_SIZE do
  begin
    // Simulate writing to dynamic array (with resizing)
    i := Length(Buffer);
    SetLength(Buffer, i + CHUNK_SIZE);
    Move(WriteData[0], Buffer[i], CHUNK_SIZE);
    Inc(TotalWritten, CHUNK_SIZE);
  end;
  
  // Read phase
  TotalRead := 0;
  while TotalRead < TEST_SIZE do
  begin
    // Simulate reading from dynamic array
    Move(Buffer[TotalRead], ReadData[0], CHUNK_SIZE);
    Inc(TotalRead, CHUNK_SIZE);
    
    // Simulate removing read data (expensive!)
    if TotalRead < Length(Buffer) then
    begin
      Move(Buffer[TotalRead], Buffer[0], Length(Buffer) - TotalRead);
      SetLength(Buffer, Length(Buffer) - TotalRead);
      TotalRead := 0;
    end;
  end;
  
  EndTime := Now;
  
  WriteLn('Time: ', MilliSecondsBetween(EndTime, StartTime), ' ms');
  WriteLn('Throughput: ', FormatFloat('0.##', 
    (TEST_SIZE / 1024.0 / 1024.0) / (MilliSecondsBetween(EndTime, StartTime) / 1000.0)), ' MB/s');
end;

procedure TestRingBuffer;
var
  Buffer: TRingBuffer;
  WriteData, ReadData: array[0..CHUNK_SIZE-1] of Byte;
  StartTime, EndTime: TDateTime;
  i, Written, Read: Integer;
  TotalWritten, TotalRead: Integer;
begin
  WriteLn('=== Ring Buffer Test ===');
  
  // Initialize - 1MB buffer
  Buffer := TRingBuffer.Create(20); // 2^20 = 1MB
  try
    for i := 0 to CHUNK_SIZE-1 do
      WriteData[i] := Byte(i mod 256);
    
    StartTime := Now;
    TotalWritten := 0;
    TotalRead := 0;
    
    // Interleaved read/write (more realistic)
    while (TotalWritten < TEST_SIZE) or (TotalRead < TEST_SIZE) do
    begin
      // Write if there's space and more to write
      if (TotalWritten < TEST_SIZE) and (Buffer.FreeSpace >= CHUNK_SIZE) then
      begin
        Written := Buffer.Write(WriteData, CHUNK_SIZE);
        Inc(TotalWritten, Written);
      end;
      
      // Read if there's data available
      if Buffer.Available >= CHUNK_SIZE then
      begin
        Read := Buffer.Read(ReadData, CHUNK_SIZE);
        Inc(TotalRead, Read);
      end;
    end;
    
    EndTime := Now;
    
    WriteLn('Time: ', MilliSecondsBetween(EndTime, StartTime), ' ms');
    WriteLn('Throughput: ', FormatFloat('0.##', 
      (TEST_SIZE / 1024.0 / 1024.0) / (MilliSecondsBetween(EndTime, StartTime) / 1000.0)), ' MB/s');
  finally
    Buffer.Free;
  end;
end;

procedure TestRingBufferZeroCopy;
var
  Buffer: TRingBuffer;
  WriteData: array[0..CHUNK_SIZE-1] of Byte;
  StartTime, EndTime: TDateTime;
  i: Integer;
  TotalWritten, TotalRead: Integer;
  ReadPtr: PByte;
  ReadSize: Integer;
begin
  WriteLn('=== Ring Buffer Zero-Copy Test ===');
  
  // Initialize - 1MB buffer
  Buffer := TRingBuffer.Create(20); // 2^20 = 1MB
  try
    for i := 0 to CHUNK_SIZE-1 do
      WriteData[i] := Byte(i mod 256);
    
    StartTime := Now;
    TotalWritten := 0;
    TotalRead := 0;
    
    // Interleaved read/write with zero-copy
    while (TotalWritten < TEST_SIZE) or (TotalRead < TEST_SIZE) do
    begin
      // Write if there's space
      if (TotalWritten < TEST_SIZE) and (Buffer.FreeSpace >= CHUNK_SIZE) then
      begin
        Buffer.Write(WriteData, CHUNK_SIZE);
        Inc(TotalWritten, CHUNK_SIZE);
      end;
      
      // Zero-copy read
      Buffer.GetReadBuffer(ReadPtr, ReadSize);
      if ReadSize > 0 then
      begin
        // Process data without copying (just simulate)
        // In real use, you'd process ReadPtr directly
        if ReadSize > CHUNK_SIZE then
          ReadSize := CHUNK_SIZE;
        
        Buffer.ConfirmRead(ReadSize);
        Inc(TotalRead, ReadSize);
      end;
    end;
    
    EndTime := Now;
    
    WriteLn('Time: ', MilliSecondsBetween(EndTime, StartTime), ' ms');
    WriteLn('Throughput: ', FormatFloat('0.##', 
      (TEST_SIZE / 1024.0 / 1024.0) / (MilliSecondsBetween(EndTime, StartTime) / 1000.0)), ' MB/s');
  finally
    Buffer.Free;
  end;
end;

procedure TestMemoryCopy;
var
  Source, Dest: array[0..TEST_SIZE-1] of Byte;
  StartTime, EndTime: TDateTime;
  i: Integer;
begin
  WriteLn('=== Baseline: Raw Memory Copy ===');
  
  // Initialize source
  for i := 0 to TEST_SIZE-1 do
    Source[i] := Byte(i mod 256);
  
  StartTime := Now;
  
  // Single large copy
  Move(Source[0], Dest[0], TEST_SIZE);
  
  EndTime := Now;
  
  WriteLn('Time: ', MilliSecondsBetween(EndTime, StartTime), ' ms');
  WriteLn('Throughput: ', FormatFloat('0.##', 
    (TEST_SIZE / 1024.0 / 1024.0) / (MilliSecondsBetween(EndTime, StartTime) / 1000.0)), ' MB/s');
end;

begin
  WriteLn('=== Performance Comparison Test ===');
  WriteLn('Test data size: ', TEST_SIZE div 1024 div 1024, ' MB');
  WriteLn('Chunk size: ', CHUNK_SIZE, ' bytes');
  WriteLn;
  
  try
    TestMemoryCopy;
    WriteLn;
    
    TestRingBuffer;
    WriteLn;
    
    TestRingBufferZeroCopy;
    WriteLn;
    
    // Dynamic array test is very slow for large data
    if TEST_SIZE <= 1024 * 1024 then
      TestDynamicArray
    else
      WriteLn('=== Dynamic Array Test skipped (too slow for large data) ===');
    
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
  
  WriteLn;
  WriteLn('=== Test Complete ===');
end.