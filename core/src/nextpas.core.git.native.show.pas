unit nextpas.core.git.native.show;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.log,
  nextpas.core.git.native.diff;

{ Show subfamily: commit display à la `git show`.
  Aggregates log entry + tree diff (first-parent for merges,
  empty tree for roots) + name-status/stat. }

type
  TGitShow = record
    Commit: TGitLogEntry;
    Diffs: TGitDiffArray;
    NameStatus: TStringArray;
    StatSummary: string;
    ParentOid: TGitOid; // zero if root
    IsRoot: Boolean;
    IsMerge: Boolean;
  end;

function GitShow(const AGitDir, ARef: string): TGitShow; overload;
function GitShow(const AGitDir: string; const AOid: TGitOid): TGitShow; overload;
function GitShowText(const AGitDir, ARef: string): string; overload;
function GitShowText(const AGitDir: string; const AOid: TGitOid): string; overload;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.revparse;

function LocalTrim(const S: string): string;
var I, J: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] in [#9, #10, #13, ' ']) do Inc(I);
  J := Length(S);
  while (J >= I) and (S[J] in [#9, #10, #13, ' ']) do Dec(J);
  if J < I then Result := '' else Result := Copy(S, I, J - I + 1);
end;

function ShortHex(const AOid: TGitOid): string;
begin
  Result := Copy(GitOidToHex(AOid), 1, 7);
end;

function IsZeroOid(const AOid: TGitOid): Boolean;
var I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do if AOid.Bytes[I] <> 0 then Exit(False);
  Result := True;
end;

function PeelToCommit(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var Kind: TGitObjectKind; Data: TBytes; TagInfo: TGitTagInfo; Depth: Integer;
begin
  Result := AOid; Depth := 0;
  while Depth < 16 do
  begin
    Data := ARepo.ReadObject(Result, Kind);
    if Kind = gokTag then
    begin TagInfo := GitParseTag(Data); Result := TagInfo.Target; Inc(Depth); end
    else if Kind = gokCommit then Exit
    else raise EGitError.CreateFmt('ref does not point to commit: %s', [GitOidToHex(AOid)]);
  end;
  raise EGitError.Create('tag peel too deep');
end;

function ResolveOid(const AGitDir, ARef: string): TGitOid;
var R: string;
begin
  R := LocalTrim(ARef);
  if R = '' then Result := GitResolveHead(AGitDir)
  else
    try Result := GitRevParse(AGitDir, R);
    except Result := GitResolveRef(AGitDir, R); end;
end;

function BuildLogEntry(ARepo: TNativeRepository; const AOid: TGitOid): TGitLogEntry;
var Kind: TGitObjectKind; Data: TBytes; Info: TGitCommitInfo;
begin
  Data := ARepo.ReadObject(AOid, Kind);
  if Kind <> gokCommit then raise EGitError.CreateFmt('object %s is not a commit', [GitOidToHex(AOid)]);
  Info := GitParseCommit(Data);
  Result.Oid := AOid;
  Result.ShortOid := ShortHex(AOid);
  Result.FullMessage := Info.Message;
  Result.Message := GitLogFirstLine(Info.Message);
  Result.Author := Info.Author;
  Result.Committer := Info.Committer;
  Result.Parents := Copy(Info.Parents, 0, Length(Info.Parents));
  Result.Tree := Info.Tree;
  Result.UnixTime := Info.Committer.UnixTime;
end;

function GetParentTree(ARepo: TNativeRepository; const AParents: array of TGitOid; out AParentTree: TGitOid; out AParentOid: TGitOid): Boolean;
var Kind: TGitObjectKind; Data: TBytes; Info: TGitCommitInfo;
begin
  Result := Length(AParents) > 0;
  if not Result then
  begin
    AParentTree := Default(TGitOid);
    AParentOid := Default(TGitOid);
    Exit;
  end;
  AParentOid := AParents[0];
  Data := ARepo.ReadObject(AParentOid, Kind);
  if Kind <> gokCommit then raise EGitError.CreateFmt('parent %s is not a commit', [GitOidToHex(AParentOid)]);
  Info := GitParseCommit(Data);
  AParentTree := Info.Tree;
end;

function GitShowInternal(const AGitDir: string; const AOid: TGitOid): TGitShow;
var
  Repo: TNativeRepository;
  Peeled: TGitOid;
  Log: TGitLogEntry;
  ParentTree, ParentOid: TGitOid;
  HasParent: Boolean;
begin
  if AGitDir = '' then raise EGitError.Create('show: gitdir empty');
  Repo := TNativeRepository.Create(AGitDir);
  try
    Peeled := PeelToCommit(Repo, AOid);
    Log := BuildLogEntry(Repo, Peeled);
    Result.Commit := Log;
    Result.IsRoot := Length(Log.Parents) = 0;
    Result.IsMerge := Length(Log.Parents) > 1;
    HasParent := GetParentTree(Repo, Log.Parents, ParentTree, ParentOid);
    if HasParent then Result.ParentOid := ParentOid
    else
    begin
      ParentTree := Default(TGitOid);
      Result.ParentOid := Default(TGitOid);
    end;
    // GitDiffTrees handles zero tree as empty
    Result.Diffs := GitDiffTrees(AGitDir, ParentTree, Log.Tree);
    Result.NameStatus := GitDiffNameStatus(AGitDir, ParentTree, Log.Tree);
    Result.StatSummary := GitDiffStatSummary(AGitDir, ParentTree, Log.Tree);
  finally
    Repo.Free;
  end;
end;

function GitShow(const AGitDir, ARef: string): TGitShow;
var Oid: TGitOid;
begin
  Oid := ResolveOid(AGitDir, ARef);
  Result := GitShowInternal(AGitDir, Oid);
end;

function GitShow(const AGitDir: string; const AOid: TGitOid): TGitShow;
begin
  Result := GitShowInternal(AGitDir, AOid);
end;

function FormatShowText(const AShow: TGitShow): string;
var
  S: string;
  I: Integer;
  Line: string;
begin
  S := 'commit ' + GitOidToHex(AShow.Commit.Oid) + #10;
  if Length(AShow.Commit.Parents) > 1 then
  begin
    S := S + 'Merge:';
    for I := 0 to High(AShow.Commit.Parents) do
      S := S + ' ' + Copy(GitOidToHex(AShow.Commit.Parents[I]), 1, 7);
    S := S + #10;
  end;
  S := S + 'Author: ' + AShow.Commit.Author.Name + ' <' + AShow.Commit.Author.Email + '>' + #10;
  S := S + 'Date:   ' + IntToStr(AShow.Commit.UnixTime) + #10 + #10;
  S := S + '    ' + AShow.Commit.FullMessage;
  if (Length(S) = 0) or (S[Length(S)] <> #10) then S := S + #10;
  S := S + #10;
  if Length(AShow.NameStatus) > 0 then
  begin
    for I := 0 to High(AShow.NameStatus) do
    begin
      Line := AShow.NameStatus[I];
      S := S + Line + #10;
    end;
  end;
  S := S + AShow.StatSummary + #10;
  Result := S;
end;

function GitShowText(const AGitDir, ARef: string): string;
var Show: TGitShow;
begin
  Show := GitShow(AGitDir, ARef);
  Result := FormatShowText(Show);
end;

function GitShowText(const AGitDir: string; const AOid: TGitOid): string;
var Show: TGitShow;
begin
  Show := GitShow(AGitDir, AOid);
  Result := FormatShowText(Show);
end;

end.
