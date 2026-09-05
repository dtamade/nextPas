unit nextpas.core.git.native.common;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo;

{ Shared object helpers used across the native git subfamily.
  Single source for tree lookup and tag peeling to avoid 6+ copies
  of FindBlobInTree / PeelToTree. Uses GitOidIsZero (inline,
  zero-copy) and preserves EGitError semantics. }

function GitOidIsZero(const AOid: TGitOid): Boolean; inline;
function GitFindBlobInTree(ARepo: TNativeRepository; const ATreeOid: TGitOid; const AName: string; out AOid: TGitOid): Boolean; inline;
function GitPeelToTree(ARepo: TNativeRepository; AOid: TGitOid): TGitOid; inline;
// single source for commit peeling, short-oid display and start-ref resolution
function GitShortHex(const AOid: TGitOid): string;
function GitPeelToCommit(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
function GitResolveStartOid(const AGitDir, ARef: string): TGitOid;

implementation

uses
  nextpas.core.exception,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.util;

function GitOidIsZero(const AOid: TGitOid): Boolean; inline;
begin
  // single source via base.GitOidIsZero -> bytes.ops IsZeroBytes (zero-copy TByteSpan, inline), base owns primitive (base←impl), no push dependency
  Result := nextpas.core.git.native.base.GitOidIsZero(AOid);
end;

function GitFindBlobInTree(ARepo: TNativeRepository; const ATreeOid: TGitOid; const AName: string; out AOid: TGitOid): Boolean;
var
  Kind: TGitObjectKind;
  Data: TBytes;
  Entries: TGitTreeEntryArray;
  I: Integer;
begin
  Result := False;
  if GitOidIsZero(ATreeOid) then Exit;
  Data := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then Exit;
  Entries := GitParseTree(Data);
  for I := 0 to High(Entries) do
    if Entries[I].Name = AName then
    begin
      AOid := Entries[I].Oid;
      Result := True;
      Exit;
    end;
end;

function GitPeelToTree(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var
  Kind: TGitObjectKind;
  Data: TBytes;
  CInfo: TGitCommitInfo;
  TInfo: TGitTagInfo;
  Depth: Integer;
begin
  Result := AOid;
  Depth := 0;
  while Depth < 16 do
  begin
    Data := ARepo.ReadObject(Result, Kind);
    case Kind of
      gokCommit:
        begin
          CInfo := GitParseCommit(Data);
          Result := CInfo.Tree;
          Exit;
        end;
      gokTree:
        Exit;
      gokTag:
        begin
          TInfo := GitParseTag(Data);
          Result := TInfo.Target;
          Inc(Depth);
        end;
    else
      raise EGitError.CreateFmt('object %s is not tree/commit/tag', [GitOidToHex(AOid)]);
    end;
  end;
  raise EGitError.Create('tag peel too deep');
end;

function GitShortHex(const AOid: TGitOid): string;
begin
  Result := Copy(GitOidToHex(AOid), 1, 7);
end;

function GitPeelToCommit(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var
  Kind: TGitObjectKind;
  Data: TBytes;
  TagInfo: TGitTagInfo;
  Depth: Integer;
begin
  Result := AOid;
  Depth := 0;
  while Depth < 16 do
  begin
    Data := ARepo.ReadObject(Result, Kind);
    if Kind = gokTag then
    begin
      TagInfo := GitParseTag(Data);
      Result := TagInfo.Target;
      Inc(Depth);
    end
    else if Kind = gokCommit then Exit
    else raise EGitError.CreateFmt('ref does not point to commit: %s', [GitOidToHex(AOid)]);
  end;
  raise EGitError.Create('tag peel too deep');
end;

function GitResolveStartOid(const AGitDir, ARef: string): TGitOid;
var
  R, LWhy: string;
begin
  R := GitTrimSpaces(ARef);
  if R = '' then
    Result := GitResolveHead(AGitDir)
  else
  begin
    { rev-parse understands specs (HEAD~1, tags); a plain ref name falls
      through to ref lookup. When both fail, report the rev-parse reason:
      it names the actual cause, the ref lookup only repeats "not found". }
    try
      Result := GitRevParse(AGitDir, R);
    except
      on E: Exception do
      begin
        LWhy := E.Message;
        try
          Result := GitResolveRef(AGitDir, R);
        except
          raise EGitError.CreateFmt('cannot resolve "%s": %s', [R, LWhy]);
        end;
      end;
    end;
  end;
end;

end.
