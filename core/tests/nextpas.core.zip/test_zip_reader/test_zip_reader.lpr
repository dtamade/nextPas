program test_zip_reader;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.zip,
  nextpas.core.zip.base;

var
  T: TTestSuite;

{ python3 zipfile 生成参考归档（独立实现交叉验证源）。
  argv[1]=输出 zip 路径 argv[2]=场景名。 }
const
  C_PY_MAKE =
    'import zipfile, sys'#10 +
    'path, scene = sys.argv[1], sys.argv[2]'#10 +
    'if scene == "deflate":'#10 +
    '    z = zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED)'#10 +
    'elif scene == "store":'#10 +
    '    z = zipfile.ZipFile(path, "w", zipfile.ZIP_STORED)'#10 +
    'else:'#10 +
    '    z = zipfile.ZipFile(path, "w")'#10 +
    'z.writestr("a.txt", b"hello world")'#10 +
    'z.writestr("dir/b.bin", bytes(range(256)) * 4)'#10 +
    'z.writestr("图片/图.txt", "图像内容".encode())'#10 +
    'z.writestr("empty.bin", b"")'#10 +
    'z.writestr("docs/", b"")'#10 +
    'z.close()'#10;

  C_PY_UNSAFE =
    'import zipfile, sys'#10 +
    'z = zipfile.ZipFile(sys.argv[1], "w")'#10 +
    'z.writestr("../evil.txt", b"x")'#10 +
    'z.close()'#10;

  C_PY_ZEROS =
    'import zipfile, sys'#10 +
    'z = zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED)'#10 +
    'z.writestr("zeros.bin", b"\x00" * (4 * 1024 * 1024))'#10 +
    'z.close()'#10;

  { force_zip64：小载荷也写 Zip64 extra，覆盖读端 Zip64 宽度解析 }
  C_PY_FORCEZ64 =
    'import zipfile, sys'#10 +
    'z = zipfile.ZipFile(sys.argv[1], "w")'#10 +
    'with z.open("a.bin", "w", force_zip64=True) as f:'#10 +
    '    f.write(b"hello zip64")'#10 +
    'z.close()'#10;

  { unix 外部属性：符号链接条目 + 自定义权限常规文件 }
  C_PY_ATTRS =
    'import zipfile, sys'#10 +
    'z = zipfile.ZipFile(sys.argv[1], "w")'#10 +
    'i = zipfile.ZipInfo("lnk")'#10 +
    'i.create_system = 3'#10 +
    'i.external_attr = (0o120777 << 16)'#10 +
    'z.writestr(i, "a.txt")'#10 +
    'j = zipfile.ZipInfo("script.sh")'#10 +
    'j.create_system = 3'#10 +
    'j.external_attr = (0o100750 << 16)'#10 +
    'z.writestr(j, b"#!/bin/sh\n")'#10 +
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

function ExpectedBin: TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, 1024);
  for LI := 0 to 1023 do
    Result[LI] := Byte(LI mod 256);
end;

procedure RunPy(const AScript: string; const AZipPath: string; const AScene: string);
var
  LPy: string;
  LOut: TProcessOutput;
begin
  if not TryLookPath('python3', LPy) then
  begin
    Check(False, 'python3 unavailable for zip reader cross-validation');
    Exit;
  end;
  LOut := Command(LPy).Arg('-c').Arg(AScript)
    .Arg(AZipPath).Arg(AScene).Output;
  Check(ProcessSucceeded(LOut),
    'python fixture exit ok: ' + Trim(LOut.StdErr));
end;

function NewCaseDir: string;
begin
  Result := TempDir(GetTempDir, 'zipreadertest');
end;

procedure TestEmptyArchiveReader;
var
  LR: IZipReader;
begin
  LR := NewZipReader(NewZipWriter.Finish);
  CheckEqual(Int64(0), Int64(LR.EntryCount), 'empty archive has zero entries');
end;

procedure TestPythonDeflateInterop;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LR: IZipReader;
  LGot: TBytes;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/py_deflate.zip';
    RunPy(C_PY_MAKE, LZipPath, 'deflate');
    LRaw := ReadFile(LZipPath);
    LR := NewZipReader(LRaw);

    CheckEqual(Int64(5), Int64(LR.EntryCount), 'five entries');

    CheckEqual(Int64(0), Int64(LR.Find('a.txt')), 'a.txt at index 0');
    CheckEqual(Int64(Ord(zmDeflate)), Int64(Ord(LR.Entry(LR.Find('a.txt')).Method)),
      'deflate archive maps to zmDeflate');
    CheckEqual(Int64(8), Int64(LR.Entry(0).MethodCode), 'method code 8');
    CheckEqual(Int64(11), Int64(LR.Entry(0).UncompressedSize), 'a.txt size');

    LGot := LR.ExtractToBytesByName('a.txt');
    Check(SameBytes(LGot, BytesOfStr('hello world')), 'a.txt content');

    LGot := LR.ExtractToBytesByName('dir/b.bin');
    Check(SameBytes(LGot, ExpectedBin), 'dir/b.bin content 1024 bytes');

    LGot := LR.ExtractToBytesByName('图片/图.txt');
    Check(SameBytes(LGot, BytesOfStr('图像内容')), 'unicode entry content');

    LGot := LR.ExtractToBytesByName('empty.bin');
    CheckEqual(Int64(0), Int64(Length(LGot)), 'empty entry extracts empty');

    Check(LR.Entry(LR.Find('docs/')).IsDirectory, 'docs/ flagged directory');
    Check(not LR.Entry(0).IsDirectory, 'file not flagged directory');
    Check(LR.Entry(0).ModTimeUnixSec > 0, 'dos time decoded to unix seconds');

    CheckEqual(Int64(-1), Int64(LR.Find('missing.txt')), 'missing find is -1');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestPythonStoreInterop;
var
  LDir, LZipPath: string;
  LR: IZipReader;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/py_store.zip';
    RunPy(C_PY_MAKE, LZipPath, 'store');
    LR := NewZipReader(ReadFile(LZipPath));
    CheckEqual(Int64(5), Int64(LR.EntryCount), 'five entries in store archive');
    CheckEqual(Int64(0), Int64(LR.Entry(0).MethodCode), 'method code 0');
    Check(SameBytes(LR.ExtractToBytesByName('dir/b.bin'), ExpectedBin),
      'stored payload round-trips');
    Check(SameBytes(LR.ExtractToBytesByName('图片/图.txt'), BytesOfStr('图像内容')),
      'stored unicode content');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestWriterReaderRoundtrip;
var
  LW: IZipWriter;
  LR: IZipReader;
  LA, LB: TBytes;
begin
  LA := BytesOfStr(#$00#$FF#$80'payload');
  LW := NewZipWriter;
  LW.AddEntry('one.bin', LA);
  LW.AddEntryWithTime('sub/two.bin', nil, 1787574896);
  LW.AddEntry('中文.文', BytesOfStr('内容'));
  LR := NewZipReader(LW.Finish);

  CheckEqual(Int64(3), Int64(LR.EntryCount), 'three entries');
  Check(SameBytes(LR.ExtractToBytesByName('one.bin'), LA), 'one.bin equality');
  CheckEqual(Int64(1787574896), Int64(LR.Entry(1).ModTimeUnixSec),
    'explicit time survives roundtrip');
  Check(SameBytes(LR.ExtractToBytesByName('sub/two.bin'), nil), 'zero-len entry');
  Check(SameBytes(LR.ExtractToBytesByName('中文.文'), BytesOfStr('内容')),
    'unicode name roundtrip');
  LB := LR.ExtractToBytes(LR.Find('one.bin'));
  Check(SameBytes(LB, LA), 'indexed extract equality');
end;

procedure TestCrcTamperDetected;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LR: IZipReader;
  LGot: Boolean;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/py_store.zip';
    RunPy(C_PY_MAKE, LZipPath, 'store');
    
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;
  { 首条目 a.txt 的 store 载荷位于 local header(30)+名字(5)=35 }
  LRaw[35] := LRaw[35] xor $01;
  LR := NewZipReader(LRaw);
  LGot := False;
  try
    LR.ExtractToBytesByName('a.txt');
  except
    on E: EIOError do LGot := True;
  end;
  Check(LGot, 'tampered stored payload raises crc mismatch');
end;

procedure TestTruncatedAndGarbage;
var
  LFull, LCut: TBytes;
  LGot: Boolean;
  LI: Integer;
begin
  LFull := NewZipWriter.Finish;
  SetLength(LCut, Length(LFull) - 10);
  for LI := 0 to High(LCut) do LCut[LI] := LFull[LI];
  LGot := False;
  try
    NewZipReader(LCut);
  except
    on E: EParseError do LGot := True;
  end;
  Check(LGot, 'truncated EOCD raises parse error');

  SetLength(LCut, 100);
  for LI := 0 to High(LCut) do
    if Odd(LI) then LCut[LI] := $55 else LCut[LI] := $AA;
  LGot := False;
  try
    NewZipReader(LCut);
  except
    on E: EParseError do LGot := True;
  end;
  Check(LGot, 'garbage raises no-eocd parse error');
end;

procedure TestUnsupportedAndEncrypted;
var
  LW: IZipWriter;
  LRaw: TBytes;
  LR: IZipReader;
  LCDPos: Integer;
  LGot: Boolean;

  function FindCentralSig(const AB: TBytes): Integer;
  var
    LI: Integer;
  begin
    Result := -1;
    for LI := 0 to Length(AB) - 4 do
      if (AB[LI] = $50) and (AB[LI + 1] = $4B) and
         (AB[LI + 2] = $01) and (AB[LI + 3] = $02) then
        Exit(LI);
  end;

begin
  { 单条目 store 归档：local 在 0，payload 30+5=35 起 }
  LW := NewZipWriter;
  LW.AddEntry('x.txt', BytesOfStr('v'));
  LRaw := LW.Finish;

  { patch central method -> 99 }
  LCDPos := FindCentralSig(LRaw);
  Check(LCDPos > 0, 'central sig located');
  LRaw[LCDPos + 10] := 99;
  LR := NewZipReader(LRaw);
  LGot := False;
  try
    LR.ExtractToBytes(0);
  except
    on E: ENotSupportedError do LGot := True;
  end;
  Check(LGot, 'unknown method raises not-supported');

  { 还原 method、patch 加密位 }
  LW := NewZipWriter;
  LW.AddEntry('x.txt', BytesOfStr('v'));
  LRaw := LW.Finish;
  LCDPos := FindCentralSig(LRaw);
  LRaw[LCDPos + 8] := LRaw[LCDPos + 8] or $01;
  LR := NewZipReader(LRaw);
  LGot := False;
  try
    LR.ExtractToBytes(0);
  except
    on E: ENotSupportedError do LGot := True;
  end;
  Check(LGot, 'encrypted flag raises not-supported');
end;

procedure TestUnsafeNameRefusedAtExtract;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LR: IZipReader;
  LGot: Boolean;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/evil.zip';
    RunPy(C_PY_UNSAFE, LZipPath, '');
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;
  LR := NewZipReader(LRaw);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'evil archive lists one entry');
  Check(LR.Find('../evil.txt') >= 0, 'listing sees hostile name');
  LGot := False;
  try
    LR.ExtractToBytes(0);
  except
    on E: EParseError do LGot := True;
  end;
  Check(LGot, 'zip-slip name refused at extract');
end;

procedure TestBombGuardByMaxOutput;
var
  LDir, LZipPath: string;
  LRaw, LGot: TBytes;
  LOpts: TZipReadOptions;
  LR: IZipReader;
  LI: Integer;
  LAllZero: Boolean;
  LGotRaise: Boolean;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/zeros.zip';
    RunPy(C_PY_ZEROS, LZipPath, '');
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;

  { 默认上限内正常解出 4 MiB 全零 }
  LR := NewZipReader(LRaw);
  LGot := LR.ExtractToBytes(0);
  CheckEqual(Int64(4 * 1024 * 1024), Int64(Length(LGot)), 'zeros extract size');
  LAllZero := True;
  for LI := 0 to High(LGot) do
    if LGot[LI] <> 0 then
    begin
      LAllZero := False;
      Break;
    end;
  Check(LAllZero, 'zeros content all zero');

  { 显式收紧上限后必须拒绝 }
  LOpts.MaxOutputSize := 1024;
  LR := NewZipReaderWithOptions(LRaw, LOpts);
  LGotRaise := False;
  try
    LR.ExtractToBytes(0);
  except
    on E: Exception do
      LGotRaise := Pos('EIOError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'over-limit output raises io error');
end;

procedure TestIndexGuards;
var
  LR: IZipReader;
  LGot: Boolean;
begin
  LR := NewZipReader(NewZipWriter.Finish);
  LGot := False;
  try
    LR.Entry(0);
  except
    on E: EIndexOutOfRangeError do LGot := True;
  end;
  Check(LGot, 'entry index guard on empty archive');
  LGot := False;
  try
    LR.ExtractToBytesByName('nope');
  except
    on E: ENotFoundError do LGot := True;
  end;
  Check(LGot, 'extract-by-name missing raises not found');
end;

procedure TestPythonForceZip64;
var
  LDir, LZipPath: string;
  LRaw, LGot: TBytes;
  LR: IZipReader;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/force64.zip';
    RunPy(C_PY_FORCEZ64, LZipPath, '');
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;
  LR := NewZipReader(LRaw);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'one forced-zip64 entry');
  CheckEqual(Int64(11), Int64(LR.Entry(0).UncompressedSize),
    'size decoded from zip64 extra');
  LGot := LR.ExtractToBytesByName('a.bin');
  Check(SameBytes(LGot, BytesOfStr('hello zip64')), 'forced-zip64 content');
end;

{ python 造 unix 属性条目：符号链接（S_IFLNK）与自定义权限常规文件 }
procedure TestExternalAttrsAndSymlink;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LR: IZipReader;
  LI: Integer;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/attrs.zip';
    RunPy(C_PY_ATTRS, LZipPath, '');
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;
  LR := NewZipReader(LRaw);

  LI := LR.Find('lnk');
  Check(LI >= 0, 'symlink entry present');
  Check(LR.Entry(LI).IsSymlink, 'IsSymlink detected from S_IFLNK');
  Check(not LR.Entry(LI).IsDirectory, 'symlink is not a directory');
  Check(ZipUnixModeOf(LR.Entry(LI)) = Word($A000 or &777),
    'symlink mode word decoded');
  Check(SameBytes(LR.ExtractToBytesByName('lnk'), BytesOfStr('a.txt')),
    'symlink payload readable');

  LI := LR.Find('script.sh');
  Check(LI >= 0, 'mode-carrying file present');
  Check(not LR.Entry(LI).IsSymlink, 'regular file not flagged symlink');
  Check(ZipUnixModeOf(LR.Entry(LI)) = Word($8000 or &750),
    'file mode 0750 decoded');
end;

{ 流式写器风格 data descriptor：本地头 bit3 置位、本地 crc/尺寸为占位零，
  提取以 central 为权威值，必须天然容忍 }
procedure TestDataDescriptorTolerance;
var
  W: IZipWriter;
  LZip, LPatched, LGot: TBytes;
  LR: IZipReader;
  LI, LLho, LI2: Integer;
begin
  W := NewZipWriter;
  W.AddEntryWithTime('d.txt', BytesOfStr('payload'), 1000000);
  LZip := W.Finish;

  LR := NewZipReader(LZip);
  LI := LR.Find('d.txt');
  Check(LI >= 0, 'descriptor fixture entry present');
  LLho := Integer(LR.Entry(LI).LocalHeaderOffset);

  LPatched := Copy(LZip, 0, Length(LZip));
  LPatched[LLho + 6] := LPatched[LLho + 6] or $08;   { general flag bit3 }
  for LI2 := LLho + 14 to LLho + 25 do               { 本地 crc/尺寸占位清零 }
    LPatched[LI2] := 0;

  LR := NewZipReader(LPatched);
  LGot := LR.ExtractToBytesByName('d.txt');
  Check(SameBytes(LGot, BytesOfStr('payload')),
    'data-descriptor local headers tolerated');
end;

begin
  T := TTestSuite.Create('nextpas.core.zip.reader');
  T.Test('Empty archive reader', @TestEmptyArchiveReader);
  T.Test('Python deflate interop', @TestPythonDeflateInterop);
  T.Test('Python store interop', @TestPythonStoreInterop);
  T.Test('Python force zip64', @TestPythonForceZip64);
  T.Test('Writer reader roundtrip', @TestWriterReaderRoundtrip);
  T.Test('CRC tamper detected', @TestCrcTamperDetected);
  T.Test('Truncated and garbage', @TestTruncatedAndGarbage);
  T.Test('Unsupported and encrypted', @TestUnsupportedAndEncrypted);
  T.Test('Unsafe name refused at extract', @TestUnsafeNameRefusedAtExtract);
  T.Test('Bomb guard by max output', @TestBombGuardByMaxOutput);
  T.Test('Index guards', @TestIndexGuards);
  T.Test('External attrs and symlink', @TestExternalAttrsAndSymlink);
  T.Test('Data descriptor tolerance', @TestDataDescriptorTolerance);
  if not T.Run then Halt(1);
end.
