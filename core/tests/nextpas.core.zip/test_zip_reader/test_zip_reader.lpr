program test_zip_reader;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.compress.intf,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
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

{ 流式读端全量读出必须与一次性提取逐字节一致（deflate 与 store 双路径） }
procedure TestStreamOpenMatchesExtract;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LR: IZipReader;
  LS: IDecompressReader;
  LGot, LWant: TBytes;
  LBuf: array[0..511] of Byte;
  LI: Integer;
  LN, LTotal: SizeUInt;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/py_deflate.zip';
    RunPy(C_PY_MAKE, LZipPath, 'deflate');
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;
  LR := NewZipReader(LRaw);

  { deflate 条目：按索引打开，分块拉取拼装 }
  LWant := LR.ExtractToBytes(LR.Find('dir/b.bin'));
  SetLength(LGot, Length(LWant));
  LS := LR.OpenEntry(LR.Find('dir/b.bin'));
  LTotal := 0;
  repeat
    LN := LS.Read(LBuf[0], SizeOf(LBuf));
    for LI := 0 to Integer(LN) - 1 do
      LGot[Integer(LTotal) + LI] := LBuf[LI];
    Inc(LTotal, LN);
  until LN = 0;
  Check(SameBytes(LGot, LWant), 'streamed deflate equals one-shot extract');
  CheckEqual(Int64(Length(LWant)), Int64(LTotal), 'stream total bytes');

  { store 条目：按名打开 }
  LWant := LR.ExtractToBytesByName('a.txt');
  SetLength(LGot, 0);
  LS := LR.OpenEntryByName('a.txt');
  LN := LS.Read(LBuf[0], 64);
  SetLength(LGot, Integer(LN));
  for LI := 0 to Integer(LN) - 1 do
    LGot[LI] := LBuf[LI];
  Check(SameBytes(LGot, LWant), 'streamed store equals extract');
end;

{ 1 字节粒度拉取：解压器与校验层在最小读取步长下正确 }
procedure TestStreamByteGranular;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LR: IZipReader;
  LS: IDecompressReader;
  LGot: string;
  LB: Byte;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/py_deflate.zip';
    RunPy(C_PY_MAKE, LZipPath, 'deflate');
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;
  LR := NewZipReader(LRaw);
  LS := LR.OpenEntryByName('a.txt');
  LGot := '';
  while LS.Read(LB, 1) = 1 do
    LGot := LGot + Chr(LB);
  Check(LGot = 'hello world', 'byte-granular stream content');
end;

{ 篡改载荷后流式读到 EOF 必须触发校验失败（EOF 处强制尺寸+CRC32） }
procedure TestStreamCrcTamperAtEof;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LR: IZipReader;
  LS: IDecompressReader;
  LBuf: array[0..63] of Byte;
  LGotRaise: Boolean;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/py_store.zip';
    RunPy(C_PY_MAKE, LZipPath, 'store');
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;
  { a.txt store 载荷位于 local header(30)+名字(5)=35 }
  LRaw[35] := LRaw[35] xor $01;
  LR := NewZipReader(LRaw);
  LS := LR.OpenEntryByName('a.txt');
  LGotRaise := False;
  try
    while LS.Read(LBuf[0], SizeOf(LBuf)) > 0 do ;
    { 读到 EOF 的这一次返回前应完成校验并 raise }
  except
    on E: Exception do
      LGotRaise := Pos('EIOError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'tampered payload raises crc mismatch at stream eof');
end;

{ 放弃未读完的流：Close 跳过校验，不 raise（契约允许中途放弃） }
procedure TestStreamAbandonSkipsVerify;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LR: IZipReader;
  LS: IDecompressReader;
  LB: Byte;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/py_store.zip';
    RunPy(C_PY_MAKE, LZipPath, 'store');
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;
  LRaw[35] := LRaw[35] xor $01;
  LR := NewZipReader(LRaw);
  LS := LR.OpenEntryByName('a.txt');
  CheckEqual(Int64(1), Int64(NativeUInt(LS.Read(LB, 1))), 'first byte readable');
  LS.Close;  { 未到 EOF：按契约放弃剩余数据且不校验 }
  Check(True, 'abandoned stream close skips verification');
end;

{ 流式路径同样受 MaxOutputSize 约束：超限在流中途中断 }
procedure TestStreamBombCap;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LOpts: TZipReadOptions;
  LR: IZipReader;
  LS: IDecompressReader;
  LBuf: array[0..4095] of Byte;
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
  LOpts.MaxOutputSize := 1024;
  LR := NewZipReaderWithOptions(LRaw, LOpts);
  LS := LR.OpenEntry(0);
  LGotRaise := False;
  try
    while LS.Read(LBuf[0], SizeOf(LBuf)) > 0 do ;
  except
    on E: Exception do
      LGotRaise := Pos('EIOError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'stream read stops at max output size');
end;

{ 同一 reader 并发打开多个流交错读取，互不串扰 }
procedure TestStreamConcurrentInterleaved;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LR: IZipReader;
  SA, SB: IDecompressReader;
  LA, LB: string;
  BA, BB: Byte;
  DoneA, DoneB: Boolean;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/py_deflate.zip';
    RunPy(C_PY_MAKE, LZipPath, 'deflate');
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;
  LR := NewZipReader(LRaw);
  SA := LR.OpenEntryByName('a.txt');
  SB := LR.OpenEntryByName('dir/b.bin');
  LA := '';
  LB := '';
  DoneA := False;
  DoneB := False;
  { 返回 0 即 EOF：停止再读该流 }
  repeat
    if not DoneA then
      if SA.Read(BA, 1) = 1 then
        LA := LA + Chr(BA)
      else
        DoneA := True;
    if not DoneB then
      if SB.Read(BB, 1) = 1 then
        LB := LB + Chr(BB)
      else
        DoneB := True;
  until DoneA and DoneB;
  Check(LA = 'hello world', 'interleaved stream A content');
  Check(Length(LB) = 1024, 'interleaved stream B length');
  { b.bin 内容为 range(256)*4；string 下标 1 基，LB[10] 即偏移 9 }
  Check(Byte(LB[10]) = Byte(9), 'interleaved stream B offset content');
end;

{ CopyEntryTo 泵送整条目到任意 IWriter，返回字节数并完成 EOF 校验 }
procedure TestCopyEntryToSink;
var
  LDir, LZipPath: string;
  LRaw: TBytes;
  LR: IZipReader;
  LDst: IStream;
  LW: IWriter;
  LGot: TBytes;
  LN, LBack: SizeUInt;
begin
  LDir := NewCaseDir;
  try
    LZipPath := LDir + '/py_deflate.zip';
    RunPy(C_PY_MAKE, LZipPath, 'deflate');
    LRaw := ReadFile(LZipPath);
  finally
    RemoveAll(LDir);
  end;
  LR := NewZipReader(LRaw);

  LDst := CreateBytesStream(64);
  LW := LDst as IWriter;
  LN := LR.CopyEntryTo(LR.Find('dir/b.bin'), LW);
  CheckEqual(Int64(1024), Int64(NativeUInt(LN)), 'copy entry returns byte count');
  SetLength(LGot, Integer(LDst.Size));
  if Length(LGot) > 0 then
  begin
    LDst.Position := 0;
    LBack := LDst.Read(LGot[0], Length(LGot));
    CheckEqual(Int64(1024), Int64(NativeUInt(LBack)), 'sink captured all bytes');
  end;
  Check(SameBytes(LGot, ExpectedBin), 'copied content matches');

  { 空条目泵送：0 字节且不 raise }
  LN := LR.CopyEntryTo(LR.Find('empty.bin'), CreateBytesStream(16) as IWriter);
  CheckEqual(Int64(0), Int64(NativeUInt(LN)), 'empty entry copies zero bytes');
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
  T.Test('Stream open matches extract', @TestStreamOpenMatchesExtract);
  T.Test('Stream byte granular', @TestStreamByteGranular);
  T.Test('Stream crc tamper at eof', @TestStreamCrcTamperAtEof);
  T.Test('Stream abandon skips verify', @TestStreamAbandonSkipsVerify);
  T.Test('Stream bomb cap', @TestStreamBombCap);
  T.Test('Stream concurrent interleaved', @TestStreamConcurrentInterleaved);
  T.Test('Copy entry to sink', @TestCopyEntryToSink);
  if not T.Run then Halt(1);
end.
