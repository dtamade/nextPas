program test_zip_fs;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.checksum.crc32,
  nextpas.core.zip,
  nextpas.core.zip.base;

var
  T: TTestSuite;

{ python3 zipfile 独立读取我们打包的目录归档。
  argv[1]=zip 路径 argv[2]=清单路径；清单行：name\tsize\tcrc32hex。 }
const
  C_PY_CHECK =
    'import sys, zipfile, zlib'#10 +
    'zpath, mpath = sys.argv[1], sys.argv[2]'#10 +
    'rows = []'#10 +
    'for line in open(mpath, encoding=''utf-8''):'#10 +
    '    line = line.rstrip(''\n'')'#10 +
    '    if not line: continue'#10 +
    '    name, size, crc = line.split(''\t'')'#10 +
    '    rows.append((name, int(size), int(crc, 16)))'#10 +
    'z = zipfile.ZipFile(zpath)'#10 +
    'assert z.testzip() is None, ''testzip failed'''#10 +
    'infos = z.infolist()'#10 +
    'names = [i.filename for i in infos]'#10 +
    'for name, size, crc in rows:'#10 +
    '    assert name in names, f''missing {name!r}'''#10 +
    '    info = [i for i in infos if i.filename == name][0]'#10 +
    '    data = z.read(info)'#10 +
    '    assert len(data) == size, f''size {len(data)} != {size} for {name!r}'''#10 +
    '    assert zlib.crc32(data) & 0xFFFFFFFF == crc, f''crc mismatch {name!r}'''#10 +
    'print(''CROSSCHECK OK'')'#10;

  C_PY_MAKE =
    'import zipfile, sys'#10 +
    'z = zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED)'#10 +
    'z.writestr("docs/readme.txt", "read me")'#10 +
    'z.writestr("图片/说明.txt", "图像说明".encode())'#10 +
    'z.writestr("empty.dat", b"")'#10 +
    'z.writestr("assets/", b"")'#10 +
    'z.close()'#10;

  C_PY_EVIL =
    'import zipfile, sys'#10 +
    'z = zipfile.ZipFile(sys.argv[1], "w")'#10 +
    'z.writestr("../evil.txt", b"x")'#10 +
    'z.close()'#10;

  { 符号链接条目（unix 外部属性 S_IFLNK）+ 同名目标文件 }
  C_PY_LINK =
    'import zipfile, sys'#10 +
    'z = zipfile.ZipFile(sys.argv[1], "w")'#10 +
    'z.writestr("real.txt", "target")'#10 +
    'i = zipfile.ZipInfo("lnk")'#10 +
    'i.create_system = 3'#10 +
    'i.external_attr = (0o120777 << 16)'#10 +
    'z.writestr(i, "real.txt")'#10 +
    'z.close()'#10;

function BytesOfStr(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

function SameBytes(const A, B: TBytes): Boolean;
var
  LI: Integer;
begin
  Result := False;
  if Length(A) <> Length(B) then Exit;
  for LI := 0 to High(A) do
    if A[LI] <> B[LI] then Exit;
  Result := True;
end;

function Hex32(AValue: LongWord): string;
const
  C_Hex: array[0..15] of Char = '0123456789abcdef';
begin
  Result := '';
  repeat
    Result := C_Hex[(AValue and $F)] + Result;
    AValue := AValue shr 4;
  until AValue = 0;
  while Length(Result) < 8 do
    Result := '0' + Result;
end;

procedure RunPy(const AScript: string; const AZipPath: string; const AExtra: string);
var
  LPy: string;
  LOut: TProcessOutput;
begin
  if not TryLookPath('python3', LPy) then
  begin
    Check(False, 'python3 unavailable for zip fs cross-validation');
    Exit;
  end;
  LOut := Command(LPy).Arg('-c').Arg(AScript)
    .Arg(AZipPath).Arg(AExtra).Output;
  Check(ProcessSucceeded(LOut),
    'python fixture exit ok: ' + Trim(LOut.StdErr));
end;

function NewCaseDir(const ATag: string): string;
begin
  Result := TempDir(GetTempDir, 'zipfstest' + ATag);
end;

const
  C_BIN_SIZE = 1024;

function ExpectedBin: TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, C_BIN_SIZE);
  for LI := 0 to C_BIN_SIZE - 1 do
    Result[LI] := Byte((LI * 17) mod 251);
end;

{ 构建源树：
    root/a.txt, root/sub/b.bin, root/图片/图.txt, root/empty.bin,
    root/emptydir/, root/sub/link -> ../a.txt（符号链接，应被跳过） }
procedure BuildTree(const ARoot: string);
begin
  MkdirAll(ARoot + '/sub', PermDirDefault);
  MkdirAll(ARoot + '/图片', PermDirDefault);
  MkdirAll(ARoot + '/emptydir', PermDirDefault);
  WriteFileText(ARoot + '/a.txt', 'hello');
  WriteFile(ARoot + '/sub/b.bin', ExpectedBin);
  WriteFileText(ARoot + '/图片/图.txt', '内容');
  WriteFile(ARoot + '/empty.bin', nil);
  try
    Symlink('../a.txt', ARoot + '/sub/link');
  except
    on E: Exception do ;  { 平台不支持符号链接时跳过该用例面 }
  end;
end;

procedure TestPackExtractRoundtrip;
var
  LRoot, LDst: string;
  LZip, LGot: TBytes;
  LR: IZipReader;
  LI: Integer;
  LFoundLink, LFoundEmptyDir: Boolean;
begin
  LRoot := NewCaseDir('src');
  LDst := NewCaseDir('dst');
  try
    MkdirAll(LRoot, PermDirDefault);
    BuildTree(LRoot);
    LZip := ZipPackDir(LRoot);

    LR := NewZipReader(LZip);
    CheckEqual(Int64(7), Int64(LR.EntryCount),
      'three dirs plus four files packed');

    LFoundLink := False;
    LFoundEmptyDir := False;
    for LI := 0 to LR.EntryCount - 1 do
    begin
      if Pos('link', LR.Entry(LI).Name) > 0 then
        LFoundLink := True;
      if LR.Entry(LI).Name = 'emptydir/' then
        LFoundEmptyDir := True;
    end;
    Check(not LFoundLink, 'symlink skipped when packing');
    Check(LFoundEmptyDir, 'empty dir recorded with trailing slash');

    ZipExtractToDir(LZip, LDst);

    Check(SameBytes(ReadFile(LDst + '/a.txt'), BytesOfStr('hello')),
      'a.txt content restored');
    Check(SameBytes(ReadFile(LDst + '/sub/b.bin'), ExpectedBin),
      'b.bin content restored');
    Check(ReadFileText(LDst + '/图片/图.txt') = '内容',
      'unicode path content restored');
    CheckEqual(Int64(0), Int64(Length(ReadFile(LDst + '/empty.bin'))),
      'empty file restored');
    Check(DirectoryExists(LDst + '/emptydir'), 'empty dir restored');
    Check(not FileExists(LDst + '/sub/link'), 'symlink not extracted as file');

    { 打包保留 mtime（Stat 为纳秒；DOS 字段 2 秒粒度，±2s 容差） }
    LI := LR.Find('a.txt');
    Check(Abs(LR.Entry(LI).ModTimeUnixSec -
      Stat(LRoot + '/a.txt').ModTime div 1000000000) <= 2,
      'packed entry keeps source mtime');
    { 解包还原 mtime（同样 2 秒粒度） }
    Check(Abs(Stat(LDst + '/a.txt').ModTime -
      Stat(LRoot + '/a.txt').ModTime) <= 2000000000,
      'extracted file restores source mtime');
  finally
    RemoveAll(LRoot);
    RemoveAll(LDst);
  end;
end;

procedure TestPythonReadsPackedDir;
var
  LRoot, LDir: string;
  LZip: TBytes;
  LB: TBytes;
begin
  LRoot := NewCaseDir('psrc');
  LDir := NewCaseDir('pchk');
  try
    MkdirAll(LRoot, PermDirDefault);
    BuildTree(LRoot);
    LZip := ZipPackDir(LRoot);
    WriteFile(LDir + '/case.zip', LZip);

    LB := ExpectedBin;
    WriteFileText(LDir + '/manifest.tsv',
      'a.txt'#9'5'#9 + Hex32(Crc32OfBytes(BytesOfStr('hello'))) + #10 +
      'empty.bin'#9'0'#9'00000000'#10 +
      'emptydir/'#9'0'#9'00000000'#10 +
      'sub/b.bin'#9 + IntToStr(C_BIN_SIZE) + #9 + Hex32(Crc32OfBytes(LB)) + #10 +
      '图片/图.txt'#9 + IntToStr(Length(BytesOfStr('内容'))) + #9 +
        Hex32(Crc32OfBytes(BytesOfStr('内容'))) + #10);
    RunPy(C_PY_CHECK, LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LRoot);
    RemoveAll(LDir);
  end;
end;

procedure TestExtractPythonArchiveToDir;
var
  LDir, LDst: string;
  LRaw: TBytes;
begin
  LDir := NewCaseDir('pmk');
  LDst := NewCaseDir('x');
  try
    RunPy(C_PY_MAKE, LDir + '/py.zip', '');
    LRaw := ReadFile(LDir + '/py.zip');
    ZipExtractToDir(LRaw, LDst);

    Check(ReadFileText(LDst + '/docs/readme.txt') = 'read me',
      'nested file extracted');
    Check(ReadFileText(LDst + '/图片/说明.txt') = '图像说明',
      'unicode nested file extracted');
    CheckEqual(Int64(0), Int64(Length(ReadFile(LDst + '/empty.dat'))),
      'empty file extracted');
    Check(DirectoryExists(LDst + '/assets'), 'directory entry creates dir');
  finally
    RemoveAll(LDir);
    RemoveAll(LDst);
  end;
end;

procedure TestHostileEntryRefusedBeforeWrite;
var
  LDir, LDst, LEvilOutside: string;
  LRaw: TBytes;
  LGot: Boolean;
begin
  LDir := NewCaseDir('evil');
  LDst := NewCaseDir('victim');
  try
    RunPy(C_PY_EVIL, LDir + '/evil.zip', '');
    LRaw := ReadFile(LDir + '/evil.zip');
    LGot := False;
    try
      ZipExtractToDir(LRaw, LDst);
    except
      on E: EParseError do LGot := True;
    end;
    Check(LGot, 'zip-slip entry refused at extract');
    { 敌意条目指向 dest 的上级目录，绝不能落盘 }
    LEvilOutside := Copy(LDst, 1, Length(LDst) - 1);
    while (LEvilOutside <> '') and (LEvilOutside[Length(LEvilOutside)] <> '/') do
      Delete(LEvilOutside, Length(LEvilOutside), 1);
    LGot := FileExists(LEvilOutside + 'evil.txt');
    Check(not LGot, 'no file escaped outside destination');
  finally
    RemoveAll(LDir);
    RemoveAll(LDst);
  end;
end;

{ 权限位保留/还原：打包携带 unix 模式字，解包默认还原；
  RestoreMode=False 时保持平台默认权限 }
procedure TestPermissionRoundtrip;
var
  LRoot, LDst: string;
  LZip: TBytes;
  LR: IZipReader;
  LI: Integer;
  LOpts: TZipExtractOptions;
begin
  LRoot := NewCaseDir('perm');
  LDst := NewCaseDir('permdst');
  try
    MkdirAll(LRoot + '/d', PermDirDefault);
    WriteFileText(LRoot + '/d/f.txt', 'x');
    Chmod(LRoot + '/d/f.txt', TFilePermission(&640));   { 0640 }
    Chmod(LRoot + '/d', TFilePermission(&750));         { 0750 }
    LZip := ZipPackDir(LRoot);

    { 打包侧：模式字 = S_IFREG/S_IFDIR | 权限位 }
    LR := NewZipReader(LZip);
    LI := LR.Find('d/f.txt');
    Check(LI >= 0, 'packed file present');
    Check(ZipUnixModeOf(LR.Entry(LI)) = Word($8000 or &640),
      'packed file keeps unix mode');
    LI := LR.Find('d/');
    Check(LI >= 0, 'packed dir present');
    Check(ZipUnixModeOf(LR.Entry(LI)) = Word($4000 or &750),
      'packed dir keeps unix mode');

    ZipExtractToDir(LZip, LDst);
    Check(Word(Stat(LDst + '/d/f.txt').Permission) and &777 = &640,
      'file permission restored');
    Check(Word(Stat(LDst + '/d').Permission) and &777 = &750,
      'dir permission restored');

    { RestoreMode=False：不还原，保持写文件时的平台默认 }
    RemoveAll(LDst);
    LOpts := DefaultZipExtractOptions;
    LOpts.RestoreMode := False;
    ZipExtractToDirWithOptions(LZip, LDst, LOpts);
    Check(Word(Stat(LDst + '/d/f.txt').Permission) and &777 <> 0,
      'RestoreMode=False leaves default perms');
  finally
    RemoveAll(LRoot);
    RemoveAll(LDst);
  end;
end;

{ 符号链接条目策略：默认跳过；SkipSymlinks=False 显式创建真实符号链接 }
procedure TestSymlinkEntryPolicy;
var
  LDir, LDst: string;
  LRaw: TBytes;
  LOpts: TZipExtractOptions;
begin
  LDir := NewCaseDir('lnk');
  LDst := NewCaseDir('lnkdst');
  try
    RunPy(C_PY_LINK, LDir + '/l.zip', '');
    LRaw := ReadFile(LDir + '/l.zip');

    ZipExtractToDir(LRaw, LDst);
    Check(not FileExists(LDst + '/lnk'), 'symlink entry skipped by default');
    Check(ReadFileText(LDst + '/real.txt') = 'target',
      'regular sibling extracted');

    RemoveAll(LDst);
    LOpts := DefaultZipExtractOptions;
    LOpts.SkipSymlinks := False;
    ZipExtractToDirWithOptions(LRaw, LDst, LOpts);
    Check(SameBytes(ReadFile(LDst + '/lnk'), BytesOfStr('target')),
      'opt-in creates resolvable symlink');
  finally
    RemoveAll(LDir);
    RemoveAll(LDst);
  end;
end;

procedure TestExtractMaxTotalGuard;
var
  LW: IZipWriter;
  LZip: TBytes;
  LOpts: TZipExtractOptions;
  LDst: string;
  LGot: Boolean;
  LI: Integer;
  LData: TBytes;
begin
  LDst := NewCaseDir('bomb');
  try
    LW := NewZipWriter;
    SetLength(LData, 50000);
    for LI := 0 to High(LData) do LData[LI] := Byte(LI mod 251);
    LW.AddEntry('a.bin', LData);
    LW.AddEntry('b.bin', LData);
    LW.AddEntry('c.bin', LData);
    LZip := LW.Finish;
    LOpts := DefaultZipExtractOptions;
    LOpts.MaxTotalOutputSize := 100000; // 100KB < 150KB total
    LGot := False;
    try
      ZipExtractToDirWithOptions(LZip, LDst, LOpts);
    except
      on E: EIOError do LGot := Pos('total', LowerCase(E.Message)) > 0;
      on E: EParseError do LGot := True;
    end;
    Check(LGot, 'extract MaxTotalOutput guard fails closed');
  finally
    RemoveAll(LDst);
  end;
end;

procedure TestAtomicExtractRoundtrip;
var
  LRoot, LDst: string;
  LZip: TBytes;
begin
  LRoot := NewCaseDir('asrc');
  LDst := NewCaseDir('adst');
  RemoveAll(LDst);
  try
    MkdirAll(LRoot, PermDirDefault);
    BuildTree(LRoot);
    LZip := ZipPackDir(LRoot);
    ZipExtractToDirAtomic(LZip, LDst);
    Check(SameBytes(ReadFile(LDst + '/a.txt'), BytesOfStr('hello')), 'atomic a.txt restored');
    Check(SameBytes(ReadFile(LDst + '/sub/b.bin'), ExpectedBin), 'atomic b.bin restored');
    Check(not Exists(LDst + '.tmp'), 'atomic no temp leak');
  finally
    RemoveAll(LRoot);
    RemoveAll(LDst);
  end;
end;

procedure TestAtomicRefusesExisting;
var
  LRoot, LDst: string;
  LZip: TBytes;
  LGot: Boolean;
begin
  LRoot := NewCaseDir('asrc2');
  LDst := NewCaseDir('adst2');
  try
    MkdirAll(LRoot, PermDirDefault);
    BuildTree(LRoot);
    LZip := ZipPackDir(LRoot);
    ZipExtractToDir(LZip, LDst);
    LGot := False;
    try
      ZipExtractToDirAtomic(LZip, LDst);
    except
      on E: EArgumentError do LGot := Pos('already exists', E.Message) > 0;
    end;
    Check(LGot, 'atomic refuses existing destination');
    Check(SameBytes(ReadFile(LDst + '/a.txt'), BytesOfStr('hello')), 'atomic existing preserved');
  finally
    RemoveAll(LRoot);
    RemoveAll(LDst);
  end;
end;

procedure TestAtomicBombCleanup;
var
  LW: IZipWriter;
  LZip: TBytes;
  LDst: string;
  LOpts: TZipExtractOptions;
  LGot: Boolean;
begin
  LDst := NewCaseDir('abomb');
  RemoveAll(LDst);
  try
    LW := NewZipWriter;
    LW.AddEntry('bomb.bin', BytesOfStr('123456789012'));
    LZip := LW.Finish;
    LOpts := DefaultZipExtractOptions;
    LOpts.MaxTotalOutputSize := 1;
    LGot := False;
    try
      ZipExtractToDirAtomicWithOptions(LZip, LDst, LOpts);
    except
      on E: EIOError do LGot := Pos('total', LowerCase(E.Message)) > 0;
      on E: EParseError do LGot := True;
    end;
    Check(LGot, 'atomic bomb fails closed');
    Check(not Exists(LDst), 'atomic bomb leaves no dest and no temp');
  finally
    RemoveAll(LDst);
  end;
end;

procedure TestAtomicPermissionRestore;
var
  LRoot, LDst: string;
  LZip: TBytes;
  LR: IZipReader;
  LI: Integer;
begin
  LRoot := NewCaseDir('aperm');
  LDst := NewCaseDir('apermdst');
  RemoveAll(LDst);
  try
    MkdirAll(LRoot + '/d', PermDirDefault);
    WriteFileText(LRoot + '/d/f.txt', 'x');
    Chmod(LRoot + '/d/f.txt', TFilePermission(&640));
    Chmod(LRoot + '/d', TFilePermission(&750));
    LZip := ZipPackDir(LRoot);
    LR := NewZipReader(LZip);
    LI := LR.Find('d/f.txt');
    Check(LI >= 0, 'atomic perm packed file present');
    ZipExtractToDirAtomic(LZip, LDst);
    Check(Word(Stat(LDst + '/d/f.txt').Permission) and &777 = &640, 'atomic file perm restored');
    Check(Word(Stat(LDst + '/d').Permission) and &777 = &750, 'atomic dir perm restored');
  finally
    RemoveAll(LRoot);
    RemoveAll(LDst);
  end;
end;

procedure TestAtomicSymlinkPolicy;
var
  LDir, LDst: string;
  LRaw: TBytes;
  LOpts: TZipExtractOptions;
begin
  LDir := NewCaseDir('alnk');
  LDst := NewCaseDir('alnkdst');
  RemoveAll(LDst);
  try
    RunPy(C_PY_LINK, LDir + '/l.zip', '');
    LRaw := ReadFile(LDir + '/l.zip');
    ZipExtractToDirAtomic(LRaw, LDst);
    Check(not FileExists(LDst + '/lnk'), 'atomic symlink skipped by default');
    Check(ReadFileText(LDst + '/real.txt') = 'target', 'atomic regular sibling extracted');
    RemoveAll(LDst);
    LOpts := DefaultZipExtractOptions;
    LOpts.SkipSymlinks := False;
    ZipExtractToDirAtomicWithOptions(LRaw, LDst, LOpts);
    Check(SameBytes(ReadFile(LDst + '/lnk'), BytesOfStr('target')), 'atomic opt-in creates symlink');
  finally
    RemoveAll(LDir);
    RemoveAll(LDst);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.zip.fs');
  T.Test('Pack extract roundtrip', @TestPackExtractRoundtrip);
  T.Test('Python reads packed dir', @TestPythonReadsPackedDir);
  T.Test('Extract python archive to dir', @TestExtractPythonArchiveToDir);
  T.Test('Hostile entry refused before write', @TestHostileEntryRefusedBeforeWrite);
  T.Test('Permission roundtrip', @TestPermissionRoundtrip);
  T.Test('Symlink entry policy', @TestSymlinkEntryPolicy);
  T.Test('Extract MaxTotal guard', @TestExtractMaxTotalGuard);
  T.Test('Atomic extract roundtrip', @TestAtomicExtractRoundtrip);
  T.Test('Atomic refuses existing', @TestAtomicRefusesExisting);
  T.Test('Atomic bomb cleanup', @TestAtomicBombCleanup);
  T.Test('Atomic permission restore', @TestAtomicPermissionRestore);
  T.Test('Atomic symlink policy', @TestAtomicSymlinkPolicy);
  if not T.Run then Halt(1);
end.
