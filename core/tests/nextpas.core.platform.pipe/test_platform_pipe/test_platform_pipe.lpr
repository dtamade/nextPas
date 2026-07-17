program test_platform_pipe;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.pipe,
  {$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi,
  {$ENDIF}
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.test;

var
  T: TTestSuite;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := '../../../' + ARelativePath;
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  Result := LowerCase(FsReadFileText(LSourcePath));
end;

function ExtractBetween(const ASource, AStartToken, AEndToken: string): string;
var
  LStartPos, LEndPos: SizeInt;
begin
  LStartPos := Pos(AStartToken, ASource);
  Check(LStartPos > 0, 'source range start should exist: ' + AStartToken);
  LEndPos := Pos(AEndToken, Copy(ASource, LStartPos + Length(AStartToken),
    Length(ASource)));
  Check(LEndPos > 0, 'source range end should exist: ' + AEndToken);
  Result := Copy(ASource, LStartPos, Length(AStartToken) + LEndPos - 1);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure TestCreateClose;
var
  P: TPlatformPipe;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  Check(P.ReadFd >= 0, 'read fd valid');
  Check(P.WriteFd >= 0, 'write fd valid');
  Check(platform_pipe_close(P) = 0, 'close');
  Check(P.ReadFd < 0, 'read fd invalidated');
  Check(P.WriteFd < 0, 'write fd invalidated');
end;

{$IFDEF NEXTPAS_UNIX}
procedure TestWriteRead;
var
  P: TPlatformPipe;
  LBuf: array[0..15] of AnsiChar;
  LWritten, LRead: PtrInt;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  LWritten := write(Int32(P.WriteFd), PAnsiChar('hello'), 5);
  Check(LWritten = 5, 'wrote 5');
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := read(Int32(P.ReadFd), @LBuf[0], 16);
  Check(LRead = 5, 'read 5');
  Check(LBuf[0] = 'h', 'data[0]');
  Check(LBuf[4] = 'o', 'data[4]');
  platform_pipe_close(P);
end;

procedure TestCloseWrite;
var
  P: TPlatformPipe;
  LBuf: array[0..7] of Byte;
  LRead: PtrInt;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  Check(platform_pipe_close_write(P) = 0, 'close write');
  LRead := read(Int32(P.ReadFd), @LBuf[0], 8);
  Check(LRead = 0, 'read returns 0 (EOF)');
  platform_pipe_close_read(P);
end;

procedure TestDup2;
var
  P1, P2: TPlatformPipe;
  LBuf: array[0..7] of AnsiChar;
  LRead: PtrInt;
begin
  Check(platform_pipe_create(P1) = 0, 'create p1');
  Check(platform_pipe_create(P2) = 0, 'create p2');
  Check(platform_dup2(P1.WriteFd, P2.WriteFd) = 0, 'dup2');
  write(Int32(P2.WriteFd), PAnsiChar('dup'), 3);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := read(Int32(P1.ReadFd), @LBuf[0], 8);
  Check(LRead = 3, 'read from p1 after dup2');
  Check(LBuf[0] = 'd', 'data');
  platform_pipe_close(P1);
  close(Int32(P2.WriteFd));
  platform_pipe_close_read(P2);
end;
{$ENDIF}

procedure TestDoubleCloseRead;
var
  P: TPlatformPipe;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  Check(platform_pipe_close_read(P) = 0, 'close read');
  Check(platform_pipe_close_read(P) <> 0, 'double close read error');
  platform_pipe_close_write(P);
end;

procedure TestWindowsPipeSourceContract;
var
  LPipe, LWindowsBranch: string;
begin
  LPipe := LoadSourceText('src/nextpas.core.platform.pipe.pas');
  LWindowsBranch := ExtractBetween(LPipe, '{$ifdef nextpas_windows}',
    '{$if not defined(nextpas_unix) and not defined(nextpas_windows)}');

  CheckContains(LPipe, 'readfd: ptrint',
    'pipe read endpoint must preserve pointer-sized Windows HANDLE values');
  CheckContains(LPipe, 'writefd: ptrint',
    'pipe write endpoint must preserve pointer-sized Windows HANDLE values');
  CheckContains(LPipe, 'function platform_dup2(aoldfd: ptrint; anewfd: ptrint): int32',
    'platform_dup2 facade must preserve pointer-sized endpoint values');
  CheckContains(LWindowsBranch, 'createpipe(@lread, @lwrite',
    'Windows pipe create must use nextPas-owned CreatePipe binding');
  CheckContains(LWindowsBranch, 'apipe.readfd := ptrint(lread)',
    'Windows pipe read fd facade must not truncate HANDLE');
  CheckContains(LWindowsBranch, 'apipe.writefd := ptrint(lwrite)',
    'Windows pipe write fd facade must not truncate HANDLE');
  CheckContains(LWindowsBranch, 'platform_err_unsupported',
    'Windows dup2 must return stable PLATFORM_ERR_UNSUPPORTED');
  CheckAbsent(LWindowsBranch, 'error_not_supported',
    'Windows dup2 must not leak raw Windows ERROR_NOT_SUPPORTED');
  CheckAbsent(LWindowsBranch, 'result := -1; // not implemented on windows',
    'Windows dup2 must not remain a bare -1 stub');
end;

procedure TestDoubleCloseWrite;
var
  P: TPlatformPipe;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  Check(platform_pipe_close_write(P) = 0, 'close write');
  Check(platform_pipe_close_write(P) <> 0, 'double close write error');
  platform_pipe_close_read(P);
end;

procedure TestPipeWriteReadMultiple;
var
  P: TPlatformPipe;
  LBuf: array[0..31] of AnsiChar;
  LWritten, LRead: PtrInt;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  {$IFDEF NEXTPAS_UNIX}
  LWritten := write(Int32(P.WriteFd), PAnsiChar('abc'), 3);
  Check(LWritten = 3, 'wrote 3');
  LWritten := write(Int32(P.WriteFd), PAnsiChar('def'), 3);
  Check(LWritten = 3, 'wrote 3 more');
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := read(Int32(P.ReadFd), @LBuf[0], 32);
  Check(LRead = 6, 'read 6 total');
  Check(LBuf[0] = 'a', 'data[0]');
  Check(LBuf[5] = 'f', 'data[5]');
  {$ENDIF}
  platform_pipe_close(P);
end;

procedure TestPipeCloseAlreadyClosed;
var
  P: TPlatformPipe;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  Check(platform_pipe_close(P) = 0, 'close');
  { Second close returns 0 (safe no-op, fd already -1) }
  Check(platform_pipe_close(P) = 0, 'double close returns 0 (safe no-op)');
end;

{$IFDEF NEXTPAS_UNIX}
procedure TestDup2SameFd;
var
  P: TPlatformPipe;
  LBuf: array[0..7] of AnsiChar;
  LRead: PtrInt;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  { dup2 to same fd should be no-op and succeed }
  Check(platform_dup2(P.WriteFd, P.WriteFd) = 0, 'dup2 same fd');
  write(Int32(P.WriteFd), PAnsiChar('same'), 4);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := read(Int32(P.ReadFd), @LBuf[0], 8);
  Check(LRead = 4, 'read 4 after dup2 same');
  Check(LBuf[0] = 's', 'data');
  platform_pipe_close(P);
end;

procedure TestPipePartialClose;
var
  P: TPlatformPipe;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  { Close read, then close entire pipe }
  Check(platform_pipe_close_read(P) = 0, 'close read');
  { Close entire pipe should still succeed even though read already closed }
  Check(platform_pipe_close(P) = 0, 'close after partial close');
end;

procedure TestPipeLargeData;
var
  P: TPlatformPipe;
  LSent, LBuf: array[0..4095] of Byte;
  LWritten, LRead: PtrInt;
  LTotalRead, I: Int32;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  { Fill pattern }
  for I := 0 to 4095 do
    LSent[I] := Byte(I and $FF);
  { Write all }
  LWritten := write(Int32(P.WriteFd), @LSent[0], 4096);
  Check(LWritten = 4096, 'wrote 4096 bytes');
  { Read all (may need multiple reads) }
  LTotalRead := 0;
  while LTotalRead < 4096 do
  begin
    LRead := read(Int32(P.ReadFd), @LBuf[LTotalRead], 4096 - LTotalRead);
    if LRead <= 0 then Break;
    Inc(LTotalRead, Int32(LRead));
  end;
  Check(LTotalRead = 4096, 'read all 4096 bytes');
  { Verify pattern }
  for I := 0 to 4095 do
    if LBuf[I] <> Byte(I and $FF) then
    begin
      Check(False, 'data mismatch at offset ' + IntToStr(I));
      Break;
    end;
  Check(True, 'large data integrity verified');
  platform_pipe_close(P);
end;

procedure TestDup2InvalidFd;
var
  LRet: Int32;
begin
  { dup2 with invalid fds should return error }
  LRet := platform_dup2(-1, -1);
  Check(LRet <> 0, 'dup2 with invalid fds returns error');
end;

procedure TestPipeWriteAfterCloseWrite;
var
  P: TPlatformPipe;
  LWritten: PtrInt;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  Check(platform_pipe_close_write(P) = 0, 'close write');
  { Write after close_write should fail }
  LWritten := write(Int32(P.WriteFd), PAnsiChar('x'), 1);
  Check(LWritten < 0, 'write after close_write fails');
  platform_pipe_close(P);
end;
{$ENDIF}

procedure TestPipeHelperMethods;
var
  P: TPlatformPipe;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  Check(P.IsValid, 'valid pipe IsValid');
  Check(P.IsReadValid, 'valid pipe IsReadValid');
  Check(P.IsWriteValid, 'valid pipe IsWriteValid');

  platform_pipe_close_read(P);
  Check(not P.IsValid, 'after close_read IsValid = false');
  Check(not P.IsReadValid, 'after close_read IsReadValid = false');
  Check(P.IsWriteValid, 'after close_read IsWriteValid = true');

  platform_pipe_close_write(P);
  Check(not P.IsValid, 'after close_write IsValid = false');
  Check(not P.IsReadValid, 'after close_read IsReadValid = false');
  Check(not P.IsWriteValid, 'after close_write IsWriteValid = false');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.pipe');
  T.Test('create/close', @TestCreateClose);
  {$IFDEF NEXTPAS_UNIX}
  T.Test('write + read', @TestWriteRead);
  T.Test('close write = EOF', @TestCloseWrite);
  T.Test('dup2', @TestDup2);
  T.Test('dup2 same fd', @TestDup2SameFd);
  T.Test('pipe partial close', @TestPipePartialClose);
  T.Test('pipe large data (4KB)', @TestPipeLargeData);
  T.Test('dup2 invalid fd', @TestDup2InvalidFd);
  T.Test('write after close_write', @TestPipeWriteAfterCloseWrite);
  {$ENDIF}
  T.Test('double close read', @TestDoubleCloseRead);
  T.Test('double close write', @TestDoubleCloseWrite);
  T.Test('pipe close already closed', @TestPipeCloseAlreadyClosed);
  T.Test('pipe write+read multiple chunks', @TestPipeWriteReadMultiple);
  T.Test('Windows pipe source contract', @TestWindowsPipeSourceContract);
  T.Test('pipe IsValid/IsReadValid/IsWriteValid', @TestPipeHelperMethods);
  if not T.Run then Halt(1);
end.
