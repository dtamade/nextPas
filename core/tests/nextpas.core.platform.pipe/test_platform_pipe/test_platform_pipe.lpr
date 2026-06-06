program test_platform_pipe;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.pipe,
  {$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi,
  {$ENDIF}
  Classes,
  SysUtils,
  nextpas.core.testing;

var
  T: TTestRunner;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
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
  CheckContains(LWindowsBranch, 'error_not_supported',
    'Windows dup2 must return stable unsupported semantics');
  CheckAbsent(LWindowsBranch, 'result := -1; // not implemented on windows',
    'Windows dup2 must not remain a bare -1 stub');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.pipe');
  T.Run('create/close', @TestCreateClose);
  {$IFDEF NEXTPAS_UNIX}
  T.Run('write + read', @TestWriteRead);
  T.Run('close write = EOF', @TestCloseWrite);
  T.Run('dup2', @TestDup2);
  {$ENDIF}
  T.Run('double close read', @TestDoubleCloseRead);
  T.Run('Windows pipe source contract', @TestWindowsPipeSourceContract);
  T.Summary;
end.
