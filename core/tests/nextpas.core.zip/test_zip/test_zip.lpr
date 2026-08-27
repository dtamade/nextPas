program test_zip;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.fs,
  nextpas.core.io,
  nextpas.core.process,
  nextpas.core.compress.intf,
  nextpas.core.io.intf,
  nextpas.core.zip,
  nextpas.core.zip.base;

var
  T: TTestSuite;

{ python3 zipfile 交叉验证脚本：argv[1]=zip 路径 argv[2]=清单路径。
  清单行格式：'TIME y m d h n s'（可选，全体条目期望 date_time）或
  'name\tmethod\tsize\tcrc32hex'。逐条目断言：文件名、压缩方法、UTF-8 flag、
  尺寸、zlib.crc32；整体断言条目数与 testzip() 通过。 }
const
  C_PY_CHECK =
    'import sys, zipfile, zlib'#10 +
    'zpath, mpath = sys.argv[1], sys.argv[2]'#10 +
    'expect_time = None; rows = []'#10 +
    'for line in open(mpath, encoding=''utf-8''):'#10 +
    '    line = line.rstrip(''\n'')'#10 +
    '    if not line: continue'#10 +
    '    if line.startswith(''TIME ''):'#10 +
    '        expect_time = tuple(int(x) for x in line.split('' '')[1:]); continue'#10 +
    '    name, method, size, crc = line.split(''\t'')'#10 +
    '    rows.append((name, int(method), int(size), int(crc, 16)))'#10 +
    'z = zipfile.ZipFile(zpath)'#10 +
    'assert z.testzip() is None, ''testzip failed'''#10 +
    'infos = z.infolist()'#10 +
    'assert len(infos) == len(rows), f''count {len(infos)} != {len(rows)}'''#10 +
    'for info, (name, method, size, crc) in zip(infos, rows):'#10 +
    '    assert info.filename == name, f''name {info.filename!r} != {name!r}'''#10 +
    '    assert info.compress_type == method, f''method {info.compress_type} != {method}'''#10 +
    '    assert info.flag_bits & 0x800, ''utf8 flag missing'''#10 +
    '    data = z.read(info)'#10 +
    '    assert len(data) == size, f''size {len(data)} != {size}'''#10 +
    '    assert zlib.crc32(data) & 0xFFFFFFFF == crc, ''crc mismatch'''#10 +
    '    if expect_time is not None and info.date_time != expect_time:'#10 +
    '        raise AssertionError(f''date_time {info.date_time} != {expect_time}'')'#10 +
    'print(''CROSSCHECK OK'')'#10;

function BytesOfStr(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

function LE16At(const AB: TBytes; AOff: Integer): Word;
begin
  Result := Word(AB[AOff]) or (Word(AB[AOff + 1]) shl 8);
end;

function LE32At(const AB: TBytes; AOff: Integer): LongWord;
var
  LI: Integer;
begin
  Result := 0;
  for LI := 3 downto 0 do
    Result := (Result shl 8) or AB[AOff + LI];
end;

function LE64At(const AB: TBytes; AOff: Integer): UInt64;
begin
  Result := UInt64(LE32At(AB, AOff)) or (UInt64(LE32At(AB, AOff + 4)) shl 32);
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

{ 用 python3 zipfile 对归档做独立实现交叉验证（结构 + 内容 + CRC）。
  python3 缺失时显式失败，不静默跳过。 }
procedure CrossCheck(const AZipPath, AManifest: string);
var
  LPy: string;
  LOut: TProcessOutput;
begin
  if not TryLookPath('python3', LPy) then
  begin
    Check(False, 'python3 unavailable for zip cross-validation');
    Exit;
  end;
  LOut := Command(LPy).Arg('-c').Arg(C_PY_CHECK)
    .Arg(AZipPath).Arg(AManifest).Output;
  Check(ProcessSucceeded(LOut),
    'python cross-check exit ok: ' + Trim(LOut.StdErr));
  Check(Pos('CROSSCHECK OK', LOut.StdOut) > 0, 'python cross-check marker');
end;

function NewTempCaseDir: string;
begin
  Result := TempDir(GetTempDir, 'ziptest');
end;

procedure WriteManifest(const ADir, AText: string);
begin
  WriteFileText(ADir + '/manifest.tsv', AText);
end;

procedure TestCrcVector;
begin
  CheckEqual(Int64($3610A686), Int64(Crc32OfBytes(BytesOfStr('hello'))),
    'crc32("hello") known vector');
end;

procedure TestEmptyArchive;
var
  LZip: TBytes;
  LDir: string;
begin
  LZip := NewZipWriter.Finish;
  CheckEqual(Int64(22), Int64(Length(LZip)), 'empty archive is bare EOCD');
  Check(LE32At(LZip, 0) = $06054B50, 'EOCD signature');
  CheckEqual(Int64(0), Int64(LE16At(LZip, 8)), 'entry count this disk');
  CheckEqual(Int64(0), Int64(LE16At(LZip, 10)), 'entry count total');

  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    WriteManifest(LDir, '');
    CrossCheck(LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestSingleEntryStructure;
var
  LW: IZipWriter;
  LZip: TBytes;
  LDir: string;
begin
  LW := NewZipWriter;
  LW.AddEntry('hello.txt', BytesOfStr('hello'));
  CheckEqual(Int64(1), Int64(LW.EntryCount), 'entry count 1');
  LZip := LW.Finish;

  Check(LE32At(LZip, 0) = $04034B50, 'local header signature');
  CheckEqual(Int64(20), Int64(LE16At(LZip, 4)), 'version needed');
  CheckEqual(Int64($0800), Int64(LE16At(LZip, 6)), 'UTF-8 flag bit 11');
  CheckEqual(Int64(0), Int64(LE16At(LZip, 8)), 'method store');
  CheckEqual(Int64($3610A686), Int64(LE32At(LZip, 14)), 'local crc32');
  CheckEqual(Int64(5), Int64(LE32At(LZip, 18)), 'local compressed size');
  CheckEqual(Int64(5), Int64(LE32At(LZip, 22)), 'local uncompressed size');
  CheckEqual(Int64(9), Int64(LE16At(LZip, 26)), 'name length');
  Check((LZip[30] = Ord('h')) and (LZip[38] = Ord('t')), 'name bytes follow header');

  CheckEqual(Int64(121), Int64(Length(LZip)), 'total size 30+9+5+46+9+22');
  Check(LE32At(LZip, 44) = $02014B50, 'central signature at 44');
  CheckEqual(Int64($3610A686), Int64(LE32At(LZip, 60)), 'central crc32');
  CheckEqual(Int64(0), Int64(LE32At(LZip, 86)), 'central local offset');
  Check(LE32At(LZip, 99) = $06054B50, 'EOCD follows central');

  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    WriteManifest(LDir, 'hello.txt'#9'0'#9'5'#9'3610a686'#10);
    CrossCheck(LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestMultiEntryUnicode;
var
  LW: IZipWriter;
  LZip: TBytes;
  LDir: string;
begin
  LW := NewZipWriter;
  LW.AddEntry('a.txt', BytesOfStr('alpha'));
  LW.AddEntry('图片/图像.png', BytesOfStr(#$89'PNG-fake-图像'));
  LW.AddEntry('deep/path/b.bin', nil);  { 零长条目合法 }
  CheckEqual(Int64(3), Int64(LW.EntryCount), 'three entries');
  LZip := LW.Finish;

  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    WriteManifest(LDir,
      'a.txt'#9'0'#9'5'#9 + Hex32(Crc32OfBytes(BytesOfStr('alpha'))) + #10 +
      '图片/图像.png'#9'0'#9 + IntToStr(Length(BytesOfStr(#$89'PNG-fake-图像'))) + #9 +
        Hex32(Crc32OfBytes(BytesOfStr(#$89'PNG-fake-图像'))) + #10 +
      'deep/path/b.bin'#9'0'#9'0'#9'00000000'#10);
    CrossCheck(LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestExplicitTimeFields;
const
  { 2026-08-24T12:34:56Z }
  C_TS: Int64 = 1787574896;
var
  LW: IZipWriter;
  LZip: TBytes;
  LDir: string;
begin
  LW := NewZipWriter;
  LW.AddEntryWithTime('timed.txt', BytesOfStr('x'), C_TS);
  LZip := LW.Finish;

  CheckEqual(Int64($645C), Int64(LE16At(LZip, 10)), 'DOS time 12:34:56 -> $645C');
  CheckEqual(Int64($5D18), Int64(LE16At(LZip, 12)), 'DOS date 2026-08-24 -> $5D18');

  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    WriteManifest(LDir, 'TIME 2026 8 24 12 34 56'#10 +
      'timed.txt'#9'0'#9'1'#9 + Hex32(Crc32OfBytes(BytesOfStr('x'))) + #10);
    CrossCheck(LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestDeterminism;
var
  LA, LB: IZipWriter;
begin
  LA := NewZipWriter;
  LB := NewZipWriter;
  LA.AddEntry('one.bin', BytesOfStr(#$01#$02#$03));
  LA.AddEntry('two.bin', nil);
  LB.AddEntry('one.bin', BytesOfStr(#$01#$02#$03));
  LB.AddEntry('two.bin', nil);
  Check(SameBytes(LA.Finish, LB.Finish), 'same inputs yield identical bytes');
end;

procedure TestNameGuards;
var
  LW: IZipWriter;
  LData: TBytes;

  procedure ExpectArgRaise(const AName: string; const ALabel: string);
  var
    LRaised: Boolean;
  begin
    LRaised := False;
    try
      LW.AddEntry(AName, LData);
    except
      on E: EArgumentError do LRaised := True;
    end;
    Check(LRaised, 'rejects ' + ALabel);
  end;

begin
  LData := BytesOfStr('x');
  LW := NewZipWriter;
  ExpectArgRaise('', 'empty name');
  ExpectArgRaise('/abs.txt', 'absolute path');
  ExpectArgRaise('C:x.txt', 'drive prefix');
  ExpectArgRaise('dir\file.txt', 'backslash');
  ExpectArgRaise('a/../b.txt', 'dotdot segment');
  ExpectArgRaise('..', 'bare dotdot');
  ExpectArgRaise('x/..', 'trailing dotdot segment');
  CheckEqual(Int64(0), Int64(LW.EntryCount), 'no entry survived rejections');
end;

procedure TestStateGuards;
var
  LW: IZipWriter;
  LFinishedOnce: Boolean;
begin
  LW := NewZipWriter;
  LW.AddEntry('ok.txt', BytesOfStr('ok'));
  LFinishedOnce := False;
  try
    LW.Finish;
    LFinishedOnce := True;
  except
    on E: EInvalidOperationError do ;
  end;
  Check(LFinishedOnce, 'first Finish succeeds');

  try
    LW.AddEntry('late.txt', BytesOfStr('x'));
    Check(False, 'AddEntry after Finish must raise');
  except
    on E: EInvalidOperationError do
      Check(True, 'AddEntry after Finish raises');
  end;

  try
    LW.Finish;
    Check(False, 'second Finish must raise');
  except
    on E: EInvalidOperationError do
      Check(True, 'second Finish raises');
  end;
end;

procedure TestZip64AutoByEntryCount;
var
  LOpts: TZipWriteOptions;
  LW: IZipWriter;
  LR: IZipReader;
  LZip, LOne: TBytes;
  LI, LTail: Integer;
begin
  { >65535 条目自动启用 Zip64 EOCD；经典字段写占位值 }
  LOne := BytesOfStr('e');
  LOpts.ForceZip64 := False;
  LW := NewZipWriterWithOptions(LOpts);
  for LI := 1 to 65600 do
    LW.AddEntry('e' + IntToStr(LI) + '.txt', LOne);
  CheckEqual(Int64(65600), Int64(LW.EntryCount),
    'entry count beyond 16-bit accepted');
  LZip := LW.Finish;

  { 布局：[central][zip64 EOCD(56)][locator(20)][EOCD(22)] }
  LTail := Length(LZip);
  CheckEqual(Int64($06054B50), Int64(LE32At(LZip, LTail - 22)), 'EOCD at tail');
  CheckEqual(Int64($FFFF), Int64(LE16At(LZip, LTail - 14)),
    'classic EOCD count placeholder');
  CheckEqual(Int64($07064B50), Int64(LE32At(LZip, LTail - 42)),
    'zip64 locator present');
  CheckEqual(Int64($06064B50), Int64(LE32At(LZip, LTail - 98)),
    'zip64 EOCD record present');

  LR := NewZipReader(LZip);
  CheckEqual(Int64(65600), Int64(LR.EntryCount), 'reader sees all entries');
  Check(SameBytes(LR.ExtractToBytesByName('e65600.txt'), LOne),
    'last entry extracts');
end;

procedure TestZip64ForcedStructures;
var
  LOpts: TZipWriteOptions;
  LW: IZipWriter;
  LR: IZipReader;
  LPayload, LZip, LGot: TBytes;
  LDir: string;
  LI: Integer;
begin
  SetLength(LPayload, 4096);
  for LI := 0 to High(LPayload) do
    LPayload[LI] := Byte(LI mod 13);
  LOpts.ForceZip64 := True;
  LW := NewZipWriterWithOptions(LOpts);
  LW.AddEntry('z64.bin', LPayload);
  LW.AddEntryDeflate('z64c.bin', BytesOfStr('compress-me-compress-me'));
  LZip := LW.Finish;

  { 首条目 local 头：version 45、尺寸占位、Zip64 extra 宽度值 }
  CheckEqual(Int64(45), Int64(LE16At(LZip, 4)), 'local version needed 45');
  CheckEqual(Int64($FFFFFFFF), Int64(LE32At(LZip, 18)),
    'compressed size placeholder');
  CheckEqual(Int64($FFFFFFFF), Int64(LE32At(LZip, 22)),
    'uncompressed size placeholder');
  CheckEqual(Int64($0001), Int64(LE16At(LZip, 37)), 'zip64 extra id');
  CheckEqual(Int64(16), Int64(LE16At(LZip, 39)), 'zip64 extra size');
  CheckEqual(Int64(4096), Int64(LE64At(LZip, 41)), 'zip64 usize');
  CheckEqual(Int64(4096), Int64(LE64At(LZip, 49)), 'zip64 csize');

  { Force 下 zip64 EOCD 链无条件出现 }
  CheckEqual(Int64($06064B50), Int64(LE32At(LZip, Length(LZip) - 98)),
    'forced zip64 EOCD record');
  CheckEqual(Int64($07064B50), Int64(LE32At(LZip, Length(LZip) - 42)),
    'forced zip64 locator');

  { 自家读器往返 }
  LR := NewZipReader(LZip);
  CheckEqual(Int64(2), Int64(LR.EntryCount), 'two entries');
  LGot := LR.ExtractToBytesByName('z64.bin');
  Check(SameBytes(LGot, LPayload), 'store z64 roundtrip');
  LGot := LR.ExtractToBytesByName('z64c.bin');
  Check(SameBytes(LGot, BytesOfStr('compress-me-compress-me')),
    'deflate z64 roundtrip');

  { python 独立读取 force_zip64 归档 }
  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    WriteManifest(LDir,
      'z64.bin'#9'0'#9'4096'#9 + Hex32(Crc32OfBytes(LPayload)) + #10 +
      'z64c.bin'#9'8'#9 +
        IntToStr(Length(BytesOfStr('compress-me-compress-me'))) + #9 +
        Hex32(Crc32OfBytes(BytesOfStr('compress-me-compress-me'))) + #10);
    CrossCheck(LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestLargePayload;
var
  LW: IZipWriter;
  LPayload: TBytes;
  LZip: TBytes;
  LDir: string;
  LI: Integer;
begin
  SetLength(LPayload, 1024 * 1024);
  for LI := 0 to High(LPayload) do
    LPayload[LI] := Byte(LI * 31 + (LI shr 8));
  LW := NewZipWriter;
  LW.AddEntry('big.bin', LPayload);
  LZip := LW.Finish;
  CheckEqual(Int64(Length(LPayload) + 30 + 7 + 46 + 7 + 22),
    Int64(Length(LZip)), 'stored payload adds container bytes only');

  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    WriteManifest(LDir, 'big.bin'#9'0'#9 + IntToStr(Length(LPayload)) + #9 +
      Hex32(Crc32OfBytes(LPayload)) + #10);
    CrossCheck(LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestDeflateEntryStructure;
var
  LW: IZipWriter;
  LR: IZipReader;
  LPayload, LZip, LGot: TBytes;
  LDir: string;
  LI: Integer;
begin
  SetLength(LPayload, 4096);
  for LI := 0 to High(LPayload) do
    LPayload[LI] := Byte(LI mod 13);  { 高可压模式 }
  LW := NewZipWriter;
  LW.AddEntryDeflate('comp.bin', LPayload);
  LZip := LW.Finish;

  CheckEqual(Int64(8), Int64(LE16At(LZip, 8)), 'local method field is 8');
  CheckEqual(Int64(Crc32OfBytes(LPayload)), Int64(LE32At(LZip, 14)),
    'crc over uncompressed payload');
  CheckEqual(Int64(4096), Int64(LE32At(LZip, 22)), 'uncompressed size');
  Check(Int64(LE32At(LZip, 18)) < 4096, 'compressed size smaller');

  { 自家读器往返还原 }
  LR := NewZipReader(LZip);
  LGot := LR.ExtractToBytesByName('comp.bin');
  Check(SameBytes(LGot, LPayload), 'deflate roundtrip equality');

  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    WriteManifest(LDir, 'comp.bin'#9'8'#9'4096'#9 +
      Hex32(Crc32OfBytes(LPayload)) + #10);
    CrossCheck(LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestDeflateDeterminism;
var
  LA, LB: IZipWriter;
  LPayload: TBytes;
  LI: Integer;
begin
  SetLength(LPayload, 2048);
  for LI := 0 to High(LPayload) do
    LPayload[LI] := Byte((LI * 7) mod 251);
  LA := NewZipWriter;
  LB := NewZipWriter;
  LA.AddEntryDeflate('d.bin', LPayload);
  LB.AddEntryDeflate('d.bin', LPayload);
  Check(SameBytes(LA.Finish, LB.Finish),
    'same deflate inputs yield identical archive bytes');
end;

procedure TestDirectoryEntries;
var
  LW: IZipWriter;
  LR: IZipReader;
  LZip: TBytes;
  LDir: string;
begin
  LW := NewZipWriter;
  LW.AddDirectory('assets');
  LW.AddDirectoryWithTime('assets/sub', 1787574896);
  LW.AddEntryWithTime('assets/sub/f.txt', BytesOfStr('x'), 1787574896);
  LZip := LW.Finish;

  LR := NewZipReader(LZip);
  CheckEqual(Int64(3), Int64(LR.EntryCount), 'two dirs plus one file');
  Check(LR.Entry(0).IsDirectory, 'assets flagged directory');
  Check(LR.Entry(1).IsDirectory, 'assets/sub flagged directory');
  Check(not LR.Entry(2).IsDirectory, 'file not flagged directory');
  CheckEqual(Int64(-1), Int64(LR.Find('assets')),
    'bare name not stored; trailing slash normalized');
  Check(SameBytes(LR.ExtractToBytesByName('assets/'), nil),
    'directory extracts empty');

  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    WriteManifest(LDir,
      'assets/'#9'0'#9'0'#9'00000000'#10 +
      'assets/sub/'#9'0'#9'0'#9'00000000'#10 +
      'assets/sub/f.txt'#9'0'#9'1'#9 + Hex32(Crc32OfBytes(BytesOfStr('x'))) + #10);
    CrossCheck(LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;
end;

{ AddEntryWithOptions：方法/时间戳/unix 模式字一次给定；目录名自动补 '/'；
  外部属性经 python zipfile 独立断言 }
procedure TestAddEntryWithOptions;
const
  C_TS: Int64 = 1787574896;
  C_PY_ATTRCHECK =
    'import sys, zipfile'#10 +
    'infos = zipfile.ZipFile(sys.argv[1]).infolist()'#10 +
    'd = {i.filename: i.external_attr for i in infos}'#10 +
    'assert d[''m.txt''] == (0o100640 << 16), hex(d[''m.txt''])'#10 +
    'assert d[''mydir/''] == ((0o040750 << 16) | 0x10), hex(d[''mydir/''])'#10 +
    'print(''ATTRS OK'')'#10;
var
  LW: IZipWriter;
  LOpts: TZipAddOptions;
  LZip: TBytes;
  LR: IZipReader;
  LI: Integer;
  LDir: string;
  LPy: string;
  LOut: TProcessOutput;
begin
  LW := NewZipWriter;
  LOpts := DefaultZipAddOptions;
  LOpts.Method := zmDeflate;
  LOpts.ModTimeUnixSec := C_TS;
  LOpts.Mode := Word($8000 or &640);   { S_IFREG|0640 }
  LW.AddEntryWithOptions('m.txt', BytesOfStr('options payload'), LOpts);

  LOpts.Method := zmStore;
  LOpts.Mode := Word($4000 or &750);   { S_IFDIR|0750 }
  LW.AddEntryWithOptions('mydir', nil, LOpts);
  LZip := LW.Finish;

  LR := NewZipReader(LZip);
  CheckEqual(Int64(2), Int64(LR.EntryCount), 'two option entries');
  LI := LR.Find('m.txt');
  Check(LI >= 0, 'file entry present');
  Check(LR.Entry(LI).Method = zmDeflate, 'option method deflate');
  Check(ZipUnixModeOf(LR.Entry(LI)) = Word($8000 or &640),
    'file mode word kept');
  LI := LR.Find('mydir/');
  Check(LI >= 0, 'dir name normalized with trailing slash');
  Check(LR.Entry(LI).IsDirectory, 'custom-mode dir detected');
  Check(ZipUnixModeOf(LR.Entry(LI)) = Word($4000 or &750),
    'dir mode word kept');

  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    if not TryLookPath('python3', LPy) then
    begin
      Check(False, 'python3 unavailable for zip attr cross-validation');
      Exit;
    end;
    LOut := Command(LPy).Arg('-c').Arg(C_PY_ATTRCHECK)
      .Arg(LDir + '/case.zip').Output;
    Check(ProcessSucceeded(LOut),
      'python attr check exit ok: ' + Trim(LOut.StdErr));
    Check(Pos('ATTRS OK', LOut.StdOut) > 0, 'python attr check marker');
  finally
    RemoveAll(LDir);
  end;
end;

{ 流式条目：deflate 不规则分块（含零长写）+ store 流式 + 零长流；
  读回断言 + python zipfile 独立交叉验证 }
procedure TestStreamedEntries;
const
  C_TS: Int64 = 1787574896;
var
  LW: IZipWriter;
  LSink: ICompressWriter;
  LOpts: TZipAddOptions;
  LHello: TBytes;
  LZip, LGot: TBytes;
  LR: IZipReader;
  LI: Integer;
  LBig: TBytes;
  LDir: string;
begin
  SetLength(LBig, 200000);
  for LI := 0 to High(LBig) do
    LBig[LI] := Byte((LI * 13 + LI shr 5) mod 251);
  LHello := BytesOfStr('hello stream');

  LW := NewZipWriter;

  LOpts := DefaultZipAddOptions;
  LOpts.Method := zmDeflate;
  LOpts.ModTimeUnixSec := C_TS;
  LSink := LW.AddEntryStream('big.bin', LOpts);
  Check(LSink.Write(LBig[0], 70000) = 70000, 'stream chunk1 written');
  Check(LSink.Write(LBig[70000], 0) = 0, 'zero-length write accepted');
  Check(LSink.Write(LBig[70000], 130000) = 130000, 'stream chunk2 written');
  LSink.Close;

  LOpts.Method := zmStore;
  LSink := LW.AddEntryStream('stored.txt', LOpts);
  LSink.Write(LHello[0], Length(LHello));
  LSink.Close;

  LOpts.Method := zmDeflate;
  LSink := LW.AddEntryStream('empty.bin', LOpts);
  LSink.Close;

  LZip := LW.Finish;

  LR := NewZipReader(LZip);
  CheckEqual(Int64(3), Int64(LR.EntryCount), 'three streamed entries');
  LGot := LR.ExtractToBytesByName('big.bin');
  Check(SameBytes(LGot, LBig), 'streamed deflate roundtrip content');
  Check(SameBytes(LR.ExtractToBytesByName('stored.txt'), LHello),
    'streamed store content');
  CheckEqual(Int64(0), Int64(Length(LR.ExtractToBytesByName('empty.bin'))),
    'streamed empty entry extracts empty');

  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    WriteManifest(LDir,
      'big.bin'#9'8'#9'200000'#9 + Hex32(Crc32OfBytes(LBig)) + #10 +
      'stored.txt'#9'0'#9'12'#9 + Hex32(Crc32OfBytes(LHello)) + #10 +
      'empty.bin'#9'8'#9'0'#9'00000000'#10);
    CrossCheck(LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;
end;

{ 流式 deflate 输出与一次性 API 字节级一致（同级别 zlib、同输入） }
procedure TestStreamedMatchesOneShot;
var
  LW: IZipWriter;
  LSink: ICompressWriter;
  LOpts: TZipAddOptions;
  LA, LB, LData: TBytes;
  LI: Integer;
begin
  SetLength(LData, 50000);
  for LI := 0 to High(LData) do
    LData[LI] := Byte((LI * 3 + LI shr 7) mod 249);

  LW := NewZipWriter;
  LW.AddEntryDeflateWithTime('same.bin', LData, 1787574896);
  LA := LW.Finish;

  LW := NewZipWriter;
  LOpts := DefaultZipAddOptions;
  LOpts.Method := zmDeflate;
  LOpts.ModTimeUnixSec := 1787574896;
  LSink := LW.AddEntryStream('same.bin', LOpts);
  LSink.Write(LData[0], 12345);
  LSink.Write(LData[12345], Length(LData) - 12345);
  LSink.Close;
  LB := LW.Finish;

  Check(SameBytes(LA, LB),
    'streamed deflate output byte-identical to one-shot');
end;

{ 放弃未关闭的流：条目不落入归档；未关闭时 Finish 拒绝；关闭后写拒绝 }
procedure TestStreamedGuards;
var
  LW: IZipWriter;
  LSink, LAbandon: ICompressWriter;
  LX: Byte;
  LZip: TBytes;
  LR: IZipReader;
  LGot: Boolean;
begin
  LX := Ord('x');
  LW := NewZipWriter;
  LSink := LW.AddEntryStream('kept.bin', DefaultZipAddOptions);
  LSink.Write(LX, 1);

  LAbandon := LW.AddEntryStream('dropped.bin', DefaultZipAddOptions);
  LAbandon.Write(LX, 1);
  LAbandon := nil;   { 显式放弃：析构解除登记，条目不落入 }

  LGot := False;
  try
    LW.Finish;
  except
    on E: Exception do
      LGot := Pos('InvalidOperation', E.ClassName) > 0;
  end;
  Check(LGot, 'finish with open stream raises');

  LSink.Close;
  LZip := LW.Finish;
  LR := NewZipReader(LZip);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'only kept entry landed');
  Check(LR.Find('dropped.bin') < 0, 'abandoned entry absent');
  Check(SameBytes(LR.ExtractToBytesByName('kept.bin'), BytesOfStr('x')),
    'kept entry intact');

  LGot := False;
  try
    LSink.Write(LX, 1);
  except
    on E: Exception do
      LGot := Pos('EIOError', E.ClassName) > 0;
  end;
  Check(LGot, 'write after close raises');
end;

{ ---- 流式输出（sink 收集器 / 小块分片 / 故障注入） ---- }

type
  TCollectWriter = class(TInterfacedObject, IWriter)
  private
    FBuf: TBytes;
    FLen: Integer;
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Bytes: TBytes;
  end;

  { 故意按 ≤7 字节切片转发的 sink：验证任意分块下输出不变 }
  TChunkWriter = class(TInterfacedObject, IWriter)
  private
    FInner: TCollectWriter;
  public
    constructor Create;
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Bytes: TBytes;
  end;

  { 首次写入少返回 1 字节（短写故障） }
  TShortWriter = class(TInterfacedObject, IWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  { 直接抛 IO 错误的 sink }
  TRaisingWriter = class(TInterfacedObject, IWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

function TCollectWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount > 0 then
  begin
    if Length(FBuf) < FLen + Integer(ACount) then
      SetLength(FBuf, (FLen + Integer(ACount)) * 2);
    Move(ABuf, PByte(FBuf)[FLen], ACount);
    Inc(FLen, ACount);
  end;
  Result := ACount;
end;

function TCollectWriter.Bytes: TBytes;
begin
  SetLength(Result, FLen);
  if FLen > 0 then
    Move(PByte(FBuf)^, Result[0], SizeUInt(FLen));
end;

constructor TChunkWriter.Create;
begin
  inherited Create;
  FInner := TCollectWriter.Create;
end;

destructor TChunkWriter.Destroy;
begin
  FInner.Free;
  inherited;
end;

function TChunkWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LP: PByte;
  LLeft, LN: SizeUInt;
begin
  LP := @ABuf;
  LLeft := ACount;
  while LLeft > 0 do
  begin
    LN := LLeft;
    if LN > 7 then
      LN := 7;
    FInner.Write(LP^, LN);
    Inc(LP, LN);
    Dec(LLeft, LN);
  end;
  Result := ACount;
end;

function TChunkWriter.Bytes: TBytes;
begin
  Result := FInner.Bytes;
end;

function TShortWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  Result := ACount - 1;
end;

function TRaisingWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  raise EIOError.Create('sink exploded');
end;

{ 确定性模式字节（deflate 输入） }
function PatternBytes(ALen: Integer; ASeed: Integer): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, ALen);
  for LI := 0 to ALen - 1 do
    Result[LI] := Byte((LI * 3 + ASeed + (LI shr 5)) mod 251);
end;

{ 固定混合条目面：store/deflate/目录/选项模式字/unicode 名，显式时间戳 }
procedure PopulateMixed(const AW: IZipWriter);
var
  LOpts: TZipAddOptions;
begin
  AW.AddEntry('hello.txt', BytesOfStr('hello world'));
  AW.AddEntryDeflateWithTime('data.bin', PatternBytes(20000, 11), 1787574896);
  AW.AddDirectoryWithTime('assets', 1780000000);
  LOpts := DefaultZipAddOptions;
  LOpts.Method := zmStore;
  LOpts.ModTimeUnixSec := 1787574896;
  LOpts.Mode := ZipRegularMode($1A4);
  AW.AddEntryWithOptions('assets/readme.txt', BytesOfStr('mode word entry'),
    LOpts);
  AW.AddEntryDeflate('数据/文件.txt', PatternBytes(4096, 22));
end;

procedure TestStreamingMatchesBuffered;
var
  LWa, LWb: IZipWriter;
  LCw: TCollectWriter;
  LChk: TChunkWriter;
  LOptsW: TZipWriteOptions;
  LA, LZ64: TBytes;
  LTotal: UInt64;
begin
  { 场景 A：暂存排空 + 绑定后透传的混合路径 }
  LWa := NewZipWriter;
  PopulateMixed(LWa);
  LWa.AddDirectoryWithTime('late', 1787574896);
  LA := LWa.Finish;

  LCw := TCollectWriter.Create;
  LWb := NewZipWriter;
  PopulateMixed(LWb);
  LWb.StreamOutputTo(LCw);              { 排空已暂存字节 }
  LWb.AddDirectoryWithTime('late', 1787574896);
  LTotal := LWb.FinishTo(LCw);
  Check(SameBytes(LA, LCw.Bytes), 'piped output byte-identical to buffered');
  CheckEqual(Int64(LTotal), Int64(Length(LCw.Bytes)),
    'finish-to total equals collected length');

  { 场景 B：强制 Zip64 结构逐字节等价 }
  LOptsW := DefaultZipWriteOptions;
  LOptsW.ForceZip64 := True;
  LWa := NewZipWriterWithOptions(LOptsW);
  PopulateMixed(LWa);
  LZ64 := LWa.Finish;

  LCw := TCollectWriter.Create;
  LWb := NewZipWriterWithOptions(LOptsW);
  PopulateMixed(LWb);
  LWb.StreamOutputTo(LCw);
  LWb.FinishTo(LCw);
  Check(SameBytes(LZ64, LCw.Bytes), 'forced-zip64 piped output identical');

  { 场景 C：≤7 字节任意小片的 sink 下输出不变（条目序列同场景 A） }
  LChk := TChunkWriter.Create;
  LWb := NewZipWriter;
  PopulateMixed(LWb);
  LWb.StreamOutputTo(LChk);
  LWb.AddDirectoryWithTime('late', 1787574896);
  LWb.FinishTo(LChk);
  Check(SameBytes(LA, LChk.Bytes), 'chunked sink output identical');
end;

procedure TestStreamedEntriesThroughPipedOutput;
var
  LWa, LWb: IZipWriter;
  LSink: ICompressWriter;
  LCw: TCollectWriter;
  LOpts: TZipAddOptions;
  LData: TBytes;
  LA, LB: TBytes;
begin
  LData := PatternBytes(50000, 33);
  LOpts := DefaultZipAddOptions;
  LOpts.Method := zmDeflate;
  LOpts.ModTimeUnixSec := 1787574896;

  LWa := NewZipWriter;
  LSink := LWa.AddEntryStream('s.bin', LOpts);
  LSink.Write(LData[0], 12345);
  LSink.Write(LData[12345], Length(LData) - 12345);
  LSink.Close;
  LA := LWa.Finish;

  LCw := TCollectWriter.Create;
  LWb := NewZipWriter;
  LWb.StreamOutputTo(LCw);
  LSink := LWb.AddEntryStream('s.bin', LOpts);
  LSink.Write(LData[0], 777);
  LSink.Write(LData[777], Length(LData) - 777);
  LSink.Close;
  LWb.FinishTo(LCw);
  LB := LCw.Bytes;

  Check(SameBytes(LA, LB), 'streamed entry under piped output identical');
end;

procedure TestPipedRoundtripAndPython;
var
  LW: IZipWriter;
  LR: IZipReader;
  LCw: TCollectWriter;
  LDir, LManifest: string;
  LPayload1, LPayload2, LPayload3: TBytes;
  LArchive: TBytes;
  LTotal: UInt64;
begin
  LPayload1 := PatternBytes(3000, 44);
  LPayload2 := PatternBytes(70000, 55);
  LPayload3 := BytesOfStr('unicode nested payload');

  LCw := TCollectWriter.Create;
  LW := NewZipWriter;
  LW.StreamOutputTo(LCw);
  LW.AddEntryWithTime('plain.txt', LPayload1, 1787574896);
  LW.AddEntryDeflateWithTime('big/lz.bin', LPayload2, 1787574896);
  LW.AddDirectoryWithTime('empty-dir', 1780000000);
  LW.AddEntryDeflateWithTime('数据/文件.txt', LPayload3, 1787574896);
  LTotal := LW.FinishTo(LCw);
  CheckEqual(Int64(LTotal), Int64(Length(LCw.Bytes)),
    'roundtrip total matches collected length');
  LArchive := LCw.Bytes;

  { 读端往返：结构、内容逐一校验 }
  LR := NewZipReader(LArchive);
  CheckEqual(Int64(4), Int64(LR.EntryCount), 'piped archive entry count');
  Check(SameBytes(LR.ExtractToBytesByName('plain.txt'), LPayload1),
    'store entry roundtrip');
  Check(SameBytes(LR.ExtractToBytesByName('big/lz.bin'), LPayload2),
    'deflate entry roundtrip');
  Check(SameBytes(LR.ExtractToBytesByName('数据/文件.txt'), LPayload3),
    'unicode entry roundtrip');

  { python3 zipfile 独立交叉验证 }
  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/piped.zip', LArchive);
    LManifest :=
      'plain.txt'#9'0'#9 + IntToStr(Length(LPayload1)) + #9 +
        Hex32(Crc32OfBytes(LPayload1)) + #10 +
      'big/lz.bin'#9'8'#9 + IntToStr(Length(LPayload2)) + #9 +
        Hex32(Crc32OfBytes(LPayload2)) + #10 +
      'empty-dir/'#9'0'#9'0'#9 +
        Hex32(Crc32OfBytes(nil)) + #10 +
      '数据/文件.txt'#9'8'#9 + IntToStr(Length(LPayload3)) + #9 +
        Hex32(Crc32OfBytes(LPayload3)) + #10;
    WriteManifest(LDir, LManifest);
    CrossCheck(LDir + '/piped.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;
end;

{ FPC 3.3.1 已知行为：带接口实参的调用若异常穿越该栈帧，实参会粘住一个
  引用不释放（heaptrc 门拦截；nil 实参与无实参调用不受影响，成功路径亦然）。
  期望抛错的流式输出调用一律经下列辅助完成——异常在【同一帧内】被捕获，
  不携带接口实参出帧。 }
function TryBindExpectInvalid(const AW: IZipWriter; ASink: TObject): Boolean;
var
  S: IWriter;
begin
  Result := False;
  if not ASink.GetInterface(IWriter, S) then Exit;
  try
    AW.StreamOutputTo(S);
  except
    on E: Exception do
      Result := Pos('InvalidOperation', E.ClassName) > 0;
  end;
end;

function TryFinishToExpectInvalid(const AW: IZipWriter; ASink: TObject): Boolean;
var
  S: IWriter;
begin
  Result := False;
  if not ASink.GetInterface(IWriter, S) then Exit;
  try
    AW.FinishTo(S);
  except
    on E: Exception do
      Result := Pos('InvalidOperation', E.ClassName) > 0;
  end;
end;

function TryFinishToExpectShortWrite(const AW: IZipWriter;
  ASink: TObject): Boolean;
var
  S: IWriter;
begin
  Result := False;
  if not ASink.GetInterface(IWriter, S) then Exit;
  try
    AW.FinishTo(S);
  except
    on E: Exception do
      Result := Pos('EIOError', E.ClassName) > 0;
  end;
end;

function TryPipedAddExpectIOError(const AW: IZipWriter;
  ASink: TObject): Boolean;
var
  S: IWriter;
begin
  Result := False;
  if not ASink.GetInterface(IWriter, S) then Exit;
  try
    AW.StreamOutputTo(S);
    AW.AddEntryDeflate('boom.bin', PatternBytes(2048, 66));
  except
    on E: Exception do
      Result := Pos('EIOError', E.ClassName) > 0;
  end;
end;

procedure TestStreamingGuards;
var
  LW: IZipWriter;
  LCw, LOther: TCollectWriter;
  LShort: TShortWriter;
  LRaise: TRaisingWriter;
  LA: TBytes;
  LR: IZipReader;
  LGot: Boolean;
begin
  { 空归档流式输出 = EOCD only，与缓冲式字节一致且可读 }
  LCw := TCollectWriter.Create;
  LW := NewZipWriter;
  LW.StreamOutputTo(LCw);
  CheckEqual(Int64(LW.FinishTo(LCw)), Int64(22),
    'empty piped archive is EOCD-only 22 bytes');
  LA := NewZipWriter.Finish;
  Check(SameBytes(LA, LCw.Bytes), 'empty piped equals buffered empty');
  LR := NewZipReader(LCw.Bytes);
  CheckEqual(Int64(0), Int64(LR.EntryCount), 'empty piped archive readable');

  { nil sink：两种入口都拒绝 }
  LW := NewZipWriter;
  LGot := False;
  try
    LW.StreamOutputTo(nil);
  except
    on E: Exception do
      LGot := Pos('EArgumentError', E.ClassName) > 0;
  end;
  Check(LGot, 'nil sink on stream-output raises argument error');

  LW := NewZipWriter;
  LGot := False;
  try
    LW.FinishTo(nil);
  except
    on E: Exception do
      LGot := Pos('EArgumentError', E.ClassName) > 0;
  end;
  Check(LGot, 'nil sink on finish-to raises argument error');

  { 双重绑定 / 绑定后 Finish / 异源 FinishTo 全部拒绝 }
  LCw := TCollectWriter.Create;
  LW := NewZipWriter;
  LW.StreamOutputTo(LCw);
  Check(TryBindExpectInvalid(LW, LCw), 'double bind raises invalid operation');

  LGot := False;
  try
    LW.Finish;
  except
    on E: Exception do
      LGot := Pos('InvalidOperation', E.ClassName) > 0;
  end;
  Check(LGot, 'finish after bind raises invalid operation');

  LOther := TCollectWriter.Create;
  Check(TryFinishToExpectInvalid(LW, LOther),
    'finish-to foreign sink raises invalid operation');

  { 终结后再操作一律拒绝 }
  LW.FinishTo(LCw);
  LGot := False;
  try
    LW.AddEntry('x.txt', BytesOfStr('x'));
  except
    on E: Exception do
      LGot := Pos('InvalidOperation', E.ClassName) > 0;
  end;
  Check(LGot, 'add after finish-to raises');

  Check(TryFinishToExpectInvalid(LW, LCw), 'finish-to twice raises');

  { 短写 sink：终结时交付 EIOError }
  LW := NewZipWriter;
  LW.AddEntry('a.txt', BytesOfStr('short write target'));
  LShort := TShortWriter.Create;
  Check(TryFinishToExpectShortWrite(LW, LShort),
    'short write surfaces as IO error');

  { 绑定模式下条目添加时 sink 故障原样传播 }
  LW := NewZipWriter;
  LRaise := TRaisingWriter.Create;
  Check(TryPipedAddExpectIOError(LW, LRaise),
    'sink failure propagates from add-time emit');
end;

{ ---- 七期：数据描述符直写（INV-15）---- }

{ 描述符条目的 local header 逐字节断言：bit3、零值占位、zip64 零占位
  extra，描述符紧贴数据且携带真实 crc/尺寸；staged 条目前后共存正常 }
procedure TestDescriptorStructure;
var
  LW: IZipWriter;
  LS: ICompressWriter;
  LO: TZipAddOptions;
  LP, LZip: TBytes;
  LOff, LDataOff, LDDOff: Integer;
begin
  LP := BytesOfStr('descriptor-payload');
  LW := NewZipWriter;
  LW.AddEntry('plain.txt', BytesOfStr('PLAIN'));
  LO := DefaultZipAddOptions;
  LO.DataDescriptor := True;
  LS := LW.AddEntryStream('a.bin', LO);
  LS.Write(LP[0], Length(LP));
  LS.Close;
  LO.Method := zmDeflate;
  LS := LW.AddEntryStream('b.bin', LO);
  LS.Write(LP[0], Length(LP));
  LS.Close;
  LW.AddEntry('tail.txt', BytesOfStr('TAIL'));
  LZip := LW.Finish;

  { dd store 条目 local header：plain 条目占 30+9+5=44 起 }
  LOff := 30 + Length('plain.txt') + Length('PLAIN');
  Check(LE32At(LZip, LOff) = C_ZIP_LOCAL_SIG, 'dd local sig');
  Check((LE16At(LZip, LOff + 6) and C_ZIP_FLAG_DESCRIPTOR) <> 0,
    'dd local bit3 set');
  Check(LE32At(LZip, LOff + 14) = 0, 'dd local crc placeholder zero');
  Check(LE32At(LZip, LOff + 18) = C_ZIP_MAX_SIZE32,
    'dd local csize placeholder');
  Check(LE32At(LZip, LOff + 22) = C_ZIP_MAX_SIZE32,
    'dd local usize placeholder');
  LDataOff := LOff + 30 + Length('a.bin') + 20;  { zip64 占位 extra=20B }
  { 描述符紧贴数据：sig + 真实 crc + 真实尺寸 }
  LDDOff := LDataOff + Length(LP);
  Check(LE32At(LZip, LDDOff) = C_ZIP_DESCRIPTOR_SIG, 'descriptor signature');
  Check(LE32At(LZip, LDDOff + 4) = Crc32OfBytes(LP),
    'descriptor carries real crc');
  Check(LE32At(LZip, LDDOff + 8) = LongWord(Length(LP)),
    'descriptor compressed size');
  Check(LE32At(LZip, LDDOff + 12) = LongWord(Length(LP)),
    'descriptor uncompressed size');
  { deflate 条目的 local 同形态：描述符（16B）之后即下一 local header }
  LOff := LDDOff + 16;
  Check(LE32At(LZip, LOff) = C_ZIP_LOCAL_SIG, 'dd deflate local sig');
  Check((LE16At(LZip, LOff + 6) and C_ZIP_FLAG_DESCRIPTOR) <> 0,
    'dd deflate bit3 set');
  LDataOff := LOff + 30 + Length('b.bin') + 20;
  Check(LE32At(LZip, LOff + 14) = 0, 'dd deflate crc placeholder zero');

  { plain 条目无 bit3 }
  Check((LE16At(LZip, 6) and C_ZIP_FLAG_DESCRIPTOR) = 0,
    'plain entry has no bit3');
end;

{ 描述符归档自家读端双路径往返 + python 独立交叉验证 + ForceZip64 组合 }
procedure TestDescriptorRoundtripAndPython;
var
  LW: IZipWriter;
  LS: ICompressWriter;
  LO: TZipAddOptions;
  LA, LB, LZip: TBytes;
  LR, LRSeek: IZipReader;
  LI: Integer;
  LDir: string;
begin
  SetLength(LA, 150000);
  for LI := 0 to High(LA) do
    LA[LI] := Byte((LI * 11 + LI shr 4) mod 251);
  LB := BytesOfStr('stored descriptor bytes');

  LW := NewZipWriter;
  LO := DefaultZipAddOptions;
  LO.DataDescriptor := True;
  LO.Method := zmDeflate;
  LS := LW.AddEntryStream('big.bin', LO);
  LS.Write(LA[0], 70000);
  LS.Write(LA[70000], Length(LA) - 70000);   { 跨块 CRC/压缩连续性 }
  LS.Close;
  LO.Method := zmStore;
  LS := LW.AddEntryStream('s.bin', LO);
  LS.Write(LB[0], Length(LB));
  LS.Close;
  LO.Method := zmDeflate;
  LS := LW.AddEntryStream('empty.bin', LO);
  LS.Close;
  LS := LW.AddEntryStream('d/', LO);         { 目录也可走描述符形态 }
  LS.Close;
  LZip := LW.Finish;

  LR := NewZipReader(LZip);
  CheckEqual(Int64(4), Int64(LR.EntryCount), 'four descriptor entries');
  Check(SameBytes(LR.ExtractToBytesByName('big.bin'), LA),
    'dd deflate roundtrip content');
  Check(SameBytes(LR.ExtractToBytesByName('s.bin'), LB),
    'dd store roundtrip content');
  CheckEqual(Int64(0), Int64(Length(LR.ExtractToBytesByName('empty.bin'))),
    'dd empty extracts empty');
  Check(LR.Entry(LR.Find('d/')).IsDirectory, 'dd directory recognized');

  LRSeek := NewZipReaderFrom(BytesStreamFrom(LZip));
  Check(SameBytes(LRSeek.ExtractToBytesByName('big.bin'), LA),
    'seekable reader parity for descriptor entries');

  LDir := NewTempCaseDir;
  try
    WriteFile(LDir + '/case.zip', LZip);
    WriteManifest(LDir,
      'big.bin'#9'8'#9'150000'#9 + Hex32(Crc32OfBytes(LA)) + #10 +
      's.bin'#9'0'#9 + IntToStr(Length(LB)) + #9 +
      Hex32(Crc32OfBytes(LB)) + #10 +
      'empty.bin'#9'8'#9'0'#9'00000000'#10 +
      'd/'#9'8'#9'0'#9'00000000'#10);
    CrossCheck(LDir + '/case.zip', LDir + '/manifest.tsv');
  finally
    RemoveAll(LDir);
  end;

  { ForceZip64 与描述符组合仍可读 }
  LW := NewZipWriterWithOptions(DefaultZipWriteOptions);
  LO := DefaultZipAddOptions;
  LO.DataDescriptor := True;
  LS := LW.AddEntryStream('z.bin', LO);
  LS.Write(LB[0], Length(LB));
  LS.Close;
  LZip := LW.Finish;
  Check(SameBytes(NewZipReader(LZip).ExtractToBytesByName('z.bin'), LB),
    'force zip64 + descriptor roundtrip');
end;

{ AES + 描述符组合：往返、central CRC=0 契约与描述符真实 CRC 分离、
  流式输出端可读 }
procedure TestDescriptorAesCombo;
const
  C_NAME = 'enc.txt';
var
  LW: IZipWriter;
  LS: ICompressWriter;
  LO: TZipAddOptions;
  LCw: TCollectWriter;
  LP, LZip: TBytes;
  LR: IZipReader;
  LROpts, LBadOpts: TZipReadOptions;
  LOff, LDDOff: Integer;
begin
  LP := BytesOfStr('aes descriptor secret');

  { 缓冲模式构建并断言布局 }
  LW := NewZipWriter;
  LO := DefaultZipAddOptions;
  LO.DataDescriptor := True;
  LO.Password := BytesOfStr('pw123');
  LO.AesStrength := 3;
  LS := LW.AddEntryStream(C_NAME, LO);
  LS.Write(LP[0], Length(LP));
  LS.Close;
  LZip := LW.Finish;

  LR := NewZipReader(LZip);
  LROpts := DefaultZipReadOptions;
  LROpts.Password := BytesOfStr('pw123');
  Check(SameBytes(
    NewZipReaderWithOptions(LZip, LROpts).ExtractToBytesByName(C_NAME), LP),
    'aes descriptor roundtrip');
  Check(LR.Entry(LR.Find(C_NAME)).Crc32 = 0,
    'central crc zero for AE-2 descriptor entry');
  { 错口令统一报文（独立选项记录，避免污染后续正例） }
  LBadOpts := DefaultZipReadOptions;
  LBadOpts.Password := BytesOfStr('bad');
  try
    NewZipReaderWithOptions(LZip, LBadOpts).ExtractToBytesByName(C_NAME);
    Check(False, 'wrong password must fail');
  except
    on E: Exception do
      Check(Pos('EParseError', E.ClassName) > 0,
        'wrong password fails as parse error');
  end;

  { 描述符携带真实 crc：位于 salt+pwv+密文+认证码之后 }
  LOff := 30 + Length(C_NAME) + 31;   { extra = zip64(20)+AE(11) }
  LDDOff := LOff + 18 + Length(LP) + 10;
  Check(LE32At(LZip, LDDOff) = C_ZIP_DESCRIPTOR_SIG, 'aes frame followed by descriptor');
  Check(LE32At(LZip, LDDOff + 4) = Crc32OfBytes(LP),
    'aes descriptor carries real crc');

  { 流式输出端同构可读 }
  LCw := TCollectWriter.Create;
  LW := NewZipWriter;
  LO := DefaultZipAddOptions;
  LO.DataDescriptor := True;
  LO.Password := BytesOfStr('pw123');
  LO.AesStrength := 3;
  LS := LW.AddEntryStream(C_NAME, LO);
  LS.Write(LP[0], Length(LP));
  LS.Close;
  LW.FinishTo(LCw);
  Check(SameBytes(
    NewZipReaderWithOptions(LCw.Bytes, LROpts).ExtractToBytesByName(C_NAME),
    LP), 'aes descriptor via piped output roundtrip');
end;

{ 描述符直写期间的串行化守卫与弃流 fail-closed。
  IWriter 实参一律经 Try*ExpectInvalid 转成命名接口局部量——FPC 异常
  穿越持有接口实参的栈帧会粘引用，直接 StreamOutputTo(TCollectWriter)
  会泄漏（六期同类陷阱） }
procedure TestDescriptorGuards;
var
  LW: IZipWriter;
  LS, LAbandon: ICompressWriter;
  LCw: TCollectWriter;
  LHold: IWriter;
  LO: TZipAddOptions;
  LX: Byte;
  LGot: Boolean;
begin
  LX := Ord('x');
  LW := NewZipWriter;
  LO := DefaultZipAddOptions;
  LO.DataDescriptor := True;
  LS := LW.AddEntryStream('active.bin', LO);
  LS.Write(LX, 1);

  { 直写进行中：一切条目级入口拒绝 }
  LGot := False;
  try
    LW.AddEntry('nope', BytesOfStr('y'));
  except
    on E: Exception do
      LGot := Pos('InvalidOperation', E.ClassName) > 0;
  end;
  Check(LGot, 'add rejected during direct entry');

  LGot := False;
  try
    LW.AddEntryStream('nope2', DefaultZipAddOptions);
  except
    on E: Exception do
      LGot := Pos('InvalidOperation', E.ClassName) > 0;
  end;
  Check(LGot, 'staged stream rejected during direct entry');

  { LHold 把收集器钉在接口上：拒绝路径的隐式 IWriter 临时量即使被
    异常粘住，对象也有命名持有者，用例结束时成对释放 }
  LCw := TCollectWriter.Create;
  LHold := LCw;
  Check(TryBindExpectInvalid(LW, LCw), 'bind rejected during direct entry');

  LS.Close;
  { Close 后串行化解除，绑定可用 }
  LW.StreamOutputTo(LHold);
  LW.AddEntry('after.bin', BytesOfStr('ok'));
  LW.FinishTo(LHold);
  Check(NewZipReader(LCw.Bytes).EntryCount = 2, 'piped direct archive valid');

  { 弃流：Finish/FinishTo fail-closed，且写器保持不可终结 }
  LW := NewZipWriter;
  LO := DefaultZipAddOptions;
  LO.DataDescriptor := True;
  LAbandon := LW.AddEntryStream('abandon.bin', LO);
  LAbandon.Write(LX, 1);
  LAbandon := nil;
  LGot := False;
  try
    LW.Finish;
  except
    on E: Exception do
      LGot := Pos('InvalidOperation', E.ClassName) > 0;
  end;
  Check(LGot, 'finish fails closed on abandoned direct stream');
  LCw := TCollectWriter.Create;
  LHold := LCw;
  Check(TryFinishToExpectInvalid(LW, LCw),
    'finish-to fails closed on abandoned direct stream');
end;

{ 大载荷跨块直写与暂存路径内容一致（常数内存路径的正确性锚）}
procedure TestDescriptorLargeParity;
var
  LW: IZipWriter;
  LS: ICompressWriter;
  LO: TZipAddOptions;
  LData: TBytes;
  LDirect, LStaged, LZip: TBytes;
  LI: Integer;
begin
  SetLength(LData, 8 * 1024 * 1024);
  for LI := 0 to High(LData) do
    LData[LI] := Byte((LI * 7 + LI shr 6) mod 249);

  { 直写路径：三块不均匀写入 }
  LW := NewZipWriter;
  LO := DefaultZipAddOptions;
  LO.DataDescriptor := True;
  LO.Method := zmDeflate;
  LS := LW.AddEntryStream('big.bin', LO);
  LS.Write(LData[0], 3 * 1024 * 1024);
  LS.Write(LData[3 * 1024 * 1024], 3 * 1024 * 1024);
  LS.Write(LData[6 * 1024 * 1024], 2 * 1024 * 1024);
  LS.Close;
  LZip := LW.Finish;
  LDirect := NewZipReader(LZip).ExtractToBytesByName('big.bin');
  Check(SameBytes(LDirect, LData), 'direct large payload roundtrip');

  { 暂存路径同输入：提取内容一致 }
  LW := NewZipWriter;
  LW.AddEntryDeflate('big.bin', LData);
  LZip := LW.Finish;
  LStaged := NewZipReader(LZip).ExtractToBytesByName('big.bin');
  Check(SameBytes(LDirect, LStaged),
    'direct equals staged extraction content');
end;

begin
  T := TTestSuite.Create('nextpas.core.zip');
  T.Test('CRC vector', @TestCrcVector);
  T.Test('Empty archive', @TestEmptyArchive);
  T.Test('Single entry structure', @TestSingleEntryStructure);
  T.Test('Multi entry unicode', @TestMultiEntryUnicode);
  T.Test('Explicit time fields', @TestExplicitTimeFields);
  T.Test('Determinism', @TestDeterminism);
  T.Test('Name guards', @TestNameGuards);
  T.Test('State guards', @TestStateGuards);
  T.Test('Zip64 auto by entry count', @TestZip64AutoByEntryCount);
  T.Test('Large payload', @TestLargePayload);
  T.Test('Deflate entry structure', @TestDeflateEntryStructure);
  T.Test('Deflate determinism', @TestDeflateDeterminism);
  T.Test('Directory entries', @TestDirectoryEntries);
  T.Test('Zip64 forced structures', @TestZip64ForcedStructures);
  T.Test('Add entry with options', @TestAddEntryWithOptions);
  T.Test('Streamed entries', @TestStreamedEntries);
  T.Test('Streamed matches one-shot', @TestStreamedMatchesOneShot);
  T.Test('Streamed guards', @TestStreamedGuards);
  T.Test('Streaming output matches buffered', @TestStreamingMatchesBuffered);
  T.Test('Streamed entries through piped output',
    @TestStreamedEntriesThroughPipedOutput);
  T.Test('Piped roundtrip and python cross-check', @TestPipedRoundtripAndPython);
  T.Test('Streaming guards', @TestStreamingGuards);
  T.Test('Descriptor structure', @TestDescriptorStructure);
  T.Test('Descriptor roundtrip and python',
    @TestDescriptorRoundtripAndPython);
  T.Test('Descriptor AES combo', @TestDescriptorAesCombo);
  T.Test('Descriptor guards', @TestDescriptorGuards);
  T.Test('Descriptor large parity', @TestDescriptorLargeParity);
  if not T.Run then Halt(1);
end.
