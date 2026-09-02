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
  nextpas.core.bytes.ops,
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
  S := BytesToString(Data);
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

// perf: EnsureIntCapacity single source via bytes.ops GrowArrayCapacity (BYTES_BUILDER_MIN_GROW + *2),
// amortized O(1) ensure, zero-copy Move in callers, inline hot.
procedure EnsureIntCapacity(var Arr: TIntArray; Need: Integer); inline;
begin
  if Length(Arr) < Need then
    SetLength(Arr, Integer(GrowArrayCapacity(SizeUInt(Length(Arr)), SizeUInt(Need))));
end;

// LCS forward row: O(bLen) memory, zero-copy via offsets, reuse buffers (no per-layer alloc)
procedure LcsForwardReuse(const AOld: TStringArray; aOff, aLen: Integer;
  const ANew: TStringArray; bOff, bLen: Integer; var OutRow: TIntArray; var BufPrev, BufCur: TIntArray); inline;
var
  I, J: Integer;
  Tmp: TIntArray;
begin
  EnsureIntCapacity(BufPrev, bLen + 1);
  EnsureIntCapacity(BufCur, bLen + 1);
  EnsureIntCapacity(OutRow, bLen + 1);
  for J := 0 to bLen do BufPrev[J] := 0;
  for I := 1 to aLen do
  begin
    BufCur[0] := 0;
    for J := 1 to bLen do
      if AOld[aOff + I - 1] = ANew[bOff + J - 1] then
        BufCur[J] := BufPrev[J - 1] + 1
      else if BufPrev[J] >= BufCur[J - 1] then
        BufCur[J] := BufPrev[J]
      else
        BufCur[J] := BufCur[J - 1];
    Tmp := BufPrev; BufPrev := BufCur; BufCur := Tmp;
  end;
  // zero-copy bulk Move, single copy into OutRow
  if bLen >= 0 then Move(BufPrev[0], OutRow[0], (bLen + 1) * SizeOf(Integer));
end;

// LCS on reversed slices — same O(bLen) memory, zero-copy, reuse buffers
procedure LcsForwardRevReuse(const AOld: TStringArray; aOff, aLen: Integer;
  const ANew: TStringArray; bOff, bLen: Integer; var OutRow: TIntArray; var BufPrev, BufCur: TIntArray); inline;
var
  I, J: Integer;
  Tmp: TIntArray;
begin
  EnsureIntCapacity(BufPrev, bLen + 1);
  EnsureIntCapacity(BufCur, bLen + 1);
  EnsureIntCapacity(OutRow, bLen + 1);
  for J := 0 to bLen do BufPrev[J] := 0;
  for I := 1 to aLen do
  begin
    BufCur[0] := 0;
    for J := 1 to bLen do
      if AOld[aOff + aLen - I] = ANew[bOff + bLen - J] then
        BufCur[J] := BufPrev[J - 1] + 1
      else if BufPrev[J] >= BufCur[J - 1] then
        BufCur[J] := BufPrev[J]
      else
        BufCur[J] := BufCur[J - 1];
    Tmp := BufPrev; BufPrev := BufCur; BufCur := Tmp;
  end;
  if bLen >= 0 then Move(BufPrev[0], OutRow[0], (bLen + 1) * SizeOf(Integer));
end;

procedure HirschbergCollect(const AOld, ANew: TStringArray;
  aOff, aLen, bOff, bLen: Integer; var Acc: TMatchArray; var AccCnt, AccCap: SizeUInt;
  var BufPrev, BufCur, BufL1, BufLRev: TIntArray); forward;

procedure HirschbergCollect(const AOld, ANew: TStringArray;
  aOff, aLen, bOff, bLen: Integer; var Acc: TMatchArray; var AccCnt, AccCap: SizeUInt;
  var BufPrev, BufCur, BufL1, BufLRev: TIntArray);
var
  Mid, BestK, BestVal, J, V: Integer;
begin
  if (aLen = 0) or (bLen = 0) then Exit;
  if aLen = 1 then
  begin
    for J := 0 to bLen - 1 do
      if AOld[aOff] = ANew[bOff + J] then
      begin
        // perf: amortized doubling via bytes.ops GrowArrayCapacity single source, amortized O(1), inline hot
        if AccCnt >= AccCap then
        begin
          AccCap := GrowArrayCapacity(AccCap, AccCnt + 1);
          SetLength(Acc, AccCap);
        end;
        Acc[AccCnt].OldIdx := aOff;
        Acc[AccCnt].NewIdx := bOff + J;
        Inc(AccCnt);
        Break;
      end;
    Exit;
  end;
  if bLen = 1 then
  begin
    for J := 0 to aLen - 1 do
      if AOld[aOff + J] = ANew[bOff] then
      begin
        if AccCnt >= AccCap then
        begin
          AccCap := GrowArrayCapacity(AccCap, AccCnt + 1);
          SetLength(Acc, AccCap);
        end;
        Acc[AccCnt].OldIdx := aOff + J;
        Acc[AccCnt].NewIdx := bOff;
        Inc(AccCnt);
        Break;
      end;
    Exit;
  end;
  Mid := aLen div 2;
  // perf: reuse buffers (zero-copy slice via off,len) — LcsForwardReuse ensures capacity via GrowArrayCapacity,
  // single Move bulk copy into BufL1/BufLRev, no per-layer double SetLength allocation
  LcsForwardReuse(AOld, aOff, Mid, ANew, bOff, bLen, BufL1, BufPrev, BufCur);
  LcsForwardRevReuse(AOld, aOff + Mid, aLen - Mid, ANew, bOff, bLen, BufLRev, BufPrev, BufCur);
  BestK := 0; BestVal := -1;
  for J := 0 to bLen do
  begin
    V := BufL1[J] + BufLRev[bLen - J];
    if V > BestVal then
    begin
      BestVal := V;
      BestK := J;
    end;
  end;
  HirschbergCollect(AOld, ANew, aOff, Mid, bOff, BestK, Acc, AccCnt, AccCap, BufPrev, BufCur, BufL1, BufLRev);
  HirschbergCollect(AOld, ANew, aOff + Mid, aLen - Mid, bOff + BestK, bLen - BestK, Acc, AccCnt, AccCap, BufPrev, BufCur, BufL1, BufLRev);
end;

function ComputeMatchesFallback(const AOld, ANew: TStringArray): TMatchArray; inline;
type
  THashEntry = record Used: Boolean; Hash: THashCode; Idx: Integer; Line: string; end;
var
  Table: array of THashEntry;
  Mask, I, J, Pos: Integer;
  H: THashCode;
  N, M: Integer;
  LCount, LCap: SizeUInt;
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
  // perf: amortized doubling via bytes.ops GrowArrayCapacity single source, amortized O(1), final shrink once
  LCount := 0; LCap := 0;
  for J := 0 to M - 1 do
  begin
    H := HashString(ANew[J]);
    Pos := Integer(H and THashCode(Mask));
    while Table[Pos].Used do
    begin
      if (Table[Pos].Hash = H) and (Table[Pos].Line = ANew[J]) then
      begin
        if LCount >= LCap then
        begin
          LCap := GrowArrayCapacity(LCap, LCount + 1);
          SetLength(Result, LCap);
        end;
        Result[LCount].OldIdx := Table[Pos].Idx;
        Result[LCount].NewIdx := J;
        Inc(LCount);
        Break;
      end;
      Pos := (Pos + 1) and Mask;
    end;
  end;
  if SizeUInt(Length(Result)) <> LCount then
    SetLength(Result, LCount);
end;

function ComputeMatches(const AOld, ANew: TStringArray): TMatchArray;
var
  n, m: Integer;
  Acc: TMatchArray;
  AccCnt, AccCap: SizeUInt;
  BufPrev, BufCur, BufL1, BufLRev: TIntArray;
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
  Acc := nil; AccCnt := 0; AccCap := 0;
  BufPrev := nil; BufCur := nil; BufL1 := nil; BufLRev := nil;
  // stability: SetLength is exception-safe; managed arrays auto-released on exception, no leak;
  // final shrink ensures logical length = count, Buffers released via managed refcount on exit
  HirschbergCollect(AOld, ANew, 0, n, 0, m, Acc, AccCnt, AccCap, BufPrev, BufCur, BufL1, BufLRev);
  if SizeUInt(Length(Acc)) <> AccCnt then
    SetLength(Acc, AccCnt);
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
