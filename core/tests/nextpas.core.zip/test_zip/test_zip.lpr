program test_zip;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.zip;

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

procedure TestEntryLimit;
var
  LW: IZipWriter;
  LI: Integer;
  LOne: TBytes;
begin
  LOne := BytesOfStr('e');
  LW := NewZipWriter;
  for LI := 1 to 65535 do
    LW.AddEntry('e' + IntToStr(LI) + '.txt', LOne);
  CheckEqual(Int64(65535), Int64(LW.EntryCount), 'limit entries accepted');
  try
    LW.AddEntry('overflow.txt', LOne);
    Check(False, 'entry 65536 must raise');
  except
    on E: EInvalidOperationError do
      Check(True, 'entry count over ZIP32 limit raises');
  end;
  Check(Length(LW.Finish) > 0, 'archive at limit still finishes');
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
  T.Test('Entry limit', @TestEntryLimit);
  T.Test('Large payload', @TestLargePayload);
  T.Test('Deflate entry structure', @TestDeflateEntryStructure);
  T.Test('Deflate determinism', @TestDeflateDeterminism);
  T.Test('Directory entries', @TestDirectoryEntries);
  if not T.Run then Halt(1);
end.
