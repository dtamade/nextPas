unit nextpas.core.git.native.mergebase;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Merge-base subfamily: best common ancestor à la `git merge-base`.
  Two-commit BFS: collect ancestors of A, then BFS from B.
  Linear history returns ancestor; criss-cross returns nearest;
  multiple candidates keep first hit (shortest from B). }

function GitMergeBase(const AGitDir, ARefA, ARefB: string): TGitOid; overload;
function GitMergeBase(const AGitDir: string; const AOidA, AOidB: TGitOid): TGitOid; overload;
function GitMergeBaseMany(const AGitDir: string; const AOids: array of TGitOid): TGitOid;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.revwalk;

function LocalTrim(const S: string): string;
var I, J: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] in [#9, #10, #13, ' ']) do Inc(I);
  J := Length(S);
  while (J >= I) and (S[J] in [#9, #10, #13, ' ']) do Dec(J);
  if J < I then Result := '' else Result := Copy(S, I, J - I + 1);
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
  if R = '' then raise EGitError.Create('merge-base: empty ref');
  try Result := GitRevParse(AGitDir, R);
  except Result := GitResolveRef(AGitDir, R); end;
end;

procedure CollectAncestors(ARepo: TNativeRepository; const AStart: TGitOid; ASet: TGitOidSet);
var
  Queue: array of TGitOid;
  Head: Integer;
  Cur: TGitOid;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  P: Integer;
begin
  if ASet.Contains(AStart) then Exit;
  SetLength(Queue, 1);
  Queue[0] := AStart;
  Head := 0;
  ASet.Add(AStart);
  while Head < Length(Queue) do
  begin
    Cur := Queue[Head]; Inc(Head);
    try
      Data := ARepo.ReadObject(Cur, Kind);
    except
      Continue;
    end;
    if Kind <> gokCommit then Continue;
    Info := GitParseCommit(Data);
    for P := 0 to High(Info.Parents) do
    begin
      if ASet.Contains(Info.Parents[P]) then Continue;
      ASet.Add(Info.Parents[P]);
      SetLength(Queue, Length(Queue) + 1);
      Queue[High(Queue)] := Info.Parents[P];
      if Length(Queue) > 200000 then
        raise EGitError.Create('merge-base: history too large');
    end;
  end;
end;

function FindCommonBFS(ARepo: TNativeRepository; const AStart: TGitOid; AAncestors: TGitOidSet): TGitOid;
var
  Queue: array of TGitOid;
  Visited: TGitOidSet;
  Head: Integer;
  Cur: TGitOid;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  P: Integer;
begin
  // check start itself
  if AAncestors.Contains(AStart) then Exit(AStart);
  Visited := TGitOidSet.Create;
  try
    SetLength(Queue, 1);
    Queue[0] := AStart;
    Visited.Add(AStart);
    Head := 0;
    while Head < Length(Queue) do
    begin
      Cur := Queue[Head]; Inc(Head);
      try
        Data := ARepo.ReadObject(Cur, Kind);
      except
        Continue;
      end;
      if Kind <> gokCommit then Continue;
      Info := GitParseCommit(Data);
      for P := 0 to High(Info.Parents) do
      begin
        if Visited.Contains(Info.Parents[P]) then Continue;
        Visited.Add(Info.Parents[P]);
        if AAncestors.Contains(Info.Parents[P]) then Exit(Info.Parents[P]);
        SetLength(Queue, Length(Queue) + 1);
        Queue[High(Queue)] := Info.Parents[P];
        if Length(Queue) > 200000 then
          raise EGitError.Create('merge-base: history too large');
      end;
    end;
  finally
    Visited.Free;
  end;
  raise EGitError.Create('no merge base found');
end;

function GitMergeBaseInternal(const AGitDir: string; const AOidA, AOidB: TGitOid): TGitOid;
var
  Repo: TNativeRepository;
  A, B: TGitOid;
  SetA: TGitOidSet;
begin
  if AGitDir = '' then raise EGitError.Create('merge-base: gitdir empty');
  if GitOidSame(AOidA, AOidB) then Exit(AOidA);
  Repo := TNativeRepository.Create(AGitDir);
  SetA := TGitOidSet.Create;
  try
    A := PeelToCommit(Repo, AOidA);
    B := PeelToCommit(Repo, AOidB);
    if GitOidSame(A, B) then Exit(A);
    CollectAncestors(Repo, A, SetA);
    Result := FindCommonBFS(Repo, B, SetA);
  finally
    SetA.Free;
    Repo.Free;
  end;
end;

function GitMergeBase(const AGitDir: string; const AOidA, AOidB: TGitOid): TGitOid;
begin
  Result := GitMergeBaseInternal(AGitDir, AOidA, AOidB);
end;

function GitMergeBase(const AGitDir, ARefA, ARefB: string): TGitOid;
var AOidA, AOidB: TGitOid;
begin
  AOidA := ResolveOid(AGitDir, ARefA);
  AOidB := ResolveOid(AGitDir, ARefB);
  Result := GitMergeBaseInternal(AGitDir, AOidA, AOidB);
end;

function GitMergeBaseMany(const AGitDir: string; const AOids: array of TGitOid): TGitOid;
var I: Integer; Cur: TGitOid;
begin
  if Length(AOids) = 0 then raise EGitError.Create('merge-base: empty list');
  if Length(AOids) = 1 then
  begin
    // peel to commit for consistency
    // we still validate gitdir
    if AGitDir = '' then raise EGitError.Create('merge-base: gitdir empty');
    Exit(AOids[0]);
  end;
  Cur := AOids[0];
  for I := 1 to High(AOids) do
    Cur := GitMergeBaseInternal(AGitDir, Cur, AOids[I]);
  Result := Cur;
end;

end.
