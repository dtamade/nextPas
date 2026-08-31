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
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.util;

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

function SplitLines(const S: string): TStringArray; inline;
var
  Tmp: TStringArray;
  I: Integer;
begin
  // single source: delegate split to util.GitSplitLines (single-alloc, inline hot)
  // then blame-specific normalization: strip CR (GitStripCR zero-copy) + trim
  // trailing LF artefact. Keeps L0-L3 layering, no duplicate loop.
  if Length(S) = 0 then
    Exit(nil);
  Tmp := GitSplitLines(S);
  for I := 0 to High(Tmp) do
    Tmp[I] := GitStripCR(Tmp[I]); // inline, zero-copy when no CR
  if (Length(Tmp) > 0) and (Tmp[High(Tmp)] = '') and (S[Length(S)] = #10) then
    SetLength(Tmp, Length(Tmp) - 1);
  Result := Tmp;
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

// -- Hirschberg/LCS helpers: zero-copy slice via (off,len), inline hot path --
// reuse single source HashString (nextpas.core.base, FNV-1a) — no duplicate hash
type
  TIntArray = array of Integer;

function NextPow2(AValue: Integer): Integer; inline;
begin
  Result := 1;
  while Result < AValue do Result := Result shl 1;
end;

// LCS forward row: O(bLen) memory, zero-copy via offsets
function LcsForward(const AOld: TStringArray; aOff, aLen: Integer;
  const ANew: TStringArray; bOff, bLen: Integer): TIntArray; inline;
var
  Prev, Cur, Tmp: TIntArray;
  I, J: Integer;
begin
  SetLength(Prev, bLen + 1);
  SetLength(Cur, bLen + 1);
  for I := 1 to aLen do
  begin
    Cur[0] := 0;
    for J := 1 to bLen do
      if AOld[aOff + I - 1] = ANew[bOff + J - 1] then
        Cur[J] := Prev[J - 1] + 1
      else if Prev[J] >= Cur[J - 1] then
        Cur[J] := Prev[J]
      else
        Cur[J] := Cur[J - 1];
    Tmp := Prev; Prev := Cur; Cur := Tmp;
  end;
  Result := Prev;
end;

// LCS on reversed slices — same O(bLen) memory, zero-copy
function LcsForwardRev(const AOld: TStringArray; aOff, aLen: Integer;
  const ANew: TStringArray; bOff, bLen: Integer): TIntArray; inline;
var
  Prev, Cur, Tmp: TIntArray;
  I, J: Integer;
begin
  SetLength(Prev, bLen + 1);
  SetLength(Cur, bLen + 1);
  for I := 1 to aLen do
  begin
    Cur[0] := 0;
    for J := 1 to bLen do
      if AOld[aOff + aLen - I] = ANew[bOff + bLen - J] then
        Cur[J] := Prev[J - 1] + 1
      else if Prev[J] >= Cur[J - 1] then
        Cur[J] := Prev[J]
      else
        Cur[J] := Cur[J - 1];
    Tmp := Prev; Prev := Cur; Cur := Tmp;
  end;
  Result := Prev;
end;

procedure HirschbergCollect(const AOld, ANew: TStringArray;
  aOff, aLen, bOff, bLen: Integer; var Acc: TMatchArray); forward;

procedure HirschbergCollect(const AOld, ANew: TStringArray;
  aOff, aLen, bOff, bLen: Integer; var Acc: TMatchArray);
var
  Mid, BestK, BestVal, J, V: Integer;
  L1, LRev: TIntArray;
  Cnt: Integer;
begin
  if (aLen = 0) or (bLen = 0) then Exit;
  if aLen = 1 then
  begin
    for J := 0 to bLen - 1 do
      if AOld[aOff] = ANew[bOff + J] then
      begin
        Cnt := Length(Acc);
        SetLength(Acc, Cnt + 1);
        Acc[Cnt].OldIdx := aOff;
        Acc[Cnt].NewIdx := bOff + J;
        Break;
      end;
    Exit;
  end;
  if bLen = 1 then
  begin
    for J := 0 to aLen - 1 do
      if AOld[aOff + J] = ANew[bOff] then
      begin
        Cnt := Length(Acc);
        SetLength(Acc, Cnt + 1);
        Acc[Cnt].OldIdx := aOff + J;
        Acc[Cnt].NewIdx := bOff;
        Break;
      end;
    Exit;
  end;
  Mid := aLen div 2;
  L1 := LcsForward(AOld, aOff, Mid, ANew, bOff, bLen);
  LRev := LcsForwardRev(AOld, aOff + Mid, aLen - Mid, ANew, bOff, bLen);
  BestK := 0; BestVal := -1;
  for J := 0 to bLen do
  begin
    V := L1[J] + LRev[bLen - J];
    if V > BestVal then
    begin
      BestVal := V;
      BestK := J;
    end;
  end;
  HirschbergCollect(AOld, ANew, aOff, Mid, bOff, BestK, Acc);
  HirschbergCollect(AOld, ANew, aOff + Mid, aLen - Mid, bOff + BestK, bLen - BestK, Acc);
end;

function ComputeMatchesFallback(const AOld, ANew: TStringArray): TMatchArray; inline;
type
  THashEntry = record Used: Boolean; Hash: THashCode; Idx: Integer; Line: string; end;
var
  Table: array of THashEntry;
  Mask, I, J, Pos: Integer;
  H: THashCode;
  N, M: Integer;
begin
  Result := nil;
  N := Length(AOld); M := Length(ANew);
  if (N = 0) or (M = 0) then Exit;
  Mask := NextPow2(N * 2 + 1) - 1;
  SetLength(Table, Mask + 1);
  for I := 0 to N - 1 do
  begin
    H := HashString(AOld[I]);
    Pos := Integer(H and THashCode(Mask));
    while Table[Pos].Used do
    begin
      if (Table[Pos].Hash = H) and (Table[Pos].Line = AOld[I]) then Break;
      Pos := (Pos + 1) and Mask;
    end;
    if not Table[Pos].Used then
    begin
      Table[Pos].Used := True;
      Table[Pos].Hash := H;
      Table[Pos].Idx := I;
      Table[Pos].Line := AOld[I];
    end;
  end;
  SetLength(Result, 0);
  for J := 0 to M - 1 do
  begin
    H := HashString(ANew[J]);
    Pos := Integer(H and THashCode(Mask));
    while Table[Pos].Used do
    begin
      if (Table[Pos].Hash = H) and (Table[Pos].Line = ANew[J]) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)].OldIdx := Table[Pos].Idx;
        Result[High(Result)].NewIdx := J;
        Break;
      end;
      Pos := (Pos + 1) and Mask;
    end;
  end;
end;

function ComputeMatches(const AOld, ANew: TStringArray): TMatchArray;
var
  n, m: Integer;
  Acc: TMatchArray;
begin
  Result := nil;
  n := Length(AOld);
  m := Length(ANew);
  if (n = 0) or (m = 0) then Exit;
  if (Int64(n) * Int64(m) > 10000000) then
  begin
    Result := ComputeMatchesFallback(AOld, ANew);
    Exit;
  end;
  Acc := nil;
  HirschbergCollect(AOld, ANew, 0, n, 0, m, Acc);
  Result := Acc;
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
