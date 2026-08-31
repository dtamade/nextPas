unit nextpas.core.git.native.common;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel;

{ Shared object helpers used across the native git subfamily.
  Single source for tree lookup and tag peeling to avoid 6+ copies
  of FindBlobInTree / PeelToTree. Uses GitOidIsZero (inline,
  zero-copy) and preserves EGitError semantics. }

function GitFindBlobInTree(ARepo: TNativeRepository; const ATreeOid: TGitOid; const AName: string; out AOid: TGitOid): Boolean; inline;
function GitPeelToTree(ARepo: TNativeRepository; AOid: TGitOid): TGitOid; inline;

implementation

uses
  nextpas.core.exception;

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

end.
