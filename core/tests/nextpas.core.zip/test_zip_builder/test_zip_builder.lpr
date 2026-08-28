program test_zip_builder;
{**
 * @desc Fluent Builder 高级感门（二十三期）：链式 `ZipBuilder` 的
 *       字节级一致性与 fail-closed 语义证明。
 *
 * 覆盖：
 * 1. 链式与直接写器字节级一致（含 Store/Deflate/Directory/Options/Reserve）；
 * 2. ForceZip64 形态与结构校验；
 * 3. Finish 后 fail-closed（再次 Add/Finish 拒绝）；
 * 4. StreamTo 直写与缓冲式字节级一致；
 * 5. 混合 unicode + 权限位往返正确性（Builder 产出经 Reader 校验）。
 *}
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.bytes.builder,
  nextpas.core.zip,
  nextpas.core.zip.base,
  nextpas.core.checksum.crc32;

var
  T: TTestSuite;

function BytesOfStr(const S: string): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then Move(Pointer(S)^, Result[0], Length(S));
end;

function SameBytes(const A, B: TBytes): Boolean;
var LI: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for LI := 0 to High(A) do if A[LI] <> B[LI] then Exit(False);
  Result := True;
end;

function PatternBytes(ALen, ASeed: Integer): TBytes;
var LI: Integer;
begin
  SetLength(Result, ALen);
  for LI := 0 to ALen-1 do Result[LI] := Byte((LI*3 + ASeed + (LI shr 5)) mod 251);
end;

function LE16At(const AB: TBytes; AOff: Integer): Word;
begin
  Result := Word(AB[AOff]) or (Word(AB[AOff+1]) shl 8);
end;

function LE32At(const AB: TBytes; AOff: Integer): LongWord;
var LI: Integer;
begin
  Result := 0;
  for LI := 3 downto 0 do Result := (Result shl 8) or AB[AOff+LI];
end;

type
  TCollectWriter = class(TInterfacedObject, IWriter)
  private
    FBuf: IBytesBuilder;
  public
    constructor Create;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Bytes: TBytes;
  end;

constructor TCollectWriter.Create;
begin
  inherited Create;
  FBuf := CreateBytesBuilder(256);
end;

function TCollectWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount>0 then FBuf.AppendBytes(PByte(@ABuf), ACount);
  Result := ACount;
end;

function TCollectWriter.Bytes: TBytes;
begin
  Result := FBuf.ToBytes;
end;

procedure TestChainMatchesWriter;
var
  B: IZipBuilder;
  W: IZipWriter;
  Opts: TZipAddOptions;
  LA, LB: TBytes;
begin
  Opts := DefaultZipAddOptions;
  Opts.Method := zmStore;
  Opts.Mode := ZipRegularMode($1A4);

  B := ZipBuilder;
  B.Reserve(10)
   .Add('a.txt', BytesOfStr('hello'))
   .AddDeflate('b.bin', PatternBytes(4096, 7))
   .AddWithOptions('c.txt', BytesOfStr('options'), Opts)
   .AddDirectory('mydir');
  LA := B.Finish;

  W := NewZipWriter;
  W.Reserve(10);
  W.AddEntry('a.txt', BytesOfStr('hello'));
  W.AddEntryDeflate('b.bin', PatternBytes(4096, 7));
  W.AddEntryWithOptions('c.txt', BytesOfStr('options'), Opts);
  W.AddDirectory('mydir');
  LB := W.Finish;

  Check(Length(LA)=Length(LB), 'chain vs writer length');
  Check(SameBytes(LA, LB), 'chain vs writer byte-identical');

  // reader roundtrip
  Check(SameBytes(NewZipReader(LA).ExtractToBytesByName('a.txt'), BytesOfStr('hello')), 'builder a.txt roundtrip');
  Check(SameBytes(NewZipReader(LA).ExtractToBytesByName('b.bin'), PatternBytes(4096, 7)), 'builder b.bin roundtrip');
  Check(NewZipReader(LA).Entry(NewZipReader(LA).Find('mydir/')).IsDirectory, 'builder dir flag');
end;

procedure TestForceZip64;
var
  B: IZipBuilder;
  LZip: TBytes;
begin
  B := ZipBuilderForceZip64;
  B.Add('z.txt', BytesOfStr('zip64 forced'));
  LZip := B.Finish;
  // local version >=45, zip64 EOCD present at tail
  Check(LE16At(LZip, 4) >= 45, 'force64 local version >=45');
  Check(LE32At(LZip, Length(LZip)-98) = $06064B50, 'force64 zip64 EOCD present');
  Check(LE32At(LZip, Length(LZip)-42) = $07064B50, 'force64 locator present');
  Check(SameBytes(NewZipReader(LZip).ExtractToBytesByName('z.txt'), BytesOfStr('zip64 forced')), 'force64 roundtrip');
end;

procedure TestFinishGuards;
var
  B: IZipBuilder;
  LOk: Boolean;
begin
  B := ZipBuilder;
  B.Add('a.txt', BytesOfStr('x'));
  B.Finish;
  LOk := False;
  try B.Add('b.txt', BytesOfStr('y')); except on E: EInvalidOperationError do LOk := True; end;
  Check(LOk, 'Add after Finish raises');
  LOk := False;
  try B.Finish; except on E: EInvalidOperationError do LOk := True; end;
  Check(LOk, 'second Finish raises');
end;

procedure TestStreamToIdentical;
var
  B1, B2: IZipBuilder;
  Cw: TCollectWriter;
  LA, LB: TBytes;
  LTotal: UInt64;
begin
  // buffered path
  B1 := ZipBuilder;
  B1.Add('a.txt', BytesOfStr('hello stream'))
     .AddDeflate('b.bin', PatternBytes(20000, 11));
  LA := B1.Finish;

  // streamed path
  Cw := TCollectWriter.Create;
  B2 := ZipBuilder;
  B2.StreamTo(Cw)
     .Add('a.txt', BytesOfStr('hello stream'))
     .AddDeflate('b.bin', PatternBytes(20000, 11));
  LTotal := B2.FinishTo(Cw);
  LB := Cw.Bytes;
  Check(SameBytes(LA, LB), 'Builder StreamTo identical to buffered');
  Check(Int64(LTotal)=Int64(Length(LB)), 'FinishTo total matches');
end;

procedure TestMixedUnicodeAndMode;
var
  B: IZipBuilder;
  Opts: TZipAddOptions;
  LZip: TBytes;
  R: IZipReader;
begin
  Opts := DefaultZipAddOptions;
  Opts.Method := zmDeflate;
  Opts.Mode := ZipRegularMode($640);

  B := ZipBuilder;
  B.Add('a.txt', BytesOfStr('alpha'))
   .AddWithOptions('m.txt', BytesOfStr('mode payload'), Opts)
   .Add('图片/文件.txt', PatternBytes(1024, 33))
   .AddDirectory('assets');
  LZip := B.Finish;

  R := NewZipReader(LZip);
  Check(R.EntryCount=4, 'mixed count 4');
  Check(SameBytes(R.ExtractToBytesByName('a.txt'), BytesOfStr('alpha')), 'mixed a.txt');
  Check(SameBytes(R.ExtractToBytesByName('m.txt'), BytesOfStr('mode payload')), 'mixed m.txt');
  Check(SameBytes(R.ExtractToBytesByName('图片/文件.txt'), PatternBytes(1024, 33)), 'mixed unicode deflate');
  Check(R.Entry(R.Find('assets/')).IsDirectory, 'mixed dir');
  Check(ZipUnixModeOf(R.Entry(R.Find('m.txt'))) = Word($8000 or $640), 'mixed mode kept');
end;

begin
  T := TTestSuite.Create('nextpas.core.zip.builder');
  T.Test('Chain matches writer', @TestChainMatchesWriter);
  T.Test('ForceZip64 structure', @TestForceZip64);
  T.Test('Finish guards', @TestFinishGuards);
  T.Test('StreamTo identical', @TestStreamToIdentical);
  T.Test('Mixed unicode/mode roundtrip', @TestMixedUnicodeAndMode);
  if not T.Run then Halt(1);
end.
