program test_respack_reader;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.respack,
  nextpas.core.respack.base;

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
  if not T.Run then Halt(1);
end.
