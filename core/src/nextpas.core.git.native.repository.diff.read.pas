unit nextpas.core.git.native.repository.diff.read;

{$I nextpas.core.settings.inc}

{ repository.diff 读取域: 工作区/对象内容行化 + 修订树解析.
  依赖: L0-L1 owner + repo/revparse/objmodel/util. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

function TrimInline(const S: string): string; inline;
function WorkDirOf(const AGitDir, AWorkTree: string): string; inline;
function IsBinaryBytes(const AData: TBytes): Boolean; inline;
function BlobLinesOf(const AGitDir: string; const AOid: TGitOid): TStringArray; inline;
function PathIncluded(const APath: string; const APaths: TStringArray): Boolean; inline;
function WorkTreeLinesOf(const AWorkTree, ARel: string): TStringArray; inline;
function ResolveTreeOid(const AGitDir, ARef: string): TGitOid; inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.fs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.util;

function TrimInline(const S: string): string; inline;
begin
  Result := GitTrimSpaces(S);
end;

function WorkDirOf(const AGitDir, AWorkTree: string): string; inline;
begin
  if AWorkTree <> '' then
    Result := AWorkTree
  else
    Result := PathDir(AGitDir);
end;

function IsBinaryBytes(const AData: TBytes): Boolean; inline;
begin
  // perf: single-source via bytes.ops BytesIndexOf (inline SpanIndexOf -> MemFindByte SIMD disp.), zero-copy span view, no per-byte Pascal loop; early exit via SIMD
  Result := BytesIndexOf(AData, 0) >= 0;
end;

function BlobLinesOf(const AGitDir: string; const AOid: TGitOid): nextpas.core.base.TStringArray; inline;
var
  R: TNativeRepository;
  K: TGitObjectKind;
  D: TBytes;
  S: string;
begin
  Result:=nil;
  if GitOidIsZero(AOid) then
    Exit;
  R:=TNativeRepository.Create(AGitDir);
  try
    D:=R.ReadObject(AOid,K);
    if IsBinaryBytes(D) then
      Exit(nil);
    S:=BytesToString(D);
    Result:=GitSplitLines(S);
    if (Length(Result)=1) and (Result[0]='') and (Length(S)=0) then
      SetLength(Result,0);
    if (Length(Result)>0) and (Result[High(Result)]='') and (Length(S)>0) and (S[Length(S)]=#10) then
      SetLength(Result,Length(Result)-1);
  finally
    R.Free;
  end;
end;

function PathIncluded(const APath: string; const APaths: nextpas.core.base.TStringArray): Boolean; inline;
var
  I: Integer;
begin
  if Length(APaths)=0 then
    Exit(True);
  for I:=0 to High(APaths) do
    if (APath=APaths[I]) or ((Length(APath)>Length(APaths[I])) and (Copy(APath,1,Length(APaths[I])+1)=APaths[I]+'/')) then
      Exit(True);
  Result:=False;
end;

function WorkTreeLinesOf(const AWorkTree, ARel: string): nextpas.core.base.TStringArray; inline;
var
  P: string;
  D: TBytes;
  S: string;
begin
  Result:=nil;
  P:=PathJoin([AWorkTree,ARel]);
  if not FileExists(P) then
    Exit(nil);
  try
    D:=ReadFile(P);
  except
    Exit(nil);
  end;
  if IsBinaryBytes(D) then
    Exit(nil);
  S:=BytesToString(D);
  Result:=GitSplitLines(S);
  if (Length(Result)=1) and (Result[0]='') and (Length(S)=0) then
    SetLength(Result,0);
  if (Length(Result)>0) and (Result[High(Result)]='') and (Length(S)>0) and (S[Length(S)]=#10) then
    SetLength(Result,Length(Result)-1);
end;
function ResolveTreeOid(const AGitDir, ARef: string): TGitOid; inline;
var
  Oid: TGitOid;
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  Tag: TGitTagInfo;
begin
  try
    Oid:=GitRevParse(AGitDir,ARef);
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create(CurrentExceptionMessage);
  end;
  Repo:=TNativeRepository.Create(AGitDir);
  try
    Data:=Repo.ReadObject(Oid,Kind);
    if Kind=gokCommit then
    begin
      Info:=GitParseCommit(Data);
      Result:=Info.Tree;
    end
    else if Kind=gokTree then
      Result:=Oid
    else if Kind=gokTag then
    begin
      Tag:=GitParseTag(Data);
      Result:=GitPeelToTree(Repo,Tag.Target);
    end
    else raise EGitError.CreateFmt('object %s is not tree/commit/tag',[GitOidToHex(Oid)]);
  finally
    Repo.Free;
  end;
end;

end.
