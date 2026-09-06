program test_respack_reader;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.respack,
  nextpas.core.respack.base,
  nextpas.core.platform.base;

var
  T: TTestSuite;
  { TResPackInputEntry 只持有内容指针。MakeInput 把传入内容复制进 G_Owned
    持活（含临时值）；全局动态数组在单元终结化释放，heaptrc 计零泄漏。 }
  G_Owned: array of TBytes;

function BytesOf(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

function SameBytesRaw(const AA, AB: PByte; const ALen: SizeUInt): Boolean;
var
  I: SizeUInt;
begin
  Result := False;
  if ALen = 0 then Exit(True);
  for I := 0 to ALen - 1 do
    if AA[I] <> AB[I] then
      Exit;
  Result := True;
end;

function MakeInput(const APath, AContent: string): TResPackInputEntry;
var
  N: SizeInt;
begin
  N := Length(G_Owned);
  SetLength(G_Owned, N + 1);
  G_Owned[N] := BytesOf(AContent);
  Result.Path := APath;
  if Length(G_Owned[N]) > 0 then
    Result.Data := @G_Owned[N][0]
  else
    Result.Data := nil;
  Result.DataSize := SizeUInt(Length(G_Owned[N]));
  Result.ModTime := 0;
end;

function BuildBase(out B: TResPackBlob): Boolean;
var
  InA: array[0..1] of TResPackInputEntry;
  C1, C2: TBytes;
begin
  C1 := BytesOf('console.log(1);');
  C2 := BytesOf('<html>ok</html>');
  InA[0] := Default(TResPackInputEntry);
  InA[0].Path := 'assets/app.js';
  InA[0].Data := @C1[0];
  InA[0].DataSize := SizeUInt(Length(C1));
  InA[1] := Default(TResPackInputEntry);
  InA[1].Path := 'index.html';
  InA[1].Data := @C2[0];
  InA[1].DataSize := SizeUInt(Length(C2));
  B := ResPackBuild(InA, ResPackDefaultOptions);
  Result := True;
end;

procedure BuildDigestBase(out B: TResPackBlob);
var
  InA: array[0..0] of TResPackInputEntry;
  Opts: TResPackBuildOptions;
  C: TBytes;
begin
  C := BytesOf('payload');
  InA[0] := Default(TResPackInputEntry);
  InA[0].Path := 'p.bin';
  InA[0].Data := @C[0];
  InA[0].DataSize := SizeUInt(Length(C));
  Opts := ResPackDefaultOptions;
  Opts.DigestFunc :=
    procedure(const AData: PByte; const ASize: SizeUInt; const ADigestOut: PByte)
    var
      I: Integer;
    begin
      for I := 0 to RESPACK_DIGEST_SIZE - 1 do
        ADigestOut[I] := Byte($10 + I);
    end;
  B := ResPackBuild(InA, Opts);
end;

{ 损坏用例统一入口：期望 AProc 抛 EResPackCorrupted；其余类名或未抛都判负 }
procedure ExpectCorrupt(AProc: TTestProc; const AMsg: string);
begin
  try
    AProc();
    Check(False, AMsg + ' (accepted!)');
  except
    on E: EResPackCorrupted do Check(True, AMsg);
    on E: Exception do Check(False, AMsg + ' wrong exception class');
  end;
end;

procedure ExpectCorruptStep(AProc: TTestProc; const AMsg: string; const AExpectStep: Integer);
begin
  try
    AProc();
    Check(False, AMsg + ' (accepted!)');
  except
    on E: EResPackCorrupted do Check(E.Step = AExpectStep, AMsg);
    on E: Exception do Check(False, AMsg + ' wrong exception class');
  end;
end;

{ ── 正常路径 ── }

procedure TestHappyOpen;
var
  B: TResPackBlob;
  RP: TResPack;
  E: TResPackEntry;
  C: TBytes;
begin
  BuildBase(B);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Count = 2, 'base pack count');
    Check(RP.Find('assets/app.js', E), 'find nested');
    C := BytesOf('console.log(1);');
    Check(SameBytesRaw(RP.ContentPtr(E), @C[0], SizeUInt(Length(C))),
      'content slice bytes');
    Check(not RP.HasDigests, 'no digest section by default');
    Check(RP.Find('missing.css', E) = False, 'find miss returns False');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestStatMissRaises;
var
  B: TResPackBlob;
  RP: TResPack;
  Got: Boolean;
begin
  BuildBase(B);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Got := False;
    try
      RP.Stat('nope.bin');
    except
      on E: EResPackNotFound do Got := True;
      on E: Exception do ;
    end;
    Check(Got, 'stat miss raises not-found');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestEntryAtOrderAndPathOf;
var
  B: TResPackBlob;
  RP: TResPack;
begin
  BuildBase(B);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.PathOf(RP.EntryAt(0)) = 'assets/app.js', 'order [0]');
    Check(RP.PathOf(RP.EntryAt(1)) = 'index.html', 'order [1]');
  finally
    ResPackFreeBlob(B);
  end;
end;

{ ── 损坏构造器（只篡改并触发 Open；异常交给 ExpectCorrupt 包装层，
  blob 一律经 try-finally 归还） ── }

procedure CorruptBadMagic;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    B.Data[0] := Byte('X');
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptBadVersion;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    WrU32LE(B.Data + 4, 99);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptUnknownHeaderFlag;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    WrU32LE(B.Data + 8, RdU32LE(B.Data + 8) or $00000004);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptDigestFlagNoOffset;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    WrU32LE(B.Data + 8, RESPACK_FLAG_DIGESTED);
    WrU64LE(B.Data + 24, 0);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptIndexOffsetTooSmall;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    WrU64LE(B.Data + 16, 20);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptIndexBeyondBlob;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    WrU32LE(B.Data + 12, 100000);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptTruncated;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    ResPackOpen(B.Data, B.Size - 1);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptReservedNonzero;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    B.Data[RESPACK_HEADER_SIZE + 37] := 1;
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptUnknownCodec;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    B.Data[RESPACK_HEADER_SIZE + 36] := 9;
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptUnknownEntryFlag;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    WrU16LE(B.Data + RESPACK_HEADER_SIZE + 6,
      RdU16LE(B.Data + RESPACK_HEADER_SIZE + 6) or $0002);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptEmptyPath;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    WrU16LE(B.Data + RESPACK_HEADER_SIZE + 4, 0);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptDataNotAligned;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    WrU64LE(B.Data + RESPACK_HEADER_SIZE + 8,
      RdU64LE(B.Data + RESPACK_HEADER_SIZE + 8) + 1);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptPathBeyondStrtab;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    WrU32LE(B.Data + RESPACK_HEADER_SIZE, 4000);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptUnsortedIndex;
var
  B: TResPackBlob;
  Tmp: array[0..RESPACK_ENTRY_SIZE - 1] of Byte;
  O0, O1: SizeUInt;
begin
  BuildBase(B);
  try
    O0 := RESPACK_HEADER_SIZE;
    O1 := RESPACK_HEADER_SIZE + RESPACK_ENTRY_SIZE;
    Move((B.Data + O0)^, Tmp[0], RESPACK_ENTRY_SIZE);
    Move((B.Data + O1)^, (B.Data + O0)^, RESPACK_ENTRY_SIZE);
    Move(Tmp[0], (B.Data + O1)^, RESPACK_ENTRY_SIZE);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptNonCanonicalStored;
var
  InA: array[0..0] of TResPackInputEntry;
  B: TResPackBlob;
  StrOff: SizeUInt;
begin
  { 合法包 'aa/bb'(len=5) 后改写存储路径为 '../zz'——等长覆盖含 '..' 段 }
  InA[0] := MakeInput('aa/bb', 'x');
  B := ResPackBuild(InA, ResPackDefaultOptions);
  try
    StrOff := RESPACK_HEADER_SIZE + RESPACK_ENTRY_SIZE;  { 单条目：strtab 紧跟 index }
    Move('../zz', (B.Data + StrOff)^, 5);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptDigestOutOfRange;
var
  B: TResPackBlob;
begin
  BuildDigestBase(B);
  try
    WrU64LE(B.Data + 24, RdU64LE(B.Data + 32) - 4);  { digestOffset = blobTotal-4 }
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptDataOverlapsIndex;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    WrU64LE(B.Data + RESPACK_HEADER_SIZE + 8, 80);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptDigestOverlapsData;
var
  B: TResPackBlob;
  DataOff: UInt64;
begin
  BuildDigestBase(B);
  try
    DataOff := RdU64LE(B.Data + RESPACK_HEADER_SIZE + 8);
    WrU64LE(B.Data + 24, DataOff);
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure CorruptHeaderHashedMismatch;
var
  B: TResPackBlob;
begin
  BuildBase(B);
  try
    { header HASHED set, but clear entry 0 HASHED → step5 }
    WrU16LE(B.Data + RESPACK_HEADER_SIZE + 6,
      RdU16LE(B.Data + RESPACK_HEADER_SIZE + 6) and not Word(RESPACK_EFLAG_HASHED));
    ResPackOpen(B.Data, B.Size);
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure DigestBaseOpensFine;
var
  B: TResPackBlob;
  RP: TResPack;
  D: PByte;
  OK: Boolean;
  I: Integer;
begin
  BuildDigestBase(B);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.HasDigests, 'digest base has digests');
    D := RP.DigestPtr(0);
    OK := True;
    for I := 0 to RESPACK_DIGEST_SIZE - 1 do
      if D[I] <> Byte($10 + I) then
        OK := False;
    Check(OK, 'digest content intact');
  finally
    ResPackFreeBlob(B);
  end;
end;

{ ── BE 显式换序门禁（P0-5）：FORMAT.md 固定 LE，RdU*LE/WrU*LE 位移编解码与宿主无关；
  host LE 下 BE buffer 经 RdU*LE 读回必为 byte-swap，host BE 时同理显式换序；
  联动 platform.base.CURRENT_ENDIAN / platform.info.CurrentEndian 探测，但编解码
  不依赖宿主，WrU*LE 逆序写入即得 BE 对照。 ── }

function SwapU16BE(const V: Word): Word; inline;
begin
  Result := Word((V shr 8) or (V shl 8));
end;

function SwapU32BE(const V: UInt32): UInt32; inline;
begin
  Result := (V shr 24) or ((V shr 8) and $0000FF00) or ((V shl 8) and $00FF0000) or (V shl 24);
end;

function SwapU64BE(const V: UInt64): UInt64; inline;
begin
  Result := (UInt64(SwapU32BE(UInt32(V))) shl 32) or SwapU32BE(UInt32(V shr 32));
end;

procedure WrU32BE(AData: PByte; const AValue: UInt32); inline;
begin
  { WrU32LE 逆序写入：BE 对照 = LE helper 的字节逆序 }
  AData[0] := Byte(AValue shr 24);
  AData[1] := Byte(AValue shr 16);
  AData[2] := Byte(AValue shr 8);
  AData[3] := Byte(AValue);
end;

procedure WrU64BE(AData: PByte; const AValue: UInt64); inline;
begin
  WrU32BE(AData, UInt32(AValue shr 32));
  WrU32BE(AData + 4, UInt32(AValue));
end;

procedure TestBEHeaderRoundTrip;
var
  BufLE: array[0..RESPACK_HEADER_SIZE - 1] of Byte;
  BufBE: array[0..RESPACK_HEADER_SIZE - 1] of Byte;
  V32: UInt32;
  V64: UInt64;
begin
  { 联动 platform.endian：当前 host 应为 LE，本门禁在 LE 下验证 BE 对照的显式换序 }
  Check(CURRENT_ENDIAN = endLittle, 'host LE for BE gate');
  FillChar(BufLE[0], SizeOf(BufLE), 0);
  FillChar(BufBE[0], SizeOf(BufBE), 0);
  V32 := $01020304;
  V64 := UInt64($0102030405060708);
  { LE 正向：WrU*LE → RdU*LE 往返 }
  WrU32LE(@BufLE[4], V32);
  WrU64LE(@BufLE[16], V64);
  Check(RdU32LE(@BufLE[4]) = V32, 'BE gate: LE header u32 roundtrip');
  Check(RdU64LE(@BufLE[16]) = V64, 'BE gate: LE header u64 roundtrip');
  { BE 对照：WrU*LE 逆序写入（此处用 WrU*BE）→ RdU*LE 读回应为 byte-swap }
  WrU32BE(@BufBE[4], V32);
  WrU64BE(@BufBE[16], V64);
  Check(RdU32LE(@BufBE[4]) = SwapU32BE(V32), 'BE gate: BE header u32 swap');
  Check(RdU64LE(@BufBE[16]) = SwapU64BE(V64), 'BE gate: BE header u64 swap');
  { 交叉验证：LE 的 BE 逆序即 BE 的 LE 逆序 }
  Check(RdU32LE(@BufBE[4]) <> V32, 'BE gate: BE header u32 not LE');
end;

procedure TestBEEntryRoundTrip;
var
  BufLE: array[0..RESPACK_ENTRY_SIZE - 1] of Byte;
  BufBE: array[0..RESPACK_ENTRY_SIZE - 1] of Byte;
  PathOff: UInt32;
  PathLen: Word;
  Flags: Word;
  DataOff: UInt64;
  FSize: UInt64;
  HVal: UInt32;
begin
  Check(CURRENT_ENDIAN = endLittle, 'host LE for BE gate entry');
  FillChar(BufLE[0], SizeOf(BufLE), 0);
  FillChar(BufBE[0], SizeOf(BufBE), 0);
  PathOff := $0A0B0C0D;
  PathLen := $1234;
  Flags := $0102;
  DataOff := UInt64($1122334455667788);
  FSize := UInt64($AABBCCDD00112233);
  HVal := $DEADBEEF;
  { LE 正向 }
  WrU32LE(@BufLE[0], PathOff);
  WrU16LE(@BufLE[4], PathLen);
  WrU16LE(@BufLE[6], Flags);
  WrU64LE(@BufLE[8], DataOff);
  WrU64LE(@BufLE[16], FSize);
  WrU32LE(@BufLE[32], HVal);
  Check(RdU32LE(@BufLE[0]) = PathOff, 'BE gate: LE entry PathOff');
  Check(RdU16LE(@BufLE[4]) = PathLen, 'BE gate: LE entry PathLen');
  Check(RdU16LE(@BufLE[6]) = Flags, 'BE gate: LE entry Flags');
  Check(RdU64LE(@BufLE[8]) = DataOff, 'BE gate: LE entry DataOff');
  Check(RdU64LE(@BufLE[16]) = FSize, 'BE gate: LE entry Size');
  Check(RdU32LE(@BufLE[32]) = HVal, 'BE gate: LE entry Hash');
  { BE 对照：WrU*LE 逆序写入 }
  WrU32BE(@BufBE[0], PathOff);
  BufBE[4] := Byte(PathLen shr 8); BufBE[5] := Byte(PathLen);
  BufBE[6] := Byte(Flags shr 8); BufBE[7] := Byte(Flags);
  WrU64BE(@BufBE[8], DataOff);
  WrU64BE(@BufBE[16], FSize);
  WrU32BE(@BufBE[32], HVal);
  Check(RdU32LE(@BufBE[0]) = SwapU32BE(PathOff), 'BE gate: BE entry PathOff swap');
  Check(RdU16LE(@BufBE[4]) = SwapU16BE(PathLen), 'BE gate: BE entry PathLen swap');
  Check(RdU16LE(@BufBE[6]) = SwapU16BE(Flags), 'BE gate: BE entry Flags swap');
  Check(RdU64LE(@BufBE[8]) = SwapU64BE(DataOff), 'BE gate: BE entry DataOff swap');
  Check(RdU64LE(@BufBE[16]) = SwapU64BE(FSize), 'BE gate: BE entry Size swap');
  Check(RdU32LE(@BufBE[32]) = SwapU32BE(HVal), 'BE gate: BE entry Hash swap');
end;

{ ── 包装层：把"构造损坏包并期待拒绝"的异常收进断言 ── }

procedure WStep1BadMagic;
begin
  ExpectCorrupt(@CorruptBadMagic, 'step1 bad magic');
end;

procedure WStep2BadVersion;
begin
  ExpectCorrupt(@CorruptBadVersion, 'step2 bad version');
end;

procedure WStep2UnknownHeaderFlag;
begin
  ExpectCorrupt(@CorruptUnknownHeaderFlag, 'step2 unknown header flag');
end;

procedure WStep2DigestFlagNoOffset;
begin
  ExpectCorrupt(@CorruptDigestFlagNoOffset, 'step2 digest flag w/o offset');
end;

procedure WStep3IndexOffsetTooSmall;
begin
  ExpectCorrupt(@CorruptIndexOffsetTooSmall, 'step3 index offset too small');
end;

procedure WStep3IndexBeyondBlob;
begin
  ExpectCorrupt(@CorruptIndexBeyondBlob, 'step3 index beyond blob');
end;

procedure WStep4Truncated;
begin
  ExpectCorrupt(@CorruptTruncated, 'step4 truncated buffer');
end;

procedure WStep5ReservedNonzero;
begin
  ExpectCorrupt(@CorruptReservedNonzero, 'step5 reserved nonzero');
end;

procedure WStep5UnknownCodec;
begin
  ExpectCorrupt(@CorruptUnknownCodec, 'step5 unknown codecId');
end;

procedure WStep5UnknownEntryFlag;
begin
  ExpectCorrupt(@CorruptUnknownEntryFlag, 'step5 unknown entry flag');
end;

procedure WStep5EmptyPath;
begin
  ExpectCorrupt(@CorruptEmptyPath, 'step5 empty path');
end;

procedure WStep5UnalignedSlot;
begin
  ExpectCorrupt(@CorruptDataNotAligned, 'step5 unaligned data slot');
end;

procedure WStep6PathBeyondStrtab;
begin
  ExpectCorrupt(@CorruptPathBeyondStrtab, 'step6 path beyond strtab');
end;

procedure WStep7UnsortedIndex;
begin
  ExpectCorrupt(@CorruptUnsortedIndex, 'step7 unsorted/duplicate index');
end;

procedure WStep7NonCanonicalStored;
begin
  ExpectCorrupt(@CorruptNonCanonicalStored, 'step7 non-canonical stored path');
end;

procedure WStep8DigestOutOfRange;
begin
  ExpectCorrupt(@CorruptDigestOutOfRange, 'step8 digest out of range');
end;

procedure WStep5DataOverlapsIndex;
begin
  ExpectCorruptStep(@CorruptDataOverlapsIndex, 'step5 data overlaps index', 5);
end;

procedure WStep8DigestOverlapsData;
begin
  ExpectCorruptStep(@CorruptDigestOverlapsData, 'step8 digest overlaps data', 8);
end;

procedure WStep5HeaderHashedMismatch;
begin
  try
    CorruptHeaderHashedMismatch;
    Check(False, 'step5 header hash flag inconsistent (accepted!)');
  except
    on E: EResPackCorrupted do
    begin
      Check(E.Step = 5, 'step5 header hash flag inconsistent step=5');
      Check(Pos('header hash flag inconsistent', E.Message) > 0,
        'step5 header hash flag inconsistent message');
    end;
    on E: Exception do
      Check(False, 'step5 header hash flag inconsistent wrong class: ' + E.ClassName);
  end;
end;

{ 尾部多余字节不属于逻辑包：伪造记录指向 tail 时 ContentPtr/StoredPathSpanOf
  必须以 BlobTotal 为界拒绝（allo trailing 下合法条目仍可读）。 }
procedure TestTailBytesNotAddressable;
var
  B: TResPackBlob;
  Wide: TBytes;
  RP: TResPack;
  E, Forged: TResPackEntry;
  Got: Boolean;
begin
  BuildBase(B);
  try
    SetLength(Wide, B.Size + 16);
    Move(B.Data^, Wide[0], B.Size);
    FillChar(Wide[B.Size], 16, $AA);
    RP := ResPackOpen(@Wide[0], SizeUInt(Length(Wide)));
    Check(RP.Find('assets/app.js', E), 'valid entry still found with trailing bytes');
    Check(RP.ContentPtr(E) <> nil, 'valid content still addressable');
    Forged := E;
    Forged.DataOffset := UInt64(B.Size);
    Forged.Size := 4;
    Got := False;
    try
      RP.ContentPtr(Forged);
    except
      on E: EResPackCorrupted do Got := True;
      on E: Exception do ;
    end;
    Check(Got, 'tail data range rejected');
    Forged := E;
    Forged.PathOffset := UInt32(B.Size);
    Forged.PathLen := 4;
    Got := False;
    try
      RP.StoredPathSpanOf(Forged);
    except
      on E: EResPackCorrupted do Got := True;
      on E: Exception do ;
    end;
    Check(Got, 'tail path range rejected');
    RP.Close;
  finally
    ResPackFreeBlob(B);
  end;
end;

{ 哈希段回归：命中走哈希、失配回退二分、段损坏整包拒、digest 组合。
  段基址按 FORMAT 派生（无 digest 时为尾段：Total - 桶数×8，测试包无 digest）。 }
procedure BuildHashBase(out B: TResPackBlob);
var
  InA: array[0..1] of TResPackInputEntry;
  Opts: TResPackBuildOptions;
begin
  InA[0] := MakeInput('assets/app.js', 'console.log(1);');
  InA[1] := MakeInput('index.html', '<html>ok</html>');
  Opts := ResPackDefaultOptions;
  Opts.HashIndex := True;
  B := ResPackBuild(InA, Opts);
end;

procedure TestHashHitAndMissFallback;
var
  B: TResPackBlob;
  RP: TResPack;
  E: TResPackEntry;
  Got: Boolean;
begin
  BuildHashBase(B);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.HasHashIndex, 'hash pack exposes index');
    Check(RP.Find('index.html', E), 'hash hit found');
    Check(E.Size = 15, 'hash hit entry sane');
    Check(not RP.Find('nope.bin', E), 'hash miss falls back to False');
    Got := False;
    try
      RP.Stat('nope.bin');
    except
      on X: EResPackNotFound do Got := True;
      on X: Exception do ;
    end;
    Check(Got, 'hash miss stat raises not-found');
    RP.Close;
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestHashCorruptRejects;
var
  B: TResPackBlob;
  Wide: TBytes;
  RP: TResPack;
  Buckets: SizeUInt;
  Base: SizeUInt;
  I: SizeUInt;
  Idx: UInt32;
  Got: Boolean;
begin
  BuildHashBase(B);
  try
    Buckets := ResPackHashBucketCount(2);
    Base := B.Size - SizeUInt(Buckets) * 8;
    SetLength(Wide, B.Size);
    Move(B.Data^, Wide[0], B.Size);
    { 找首个非空桶，翻其 fnv 首字节：指纹必失配，指位仍界内 → step9 拒绝。 }
    I := 0;
    while I < Buckets do
    begin
      Idx := RdU32LE(@Wide[Base + I * 8 + 4]);
      if Idx <> UInt32($FFFFFFFF) then
        Break;
      Inc(I);
    end;
    Check(I < Buckets, 'hash pack has a non-empty bucket');
    Wide[Base + I * 8] := Wide[Base + I * 8] xor $FF;
    Got := False;
    try
      RP := ResPackOpen(@Wide[0], SizeUInt(Length(Wide)));
    except
      on X: EResPackCorrupted do Got := True;
      on X: Exception do ;
    end;
    Check(Got, 'corrupt hash section rejected');
  finally
    ResPackFreeBlob(B);
  end;
end;

{ 晚桶损坏仍拒绝：70 条目 256 桶，翻末个非空桶指纹（序号 ≥64，抽验盲区），
  Open 全量回验必须拒绝——锁定 INV-R2 无半信任，不以 Open 提速抽验。 }
procedure TestHashLateCorruptRejects;
const
  ENTRY_COUNT = 70;
var
  Inputs: array of TResPackInputEntry;
  B: TResPackBlob;
  Wide: TBytes;
  Opts: TResPackBuildOptions;
  RP: TResPack;
  Buckets: SizeUInt;
  Base: SizeUInt;
  I: SizeUInt;
  Ordinal: SizeUInt;
  Last: SizeUInt;
  Idx: UInt32;
  Got: Boolean;
begin
  SetLength(Inputs, ENTRY_COUNT);
  for I := 0 to ENTRY_COUNT - 1 do
    Inputs[I] := MakeInput('bulk/f' + Char(Ord('0') + (I div 10)) +
      Char(Ord('0') + (I mod 10)) + '.bin', 'payload');
  Opts := ResPackDefaultOptions;
  Opts.HashIndex := True;
  B := ResPackBuild(Inputs, Opts);
  try
    Buckets := ResPackHashBucketCount(ENTRY_COUNT);
    Base := B.Size - SizeUInt(Buckets) * 8;
    SetLength(Wide, B.Size);
    Move(B.Data^, Wide[0], B.Size);
    Ordinal := 0;
    Last := 0;
    for I := 0 to Buckets - 1 do
    begin
      Idx := RdU32LE(@Wide[Base + I * 8 + 4]);
      if Idx = UInt32($FFFFFFFF) then
        Continue;
      Inc(Ordinal);
      Last := I;
    end;
    Check(Ordinal = ENTRY_COUNT, 'hash pack holds seventy fingerprints');
    Check(Ordinal > 64, 'late bucket beyond spot-check range exists');
    Wide[Base + Last * 8] := Wide[Base + Last * 8] xor $FF;
    Got := False;
    try
      RP := ResPackOpen(@Wide[0], SizeUInt(Length(Wide)));
    except
      on X: EResPackCorrupted do Got := True;
      on X: Exception do ;
    end;
    Check(Got, 'late corrupt fingerprint rejected at open');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestHashWithDigest;
var
  InA: array[0..1] of TResPackInputEntry;
  Opts: TResPackBuildOptions;
  B: TResPackBlob;
  RP: TResPack;
  E: TResPackEntry;
begin
  InA[0] := MakeInput('assets/app.js', 'console.log(1);');
  InA[1] := MakeInput('index.html', '<html>ok</html>');
  Opts := ResPackDefaultOptions;
  Opts.HashIndex := True;
  Opts.DigestFunc :=
    procedure(const AData: PByte; const ASize: SizeUInt; const ADigestOut: PByte)
    var
      I: Integer;
    begin
      for I := 0 to RESPACK_DIGEST_SIZE - 1 do
        ADigestOut[I] := Byte($10 + I);
    end;
  B := ResPackBuild(InA, Opts);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.HasHashIndex and RP.HasDigests, 'digest+hash pack exposes both');
    Check(RP.Find('assets/app.js', E), 'digest+hash find works');
    RP.Close;
  finally
    ResPackFreeBlob(B);
  end;
end;

{ 非法查询一律 False（ValidSpan 预扫，不进入索引结构）。 }
procedure TestFindInvalidReturnsFalse;
var
  B: TResPackBlob;
  RP: TResPack;
  E: TResPackEntry;
begin
  BuildBase(B);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(not RP.Find('../zz', E), 'non-canonical query misses');
    Check(not RP.Find('', E), 'empty query misses');
    RP.Close;
  finally
    ResPackFreeBlob(B);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.respack.reader');
  T.Test('happy open/find/content', @TestHappyOpen);
  T.Test('stat miss raises not found', @TestStatMissRaises);
  T.Test('entry order and PathOf', @TestEntryAtOrderAndPathOf);
  T.Test('digest base opens and exposes digests', @DigestBaseOpensFine);
  T.Test('step1 bad magic', @WStep1BadMagic);
  T.Test('step2 bad version', @WStep2BadVersion);
  T.Test('step2 unknown header flag', @WStep2UnknownHeaderFlag);
  T.Test('step2 digest flag w/o offset', @WStep2DigestFlagNoOffset);
  T.Test('step3 index offset too small', @WStep3IndexOffsetTooSmall);
  T.Test('step3 index beyond blob', @WStep3IndexBeyondBlob);
  T.Test('step4 truncated buffer', @WStep4Truncated);
  T.Test('step5 reserved nonzero', @WStep5ReservedNonzero);
  T.Test('step5 unknown codecId', @WStep5UnknownCodec);
  T.Test('step5 unknown entry flag', @WStep5UnknownEntryFlag);
  T.Test('step5 empty path', @WStep5EmptyPath);
  T.Test('step5 unaligned data slot', @WStep5UnalignedSlot);
  T.Test('step6 path beyond strtab', @WStep6PathBeyondStrtab);
  T.Test('step7 unsorted/duplicate index', @WStep7UnsortedIndex);
  T.Test('step7 non-canonical stored path', @WStep7NonCanonicalStored);
  T.Test('step8 digest out of range', @WStep8DigestOutOfRange);
  T.Test('step5 data overlaps index (DataOffset=80)', @WStep5DataOverlapsIndex);
  T.Test('step8 digest overlaps data', @WStep8DigestOverlapsData);
  T.Test('step5 header HASHED inconsistent', @WStep5HeaderHashedMismatch);
  T.Test('BE header explicit LE roundtrip', @TestBEHeaderRoundTrip);
  T.Test('BE entry explicit LE roundtrip', @TestBEEntryRoundTrip);
  T.Test('tail bytes not addressable', @TestTailBytesNotAddressable);
  T.Test('hash hit and miss fallback', @TestHashHitAndMissFallback);
  T.Test('hash corrupt rejects', @TestHashCorruptRejects);
  T.Test('hash late corrupt rejects', @TestHashLateCorruptRejects);
  T.Test('hash with digest', @TestHashWithDigest);
  T.Test('find invalid returns false', @TestFindInvalidReturnsFalse);
  if not T.Run then Halt(1);
end.
