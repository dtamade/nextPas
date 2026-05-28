program test_platform_pipe;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.pipe,
  nextpas.core.platform.posix.ffi,
  nextpas.core.testing;

var
  T: TTestRunner;

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

procedure TestWriteRead;
var
  P: TPlatformPipe;
  LBuf: array[0..15] of AnsiChar;
  LWritten, LRead: PtrInt;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  LWritten := write(P.WriteFd, PAnsiChar('hello'), 5);
  Check(LWritten = 5, 'wrote 5');
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := read(P.ReadFd, @LBuf[0], 16);
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
  LRead := read(P.ReadFd, @LBuf[0], 8);
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
  write(P2.WriteFd, PAnsiChar('dup'), 3);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := read(P1.ReadFd, @LBuf[0], 8);
  Check(LRead = 3, 'read from p1 after dup2');
  Check(LBuf[0] = 'd', 'data');
  platform_pipe_close(P1);
  close(P2.WriteFd);
  platform_pipe_close_read(P2);
end;

procedure TestDoubleCloseRead;
var
  P: TPlatformPipe;
begin
  Check(platform_pipe_create(P) = 0, 'create');
  Check(platform_pipe_close_read(P) = 0, 'close read');
  Check(platform_pipe_close_read(P) <> 0, 'double close read error');
  platform_pipe_close_write(P);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.pipe');
  T.Run('create/close', @TestCreateClose);
  T.Run('write + read', @TestWriteRead);
  T.Run('close write = EOF', @TestCloseWrite);
  T.Run('dup2', @TestDup2);
  T.Run('double close read', @TestDoubleCloseRead);
  T.Summary;
end.
