program test_respack_writer;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.respack,
  nextpas.core.respack.base;

{$I golden_respack_v1.inc}

var
  T: TTestSuite;
  { TResPackInputEntry 只持有内容指针，不拥有内存。测试辅助统一把传入的
    TBytes（含 BytesOf(...) 的临时值）复制进 G_Owned 持活，避免悬空指针；
    全局动态数组在单元终结化时释放，heaptrc 计零泄漏。 }
  G_Owned: array of TBytes;

function BytesOf(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

function SameBytes(const AA, AB: TBytes): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(AA) <> Length(AB) then Exit;
  if Length(AA) = 0 then Exit(True);
  for I := 0 to Length(AA) - 1 do
    if AA[I] <> AB[I] then
      Exit;
  Result := True;
end;

function SameBytesRaw(const AA, AB: PByte; const ALen: SizeUInt): Boolean;
var
  I: SizeUInt;
begin
  Result := False;
  for I := 0 to ALen - 1 do
    if AA[I] <> AB[I] then
      Exit;
  Result := True;
end;

function Ent(const APath: string; const AData: TBytes;
  const AModTime: Int64 = 0): TResPackInputEntry;
var
  N: SizeInt;
begin
  N := Length(G_Owned);
  SetLength(G_Owned, N + 1);
  G_Owned[N] := AData;
  Result.Path := APath;
  if Length(AData) > 0 then
    Result.Data := @G_Owned[N][0]
  else
    Result.Data := nil;
  Result.DataSize := SizeUInt(Length(AData));
  Result.ModTime := AModTime;
end;

procedure ExpectResPackError(AProc: TTestProc; const AMsg: string);
begin
  try
    AProc();
    Check(False, AMsg + ' (no exception)');
  except
    on E: EResPackError do Check(True, AMsg);
    on E: Exception do Check(False, AMsg + ' wrong class');
  end;
end;

{ ── 场景 ── }

procedure BuildTwo;
var
  InA: array[0..1] of TResPackInputEntry;
begin
  InA[0] := Ent('b.txt', BytesOf('beta'));
  InA[1] := Ent('a.txt', BytesOf('alpha'));
  ResPackBuild(InA, ResPackDefaultOptions);
end;

procedure TestDeterminism;
var
  InA: array[0..1] of TResPackInputEntry;
  B1, B2: TResPackBlob;
begin
  InA[0] := Ent('x/y.js', BytesOf('console.log(1)'));
  InA[1] := Ent('index.html', BytesOf('<html></html>'));
  B1 := ResPackBuild(InA, ResPackDefaultOptions);
  B2 := ResPackBuild(InA, ResPackDefaultOptions);
  try
    Check(B1.Size = B2.Size, 'determinism size equal');
    Check(SameBytesRaw(B1.Data, B2.Data, B1.Size), 'determinism bytes equal');
  finally
    ResPackFreeBlob(B1);
    ResPackFreeBlob(B2);
  end;
end;

procedure TestSortedIndex;
var
  InA: array[0..2] of TResPackInputEntry;
  B: TResPackBlob;
  RP: TResPack;
begin
  InA[0] := Ent('z.txt', BytesOf('z'));
  InA[1] := Ent('a/m.txt', BytesOf('m'));
  InA[2] := Ent('index.html', BytesOf('i'));
  B := ResPackBuild(InA, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Count = 3, 'sorted count');
    Check(RP.PathOf(RP.EntryAt(0)) = 'a/m.txt', 'sorted [0]=a/m.txt');
    Check(RP.PathOf(RP.EntryAt(1)) = 'index.html', 'sorted [1]=index.html');
    Check(RP.PathOf(RP.EntryAt(2)) = 'z.txt', 'sorted [2]=z.txt');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestDuplicate;
var
  InA: array[0..1] of TResPackInputEntry;
  B: TResPackBlob;
begin
  InA[0] := Ent('same.txt', BytesOf('one'));
  InA[1] := Ent('same.txt', BytesOf('two'));
  try
    B := ResPackBuild(InA, ResPackDefaultOptions);
    ResPackFreeBlob(B);
    Check(False, 'duplicate path accepted');
  except
    on E: EResPackDuplicatePath do Check(True, 'duplicate path raises');
    on E: Exception do Check(False, 'wrong exception class for duplicate');
  end;
end;

procedure TestInvalidPaths;
const
  BAD: array[0..5] of string = ('', '/x', 'a//b', 'a/../b', 'a/', './x');
var
  I: Integer;
  InA: array[0..0] of TResPackInputEntry;
  B: TResPackBlob;

  function Mk(const P: string): TResPackInputEntry;
  begin
    Result := Ent(P, BytesOf('x'));
  end;

begin
  for I := Low(BAD) to High(BAD) do
  begin
    InA[0] := Mk(BAD[I]);
    try
      B := ResPackBuild(InA, ResPackDefaultOptions);
      ResPackFreeBlob(B);
      Check(False, 'invalid path accepted: ' + BAD[I]);
    except
      on E: EResPackInvalidPath do Check(True, 'invalid rejected: ' + BAD[I]);
      on E: Exception do Check(False, 'wrong class for: ' + BAD[I]);
    end;
  end;
end;

procedure TestAlignment;
var
  InA: array[0..2] of TResPackInputEntry;
  B: TResPackBlob;
  RP: TResPack;
  I: SizeUInt;
  OK: Boolean;
begin
  InA[0] := Ent('f1', BytesOf('12345'));
  InA[1] := Ent('f2', BytesOf('1234567890abcdefABCDEF'));  { 22B }
  InA[2] := Ent('empty', nil, 0);
  InA[2].DataSize := 0;
  B := ResPackBuild(InA, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    OK := True;
    for I := 0 to RP.Count - 1 do
      if RP.EntryAt(I).DataOffset mod 16 <> 0 then
        OK := False;
    Check(OK, 'all data slots 16-aligned (incl empty file)');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestDedupeSharedSlot;
var
  InA: array[0..2] of TResPackInputEntry;
  Opts: TResPackBuildOptions;
  B: TResPackBlob;
  RP: TResPack;
  EA, EB, EC: TResPackEntry;
begin
  Opts := ResPackDefaultOptions;
  Opts.Deduplicate := True;
  InA[0] := Ent('one.js', BytesOf('shared-content'));
  InA[1] := Ent('two.js', BytesOf('shared-content'));
  InA[2] := Ent('three.js', BytesOf('other-content!!'));
  B := ResPackBuild(InA, Opts);
  try
    RP := ResPackOpen(B.Data, B.Size);
    EA := RP.Stat('one.js');
    EB := RP.Stat('two.js');
    EC := RP.Stat('three.js');
    Check(EA.DataOffset = EB.DataOffset, 'dedupe shares slot');
    Check(EA.DataOffset <> EC.DataOffset, 'distinct content distinct slot');
    Check(RP.Find('one.js', EA) and RP.Find('two.js', EB),
      'both deduped entries findable');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestNoDedupeSeparate;
var
  InA: array[0..1] of TResPackInputEntry;
  Opts: TResPackBuildOptions;
  B: TResPackBlob;
  RP: TResPack;
begin
  Opts := ResPackDefaultOptions;
  Opts.Deduplicate := False;
  InA[0] := Ent('p/a', BytesOf('same'));
  InA[1] := Ent('q/b', BytesOf('same'));
  B := ResPackBuild(InA, Opts);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Stat('p/a').DataOffset <> RP.Stat('q/b').DataOffset,
      'no-dedupe keeps separate slots');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestHashValue;
var
  InA: array[0..0] of TResPackInputEntry;
  Content: TBytes;
  B: TResPackBlob;
  RP: TResPack;
  E: TResPackEntry;
begin
  Content := BytesOf('hash me please');
  InA[0] := Ent('h.bin', Content);
  B := ResPackBuild(InA, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    E := RP.Stat('h.bin');
    Check((E.Flags and RESPACK_EFLAG_HASHED) <> 0, 'hash flag set');
    Check(E.Hash = ResPackFnv1a32(@Content[0], SizeUInt(Length(Content))),
      'hash equals fnv1a32 of content');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestNoHashFlag;
var
  InA: array[0..0] of TResPackInputEntry;
  Opts: TResPackBuildOptions;
  B: TResPackBlob;
  RP: TResPack;
begin
  Opts := ResPackDefaultOptions;
  Opts.Hashes := False;
  InA[0] := Ent('n.bin', BytesOf('no hash'));
  B := ResPackBuild(InA, Opts);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check((RP.Stat('n.bin').Flags and RESPACK_EFLAG_HASHED) = 0,
      'hash flag clear when disabled');
  finally
    ResPackFreeBlob(B);
  end;
end;

var
  G_DigestSeen: Boolean;
  G_DigestOK: Boolean;

procedure FillDigest(const AData: PByte; const ASize: SizeUInt;
  const ADigestOut: PByte);
var
  I: Integer;
begin
  G_DigestSeen := True;
  for I := 0 to RESPACK_DIGEST_SIZE - 1 do
    ADigestOut[I] := Byte($A0 + I);
end;

procedure TestDigestRegion;
var
  InA: TResPackInputArray;
  Opts: TResPackBuildOptions;
  B: TResPackBlob;
  RP: TResPack;
  D: PByte;
  I: Integer;
  OK: Boolean;
begin
  G_DigestSeen := False;
  Opts := ResPackDefaultOptions;
  Opts.DigestFunc :=
    procedure(const AData: PByte; const ASize: SizeUInt; const ADigestOut: PByte)
    begin
      FillDigest(AData, ASize, ADigestOut);
    end;
  SetLength(InA, 1);
  InA[0] := Ent('d.bin', BytesOf('digest payload'));
  B := ResPackBuild(InA, Opts);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(G_DigestSeen, 'digest func invoked');
    Check((RP.Header.Flags and RESPACK_FLAG_DIGESTED) <> 0, 'header digest flag');
    Check(RP.HasDigests, 'reader exposes digest section');
    D := RP.DigestPtr(0);
    OK := True;
    for I := 0 to RESPACK_DIGEST_SIZE - 1 do
      if D[I] <> Byte($A0 + I) then
        OK := False;
    Check(OK, 'digest bytes match injected output');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestModTime;
var
  InA: array[0..0] of TResPackInputEntry;
  B: TResPackBlob;
  RP: TResPack;
begin
  InA[0] := Ent('t.txt', BytesOf('tt'), Int64(1700000000));
  B := ResPackBuild(InA, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Stat('t.txt').ModTime = Int64(1700000000), 'modtime roundtrip');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure BuildTooLarge;
var
  InA: array[0..0] of TResPackInputEntry;
  Opts: TResPackBuildOptions;
begin
  Opts := ResPackDefaultOptions;
  Opts.MaxTotalInputBytes := 8;
  InA[0] := Ent('big.bin', BytesOf('123456789ABCDEF'));
  ResPackBuild(InA, Opts);
end;

procedure TestTooLargeWrapped;
begin
  ExpectResPackError(@BuildTooLarge, 'over-limit input raises');
end;

procedure TestEmptyPack;
var
  InA: TResPackInputArray;
  B: TResPackBlob;
  RP: TResPack;
begin
  InA := nil;
  B := ResPackBuild(InA, ResPackDefaultOptions);
  try
    Check(B.Size = RESPACK_HEADER_SIZE, 'empty pack is header only');
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Count = 0, 'empty pack count zero');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestGoldenSnapshot;
var
  InA: array[0..3] of TResPackInputEntry;
  B: TResPackBlob;
begin
  { 输入集必须与 golden_respack_v1.inc 头注释一致（由 rp-check/gen_golden 生成） }
  InA[0] := Ent('assets/app.js', BytesOf('console.log(1);'), Int64(100));
  InA[1] := Ent('docs/指南.md', BytesOf('# 指南'#10'中文内容'#10), Int64(200));
  InA[2] := Ent('empty.txt', BytesOf(''), Int64(0));
  InA[3] := Ent('index.html', BytesOf('<html>ok</html>'), Int64(0));
  B := ResPackBuild(InA, ResPackDefaultOptions);
  try
    Check(B.Size = SizeUInt(GOLDEN_SIZE), 'golden size matches');
    Check(SameBytesRaw(B.Data, @GOLDEN_BYTES[0], SizeUInt(GOLDEN_SIZE)),
      'golden bytes match (INV-R5 determinism locked)');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestHeaderFields;
var
  InA: array[0..0] of TResPackInputEntry;
  B: TResPackBlob;
  RP: TResPack;
begin
  InA[0] := Ent('k', BytesOf('kk'));
  B := ResPackBuild(InA, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Header.Version = RESPACK_VERSION, 'header version');
    Check(RP.Header.IndexOffset = RESPACK_HEADER_SIZE, 'index follows header');
    Check(RP.Header.BlobTotal = B.Size, 'blobTotal exact');
    Check((RP.Header.Flags and RESPACK_FLAG_HASHED) <> 0, 'hashed flag');
  finally
    ResPackFreeBlob(B);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.respack.writer');
  T.Test('determinism', @TestDeterminism);
  T.Test('sorted index', @TestSortedIndex);
  T.Test('duplicate path raises', @TestDuplicate);
  T.Test('invalid paths raise', @TestInvalidPaths);
  T.Test('alignment incl empty', @TestAlignment);
  T.Test('dedupe shared slot', @TestDedupeSharedSlot);
  T.Test('no dedupe separate slots', @TestNoDedupeSeparate);
  T.Test('hash value matches fnv1a32', @TestHashValue);
  T.Test('hash flag off', @TestNoHashFlag);
  T.Test('digest region written', @TestDigestRegion);
  T.Test('modtime roundtrip', @TestModTime);
  T.Test('too large raises', @TestTooLargeWrapped);
  T.Test('empty pack opens', @TestEmptyPack);
  T.Test('golden snapshot', @TestGoldenSnapshot);
  T.Test('header fields sane', @TestHeaderFields);
  if not T.Run then Halt(1);
end.
