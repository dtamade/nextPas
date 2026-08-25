program test_compress_tar;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.io.memory,
  nextpas.core.fs,
  nextpas.core.os.env,
  nextpas.core.process,
  nextpas.core.compress.tar,
  nextpas.core.compress;

type
  TCheckProc = procedure;

var
  GDir: string;      // fixture root
  GArc: TBytes;      // archive built by the writer test
  Seed2: Cardinal;

const
  CFmtList: array[0..2] of string = ('gnu', 'pax', 'ustar');

function BytesOfString(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], Result[0], Length(AText));
end;

function Rep(const ACh: string; ACount: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ACount do
    Result := Result + ACh;
end;

function SameBytes(const AA, AB: TBytes): Boolean;
var
  I: SizeInt;
begin
  Result := False;
  if Length(AA) <> Length(AB) then
    Exit;
  for I := 0 to Length(AA) - 1 do
    if AA[I] <> AB[I] then
      Exit;
  Result := True;
end;

procedure CheckBytes(const AExpected, AActual: TBytes; const AMessage: string);
begin
  Check(SameBytes(AExpected, AActual), AMessage);
end;

{ Snapshot the full contents of a memory stream (io.memory has no
  direct ToBytes on IStream, so read back through the reader face) }
function StreamSnapshot(const ASrc: IStream): TBytes;
begin
  SetLength(Result, ASrc.Size);
  if Length(Result) > 0 then
  begin
    ASrc.Seek(0, soBeginning);
    if ASrc.Read(Result[0], Length(Result)) <> Length(Result) then
      raise EIOError.Create('short stream snapshot');
  end;
end;

function LcgNext(var AState: Cardinal): Byte;
begin
  AState := AState * 1664525 + 1013904223;
  Result := Byte((AState shr 16) and $FF);
end;

function RaisedEIOError(AProc: TCheckProc): Boolean;
begin
  Result := False;
  try
    AProc;
  except
    on E: EIOError do
      Result := True;
  end;
end;

function PatternedBytes(ASize: SizeInt; var ASeed: Cardinal): TBytes;
var
  I: SizeInt;
begin
  SetLength(Result, ASize);
  for I := 0 to ASize - 1 do
    Result[I] := LcgNext(ASeed);
end;

procedure PutFile(const APath: string; const AData: TBytes);
var
  DirPart: string;
begin
  DirPart := PathDir(APath);
  if (DirPart <> '') and not DirectoryExists(DirPart) then
    MkdirAll(DirPart, PermDirDefault);
  WriteFile(APath, AData, PermDefault);
end;

{ ── writer vs system tar ─────────────────────────────────────────────────── }

procedure TestWriterArchiveExtractedBySystemTar;
var
  S: IStream;
  TW: TTarWriter;
  Seed: Cardinal;
  D511, D512, D513, DBig: TBytes;
  XDir: string;
begin
  Seed := $BEEF0001;
  D511 := PatternedBytes(511, Seed);
  D512 := PatternedBytes(512, Seed);
  D513 := PatternedBytes(513, Seed);
  DBig := PatternedBytes(70000, Seed);

  S := CreateBytesStream;
  // IStream does not extend IWriter; bridge via runtime interface cast
  TW := TTarWriter.Create((S as IWriter));
  TW.AddFile('empty.dat', nil);
  TW.AddFile('one.dat', BytesOfString('A'), $1A4, 1735689600);
  TW.AddFile('mid511.dat', D511);
  TW.AddFile('mid512.dat', D512);
  TW.AddFile('mid513.dat', D513);
  TW.AddDir('sub');
  TW.AddFile('sub/big.bin', DBig);
  TW.AddDir('sub2');
  TW.AddFile('sub2/deep.txt', BytesOfString('deep'#10));
  TW.Finish;
  TW.Free;
  GArc := StreamSnapshot(S);
  S := nil;
  CheckTrue(Length(GArc) mod 512 = 0, 'archive is block aligned');

  PutFile(PathJoin2(GDir, 'w.tar'), GArc);
  XDir := PathJoin2(GDir, 'x');
  MkdirAll(XDir, PermDirDefault);
  RunInChecked('tar',
    ['-xf', PathJoin2(GDir, 'w.tar'), '-C', XDir], GDir);

  CheckTrue(DirectoryExists(PathJoin2(XDir, 'sub')), 'dir extracted');
  CheckBytes(TBytes(nil), ReadFile(PathJoin2(XDir, 'empty.dat')),
    'empty file');
  CheckBytes(BytesOfString('A'), ReadFile(PathJoin2(XDir, 'one.dat')),
    '1-byte file');
  CheckBytes(D511, ReadFile(PathJoin2(XDir, 'mid511.dat')), '511 bytes');
  CheckBytes(D512, ReadFile(PathJoin2(XDir, 'mid512.dat')), '512 bytes');
  CheckBytes(D513, ReadFile(PathJoin2(XDir, 'mid513.dat')), '513 bytes');
  CheckBytes(DBig, ReadFile(PathJoin2(XDir, 'sub/big.bin')), '70000 bytes');
  CheckBytes(BytesOfString('deep'#10),
    ReadFile(PathJoin2(XDir, 'sub2/deep.txt')), 'nested text');
end;

{ ── reader vs system tar ─────────────────────────────────────────────────── }

procedure RaiseCorruptHeader;
var
  Bad: TBytes;
  H: TTarHeader;
begin
  Bad := Copy(GArc, 0, Length(GArc));
  Bad[3] := Bad[3] xor $20;
  with TTarReader.Create(Bad) do
  try
    Next(H);
  finally
    Free;
  end;
end;

procedure TestReaderOnSystemTarArchive;
var
  YDir, RefPath: string;
  R: TTarReader;
  H: TTarHeader;
  Body: TBytes;
begin
  YDir := PathJoin2(GDir, 'y');
  MkdirAll(PathJoin2(YDir, 'r_dir'), PermDirDefault);
  PutFile(PathJoin2(YDir, 'r_a.txt'), BytesOfString('alpha'));
  Body := PatternedBytes(600, Seed2);
  PutFile(PathJoin2(YDir, 'r_dir/r_b.bin'), Body);
  RunInChecked('tar',
    ['-cf', 'ref.tar', '-C', 'y', 'r_a.txt', 'r_dir', 'r_dir/r_b.bin'], GDir);
  RefPath := PathJoin2(GDir, 'ref.tar');
  R := TTarReader.Create(ReadFile(RefPath));
  try
    CheckTrue(R.Next(H), 'first entry');
    CheckEqual('r_a.txt', H.Name, 'plain name');
    CheckEqual(Ord(tekRegular), Ord(H.Kind), 'regular kind');
    CheckBytes(BytesOfString('alpha'), R.EntryData, 'payload');

    CheckTrue(R.Next(H), 'second entry');
    CheckEqual('r_dir', Copy(H.Name, 1, Length('r_dir')), 'dir name core');
    CheckEqual(Ord(tekDirectory), Ord(H.Kind), 'dir kind');
    CheckTrue(R.EntryData = nil, 'dir has no payload');

    CheckTrue(R.Next(H), 'third entry');
    CheckEqual('r_dir/r_b.bin', H.Name, 'nested path preserved');
    CheckEqual(600, H.Size, 'size from octal header');
    CheckBytes(Body, R.EntryData, 'binary payload');

    // GNU tar stores the repeated file argument as a hardlink entry
    CheckTrue(R.Next(H), 'fourth entry (gnu hardlink dedup)');
    CheckEqual('r_dir/r_b.bin', H.Name, 'hardlink name');
    CheckEqual(Ord(tekHardLink), Ord(H.Kind), 'hardlink kind');
    CheckEqual('r_dir/r_b.bin', H.LinkName, 'hardlink target');

    CheckFalse(R.Next(H), 'archive ends cleanly');
  finally
    R.Free;
  end;
end;

procedure TestCorruptChecksumRaises;
begin
  CheckTrue(RaisedEIOError(@RaiseCorruptHeader),
    'corrupt header raises EIOError');
end;

{ ── long names: GNU / pax / ustar prefix split ───────────────────────────── }

procedure TestLongNamesGnuPaxAndUstarSplit;
var
  Y2Dir, LongRel, TarPath: string;
  Payload: TBytes;
  Fmt: string;
  R: TTarReader;
  H: TTarHeader;
  S: IStream;
  TW: TTarWriter;
  SplitName, XDir: string;
begin
  Y2Dir := PathJoin2(GDir, 'y2');
  LongRel := Rep('l', 40) + '/' + Rep('m', 40) + '/'
    + Rep('n', 45);
  Payload := BytesOfString('longname-payload');
  PutFile(PathJoin([Y2Dir, LongRel]), Payload);

  for Fmt in CFmtList do
  begin
    TarPath := 'fmt_' + Fmt + '.tar';
    RunInChecked('tar',
      ['--format=' + Fmt, '-cf', TarPath, '-C', 'y2', LongRel], GDir);
    R := TTarReader.Create(ReadFile(PathJoin2(GDir, TarPath)));
    try
      CheckTrue(R.Next(H), Fmt + ': entry found');
      CheckEqual(LongRel, H.Name, Fmt + ': full long name');
      CheckBytes(Payload, R.EntryData, Fmt + ': payload intact');
      CheckFalse(R.Next(H), Fmt + ': no extra entries');
    finally
      R.Free;
    end;
  end;

  // our writer must split >100 char names into ustar prefix fields
  SplitName := Rep('q', 80) + '/' + Rep('z', 60);
  S := CreateBytesStream;
  TW := TTarWriter.Create((S as IWriter));
  TW.AddFile(SplitName, Payload);
  TW.Finish;
  TW.Free;
  PutFile(PathJoin2(GDir, 'split.tar'), StreamSnapshot(S));
  S := nil;
  XDir := PathJoin2(GDir, 'xs');
  MkdirAll(XDir, PermDirDefault);
  RunInChecked('tar',
    ['-xf', PathJoin2(GDir, 'split.tar'), '-C', XDir], GDir);
  CheckTrue(FileExists(PathJoin([XDir, SplitName])), 'split name extracted');
  CheckBytes(Payload, ReadFile(PathJoin([XDir, SplitName])),
    'split name content');
end;

{ ── gzip composition + system listing ───────────────────────────────────── }

procedure TestTarGzComboAndSystemList;
var
  Gz, Back: TBytes;
  Out: TProcessOutput;
  LineCount, I: Integer;
begin
  Gz := GzipCompress(GArc);
  PutFile(PathJoin2(GDir, 'w.tar.gz'), Gz);
  Out := RunInChecked('tar', ['-tzf', PathJoin2(GDir, 'w.tar.gz')], GDir);
  LineCount := 0;
  for I := 1 to Length(Out.StdOut) do
    if Out.StdOut[I] = #10 then
      Inc(LineCount);
  CheckTrue(LineCount >= 9, 'system tar lists our gzipped archive');

  Back := GzipDecompress(Gz);
  CheckBytes(GArc, Back, 'gzip roundtrip restores tar bytes');
end;

{ ── base-256 numeric field ───────────────────────────────────────────────── }

procedure TestBase256SizeField;
var
  B: TBytes;
  Sum: Integer;
  I: Integer;
  R: TTarReader;
  H: TTarHeader;
  Hello: TBytes;

  procedure PutTextAt(AOfs: SizeInt; const AValue: string);
  begin
    Move(AValue[1], B[AOfs], Length(AValue));
  end;

begin
  SetLength(B, 2048);
  FillChar(B[0], 2048, 0);
  PutTextAt(0, 'b256.txt');
  PutTextAt(100, '0000644' + #0);
  B[124] := $80;   // GNU base-256 marker, value 5 in the remaining bytes
  B[135] := 5;
  PutTextAt(136, '00000000000' + #0);
  FillChar(B[148], 8, Ord(' '));
  B[156] := Ord('0');
  PutTextAt(257, 'ustar');
  PutTextAt(263, '00');
  Sum := 0;
  for I := 0 to 511 do
    Sum := Sum + B[I];
  for I := 0 to 5 do
    B[148 + I] := Byte(Ord('0') + ((Sum shr ((5 - I) * 3)) and 7));
  B[154] := 0;
  B[155] := Ord(' ');
  Hello := BytesOfString('hello');
  Move(Hello[0], B[512], 5);

  R := TTarReader.Create(B);
  try
    CheckTrue(R.Next(H), 'entry parsed');
    CheckEqual('b256.txt', H.Name, 'name');
    CheckEqual(5, H.Size, 'base-256 size decoded');
    CheckBytes(Hello, R.EntryData, 'payload after b256 header');
    CheckFalse(R.Next(H), 'clean end');
  finally
    R.Free;
  end;
end;

{ ── main ─────────────────────────────────────────────────────────────────── }

procedure SetupFixture;
begin
  GDir := PathJoin([GetTempDir,
    'nextpas_tar_' + IntToStr(GetProcessID)]);
  RemoveAll(GDir);
  MkdirAll(GDir, PermDirDefault);
  Seed2 := $1234ABCD;
end;

procedure CleanupFixture;
begin
  RemoveAll(GDir);
end;

var
  T: TTestSuite;
begin
  SetupFixture;
  try
    T := TTestSuite.Create('nextpas.core.compress.tar');
    T.Test('writer archive extracted by system tar',
      @TestWriterArchiveExtractedBySystemTar);
    T.Test('reader consumes system tar archive',
      @TestReaderOnSystemTarArchive);
    T.Test('corrupt checksum raises', @TestCorruptChecksumRaises);
    T.Test('long names across gnu/pax/ustar and our prefix split',
      @TestLongNamesGnuPaxAndUstarSplit);
    T.Test('tar.gz composition and system listing',
      @TestTarGzComboAndSystemList);
    T.Test('base-256 size field decode', @TestBase256SizeField);
    if not T.Run then Halt(1);
  finally
    CleanupFixture;
  end;
end.
