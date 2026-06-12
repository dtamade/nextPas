program test_fs;

{$I nextpas.core.settings.inc}

uses
  SysUtils, Classes,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.base,
  nextpas.core.io.intf,
{$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi,
{$ENDIF}
{$IFDEF NEXTPAS_LINUX}
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi,
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

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandFileName('../../../' + ARelativePath);
  Check(FileExists(LSourcePath), 'source exists: ' + ARelativePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

function ExtractFunctionBody(const ASource, AStartToken, ANextToken: string): string;
var
  LStart, LNext: Integer;
begin
  Result := '';
  LStart := Pos(AStartToken, ASource);
  if LStart = 0 then
    Exit;
  LNext := Pos(ANextToken, Copy(ASource, LStart + Length(AStartToken),
    Length(ASource)));
  if LNext = 0 then
    Exit(Copy(ASource, LStart, Length(ASource)));
  Result := Copy(ASource, LStart, Length(AStartToken) + LNext - 1);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage);
end;

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

{$IFDEF NEXTPAS_LINUX}
type
  TLibcSigSet = record
    Bits: array[0..15] of QWord;
  end;
  TLibcSigAction = record
    sa_handler: Pointer;
    sa_mask: TLibcSigSet;
    sa_flags: Int32;
    sa_restorer: Pointer;
  end;

function BeginShortWriteRegression(out AOldLimit: TRLimit;
  out AOldAct: TLibcSigAction): Boolean;
var
  LIgnoreAct: TLibcSigAction;
  LNewLimit: TRLimit;
begin
  Result := False;
  if getrlimit(RLIMIT_FSIZE, @AOldLimit) <> 0 then
    Exit;
  if AOldLimit.rlim_max < 4 then
    Exit;

  FillChar(LIgnoreAct, SizeOf(LIgnoreAct), 0);
  LIgnoreAct.sa_handler := Pointer(SIG_IGN);
  Check(sigaction(SIGXFSZ, @LIgnoreAct, @AOldAct) = 0,
    'ignore SIGXFSZ during short-write regression');
  LNewLimit := AOldLimit;
  LNewLimit.rlim_cur := 4;
  Check(setrlimit(RLIMIT_FSIZE, @LNewLimit) = 0,
    'lower file-size limit for short-write regression');
  Result := True;
end;

procedure EndShortWriteRegression(const AOldLimit: TRLimit;
  const AOldAct: TLibcSigAction);
begin
  Check(setrlimit(RLIMIT_FSIZE, @AOldLimit) = 0,
    'restore file-size limit');
  Check(sigaction(SIGXFSZ, @AOldAct, nil) = 0,
    'restore SIGXFSZ handler');
end;

procedure TestWriteFileRaisesOnShortWrite;
var
  LOldLimit: TRLimit;
  LOldAct: TLibcSigAction;
  LData: TBytes;
  LGot: Boolean;
begin
  if not BeginShortWriteRegression(LOldLimit, LOldAct) then
  begin
    Check(True, 'RLIMIT_FSIZE unavailable, skip');
    Exit;
  end;
  try
    LData := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8,
      9, 10, 11, 12, 13, 14, 15, 16);
    LGot := False;
    try
      FsWriteFile(GTmpDir + '/short-write.bin', LData);
    except
      on E: EIOError do
        LGot := True;
    end;
    Check(LGot, 'FsWriteFile raises EIOError on positive short write');
  finally
    EndShortWriteRegression(LOldLimit, LOldAct);
  end;
end;

procedure TestAppendFileRaisesOnShortWrite;
var
  LOldLimit: TRLimit;
  LOldAct: TLibcSigAction;
  LData: TBytes;
  LGot: Boolean;
begin
  if not BeginShortWriteRegression(LOldLimit, LOldAct) then
  begin
    Check(True, 'RLIMIT_FSIZE unavailable, skip');
    Exit;
  end;
  try
    LData := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8,
      9, 10, 11, 12, 13, 14, 15, 16);
    LGot := False;
    try
      nextpas.core.fs.AppendFile(GTmpDir + '/short-append.bin', LData);
    except
      on E: EIOError do
        LGot := True;
    end;
    Check(LGot, 'AppendFile raises EIOError on positive short write');
  finally
    EndShortWriteRegression(LOldLimit, LOldAct);
  end;
end;
{$ENDIF}

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

procedure TestMkdirExistingFileRaisesAlreadyExists;
var
  LGot: Boolean;
begin
  FsWriteFile(GTmpDir + '/mkdir-existing-file.txt', TBytes.Create(1));
  LGot := False;
  try
    FsMkdir(GTmpDir + '/mkdir-existing-file.txt');
  except
    on E: EAlreadyExistsError do
      LGot := True;
  end;
  Check(LGot, 'FsMkdir existing regular file raises EAlreadyExistsError');
end;

procedure TestMkdirAllExistingFileChildRaisesInvalidOperation;
var
  LGot: Boolean;
begin
  FsWriteFile(GTmpDir + '/mkdirall-file-parent.txt', TBytes.Create(1));
  LGot := False;
  try
    FsMkdirAll(GTmpDir + '/mkdirall-file-parent.txt/child');
  except
    on E: EInvalidOperationError do
      LGot := True;
  end;
  Check(LGot, 'FsMkdirAll through regular file raises EInvalidOperationError');
end;

procedure TestRemove;
begin
  FsWriteFile(GTmpDir + '/rm.txt', TBytes.Create(1));
  Check(FsRemove(GTmpDir + '/rm.txt'), 'remove file');
  Check(not FsExists(GTmpDir + '/rm.txt'), 'gone');
end;

procedure TestRemoveNonEmptyDirRaisesInvalidOperation;
var
  LDir, LChild: string;
  LGot: Boolean;
begin
  LDir := GTmpDir + '/rm-nonempty';
  LChild := LDir + '/child.txt';
  FsMkdir(LDir);
  FsWriteFile(LChild, TBytes.Create(1));
  LGot := False;
  try
    FsRemove(LDir);
  except
    on E: EInvalidOperationError do
      LGot := True;
  end;
  Check(LGot, 'FsRemove non-empty directory raises EInvalidOperationError');
  Check(FsIsDir(LDir), 'non-empty dir remains after failed remove');
  Check(FsExists(LChild), 'child remains after failed remove');
end;

procedure TestRemoveMissingPathRaisesNotFound;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    FsRemove(GTmpDir + '/missing-remove-path');
  except
    on E: ENotFoundError do
      LGot := True;
  end;
  Check(LGot, 'FsRemove missing path raises ENotFoundError');
end;

procedure TestRemoveAllMissingPathRaisesNotFound;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    FsRemoveAll(GTmpDir + '/missing-removeall-path');
  except
    on E: ENotFoundError do
      LGot := True;
  end;
  Check(LGot, 'FsRemoveAll missing path raises ENotFoundError');
end;

procedure TestRemoveAllUnsafeRootGuardRaisesInvalidOperation;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    FsRemoveAll('');
  except
    on E: EInvalidOperationError do
      LGot := True;
  end;
  Check(LGot, 'FsRemoveAll empty path raises EInvalidOperationError');
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

procedure TestRenameMissingSourceRaisesNotFound;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    FsRename(GTmpDir + '/missing-rename-source', GTmpDir + '/rename-dst');
  except
    on E: ENotFoundError do
      LGot := True;
  end;
  Check(LGot, 'FsRename missing source raises ENotFoundError');
end;

procedure TestFsErrorNonEmptyDirSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.errors.pas');
  CheckContains(LSource, 'ENOTEMPTY_',
    'POSIX non-empty directory errno is named in fs error mapper');
  CheckContains(LSource, 'ERR_DIR_NOT_EMPTY',
    'Windows non-empty directory error is named in fs error mapper');
  CheckContains(LSource, 'ERROR_DIR_NOT_EMPTY',
    'Windows non-empty directory mapping stays tied to platform kernel32 constant name');
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

{$IFDEF NEXTPAS_LINUX}
function FindDirIteratorFd(const APath: string): Int32;
var
  I: Int32;
  LFdPath: string;
  LBuf: array[0..1023] of AnsiChar;
  LLen: nextpas.core.platform.posix.base.ssize_t;
  LTarget: string;
begin
  Result := -1;
  for I := 3 to 1024 do
  begin
    LFdPath := '/proc/self/fd/' + IntToStr(I);
    FillChar(LBuf, SizeOf(LBuf), 0);
    LLen := nextpas.core.platform.posix.ffi.readlink(PAnsiChar(LFdPath),
      @LBuf[0], SizeOf(LBuf) - 1);
    if LLen <= 0 then
      Continue;
    LBuf[LLen] := #0;
    LTarget := StrPas(@LBuf[0]);
    if LTarget = APath then
      Exit(I);
  end;
end;

procedure TestDirIteratorCloseReportsPlatformError;
var
  LIter: IDirIterator;
  LFd: Int32;
  LGot: Boolean;
begin
  FsMkdir(GTmpDir + '/iter-close-error');
  LIter := FsOpenDir(GTmpDir + '/iter-close-error');
  LFd := FindDirIteratorFd(GTmpDir + '/iter-close-error');
  Check(LFd >= 0, 'found open dir fd');
  Check(nextpas.core.platform.posix.ffi.close(LFd) = 0,
    'external close of dir fd succeeds');

  LGot := False;
  try
    LIter.Close;
  except
    on E: EIOError do
      LGot := True;
  end;
  Check(LGot, 'DirIterator.Close raises EIOError when platform close fails');
end;
{$ENDIF}

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

procedure TestPathExtLongResult;
var
  LExt: string;
  LPath: string;
begin
  LExt := '.' + StringOfChar('x', 2048);
  LPath := 'file' + LExt;
  CheckEqual(LExt, FsPathExt(LPath), 'long extension preserves content');
end;

procedure TestPathChangeExtDotfiles;
begin
  CheckEqual('.gitignore.bak', FsPathChangeExt('.gitignore', '.bak'),
    'dotfile without ext appends new ext');
  CheckEqual('/path/.config.bak', FsPathChangeExt('/path/.config', '.bak'),
    'path dotfile without ext appends new ext');
  CheckEqual('.bashrc.old', FsPathChangeExt('.bashrc.bak', '.old'),
    'dotfile with ext replaces last ext');
end;

procedure TestPathWithoutExtDotfiles;
begin
  CheckEqual('.gitignore', FsPathWithoutExt('.gitignore'),
    'dotfile without ext is preserved');
  CheckEqual('/path/.config', FsPathWithoutExt('/path/.config'),
    'path dotfile without ext is preserved');
  CheckEqual('.bashrc', FsPathWithoutExt('.bashrc.bak'),
    'dotfile with ext removes last ext');
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

procedure TestPathRelative;
begin
  CheckEqual('c/d', FsPathRelative('/a/b', '/a/b/c/d'),
    'relative descendant');
  CheckEqual('../../d/e', FsPathRelative('/a/b/c', '/a/d/e'),
    'relative sibling branch');
  CheckEqual('.', FsPathRelative('/a/b', '/a/b'), 'relative same path');
  CheckEqual('c', FsPathRelative('a/b', 'a/b/c'), 'relative paths supported');
end;

procedure TestPathSplit;
var
  LDir: string;
  LBase: string;
begin
  FsPathSplit('/home/user/file.txt', LDir, LBase);
  CheckEqual('/home/user', LDir, 'FsPathSplit dir with file');
  CheckEqual('file.txt', LBase, 'FsPathSplit base with file');

  FsPathSplit('file.txt', LDir, LBase);
  CheckEqual('.', LDir, 'FsPathSplit no path dir follows fs path contract');
  CheckEqual('file.txt', LBase, 'FsPathSplit no path base');

  FsPathSplit('/', LDir, LBase);
  CheckEqual('/', LDir, 'FsPathSplit root dir');
  CheckEqual('/', LBase, 'FsPathSplit root base');
end;

procedure TestPathSeparatorSourceContract;
var
  LSource, LImpl, LEnsure, LTrim: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.path.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'path separator contract has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));

  LEnsure := ExtractFunctionBody(LImpl,
    'function FsPathEnsureSep(const APath: string): string;',
    'function FsPathTrimSep');
  LTrim := ExtractFunctionBody(LImpl,
    'function FsPathTrimSep(const APath: string): string;',
    'function FsPathChangeExt');

  CheckAbsent(LSource, 'function IsPathSep',
    'fs.path no longer owns separator classification');
  CheckContains(LEnsure, 'platform_path_ensure_sep',
    'ensure separator uses platform path contract');
  CheckContains(LTrim, 'platform_path_trim_sep',
    'trim separator uses platform path contract');
  CheckAbsent(LTrim, 'IsPathSep(APath[L])',
    'trim separator no longer owns separator policy');
end;

procedure TestPathDelegatesPlatformRootContract;
var
  LSource, LImpl, LJoin, LDir, LClean, LIsAbs: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.path.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'fs.path root contract has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));

  LJoin := ExtractFunctionBody(LImpl,
    'function FsPathJoin(const AParts: array of string): string;',
    'function FsPathDir');
  LDir := ExtractFunctionBody(LImpl,
    'function FsPathDir(const APath: string): string;',
    'function FsPathBase');
  LClean := ExtractFunctionBody(LImpl,
    'function FsPathClean(const APath: string): string;',
    'function FsPathAbs');
  LIsAbs := ExtractFunctionBody(LImpl,
    'function FsPathIsAbs(const APath: string): Boolean;',
    'function FsPathEnsureSep');

  CheckContains(LJoin, 'platform_path_join',
    'FsPathJoin delegates root semantics to platform.path');
  CheckContains(LDir, 'platform_path_dirname',
    'FsPathDir delegates root semantics to platform.path');
  CheckContains(LClean, 'platform_path_normalize',
    'FsPathClean delegates root semantics to platform.path');
  CheckContains(LIsAbs, 'platform_path_is_absolute',
    'FsPathIsAbs delegates root semantics to platform.path');
  CheckContains(LImpl, 'platform_path_relative',
    'FsPathRelative delegates relative semantics to platform.path');
  CheckContains(LImpl, 'procedure FsPathSplit',
    'FsPathSplit is part of fs path implementation');
  CheckContains(LImpl, 'platform_path_same_file_name',
    'FsSameFileName delegates name comparison semantics to platform.path');
end;

{$IFDEF NEXTPAS_WINDOWS}
procedure TestWindowsPathWrapperContract;
begin
  Check(FsPathIsAbs('C:\tools'), 'drive absolute is absolute');
  Check(FsPathIsAbs('\\server\share'), 'UNC share is absolute');
  Check(not FsPathIsAbs('C:tools'), 'drive-relative path is not absolute');
  Check(not FsPathIsAbs('\tools'), 'rooted-relative path is not absolute');
  CheckEqual('C:\', FsPathDir('C:\tools'), 'FsPathDir keeps drive root');
  CheckEqual('\\server\share', FsPathDir('\\server\share\file.txt'),
    'FsPathDir keeps UNC share root');
  CheckEqual('C:\bin', FsPathClean('C:\tools\..\bin'),
    'FsPathClean keeps drive root');
  CheckEqual('C:bin', FsPathClean('C:tools\..\bin'),
    'FsPathClean keeps drive-relative volume');
  CheckEqual('\bin', FsPathClean('\tools\..\bin'),
    'FsPathClean keeps rooted-relative root');
  CheckEqual('C:\base\child', FsPathJoin(['C:\base', '\child']),
    'FsPathJoin does not treat rooted-relative child as absolute');
  CheckEqual('C:\', FsPathTrimSep('C:\'), 'FsPathTrimSep preserves drive root');
  CheckEqual('\\server\share', FsPathTrimSep('\\server\share\'),
    'FsPathTrimSep preserves UNC share root');
  Check(FsSameFileName('C:\Tools\App.exe', 'c:\tools\app.EXE'),
    'FsSameFileName is case-insensitive on Windows');
  Check(FsSameFileName('C:\Tools\App.exe', 'C:/Tools/App.exe'),
    'FsSameFileName treats Windows separators equivalently');
end;
{$ENDIF}

procedure TestPathEnsureTrimSep;
begin
  CheckEqual('/tmp/', FsPathEnsureSep('/tmp'), 'ensure sep appends separator');
  CheckEqual('/tmp/', FsPathEnsureSep('/tmp/'), 'ensure sep preserves existing separator');
  CheckEqual('/tmp', FsPathTrimSep('/tmp///'), 'trim sep removes trailing separators');
  CheckEqual('/', FsPathTrimSep('/'), 'trim sep preserves root');
end;

procedure TestSameFileName;
begin
  Check(FsSameFileName('/tmp/file.txt', '/tmp/file.txt'),
    'same file exact match');
  Check(not FsSameFileName('/tmp/File.txt', '/tmp/file.txt'),
    'same file name is case-sensitive on POSIX');
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

procedure TestTempFileSystemDirUsesTypedHandleContract;
var
  LSource, LStreamSource, LImpl, LBody: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.util.pas');
  LStreamSource := LoadSourceText('src/nextpas.core.fs.stream.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'fs.util temp contract has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));
  LBody := ExtractFunctionBody(LImpl,
    'function FsTempFile(const ADir, APattern: string): IFile;',
    'procedure FillFileInfo');

  CheckContains(LBody, 'platform_fs_mktemp_handle',
    'FsTempFile system temp path uses typed platform handle seam');
  CheckContains(LBody, 'FsFromPlatformHandle',
    'FsTempFile system temp path wraps typed platform handle directly');
  CheckAbsent(LBody, 'platform_fs_mktemp(',
    'FsTempFile system temp path does not use legacy Int32 fd mktemp seam');
  CheckAbsent(LBody, 'FsFromHandle',
    'FsTempFile system temp path does not wrap a narrowed Int32 fd');
  CheckContains(LStreamSource,
    'Takes ownership of AHandle; the returned IFile closes it.',
    'FsFromPlatformHandle documents owned handle transfer');
end;

procedure TestFsCwdRoundTrip;
var
  LOldCwd, LNewCwd: string;
begin
  LOldCwd := FsGetCwd;
  FsMkdirAll(GTmpDir + '/cwd-sub');
  try
    FsSetCwd(GTmpDir + '/cwd-sub');
    LNewCwd := FsGetCwd;
    CheckEqual(GTmpDir + '/cwd-sub', LNewCwd, 'FsGetCwd reflects FsSetCwd');
  finally
    FsSetCwd(LOldCwd);
  end;
end;

procedure TestFsSetCwdInvalidPathRaisesNotFound;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    FsSetCwd(GTmpDir + '/missing-cwd-dir');
  except
    on E: ENotFoundError do
      LGot := True;
  end;
  Check(LGot, 'FsSetCwd invalid path raises mapped fs error');
end;

procedure TestFsCwdUsesPlatformOwnerContract;
var
  LSource, LImpl, LGetBody, LSetBody: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.util.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'fs.util cwd contract has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));
  LGetBody := ExtractFunctionBody(LImpl,
    'function FsGetCwd: string;',
    'procedure FsSetCwd');
  LSetBody := ExtractFunctionBody(LImpl,
    'procedure FsSetCwd(const APath: string);',
    'function FsGetEnv');

  CheckContains(LGetBody, 'platform_file_getcwd',
    'FsGetCwd delegates to platform file owner');
  CheckContains(LSetBody, 'platform_file_chdir',
    'FsSetCwd delegates to platform file owner');
  CheckAbsent(LGetBody, 'GetDir(',
    'FsGetCwd does not call raw FPC GetDir');
  CheckAbsent(LSetBody, 'ChDir(',
    'FsSetCwd does not call raw FPC ChDir');
end;

procedure TestFsGetEnvInvalidNameRaises;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    FsGetEnv('');
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'FsGetEnv invalid name delegates to os.env validation');
end;

procedure TestFsGetEnvUsesOsEnvOwnerContract;
var
  LSource, LImpl, LBody: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.util.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'fs.util env contract has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));
  LBody := ExtractFunctionBody(LImpl,
    'function FsGetEnv(const AName: string): string;',
    'end.');

  CheckContains(LSource, 'nextpas.core.os.env',
    'fs.util imports os.env owner');
  CheckContains(LBody, 'GetEnvironmentVariable(AName)',
    'FsGetEnv delegates value lookup to os.env owner');
  CheckAbsent(LSource, 'BaseUnix',
    'fs.util does not import raw FPC BaseUnix env owner');
  CheckAbsent(LSource, 'fpGetEnv',
    'fs.util does not call raw FPC fpGetEnv');
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

procedure TestRemoveSymlinkToDirUnlinksLink;
var
  LTarget, LLink: string;
begin
  LTarget := GTmpDir + '/rmtarget_single';
  LLink := GTmpDir + '/rmlink_single';
  FsMkdir(LTarget);
  FsWriteFile(LTarget + '/keep.txt', TBytes.Create(99));
  if nextpas.core.platform.posix.ffi.symlink(PAnsiChar(LTarget), PAnsiChar(LLink)) <> 0 then
  begin
    Check(True, 'symlink unsupported, skip');
    Exit;
  end;
  Check(FsRemove(LLink), 'remove symlink-to-dir returns true');
  Check(not FsExists(LLink), 'symlink-to-dir link removed');
  Check(FsExists(LTarget + '/keep.txt'), 'symlink-to-dir target tree intact');
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

procedure TestSymlinkReadlinkLongTarget;
var
  LTarget, LLink, LRead: string;
begin
  LTarget := StringOfChar('t', 1500);
  LLink := GTmpDir + '/symlink-long-target.txt';
  FsSymlink(LTarget, LLink);
  LRead := FsReadlink(LLink);
  CheckEqual(Int64(Length(LTarget)), Int64(Length(LRead)),
    'readlink long target length');
  CheckEqual(LTarget, LRead, 'readlink long target content');
end;

procedure TestReadlinkRegularFileRaisesInvalidOperation;
var
  LGot: Boolean;
begin
  FsWriteFile(GTmpDir + '/readlink-regular.txt', TBytes.Create(1));
  LGot := False;
  try
    FsReadlink(GTmpDir + '/readlink-regular.txt');
  except
    on E: EInvalidOperationError do
      LGot := True;
  end;
  Check(LGot, 'readlink regular file raises invalid operation');
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
{$IFDEF NEXTPAS_LINUX}
    T.Run('WriteFile raises on short write', @TestWriteFileRaisesOnShortWrite);
    T.Run('AppendFile raises on short write', @TestAppendFileRaisesOnShortWrite);
{$ENDIF}
    T.Run('Exists', @TestExists);
    T.Run('IsFile/IsDir', @TestIsFileIsDir);
    T.Run('FileSize', @TestFileSize);

    T.Run('Mkdir + ReadDir', @TestMkdirAndReadDir);
    T.Run('MkdirAll', @TestMkdirAll);
    T.Run('Mkdir existing file raises already exists',
      @TestMkdirExistingFileRaisesAlreadyExists);
    T.Run('MkdirAll existing file child raises invalid operation',
      @TestMkdirAllExistingFileChildRaisesInvalidOperation);
    T.Run('Remove', @TestRemove);
    T.Run('Remove non-empty dir raises invalid operation',
      @TestRemoveNonEmptyDirRaisesInvalidOperation);
    T.Run('Remove missing path raises not found',
      @TestRemoveMissingPathRaisesNotFound);
    T.Run('RemoveAll missing path raises not found',
      @TestRemoveAllMissingPathRaisesNotFound);
    T.Run('RemoveAll unsafe root guard raises invalid operation',
      @TestRemoveAllUnsafeRootGuardRaisesInvalidOperation);
    T.Run('RemoveAll', @TestRemoveAll);
    T.Run('Rename', @TestRename);
    T.Run('Rename missing source raises not found',
      @TestRenameMissingSourceRaisesNotFound);
    T.Run('Fs error non-empty dir source contract',
      @TestFsErrorNonEmptyDirSourceContract);
    T.Run('DirIterator', @TestDirIterator);
{$IFDEF NEXTPAS_LINUX}
    T.Run('DirIterator close reports platform error',
      @TestDirIteratorCloseReportsPlatformError);
{$ENDIF}

    T.Run('PathJoin', @TestPathJoin);
    T.Run('PathDir', @TestPathDir);
    T.Run('PathBase', @TestPathBase);
    T.Run('PathExt', @TestPathExt);
    T.Run('PathExt long result', @TestPathExtLongResult);
    T.Run('PathChangeExt dotfiles', @TestPathChangeExtDotfiles);
    T.Run('PathWithoutExt dotfiles', @TestPathWithoutExtDotfiles);
    T.Run('PathIsAbs', @TestPathIsAbs);
    T.Run('PathClean empty', @TestPathCleanEmpty);
    T.Run('PathRelative', @TestPathRelative);
    T.Run('PathSplit', @TestPathSplit);
    T.Run('Path separator source contract', @TestPathSeparatorSourceContract);
    T.Run('Path delegates platform root contract', @TestPathDelegatesPlatformRootContract);
{$IFDEF NEXTPAS_WINDOWS}
    T.Run('Windows path wrapper contract', @TestWindowsPathWrapperContract);
{$ENDIF}
    T.Run('PathEnsureSep/PathTrimSep', @TestPathEnsureTrimSep);
    T.Run('SameFileName', @TestSameFileName);
    T.Run('PathJoin long', @TestPathLong);

    T.Run('Open not found', @TestOpenNotFound);
    T.Run('Close invalid handle raises', @TestCloseInvalidHandleRaises);

    T.Run('Append', @TestAppend);
    T.Run('Exclusive create', @TestExclusive);
    T.Run('ReadAt position-independent', @TestReadAtPositionIndependent);
    T.Run('Chmod + perm', @TestChmodAndPerm);
    T.Run('Truncate path', @TestTruncatePath);
    T.Run('TempFile in dir', @TestTempFileInDir);
    T.Run('TempFile system dir typed handle contract',
      @TestTempFileSystemDirUsesTypedHandleContract);
    T.Run('FsGetCwd/FsSetCwd roundtrip', @TestFsCwdRoundTrip);
    T.Run('FsSetCwd invalid path raises mapped fs error',
      @TestFsSetCwdInvalidPathRaisesNotFound);
    T.Run('FsGetCwd/FsSetCwd use platform owner contract',
      @TestFsCwdUsesPlatformOwnerContract);
    T.Run('FsGetEnv invalid name raises', @TestFsGetEnvInvalidNameRaises);
    T.Run('FsGetEnv uses os.env owner contract',
      @TestFsGetEnvUsesOsEnvOwnerContract);
    T.Run('Lstat', @TestLstat);
{$IFDEF NEXTPAS_UNIX}
    T.Run('RemoveAll symlink root', @TestRemoveAllSymlinkRoot);
    T.Run('Remove symlink-to-dir unlinks link', @TestRemoveSymlinkToDirUnlinksLink);
    T.Run('Symlink + Readlink', @TestSymlinkReadlink);
    T.Run('Symlink + Readlink long target', @TestSymlinkReadlinkLongTarget);
    T.Run('Readlink regular file raises invalid operation', @TestReadlinkRegularFileRaisesInvalidOperation);
{$ENDIF}

    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.
