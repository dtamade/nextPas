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
  nextpas.core.io.base,
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

  { patch central method -> 99（无加密标志）：六期起在解析期即以
    EParseError 拒绝（AE extra 缺失） }
  LCDPos := FindCentralSig(LRaw);
  Check(LCDPos > 0, 'central sig located');
  LRaw[LCDPos + 10] := 99;
  LR := nil;
  LGot := False;
  try
    LR := NewZipReader(LRaw);
  except
    on E: EParseError do LGot := True;
  end;
  Check(LGot, 'method 99 without flag refused at parse');

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

procedure TestStoreBombGuardByMaxOutput;
var
  LW: IZipWriter;
  LRaw: TBytes;
  LOpts: TZipReadOptions;
  LR: IZipReader;
  LPayload: TBytes;
  LGotRaise: Boolean;
begin
  SetLength(LPayload, 4 * 1024 * 1024);
  FillChar(LPayload[0], Length(LPayload), 0);
  LW := NewZipWriter;
  LW.AddEntry('store_bomb.bin', LPayload); { store, not deflate }
  LRaw := LW.Finish;
  LOpts := DefaultZipReadOptions;
  LOpts.MaxOutputSize := 1024;
  LR := NewZipReaderWithOptions(LRaw, LOpts);
  LGotRaise := False;
  try
    LR.ExtractToBytes(0);
  except
    on E: Exception do
      LGotRaise := Pos('EIOError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'store over-limit raises io error (P0-1)');
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

{ ---- 可定位流来源读器（NewZipReaderFrom）---- }

type
  { 仅实现 IStream 的最小源（无 IReaderAt）：验证构造期 fail-closed }
  TNoAtStream = class(TInterfacedObject, IStream)
  private
    FData: TBytes;
  public
    constructor Create(const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    property Size: Int64 read GetSize;
    property Position: Int64 read GetPosition write SetPosition;
  end;

constructor TNoAtStream.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
end;

function TNoAtStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount;
end;

function TNoAtStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount;
end;

function TNoAtStream.Seek(const AOffset: Int64;
  const AOrigin: TSeekOrigin): Int64;
begin
  Result := AOffset;
end;

procedure TNoAtStream.Close;
begin
end;

function TNoAtStream.GetSize: Int64;
begin
  Result := Length(FData);
end;

function TNoAtStream.GetPosition: Int64;
begin
  Result := 0;
end;

procedure TNoAtStream.SetPosition(const AValue: Int64);
begin
end;

function PatternBytes(ALen: Integer; ASeed: Integer): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, ALen);
  for LI := 0 to ALen - 1 do
    Result[LI] := Byte((LI * 3 + ASeed + (LI shr 5)) mod 251);
end;

{ 固定混合条目面：store/deflate/目录/unicode 名，显式时间戳 }
function BuildMixedArchive: TBytes;
var
  LW: IZipWriter;
begin
  LW := NewZipWriter;
  LW.AddEntryWithTime('hello.txt', BytesOfStr('hello world'), 1787574896);
  LW.AddEntryDeflateWithTime('data.bin', PatternBytes(20000, 11), 1787574896);
  LW.AddDirectoryWithTime('assets', 1780000000);
  LW.AddEntryDeflateWithTime('数据/文件.txt',
    BytesOfStr('unicode nested payload'), 1787574896);
  Result := LW.Finish;
end;

{ 元数据逐项对齐（与内存读器互为参照） }
procedure CheckParity(const AMem, ASrc: IZipReader);
var
  LI: Integer;
  LE, LS: TZipEntryInfo;
begin
  CheckEqual(Int64(AMem.EntryCount), Int64(ASrc.EntryCount),
    'source reader entry count parity');
  for LI := 0 to AMem.EntryCount - 1 do
  begin
    LE := AMem.Entry(LI);
    LS := ASrc.Entry(LI);
    Check(LE.Name = LS.Name, 'parity name: ' + LE.Name);
    CheckEqual(Int64(Integer(LE.MethodCode)), Int64(Integer(LS.MethodCode)),
      'parity method: ' + LE.Name);
    CheckEqual(Int64(LE.CompressedSize), Int64(LS.CompressedSize),
      'parity csize: ' + LE.Name);
    CheckEqual(Int64(LE.UncompressedSize), Int64(LS.UncompressedSize),
      'parity usize: ' + LE.Name);
    CheckEqual(Int64(LE.Crc32), Int64(LS.Crc32),
      'parity crc: ' + LE.Name);
    CheckEqual(Int64(LE.ExternalAttrs), Int64(LS.ExternalAttrs),
      'parity attrs: ' + LE.Name);
  end;
end;

procedure TestSourceReaderParityAndExtract;
var
  LArchive: TBytes;
  LMem, LSrc: IZipReader;
  LS: IStream;
  LI: Integer;
begin
  LArchive := BuildMixedArchive;
  LMem := NewZipReader(LArchive);

  { 内存流源：元数据对齐 + 提取逐一相等 }
  LS := CreateBytesStreamFrom(LArchive);
  LSrc := NewZipReaderFrom(LS);
  CheckParity(LMem, LSrc);
  for LI := 0 to LSrc.EntryCount - 1 do
    if not LSrc.Entry(LI).IsDirectory then
      Check(SameBytes(LMem.ExtractToBytes(LI), LSrc.ExtractToBytes(LI)),
        'source extract equals memory: ' + LSrc.Entry(LI).Name);

  { 空归档（仅 EOCD）也可从源打开 }
  LS := CreateBytesStreamFrom(NewZipWriter.Finish);
  CheckEqual(Int64(0), Int64(NewZipReaderFrom(LS).EntryCount),
    'empty archive from source');
end;

{ 同一源读器并发打开两条流交错小块读取——各自区间游标独立；
  CopyEntryTo 经源路径泵送 }
procedure TestSourceReaderStreamsInterleavedAndCopy;
var
  LR: IZipReader;
  LS1, LS2: IDecompressReader;
  LGot, LGot2: TBytes;
  LB: Byte;
  LN1, LN2: SizeUInt;
  LDst: IStream;
  LW: IWriter;
  LCopied: TBytes;
  LBack: SizeUInt;
begin
  LR := NewZipReaderFrom(CreateBytesStreamFrom(BuildMixedArchive));

  SetLength(LGot, 0);
  SetLength(LGot2, 0);
  LS1 := LR.OpenEntryByName('data.bin');
  LS2 := LR.OpenEntryByName('hello.txt');
  repeat
    LN1 := LS1.Read(LB, 7);
    if LN1 > 0 then
    begin
      SetLength(LGot, Length(LGot) + Integer(LN1));
      Move(LB, LGot[Length(LGot) - Integer(LN1)], LN1);
    end;
    LN2 := LS2.Read(LB, 3);
    if LN2 > 0 then
    begin
      SetLength(LGot2, Length(LGot2) + Integer(LN2));
      Move(LB, LGot2[Length(LGot2) - Integer(LN2)], LN2);
    end;
  until (LN1 = 0) and (LN2 = 0);
  LS1.Close;
  LS2.Close;
  Check(SameBytes(LGot, PatternBytes(20000, 11)),
    'interleaved deflate stream intact');
  Check(SameBytes(LGot2, BytesOfStr('hello world')),
    'interleaved store stream intact');

  LDst := CreateBytesStream(64);
  LW := LDst as IWriter;
  CheckEqual(Int64(20000),
    Int64(NativeUInt(LR.CopyEntryTo(LR.Find('data.bin'), LW))),
    'source copy pumped length');
  SetLength(LCopied, Integer(LDst.Size));
  LDst.Position := 0;
  LBack := LDst.Read(LCopied[0], Length(LCopied));
  CheckEqual(Int64(Length(LCopied)), Int64(NativeUInt(LBack)),
    'source copy read back fully');
  Check(SameBytes(LCopied, PatternBytes(20000, 11)),
    'source copied content matches');
end;

{ 定位读语义：调用方 Position 不受影响；nil / 无定位读 / 垃圾 / 截断源
  在构造期显式失败 }
procedure TestSourceReaderGuardsAndPosition;
var
  LArchive, LBad: TBytes;
  LS: IStream;
  LR: IZipReader;
  LGot: TBytes;
  LGotRaise: Boolean;
  LI: Integer;
begin
  LArchive := BuildMixedArchive;

  { Position 不受构造与提取影响 }
  LS := CreateBytesStreamFrom(LArchive);
  LS.Position := 3;
  LR := NewZipReaderFrom(LS);
  LGot := LR.ExtractToBytesByName('hello.txt');
  Check(SameBytes(LGot, BytesOfStr('hello world')),
    'extract with mid-position source works');
  CheckEqual(Int64(3), Int64(LS.Position), 'caller position untouched');

  { nil 源：EArgumentError }
  LGotRaise := False;
  try
    NewZipReaderFrom(nil);
  except
    on E: Exception do
      LGotRaise := Pos('EArgumentError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'nil source raises argument error');

  { 无 IReaderAt 的源：构造期 ENotSupportedError（fail-closed） }
  LGotRaise := False;
  try
    NewZipReaderFrom(TNoAtStream.Create(LArchive));
  except
    on E: Exception do
      LGotRaise := Pos('ENotSupportedError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'source without positioned reads refused');

  { 无 EOCD 的垃圾字节 }
  SetLength(LBad, 100);
  for LI := 0 to High(LBad) do
    LBad[LI] := Byte((LI * 31 + 7) mod 253);
  LGotRaise := False;
  try
    NewZipReaderFrom(CreateBytesStreamFrom(LBad));
  except
    on E: Exception do
      LGotRaise := Pos('EParseError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'garbage source raises parse error');

  { 截断掉 EOCD 尾部 }
  LBad := Copy(LArchive, 0, Length(LArchive) - 10);
  LGotRaise := False;
  try
    NewZipReaderFrom(CreateBytesStreamFrom(LBad));
  except
    on E: Exception do
      LGotRaise := Pos('EParseError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'truncated tail raises parse error');
end;

{ ForceZip64 结构经源路径解析；MaxOutputSize 对提取与流式两条路径生效 }
procedure TestSourceReaderZip64AndMaxOutput;
var
  LOptsW: TZipWriteOptions;
  LOptsR: TZipReadOptions;
  LW: IZipWriter;
  LS: IStream;
  LR: IZipReader;
  LSt: IDecompressReader;
  LGot: TBytes;
  LB: Byte;
  LGotRaise: Boolean;
begin
  LOptsW := DefaultZipWriteOptions;
  LOptsW.ForceZip64 := True;
  LW := NewZipWriterWithOptions(LOptsW);
  LW.AddEntryWithTime('tiny.txt', BytesOfStr('hello zip64'), 1787574896);
  LS := CreateBytesStreamFrom(LW.Finish);
  LR := NewZipReaderFrom(LS);
  CheckEqual(Int64(11), Int64(LR.Entry(0).UncompressedSize),
    'zip64 source usize from extra field');
  Check(SameBytes(LR.ExtractToBytesByName('tiny.txt'),
    BytesOfStr('hello zip64')), 'zip64 source extract');

  { 提取路径：超上限 raise EIOError }
  LS := CreateBytesStreamFrom(BuildMixedArchive);
  LOptsR := DefaultZipReadOptions;
  LOptsR.MaxOutputSize := 16;
  LR := NewZipReaderFromWithOptions(LS, LOptsR);
  LGotRaise := False;
  try
    LGot := LR.ExtractToBytesByName('data.bin');
  except
    on E: Exception do
      LGotRaise := Pos('EIOError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'max output enforced on source extract');

  { 流式路径：读取途中超上限 raise }
  LGotRaise := False;
  LSt := LR.OpenEntryByName('data.bin');
  try
    while LSt.Read(LB, 8) > 0 do ;
  except
    on E: Exception do
      LGotRaise := Pos('EIOError', E.ClassName) > 0;
  end;
  LSt.Close;
  Check(LGotRaise, 'max output enforced mid-stream on source path');
end;

{ 跨条目总上限 MaxTotalOutputSize：单条目均在 MaxOutput 内，但总和超限即
  在构造期拒绝（fail-closed，防“多小条目绕过单条目上限”型 zip bomb） }
procedure TestTotalOutputLimit;
var
  LW: IZipWriter;
  LArch: TBytes;
  LOpts: TZipReadOptions;
  LR: IZipReader;
  LS: IStream;
  LGotRaise: Boolean;
  LI: Integer;
begin
  LW := NewZipWriter;
  for LI := 0 to 4 do
    LW.AddEntry('f' + IntToStr(LI) + '.bin', PatternBytes(100, LI));
  LArch := LW.Finish;
  { 5*100=500 总量，设限 250 应在解析期即拒绝 }
  LOpts := DefaultZipReadOptions;
  LOpts.MaxTotalOutputSize := 250;
  LGotRaise := False;
  try
    LR := NewZipReaderWithOptions(LArch, LOpts);
    LR.EntryCount;
  except
    on E: Exception do
      LGotRaise := Pos('EIOError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'total limit enforced on memory reader');

  LGotRaise := False;
  try
    LS := CreateBytesStreamFrom(LArch);
    LR := NewZipReaderFromWithOptions(LS, LOpts);
    LR.EntryCount;
  except
    on E: Exception do
      LGotRaise := Pos('EIOError', E.ClassName) > 0;
  end;
  Check(LGotRaise, 'total limit enforced on source reader');

  { 合法边界：总和恰等于上限不拒绝 }
  LOpts.MaxTotalOutputSize := 500;
  LR := NewZipReaderWithOptions(LArch, LOpts);
  CheckEqual(Int64(5), Int64(LR.EntryCount), 'total limit exact boundary');
  Check(SameBytes(LR.ExtractToBytesByName('f0.bin'), PatternBytes(100, 0)),
    'boundary still extracts');

  { 0=不限：500 远大于单条目默认上限的 1 GiB? 不，500 <1GiB 所以依然通过 }
  LOpts.MaxTotalOutputSize := 0;
  LR := NewZipReaderWithOptions(LArch, LOpts);
  CheckEqual(Int64(5), Int64(LR.EntryCount), 'total unlimited passes');
end;

function ZipReadOptsLimit10: TZipReadOptions;
begin
  Result := DefaultZipReadOptions;
  Result.MaxOutputSize := 10;
end;

procedure TestExtractToBufferZeroCopy;
var
  LArch, LWant, LTampered: TBytes;
  LR, LRSrc: IZipReader;
  LSrc: IStream;
  LIdx, LI: Integer;
  LBuf, LByNameBuf: array of Byte;
  LPos: Int64;
  LGot: SizeUInt;
  LGotRaise: Boolean;
  LSentinel: Byte;

  function BuildTinyArchive: TBytes;
  var LW: IZipWriter;
  begin
    LW := NewZipWriter;
    LW.AddEntry('s.txt', BytesOfStr('hello'));
    LW.AddEntryDeflate('d.bin', PatternBytes(5000, 7));
    LW.AddDirectory('emptydir/');
    LW.AddEntryWithTime('数据/x.txt', BytesOfStr('payload'), 1787574896);
    Result := LW.Finish;
  end;

  procedure CheckBufEquals(const ABuf: array of Byte; ASize: SizeUInt; const AWant: TBytes; const ALabel: string);
  var J: Integer;
  begin
    CheckEqual(Int64(Length(AWant)), Int64(ASize), ALabel + ' size');
    for J := 0 to High(AWant) do
      Check(ABuf[J] = AWant[J], ALabel + ' byte ' + IntToStr(J));
  end;

begin
  LArch := BuildTinyArchive;
  for LI := 0 to 1 do
  begin
    if LI = 0 then
    begin
      LR := NewZipReader(LArch);
      LRSrc := LR;
    end
    else
    begin
      LSrc := CreateBytesStreamFrom(LArch);
      LRSrc := NewZipReaderFrom(LSrc);
    end;
    for LIdx := 0 to LRSrc.EntryCount - 1 do
    begin
      if LRSrc.Entry(LIdx).IsDirectory then
      begin
        LSentinel := $CC;
        SetLength(LBuf, 4);
        LBuf[0] := LSentinel; LBuf[1] := LSentinel; LBuf[2] := LSentinel; LBuf[3] := LSentinel;
        LGot := LRSrc.ExtractToBuffer(LIdx, @LBuf[0], Length(LBuf));
        CheckEqual(Int64(0), Int64(LGot), 'dir zero');
        Check((LBuf[0]=LSentinel) and (LBuf[1]=LSentinel) and (LBuf[2]=LSentinel) and (LBuf[3]=LSentinel), 'dir untouched');
        Continue;
      end;
      LWant := LRSrc.ExtractToBytes(LIdx);
      SetLength(LBuf, Length(LWant));
      LGot := LRSrc.ExtractToBuffer(LIdx, @LBuf[0], Length(LBuf));
      CheckEqual(Int64(Length(LWant)), Int64(LGot), 'pbyte size ' + LRSrc.Entry(LIdx).Name);
      CheckBufEquals(LBuf, LGot, LWant, 'pbyte bytes ' + LRSrc.Entry(LIdx).Name);
      SetLength(LByNameBuf, Length(LWant));
      LGot := LRSrc.ExtractToBufferByName(LRSrc.Entry(LIdx).Name, @LByNameBuf[0], Length(LByNameBuf));
      CheckBufEquals(LByNameBuf, LGot, LWant, 'pbyte byname ' + LRSrc.Entry(LIdx).Name);
      if Length(LWant) > 0 then
      begin
        LGotRaise := False;
        try
          SetLength(LBuf, Length(LWant) - 1);
          if Length(LBuf) = 0 then
            LRSrc.ExtractToBuffer(LIdx, nil, 0)
          else
            LRSrc.ExtractToBuffer(LIdx, @LBuf[0], Length(LBuf));
        except
          on E: Exception do LGotRaise := Pos('EIOError', E.ClassName) > 0;
        end;
        Check(LGotRaise, 'small buffer raises');
      end;
    end;
    LGotRaise := False;
    try LRSrc.ExtractToBufferByName('nope.bin', nil, 0);
    except on E: Exception do LGotRaise := Pos('ENotFoundError', E.ClassName) > 0; end;
    Check(LGotRaise, 'pbyte not found');
    LGotRaise := False;
    try
      LIdx := LRSrc.Find('s.txt');
      if LIdx >= 0 then LRSrc.ExtractToBuffer(LIdx, nil, 0);
    except on E: Exception do LGotRaise := Pos('EArgumentError', E.ClassName) > 0; end;
    Check(LGotRaise, 'nil buffer nonzero raises');
  end;
  { tamper: store s.txt payload at local header +30+5=35 }
  LTampered := Copy(LArch, 0, Length(LArch));
  LR := NewZipReader(LArch);
  LPos := LR.Entry(LR.Find('s.txt')).LocalHeaderOffset + 30 + Length('s.txt');
  if (LPos >= 0) and (LPos < Length(LTampered)) then
  begin
    LTampered[Integer(LPos)] := LTampered[Integer(LPos)] xor $01;
    LR := NewZipReader(LTampered);
    LIdx := LR.Find('s.txt');
    SetLength(LBuf, Integer(LR.Entry(LIdx).UncompressedSize));
    LGotRaise := False;
    try LR.ExtractToBuffer(LIdx, @LBuf[0], Length(LBuf));
    except on E: Exception do LGotRaise := Pos('EIOError', E.ClassName) > 0; end;
    Check(LGotRaise, 'pbyte crc mismatch raises');
  end;
  { MaxOutput guard }
  LIdx := NewZipReader(LArch).Find('d.bin');
  SetLength(LBuf, 6000);
  LGotRaise := False;
  try
    begin
      LR := NewZipReaderWithOptions(LArch, DefaultZipReadOptions);
      LRSrc := NewZipReaderWithOptions(LArch, DefaultZipReadOptions);
    end;
    begin
      LR := NewZipReaderWithOptions(LArch, ZipReadOptsLimit10);
      LR.ExtractToBuffer(LIdx, @LBuf[0], Length(LBuf));
    end;
  except on E: Exception do LGotRaise := Pos('EIOError', E.ClassName) > 0; end;
  Check(LGotRaise, 'pbyte maxoutput guard');
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
  T.Test('Store bomb guard by max output', @TestStoreBombGuardByMaxOutput);
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
  T.Test('Source reader parity and extract', @TestSourceReaderParityAndExtract);
  T.Test('Source reader streams interleaved and copy',
    @TestSourceReaderStreamsInterleavedAndCopy);
  T.Test('Source reader guards and position',
    @TestSourceReaderGuardsAndPosition);
  T.Test('Source reader zip64 and max output',
    @TestSourceReaderZip64AndMaxOutput);
  T.Test('Total output limit', @TestTotalOutputLimit);
  T.Test('ExtractToBuffer zero copy', @TestExtractToBufferZeroCopy);
  if not T.Run then Halt(1);
end.
