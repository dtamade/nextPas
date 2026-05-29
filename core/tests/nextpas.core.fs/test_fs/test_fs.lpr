program test_fs;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.base,
  nextpas.core.io.intf,
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

    T.Run('Open not found', @TestOpenNotFound);

    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.