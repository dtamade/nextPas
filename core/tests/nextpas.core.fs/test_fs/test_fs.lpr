program test_fs;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.base,
  nextpas.core.io.intf,
{$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi,
{$ENDIF}
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.fs.stream,
  nextpas.core.fs.dir,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.fs;

var
  T: TTestRunner;
  GTmpDir: string;

procedure SetupTmpDir;
begin
  GTmpDir := '/tmp/nextpas_fs_test_' + IntToStr(GetProcessID);
  nextpas.core.fs.MkdirAll(GTmpDir);
end;

procedure CleanupTmpDir;
begin
  nextpas.core.fs.RemoveAll(GTmpDir);
end;

{ File tests }

procedure TestCreateAndRead;
var
  LF: IFile;
  LBuf: array[0..9] of Byte;
  LN: SizeUInt;
begin
  LF := FsCreate(GTmpDir + '/hello.txt');
  LF.Write(PAnsiChar('hello')^, 5);
  LF.Close;

  LF := FsOpen(GTmpDir + '/hello.txt', [fmRead]);
  LN := LF.Read(LBuf[0], 10);
  CheckEqual(SizeUInt(5), LN, 'read 5');
  CheckEqual(Byte(Ord('h')), LBuf[0]);
  CheckEqual(Byte(Ord('o')), LBuf[4]);
  LF.Close;
end;

procedure TestSeek;
var
  LF: IFile;
  LBuf: Byte;
begin
  LF := FsOpen(GTmpDir + '/hello.txt', [fmRead]);
  LF.Seek(3, soBeginning);
  LF.Read(LBuf, 1);
  CheckEqual(Byte(Ord('l')), LBuf, 'seek to 3');
  LF.Close;
end;

procedure TestStat;
var
  LF: IFile;
  LInfo: TFileInfo;
begin
  LF := FsOpen(GTmpDir + '/hello.txt', [fmRead]);
  LInfo := LF.Stat;
  CheckEqual(Int64(5), LInfo.Size, 'size 5');
  Check(LInfo.FileType = nextpas.core.fs.base.ftRegular, 'regular file');
  Check(not LInfo.IsDir, 'not dir');
  LF.Close;
end;

procedure TestTruncate;
var
  LF: IFile;
begin
  LF := FsOpen(GTmpDir + '/hello.txt', [fmRead, fmWrite]);
  LF.Truncate(3);
  CheckEqual(Int64(3), LF.GetSize, 'truncated to 3');
  LF.Close;
end;

procedure TestReadAt;
var
  LF: IFile;
  LRA: IReaderAt;
  LBuf: array[0..1] of Byte;
begin
  FsWriteFile(GTmpDir + '/rdat.bin', TBytes.Create(10, 20, 30, 40, 50));
  LF := FsOpen(GTmpDir + '/rdat.bin', [fmRead]);
  LRA := LF as IReaderAt;
  CheckEqual(SizeUInt(2), LRA.ReadAt(LBuf[0], 2, 2), 'readat 2');
  CheckEqual(Byte(30), LBuf[0]);
  CheckEqual(Byte(40), LBuf[1]);
  LF.Close;
end;

procedure TestWriteAt;
var
  LF: IFile;
  LWA: IWriterAt;
  LBuf: array[0..1] of Byte;
begin
  FsWriteFile(GTmpDir + '/wat.bin', TBytes.Create(0, 0, 0, 0, 0));
  LF := FsOpen(GTmpDir + '/wat.bin', [fmRead, fmWrite]);
  LWA := LF as IWriterAt;
  LBuf[0] := $AA; LBuf[1] := $BB;
  LWA.WriteAt(LBuf[0], 2, 1);
  LF.Seek(1, soBeginning);
  LF.Read(LBuf[0], 2);
  CheckEqual(Byte($AA), LBuf[0]);
  CheckEqual(Byte($BB), LBuf[1]);
  LF.Close;
end;

{ Util tests }

procedure TestReadWriteFile;
var
  LData, LRead: TBytes;
begin
  LData := TBytes.Create(1, 2, 3, 4, 5);
  FsWriteFile(GTmpDir + '/rw.bin', LData);
  LRead := FsReadFile(GTmpDir + '/rw.bin');
  CheckEqual(Int64(5), Int64(Length(LRead)), 'len 5');
  CheckEqual(Byte(1), LRead[0]);
  CheckEqual(Byte(5), LRead[4]);
end;

procedure TestWriteAtomic;
var
  LData, LRead: TBytes;
begin
  LData := TBytes.Create(10, 20, 30);
  FsWriteAtomic(GTmpDir + '/atomic.bin', LData);
  LRead := FsReadFile(GTmpDir + '/atomic.bin');
  CheckEqual(Int64(3), Int64(Length(LRead)), 'len 3');
  CheckEqual(Byte(10), LRead[0]);
end;

procedure TestCopyFile;
var
  LData, LRead: TBytes;
  LCopied: Int64;
begin
  LData := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8);
  FsWriteFile(GTmpDir + '/src.bin', LData);
  LCopied := FsCopyFile(GTmpDir + '/src.bin', GTmpDir + '/dst.bin');
  CheckEqual(Int64(8), LCopied, 'copied 8');
  LRead := FsReadFile(GTmpDir + '/dst.bin');
  CheckEqual(Int64(8), Int64(Length(LRead)), 'dst len');
end;

procedure TestExists;
begin
  Check(FsExists(GTmpDir), 'dir exists');
  Check(not FsExists(GTmpDir + '/nonexistent'), 'not exists');
end;

procedure TestIsFileIsDir;
begin
  FsWriteFile(GTmpDir + '/afile.txt', TBytes.Create(1));
  Check(FsIsFile(GTmpDir + '/afile.txt'), 'is file');
  Check(not FsIsDir(GTmpDir + '/afile.txt'), 'not dir');
  Check(FsIsDir(GTmpDir), 'is dir');
  Check(not FsIsFile(GTmpDir), 'not file');
end;

procedure TestFileSize;
begin
  FsWriteFile(GTmpDir + '/sz.bin', TBytes.Create(1, 2, 3));
  CheckEqual(Int64(3), FsFileSize(GTmpDir + '/sz.bin'), 'size 3');
end;

{ Dir tests }

procedure TestMkdirAndReadDir;
var
  LEntries: TDirEntryArray;
  LFound: Boolean;
  LI: Integer;
begin
  FsMkdir(GTmpDir + '/subdir');
  FsWriteFile(GTmpDir + '/subdir/a.txt', TBytes.Create(1));
  LEntries := FsReadDir(GTmpDir + '/subdir');
  LFound := False;
  for LI := 0 to High(LEntries) do
    if LEntries[LI].Name = 'a.txt' then
      LFound := True;
  Check(LFound, 'found a.txt');
end;

procedure TestMkdirAll;
begin
  Check(FsMkdirAll(GTmpDir + '/a/b/c'), 'mkdir -p');
  Check(FsIsDir(GTmpDir + '/a/b/c'), 'deep dir exists');
end;

procedure TestRemove;
begin
  FsWriteFile(GTmpDir + '/rm.txt', TBytes.Create(1));
  Check(FsRemove(GTmpDir + '/rm.txt'), 'remove file');
  Check(not FsExists(GTmpDir + '/rm.txt'), 'gone');
end;

procedure TestRemoveAll;
begin
  FsMkdirAll(GTmpDir + '/rmall/sub');
  FsWriteFile(GTmpDir + '/rmall/sub/f.txt', TBytes.Create(1));
  Check(FsRemoveAll(GTmpDir + '/rmall'), 'removeall');
  Check(not FsExists(GTmpDir + '/rmall'), 'gone');
end;

procedure TestRename;
begin
  FsWriteFile(GTmpDir + '/old.txt', TBytes.Create(42));
  Check(FsRename(GTmpDir + '/old.txt', GTmpDir + '/new.txt'), 'rename');
  Check(not FsExists(GTmpDir + '/old.txt'), 'old gone');
  Check(FsExists(GTmpDir + '/new.txt'), 'new exists');
end;

procedure TestDirIterator;
var
  LIter: IDirIterator;
  LCount: Integer;
begin
  FsMkdir(GTmpDir + '/iter');
  FsWriteFile(GTmpDir + '/iter/x.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/iter/y.txt', TBytes.Create(2));
  LIter := FsOpenDir(GTmpDir + '/iter');
  LCount := 0;
  while LIter.Next do
    Inc(LCount);
  LIter.Close;
  CheckEqual(Int64(2), Int64(LCount), '2 entries');
end;

{ Path tests }

procedure TestPathJoin;
begin
  CheckEqual('/home/user/file.txt', FsPathJoin(['/home', 'user', 'file.txt']), 'join');
end;

procedure TestPathDir;
begin
  CheckEqual('/home/user', FsPathDir('/home/user/file.txt'), 'dir');
end;

procedure TestPathBase;
begin
  CheckEqual('file.txt', FsPathBase('/home/user/file.txt'), 'base');
end;

procedure TestPathExt;
begin
  CheckEqual('.txt', FsPathExt('/home/user/file.txt'), 'ext');
end;

procedure TestPathIsAbs;
begin
  Check(FsPathIsAbs('/home/user'), 'abs');
  Check(not FsPathIsAbs('relative/path'), 'not abs');
end;

procedure TestPathCleanEmpty;
begin
  CheckEqual('.', FsPathClean(''), 'Clean("") = "."');
end;

procedure TestPathLong;
var
  LLong, LJoined: string;
  LI: Integer;
begin
  { Build a path longer than the 1024 stack buffer to exercise heap retry. }
  LLong := '';
  for LI := 1 to 200 do
    LLong := LLong + 'segment_';
  LJoined := FsPathJoin(['/base', LLong, 'file.txt']);
  Check(Pos('file.txt', LJoined) > 0, 'long join keeps tail');
  Check(Length(LJoined) > 1024, 'long path not truncated');
end;

{ Error tests }

procedure TestOpenNotFound;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    FsOpen(GTmpDir + '/no_such_file_xyz', [fmRead]);
  except
    on E: ENotFoundError do
      LGot := True;
  end;
  Check(LGot, 'ENotFoundError raised');
end;

procedure TestCloseInvalidHandleRaises;
var
  LF: IFile;
  LGot: Boolean;
begin
  LF := FsFromHandle(-1, 'invalid-close-handle');
  LGot := False;
  try
    LF.Close;
  except
    on E: EIOError do
      LGot := True;
  end;
  Check(LGot, 'Close raises EIOError for invalid handle');
end;

procedure TestAppend;
var
  LF: IFile;
  LData: TBytes;
begin
  FsWriteFile(GTmpDir + '/append.txt', TBytes.Create(Ord('a'), Ord('b'), Ord('c')));
  LF := FsOpen(GTmpDir + '/append.txt', [fmAppend]);
  LF.Write(PAnsiChar('Z')^, 1);
  LF.Close;
  LData := FsReadFile(GTmpDir + '/append.txt');
  CheckEqual(Int64(4), Int64(Length(LData)), 'len 4 after append');
  CheckEqual(Byte(Ord('a')), LData[0], 'original preserved');
  CheckEqual(Byte(Ord('Z')), LData[3], 'appended at end');
end;

procedure TestExclusive;
var
  LGot: Boolean;
begin
  FsWriteFile(GTmpDir + '/excl.txt', TBytes.Create(1));
  LGot := False;
  try
    FsOpenFile(GTmpDir + '/excl.txt', [fmWrite, fmCreate, fmExclusive], PermDefault);
  except
    on E: EAlreadyExistsError do
      LGot := True;
  end;
  Check(LGot, 'EAlreadyExistsError on exclusive existing');
end;

procedure TestReadAtPositionIndependent;
var
  LF: IFile;
  LRA: IReaderAt;
  LBuf: array[0..1] of Byte;
  LPosBefore, LPosAfter: Int64;
begin
  FsWriteFile(GTmpDir + '/posindep.bin', TBytes.Create(10, 20, 30, 40, 50));
  LF := FsOpen(GTmpDir + '/posindep.bin', [fmRead]);
  LF.Seek(1, soBeginning);
  LPosBefore := LF.GetPosition;
  LRA := LF as IReaderAt;
  LRA.ReadAt(LBuf[0], 2, 3);
  LPosAfter := LF.GetPosition;
  CheckEqual(Byte(40), LBuf[0], 'readat offset 3');
  CheckEqual(LPosBefore, LPosAfter, 'ReadAt leaves position unchanged');
  LF.Close;
end;

procedure TestChmodAndPerm;
var
  LInfo: TFileInfo;
begin
  FsWriteFile(GTmpDir + '/perm.txt', TBytes.Create(1), PermOwnerRead or PermOwnerWrite);
  FsChmod(GTmpDir + '/perm.txt', PermOwnerRead or PermOwnerWrite or PermOwnerExec);
  LInfo := FsStat(GTmpDir + '/perm.txt');
{$IFDEF NEXTPAS_UNIX}
  CheckEqual(Int64(PermOwnerRead or PermOwnerWrite or PermOwnerExec),
    Int64(LInfo.Permission), 'perm 0700');
{$ENDIF}
end;

procedure TestTruncatePath;
begin
  FsWriteFile(GTmpDir + '/trunc.bin', TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8));
  FsTruncate(GTmpDir + '/trunc.bin', 3);
  CheckEqual(Int64(3), FsFileSize(GTmpDir + '/trunc.bin'), 'truncated to 3');
end;

procedure TestTempFileInDir;
var
  LF: IFile;
  LName: string;
begin
  FsMkdir(GTmpDir + '/tmpdir');
  LF := FsTempFile(GTmpDir + '/tmpdir', 'pre_');
  LName := LF.Name;
  LF.Write(PAnsiChar('hi')^, 2);
  LF.Close;
  Check(Pos(GTmpDir + '/tmpdir/pre_', LName) = 1, 'temp file created in ADir');
  Check(FsExists(LName), 'temp file exists');
end;

procedure TestLstat;
begin
  FsWriteFile(GTmpDir + '/lst.txt', TBytes.Create(1, 2));
  Check(not FsLstat(GTmpDir + '/lst.txt').IsSymlink, 'regular not symlink');
  Check(FsLstat(GTmpDir + '/lst.txt').FileType = nextpas.core.fs.base.ftRegular, 'regular');
end;

{$IFDEF NEXTPAS_UNIX}
procedure TestRemoveAllSymlinkRoot;
var
  LTarget, LLink: string;
begin
  LTarget := GTmpDir + '/rmtarget';
  LLink := GTmpDir + '/rmlink';
  FsMkdir(LTarget);
  FsWriteFile(LTarget + '/keep.txt', TBytes.Create(42));
  if nextpas.core.platform.posix.ffi.symlink(PAnsiChar(LTarget), PAnsiChar(LLink)) <> 0 then
  begin
    Check(True, 'symlink unsupported, skip');
    Exit;
  end;
  FsRemoveAll(LLink);
  Check(not FsExists(LLink), 'symlink removed');
  Check(FsExists(LTarget + '/keep.txt'), 'target tree intact');
end;

procedure TestSymlinkReadlink;
var
  LTarget, LLink, LRead: string;
begin
  LTarget := GTmpDir + '/symtarget.txt';
  LLink := GTmpDir + '/symlink.txt';
  FsWriteFile(LTarget, TBytes.Create(1, 2, 3));
  FsSymlink(LTarget, LLink);
  Check(FsExists(LLink), 'link exists');
  LRead := FsReadlink(LLink);
  CheckEqual(LTarget, LRead, 'readlink returns target');
  Check(FsLstat(LLink).IsSymlink, 'lstat sees symlink');
  Check(not FsStat(LLink).IsSymlink, 'stat follows link');
end;
{$ENDIF}

begin
  SetupTmpDir;
  try
    T := TTestRunner.Create('nextpas.core.fs');

    T.Run('Create and read', @TestCreateAndRead);
    T.Run('Seek', @TestSeek);
    T.Run('Stat', @TestStat);
    T.Run('Truncate', @TestTruncate);
    T.Run('ReadAt', @TestReadAt);
    T.Run('WriteAt', @TestWriteAt);

    T.Run('ReadFile/WriteFile', @TestReadWriteFile);
    T.Run('WriteAtomic', @TestWriteAtomic);
    T.Run('CopyFile', @TestCopyFile);
    T.Run('Exists', @TestExists);
    T.Run('IsFile/IsDir', @TestIsFileIsDir);
    T.Run('FileSize', @TestFileSize);

    T.Run('Mkdir + ReadDir', @TestMkdirAndReadDir);
    T.Run('MkdirAll', @TestMkdirAll);
    T.Run('Remove', @TestRemove);
    T.Run('RemoveAll', @TestRemoveAll);
    T.Run('Rename', @TestRename);
    T.Run('DirIterator', @TestDirIterator);

    T.Run('PathJoin', @TestPathJoin);
    T.Run('PathDir', @TestPathDir);
    T.Run('PathBase', @TestPathBase);
    T.Run('PathExt', @TestPathExt);
    T.Run('PathIsAbs', @TestPathIsAbs);
    T.Run('PathClean empty', @TestPathCleanEmpty);
    T.Run('PathJoin long', @TestPathLong);

    T.Run('Open not found', @TestOpenNotFound);
    T.Run('Close invalid handle raises', @TestCloseInvalidHandleRaises);

    T.Run('Append', @TestAppend);
    T.Run('Exclusive create', @TestExclusive);
    T.Run('ReadAt position-independent', @TestReadAtPositionIndependent);
    T.Run('Chmod + perm', @TestChmodAndPerm);
    T.Run('Truncate path', @TestTruncatePath);
    T.Run('TempFile in dir', @TestTempFileInDir);
    T.Run('Lstat', @TestLstat);
{$IFDEF NEXTPAS_UNIX}
    T.Run('RemoveAll symlink root', @TestRemoveAllSymlinkRoot);
    T.Run('Symlink + Readlink', @TestSymlinkReadlink);
{$ENDIF}

    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.
