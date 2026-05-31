{******************************************************************************}
{  Lock-Free Ring Buffer Test                                                  }
{******************************************************************************}

program test_ringbuffer_lockfree;

{$mode objfpc}{$H+}
{$UNITPATH framework}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.ringbuffer.lockfree,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  test_openssl_base;

const
  TEST_BUFFER_SIZE = 16; // 2^16 = 64KB

var
  Runner: TSimpleTestRunner;
  Buffer: TLockFreeRingBuffer;

procedure TestBasicWrite;
var
  Data: array[0..99] of Byte;
  Written: Integer;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== Basic Write ===');

  Buffer := TLockFreeRingBuffer.Create(TEST_BUFFER_SIZE);
  try
    // Fill test data
    for I := 0 to 99 do
      Data[I] := I;

    Written := Buffer.TryWrite(Data, 100);
    Runner.Check('Write 100 bytes', Written = 100);
    Runner.Check('Available after write', Buffer.GetAvailable = 100);
    Runner.Check('Write space decreased', Buffer.GetWriteSpace < Buffer.Capacity - 100);
  finally
    Buffer.Free;
  end;
end;

procedure TestBasicRead;
var
  WriteData: array[0..99] of Byte;
  ReadData: array[0..99] of Byte;
  Written, BytesRead: Integer;
  I: Integer;
  Match: Boolean;
begin
  WriteLn;
  WriteLn('=== Basic Read ===');

  Buffer := TLockFreeRingBuffer.Create(TEST_BUFFER_SIZE);
  try
    // Fill test data
    for I := 0 to 99 do
      WriteData[I] := I;

    Written := Buffer.TryWrite(WriteData, 100);
    Runner.Check('Write succeeded', Written = 100);

    FillChar(ReadData, 100, 0);
    BytesRead := Buffer.TryRead(ReadData, 100);
    Runner.Check('Read 100 bytes', BytesRead = 100);
    Runner.Check('Available after read', Buffer.GetAvailable = 0);

    // Verify data integrity
    Match := True;
    for I := 0 to 99 do
      if ReadData[I] <> WriteData[I] then
      begin
        Match := False;
        Break;
      end;
    Runner.Check('Data integrity', Match);
  finally
    Buffer.Free;
  end;
end;

procedure TestWrapAround;
var
  Data: array[0..511] of Byte;
  ReadBuf: array[0..511] of Byte;
  Written, BytesRead: Integer;
  I, Round: Integer;
  Match: Boolean;
begin
  WriteLn;
  WriteLn('=== Wrap-Around ===');

  // Use small buffer to force wrap-around
  Buffer := TLockFreeRingBuffer.Create(10); // 1024 bytes
  try
    for Round := 1 to 5 do
    begin
      // Fill test data
      for I := 0 to 511 do
        Data[I] := (Round * 10 + I) mod 256;

      Written := Buffer.TryWrite(Data, 512);
      Runner.Check(Format('Round %d: Write 512 bytes', [Round]), Written = 512);

      FillChar(ReadBuf, 512, 0);
      BytesRead := Buffer.TryRead(ReadBuf, 512);
      Runner.Check(Format('Round %d: Read 512 bytes', [Round]), BytesRead = 512);

      // Verify data
      Match := True;
      for I := 0 to 511 do
        if ReadBuf[I] <> Data[I] then
        begin
          Match := False;
          Break;
        end;
      Runner.Check(Format('Round %d: Data integrity', [Round]), Match);
    end;
  finally
    Buffer.Free;
  end;
end;

procedure TestPeek;
var
  Data: array[0..99] of Byte;
  PeekBuf: array[0..49] of Byte;
  Written, Peeked: Integer;
  I: Integer;
  Match: Boolean;
begin
  WriteLn;
  WriteLn('=== Peek ===');

  Buffer := TLockFreeRingBuffer.Create(TEST_BUFFER_SIZE);
  try
    for I := 0 to 99 do
      Data[I] := I;

    Written := Buffer.TryWrite(Data, 100);
    Runner.Check('Write succeeded', Written = 100);

    // Peek first 50 bytes
    FillChar(PeekBuf, 50, 0);
    Peeked := Buffer.TryPeek(PeekBuf, 50, 0);
    Runner.Check('Peek 50 bytes', Peeked = 50);
    Runner.Check('Available unchanged after peek', Buffer.GetAvailable = 100);

    Match := True;
    for I := 0 to 49 do
      if PeekBuf[I] <> Data[I] then
      begin
        Match := False;
        Break;
      end;
    Runner.Check('Peek data matches', Match);

    // Peek with offset
    FillChar(PeekBuf, 50, 0);
    Peeked := Buffer.TryPeek(PeekBuf, 50, 25);
    Runner.Check('Peek with offset', Peeked = 50);

    Match := True;
    for I := 0 to 49 do
      if PeekBuf[I] <> Data[I + 25] then
      begin
        Match := False;
        Break;
      end;
    Runner.Check('Offset peek data matches', Match);
  finally
    Buffer.Free;
  end;
end;

procedure TestSkip;
var
  Data: array[0..99] of Byte;
  ReadBuf: array[0..49] of Byte;
  Written, Skipped, BytesRead: Integer;
  I: Integer;
  Match: Boolean;
begin
  WriteLn;
  WriteLn('=== Skip ===');

  Buffer := TLockFreeRingBuffer.Create(TEST_BUFFER_SIZE);
  try
    for I := 0 to 99 do
      Data[I] := I;

    Written := Buffer.TryWrite(Data, 100);
    Runner.Check('Write succeeded', Written = 100);

    Skipped := Buffer.TrySkip(25);
    Runner.Check('Skip 25 bytes', Skipped = 25);
    Runner.Check('Available after skip', Buffer.GetAvailable = 75);

    // Read remaining data
    FillChar(ReadBuf, 50, 0);
    BytesRead := Buffer.TryRead(ReadBuf, 50);
    Runner.Check('Read after skip', BytesRead = 50);

    Match := True;
    for I := 0 to 49 do
      if ReadBuf[I] <> Data[I + 25] then
      begin
        Match := False;
        Break;
      end;
    Runner.Check('Data after skip correct', Match);
  finally
    Buffer.Free;
  end;
end;

procedure TestZeroCopy;
var
  Data: array[0..255] of Byte;
  WritePtr, ReadPtr: PByte;
  WriteSize, ReadSize: Integer;
  I: Integer;
  Match: Boolean;
begin
  WriteLn;
  WriteLn('=== Zero-Copy Interface ===');

  Buffer := TLockFreeRingBuffer.Create(TEST_BUFFER_SIZE);
  try
    for I := 0 to 255 do
      Data[I] := I;

    // Get write buffer
    Buffer.GetWriteBuffer(WritePtr, WriteSize);
    Runner.Check('Get write buffer', WritePtr <> nil);
    Runner.Check('Write buffer size > 0', WriteSize > 0);

    // Copy directly to buffer
    if WriteSize >= 256 then
    begin
      Move(Data[0], WritePtr^, 256);
      Buffer.CommitWrite(256);
      Runner.Check('Commit write', Buffer.GetAvailable = 256);
    end;

    // Get read buffer
    Buffer.GetReadBuffer(ReadPtr, ReadSize);
    Runner.Check('Get read buffer', ReadPtr <> nil);
    Runner.Check('Read buffer size', ReadSize = 256);

    // Verify data directly
    Match := True;
    for I := 0 to 255 do
      if ReadPtr[I] <> Data[I] then
      begin
        Match := False;
        Break;
      end;
    Runner.Check('Zero-copy data integrity', Match);

    Buffer.CommitRead(256);
    Runner.Check('Commit read', Buffer.GetAvailable = 0);
  finally
    Buffer.Free;
  end;
end;

procedure TestBufferFull;
var
  Data: array[0..1023] of Byte;
  Written: Integer;
begin
  WriteLn;
  WriteLn('=== Buffer Full ===');

  // Small buffer - 1024 bytes
  Buffer := TLockFreeRingBuffer.Create(10);
  try
    FillChar(Data, 1024, $AA);

    // Fill the buffer (leave one slot empty for SPSC protocol)
    Written := Buffer.TryWrite(Data, 1024);
    Runner.Check('Write to fill buffer', Written = 1023); // 1023 because one slot reserved

    // Try to write more - should fail
    Written := Buffer.TryWrite(Data, 100);
    Runner.Check('Write to full buffer', Written = 0);
  finally
    Buffer.Free;
  end;
end;

procedure TestReset;
var
  Data: array[0..99] of Byte;
  Written: Integer;
begin
  WriteLn;
  WriteLn('=== Reset ===');

  Buffer := TLockFreeRingBuffer.Create(TEST_BUFFER_SIZE);
  try
    FillChar(Data, 100, $BB);

    Written := Buffer.TryWrite(Data, 100);
    Runner.Check('Write before reset', Written = 100);
    Runner.Check('Available before reset', Buffer.GetAvailable = 100);

    Buffer.Reset;
    Runner.Check('Available after reset', Buffer.GetAvailable = 0);
    Runner.Check('Size after reset', Buffer.Size = 0);
  finally
    Buffer.Free;
  end;
end;

begin
  WriteLn('Lock-Free Ring Buffer Tests');
  WriteLn('============================');

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    TestBasicWrite;
    TestBasicRead;
    TestWrapAround;
    TestPeek;
    TestSkip;
    TestZeroCopy;
    TestBufferFull;
    TestReset;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
