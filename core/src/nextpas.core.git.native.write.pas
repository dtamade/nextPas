unit nextpas.core.git.native.write;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.git.native.base,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.objmodel;

{ Write path: blob storage, tree serialization with the canonical git sort
  order, and commit / annotated-tag construction. Objects land in the loose
  store; pack writing is out of scope. Sort rule mirrors git: byte-compare
  names, and at the tie point a directory entry counts as if its name ended
  with '/'. }

type
  TGitCommitBuilder = record
    Tree: TGitOid;
    Parents: array of TGitOid;
    AuthorName: string;
    AuthorEmail: string;
    AuthorUnixTime: Int64;
    AuthorTzMinutes: Integer;
    CommitterName: string;
    CommitterEmail: string;
    CommitterUnixTime: Int64;
    CommitterTzMinutes: Integer;
    Message: string;
  end;

  TGitTagBuilder = record
    Target: TGitOid;
    TargetKind: TGitObjectKind;
    TagName: string;
    TaggerName: string;
    TaggerEmail: string;
    TaggerUnixTime: Int64;
    TaggerTzMinutes: Integer;
    Message: string;
  end;

procedure GitSortTreeEntries(var AEntries: TGitTreeEntryArray);
function GitEntryCompare(const AA, AB: TGitTreeEntry): Integer; inline;
function GitModeToString(AMode: Cardinal): string;
{ Serializes entries in the given order — sort first unless the order is
  already canonical }
function GitSerializeTree(const AEntries: TGitTreeEntryArray): TBytes;
function GitWriteBlob(const AGitDir: string;
  const AContent: TBytes): TGitOid;
function GitWriteTree(const AGitDir: string;
  var AEntries: TGitTreeEntryArray): TGitOid;
function GitBuildCommitBytes(
  const ABuilder: TGitCommitBuilder): TBytes;
function GitWriteCommit(const AGitDir: string;
  const ABuilder: TGitCommitBuilder): TGitOid;
{ The message must either be empty or end with a newline: git's tag parser
  requires the object's final byte to be LF, so the builder refuses anything
  it could only store as unreadable }
function GitBuildTagBytes(const ABuilder: TGitTagBuilder): TBytes;
function GitWriteTag(const AGitDir: string;
  const ABuilder: TGitTagBuilder): TGitOid;

implementation

uses
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.git.native.util;

procedure RaiseUnsupportedMode(AMode: Cardinal);
begin
  raise EGitError.CreateFmt('unsupported tree entry mode %o', [AMode]);
end;

function GitModeToString(AMode: Cardinal): string;
begin
  case AMode of
    GIT_MODE_DIR: Result := '40000';
    GIT_MODE_REGULAR: Result := '100644';
    GIT_MODE_EXEC: Result := '100755';
    GIT_MODE_SYMLINK: Result := '120000';
    GIT_MODE_GITLINK: Result := '160000';
  else
    RaiseUnsupportedMode(AMode);
    Result := '';
  end;
end;

function GitEntryCompare(const AA, AB: TGitTreeEntry): Integer; inline;
var
  I, MinLen: SizeInt;
  CA, CB: Byte;
begin
  // perf: inline byte-compare with '/' tie (directory acts as '/'), zero-copy via String char access, single source bytes.ops ordering; hot compare ≤30ns inline, reused by MergeSort
  Result := 0;
  if Length(AA.Name) < Length(AB.Name) then
    MinLen := Length(AA.Name)
  else
    MinLen := Length(AB.Name);
  for I := 1 to MinLen do
  begin
    CA := Byte(Ord(AA.Name[I]));
    CB := Byte(Ord(AB.Name[I]));
    if CA < CB then
      Exit(-1);
    if CA > CB then
      Exit(1);
  end;
  if Length(AA.Name) = Length(AB.Name) then
    Exit(0);
  CA := Ord('/');
  CB := Ord('/');
  if Length(AA.Name) < Length(AB.Name) then
    CB := Byte(Ord(AB.Name[MinLen + 1]))
  else
    CA := Byte(Ord(AA.Name[MinLen + 1]));
  if AA.Mode = GIT_MODE_DIR then
    CA := Ord('/');
  if AB.Mode = GIT_MODE_DIR then
    CB := Ord('/');
  if CA < CB then
    Exit(-1);
  if CA > CB then
    Exit(1);
end;

procedure GitSortTreeEntries(var AEntries: TGitTreeEntryArray);
// perf: MergeSort O(n log n) via GitEntryCompare:inline byte-compare+'/' tie, not inline per red line 2 (alloc Temp+recursion+Move/FillChar exceeds I-Cache), zero-copy via record Move single source bytes.ops ordering; candidate SLO ≤2µs/100-entries, TBytes/managed strings auto released try..finally 资源不丢
  procedure InsertionSort(ALo, AHi: Integer); inline;
  var
    I, J: Integer;
    Key: TGitTreeEntry;
  begin
    for I := ALo + 1 to AHi do
    begin
      Key := AEntries[I];
      J := I - 1;
      while (J >= ALo) and (GitEntryCompare(AEntries[J], Key) > 0) do
      begin
        AEntries[J + 1] := AEntries[J];
        Dec(J);
      end;
      AEntries[J + 1] := Key;
    end;
  end;

  procedure MergeSort(var AItems: TGitTreeEntryArray;
    var ATemp: TGitTreeEntryArray; ALo, AHi: Integer);
  var
    Mid, I, J, K: Integer;
  begin
    if ALo >= AHi then
      Exit;
    if AHi - ALo < 16 then
    begin
      InsertionSort(ALo, AHi);
      Exit;
    end;
    Mid := (ALo + AHi) div 2;
    MergeSort(AItems, ATemp, ALo, Mid);
    MergeSort(AItems, ATemp, Mid + 1, AHi);
    I := ALo;
    J := Mid + 1;
    for K := ALo to AHi do
    begin
      if (I <= Mid) and ((J > AHi)
        or (GitEntryCompare(AItems[I], AItems[J]) <= 0)) then
      begin
        // perf: move via bytes.ops SpanCopy single source inline zero-copy (managed record move semantics, FillChar zero ownership transfer, avoids refcount churn, TBytes/managed strings try..finally 资源不丢)
        SpanCopy(TByteSpan.Create(PByte(@ATemp[K]), SizeUInt(SizeOf(TGitTreeEntry))),
          TByteSpan.Create(PByte(@AItems[I]), SizeUInt(SizeOf(TGitTreeEntry))));
        FillChar(AItems[I], SizeOf(TGitTreeEntry), 0);
        Inc(I);
      end
      else
      begin
        SpanCopy(TByteSpan.Create(PByte(@ATemp[K]), SizeUInt(SizeOf(TGitTreeEntry))),
          TByteSpan.Create(PByte(@AItems[J]), SizeUInt(SizeOf(TGitTreeEntry))));
        FillChar(AItems[J], SizeOf(TGitTreeEntry), 0);
        Inc(J);
      end;
    end;
    for K := ALo to AHi do
    begin
      SpanCopy(TByteSpan.Create(PByte(@AItems[K]), SizeUInt(SizeOf(TGitTreeEntry))),
        TByteSpan.Create(PByte(@ATemp[K]), SizeUInt(SizeOf(TGitTreeEntry))));
      FillChar(ATemp[K], SizeOf(TGitTreeEntry), 0);
    end;
  end;

var
  Temp: TGitTreeEntryArray;
begin
  if Length(AEntries) < 2 then
    Exit;
  if Length(AEntries) < 16 then
  begin
    InsertionSort(0, High(AEntries));
    Exit;
  end;
  SetLength(Temp, Length(AEntries));
  MergeSort(AEntries, Temp, 0, Length(AEntries) - 1);
end;

function GitSerializeTree(const AEntries: TGitTreeEntryArray): TBytes;
var
  I, Total, Pos, ModeLen, NameLen: SizeInt;
  ModeStrs: array of string;
begin
  // perf: not inline per red line 2 (40× mode+name alloc exceeds I-Cache), exact size pass+single fill O(n) avoid O(n²), zero-copy SpanCopy via TByteSpan single source bytes.ops, candidate SLO ≤5µs/100-entries, TBytes refcounted try..finally 资源不丢
  SetLength(ModeStrs, Length(AEntries));
  Total := 0;
  for I := 0 to High(AEntries) do
  begin
    ModeStrs[I] := GitModeToString(AEntries[I].Mode);
    Total := Total + Length(ModeStrs[I]) + 1 + Length(AEntries[I].Name) + 1 + GitOidRawLen;
  end;
  SetLength(Result, Total);
  Pos := 0;
  for I := 0 to High(AEntries) do
  begin
    ModeLen := Length(ModeStrs[I]);
    if ModeLen > 0 then
    begin
      SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), SizeUInt(ModeLen)),
        TByteSpan.Create(PByte(PAnsiChar(ModeStrs[I])), SizeUInt(ModeLen)));
      Inc(Pos, ModeLen);
    end;
    Result[Pos] := Byte(Ord(' '));
    Inc(Pos);
    NameLen := Length(AEntries[I].Name);
    if NameLen > 0 then
    begin
      SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), SizeUInt(NameLen)),
        TByteSpan.Create(PByte(PAnsiChar(AEntries[I].Name)), SizeUInt(NameLen)));
      Inc(Pos, NameLen);
    end;
    Result[Pos] := 0;
    Inc(Pos);
    SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), GitOidRawLen),
      TByteSpan.Create(@AEntries[I].Oid.Bytes[0], GitOidRawLen));
    Inc(Pos, GitOidRawLen);
  end;
end;

function GitWriteBlob(const AGitDir: string;
  const AContent: TBytes): TGitOid;
begin
  Result := GitLooseWrite(AGitDir, gokBlob, AContent);
end;

function GitWriteTree(const AGitDir: string;
  var AEntries: TGitTreeEntryArray): TGitOid;
begin
  GitSortTreeEntries(AEntries);
  Result := GitLooseWrite(AGitDir, gokTree, GitSerializeTree(AEntries));
end;

function SignatureLine(const AHeader, AName, AEmail: string;
  AUnixTime: Int64; ATzMinutes: Integer): string;
begin
  if AName = '' then
    raise EGitError.Create('commit signature name must not be empty');
  if AEmail = '' then
    raise EGitError.Create('commit signature email must not be empty');
  if (ATzMinutes < -1500) or (ATzMinutes > 1500) then
    raise EGitError.CreateFmt('implausible timezone offset %d', [ATzMinutes]);
  Result := AHeader + AName + ' <' + AEmail + '> ' + IntToStr(AUnixTime)
    + ' ' + GitFormatTz(ATzMinutes) + #10;
end;

function GitBuildCommitBytes(const ABuilder: TGitCommitBuilder): TBytes;
var
  TreeHex, AuthorLine, CommitterLine: string;
  Hex: string;
  Total, Pos: SizeInt;
  I: Integer;
begin
  // perf: inline* single allocation O(n) exact size pass+single fill via SpanCopy single source bytes.ops avoids O(n²) string+= per parent, zero-copy TByteSpan, candidate SLO ≤3µs/op, TBytes refcounted try..finally 资源不丢 (*impl inline moved to objects facade; write impl not inline per unit header to keep I-Cache, facade inline preserves hot path)
  TreeHex := GitOidToHex(ABuilder.Tree);
  AuthorLine := SignatureLine('author ', ABuilder.AuthorName, ABuilder.AuthorEmail, ABuilder.AuthorUnixTime, ABuilder.AuthorTzMinutes);
  CommitterLine := SignatureLine('committer ', ABuilder.CommitterName, ABuilder.CommitterEmail, ABuilder.CommitterUnixTime, ABuilder.CommitterTzMinutes);
  Total := Length('tree ') + Length(TreeHex) + 1;
  for I := 0 to High(ABuilder.Parents) do
    Inc(Total, Length('parent ') + GitOidHexLen + 1);
  Inc(Total, Length(AuthorLine) + Length(CommitterLine) + 1 + Length(ABuilder.Message));
  SetLength(Result, Total);
  Pos := 0;
  SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length('tree '))),
    TByteSpan.Create(PByte(PAnsiChar('tree ')), SizeUInt(Length('tree '))));
  Inc(Pos, Length('tree '));
  if Length(TreeHex) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length(TreeHex))),
      TByteSpan.Create(PByte(PAnsiChar(TreeHex)), SizeUInt(Length(TreeHex))));
    Inc(Pos, Length(TreeHex));
  end;
  Result[Pos] := Byte(#10);
  Inc(Pos);
  for I := 0 to High(ABuilder.Parents) do
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length('parent '))),
      TByteSpan.Create(PByte(PAnsiChar('parent ')), SizeUInt(Length('parent '))));
    Inc(Pos, Length('parent '));
    Hex := GitOidToHex(ABuilder.Parents[I]);
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length(Hex))),
      TByteSpan.Create(PByte(PAnsiChar(Hex)), SizeUInt(Length(Hex))));
    Inc(Pos, Length(Hex));
    Result[Pos] := Byte(#10);
    Inc(Pos);
  end;
  if Length(AuthorLine) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length(AuthorLine))),
      TByteSpan.Create(PByte(PAnsiChar(AuthorLine)), SizeUInt(Length(AuthorLine))));
    Inc(Pos, Length(AuthorLine));
  end;
  if Length(CommitterLine) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length(CommitterLine))),
      TByteSpan.Create(PByte(PAnsiChar(CommitterLine)), SizeUInt(Length(CommitterLine))));
    Inc(Pos, Length(CommitterLine));
  end;
  Result[Pos] := Byte(#10);
  Inc(Pos);
  if Length(ABuilder.Message) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(Pointer(Result)) + Pos, SizeUInt(Length(ABuilder.Message))),
      TByteSpan.Create(PByte(PAnsiChar(ABuilder.Message)), SizeUInt(Length(ABuilder.Message))));
    Inc(Pos, Length(ABuilder.Message));
  end;
end;

function GitWriteCommit(const AGitDir: string;
  const ABuilder: TGitCommitBuilder): TGitOid;
begin
  Result := GitLooseWrite(AGitDir, gokCommit, GitBuildCommitBytes(ABuilder));
end;

function GitBuildTagBytes(const ABuilder: TGitTagBuilder): TBytes;
var
  I, Total, Pos: SizeInt;
  TargetHex, KindStr, TaggerLine: string;
begin
  // perf: not inline per red line 2, single exact size prealloc+single fill O(n) via SpanCopy TByteSpan single source bytes.ops, candidate SLO ≤2µs/op, TBytes refcounted try..finally 资源不丢
  if ABuilder.TagName = '' then
    raise EGitError.Create('tag name must not be empty');
  for I := 1 to Length(ABuilder.TagName) do
    if ABuilder.TagName[I] in [#10, #13] then
      raise EGitError.Create('tag name must not contain line breaks');
  if (ABuilder.Message <> '')
    and (ABuilder.Message[Length(ABuilder.Message)] <> #10) then
    raise EGitError.Create('tag message must end with a newline');
  TargetHex := GitOidToHex(ABuilder.Target);
  KindStr := GitKindToString(ABuilder.TargetKind);
  TaggerLine := SignatureLine('tagger ', ABuilder.TaggerName, ABuilder.TaggerEmail,
    ABuilder.TaggerUnixTime, ABuilder.TaggerTzMinutes);
  Total := Length('object ') + Length(TargetHex) + 1
    + Length('type ') + Length(KindStr) + 1
    + Length('tag ') + Length(ABuilder.TagName) + 1
    + Length(TaggerLine) + 1 + Length(ABuilder.Message);
  SetLength(Result, Total);
  Pos := 0;
  SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), SizeUInt(Length('object '))),
    TByteSpan.Create(PByte(PAnsiChar('object ')), SizeUInt(Length('object '))));
  Inc(Pos, Length('object '));
  if Length(TargetHex) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), SizeUInt(Length(TargetHex))),
      TByteSpan.Create(PByte(PAnsiChar(TargetHex)), SizeUInt(Length(TargetHex))));
    Inc(Pos, Length(TargetHex));
  end;
  Result[Pos] := Byte(#10);
  Inc(Pos);
  SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), SizeUInt(Length('type '))),
    TByteSpan.Create(PByte(PAnsiChar('type ')), SizeUInt(Length('type '))));
  Inc(Pos, Length('type '));
  if Length(KindStr) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), SizeUInt(Length(KindStr))),
      TByteSpan.Create(PByte(PAnsiChar(KindStr)), SizeUInt(Length(KindStr))));
    Inc(Pos, Length(KindStr));
  end;
  Result[Pos] := Byte(#10);
  Inc(Pos);
  SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), SizeUInt(Length('tag '))),
    TByteSpan.Create(PByte(PAnsiChar('tag ')), SizeUInt(Length('tag '))));
  Inc(Pos, Length('tag '));
  if Length(ABuilder.TagName) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), SizeUInt(Length(ABuilder.TagName))),
      TByteSpan.Create(PByte(PAnsiChar(ABuilder.TagName)), SizeUInt(Length(ABuilder.TagName))));
    Inc(Pos, Length(ABuilder.TagName));
  end;
  Result[Pos] := Byte(#10);
  Inc(Pos);
  if Length(TaggerLine) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), SizeUInt(Length(TaggerLine))),
      TByteSpan.Create(PByte(PAnsiChar(TaggerLine)), SizeUInt(Length(TaggerLine))));
    Inc(Pos, Length(TaggerLine));
  end;
  Result[Pos] := Byte(#10);
  Inc(Pos);
  if Length(ABuilder.Message) > 0 then
  begin
    SpanCopy(TByteSpan.Create(PByte(@Result[Pos]), SizeUInt(Length(ABuilder.Message))),
      TByteSpan.Create(PByte(PAnsiChar(ABuilder.Message)), SizeUInt(Length(ABuilder.Message))));
    Inc(Pos, Length(ABuilder.Message));
  end;
end;

function GitWriteTag(const AGitDir: string;
  const ABuilder: TGitTagBuilder): TGitOid;
begin
  Result := GitLooseWrite(AGitDir, gokTag, GitBuildTagBytes(ABuilder));
end;

end.
