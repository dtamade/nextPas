unit nextpas.core.git.native.index;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1,
  nextpas.core.git.native.base,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.write,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.cachetree;

{ Read/write support for the .git/index binary format (DIRC). Parsing
  covers versions 2, 3 and 4 including v4 prefix-compressed paths; the
  TREE cache-tree extension is parsed into the record, unknown uppercase
  extensions are skipped, mandatory lowercase extensions such as
  split-index "link" are refused because ignoring them would silently
  return wrong entries, and the trailing SHA-1 checksum is verified.
  Serialization re-emits a parsed TREE cache verbatim when present and
  stays extension-less otherwise (extensions are optional caches git
  rebuilds on demand). }

type
  TGitIndexEntry = record
    { stat data as stored by git — truncated to 32 bits per format }
    CTimeSec: Cardinal;
    CTimeNSec: Cardinal;
    MTimeSec: Cardinal;
    MTimeNSec: Cardinal;
    Dev: Cardinal;
    Ino: Cardinal;
    Mode: Cardinal;
    UID: Cardinal;
    GID: Cardinal;
    Size: Cardinal;
    Oid: TGitOid;
    Stage: Byte;
    AssumeValid: Boolean;
    SkipWorktree: Boolean;
    IntentToAdd: Boolean;
    Path: string;
  end;

  TGitIndexFile = record
    Version: Cardinal;
    Entries: array of TGitIndexEntry;
    { parsed TREE extension payload; HasCacheTree=False means absent }
    CacheTree: TGitCacheTree;
    HasCacheTree: Boolean;
  end;
  TGitIndexEntryArray = array of TGitIndexEntry;

function GitParseIndex(const AData: TBytes): TGitIndexFile;
function GitReadIndex(const AGitDir: string): TGitIndexFile;

{ Canonical index order: byte-compare paths, ties broken by ascending
  stage so conflict stages stay adjacent }
procedure GitSortIndexEntries(var AEntries: TGitIndexEntryArray);
function GitSerializeIndex(
  const AEntries: array of TGitIndexEntry;
  AVersion: Cardinal): TBytes;
{ Sorts in place (like GitWriteTree), then atomically replaces the index }
procedure GitWriteIndex(const AGitDir: string;
  var AEntries: TGitIndexEntryArray; AVersion: Cardinal);

{ derives the full valid cache-tree hierarchy from index entries (any
  order); a single non-stage-0 entry invalidates the whole root, which
  consumers treat as "recompute" — coarser than git's per-directory
  invalidation but equally safe }
function GitBuildIndexCacheTree(
  const AEntries: array of TGitIndexEntry): TGitCacheTree;

{ full-record variants: serialize/write preserving the TREE cache when
  the record carries one; extension-less otherwise }
function GitSerializeIndexFile(const AFile: TGitIndexFile): TBytes;
procedure GitWriteIndexFile(const AGitDir: string;
  var AFile: TGitIndexFile);

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary;

const
  CFixedV2 = 62;   // stat block (40) + oid (20) + flags (2)
  CFixedExt = 64;  // + extended flags word (v3/v4)
  CTrailerLen = GitOidRawLen;
  CModeTree = $4000;

procedure Need(const ALen, APos, ACount: SizeInt);
begin
  if (APos < 0) or (APos + ACount > ALen) then
    raise EGitError.Create('truncated index data');
end;

function Be16At(const AData: TBytes; const APos: SizeInt): Word; inline;
begin
  { perf: inline + single source via bytes.binary ReadUInt16BE (zero-copy PByte view), no manual shift branch, bounds via Need single source }
  Need(Length(AData), APos, 2);
  Result := ReadUInt16BE(PByte(@AData[APos]));
end;

function Be32At(const AData: TBytes; const APos: SizeInt): Cardinal; inline;
begin
  { perf: inline + single source via bytes.binary ReadUInt32BE (zero-copy PByte view), centralized endian, no duplicate shift }
  Need(Length(AData), APos, 4);
  Result := ReadUInt32BE(PByte(@AData[APos]));
end;

function SliceAt(const AData: TBytes; APos, ACount: SizeInt): TBytes; inline;
begin
  { perf: single source via bytes.ops SpanCopySlice (inline, single Move), zero-copy view via TByteSpan, replaces manual SetLength+Move }
  Need(Length(AData), APos, ACount);
  Result := SpanCopySlice(TByteSpan.FromBytes(AData), SizeUInt(APos), SizeUInt(ACount));
end;

function BytesRangeToString(const AData: TBytes; const AStart,
  ACount: SizeInt): string; inline;
begin
  { perf: single source via bytes.ops BytesSliceToString (single SetLength+Move via PByte/PChar), zero-copy slice view }
  Need(Length(AData), AStart, ACount);
  Result := BytesSliceToString(AData, SizeUInt(AStart), SizeUInt(ACount));
end;

{ Offset-encoding varint shared by pack OFS_DELTA headers and index v4
  path prefix strips — same git codec, different data source than
  TPackFile, hence a local copy over TBytes }
function ReadOffsetVarint(const AData: TBytes; var APos: SizeInt): Int64;
var
  B: Byte;
begin
  Need(Length(AData), APos, 1);
  B := AData[APos];
  Inc(APos);
  Result := B and $7F;
  while (B and $80) <> 0 do
  begin
    Need(Length(AData), APos, 1);
    B := AData[APos];
    Inc(APos);
    Result := ((Result + 1) shl 7) or Int64(B and $7F);
  end;
end;

procedure ParseEntryV23(const AData: TBytes; var APos: SizeInt;
  const AVersion: Cardinal; out AEntry: TGitIndexEntry);
var
  Len, FixedUsed, NameLen, PadLen: SizeInt;
  Flags, ExtFlags: Word;
  Q: SizeInt;
begin
  Len := Length(AData);
  Need(Len, APos, CFixedV2);
  AEntry.CTimeSec := Be32At(AData, APos);
  AEntry.CTimeNSec := Be32At(AData, APos + 4);
  AEntry.MTimeSec := Be32At(AData, APos + 8);
  AEntry.MTimeNSec := Be32At(AData, APos + 12);
  AEntry.Dev := Be32At(AData, APos + 16);
  AEntry.Ino := Be32At(AData, APos + 20);
  AEntry.Mode := Be32At(AData, APos + 24);
  AEntry.UID := Be32At(AData, APos + 28);
  AEntry.GID := Be32At(AData, APos + 32);
  AEntry.Size := Be32At(AData, APos + 36);
  { perf: single source OID copy via bytes.ops SpanCopy (inline, zero-copy TByteSpan view, single Move), replaces scattered Move 20B }
  SpanCopy(TByteSpan.Create(@AEntry.Oid.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AData[APos + 40], GitOidRawLen));
  Flags := Be16At(AData, APos + 60);
  AEntry.AssumeValid := (Flags and $8000) <> 0;
  AEntry.Stage := Byte((Flags shr 12) and $3);
  FixedUsed := CFixedV2;
  if (Flags and $4000) <> 0 then
  begin
    // extended flags word only exists from version 3 on
    if AVersion < 3 then
      raise EGitError.Create('extended entry flag in index version '
        + IntToStr(AVersion));
    Need(Len, APos + CFixedV2, 2);
    ExtFlags := Be16At(AData, APos + CFixedV2);
    AEntry.SkipWorktree := (ExtFlags and $4000) <> 0;
    AEntry.IntentToAdd := (ExtFlags and $2000) <> 0;
    FixedUsed := CFixedExt;
  end
  else
  begin
    AEntry.SkipWorktree := False;
    AEntry.IntentToAdd := False;
  end;
  NameLen := Flags and $FFF;
  if NameLen = $FFF then
  begin
    // long name: real length runs to the first NUL inside the pad area
    Q := APos + FixedUsed;
    while True do
    begin
      Need(Len, Q, 1);
      if AData[Q] = 0 then
        Break;
      Inc(Q);
    end;
    NameLen := Q - (APos + FixedUsed);
  end;
  Need(Len, APos + FixedUsed, NameLen);
  AEntry.Path := BytesRangeToString(AData, APos + FixedUsed, NameLen);
  // entries are padded with at least one NUL up to a multiple of eight
  PadLen := ((FixedUsed + NameLen + 8) and (not 7))
    - FixedUsed - NameLen;
  APos := APos + FixedUsed + NameLen + PadLen;
end;

procedure ParseEntryV4(const AData: TBytes; var APos: SizeInt;
  var APrevPath: string; out AEntry: TGitIndexEntry);
var
  Len, FixedUsed, StripN, SuffixLen: SizeInt;
  Q: SizeInt;
  Flags: Word;
  Suffix: string;
begin
  Len := Length(AData);
  Need(Len, APos, CFixedV2);
  AEntry.CTimeSec := Be32At(AData, APos);
  AEntry.CTimeNSec := Be32At(AData, APos + 4);
  AEntry.MTimeSec := Be32At(AData, APos + 8);
  AEntry.MTimeNSec := Be32At(AData, APos + 12);
  AEntry.Dev := Be32At(AData, APos + 16);
  AEntry.Ino := Be32At(AData, APos + 20);
  AEntry.Mode := Be32At(AData, APos + 24);
  AEntry.UID := Be32At(AData, APos + 28);
  AEntry.GID := Be32At(AData, APos + 32);
  AEntry.Size := Be32At(AData, APos + 36);
  { perf: single source OID copy via bytes.ops SpanCopy (inline, zero-copy TByteSpan, single Move) }
  SpanCopy(TByteSpan.Create(@AEntry.Oid.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AData[APos + 40], GitOidRawLen));
  Flags := Be16At(AData, APos + 60);
  AEntry.AssumeValid := (Flags and $8000) <> 0;
  AEntry.Stage := Byte((Flags shr 12) and $3);
  // v4 keeps the v3 extended-flags word (e.g. intent-to-add entries)
  FixedUsed := CFixedV2;
  if (Flags and $4000) <> 0 then
  begin
    Need(Len, APos + CFixedV2, 2);
    AEntry.SkipWorktree :=
      (Be16At(AData, APos + CFixedV2) and $4000) <> 0;
    AEntry.IntentToAdd :=
      (Be16At(AData, APos + CFixedV2) and $2000) <> 0;
    FixedUsed := CFixedExt;
  end
  else
  begin
    AEntry.SkipWorktree := False;
    AEntry.IntentToAdd := False;
  end;
  APos := APos + FixedUsed;
  StripN := Integer(ReadOffsetVarint(AData, APos));
  if StripN > Length(APrevPath) then
    raise EGitError.Create('corrupt v4 index entry: strip exceeds prev');
  Q := APos;
  while True do
  begin
    Need(Len, Q, 1);
    if AData[Q] = 0 then
      Break;
    Inc(Q);
  end;
  SuffixLen := Q - APos;
  Suffix := BytesRangeToString(AData, APos, SuffixLen);
  AEntry.Path := Copy(APrevPath, 1, Length(APrevPath) - StripN) + Suffix;
  // v4 entries carry no padding
  APos := Q + 1;
  APrevPath := AEntry.Path;
end;

procedure VerifyChecksum(const AData: TBytes);
var
  H: IHasher;
  Got: TGitOid;
  LSum: TBytes;
begin
  { perf: single source OID via bytes.ops SpanEqual/SpanCopy (inline, zero-copy TByteSpan view, ~3×QWord MemEqual), replaces byte loop + scattered Move }
  H := NewSHA1;
  H.Write(AData[0], SizeUInt(Length(AData) - CTrailerLen));
  LSum := H.SumBytes;
  SpanCopy(TByteSpan.Create(@Got.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@LSum[0], GitOidRawLen));
  if not SpanEqual(TByteSpan.Create(@Got.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AData[Length(AData) - CTrailerLen], GitOidRawLen)) then
    raise EGitError.Create('index checksum mismatch');
end;

function GitParseIndex(const AData: TBytes): TGitIndexFile;
var
  Len, P: SizeInt;
  EntryCount, I: Integer;
  PrevPath, Sig: string;
  ExtSize: Cardinal;
begin
  Len := Length(AData);
  if Len < 12 + CTrailerLen then
    raise EGitError.Create('index too short');
  if (AData[0] <> $44) or (AData[1] <> $49)
    or (AData[2] <> $52) or (AData[3] <> $43) then
    raise EGitError.Create('bad index signature');
  Result.Version := Be32At(AData, 4);
  if not (Result.Version in [2, 3, 4]) then
    raise EGitError.CreateFmt('unsupported index version %d',
      [Result.Version]);
  EntryCount := Integer(Be32At(AData, 8));
  if EntryCount < 0 then
    raise EGitError.Create('corrupt index entry count');

  SetLength(Result.Entries, EntryCount);
  P := 12;
  PrevPath := '';
  for I := 0 to EntryCount - 1 do
  begin
    if Result.Version = 4 then
      ParseEntryV4(AData, P, PrevPath, Result.Entries[I])
    else
      ParseEntryV23(AData, P, Result.Version, Result.Entries[I]);
  end;

  // extensions live between the last entry and the checksum trailer
  while P < Len - CTrailerLen do
  begin
    Need(Len, P, 8);
    Sig := Chr(AData[P]) + Chr(AData[P + 1]) + Chr(AData[P + 2])
      + Chr(AData[P + 3]);
    ExtSize := Be32At(AData, P + 4);
    if Sig = 'TREE' then
    begin
      // optional cache: parse into the record instead of skipping
      Need(Len, P, 8 + SizeInt(ExtSize));
      Result.CacheTree := GitParseCacheTree(
        SliceAt(AData, P + 8, SizeInt(ExtSize)));
      Result.HasCacheTree := True;
    end
    else if not (AData[P] in [Ord('A')..Ord('Z')]) then
      // uppercase signatures are optional and skippable; lowercase ones
      // (split-index "link", sparse "sdir") change entry semantics and
      // must not be silently ignored
      raise EGitError.CreateFmt(
        'unsupported mandatory index extension "%s"', [Sig])
    else
      Need(Len, P, 8 + SizeInt(ExtSize));
    P := P + 8 + SizeInt(ExtSize);
  end;
  if P <> Len - CTrailerLen then
    raise EGitError.Create('truncated index extension block');

  VerifyChecksum(AData);
end;

function GitReadIndex(const AGitDir: string): TGitIndexFile;
begin
  Result := GitParseIndex(ReadFile(PathJoin([AGitDir, 'index'])));
end;

{ ── write side ───────────────────────────────────────────────────────────── }

procedure Put16(var ABuf: TBytes; const APos: SizeInt; AValue: Word); inline;
begin
  { perf: inline + single source via bytes.binary WriteUInt16BE (zero-copy PByte, single 2-byte store) }
  WriteUInt16BE(PByte(@ABuf[APos]), AValue);
end;

procedure Put32(var ABuf: TBytes; const APos: SizeInt; AValue: Cardinal); inline;
begin
  { perf: inline + single source via bytes.binary WriteUInt32BE (zero-copy PByte, single 4-byte store) }
  WriteUInt32BE(PByte(@ABuf[APos]), AValue);
end;

{ Inverse of ReadOffsetVarint — the git offset encoding used by pack
  OFS_DELTA and index v4 prefix strips }
procedure WriteOffsetVarint(var ABuf: TBytes; var APos: SizeInt;
  AValue: Int64);
var
  Start, N: SizeInt;
  I: Int64;
begin
  if AValue < 0 then
    raise EGitError.Create('negative varint value');
  // byte count: strip 7 bits per level, compensating the decoder's +1
  N := 1;
  I := AValue;
  while I >= 128 do
  begin
    I := (I shr 7) - 1;
    Inc(N);
  end;
  Start := APos;
  APos := APos + N;
  I := AValue;
  ABuf[Start + N - 1] := Byte(I and $7F);
  while I >= 128 do
  begin
    I := (I shr 7) - 1;
    Dec(N);
    ABuf[Start + N - 1] := Byte($80 or (I and $7F));
  end;
end;

function OffsetVarintEncodedLen(AValue: Int64): Integer;
begin
  if AValue < 0 then
    raise EGitError.Create('negative varint value');
  Result := 1;
  while AValue >= 128 do
  begin
    AValue := (AValue shr 7) - 1;
    Inc(Result);
  end;
end;

function CommonPrefixLen(const AA, AB: string): SizeInt;
var
  MinLen: SizeInt;
begin
  Result := 0;
  if Length(AA) < Length(AB) then
    MinLen := Length(AA)
  else
    MinLen := Length(AB);
  while Result < MinLen do
    if AA[Result + 1] <> AB[Result + 1] then
      Exit
    else
      Inc(Result);
end;

function IndexEntryCompare(const AA, AB: TGitIndexEntry): Integer;
var
  I, MinLen: SizeInt;
begin
  Result := 0;
  if Length(AA.Path) < Length(AB.Path) then
    MinLen := Length(AA.Path)
  else
    MinLen := Length(AB.Path);
  for I := 1 to MinLen do
  begin
    if Ord(AA.Path[I]) < Ord(AB.Path[I]) then
      Exit(-1);
    if Ord(AA.Path[I]) > Ord(AB.Path[I]) then
      Exit(1);
  end;
  if Length(AA.Path) <> Length(AB.Path) then
    Exit(SizeInt(Length(AA.Path) - Length(AB.Path)));
  if AA.Stage < AB.Stage then
    Exit(-1);
  if AA.Stage > AB.Stage then
    Exit(1);
end;

procedure GitSortIndexEntries(var AEntries: TGitIndexEntryArray);
var
  StackLo, StackHi: array[0..63] of Integer;
  Top, Lo, Hi, Mid, I, J: Integer;
  Pivot: TGitIndexEntry;
  Tmp: TGitIndexEntry;
  procedure SwapIdx(A, B: Integer); inline;
  begin
    if A = B then Exit;
    Tmp := AEntries[A];
    AEntries[A] := AEntries[B];
    AEntries[B] := Tmp;
  end;
  procedure InsertionSort(ALo, AHi: Integer); inline;
  var
    II, JJ: Integer;
    Key: TGitIndexEntry;
  begin
    for II := ALo + 1 to AHi do
    begin
      Key := AEntries[II];
      JJ := II - 1;
      while (JJ >= ALo) and (IndexEntryCompare(AEntries[JJ], Key) > 0) do
      begin
        AEntries[JJ + 1] := AEntries[JJ];
        Dec(JJ);
      end;
      AEntries[JJ + 1] := Key;
    end;
  end;
begin
  if Length(AEntries) < 2 then
    Exit;
  // perf: in-place introsort (median-of-3 quicksort + insertion, O(1) extra, zero heap Temp), single-source IndexEntryCompare, inline Swap/InsertionSort, no 2N doubling
  Top := 0;
  StackLo[0] := 0;
  StackHi[0] := High(AEntries);
  while Top >= 0 do
  begin
    Lo := StackLo[Top];
    Hi := StackHi[Top];
    Dec(Top);
    if Lo >= Hi then Continue;
    if (Hi - Lo) < 16 then
    begin
      InsertionSort(Lo, Hi);
      Continue;
    end;
    Mid := (Lo + Hi) shr 1;
    if IndexEntryCompare(AEntries[Lo], AEntries[Mid]) > 0 then SwapIdx(Lo, Mid);
    if IndexEntryCompare(AEntries[Lo], AEntries[Hi]) > 0 then SwapIdx(Lo, Hi);
    if IndexEntryCompare(AEntries[Mid], AEntries[Hi]) > 0 then SwapIdx(Mid, Hi);
    SwapIdx(Mid, Hi - 1);
    Pivot := AEntries[Hi - 1];
    I := Lo;
    J := Hi - 1;
    while True do
    begin
      repeat Inc(I); until IndexEntryCompare(AEntries[I], Pivot) >= 0;
      repeat Dec(J); until IndexEntryCompare(AEntries[J], Pivot) <= 0;
      if I >= J then Break;
      SwapIdx(I, J);
    end;
    SwapIdx(I, Hi - 1);
    // push larger partition first to bound stack depth log2 N
    if (I - 1 - Lo) > (Hi - (I + 1)) then
    begin
      if Lo < I - 1 then
      begin
        Inc(Top);
        StackLo[Top] := Lo;
        StackHi[Top] := I - 1;
      end;
      if I + 1 < Hi then
      begin
        Inc(Top);
        StackLo[Top] := I + 1;
        StackHi[Top] := Hi;
      end;
    end
    else
    begin
      if I + 1 < Hi then
      begin
        Inc(Top);
        StackLo[Top] := I + 1;
        StackHi[Top] := Hi;
      end;
      if Lo < I - 1 then
      begin
        Inc(Top);
        StackLo[Top] := Lo;
        StackHi[Top] := I - 1;
      end;
    end;
  end;
end;

procedure CheckSerializableEntry(const AEntry: TGitIndexEntry;
  AVersion: Cardinal);
begin
  if AEntry.Path = '' then
    raise EGitError.Create('index entry path must not be empty');
  if AEntry.Stage > 3 then
    raise EGitError.CreateFmt('index entry stage %d out of range',
      [AEntry.Stage]);
  if (AEntry.SkipWorktree or AEntry.IntentToAdd) and (AVersion < 3) then
    raise EGitError.Create(
      'extended entry flags require index version 3 or later');
end;

{ fixed-part size including the optional extended-flags word }
function EntryFixedLen(const AEntry: TGitIndexEntry): SizeInt;
begin
  if AEntry.SkipWorktree or AEntry.IntentToAdd then
    Result := CFixedExt
  else
    Result := CFixedV2;
end;

function FlagsWordFor(const AEntry: TGitIndexEntry): Word;
var
  NameField: SizeInt;
begin
  // names at or past 4095 bytes carry $FFF and are NUL-scanned on read
  NameField := Length(AEntry.Path);
  if NameField >= $FFF then
    NameField := $FFF;
  Result := Word((Ord(AEntry.AssumeValid) shl 15)
    or (Ord(AEntry.SkipWorktree or AEntry.IntentToAdd) shl 14)
    or (Word(AEntry.Stage) shl 12)
    or Word(NameField));
end;

procedure FillFixedFields(var ABuf: TBytes; APos: SizeInt;
  const AEntry: TGitIndexEntry);
begin
  Put32(ABuf, APos, AEntry.CTimeSec);
  Put32(ABuf, APos + 4, AEntry.CTimeNSec);
  Put32(ABuf, APos + 8, AEntry.MTimeSec);
  Put32(ABuf, APos + 12, AEntry.MTimeNSec);
  Put32(ABuf, APos + 16, AEntry.Dev);
  Put32(ABuf, APos + 20, AEntry.Ino);
  Put32(ABuf, APos + 24, AEntry.Mode);
  Put32(ABuf, APos + 28, AEntry.UID);
  Put32(ABuf, APos + 32, AEntry.GID);
  Put32(ABuf, APos + 36, AEntry.Size);
  { perf: single source OID copy via bytes.ops SpanCopy (inline, zero-copy TByteSpan, single Move) }
  SpanCopy(TByteSpan.Create(@ABuf[APos + 40], GitOidRawLen),
    TByteSpan.Create(@AEntry.Oid.Bytes[0], GitOidRawLen));
  Put16(ABuf, APos + 60, FlagsWordFor(AEntry));
  if AEntry.SkipWorktree or AEntry.IntentToAdd then
    Put16(ABuf, APos + 62,
      Word((Ord(AEntry.SkipWorktree) shl 14)
        or (Ord(AEntry.IntentToAdd) shl 13)));
end;

function GitSerializeIndex(const AEntries: array of TGitIndexEntry;
  AVersion: Cardinal): TBytes;
var
  Total, P, I, EntSize, Common: SizeInt;
  PrevPath: string;
  H: IHasher;
  LSum: TBytes;
begin
  if not (AVersion in [2, 3, 4]) then
    raise EGitError.CreateFmt('unsupported index version %d', [AVersion]);

  // managed function results are not guaranteed cleared on entry
  Result := nil;

  // exact size pass (v4 strip counts depend on each previous path)
  Total := 12 + CTrailerLen;
  PrevPath := '';
  for I := 0 to High(AEntries) do
  begin
    CheckSerializableEntry(AEntries[I], AVersion);
    if AVersion = 4 then
    begin
      Common := CommonPrefixLen(PrevPath, AEntries[I].Path);
      Total := Total + EntryFixedLen(AEntries[I])
        + OffsetVarintEncodedLen(Length(PrevPath) - Common)
        + Length(AEntries[I].Path) - Common + 1;
    end
    else
      Total := Total + ((EntryFixedLen(AEntries[I])
        + Length(AEntries[I].Path) + 8) and (not 7));
    PrevPath := AEntries[I].Path;
  end;

  SetLength(Result, Total);
  Result[0] := $44;  // 'D'
  Result[1] := $49;  // 'I'
  Result[2] := $52;  // 'R'
  Result[3] := $43;  // 'C'
  Put32(Result, 4, AVersion);
  Put32(Result, 8, Cardinal(Length(AEntries)));

  P := 12;
  PrevPath := '';
  for I := 0 to High(AEntries) do
  begin
    FillFixedFields(Result, P, AEntries[I]);
    EntSize := EntryFixedLen(AEntries[I]);
    P := P + EntSize;
    if AVersion = 4 then
    begin
      Common := CommonPrefixLen(PrevPath, AEntries[I].Path);
      WriteOffsetVarint(Result, P, Length(PrevPath) - Common);
      if Common < Length(AEntries[I].Path) then
      begin
        { perf: single source via bytes.ops SpanCopy (inline, zero-copy TByteSpan view, single Move, no indexed var for untyped param per red line 1) }
        SpanCopy(TByteSpan.Create(PByte(@Result[P]), SizeUInt(Length(AEntries[I].Path) - Common)),
          TByteSpan.Create(PByte(@AEntries[I].Path[Common + 1]), SizeUInt(Length(AEntries[I].Path) - Common)));
      end;
      P := P + Length(AEntries[I].Path) - Common;
      Result[P] := 0;
      Inc(P);
    end
    else
    begin
      // name plus padding only — the fixed part is already advanced past
      EntSize := ((EntSize + Length(AEntries[I].Path) + 8) and (not 7))
        - EntSize;
      { perf: single source via bytes.ops SpanCopy (inline, zero-copy TByteSpan view, single Move, no indexed var for untyped param per red line 1) }
      SpanCopy(TByteSpan.Create(PByte(@Result[P]), SizeUInt(Length(AEntries[I].Path))),
        TByteSpan.Create(PByte(@AEntries[I].Path[1]), SizeUInt(Length(AEntries[I].Path))));
      // padding bytes are already zeroed by the allocation above
      P := P + EntSize;
    end;
    PrevPath := AEntries[I].Path;
  end;
  if P <> Total - CTrailerLen then
    raise EGitError.Create('internal: index size calculation drifted');

  H := NewSHA1;
  H.Write(Result[0], SizeUInt(Total - CTrailerLen));
  { perf: single source OID via bytes.ops SpanCopy (inline, zero-copy TByteSpan, single Move), stable LSum temp keeps refcount }
  LSum := H.SumBytes;
  SpanCopy(TByteSpan.Create(@Result[Total - CTrailerLen], GitOidRawLen),
    TByteSpan.Create(@LSum[0], GitOidRawLen));
end;

procedure GitWriteIndex(const AGitDir: string;
  var AEntries: TGitIndexEntryArray; AVersion: Cardinal);
begin
  GitSortIndexEntries(AEntries);
  WriteAtomic(PathJoin([AGitDir, 'index']),
    GitSerializeIndex(AEntries, AVersion), PermDefault);
end;

{ ── TREE cache-tree derivation ──────────────────────────────────────────── }

function FirstSlashPos(const AText: string): SizeInt;
var
  I: SizeInt;
begin
  Result := 0;
  for I := 1 to Length(AText) do
    if AText[I] = '/' then
      Exit(I);
end;

{ builds one level of the hierarchy over the canonical-order run
  [ALo..AHi], all paths starting with APrefix }
procedure BuildRange(var AList: TGitIndexEntryArray; ALo, AHi: SizeInt;
  const APrefix: string; out ATree: TGitCacheTree);
var
  Direct, All: TGitTreeEntryArray;
  DirectCount, DirectCap, AllCount, AllCap, ChildrenCount, ChildrenCap: SizeUInt;
  PrefixLen, I, GroupEnd, SlashPos: SizeInt;
  Rest, ChildName, ChildPrefix: string;
begin
  ATree := Default(TGitCacheTree);
  Direct := nil;
  DirectCount := 0;
  DirectCap := 0;
  ChildrenCount := 0;
  ChildrenCap := 0;
  { perf: amortized geometric growth via bytes.ops GrowArrayCapacity (single source, BYTES_BUILDER_MIN_GROW + *2), avoids O(n²) SetLength(Length+1) churn, single shrink at end; zero-copy Oid record Move }
  PrefixLen := Length(APrefix);
  I := ALo;
  while I <= AHi do
  begin
    Rest := Copy(AList[I].Path, PrefixLen + 1, MaxInt);
    SlashPos := FirstSlashPos(Rest);
    if SlashPos = 0 then
    begin
      // plain blob/symlink/gitlink at this level
      if DirectCount >= DirectCap then
      begin
        DirectCap := GrowArrayCapacity(DirectCap, DirectCount + 1);
        SetLength(Direct, DirectCap);
      end;
      Direct[DirectCount].Mode := AList[I].Mode;
      Direct[DirectCount].Name := Rest;
      Direct[DirectCount].Oid := AList[I].Oid;
      Inc(DirectCount);
      Inc(ATree.EntryCount);
      Inc(I);
    end
    else
    begin
      // canonical order keeps the whole child subtree contiguous
      ChildName := Copy(Rest, 1, SlashPos - 1);
      ChildPrefix := APrefix + ChildName + '/';
      GroupEnd := I;
      while (GroupEnd <= AHi)
        and (Copy(AList[GroupEnd].Path, 1, Length(ChildPrefix))
          = ChildPrefix) do
        Inc(GroupEnd);
      if ChildrenCount >= ChildrenCap then
      begin
        ChildrenCap := GrowArrayCapacity(ChildrenCap, ChildrenCount + 1);
        SetLength(ATree.Children, ChildrenCap);
      end;
      BuildRange(AList, I, GroupEnd - 1, ChildPrefix,
        ATree.Children[ChildrenCount]);
      // Default() inside the recursion wipes the field, so name last
      ATree.Children[ChildrenCount].Name := ChildName;
      Inc(ChildrenCount);
      Inc(ATree.EntryCount, ATree.Children[ChildrenCount - 1].EntryCount);
      I := GroupEnd;
    end;
  end;
  if SizeUInt(Length(Direct)) <> DirectCount then
    SetLength(Direct, DirectCount);
  if SizeUInt(Length(ATree.Children)) <> ChildrenCount then
    SetLength(ATree.Children, ChildrenCount);

  All := Direct;
  AllCount := DirectCount;
  AllCap := AllCount;
  for I := 0 to High(ATree.Children) do
  begin
    if AllCount >= AllCap then
    begin
      AllCap := GrowArrayCapacity(AllCap, AllCount + 1);
      SetLength(All, AllCap);
    end;
    All[AllCount].Mode := CModeTree;
    All[AllCount].Name := ATree.Children[I].Name;
    All[AllCount].Oid := ATree.Children[I].Oid;
    Inc(AllCount);
  end;
  if SizeUInt(Length(All)) <> AllCount then
    SetLength(All, AllCount);
  GitSortTreeEntries(All);
  ATree.Oid := GitHashObject(gokTree, GitSerializeTree(All));
end;

function GitBuildIndexCacheTree(
  const AEntries: array of TGitIndexEntry): TGitCacheTree;
var
  List: TGitIndexEntryArray;
  I: SizeInt;
begin
  Result := Default(TGitCacheTree);
  SetLength(List, Length(AEntries));
  for I := 0 to High(AEntries) do
    List[I] := AEntries[I];
  GitSortIndexEntries(List);

  // any conflict invalidates the whole cache; consumers recompute
  for I := 0 to High(List) do
    if List[I].Stage <> 0 then
    begin
      Result.EntryCount := -1;
      Exit;
    end;

  BuildRange(List, 0, High(List), '', Result);
end;

{ ── full-record serialization with optional TREE extension ─────────────── }

function GitSerializeIndexFile(const AFile: TGitIndexFile): TBytes;
var
  Base, ExtData: TBytes;
  BaseLen, NewTotal, ExtLen, P: SizeInt;
  Hasher: IHasher;
  LSum: TBytes;
begin
  Base := GitSerializeIndex(AFile.Entries, AFile.Version);
  if not AFile.HasCacheTree then
    Exit(Base);

  ExtData := GitSerializeCacheTree(AFile.CacheTree);
  BaseLen := Length(Base);
  ExtLen := 8 + Length(ExtData);
  NewTotal := BaseLen + ExtLen;

  // splice the extension in front of the base checksum, then reseal
  SetLength(Result, NewTotal);
  { perf: single source via bytes.ops SpanCopy (inline, zero-copy TByteSpan PByte+Len view, single Move), centralized EOutOfRange vs scattered Move }
  if BaseLen > CTrailerLen then
    SpanCopy(TByteSpan.Create(PByte(@Result[0]), SizeUInt(BaseLen - CTrailerLen)),
      TByteSpan.Create(PByte(@Base[0]), SizeUInt(BaseLen - CTrailerLen)));
  P := BaseLen - CTrailerLen;
  Result[P] := Ord('T');
  Result[P + 1] := Ord('R');
  Result[P + 2] := Ord('E');
  Result[P + 3] := Ord('E');
  Put32(Result, P + 4, Cardinal(Length(ExtData)));
  if Length(ExtData) > 0 then
    SpanCopy(TByteSpan.Create(PByte(@Result[P + 8]), SizeUInt(Length(ExtData))),
      TByteSpan.Create(PByte(@ExtData[0]), SizeUInt(Length(ExtData))));

  Hasher := NewSHA1;
  Hasher.Write(Result[0], SizeUInt(NewTotal - CTrailerLen));
  { perf: single source OID via bytes.ops SpanCopy (inline, zero-copy TByteSpan, single Move), stable LSum }
  LSum := Hasher.SumBytes;
  SpanCopy(TByteSpan.Create(@Result[NewTotal - CTrailerLen], GitOidRawLen),
    TByteSpan.Create(@LSum[0], GitOidRawLen));
end;

procedure GitWriteIndexFile(const AGitDir: string;
  var AFile: TGitIndexFile);
begin
  GitSortIndexEntries(AFile.Entries);
  WriteAtomic(PathJoin([AGitDir, 'index']),
    GitSerializeIndexFile(AFile), PermDefault);
end;

end.
