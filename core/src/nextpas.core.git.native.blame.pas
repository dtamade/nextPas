unit nextpas.core.git.native.blame;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.objmodel;

{ Blame subfamily: line-level attribution à la `git blame`.
  Linear history, LCS line diff, oldest-match attribution.
  No rename following, no binary handling. }

type
  TGitBlameEntry = record
    LineNo: Integer; // 1-based
    Line: string;
    CommitOid: TGitOid;
    ShortOid: string; // 7
    AuthorName: string;
    AuthorEmail: string;
    CommitTime: Int64;
  end;
  TGitBlameArray = array of TGitBlameEntry;

function GitBlame(const AGitDir, ARef, APath: string): TGitBlameArray; overload;
function GitBlame(const AGitDir, APath: string): TGitBlameArray; overload;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.revwalk,
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

function SplitLines(const S: string): TStringArray;
var I, Start, L: Integer; Line: string;
begin
  Result := nil;
  L := Length(S);
  Start := 1;
  for I := 1 to L + 1 do
  begin
    if (I > L) or (S[I] = #10) then
    begin
      Line := Copy(S, Start, I - Start);
      // strip trailing CR
      if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
        SetLength(Line, Length(Line) - 1);
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Line;
      Start := I + 1;
    end;
  end;
  // git blame: if file ends with newline, last split is empty after final LF.
  // Our loop adds one entry for final LF; if file ends with LF, last entry is ''.
  // Remove trailing empty that came from final newline to match git's line count
  // (git blame counts lines without extra). But keep empty file as 0.
  if (Length(Result) > 0) and (Result[High(Result)] = '') and (L > 0) and (S[L] = #10) then
    SetLength(Result, Length(Result) - 1);
  if (Length(Result) = 1) and (Result[0] = '') and (L = 0) then
    SetLength(Result, 0);
end;

function FindBlobOid(ARepo: TNativeRepository; const ARootTree: TGitOid; const APath: string): TGitOid;
var
  Parts: TStringArray;
  I, J, K: Integer;
  CurOid: TGitOid;
  Kind: TGitObjectKind;
  Data: TBytes;
  Entries: TGitTreeEntryArray;
  Found: Boolean;
  Name: string;
  Count: Integer;
  Start: Integer;
begin
  Result := Default(TGitOid);
  if IsZeroOid(ARootTree) then Exit;
  if APath = '' then Exit;
  // split by '/'
  Count := 1;
  for I := 1 to Length(APath) do if APath[I] = '/' then Inc(Count);
  SetLength(Parts, Count);
  Start := 1;
  K := 0;
  for I := 1 to Length(APath) + 1 do
    if (I > Length(APath)) or (APath[I] = '/') then
    begin
      Parts[K] := Copy(APath, Start, I - Start);
      Inc(K);
      Start := I + 1;
    end;
  CurOid := ARootTree;
  for I := 0 to High(Parts) do
  begin
    Name := Parts[I];
    if Name = '' then Exit; // invalid
    Data := ARepo.ReadObject(CurOid, Kind);
    if Kind <> gokTree then Exit;
    Entries := GitParseTree(Data);
    Found := False;
    for J := 0 to High(Entries) do
      if Entries[J].Name = Name then
      begin
        if I = High(Parts) then
        begin
          // last component: may be blob or commit (submodule) etc; accept blob/symlink
          Result := Entries[J].Oid;
          Exit;
        end
        else
        begin
          if Entries[J].Mode <> $4000 then Exit; // not a tree
          CurOid := Entries[J].Oid;
          Found := True;
          Break;
        end;
      end;
    if (I <> High(Parts)) and not Found then Exit;
  end;
end;

function ReadFileLines(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APath: string; out ALines: TStringArray): Boolean;
var
  BlobOid: TGitOid;
  Kind: TGitObjectKind;
  Data: TBytes;
  S: string;
begin
  BlobOid := FindBlobOid(ARepo, ATreeOid, APath);
  if IsZeroOid(BlobOid) then Exit(False);
  Data := ARepo.ReadObject(BlobOid, Kind);
  if Kind = gokTree then Exit(False);
  // for symlink/gitlink, treat content as is (blame still lines)
  S := GitBytesToString(Data);
  ALines := SplitLines(S);
  Result := True;
end;

type
  TMatch = record OldIdx, NewIdx: Integer; end;
  TMatchArray = array of TMatch;

function ComputeMatches(const AOld, ANew: TStringArray): TMatchArray;
var
  n, m, I, J, K: Integer;
  dp: array of Integer;
  Matches: TMatchArray;

  function Idx(Ai, Aj: Integer): Integer; inline;
  begin
    Result := Ai * (m + 1) + Aj;
  end;

begin
  Result := nil;
  n := Length(AOld);
  m := Length(ANew);
  if (n = 0) or (m = 0) then Exit;
  // guard large files: fall back to hashed exact line scan (first occurrence)
  if (Int64(n) * Int64(m) > 10000000) then
  begin
    // naive fallback: for each new line, find first equal old line
    SetLength(Matches, 0);
    for J := 0 to m - 1 do
      for I := 0 to n - 1 do
        if AOld[I] = ANew[J] then
        begin
          SetLength(Matches, Length(Matches) + 1);
          Matches[High(Matches)].OldIdx := I;
          Matches[High(Matches)].NewIdx := J;
          Break;
        end;
    Result := Matches;
    Exit;
  end;
  SetLength(dp, (n + 1) * (m + 1));
  for I := 1 to n do
    for J := 1 to m do
      if AOld[I - 1] = ANew[J - 1] then
        dp[Idx(I, J)] := dp[Idx(I - 1, J - 1)] + 1
      else if dp[Idx(I - 1, J)] >= dp[Idx(I, J - 1)] then
        dp[Idx(I, J)] := dp[Idx(I - 1, J)]
      else
        dp[Idx(I, J)] := dp[Idx(I, J - 1)];

  // backtrack
  I := n; J := m;
  SetLength(Matches, 0);
  while (I > 0) and (J > 0) do
  begin
    if AOld[I - 1] = ANew[J - 1] then
    begin
      SetLength(Matches, Length(Matches) + 1);
      Matches[High(Matches)].OldIdx := I - 1;
      Matches[High(Matches)].NewIdx := J - 1;
      Dec(I); Dec(J);
    end
    else if dp[Idx(I - 1, J)] >= dp[Idx(I, J - 1)] then
      Dec(I)
    else
      Dec(J);
  end;
  // reverse to ascending NewIdx order
  SetLength(Result, Length(Matches));
  K := 0;
  for I := High(Matches) downto 0 do
  begin
    Result[K] := Matches[I];
    Inc(K);
  end;
end;

function PeelToCommit(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var Kind: TGitObjectKind; Data: TBytes; TagInfo: TGitTagInfo; Depth: Integer;
begin
  Result := AOid; Depth := 0;
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

function ResolveStartOid(const AGitDir, ARef: string): TGitOid;
var R: string;
begin
  R := LocalTrim(ARef);
  if R = '' then Result := GitResolveHead(AGitDir)
  else
    try Result := GitRevParse(AGitDir, R);
    except Result := GitResolveRef(AGitDir, R); end;
end;

function GitBlameInternal(const AGitDir, ARef, APath: string): TGitBlameArray;
var
  Repo: TNativeRepository;
  StartOid, Peeled: TGitOid;
  Oids: TGitOidArray;
  Infos: array of TGitCommitInfo;
  HeadTree: TGitOid;
  HeadLines: TStringArray;
  BlameOids: array of TGitOid;
  I, J: Integer;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  PrevLines: TStringArray;
  Matches: TMatchArray;
  Entry: TGitBlameEntry;
begin
  Result := nil;
  if AGitDir = '' then raise EGitError.Create('blame: gitdir empty');
  if LocalTrim(APath) = '' then raise EGitError.Create('blame: path empty');
  if Pos('/', APath) = 1 then raise EGitError.Create('blame: absolute path');
  Repo := TNativeRepository.Create(AGitDir);
  try
    StartOid := ResolveStartOid(AGitDir, ARef);
    Peeled := PeelToCommit(Repo, StartOid);
    Oids := GitCollectCommits(Repo, [Peeled], -1);
    if Length(Oids) = 0 then raise EGitError.Create('blame: no commits');
    // cache commit infos and trees
    SetLength(Infos, Length(Oids));
    for I := 0 to High(Oids) do
    begin
      Data := Repo.ReadObject(Oids[I], Kind);
      if Kind <> gokCommit then raise EGitError.CreateFmt('object %s is not a commit', [GitOidToHex(Oids[I])]);
      Infos[I] := GitParseCommit(Data);
    end;
    HeadTree := Infos[0].Tree;
    if not ReadFileLines(Repo, HeadTree, APath, HeadLines) then
      raise EGitError.CreateFmt('path not in HEAD: %s', [APath]);
    if Length(HeadLines) = 0 then Exit(nil); // empty file
    SetLength(BlameOids, Length(HeadLines));
    for I := 0 to High(BlameOids) do BlameOids[I] := Oids[0];

    // walk older commits: head vs each older (newest->oldest, so first matches -> newer, later overwrites -> oldest)
    for I := 1 to High(Oids) do
    begin
      if not ReadFileLines(Repo, Infos[I].Tree, APath, PrevLines) then Continue;
      Matches := ComputeMatches(PrevLines, HeadLines);
      for J := 0 to High(Matches) do
        BlameOids[Matches[J].NewIdx] := Oids[I];
    end;

    // build result with author info
    SetLength(Result, Length(HeadLines));
    for I := 0 to High(HeadLines) do
    begin
      // find info index for BlameOids[I]
      Info := Infos[0];
      for J := 0 to High(Oids) do
        if GitOidSame(Oids[J], BlameOids[I]) then
        begin
          Info := Infos[J];
          Break;
        end;
      Entry.LineNo := I + 1;
      Entry.Line := HeadLines[I];
      Entry.CommitOid := BlameOids[I];
      Entry.ShortOid := ShortHex(BlameOids[I]);
      Entry.AuthorName := Info.Author.Name;
      Entry.AuthorEmail := Info.Author.Email;
      Entry.CommitTime := Info.Committer.UnixTime;
      Result[I] := Entry;
    end;
  finally
    Repo.Free;
  end;
end;

function GitBlame(const AGitDir, ARef, APath: string): TGitBlameArray;
begin
  Result := GitBlameInternal(AGitDir, ARef, APath);
end;

function GitBlame(const AGitDir, APath: string): TGitBlameArray;
begin
  Result := GitBlameInternal(AGitDir, '', APath);
end;

end.
