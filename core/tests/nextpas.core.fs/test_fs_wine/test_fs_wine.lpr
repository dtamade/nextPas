program test_fs_wine;

{ L2 fs Windows evidence under Wine.
  truth=wine-runtime-smoke — NOT real Windows host runtime. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.fs,
  nextpas.core.fs.base,
  nextpas.core.path,
  nextpas.core.text.conv
  ;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

function WineTmp: string;
begin
  Result := GetTempDir;
  if Result = '' then
    Result := 'C:\windows\temp';
  Result := PathJoin(Result, 'nextpas_fs_wine');
end;

procedure TestWriteReadRemove;
var
  LDir, LFile, LText: string;
begin
  LDir := WineTmp;
  MkdirAll(LDir);
  LFile := PathJoin(LDir, 'hello.txt');
  WriteFileText(LFile, 'wine_fs_ok');
  Check(Exists(LFile), 'file exists after write');
  LText := ReadFileText(LFile);
  Check(Pos('wine_fs_ok', LText) > 0, 'read back content');
  Remove(LFile);
  Check(not Exists(LFile), 'removed');
  RemoveAll(LDir);
end;


procedure TestOpenLocked;
var
  LDir, LFile: string;
  A: IFile;
begin
  LDir := WineTmp;
  MkdirAll(LDir);
  LFile := PathJoin(LDir, 'lock.bin');
  WriteFileText(LFile, 'x');
  A := OpenLocked(LFile, [fmRead, fmWrite], flkExclusive);
  Check(A <> nil, 'OpenLocked non-nil');
  A.Unlock;
  A.Close;
  RemoveAll(LDir);
end;

procedure TestReadAt;
var
  LDir, LFile: string;
  A: IFile;
  LBuf: array[0..15] of AnsiChar;
  N: SizeUInt;
begin
  LDir := WineTmp;
  MkdirAll(LDir);
  LFile := PathJoin(LDir, 'pread.bin');
  WriteFileText(LFile, 'ABCDEFGH');
  A := Open(LFile, [fmRead]);
  FillChar(LBuf, SizeOf(LBuf), 0);
  N := A.ReadAt(LBuf[0], 4, 2);
  Check(N = 4, 'ReadAt len 4');
  Check((LBuf[0] = 'C') and (LBuf[1] = 'D') and (LBuf[2] = 'E') and (LBuf[3] = 'F'),
    'ReadAt offset 2 payload CDEF');
  A.Close;
  RemoveAll(LDir);
end;

procedure TestMkdirAllNested;
var
  LRoot, LNest: string;
begin
  LRoot := WineTmp;
  LNest := PathJoin(PathJoin(LRoot, 'a'), 'b');
  MkdirAll(LNest);
  Check(IsDir(LNest), 'nested dir exists');
  RemoveAll(LRoot);
end;

{$ELSE}

procedure TestSkipHost;
begin
  Check(True, 'host is not Windows; wine suite is cross-target only');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('fs L2 wine-runtime-smoke');
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('write read remove', @TestWriteReadRemove);
  T.Test('mkdirall nested', @TestMkdirAllNested);
  T.Test('OpenLocked', @TestOpenLocked);
  T.Test('ReadAt', @TestReadAt);
{$ELSE}
  T.Test('skip non-windows host', @TestSkipHost);
{$ENDIF}
  if not T.Run then
    Halt(1);
end.
