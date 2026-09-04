unit nextpas.core.git.native.index.cachetree;

{$I nextpas.core.settings.inc}

{ index 缓存树域: 条目派生全量 cache-tree + 全记录序列化/落盘.
  发射/排序经 serialize 域单源复用.
  依赖: base/serialize (index.*) + L0-L1 owner + hash/cachetree/loose. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.index.base,
  nextpas.core.git.native.cachetree;

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
  nextpas.core.fs,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1,
  nextpas.core.git.native.base,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.write,
  nextpas.core.git.native.index.serialize;

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
