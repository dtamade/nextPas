unit nextpas.core.git.native.util;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel;

function GitIsZeroOid(const AOid: TGitOid): Boolean; inline;
// shared string helpers (single source for Trim/EndsWith/SplitLines/StripCR)
function GitTrimSpaces(const S: string): string; inline;
function GitEndsWith(const S, Suffix: string): Boolean; inline;
function GitSplitLines(const S: string): TStringArray; inline;
function GitStripCR(const S: string): string; inline;
function GitWorktreeDir(const AGitDir: string): string; inline;
function GitFindBlobInTree(ARepo: TNativeRepository; const ATreeOid: TGitOid; const AName: string; out AOid: TGitOid): Boolean;
function GitPeelToTree(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.utils;

function GitIsZeroOid(const AOid: TGitOid): Boolean; inline;
var I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do
    if AOid.Bytes[I] <> 0 then Exit(False);
  Result := True;
end;

function GitTrimSpaces(const S: string): string; inline;
begin
  Result := Trim(S);
end;

function GitEndsWith(const S, Suffix: string): Boolean; inline;
begin
  Result := (Length(S) >= Length(Suffix)) and (Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix)) = Suffix);
end;

function GitStripCR(const S: string): string; inline;
begin
  if (Length(S) > 0) and (S[Length(S)] = #13) then
    Result := Copy(S, 1, Length(S) - 1)
  else
    Result := S;
end;

function GitSplitLines(const S: string): TStringArray; inline;
var I, Start, Idx, Cnt: Integer;
begin
  if S = '' then
  begin
    SetLength(Result, 1);
    Result[0] := '';
    Exit;
  end;
  Cnt := 1;
  for I := 1 to Length(S) do
    if S[I] = #10 then Inc(Cnt);
  SetLength(Result, Cnt);
  Start := 1;
  Idx := 0;
  for I := 1 to Length(S) + 1 do
    if (I > Length(S)) or (S[I] = #10) then
    begin
      Result[Idx] := Copy(S, Start, I - Start);
      Inc(Idx);
      Start := I + 1;
    end;
end;

function GitWorktreeDir(const AGitDir: string): string; inline;
var P: Integer;
begin
  if GitEndsWith(AGitDir, '/.git') then
    Result := Copy(AGitDir, 1, Length(AGitDir) - 5)
  else if GitEndsWith(AGitDir, '.git') then
  begin
    P := Length(AGitDir);
    while (P > 0) and (AGitDir[P] <> '/') do Dec(P);
    if P > 0 then Result := Copy(AGitDir, 1, P - 1) else Result := '.';
  end
  else
    Result := AGitDir;
end;

function GitFindBlobInTree(ARepo: TNativeRepository; const ATreeOid: TGitOid; const AName: string; out AOid: TGitOid): Boolean;
var Kind: TGitObjectKind; Data: TBytes; Entries: TGitTreeEntryArray; I: Integer;
begin
  Result := False;
  if GitIsZeroOid(ATreeOid) then Exit;
  Data := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then Exit;
  Entries := GitParseTree(Data);
  for I := 0 to High(Entries) do
    if Entries[I].Name = AName then
    begin AOid := Entries[I].Oid; Result := True; Exit; end;
end;

function GitPeelToTree(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var Kind: TGitObjectKind; Data: TBytes; CInfo: TGitCommitInfo; TInfo: TGitTagInfo; Depth: Integer;
begin
  Result := AOid; Depth := 0;
  while Depth < 16 do
  begin
    Data := ARepo.ReadObject(Result, Kind);
    case Kind of
      gokCommit: begin CInfo := GitParseCommit(Data); Result := CInfo.Tree; Exit; end;
      gokTree: Exit;
      gokTag: begin TInfo := GitParseTag(Data); Result := TInfo.Target; Inc(Depth); end;
    else raise EGitError.CreateFmt('object %s is not a tree/commit/tag', [GitOidToHex(AOid)]);
    end;
  end;
  raise EGitError.Create('tag peel too deep');
end;

end.
