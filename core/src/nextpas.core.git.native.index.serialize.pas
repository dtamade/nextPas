unit nextpas.core.git.native.index.serialize;

{$I nextpas.core.settings.inc}

{ index 序列化域: 规范排序 + DIRC 发射 + 原子落盘.
  依赖: base (index.*) + L0-L1 owner + hash/write. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.index.base;

{ Canonical index order: byte-compare paths, ties broken by ascending
  stage so conflict stages stay adjacent }
procedure GitSortIndexEntries(var AEntries: TGitIndexEntryArray);
procedure Put32(var ABuf: TBytes; const APos: SizeInt; AValue: Cardinal); inline;
function GitSerializeIndex(
  const AEntries: array of TGitIndexEntry;
  AVersion: Cardinal): TBytes;
{ Sorts in place (like GitWriteTree), then atomically replaces the index }
procedure GitWriteIndex(const AGitDir: string;
  var AEntries: TGitIndexEntryArray; AVersion: Cardinal);

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.fs,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1,
  nextpas.core.git.native.base,
  nextpas.core.git.native.write;

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

end.
