program test_async_vectored_io;
{$mode ObjFPC}{$H+}{$J-}

uses
  nextpas.core.text.conv,
  nextpas.core.base, nextpas.core.errors, nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.pipe,
  nextpas.core.io.uring, nextpas.core.io.reactor,
  nextpas.core.async.base, nextpas.core.async.loop;

const
  HEAPTRC_ACTIVE =
    {$IFDEF HEAPTRC_ACTIVE} True {$ELSE} False {$ENDIF};

type
  TIovecArray = array[0..7] of iovec;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GState: record
    Done: Boolean;
    Result: Int32;
  end;
  GInvalidFdCallbackFired: Boolean;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', ATestName);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAIL: ', ATestName);
  end;
end;

procedure ResetState;
begin
  GState.Done := False;
  GState.Result := 0;
end;

procedure IoCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GState.Result := AResult;
  GState.Done := True;
end;

procedure InvalidFdCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GInvalidFdCallbackFired := True;
end;

{ Test 1: AsyncWritev writes multiple buffers to pipe }
procedure TestAsyncWritevMultipleBuffers;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LBuf1, LBuf2, LBuf3: string;
  LIovecs: TIovecArray;
  LReadBuf: array[0..255] of Byte;
  LReadLen: ssize_t;
begin
  WriteLn('TestAsyncWritevMultipleBuffers:');
  LLoop := TAsyncLoop.Create;
  try
    Check(platform_pipe_create(LPipe) = 0, 'pipe created');
    try
      LBuf1 := 'Hello,';
      LBuf2 := ' World';
      LBuf3 := '!';
      ResetState;

      LIovecs[0].iov_base := @LBuf1[1];
      LIovecs[0].iov_len := Length(LBuf1);
      LIovecs[1].iov_base := @LBuf2[1];
      LIovecs[1].iov_len := Length(LBuf2);
      LIovecs[2].iov_base := @LBuf3[1];
      LIovecs[2].iov_len := Length(LBuf3);

      if LLoop.AsyncWritev(LPipe.WriteFd, @LIovecs[0], 3, 0, @IoCallback) then
      begin
        LLoop.RunOnce;
        if not GState.Done then
          LLoop.RunOnce;
      end;

      Check(GState.Done, 'writev callback fired');
      Check(GState.Result > 0, 'writev wrote bytes (got ' + IntToStr(GState.Result) + ')');

      FillChar(LReadBuf, SizeOf(LReadBuf), 0);
      LReadLen := nextpas.core.platform.posix.ffi.read(LPipe.ReadFd, @LReadBuf[0], SizeOf(LReadBuf));
      Check(LReadLen = Length(LBuf1) + Length(LBuf2) + Length(LBuf3),
        'read correct total length (' + IntToStr(LReadLen) + ')');
      Check(CompareMem(@LReadBuf[0], @LBuf1[1], Length(LBuf1)),
        'first buffer content matches');
      Check(CompareMem(@LReadBuf[Length(LBuf1)], @LBuf2[1], Length(LBuf2)),
        'second buffer content matches');
      Check(CompareMem(@LReadBuf[Length(LBuf1) + Length(LBuf2)], @LBuf3[1], Length(LBuf3)),
        'third buffer content matches');
    finally
      platform_pipe_close(LPipe);
    end;
  finally
    LLoop.Close;
    LLoop.Free;
  end;
end;

{ Test 2: AsyncReadv reads into multiple buffers }
procedure TestAsyncReadvMultipleBuffers;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LWriteData: string;
  LPart1, LPart2: array[0..4] of Byte;
  LIovecs: TIovecArray;
  LWritten: ssize_t;
begin
  WriteLn('TestAsyncReadvMultipleBuffers:');
  LLoop := TAsyncLoop.Create;
  try
    Check(platform_pipe_create(LPipe) = 0, 'pipe created');
    try
      LWriteData := 'HelloWorld';
      LWritten := nextpas.core.platform.posix.ffi.write(LPipe.WriteFd, @LWriteData[1], Length(LWriteData));
      Check(LWritten = 10, 'wrote 10 bytes to pipe');
      platform_pipe_close_write(LPipe);

      FillChar(LPart1, SizeOf(LPart1), 0);
      FillChar(LPart2, SizeOf(LPart2), 0);
      ResetState;

      LIovecs[0].iov_base := @LPart1[0];
      LIovecs[0].iov_len := 5;
      LIovecs[1].iov_base := @LPart2[0];
      LIovecs[1].iov_len := 5;

      if LLoop.AsyncReadv(LPipe.ReadFd, @LIovecs[0], 2, 0, @IoCallback) then
      begin
        LLoop.RunOnce;
        if not GState.Done then
          LLoop.RunOnce;
      end;

      Check(GState.Done, 'readv callback fired');
      Check(GState.Result = 10, 'readv read 10 bytes (got ' + IntToStr(GState.Result) + ')');
      Check(CompareMem(@LPart1[0], @LWriteData[1], 5),
        'first iov buffer matches "Hello"');
      Check(CompareMem(@LPart2[0], @LWriteData[6], 5),
        'second iov buffer matches "World"');
    finally
      platform_pipe_close(LPipe);
    end;
  finally
    LLoop.Close;
    LLoop.Free;
  end;
end;

{ Test 3: AsyncWritev with single buffer (degrades to AsyncWrite) }
procedure TestAsyncWritevSingleBuffer;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LBuf: string;
  LIovecs: TIovecArray;
  LReadBuf: array[0..63] of Byte;
  LReadLen: ssize_t;
begin
  WriteLn('TestAsyncWritevSingleBuffer:');
  LLoop := TAsyncLoop.Create;
  try
    Check(platform_pipe_create(LPipe) = 0, 'pipe created');
    try
      LBuf := 'SingleBuffer';
      ResetState;

      LIovecs[0].iov_base := @LBuf[1];
      LIovecs[0].iov_len := Length(LBuf);

      if LLoop.AsyncWritev(LPipe.WriteFd, @LIovecs[0], 1, 0, @IoCallback) then
      begin
        LLoop.RunOnce;
        if not GState.Done then
          LLoop.RunOnce;
      end;

      Check(GState.Done, 'writev callback fired');
      Check(GState.Result = Length(LBuf),
        'writev wrote ' + IntToStr(Length(LBuf)) + ' bytes');

      FillChar(LReadBuf, SizeOf(LReadBuf), 0);
      LReadLen := nextpas.core.platform.posix.ffi.read(LPipe.ReadFd, @LReadBuf[0], SizeOf(LReadBuf));
      Check(LReadLen = Length(LBuf), 'read correct length');
      Check(CompareMem(@LReadBuf[0], @LBuf[1], Length(LBuf)),
        'content matches');
    finally
      platform_pipe_close(LPipe);
    end;
  finally
    LLoop.Close;
    LLoop.Free;
  end;
end;

{ Test 4: AsyncReadv with single buffer }
procedure TestAsyncReadvSingleBuffer;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LWriteData: string;
  LPart: array[0..11] of Byte;
  LIovecs: TIovecArray;
  LWritten: ssize_t;
begin
  WriteLn('TestAsyncReadvSingleBuffer:');
  LLoop := TAsyncLoop.Create;
  try
    Check(platform_pipe_create(LPipe) = 0, 'pipe created');
    try
      LWriteData := 'SingleBuffer';
      LWritten := nextpas.core.platform.posix.ffi.write(LPipe.WriteFd, @LWriteData[1], Length(LWriteData));
      Check(LWritten = 12, 'wrote 12 bytes to pipe');
      platform_pipe_close_write(LPipe);

      FillChar(LPart, SizeOf(LPart), 0);
      ResetState;

      LIovecs[0].iov_base := @LPart[0];
      LIovecs[0].iov_len := 12;

      if LLoop.AsyncReadv(LPipe.ReadFd, @LIovecs[0], 1, 0, @IoCallback) then
      begin
        LLoop.RunOnce;
        if not GState.Done then
          LLoop.RunOnce;
      end;

      Check(GState.Done, 'readv callback fired');
      Check(GState.Result = 12, 'readv read 12 bytes (got ' + IntToStr(GState.Result) + ')');
      Check(CompareMem(@LPart[0], @LWriteData[1], 12),
        'content matches');
    finally
      platform_pipe_close(LPipe);
    end;
  finally
    LLoop.Close;
    LLoop.Free;
  end;
end;

{ Test 5: AsyncWritev + AsyncReadv round-trip }
procedure TestVectoredRoundTrip;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LHeader, LPayload, LFooter: string;
  LWriteIovecs: TIovecArray;
  LPart1: array[0..3] of Byte;
  LPart2: array[0..4] of Byte;
  LPart3: array[0..2] of Byte;
  LReadIovecs: TIovecArray;
begin
  WriteLn('TestVectoredRoundTrip:');
  LLoop := TAsyncLoop.Create;
  try
    Check(platform_pipe_create(LPipe) = 0, 'pipe created');
    try
      LHeader := 'HDR:';
      LPayload := 'DATA!';
      LFooter := 'END';

      { Write: header + payload + footer in one writev }
      ResetState;
      LWriteIovecs[0].iov_base := @LHeader[1];
      LWriteIovecs[0].iov_len := Length(LHeader);
      LWriteIovecs[1].iov_base := @LPayload[1];
      LWriteIovecs[1].iov_len := Length(LPayload);
      LWriteIovecs[2].iov_base := @LFooter[1];
      LWriteIovecs[2].iov_len := Length(LFooter);

      if LLoop.AsyncWritev(LPipe.WriteFd, @LWriteIovecs[0], 3, 0, @IoCallback) then
      begin
        LLoop.RunOnce;
        if not GState.Done then
          LLoop.RunOnce;
      end;

      Check(GState.Done, 'writev completed');
      Check(GState.Result = Length(LHeader) + Length(LPayload) + Length(LFooter),
        'writev wrote all bytes');

      { Read into separate buffers with readv }
      FillChar(LPart1, SizeOf(LPart1), 0);
      FillChar(LPart2, SizeOf(LPart2), 0);
      FillChar(LPart3, SizeOf(LPart3), 0);
      ResetState;

      LReadIovecs[0].iov_base := @LPart1[0];
      LReadIovecs[0].iov_len := 4;
      LReadIovecs[1].iov_base := @LPart2[0];
      LReadIovecs[1].iov_len := 5;
      LReadIovecs[2].iov_base := @LPart3[0];
      LReadIovecs[2].iov_len := 3;

      if LLoop.AsyncReadv(LPipe.ReadFd, @LReadIovecs[0], 3, 0, @IoCallback) then
      begin
        LLoop.RunOnce;
        if not GState.Done then
          LLoop.RunOnce;
      end;

      Check(GState.Done, 'readv completed');
      Check(GState.Result = 12, 'readv read 12 bytes');
      Check(CompareMem(@LPart1[0], @LHeader[1], 4), 'header matches');
      Check(CompareMem(@LPart2[0], @LPayload[1], 5), 'payload matches');
      Check(CompareMem(@LPart3[0], @LFooter[1], 3), 'footer matches');
    finally
      platform_pipe_close(LPipe);
    end;
  finally
    LLoop.Close;
    LLoop.Free;
  end;
end;

{ Test 6: AsyncWritev with invalid fd — io_uring accepts but completion returns error }
procedure TestAsyncWritevInvalidFd;
var
  LLoop: TAsyncLoop;
  LIovecs: TIovecArray;
  LBuf: string;
begin
  WriteLn('TestAsyncWritevInvalidFd:');
  LLoop := TAsyncLoop.Create;
  try
    LBuf := 'test';
    LIovecs[0].iov_base := @LBuf[1];
    LIovecs[0].iov_len := Length(LBuf);
    ResetState;

    { io_uring accepts the SQE even for invalid fds; error comes in completion }
    if LLoop.AsyncWritev(-1, @LIovecs[0], 1, 0, @IoCallback) then
    begin
      LLoop.RunOnce;
      if not GState.Done then
        LLoop.RunOnce;
    end;

    Check(GState.Done, 'callback fired for invalid fd');
    Check(GState.Result < 0, 'completion returned error (got ' + IntToStr(GState.Result) + ')');
  finally
    LLoop.Close;
    LLoop.Free;
  end;
end;

{ Main }
begin
  WriteLn('=== test_async_vectored_io ===');
  WriteLn;

  TestAsyncWritevMultipleBuffers;
  WriteLn;

  TestAsyncReadvMultipleBuffers;
  WriteLn;

  TestAsyncWritevSingleBuffer;
  WriteLn;

  TestAsyncReadvSingleBuffer;
  WriteLn;

  TestVectoredRoundTrip;
  WriteLn;

  TestAsyncWritevInvalidFd;
  WriteLn;

  WriteLn('=== Results ===');
  WriteLn('Passed: ', GTestsPassed);
  WriteLn('Failed: ', GTestsFailed);
  WriteLn('Total:  ', GTestsPassed + GTestsFailed);
  WriteLn;

  if GTestsFailed > 0 then
  begin
    WriteLn('FAILED');
    Halt(1);
  end
  else
    WriteLn('OK');
end.
