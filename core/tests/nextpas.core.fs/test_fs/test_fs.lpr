program test_fs;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.io.base,
  nextpas.core.io.intf,
{$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi,
{$ENDIF}
  nextpas.core.platform.process,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
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
  nextpas.core.io.scanner,
  nextpas.core.io.mapped,
  nextpas.core.fs;

var
  T: TTestSuite;
  GTmpDir: string;
  GWalkErrorSeen: Boolean;
  GWalkErrorPath: string;

  { FsWalk success-path capture state }
  GWalkVisited: TStringArray;
  GWalkFileTypes: array of TFileType;
  GWalkStopCount: Integer;

function HasVisitedPath(const APath: string): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to High(GWalkVisited) do
    if GWalkVisited[I] = APath then
      Exit(True);
  Result := False;
end;

function WalkCaptureCallback(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception): Boolean;
var
  LIndex: SizeInt;
begin
  Check(AErr = nil, 'success walk callback should not receive error');
  LIndex := Length(GWalkVisited);
  SetLength(GWalkVisited, LIndex + 1);
  SetLength(GWalkFileTypes, LIndex + 1);
  GWalkVisited[LIndex] := APath;
  GWalkFileTypes[LIndex] := AInfo.FileType;
  Result := True;
end;

function WalkStopAfterTwoCallback(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception): Boolean;
begin
  Inc(GWalkStopCount);
  Result := GWalkStopCount < 2;
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := FsPathAbs('../../../' + ARelativePath);
  Check(FsExists(LSourcePath), 'source exists: ' + ARelativePath);
  Result := FsReadFileText(LSourcePath);
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

{$I ../../fpc_rtl_uses_scan.inc}

procedure AssertSourceNoBareFpcRtlUses(const ALabel, ASource: string);
var
  LHit: string;
  LOk: Boolean;
  LMsg: string;
begin
  LOk := not FindBareFpcRtlInUses(ASource, LHit);
  LMsg := ALabel + ' — no bare FPC RTL in uses';
  if not LOk then
    LMsg := LMsg + ' (hit: ' + LHit + ')';
  Check(LOk, LMsg);
end;

procedure TestFsOwnedSourcesNoFpcRtl;
var
  LFiles: array[0..8] of string;
  LI: Integer;
begin
  LFiles[0] := 'src/nextpas.core.fs.pas';
  LFiles[1] := 'src/nextpas.core.fs.base.pas';
  LFiles[2] := 'src/nextpas.core.fs.dir.pas';
  LFiles[3] := 'src/nextpas.core.fs.errors.pas';
  LFiles[4] := 'src/nextpas.core.fs.glob.pas';
  LFiles[5] := 'src/nextpas.core.fs.intf.pas';
  LFiles[6] := 'src/nextpas.core.fs.path.pas';
  LFiles[7] := 'src/nextpas.core.fs.stream.pas';
  LFiles[8] := 'src/nextpas.core.fs.util.pas';
  for LI := 0 to High(LFiles) do
    AssertSourceNoBareFpcRtlUses('fs src ' + LFiles[LI], LoadSourceText(LFiles[LI]));
end;

procedure TestFsTestSuitesNoFpcRtl;
var
  LFiles: array[0..5] of string;
  LI: Integer;
begin
  LFiles[0] := 'tests/nextpas.core.fs/test_fs/test_fs.lpr';
  LFiles[1] := 'tests/nextpas.core.fs/test_fs_facade/test_fs_facade.lpr';
  LFiles[2] := 'tests/nextpas.core.fs/test_fs_glob/test_fs_glob.lpr';
  LFiles[3] := 'tests/nextpas.core.fs/test_fs_idir/test_fs_idir.lpr';
  LFiles[4] := 'tests/nextpas.core.fs/test_fs_ifile/test_fs_ifile.lpr';
  LFiles[5] := 'tests/nextpas.core.fs/test_fs_text/test_fs_text.lpr';
  for LI := 0 to High(LFiles) do
    AssertSourceNoBareFpcRtlUses('fs test ' + LFiles[LI], LoadSourceText(LFiles[LI]));
end;

function WalkErrorCallback(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception): Boolean;
begin
  if AErr <> nil then
  begin
    GWalkErrorSeen := True;
    GWalkErrorPath := APath;
  end;
  Result := True;
end;

procedure SetupTmpDir;
begin
  GTmpDir := '/tmp/nextpas_fs_test_' + IntToStr(platform_getpid);
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

procedure TestFsWriteFileText;
var
  LText: string;
begin
  FsWriteFileText(GTmpDir + '/writetext.txt', 'Hello, World!');
  LText := FsReadFileText(GTmpDir + '/writetext.txt');
  CheckEqual('Hello, World!', LText, 'FsWriteFileText basic');
  { Overwrite }
  FsWriteFileText(GTmpDir + '/writetext.txt', 'Overwritten');
  LText := FsReadFileText(GTmpDir + '/writetext.txt');
  CheckEqual('Overwritten', LText, 'FsWriteFileText overwrite');
end;

procedure TestFsWriteFileLines;
var
  LLines: TStringArray;
  LRead: TStringArray;
begin
  LLines := TStringArray.Create('line1', 'line2', 'line3');
  FsWriteFileLines(GTmpDir + '/writelines.txt', LLines);
  LRead := FsReadFileLines(GTmpDir + '/writelines.txt');
  CheckEqual(Int64(3), Int64(Length(LRead)), 'FsWriteFileLines line count');
  CheckEqual('line1', LRead[0], 'FsWriteFileLines line 1');
  CheckEqual('line2', LRead[1], 'FsWriteFileLines line 2');
  CheckEqual('line3', LRead[2], 'FsWriteFileLines line 3');
end;

procedure TestFsWriteFileLines_Empty;
var
  LLines: TStringArray;
begin
  LLines := nil;
  FsWriteFileLines(GTmpDir + '/writelines_empty.txt', LLines);
  CheckEqual(Int64(0), FsFileSize(GTmpDir + '/writelines_empty.txt'),
    'FsWriteFileLines empty array creates empty file');
end;

procedure TestFsAppendFileLines;
var
  LRead: TStringArray;
begin
  { Write initial content with trailing newline }
  FsWriteFileText(GTmpDir + '/applines.txt', 'first'#10);
  { Append lines }
  FsAppendFileLines(GTmpDir + '/applines.txt',
    TStringArray.Create('second', 'third'));
  LRead := FsReadFileLines(GTmpDir + '/applines.txt');
  CheckEqual(Int64(3), Int64(Length(LRead)), 'FsAppendFileLines line count');
  CheckEqual('first', LRead[0], 'FsAppendFileLines line 1');
  CheckEqual('second', LRead[1], 'FsAppendFileLines line 2');
  CheckEqual('third', LRead[2], 'FsAppendFileLines line 3');
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
  { 内核 ABI 布局：handler(8) + mask(128) + flags(8) + restorer(8) = 152 字节。
    注意：平台 TSigAction 字段顺序不同，不可直接用于 sigaction 裸调用。 }
  TLibcSigSet = record
    Bits: array[0..15] of QWord;
  end;
  TLibcSigAction = record
    sa_handler: Pointer;
    sa_mask: TLibcSigSet;
    sa_flags: culong;
    sa_restorer: Pointer;
  end;

function BeginShortWriteRegression(out AOldLimit: TRLimit;
  out AOldAct: TLibcSigAction): Boolean;
var
  LIgnoreAct: TLibcSigAction;
  LNewLimit: TRLimit;
begin
  Result := False;
  if nextpas.core.platform.posix.ffi.getrlimit(RLIMIT_FSIZE, @AOldLimit) <> 0 then
    Exit;
  if AOldLimit.rlim_max < 4 then
    Exit;

  FillChar(LIgnoreAct, SizeOf(LIgnoreAct), 0);
  LIgnoreAct.sa_handler := Pointer(SIG_IGN);
  Check(nextpas.core.platform.linux.ffi.sigaction(SIGXFSZ,
    @LIgnoreAct, @AOldAct) = 0,
    'ignore SIGXFSZ during short-write regression');
  LNewLimit := AOldLimit;
  LNewLimit.rlim_cur := 4;
  Check(nextpas.core.platform.posix.ffi.setrlimit(RLIMIT_FSIZE,
    @LNewLimit) = 0,
    'lower file-size limit for short-write regression');
  Result := True;
end;

procedure EndShortWriteRegression(const AOldLimit: TRLimit;
  const AOldAct: TLibcSigAction);
begin
  Check(nextpas.core.platform.posix.ffi.setrlimit(RLIMIT_FSIZE,
    @AOldLimit) = 0,
    'restore file-size limit');
  Check(nextpas.core.platform.linux.ffi.sigaction(SIGXFSZ,
    @AOldAct, nil) = 0,
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

procedure TestIsSymlink;
var
  LTarget, LLink: string;
begin
  LTarget := GTmpDir + '/isym-target.txt';
  LLink := GTmpDir + '/isym-link.txt';
  FsWriteFile(LTarget, TBytes.Create(1));
  Check(not FsIsSymlink(LTarget), 'regular file not symlink');
  Check(not IsSymlink(LTarget), 'facade regular not symlink');
  Check(not FsIsSymlink(GTmpDir + '/no-such-isym'), 'missing not symlink');
  FsSymlink(LTarget, LLink);
  Check(FsIsSymlink(LLink), 'FsIsSymlink true');
  Check(IsSymlink(LLink), 'facade IsSymlink true');
  Check(not FsIsSymlink(GTmpDir), 'dir not symlink');
end;

procedure TestSameFile;
var
  LPath, LHard: string;
  LRaised: Boolean;
begin
  LPath := GTmpDir + '/samefile-a.txt';
  FsWriteFile(LPath, TBytes.Create(1, 2, 3));
  Check(SameFile(LPath, LPath), 'same path is same file');
  Check(FsSameFile(LPath, LPath), 'FsSameFile path');
  LRaised := False;
  try
    SameFile(LPath, GTmpDir + '/no-such-samefile');
  except
    on E: ENotFoundError do
      LRaised := True;
  end;
  Check(LRaised, 'SameFile missing raises ENotFoundError');
  LHard := GTmpDir + '/samefile-b.txt';
  FsWriteFile(LHard, TBytes.Create(9));
  Check(not SameFile(LPath, LHard), 'distinct files not same');
end;

procedure TestSymlinkRelativeTarget;
var
  LLink, LRead: string;
begin
  LLink := GTmpDir + '/rel-link';
  FsSymlink('relative-target', LLink);
  LRead := FsReadlink(LLink);
  CheckEqual('relative-target', LRead, 'readlink keeps relative target');
end;

{ FsRealPath：整链解析——末端/中间段符号链接展开、不存在 → ENotFoundError、
  相对目标拼接父目录 }
procedure TestRealPath;
var
  LBase, LDir, LReal, LLink, LMidDir, LMidLink, LFile, LRes: string;
  LRaised: Boolean;
begin
  { 基准 canonical 前缀（GTmpDir 自身无符号链接段；断言用字面期望后缀，
    杜绝「两个 FsRealPath 调用互比」的自我参照——曾掩盖返回根 '/' 的 bug） }
  LBase := FsRealPath(GTmpDir);
  CheckTrue(LBase <> '', 'base canonical non-empty');
  CheckTrue(LBase <> '/', 'base canonical is not root');

  LDir := GTmpDir + '/realpath-dir';
  MkdirAll(LDir, PermDirDefault);
  LReal := LDir + '/real-sub';
  MkdirAll(LReal, PermDirDefault);
  LFile := LReal + '/f.txt';
  FsWriteFile(LFile, TBytes.Create(Ord('x')));

  { 普通既有路径 → canonical 化（字面期望：基准 + 相对后缀） }
  LRes := FsRealPath(LFile);
  CheckEqual(LBase + '/realpath-dir/real-sub/f.txt', LRes,
    'plain path canonicalized');
  CheckTrue(FsExists(LRes), 'realpath resolves to existing path');

  { 末端 symlink：link → real-sub；link/f.txt 解析到 real-sub/f.txt }
  LLink := LDir + '/end-link';
  FsSymlink('real-sub', LLink);
  LRes := FsRealPath(LLink + '/f.txt');
  CheckEqual(LBase + '/realpath-dir/real-sub/f.txt', LRes,
    'end symlink resolved');

  { 中间段 symlink：link → real-sub；link 下再套一层真实目录 }
  LMidDir := LReal + '/mid';
  MkdirAll(LMidDir, PermDirDefault);
  FsWriteFile(LMidDir + '/m.txt', TBytes.Create(Ord('y')));
  LMidLink := LDir + '/mid-link';
  FsSymlink('real-sub', LMidLink);
  LRes := FsRealPath(LMidLink + '/mid/m.txt');
  CheckEqual(LBase + '/realpath-dir/real-sub/mid/m.txt', LRes,
    'mid symlink resolved');

  { 绝对目标 symlink：abs-link → 绝对路径 }
  LMidDir := LDir + '/linker';
  MkdirAll(LMidDir, PermDirDefault);
  FsWriteFile(LMidDir + '/t.txt', TBytes.Create(Ord('z')));
  FsSymlink(LBase + '/realpath-dir/linker/t.txt', LMidDir + '/abs-link');
  LRes := FsRealPath(LMidDir + '/abs-link');
  CheckEqual(LBase + '/realpath-dir/linker/t.txt', LRes,
    'absolute target link resolved');

  { 不存在 → ENotFoundError }
  LRaised := False;
  try
    FsRealPath(GTmpDir + '/no-such-realpath');
  except
    on E: ENotFoundError do
      LRaised := True;
  end;
  Check(LRaised, 'missing path raises ENotFoundError');
end;

procedure TestReadFileMissingNotFound;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    FsReadFile(GTmpDir + '/no-read-file');
  except
    on E: ENotFoundError do
      LRaised := True;
  end;
  Check(LRaised, 'ReadFile missing raises ENotFoundError');
end;

procedure TestWriteAtomicMissingParentRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    FsWriteAtomic(GTmpDir + '/no-parent-r17/nested/atomic.bin',
      TBytes.Create(1, 2));
  except
    on E: ENotFoundError do
      LRaised := True;
    on E: EIOError do
      LRaised := True;
  end;
  Check(LRaised, 'WriteAtomic missing parent raises');
end;

procedure TestCopyFileMissingSourceRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    FsCopyFile(GTmpDir + '/no-copy-src', GTmpDir + '/no-copy-dst');
  except
    on E: ENotFoundError do
      LRaised := True;
  end;
  Check(LRaised, 'CopyFile missing source raises ENotFoundError');
end;

procedure TestWriteFileEmptyRoundtrip;
var
  LRead: TBytes;
begin
  FsWriteFile(GTmpDir + '/empty-r17.bin', nil);
  LRead := FsReadFile(GTmpDir + '/empty-r17.bin');
  CheckEqual(Int64(0), Int64(Length(LRead)), 'empty file len 0');
  Check(FsExists(GTmpDir + '/empty-r17.bin'), 'empty file exists');
  CheckEqual(Int64(0), FsFileSize(GTmpDir + '/empty-r17.bin'), 'empty size 0');
end;

procedure TestAppendFileTextRoundtrip;
begin
  FsWriteFileText(GTmpDir + '/append-r17.txt', 'a');
  FsAppendFileText(GTmpDir + '/append-r17.txt', 'b');
  CheckEqual('ab', FsReadFileText(GTmpDir + '/append-r17.txt'), 'append text');
end;

procedure TestAppendFileLineRoundtrip;
var
  LText: string;
begin
  FsWriteFileText(GTmpDir + '/line-r17.txt', '');
  AppendFileLine(GTmpDir + '/line-r17.txt', 'one');
  AppendFileLine(GTmpDir + '/line-r17.txt', 'two');
  LText := FsReadFileText(GTmpDir + '/line-r17.txt');
  Check(Pos('one', LText) > 0, 'line one');
  Check(Pos('two', LText) > 0, 'line two');
end;

procedure TestExistsFalseForMissing;
begin
  Check(not FsExists(GTmpDir + '/definitely-missing-r17'), 'missing false');
  Check(not Exists(GTmpDir + '/definitely-missing-r17'), 'facade missing false');
end;

procedure TestIsFileIsDirEdges;
begin
  FsWriteFile(GTmpDir + '/isfile-r17.txt', TBytes.Create(1));
  FsMkdir(GTmpDir + '/isdir-r17');
  Check(FsIsFile(GTmpDir + '/isfile-r17.txt'), 'is file');
  Check(not FsIsDir(GTmpDir + '/isfile-r17.txt'), 'file not dir');
  Check(FsIsDir(GTmpDir + '/isdir-r17'), 'is dir');
  Check(not FsIsFile(GTmpDir + '/isdir-r17'), 'dir not file');
  Check(not FsIsFile(GTmpDir + '/no-isfile'), 'missing not file');
  Check(not FsIsDir(GTmpDir + '/no-isdir'), 'missing not dir');
end;

procedure TestRemoveMissingSilent;
begin
  FsRemove(GTmpDir + '/never-existed-r17');
  Check(True, 'Remove missing silent');
  Check(not FsExists(GTmpDir + '/never-existed-r17'), 'still missing');
end;

procedure TestRenameRoundtrip;
begin
  FsWriteFile(GTmpDir + '/ren-src-r17.txt', TBytes.Create(7));
  FsRename(GTmpDir + '/ren-src-r17.txt', GTmpDir + '/ren-dst-r17.txt');
  Check(not FsExists(GTmpDir + '/ren-src-r17.txt'), 'src gone');
  Check(FsExists(GTmpDir + '/ren-dst-r17.txt'), 'dst present');
  CheckEqual(Int64(1), FsFileSize(GTmpDir + '/ren-dst-r17.txt'), 'renamed size');
end;

procedure TestTruncatePathToZero;
begin
  FsWriteFile(GTmpDir + '/trunc-r17.bin', TBytes.Create(1, 2, 3, 4));
  FsTruncate(GTmpDir + '/trunc-r17.bin', 0);
  CheckEqual(Int64(0), FsFileSize(GTmpDir + '/trunc-r17.bin'), 'truncated zero');
end;

procedure TestChmodReadWrite;
var
  LInfo: TFileInfo;
begin
  FsWriteFile(GTmpDir + '/chmod-r17.txt', TBytes.Create(1));
  FsChmod(GTmpDir + '/chmod-r17.txt', PermDefault); { 0644 }
  LInfo := FsStat(GTmpDir + '/chmod-r17.txt');
  Check(LInfo.Size = 1, 'chmod file size');
  Check(FsIsFile(GTmpDir + '/chmod-r17.txt'), 'still file after chmod');
end;

procedure TestSameFileEmptyPathRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    SameFile('', GTmpDir + '/x');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'SameFile empty path raises EArgumentError');
end;

procedure TestWriteAtomicOverwrite;
var
  LRead: TBytes;
begin
  FsWriteAtomic(GTmpDir + '/atomic-ow.bin', TBytes.Create(1));
  FsWriteAtomic(GTmpDir + '/atomic-ow.bin', TBytes.Create(9, 8));
  LRead := FsReadFile(GTmpDir + '/atomic-ow.bin');
  CheckEqual(Int64(2), Int64(Length(LRead)), 'atomic overwrite len');
  CheckEqual(Byte(9), LRead[0], 'atomic overwrite first byte');
end;

procedure TestReadFileTextEmpty;
begin
  FsWriteFile(GTmpDir + '/empty-text-r17.txt', nil);
  CheckEqual('', FsReadFileText(GTmpDir + '/empty-text-r17.txt'), 'empty text');
end;

procedure TestEnsureFileIdempotent;
begin
  FsEnsureFile(GTmpDir + '/ensure-r17.txt');
  Check(FsExists(GTmpDir + '/ensure-r17.txt'), 'ensure creates');
  FsWriteFileText(GTmpDir + '/ensure-r17.txt', 'keep');
  FsEnsureFile(GTmpDir + '/ensure-r17.txt');
  CheckEqual('keep', FsReadFileText(GTmpDir + '/ensure-r17.txt'), 'ensure preserves');
end;

procedure TestTempDirIsDirectory;
var
  LDir: string;
begin
  LDir := FsTempDir(GTmpDir, 'r17tmp*');
  try
    Check(FsIsDir(LDir), 'temp dir is dir');
    Check(FsExists(LDir), 'temp dir exists');
  finally
    FsRemoveAll(LDir);
  end;
end;


procedure TestStatMissingR19;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    FsStat(GTmpDir + '/no-stat-r19');
  except
    on E: ENotFoundError do
      LRaised := True;
  end;
  Check(LRaised, 'r19 Stat missing ENotFound');
end;

procedure TestOpenMissingR19;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    Open(GTmpDir + '/no-open-r19', [fmRead]);
  except
    on E: ENotFoundError do
      LRaised := True;
  end;
  Check(LRaised, 'r19 Open missing ENotFound');
end;

procedure TestReadlinkMissingR19;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    FsReadlink(GTmpDir + '/no-link-r19');
  except
    on E: ENotFoundError do
      LRaised := True;
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'r19 Readlink missing raises');
end;

procedure TestWriteFileRoundtripR19;
begin
  FsWriteFileText(GTmpDir + '/wr-r19.txt', 'hello-r19');
  CheckEqual('hello-r19', FsReadFileText(GTmpDir + '/wr-r19.txt'), 'r19 write read');
  Check(FsIsFile(GTmpDir + '/wr-r19.txt'), 'r19 is file');
  Check(not FsIsDir(GTmpDir + '/wr-r19.txt'), 'r19 not dir');
end;

procedure TestMkdirAllIdempotentR19;
begin
  FsMkdirAll(GTmpDir + '/mk-r19/a/b');
  FsMkdirAll(GTmpDir + '/mk-r19/a/b');
  Check(FsIsDir(GTmpDir + '/mk-r19/a/b'), 'r19 mkdirall idem');
end;

procedure TestCopyFileRoundtripR19;
var
  N: Int64;
begin
  FsWriteFile(GTmpDir + '/cp-src-r19.bin', TBytes.Create(1, 2, 3));
  N := FsCopyFile(GTmpDir + '/cp-src-r19.bin', GTmpDir + '/cp-dst-r19.bin');
  CheckEqual(Int64(3), N, 'r19 copy n');
  Check(FsExists(GTmpDir + '/cp-dst-r19.bin'), 'r19 copy exists');
end;

procedure TestRenameThenMissingR19;
begin
  FsWriteFile(GTmpDir + '/rn-src-r19', TBytes.Create(1));
  FsRename(GTmpDir + '/rn-src-r19', GTmpDir + '/rn-dst-r19');
  Check(not FsExists(GTmpDir + '/rn-src-r19'), 'r19 rename src gone');
  Check(FsExists(GTmpDir + '/rn-dst-r19'), 'r19 rename dst');
end;

procedure TestIsSymlinkFacadeR19;
var
  LTarget, LLink: string;
begin
  LTarget := GTmpDir + '/sym-t-r19';
  LLink := GTmpDir + '/sym-l-r19';
  FsWriteFile(LTarget, TBytes.Create(1));
  Check(not IsSymlink(LTarget), 'r19 not symlink file');
  FsSymlink(LTarget, LLink);
  Check(IsSymlink(LLink), 'r19 is symlink');
  Check(not IsSymlink(GTmpDir + '/no-sym-r19'), 'r19 missing not symlink');
end;

procedure TestSameFileSelfR19;
var
  P: string;
begin
  P := GTmpDir + '/same-r19.txt';
  FsWriteFile(P, TBytes.Create(9));
  Check(SameFile(P, P), 'r19 same self');
end;

procedure TestSameFileMissingR19;
var
  P: string;
  LRaised: Boolean;
begin
  P := GTmpDir + '/same-r19b.txt';
  FsWriteFile(P, TBytes.Create(1));
  LRaised := False;
  try
    SameFile(P, GTmpDir + '/same-r19-other.txt');
  except
    on E: ENotFoundError do
      LRaised := True;
  end;
  Check(LRaised, 'r19 same other missing raises');
end;

procedure TestFileSizeAfterWriteR19;
begin
  FsWriteFile(GTmpDir + '/sz-r19.bin', TBytes.Create(1, 2, 3, 4, 5));
  CheckEqual(Int64(5), FsFileSize(GTmpDir + '/sz-r19.bin'), 'r19 size 5');
end;

procedure TestGetCwdNonEmptyR19;
begin
  Check(FsGetCwd <> '', 'r19 cwd non-empty');
  Check(GetCwd <> '', 'r19 facade cwd');
end;

procedure TestTempFileWritableR19;
var
  F: IFile;
  P: string;
begin
  F := FsTempFile(GTmpDir, 'r19tf*');
  P := F.Name;
  Check(P <> '', 'r19 temp path');
  Check(FsExists(P), 'r19 temp exists');
end;



procedure TestExistsR19Extra;
begin
  FsWriteFile(GTmpDir + '/ex-r19', TBytes.Create(1));
  Check(FsExists(GTmpDir + '/ex-r19'), 'r19ex1');
  Check(Exists(GTmpDir + '/ex-r19'), 'r19ex2');
  Check(not FsExists(GTmpDir + '/ex-r19-no'), 'r19ex3');
end;

procedure TestReadDirHasFileR19Extra;
var
  E: TDirEntryArray;
  I: Integer;
  Found: Boolean;
begin
  FsMkdir(GTmpDir + '/rd-r19');
  FsWriteFile(GTmpDir + '/rd-r19/f.txt', TBytes.Create(1));
  E := FsReadDir(GTmpDir + '/rd-r19');
  Found := False;
  for I := 0 to High(E) do
    if E[I].Name = 'f.txt' then
      Found := True;
  Check(Found, 'r19rd found');
end;

procedure TestRemoveFileR19Extra;
begin
  FsWriteFile(GTmpDir + '/rm-r19', TBytes.Create(1));
  FsRemove(GTmpDir + '/rm-r19');
  Check(not FsExists(GTmpDir + '/rm-r19'), 'r19rm gone');
end;

procedure TestChmodExistsR19Extra;
begin
  FsWriteFile(GTmpDir + '/ch-r19', TBytes.Create(1));
  FsChmod(GTmpDir + '/ch-r19', PermDefault);
  Check(FsIsFile(GTmpDir + '/ch-r19'), 'r19ch still file');
end;

procedure TestTruncateR19Extra;
begin
  FsWriteFile(GTmpDir + '/tr-r19', TBytes.Create(1, 2, 3, 4));
  FsTruncate(GTmpDir + '/tr-r19', 2);
  CheckEqual(Int64(2), FsFileSize(GTmpDir + '/tr-r19'), 'r19tr size');
end;


procedure TestHardLinkR20;
var
  A, B: string;
begin
  A := GTmpDir + '/hl-a-r20.bin';
  B := GTmpDir + '/hl-b-r20.bin';
  FsWriteFile(A, TBytes.Create(1, 2, 3));
  HardLink(A, B);
  Check(SameFile(A, B), 'r20 hardlink samefile');
  CheckEqual(Int64(3), FsFileSize(B), 'r20 hardlink size');
  FsWriteFile(A, TBytes.Create(9, 9));
  CheckEqual(Int64(2), FsFileSize(B), 'r20 hardlink shared data');
end;

procedure TestHardLinkMissingR20;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HardLink(GTmpDir + '/no-hl-src', GTmpDir + '/no-hl-dst');
  except
    on E: ENotFoundError do
      LRaised := True;
  end;
  Check(LRaised, 'r20 hardlink missing src');
end;

procedure TestHardLinkEmptyR20;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HardLink('', GTmpDir + '/x');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'r20 hardlink empty');
end;

procedure TestChtimesR20;
var
  P: string;
  Info: TFileInfo;
  At, Mt: Int64;
begin
  P := GTmpDir + '/chtimes-r20.txt';
  FsWriteFileText(P, 't');
  At := Int64(1000000000) * 1600000000;
  Mt := Int64(1000000000) * 1600000500;
  Chtimes(P, At, Mt);
  Info := Stat(P);
  Check(Abs(Info.AccessTime - At) < 2000000000, 'r20 atime');
  Check(Abs(Info.ModTime - Mt) < 2000000000, 'r20 mtime');
end;

procedure TestChtimesMissingR20;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    Chtimes(GTmpDir + '/no-ct-r20', 0, 0);
  except
    on E: ENotFoundError do
      LRaised := True;
  end;
  Check(LRaised, 'r20 chtimes missing');
end;

procedure TestChownSelfR20;
var
  P: string;
  S: TPlatformFileStat;
begin
  P := GTmpDir + '/chown-r20.txt';
  FsWriteFileText(P, 'c');
  Check(platform_file_stat(PAnsiChar(P), S) = 0, 'r20 chown pre-stat');
  Chown(P, S.Uid, S.Gid);
  Check(FsExists(P), 'r20 chown self ok');
end;

procedure TestChownMissingR20;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    Chown(GTmpDir + '/no-chown-r20', 0, 0);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'r20 chown missing raises');
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
  FsMkdirAll(GTmpDir + '/a/b/c');
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
  FsRemove(GTmpDir + '/rm.txt');
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

procedure TestRemoveMissingPathReturnsTrue;
begin
  { FsRemove treats missing paths as success (Pascal Erase/DeleteFile) }
  FsRemove(GTmpDir + '/missing-remove-path');
  Check(True, 'FsRemove missing path does not raise');
end;

procedure TestRemoveAllMissingPathReturnsTrue;
begin
  FsRemoveAll(GTmpDir + '/missing-removeall-path');
  Check(True, 'FsRemoveAll missing path does not raise');
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

  LGot := False;
  try
    FsRemoveAll('/');
  except
    on E: EInvalidOperationError do
      LGot := True;
  end;
  Check(LGot, 'FsRemoveAll root path raises EInvalidOperationError');
end;

procedure TestRemoveAll;
begin
  FsMkdirAll(GTmpDir + '/rmall/sub');
  FsWriteFile(GTmpDir + '/rmall/sub/f.txt', TBytes.Create(1));
  FsRemoveAll(GTmpDir + '/rmall');
  Check(not FsExists(GTmpDir + '/rmall'), 'gone');
end;

procedure TestRemoveAllDeepTree;
var
  LBase, LPath: string;
  I: Integer;
begin
  { P2-7 regression test: deep directory tree must not stack overflow.
    Creates 200 nested directories, each with a file. }
  LBase := GTmpDir + '/rmall-deep';
  LPath := LBase;
  for I := 1 to 200 do
  begin
    LPath := LPath + '/d';
    FsMkdirAll(LPath);
    FsWriteFile(LPath + '/f.txt', TBytes.Create(I and $FF));
  end;
  Check(FsExists(LBase + '/d/d/f.txt'), 'deep tree created');
  FsRemoveAll(LBase);
  Check(not FsExists(LBase), 'deep tree gone');
end;

procedure TestGlob;
var
  LResults: TStringArray;
begin
  FsMkdir(GTmpDir + '/globtest');
  FsWriteFile(GTmpDir + '/globtest/a.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/globtest/b.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/globtest/c.pas', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/globtest/d.log', TBytes.Create(1));
  LResults := Glob(GTmpDir + '/globtest', '*.txt');
  Check(Length(LResults) = 2, 'Glob *.txt finds 2 files');
  LResults := Glob(GTmpDir + '/globtest', '*.pas');
  Check(Length(LResults) = 1, 'Glob *.pas finds 1 file');
  LResults := Glob(GTmpDir + '/globtest', '*');
  Check(Length(LResults) = 4, 'Glob * finds all 4 files');
  LResults := Glob(GTmpDir + '/globtest', '*.xyz');
  Check(Length(LResults) = 0, 'Glob *.xyz finds nothing');
  FsRemoveAll(GTmpDir + '/globtest');
  { Non-existent directory returns empty array, not exception }
  LResults := Glob(GTmpDir + '/nonexistent-glob-dir', '*');
  Check(Length(LResults) = 0, 'Glob non-existent dir returns empty');
end;

procedure TestFsGlobRecursive;
var
  LResults: TStringArray;
begin
  FsMkdirAll(GTmpDir + '/fsglob/sub/deep');
  FsWriteFile(GTmpDir + '/fsglob/a.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/fsglob/b.pas', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/fsglob/sub/c.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/fsglob/sub/d.log', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/fsglob/sub/deep/e.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/fsglob/sub/deep/f.pas', TBytes.Create(1));
  { **/*.txt should find a.txt + c.txt + e.txt = 3 }
  LResults := FsGlob(GTmpDir + '/fsglob', '**/*.txt');
  Check(Length(LResults) = 3, 'FsGlob **/*.txt finds 3 files recursively');
  { **/*.pas should find b.pas + f.pas = 2 }
  LResults := FsGlob(GTmpDir + '/fsglob', '**/*.pas');
  Check(Length(LResults) = 2, 'FsGlob **/*.pas finds 2 files recursively');
  { non-existent dir returns empty }
  LResults := FsGlob(GTmpDir + '/nonexistent-fsglob', '**/*');
  Check(Length(LResults) = 0, 'FsGlob non-existent dir returns empty');
  FsRemoveAll(GTmpDir + '/fsglob');
end;

procedure TestRename;
begin
  FsWriteFile(GTmpDir + '/old.txt', TBytes.Create(42));
  FsRename(GTmpDir + '/old.txt', GTmpDir + '/new.txt');
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
  CheckContains(LSource, 'ENOSPC_',
    'POSIX ENOSPC is named in fs error mapper');
  CheckContains(LSource, 'ENOMEM_',
    'POSIX ENOMEM is named in fs error mapper');
  CheckContains(LSource, 'EResourceExhaustedError',
    'disk full / OOM map to EResourceExhaustedError');
  CheckContains(LSource, 'ERR_DISK_FULL',
    'Windows ERROR_DISK_FULL named in fs error mapper');
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
  LRealWanted: string;
begin
  Result := -1;
  // /tmp may be symlink (e.g. /tmp -> /vm/tmp); /proc/self/fd reports realpath — compare via RealPath
  try LRealWanted := FsRealPath(APath); except LRealWanted := APath; end;
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
    if (LTarget = APath) or (LTarget = LRealWanted) then
      Exit(I);
    try if FsRealPath(LTarget) = LRealWanted then Exit(I); except end;
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

procedure TestFacadePathDirSysUtilsEmpty;
var
  LDir, LBase: string;
begin
  { Public PathDir/PathSplit: bare name → ''; './x' keeps '.'; Fs* stays Go. }
  CheckEqual('', PathDir('file.txt'), 'facade PathDir bare file is empty');
  CheckEqual('/home/user', PathDir('/home/user/file.txt'), 'facade PathDir with dir');
  CheckEqual('.', PathDir('./x'), 'facade PathDir ./x keeps dot');
  CheckEqual('.', FsPathDir('file.txt'), 'FsPathDir bare file is dot');
  CheckEqual('.', FsPathDir('./x'), 'FsPathDir ./x is dot');
  PathSplit('file.txt', LDir, LBase);
  CheckEqual('', LDir, 'facade PathSplit bare dir empty');
  CheckEqual('file.txt', LBase, 'facade PathSplit bare base');
  PathSplit('./x', LDir, LBase);
  CheckEqual('.', LDir, 'facade PathSplit ./x dir is dot');
  CheckEqual('x', LBase, 'facade PathSplit ./x base');
  FsPathSplit('file.txt', LDir, LBase);
  CheckEqual('.', LDir, 'FsPathSplit bare dir is dot');
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

procedure TestPathStackBufferConstantContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.path.pas');

  CheckContains(LSource, 'FS_PATH_STACK_BUF_SIZE = 1024;',
    'fs.path names the stack path buffer constant');
  CheckContains(LSource, 'array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;',
    'fs.path stack buffers use the named size constant');
  CheckAbsent(LSource, 'PATH_BUF_SIZE = 1024;',
    'fs.path no longer uses the old path buffer constant name');
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

procedure TestTempDir;
var
  LDir: string;
begin
  LDir := FsTempDir(GTmpDir, 'testdir_');
  Check(Pos(GTmpDir + '/testdir_', LDir) = 1, 'temp dir created with prefix');
  Check(FsIsDir(LDir), 'temp dir is a directory');
  FsRemoveAll(LDir);
end;

procedure TestTempDirDefaultLocation;
var
  LDir: string;
begin
  LDir := FsTempDir('', 'testdir_');
  Check(FsIsDir(LDir), 'temp dir in system location exists');
  Check(Pos('testdir_', LDir) > 0, 'temp dir has prefix');
  FsRemoveAll(LDir);
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

procedure TestTempFilePathBufferConstantContract;
var
  LSource, LImpl, LBody: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.util.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'fs.util temp buffer contract has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));
  LBody := ExtractFunctionBody(LImpl,
    'function FsTempFile(const ADir, APattern: string): IFile;',
    'procedure FillFileInfo');

  CheckContains(LBody, 'TEMP_FILE_PATH_BUF_SIZE = 1024;',
    'FsTempFile names the temp path stack buffer constant');
  CheckContains(LBody, 'array[0..TEMP_FILE_PATH_BUF_SIZE - 1] of AnsiChar;',
    'FsTempFile stack buffer uses the named size constant');
end;

procedure TestFsReadFileUsesReadIntoContract;
var
  LSource, LImpl, LBody: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.util.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'fs.util read-file contract has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));
  LBody := ExtractFunctionBody(LImpl,
    'function FsReadFile(const APath: string): TBytes;',
    'procedure FsWriteFile');

  CheckContains(LBody, 'platform_fs_file_size(PAnsiChar(APath), LSize)',
    'FsReadFile stats file size before allocating');
  CheckContains(LBody, 'SetLength(Result, LSize)',
    'FsReadFile preallocates the TBytes result');
  CheckContains(LBody, 'platform_fs_read_file_into(PAnsiChar(APath),',
    'FsReadFile reads directly into caller-owned TBytes storage');
  CheckContains(LBody, 'if LRead < PtrUInt(LSize) then',
    'FsReadFile trims the result when file shrinks after stat');
  CheckContains(LBody, 'SetLength(Result, LRead)',
    'FsReadFile crops the result to actual bytes read');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestFsReadFileProcFilesystem;
var
  LData: TBytes;
  LText: string;
begin
  { P1-7 regression test: /proc files report size=0 but have content.
    FsReadFile must fall back to growing read for such files. }
  LData := FsReadFile('/proc/self/status');
  Check(Length(LData) > 0, '/proc/self/status is non-empty');
  LText := string(PAnsiChar(@LData[0]));
  Check(Pos('Name:', LText) > 0, '/proc/self/status contains Name:');
end;
{$ENDIF}

procedure TestFsCwdRoundTrip;
var
  LOldCwd, LNewCwd: string;
begin
  LOldCwd := FsGetCwd;
  FsMkdirAll(GTmpDir + '/cwd-sub');
  try
    FsSetCwd(GTmpDir + '/cwd-sub');
    LNewCwd := FsGetCwd;
    // /tmp may be symlink to /vm/tmp; kernel getcwd returns realpath — compare via RealPath to handle both
    if FsRealPath(GTmpDir + '/cwd-sub') <> FsRealPath(LNewCwd) then
      CheckEqual(GTmpDir + '/cwd-sub', LNewCwd, 'FsGetCwd reflects FsSetCwd')
    else
      Check(True, 'FsGetCwd reflects FsSetCwd via realpath');
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
procedure TestWalkOpenDirErrorGoesToCallback;
var
  LDir: string;
begin
  LDir := GTmpDir + '/walk-no-access';
  FsMkdirAll(LDir);
  GWalkErrorSeen := False;
  GWalkErrorPath := '';
  FsChmod(LDir, 0);
  try
    FsWalk(LDir, @WalkErrorCallback);
  finally
    FsChmod(LDir, PermDirDefault);
    FsRemoveAll(LDir);
  end;
  Check(GWalkErrorSeen, 'FsWalk opendir error goes to callback');
  Check(GWalkErrorPath = LDir, 'FsWalk error path is directory');
end;

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
  FsRemove(LLink);
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

{ T1: ScanFileLines tests }

procedure TestScanFileLines_Basic;
var
  LScanner: IScanner;
  LCount: Integer;
  LLine1, LLine2, LLine3: string;
begin
  nextpas.core.fs.WriteFileLines(GTmpDir + '/scan_basic.txt',
    TStringArray.Create('alpha', 'beta', 'gamma'));
  LScanner := nextpas.core.fs.ScanFileLines(GTmpDir + '/scan_basic.txt');
  LCount := 0;
  LLine1 := '';
  LLine2 := '';
  LLine3 := '';
  while LScanner.Scan do
  begin
    Inc(LCount);
    case LCount of
      1: LLine1 := LScanner.Text;
      2: LLine2 := LScanner.Text;
      3: LLine3 := LScanner.Text;
    end;
  end;
  CheckEqual(Int64(3), Int64(LCount), 'ScanFileLines basic line count');
  CheckEqual('alpha', LLine1, 'ScanFileLines line 1');
  CheckEqual('beta', LLine2, 'ScanFileLines line 2');
  CheckEqual('gamma', LLine3, 'ScanFileLines line 3');
end;

procedure TestScanFileLines_Empty;
var
  LScanner: IScanner;
begin
  nextpas.core.fs.WriteFile(GTmpDir + '/scan_empty.txt', nil);
  LScanner := nextpas.core.fs.ScanFileLines(GTmpDir + '/scan_empty.txt');
  Check(not LScanner.Scan, 'ScanFileLines empty file Scan returns False');
end;

procedure TestScanFileLines_SingleLine;
var
  LScanner: IScanner;
begin
  nextpas.core.fs.WriteFile(GTmpDir + '/scan_single.txt',
    TBytes.Create(Ord('h'), Ord('i')));
  LScanner := nextpas.core.fs.ScanFileLines(GTmpDir + '/scan_single.txt');
  Check(LScanner.Scan, 'ScanFileLines single line Scan returns True');
  CheckEqual('hi', LScanner.Text, 'ScanFileLines single line content');
  Check(not LScanner.Scan, 'ScanFileLines single line second Scan returns False');
end;

procedure TestScanFileLines_CRLF;
var
  LScanner: IScanner;
  LCount: Integer;
  LLine1, LLine2: string;
begin
  nextpas.core.fs.WriteFileText(GTmpDir + '/scan_crlf.txt', 'one'#13#10'two'#13#10);
  LScanner := nextpas.core.fs.ScanFileLines(GTmpDir + '/scan_crlf.txt');
  LCount := 0;
  LLine1 := '';
  LLine2 := '';
  while LScanner.Scan do
  begin
    Inc(LCount);
    case LCount of
      1: LLine1 := LScanner.Text;
      2: LLine2 := LScanner.Text;
    end;
  end;
  CheckEqual(Int64(2), Int64(LCount), 'ScanFileLines CRLF line count');
  CheckEqual('one', LLine1, 'ScanFileLines CRLF line 1 strips CR');
  CheckEqual('two', LLine2, 'ScanFileLines CRLF line 2 strips CR');
end;

procedure TestScanFileLines_LargeFile;
var
  LLines: TStringArray;
  LScanner: IScanner;
  LCount: Integer;
  LI: Integer;
begin
  SetLength(LLines, 1000);
  for LI := 0 to 999 do
    LLines[LI] := 'line_' + IntToStr(LI);
  nextpas.core.fs.WriteFileLines(GTmpDir + '/scan_large.txt', LLines);
  LScanner := nextpas.core.fs.ScanFileLines(GTmpDir + '/scan_large.txt');
  LCount := 0;
  while LScanner.Scan do
    Inc(LCount);
  CheckEqual(Int64(1000), Int64(LCount), 'ScanFileLines large file line count');
end;

procedure TestScanFileLines_Bytes;
var
  LScanner: IScanner;
  LBytes: TBytes;
begin
  nextpas.core.fs.WriteFileText(GTmpDir + '/scan_bytes.txt', 'abc'#10'def'#10);
  LScanner := nextpas.core.fs.ScanFileLines(GTmpDir + '/scan_bytes.txt');
  Check(LScanner.Scan, 'ScanFileLines bytes Scan');
  LBytes := LScanner.Bytes;
  CheckEqual(Int64(3), Int64(Length(LBytes)), 'ScanFileLines bytes length');
  CheckEqual(Byte(Ord('a')), LBytes[0], 'ScanFileLines bytes[0]');
  CheckEqual(Byte(Ord('b')), LBytes[1], 'ScanFileLines bytes[1]');
  CheckEqual(Byte(Ord('c')), LBytes[2], 'ScanFileLines bytes[2]');
end;

procedure TestScanFileLines_ErrorPath;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    nextpas.core.fs.ScanFileLines(GTmpDir + '/nonexistent_scan_xyz');
  except
    on E: Exception do
      LGot := True;
  end;
  Check(LGot, 'ScanFileLines nonexistent file raises exception');
end;

{ T2: MapFileLines tests }

procedure TestMapFileLines_Basic;
var
  LMap: IMappedLines;
begin
  nextpas.core.fs.WriteFileLines(GTmpDir + '/map_basic.txt',
    TStringArray.Create('alpha', 'beta', 'gamma'));
  LMap := nextpas.core.fs.MapFileLines(GTmpDir + '/map_basic.txt');
  CheckEqual(Int64(3), Int64(LMap.Count), 'MapFileLines basic count');
  CheckEqual('alpha', LMap.Line(0).ToString, 'MapFileLines line 0');
  CheckEqual('beta', LMap.Line(1).ToString, 'MapFileLines line 1');
  CheckEqual('gamma', LMap.Line(2).ToString, 'MapFileLines line 2');
end;

procedure TestMapFileLines_Empty;
var
  LMap: IMappedLines;
begin
  nextpas.core.fs.WriteFile(GTmpDir + '/map_empty.txt', nil);
  LMap := nextpas.core.fs.MapFileLines(GTmpDir + '/map_empty.txt');
  CheckEqual(Int64(0), Int64(LMap.Count), 'MapFileLines empty count = 0');
end;

procedure TestMapFileLines_CrossValidate;
var
  LLines: TStringArray;
  LMap: IMappedLines;
  LI: Integer;
begin
  LLines := TStringArray.Create('foo', 'bar', 'baz');
  nextpas.core.fs.WriteFileLines(GTmpDir + '/map_cross.txt', LLines);
  LLines := nextpas.core.fs.ReadFileLines(GTmpDir + '/map_cross.txt');
  LMap := nextpas.core.fs.MapFileLines(GTmpDir + '/map_cross.txt');
  CheckEqual(Int64(Length(LLines)), Int64(LMap.Count),
    'MapFileLines cross-validate count matches ReadFileLines');
  for LI := 0 to High(LLines) do
    CheckEqual(LLines[LI], LMap.Line(LI).ToString,
      'MapFileLines cross-validate line ' + IntToStr(LI));
end;

procedure TestMapFileLines_IndexOf;
var
  LMap: IMappedLines;
begin
  nextpas.core.fs.WriteFileLines(GTmpDir + '/map_indexof.txt',
    TStringArray.Create('aaa', 'bbb', 'ccc'));
  LMap := nextpas.core.fs.MapFileLines(GTmpDir + '/map_indexof.txt');
  CheckEqual(Int64(1), Int64(LMap.IndexOf('bbb')), 'MapFileLines IndexOf finds bbb');
  CheckEqual(Int64(0), Int64(LMap.IndexOf('aaa')), 'MapFileLines IndexOf finds aaa');
  CheckEqual(Int64(2), Int64(LMap.IndexOf('ccc')), 'MapFileLines IndexOf finds ccc');
end;

procedure TestMapFileLines_IndexOfNotFound;
var
  LMap: IMappedLines;
begin
  nextpas.core.fs.WriteFileLines(GTmpDir + '/map_notfound.txt',
    TStringArray.Create('aaa', 'bbb'));
  LMap := nextpas.core.fs.MapFileLines(GTmpDir + '/map_notfound.txt');
  CheckEqual(Int64(-1), Int64(LMap.IndexOf('zzz')),
    'MapFileLines IndexOf not found returns -1');
end;

procedure TestMapFileLines_Contains;
var
  LMap: IMappedLines;
begin
  nextpas.core.fs.WriteFileLines(GTmpDir + '/map_contains.txt',
    TStringArray.Create('hello', 'world'));
  LMap := nextpas.core.fs.MapFileLines(GTmpDir + '/map_contains.txt');
  Check(LMap.Contains('hello'), 'MapFileLines Contains hello');
  Check(LMap.Contains('world'), 'MapFileLines Contains world');
end;

procedure TestMapFileLines_ContainsNotFound;
var
  LMap: IMappedLines;
begin
  nextpas.core.fs.WriteFileLines(GTmpDir + '/map_contains_not.txt',
    TStringArray.Create('hello', 'world'));
  LMap := nextpas.core.fs.MapFileLines(GTmpDir + '/map_contains_not.txt');
  Check(not LMap.Contains('zzz'), 'MapFileLines Contains not found returns False');
end;

procedure TestMapFileLines_ErrorPath;
var
  LMap: IMappedLines;
begin
  LMap := nextpas.core.fs.MapFileLines(GTmpDir + '/nonexistent_map_xyz');
  CheckEqual(Int64(0), Int64(LMap.Count),
    'MapFileLines nonexistent file returns count 0');
end;

{ T3: WriteFileLines / ReadFileLines tests }

procedure TestWriteReadFileLines_Roundtrip;
var
  LWritten, LRead: TStringArray;
begin
  LWritten := TStringArray.Create('first', 'second', 'third');
  nextpas.core.fs.WriteFileLines(GTmpDir + '/roundtrip.txt', LWritten);
  LRead := nextpas.core.fs.ReadFileLines(GTmpDir + '/roundtrip.txt');
  CheckEqual(Int64(3), Int64(Length(LRead)), 'roundtrip line count');
  CheckEqual('first', LRead[0], 'roundtrip line 0');
  CheckEqual('second', LRead[1], 'roundtrip line 1');
  CheckEqual('third', LRead[2], 'roundtrip line 2');
end;

procedure TestWriteFileLines_Empty;
var
  LWritten, LRead: TStringArray;
begin
  LWritten := nil;
  nextpas.core.fs.WriteFileLines(GTmpDir + '/write_empty.txt', LWritten);
  LRead := nextpas.core.fs.ReadFileLines(GTmpDir + '/write_empty.txt');
  CheckEqual(Int64(0), Int64(Length(LRead)), 'WriteFileLines empty array');
end;

procedure TestWriteFileLines_SingleLine;
var
  LRead: TStringArray;
begin
  nextpas.core.fs.WriteFileLines(GTmpDir + '/write_single.txt',
    TStringArray.Create('only'));
  LRead := nextpas.core.fs.ReadFileLines(GTmpDir + '/write_single.txt');
  CheckEqual(Int64(1), Int64(Length(LRead)), 'WriteFileLines single line count');
  CheckEqual('only', LRead[0], 'WriteFileLines single line content');
end;

procedure TestWriteFileLines_Unicode;
var
  LWritten, LRead: TStringArray;
begin
  LWritten := TStringArray.Create('hello', '日本語', 'émoji 🎉');
  nextpas.core.fs.WriteFileLines(GTmpDir + '/write_unicode.txt', LWritten);
  LRead := nextpas.core.fs.ReadFileLines(GTmpDir + '/write_unicode.txt');
  CheckEqual(Int64(3), Int64(Length(LRead)), 'Unicode line count');
  CheckEqual('hello', LRead[0], 'Unicode line 0');
  CheckEqual('日本語', LRead[1], 'Unicode line 1');
  CheckEqual('émoji 🎉', LRead[2], 'Unicode line 2');
end;

procedure TestWriteFileLines_NativeLineEnding;
var
  LRaw: TBytes;
  LFoundLF: Boolean;
  LFoundCRLF: Boolean;
  LI: Integer;
begin
  nextpas.core.fs.WriteFileLines(GTmpDir + '/write_native.txt',
    TStringArray.Create('a', 'b'));
  LRaw := nextpas.core.fs.ReadFile(GTmpDir + '/write_native.txt');
  LFoundLF := False;
  LFoundCRLF := False;
  for LI := 0 to High(LRaw) - 1 do
    if (LRaw[LI] = 13) and (LRaw[LI + 1] = 10) then
      LFoundCRLF := True;
  for LI := 0 to High(LRaw) do
    if LRaw[LI] = 10 then
    begin
      LFoundLF := True;
      Break;
    end;
{$IFDEF NEXTPAS_WINDOWS}
  Check(LFoundCRLF, 'WriteFileLines uses CRLF on Windows');
{$ELSE}
  Check(LFoundLF, 'WriteFileLines uses LF on Unix');
  Check(not LFoundCRLF, 'WriteFileLines does not use CRLF on Unix');
{$ENDIF}
end;

{ T7: fs facade source-contract for ScanFileLines / MapFileLines }

procedure TestScanFileLinesUsesCreateScannerContract;
var
  LSource, LImpl, LBody: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'fs facade ScanFileLines has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));
  LBody := ExtractFunctionBody(LImpl,
    'function ScanFileLines(const APath: string): IScanner;',
    'function MapFileLines');
  CheckContains(LBody, 'CreateScanner',
    'ScanFileLines uses CreateScanner from io.scanner');
  CheckContains(LBody, 'FsOpen',
    'ScanFileLines opens file with FsOpen');
end;

procedure TestMapFileLinesUsesMmapLinesContract;
var
  LSource, LImpl, LBody: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'fs facade MapFileLines has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));
  LBody := ExtractFunctionBody(LImpl,
    'function MapFileLines(const APath: string): IMappedLines;',
    'procedure WriteAtomic');
  CheckContains(LBody, 'MmapLines',
    'MapFileLines uses MmapLines from io.mapped');
end;

procedure TestFsFacadeUsesIOModulesContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.pas');
  CheckContains(LSource, 'nextpas.core.io.scanner',
    'fs facade uses io.scanner');
  CheckContains(LSource, 'nextpas.core.io.mapped',
    'fs facade uses io.mapped');
  CheckContains(LSource, 'IScanner = nextpas.core.io.scanner.IScanner',
    'fs facade re-exports IScanner type');
  CheckContains(LSource, 'IMappedLines = nextpas.core.io.mapped.IMappedLines',
    'fs facade re-exports IMappedLines type');
end;

procedure TestFsWalkDelegatesToPlatformWalker;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.fs.dir.pas');
  CheckContains(LSource, 'platform_fs_walk(PAnsiChar(ARoot), @FsWalkPlatformCallback,',
    'FsWalk delegates traversal to platform_fs_walk');
  CheckAbsent(LSource, 'procedure DoWalk(',
    'FsWalk no longer embeds recursive Pascal traversal');
  CheckAbsent(LSource, 'MAX_WALK_DEPTH = 256',
    'FsWalk depth truth comes from platform walk owner');
end;

procedure TestWalkVisitsFilesAndDirectories;
var
  LRoot: string;
  I: SizeInt;
  LFoundRoot, LFoundChildDir, LFoundDeepFile: Boolean;
begin
  LRoot := GTmpDir + '/walk-tree';
  FsMkdirAll(LRoot + '/a/b');
  FsWriteFile(LRoot + '/root.txt', TBytes.Create(1));
  FsWriteFile(LRoot + '/a/child.txt', TBytes.Create(2));
  FsWriteFile(LRoot + '/a/b/deep.txt', TBytes.Create(3));

  GWalkVisited := nil;
  GWalkFileTypes := nil;
  FsWalk(LRoot, @WalkCaptureCallback);

  Check(Length(GWalkVisited) >= 6,
    'walk visits root + dirs + files (got ' +
    IntToStr(Length(GWalkVisited)) + ')');
  Check(GWalkVisited[0] = LRoot, 'walk visits root first');

  LFoundRoot := False;
  LFoundChildDir := False;
  LFoundDeepFile := False;
  for I := 0 to High(GWalkVisited) do
  begin
    if GWalkVisited[I] = LRoot then
      LFoundRoot := True;
    if GWalkVisited[I] = LRoot + '/a' then
      LFoundChildDir := True;
    if GWalkVisited[I] = LRoot + '/a/b/deep.txt' then
      LFoundDeepFile := True;
  end;
  Check(LFoundRoot, 'root directory visited');
  Check(LFoundChildDir, 'child directory visited');
  Check(LFoundDeepFile, 'deep file visited');
end;

procedure TestWalkClassifiesFileTypes;
var
  LRoot: string;
  I: SizeInt;
  LRegularCount, LDirCount: Integer;
begin
  LRoot := GTmpDir + '/walk-types';
  FsMkdirAll(LRoot + '/sub');
  FsWriteFile(LRoot + '/file.txt', TBytes.Create(1));
  FsWriteFile(LRoot + '/sub/nested.txt', TBytes.Create(2));

  GWalkVisited := nil;
  GWalkFileTypes := nil;
  FsWalk(LRoot, @WalkCaptureCallback);

  LRegularCount := 0;
  LDirCount := 0;
  for I := 0 to High(GWalkFileTypes) do
  begin
    if GWalkFileTypes[I] = ftRegular then
      Inc(LRegularCount);
    if GWalkFileTypes[I] = ftDirectory then
      Inc(LDirCount);
  end;
  Check(LRegularCount >= 2, 'walk classifies regular files');
  Check(LDirCount >= 2, 'walk classifies directories');
end;

procedure TestWalkFiles;
var
  LRoot: string;
  I: SizeInt;
  LFileCount, LDirCount: Integer;
begin
  LRoot := GTmpDir + '/walkfiles';
  FsMkdirAll(LRoot + '/sub/deep');
  FsWriteFile(LRoot + '/root.txt', TBytes.Create(1));
  FsWriteFile(LRoot + '/sub/child.txt', TBytes.Create(2));
  FsWriteFile(LRoot + '/sub/deep/deep.txt', TBytes.Create(3));

  GWalkVisited := nil;
  GWalkFileTypes := nil;
  WalkFiles(LRoot, @WalkCaptureCallback);

  LFileCount := 0;
  LDirCount := 0;
  for I := 0 to High(GWalkFileTypes) do
  begin
    if GWalkFileTypes[I] = ftRegular then
      Inc(LFileCount);
    if GWalkFileTypes[I] = ftDirectory then
      Inc(LDirCount);
  end;
  Check(LFileCount >= 3, 'WalkFiles visits all files');
  Check(LDirCount = 0, 'WalkFiles skips directories');
  FsRemoveAll(LRoot);
end;

procedure TestWalkStopsWhenCallbackReturnsFalse;
var
  LRoot: string;
begin
  LRoot := GTmpDir + '/walk-stop';
  FsMkdirAll(LRoot + '/a/b');
  FsWriteFile(LRoot + '/a/b/file.txt', TBytes.Create(1));

  GWalkStopCount := 0;
  FsWalk(LRoot, @WalkStopAfterTwoCallback);
  Check(GWalkStopCount = 2, 'walk stops when callback returns false');
end;

{$IFDEF NEXTPAS_UNIX}
procedure TestWalkDoesNotDescendSymlinkDirectory;
var
  LRoot, LTarget, LLink: string;
  I: SizeInt;
  LFoundInside: Boolean;
begin
  LRoot := GTmpDir + '/walk-link-root';
  LTarget := LRoot + '/target';
  LLink := LRoot + '/link-target';
  FsMkdirAll(LTarget);
  FsWriteFile(LTarget + '/inside.txt', TBytes.Create(1));
  FsSymlink(LTarget, LLink);

  GWalkVisited := nil;
  GWalkFileTypes := nil;
  FsWalk(LRoot, @WalkCaptureCallback);

  Check(HasVisitedPath(LLink), 'symlink entry is visited');

  { The real target/ directory is walked (it is a real dir in the tree).
    We must verify that the symlink path itself is NOT descended —
    i.e. no path starting with LLink + '/' appears. }
  LFoundInside := False;
  for I := 0 to High(GWalkVisited) do
    if Copy(GWalkVisited[I], 1, Length(LLink) + 1) = LLink + '/' then
      LFoundInside := True;
  Check(not LFoundInside, 'symlink target subtree not descended via symlink path');
end;
{$ENDIF}

procedure TestFsEnsureFile;
var
  LPath: string;
begin
  LPath := GTmpDir + '/ensure_file_test.txt';
  { File doesn't exist — should create it }
  Check(not FsExists(LPath), 'FsEnsureFile: file does not exist before');
  FsEnsureFile(LPath);
  Check(FsExists(LPath), 'FsEnsureFile: file exists after call');
  Check(FsFileSize(LPath) = 0, 'FsEnsureFile: created file is empty');
  { File exists — should not modify it }
  FsWriteFile(LPath, TBytes.Create($41, $42, $43));
  FsEnsureFile(LPath);
  Check(FsFileSize(LPath) = 3, 'FsEnsureFile: existing file not modified');
  FsRemove(LPath);
end;

procedure TestFsGetTempDir;
var
  LDir, LTestFile: string;
begin
  LDir := FsGetTempDir;
  Check(LDir <> '', 'FsGetTempDir: returns non-empty');
  Check(FsIsDir(LDir), 'FsGetTempDir: directory exists');
  { Verify temp dir is writable by creating a test file }
  LTestFile := LDir + '/nextpas_test_write_check';
  FsWriteFile(LTestFile, TBytes.Create(42));
  Check(FsExists(LTestFile), 'FsGetTempDir: dir is writable');
  FsRemove(LTestFile);
end;

begin
  SetupTmpDir;
  try
    T := TTestSuite.Create('nextpas.core.fs');

    T.Test('Create and read', @TestCreateAndRead);
    T.Test('Seek', @TestSeek);
    T.Test('Stat', @TestStat);
    T.Test('Truncate', @TestTruncate);
    T.Test('ReadAt', @TestReadAt);
    T.Test('WriteAt', @TestWriteAt);

    T.Test('ReadFile/WriteFile', @TestReadWriteFile);
    T.Test('FsWriteFileText', @TestFsWriteFileText);
    T.Test('FsWriteFileLines', @TestFsWriteFileLines);
    T.Test('FsWriteFileLines_Empty', @TestFsWriteFileLines_Empty);
    T.Test('FsAppendFileLines', @TestFsAppendFileLines);
    T.Test('WriteAtomic', @TestWriteAtomic);
    T.Test('CopyFile', @TestCopyFile);
{$IFDEF NEXTPAS_LINUX}
    T.Test('WriteFile raises on short write', @TestWriteFileRaisesOnShortWrite);
    T.Test('AppendFile raises on short write', @TestAppendFileRaisesOnShortWrite);
{$ENDIF}
    T.Test('Exists', @TestExists);
    T.Test('IsFile/IsDir', @TestIsFileIsDir);
    T.Test('IsSymlink', @TestIsSymlink);
    T.Test('SameFile', @TestSameFile);
    T.Test('Symlink relative target', @TestSymlinkRelativeTarget);
    T.Test('RealPath', @TestRealPath);
    T.Test('ReadFile missing ENotFound', @TestReadFileMissingNotFound);
    T.Test('WriteAtomic missing parent', @TestWriteAtomicMissingParentRaises);
    T.Test('CopyFile missing source', @TestCopyFileMissingSourceRaises);
    T.Test('WriteFile empty roundtrip', @TestWriteFileEmptyRoundtrip);
    T.Test('AppendFileText roundtrip', @TestAppendFileTextRoundtrip);
    T.Test('AppendFileLine roundtrip', @TestAppendFileLineRoundtrip);
    T.Test('Exists false for missing', @TestExistsFalseForMissing);
    T.Test('IsFile IsDir edges', @TestIsFileIsDirEdges);
    T.Test('Remove missing silent', @TestRemoveMissingSilent);
    T.Test('Rename roundtrip', @TestRenameRoundtrip);
    T.Test('Truncate path to zero', @TestTruncatePathToZero);
    T.Test('Chmod read write', @TestChmodReadWrite);
    T.Test('SameFile empty path raises', @TestSameFileEmptyPathRaises);
    T.Test('WriteAtomic overwrite', @TestWriteAtomicOverwrite);
    T.Test('ReadFileText empty', @TestReadFileTextEmpty);
    T.Test('EnsureFile idempotent', @TestEnsureFileIdempotent);
    T.Test('TempDir is directory', @TestTempDirIsDirectory);
    T.Test('Stat missing R19', @TestStatMissingR19);
    T.Test('Open missing R19', @TestOpenMissingR19);
    T.Test('Readlink missing R19', @TestReadlinkMissingR19);
    T.Test('WriteFile roundtrip R19', @TestWriteFileRoundtripR19);
    T.Test('MkdirAll idempotent R19', @TestMkdirAllIdempotentR19);
    T.Test('CopyFile roundtrip R19', @TestCopyFileRoundtripR19);
    T.Test('Rename then missing R19', @TestRenameThenMissingR19);
    T.Test('IsSymlink facade R19', @TestIsSymlinkFacadeR19);
    T.Test('SameFile self R19', @TestSameFileSelfR19);
    T.Test('SameFile missing R19', @TestSameFileMissingR19);
    T.Test('FileSize after write R19', @TestFileSizeAfterWriteR19);
    T.Test('GetCwd non-empty R19', @TestGetCwdNonEmptyR19);
    T.Test('TempFile writable R19', @TestTempFileWritableR19);
    T.Test('Exists R19 extra', @TestExistsR19Extra);
    T.Test('ReadDir has file R19 extra', @TestReadDirHasFileR19Extra);
    T.Test('Remove file R19 extra', @TestRemoveFileR19Extra);
    T.Test('Chmod exists R19 extra', @TestChmodExistsR19Extra);
    T.Test('Truncate R19 extra', @TestTruncateR19Extra);
    T.Test('HardLink R20', @TestHardLinkR20);
    T.Test('HardLink missing R20', @TestHardLinkMissingR20);
    T.Test('HardLink empty R20', @TestHardLinkEmptyR20);
    T.Test('Chtimes R20', @TestChtimesR20);
    T.Test('Chtimes missing R20', @TestChtimesMissingR20);
    T.Test('Chown self R20', @TestChownSelfR20);
    T.Test('Chown missing R20', @TestChownMissingR20);
    T.Test('FileSize', @TestFileSize);

    T.Test('Mkdir + ReadDir', @TestMkdirAndReadDir);
    T.Test('MkdirAll', @TestMkdirAll);
    T.Test('Mkdir existing file raises already exists',
      @TestMkdirExistingFileRaisesAlreadyExists);
    T.Test('MkdirAll existing file child raises invalid operation',
      @TestMkdirAllExistingFileChildRaisesInvalidOperation);
    T.Test('Remove', @TestRemove);
    T.Test('Remove non-empty dir raises invalid operation',
      @TestRemoveNonEmptyDirRaisesInvalidOperation);
    T.Test('Remove missing path returns true',
      @TestRemoveMissingPathReturnsTrue);
    T.Test('RemoveAll missing path returns true',
      @TestRemoveAllMissingPathReturnsTrue);
    T.Test('RemoveAll unsafe root guard raises invalid operation',
      @TestRemoveAllUnsafeRootGuardRaisesInvalidOperation);
    T.Test('RemoveAll', @TestRemoveAll);
    T.Test('RemoveAll deep tree (200 levels)', @TestRemoveAllDeepTree);
    T.Test('Glob pattern matching', @TestGlob);
    T.Test('FsGlob recursive matching', @TestFsGlobRecursive);
    T.Test('Rename', @TestRename);
    T.Test('Rename missing source raises not found',
      @TestRenameMissingSourceRaisesNotFound);
    T.Test('Fs error non-empty dir source contract',
      @TestFsErrorNonEmptyDirSourceContract);
    T.Test('DirIterator', @TestDirIterator);
{$IFDEF NEXTPAS_LINUX}
    T.Test('DirIterator close reports platform error',
      @TestDirIteratorCloseReportsPlatformError);
{$ENDIF}

    T.Test('PathJoin', @TestPathJoin);
    T.Test('PathDir', @TestPathDir);
    T.Test('facade PathDir/PathSplit SysUtils empty', @TestFacadePathDirSysUtilsEmpty);
    T.Test('PathBase', @TestPathBase);
    T.Test('PathExt', @TestPathExt);
    T.Test('PathExt long result', @TestPathExtLongResult);
    T.Test('PathChangeExt dotfiles', @TestPathChangeExtDotfiles);
    T.Test('PathWithoutExt dotfiles', @TestPathWithoutExtDotfiles);
    T.Test('PathIsAbs', @TestPathIsAbs);
    T.Test('PathClean empty', @TestPathCleanEmpty);
    T.Test('PathRelative', @TestPathRelative);
    T.Test('PathSplit', @TestPathSplit);
    T.Test('Path separator source contract', @TestPathSeparatorSourceContract);
    T.Test('Path delegates platform root contract', @TestPathDelegatesPlatformRootContract);
    T.Test('Path stack buffer constant contract',
      @TestPathStackBufferConstantContract);
{$IFDEF NEXTPAS_WINDOWS}
    T.Test('Windows path wrapper contract', @TestWindowsPathWrapperContract);
{$ENDIF}
    T.Test('PathEnsureSep/PathTrimSep', @TestPathEnsureTrimSep);
    T.Test('SameFileName', @TestSameFileName);
    T.Test('PathJoin long', @TestPathLong);

    { T1: ScanFileLines }
    T.Test('ScanFileLines basic', @TestScanFileLines_Basic);
    T.Test('ScanFileLines empty', @TestScanFileLines_Empty);
    T.Test('ScanFileLines single line', @TestScanFileLines_SingleLine);
    T.Test('ScanFileLines CRLF', @TestScanFileLines_CRLF);
    T.Test('ScanFileLines large file', @TestScanFileLines_LargeFile);
    T.Test('ScanFileLines bytes', @TestScanFileLines_Bytes);
    T.Test('ScanFileLines error path', @TestScanFileLines_ErrorPath);

    { T2: MapFileLines }
    T.Test('MapFileLines basic', @TestMapFileLines_Basic);
    T.Test('MapFileLines empty', @TestMapFileLines_Empty);
    T.Test('MapFileLines cross-validate', @TestMapFileLines_CrossValidate);
    T.Test('MapFileLines IndexOf', @TestMapFileLines_IndexOf);
    T.Test('MapFileLines IndexOf not found', @TestMapFileLines_IndexOfNotFound);
    T.Test('MapFileLines Contains', @TestMapFileLines_Contains);
    T.Test('MapFileLines Contains not found', @TestMapFileLines_ContainsNotFound);
    T.Test('MapFileLines error path', @TestMapFileLines_ErrorPath);

    { T3: WriteFileLines / ReadFileLines }
    T.Test('WriteReadFileLines roundtrip', @TestWriteReadFileLines_Roundtrip);
    T.Test('WriteFileLines empty', @TestWriteFileLines_Empty);
    T.Test('WriteFileLines single line', @TestWriteFileLines_SingleLine);
    T.Test('WriteFileLines unicode', @TestWriteFileLines_Unicode);
    T.Test('WriteFileLines native line ending', @TestWriteFileLines_NativeLineEnding);

    { T7: fs facade source-contract }
    T.Test('ScanFileLines uses CreateScanner contract',
      @TestScanFileLinesUsesCreateScannerContract);
    T.Test('MapFileLines uses MmapLines contract',
      @TestMapFileLinesUsesMmapLinesContract);
    T.Test('Fs facade uses io.scanner and io.mapped contract',
      @TestFsFacadeUsesIOModulesContract);

    T.Test('Open not found', @TestOpenNotFound);
    T.Test('Close invalid handle raises', @TestCloseInvalidHandleRaises);

    T.Test('Append', @TestAppend);
    T.Test('Exclusive create', @TestExclusive);
    T.Test('ReadAt position-independent', @TestReadAtPositionIndependent);
    T.Test('Chmod + perm', @TestChmodAndPerm);
    T.Test('Truncate path', @TestTruncatePath);
    T.Test('TempFile in dir', @TestTempFileInDir);
    T.Test('TempDir', @TestTempDir);
    T.Test('TempDir default location', @TestTempDirDefaultLocation);
    T.Test('TempFile system dir typed handle contract',
      @TestTempFileSystemDirUsesTypedHandleContract);
    T.Test('TempFile path buffer constant contract',
      @TestTempFilePathBufferConstantContract);
    T.Test('FsReadFile uses read_into contract',
      @TestFsReadFileUsesReadIntoContract);
    {$IFDEF NEXTPAS_LINUX}
    T.Test('FsReadFile /proc filesystem (size=0)',
      @TestFsReadFileProcFilesystem);
    {$ENDIF}
    T.Test('FsGetCwd/FsSetCwd roundtrip', @TestFsCwdRoundTrip);
    T.Test('FsSetCwd invalid path raises mapped fs error',
      @TestFsSetCwdInvalidPathRaisesNotFound);
    T.Test('FsGetCwd/FsSetCwd use platform owner contract',
      @TestFsCwdUsesPlatformOwnerContract);
    T.Test('FsGetEnv invalid name raises', @TestFsGetEnvInvalidNameRaises);
    T.Test('FsGetEnv uses os.env owner contract',
      @TestFsGetEnvUsesOsEnvOwnerContract);
    T.Test('Lstat', @TestLstat);
    T.Test('FsWalk delegates to platform walker',
      @TestFsWalkDelegatesToPlatformWalker);
    T.Test('Walk visits files and directories',
      @TestWalkVisitsFilesAndDirectories);
    T.Test('Walk classifies file types', @TestWalkClassifiesFileTypes);
    T.Test('WalkFiles skips directories', @TestWalkFiles);
    T.Test('Walk stops when callback returns false',
      @TestWalkStopsWhenCallbackReturnsFalse);
    T.Test('FsEnsureFile creates and preserves', @TestFsEnsureFile);
    T.Test('FsGetTempDir returns valid dir', @TestFsGetTempDir);
{$IFDEF NEXTPAS_UNIX}
    T.Test('RemoveAll symlink root', @TestRemoveAllSymlinkRoot);
    T.Test('Walk opendir error callback', @TestWalkOpenDirErrorGoesToCallback);
    T.Test('Walk does not descend symlink directory',
      @TestWalkDoesNotDescendSymlinkDirectory);
    T.Test('Remove symlink-to-dir unlinks link', @TestRemoveSymlinkToDirUnlinksLink);
    T.Test('Symlink + Readlink', @TestSymlinkReadlink);
    T.Test('Symlink + Readlink long target', @TestSymlinkReadlinkLongTarget);
    T.Test('Readlink regular file raises invalid operation', @TestReadlinkRegularFileRaisesInvalidOperation);
{$ENDIF}
    T.Test('fs owned sources no bare FPC RTL uses', @TestFsOwnedSourcesNoFpcRtl);
    T.Test('fs test suites no bare FPC RTL uses', @TestFsTestSuitesNoFpcRtl);

  if not T.Run then Halt(1);
  finally
    CleanupTmpDir;
  end;
end.
