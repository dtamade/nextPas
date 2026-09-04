unit nextpas.core.git.native.index.parse;

{$I nextpas.core.settings.inc}

{ index 解析域: DIRC v2/v3/v4 解析 + 校验 + 文件读取.
  依赖: base (index.*) + L0-L1 owner + hash/cachetree. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.index.base;

function GitParseIndex(const AData: TBytes): TGitIndexFile;
function GitReadIndex(const AGitDir: string): TGitIndexFile;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.fs,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1,
  nextpas.core.git.native.cachetree;

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

end.
