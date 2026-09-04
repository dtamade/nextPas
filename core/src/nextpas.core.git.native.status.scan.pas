unit nextpas.core.git.native.status.scan;

{$I nextpas.core.settings.inc}

{ status 扫描域: 树扁平化 + 工作树比对 (HEAD/index/worktree 三方输入).
  依赖: base/similarity (status.*) + L0-L1 owner + repo/index/objmodel. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.status.base,
  nextpas.core.git.native.status.similarity,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.index;

function ComparePathOid(const A, B: TPathOid; AData: Pointer): SizeInt;
procedure SortPathOids(var AList: TPathOidArray);
procedure FlattenTree(ARepo: TNativeRepository; const ATreeOid: TGitOid;
  const APrefix: string; var AOut: TPathOidArray);
function ModeClassOf(AMode: Cardinal): Integer;
function WorkCodeFor(const AWorkTree: string; const AEntry: TGitIndexEntry): TGitStatusCode;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.collections.algorithms,
  nextpas.core.collections.arr.sort,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.loose;

function ComparePathOid(const A, B: TPathOid; AData: Pointer): SizeInt;
var
  LA, LB: TByteSpan;
begin
  if A.Path = B.Path then Exit(0);
  if A.Path = '' then LA := TByteSpan.Empty
  else LA := TByteSpan.Create(PByte(@A.Path[1]), SizeUInt(Length(A.Path)));
  if B.Path = '' then LB := TByteSpan.Empty
  else LB := TByteSpan.Create(PByte(@B.Path[1]), SizeUInt(Length(B.Path)));
  Result := SpanCompare(LA, LB);
end;

procedure SortPathOids(var AList: TPathOidArray);
begin
  if Length(AList) < 2 then Exit;
  specialize Sort<TPathOid>(AList, @ComparePathOid, nil);
end;

procedure FlattenTree(ARepo: TNativeRepository; const ATreeOid: TGitOid;
  const APrefix: string; var AOut: TPathOidArray);
var
  LCount, LCap: SizeInt;
  procedure DoFlatten(const ATreeOidInner: TGitOid; const APrefixInner: string; ADepth: Integer);
  var
    Data: TBytes;
    Kind: TGitObjectKind;
    Entries: TGitTreeEntryArray;
    I: SizeInt;
  begin
    if ADepth > CMaxFlattenDepth then
      raise EGitError.Create('tree depth exceeds limit');
    Data := ARepo.ReadObject(ATreeOidInner, Kind);
    if Kind <> gokTree then
      raise EGitError.Create('head commit points at a non-tree object');
    Entries := GitParseTree(Data);
    for I := 0 to High(Entries) do
    begin
      if Entries[I].Mode = CModeDir then
        DoFlatten(Entries[I].Oid, APrefixInner + Entries[I].Name + '/', ADepth + 1)
      else
      begin
        if LCount = LCap then
        begin
          LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
          SetLength(AOut, LCap);
        end;
        AOut[LCount].Path := APrefixInner + Entries[I].Name;
        AOut[LCount].Oid := Entries[I].Oid;
        AOut[LCount].Mode := Entries[I].Mode;
        Inc(LCount);
      end;
    end;
  end;
begin
  LCount := Length(AOut);
  LCap := Length(AOut);
  DoFlatten(ATreeOid, APrefix, 0);
  if LCap <> LCount then
    SetLength(AOut, LCount);
end;

function ModeClassOf(AMode: Cardinal): Integer;
begin
  case AMode of
    CModeSymlink: Result := 1;
    CModeGitlink: Result := 2;
    CModeDir: Result := 3;
  else
    Result := 0;
  end;
end;

function WorkCodeFor(const AWorkTree: string; const AEntry: TGitIndexEntry): TGitStatusCode;
var
  Full: string;
  Info: TFileInfo;
  WorkMode: Cardinal;
  WorkOid: TGitOid;
  EntryKind: TGitObjectKind;
begin
  Full := PathJoin([AWorkTree, AEntry.Path]);
  try
    if not Exists(Full) then Exit(gscDeleted);
  except
    Exit(gscDeleted);
  end;
  try
    Info := Lstat(Full);
  except
    Exit(gscDeleted);
  end;
  EntryKind := GitKindFromMode(AEntry.Mode);
  if EntryKind = gokCommit then
  begin
    if Info.IsDir then Exit(gscUnmodified);
    Exit(gscDeleted);
  end;
  if Info.IsDir then Exit(gscTypeChanged);
  if Info.IsSymlink then
  begin
    try
      WorkOid := GitHashObject(gokBlob, GitStringToBytes(Readlink(Full)));
    except
      Exit(gscDeleted);
    end;
    if not GitOidSame(WorkOid, AEntry.Oid) then Exit(gscModified);
    if AEntry.Mode <> CModeSymlink then Exit(gscTypeChanged);
    Exit(gscUnmodified);
  end;
  WorkMode := CModeRegular;
  if (Info.Permission and (PermOwnerExec or PermGroupExec or PermOtherExec)) <> 0 then
    WorkMode := CModeExec;
  if ModeClassOf(AEntry.Mode) <> 0 then Exit(gscTypeChanged);
  if Info.Size <> Int64(AEntry.Size) then Exit(gscModified);
  if Info.ModTime = Int64(AEntry.MTimeSec) * 1000000000 + Int64(AEntry.MTimeNSec) then
    Exit(gscUnmodified);
  if WorkMode <> AEntry.Mode then Exit(gscModified);
  Result := gscModified;
end;

end.
