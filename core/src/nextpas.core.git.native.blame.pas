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
  TBlameMatch = record OldIdx, NewIdx: Integer; end;
  TBlameMatchArray = array of TBlameMatch;

function GitBlame(const AGitDir, ARef, APath: string): TGitBlameArray; overload;
function GitBlame(const AGitDir, APath: string): TGitBlameArray; overload;

const
  // single source 1M threshold shared with tests (anti-jitter, Int64 product)
  BLAME_HIRSCHBERG_CELLS_LIMIT = 1000000;

function GitBlameComputeMatches(const AOld, ANew: TStringArray): TBlameMatchArray; inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.bytes.ops,
  nextpas.core.text.strings,
  nextpas.core.text.utils,
  nextpas.core.git.native.common,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.revwalk,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.util,
  nextpas.core.collections.algorithms,
  nextpas.core.collections.hashmap.swiss;

function IsZeroOid(const AOid: TGitOid): Boolean; inline;
begin
  Result := GitOidIsZero(AOid);
end;

// tree-field scan over raw commit bytes, one 40-char alloc, no signature parse
function BlameCommitTreeOf(const AData: TBytes; out ATree: TGitOid): Boolean; inline;
var Hex: string; I: Integer;
begin
  Result := False;
  if Length(AData) < 45 then Exit;
  if (AData[0] <> Ord('t')) or (AData[1] <> Ord('r')) or (AData[2] <> Ord('e')) or
     (AData[3] <> Ord('e')) or (AData[4] <> Ord(' ')) then Exit;
  SetLength(Hex, 40);
  for I := 0 to 39 do Hex[I + 1] := Chr(AData[5 + I]);
  if not GitOidIsValidHex(Hex) then Exit;
  ATree := GitOidFromHex(Hex);
  Result := True;
end;

function SplitLines(const S: string): TStringArray; inline;
var
  Tmp: TStringArray;
  I: Integer;
begin
  if Length(S) = 0 then
    Exit(nil);
  Tmp := GitSplitLines(S);
  for I := 0 to High(Tmp) do
    Tmp[I] := GitStripCR(Tmp[I]);
  if (Length(Tmp) > 0) and (Tmp[High(Tmp)] = '') and (S[Length(S)] = #10) then
    SetLength(Tmp, Length(Tmp) - 1);
  Result := Tmp;
end;

function FindBlobOid(ARepo: TNativeRepository; const ARootTree: TGitOid; const APath: string): TGitOid;
var
  Parts: TStringArray;
  I: Integer;
  CurOid, NextOid: TGitOid;
  Kind: TGitObjectKind;
  Data: TBytes;
  Name: string;
begin
  Result := Default(TGitOid);
  if IsZeroOid(ARootTree) then Exit;
  if APath = '' then Exit;
  Parts := StringsSplit(APath, '/', False);
  CurOid := ARootTree;
  for I := 0 to High(Parts) do
  begin
    Name := Parts[I];
    if Name = '' then Exit;
    if not GitFindBlobInTree(ARepo, CurOid, Name, NextOid) then Exit;
    if I = High(Parts) then
    begin
      Result := NextOid;
      Exit;
    end;
    Data := ARepo.ReadObject(NextOid, Kind);
    if Kind <> gokTree then Exit;
    CurOid := NextOid;
  end;
end;

function ReadFileLines(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APath: string; out ALines: TStringArray): Boolean;
var
  BlobOid: TGitOid;
  Kind: TGitObjectKind;
  Data: TBytes;
  LLen, I, Start, LCount, LCap: SizeInt;
  LLineLen: SizeInt;
begin
  BlobOid := FindBlobOid(ARepo, ATreeOid, APath);
  if IsZeroOid(BlobOid) then Exit(False);
  Data := ARepo.ReadObject(BlobOid, Kind);
  if Kind = gokTree then Exit(False);
  LLen := Length(Data);
  if LLen = 0 then
  begin
    ALines := nil;
    Exit(True);
  end;
  // zero-copy scan on TBytes via TByteSpan view, one alloc per line
  LCount := 0; LCap := 0; Start := 0;
  for I := 0 to LLen - 1 do
    if Data[I] = 10 then
    begin
      LLineLen := I - Start;
      if (LLineLen > 0) and (Data[I - 1] = 13) then Dec(LLineLen);
      if LCount >= LCap then
      begin
        LCap := Integer(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
        SetLength(ALines, LCap);
      end;
      if LLineLen > 0 then
        SetString(ALines[LCount], PAnsiChar(@Data[Start]), LLineLen)
      else
        ALines[LCount] := '';
      Inc(LCount);
      Start := I + 1;
    end;
  if Start < LLen then
  begin
    LLineLen := LLen - Start;
    if (LLineLen > 0) and (Data[LLen - 1] = 13) then Dec(LLineLen);
    if LCount >= LCap then
    begin
      LCap := Integer(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
      SetLength(ALines, LCap);
    end;
    if LLineLen > 0 then
      SetString(ALines[LCount], PAnsiChar(@Data[Start]), LLineLen)
    else
      ALines[LCount] := '';
    Inc(LCount);
  end
  else if (LLen > 0) and (Data[LLen - 1] = 10) then
  begin
    // trailing LF already emitted empty tail in loop? GitSplitLines trims; keep consistent
  end;
  if LCount = 0 then ALines := nil
  else SetLength(ALines, LCount);
  // handle single-line without LF: already covered; drop trailing empty from GitSplitLines equivalence
  if (Length(ALines) > 0) and (ALines[High(ALines)] = '') and (LLen > 0) and (Data[LLen - 1] = 10) then
    SetLength(ALines, Length(ALines) - 1);
  Result := True;
end;

type
  TMatch = TBlameMatch;
  TMatchArray = TBlameMatchArray;

type
  TIntArray = array of Integer;
  TBlameLineEntry = record Hash: THashCode; Idx: Integer; Line: string; end;
  TBlameLineArray = array of TBlameLineEntry;
  TBlameCacheEntry = record Oid: TGitOid; Lines: TStringArray; Sorted: TBlameLineArray; UCount: Integer; end;
  TBlameCache = array of TBlameCacheEntry;

{ blame Oid→index map via L1 swiss: decouples from revwalk private TOidIndexMap }
function BlameOidHash(const AOid: TGitOid): UInt32; inline;
begin
  Result := GitOidHash(AOid); // bytes.ops SpanHashFNV1a single source, zero-copy
end;

function BlameOidEqual(const A, B: TGitOid): Boolean; inline;
begin
  Result := GitOidSame(A, B); // bytes.ops SpanEqual single source, zero-copy
end;

type
  TBlameOidMap = specialize TSwissTable<TGitOid, Integer>;

function BlameLineLess(const A, B: TBlameLineEntry): Boolean; inline;
begin
  if A.Hash < B.Hash then Exit(True);
  if A.Hash > B.Hash then Exit(False);
  if A.Line < B.Line then Exit(True);
  if A.Line > B.Line then Exit(False);
  Result := A.Idx < B.Idx;
end;

function BlameLineCompare(const A, B: TBlameLineEntry; Data: Pointer): SizeInt;
begin
  if BlameLineLess(A, B) then Exit(-1);
  if BlameLineLess(B, A) then Exit(1);
  Result := 0;
end;

procedure BlameQuickSort(var Arr: TBlameLineArray);
begin
  if Length(Arr) > 1 then
    specialize Sort<TBlameLineEntry>(Arr, @BlameLineCompare, nil);
end;

function BlameFindLine(const Arr: TBlameLineArray; Count: Integer; AHash: THashCode; const ALine: string; out AIdx: Integer): Boolean; inline;
var Lo, Hi, Mid: Integer;
begin
  Lo := 0; Hi := Count - 1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) shr 1;
    if Arr[Mid].Hash < AHash then Lo := Mid + 1
    else if Arr[Mid].Hash > AHash then Hi := Mid - 1
    else if Arr[Mid].Line < ALine then Lo := Mid + 1
    else if Arr[Mid].Line > ALine then Hi := Mid - 1
    else begin AIdx := Arr[Mid].Idx; Exit(True); end;
  end;
  Result := False;
end;

function BuildBlameSortedDedup(const AOld: TStringArray; out AUCount: Integer): TBlameLineArray;
var N, I, UCount: Integer;
begin
  N := Length(AOld);
  AUCount := 0;
  if N = 0 then Exit(nil);
  SetLength(Result, N);
  for I := 0 to N - 1 do
  begin
    Result[I].Hash := HashString(AOld[I]);
    Result[I].Idx := I;
    Result[I].Line := AOld[I];
  end;
  if N > 1 then BlameQuickSort(Result);
  UCount := 1;
  for I := 1 to N - 1 do
    if (Result[I].Hash <> Result[UCount - 1].Hash) or (Result[I].Line <> Result[UCount - 1].Line) then
    begin
      if I <> UCount then Result[UCount] := Result[I];
      Inc(UCount);
    end;
  if UCount <> N then SetLength(Result, UCount);
  AUCount := UCount;
end;

function MatchesFromSortedDedup(const ASorted: TBlameLineArray; AUCount: Integer; const ANew: TStringArray): TMatchArray;
var J, FoundIdx: Integer; H: THashCode; LCount, LCap: SizeUInt;
begin
  Result := nil;
  if (AUCount = 0) or (Length(ANew) = 0) then Exit;
  LCount := 0; LCap := 0;
  for J := 0 to High(ANew) do
  begin
    H := HashString(ANew[J]);
    if BlameFindLine(ASorted, AUCount, H, ANew[J], FoundIdx) then
    begin
      if LCount >= LCap then
      begin
        LCap := GrowArrayCapacity(LCap, LCount + 1);
        SetLength(Result, LCap);
      end;
      Result[LCount].OldIdx := FoundIdx;
      Result[LCount].NewIdx := J;
      Inc(LCount);
    end;
  end;
  if SizeUInt(Length(Result)) <> LCount then SetLength(Result, LCount);
end;

procedure EnsureIntCapacity(var Arr: TIntArray; Need: Integer); inline;
begin
  if Length(Arr) < Need then
    SetLength(Arr, Integer(GrowArrayCapacity(SizeUInt(Length(Arr)), SizeUInt(Need))));
end;

// O(bLen) memory, reuse buffers
procedure LcsForwardReuse(const AOld: TStringArray; aOff, aLen: Integer;
  const ANew: TStringArray; bOff, bLen: Integer; var OutRow: TIntArray; var BufPrev, BufCur: TIntArray);
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
  Tmp := OutRow; OutRow := BufPrev; BufPrev := Tmp;
end;

procedure LcsForwardRevReuse(const AOld: TStringArray; aOff, aLen: Integer;
  const ANew: TStringArray; bOff, bLen: Integer; var OutRow: TIntArray; var BufPrev, BufCur: TIntArray);
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
  Tmp := OutRow; OutRow := BufPrev; BufPrev := Tmp;
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

function ComputeMatchesFallback(const AOld, ANew: TStringArray): TMatchArray;
var
  Entries: TBlameLineArray;
  UCount: Integer;
begin
  Result := nil;
  if (Length(AOld) = 0) or (Length(ANew) = 0) then Exit;
  Entries := BuildBlameSortedDedup(AOld, UCount);
  Result := MatchesFromSortedDedup(Entries, UCount, ANew);
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
  if (Int64(n) * Int64(m) > BLAME_HIRSCHBERG_CELLS_LIMIT) then
  begin
    Result := ComputeMatchesFallback(AOld, ANew);
    Exit;
  end;
  Acc := nil; AccCnt := 0; AccCap := 0;
  BufPrev := nil; BufCur := nil; BufL1 := nil; BufLRev := nil;
  HirschbergCollect(AOld, ANew, 0, n, 0, m, Acc, AccCnt, AccCap, BufPrev, BufCur, BufL1, BufLRev);
  if SizeUInt(Length(Acc)) <> AccCnt then
    SetLength(Acc, AccCnt);
  Result := Acc;
end;

function GitBlameComputeMatches(const AOld, ANew: TStringArray): TBlameMatchArray; inline;
begin
  Result := TBlameMatchArray(ComputeMatches(AOld, ANew));
end;

function BytesToLines(const AData: TBytes): TStringArray;
var LLen, I, Start, LCount, LCap: SizeInt; LLineLen: SizeInt;
begin
  Result := nil;
  LLen := Length(AData);
  if LLen = 0 then Exit(nil);
  LCount := 0; LCap := 0; Start := 0;
  for I := 0 to LLen - 1 do
    if AData[I] = 10 then
    begin
      LLineLen := I - Start;
      if (LLineLen > 0) and (AData[I - 1] = 13) then Dec(LLineLen);
      if LCount >= LCap then
      begin
        LCap := Integer(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
        SetLength(Result, LCap);
      end;
      if LLineLen > 0 then
        SetString(Result[LCount], PAnsiChar(@AData[Start]), LLineLen)
      else
        Result[LCount] := '';
      Inc(LCount);
      Start := I + 1;
    end;
  if Start < LLen then
  begin
    LLineLen := LLen - Start;
    if LCount >= LCap then
    begin
      LCap := Integer(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
      SetLength(Result, LCap);
    end;
    SetString(Result[LCount], PAnsiChar(@AData[Start]), LLineLen);
    if (LLineLen > 0) and (Result[LCount][Length(Result[LCount])]=#13) then
      SetLength(Result[LCount], Length(Result[LCount])-1);
    Inc(LCount);
  end;
  if LCount = 0 then Result := nil else SetLength(Result, LCount);
  if (Length(Result)>0) and (Result[High(Result)]='') and (LLen>0) and (AData[LLen-1]=10) then
    SetLength(Result, Length(Result)-1);
end;

function GitBlameInternal(const AGitDir, ARef, APath: string): TGitBlameArray;
var
  Repo: TNativeRepository;
  StartOid, Peeled: TGitOid;
  Oids: TGitOidArray;
  Infos: array of TGitCommitInfo;
  Parsed: array of Boolean;
  OidIdx: TOidIndexMap;
  HeadTree: TGitOid;
  HeadLines: TStringArray;
  HeadBlobOid, CurBlobOid, CurTree: TGitOid;
  BlameOids: array of TGitOid;
  Cache: TBlameCache;
  CacheCap, CacheCnt: SizeUInt;
  CacheMap: TBlameOidMap;
  I, J, K: Integer;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  PrevLines: TStringArray;
  Matches: TMatchArray;
  Entry: TGitBlameEntry;
  procedure EnsureCommit(AIdx: Integer);
  begin
    if Parsed[AIdx] then Exit;
    Data := Repo.ReadObject(Oids[AIdx], Kind);
    if Kind <> gokCommit then raise EGitError.CreateFmt('object %s is not a commit', [GitOidToHex(Oids[AIdx])]);
    Infos[AIdx] := GitParseCommit(Data);
    Parsed[AIdx] := True;
  end;
begin
  Result := nil;
  if AGitDir = '' then raise EGitError.Create('blame: gitdir empty');
  if GitTrimSpaces(APath) = '' then raise EGitError.Create('blame: path empty');
  if Pos('/', APath) = 1 then raise EGitError.Create('blame: absolute path');
  Repo := TNativeRepository.Create(AGitDir);
  CacheMap := TBlameOidMap.Create(0, @BlameOidHash, @BlameOidEqual);
  OidIdx := TOidIndexMap.Create;
  try
    StartOid := GitResolveStartOid(AGitDir, ARef);
    Peeled := GitPeelToCommit(Repo, StartOid);
    Oids := GitCollectCommits(Repo, [Peeled], -1);
    if Length(Oids) = 0 then raise EGitError.Create('blame: no commits');
    SetLength(Infos, Length(Oids));
    SetLength(Parsed, Length(Oids));
    for I := 0 to High(Oids) do OidIdx.Add(Oids[I], I);
    EnsureCommit(0);
    HeadTree := Infos[0].Tree;
    if not ReadFileLines(Repo, HeadTree, APath, HeadLines) then
      raise EGitError.CreateFmt('path not in HEAD: %s', [APath]);
    if Length(HeadLines) = 0 then Exit(nil);
    HeadBlobOid := FindBlobOid(Repo, HeadTree, APath);
    SetLength(BlameOids, Length(HeadLines));
    for I := 0 to High(BlameOids) do BlameOids[I] := Oids[0];
    Cache := nil; CacheCap := 0; CacheCnt := 0;
    if not IsZeroOid(HeadBlobOid) then
    begin
      CacheCap := GrowArrayCapacity(CacheCap, CacheCnt + 1);
      SetLength(Cache, CacheCap);
      Cache[CacheCnt].Oid := HeadBlobOid;
      Cache[CacheCnt].Lines := HeadLines;
      Cache[CacheCnt].Sorted := nil;
      Cache[CacheCnt].UCount := 0;
      CacheMap.Put(HeadBlobOid, Integer(CacheCnt));
      Inc(CacheCnt);
    end;
    for I := 1 to High(Oids) do
    begin
      Data := Repo.ReadObject(Oids[I], Kind);
      if Kind <> gokCommit then raise EGitError.CreateFmt('object %s is not a commit', [GitOidToHex(Oids[I])]);
      if not BlameCommitTreeOf(Data, CurTree) then
      begin
        EnsureCommit(I);
        CurTree := Infos[I].Tree;
      end;
      CurBlobOid := FindBlobOid(Repo, CurTree, APath);
      if IsZeroOid(CurBlobOid) then Continue;
      if GitOidSame(CurBlobOid, HeadBlobOid) then
      begin
        for J := 0 to High(BlameOids) do BlameOids[J] := Oids[I];
        Continue;
      end;
      if not CacheMap.TryGetValue(CurBlobOid, K) then
      begin
        Data := Repo.ReadObject(CurBlobOid, Kind);
        if Kind = gokTree then Continue;
        PrevLines := BytesToLines(Data);
        if CacheCnt >= CacheCap then
        begin
          CacheCap := GrowArrayCapacity(CacheCap, CacheCnt + 1);
          SetLength(Cache, CacheCap);
        end;
        Cache[CacheCnt].Oid := CurBlobOid;
        Cache[CacheCnt].Lines := PrevLines;
        Cache[CacheCnt].Sorted := nil;
        Cache[CacheCnt].UCount := 0;
        K := Integer(CacheCnt);
        CacheMap.Put(CurBlobOid, K);
        Inc(CacheCnt);
      end
      else
        PrevLines := Cache[K].Lines;
      if Int64(Length(PrevLines)) * Int64(Length(HeadLines)) > BLAME_HIRSCHBERG_CELLS_LIMIT then
      begin
        if Cache[K].Sorted = nil then
          Cache[K].Sorted := BuildBlameSortedDedup(PrevLines, Cache[K].UCount)
        else if Cache[K].UCount = 0 then
          Cache[K].UCount := Length(Cache[K].Sorted);
        Matches := MatchesFromSortedDedup(Cache[K].Sorted, Cache[K].UCount, HeadLines);
      end
      else
        Matches := ComputeMatches(PrevLines, HeadLines);
      for J := 0 to High(Matches) do
        BlameOids[Matches[J].NewIdx] := Oids[I];
    end;
    SetLength(Result, Length(HeadLines));
    for I := 0 to High(HeadLines) do
    begin
      Info := Infos[0];
      if OidIdx.TryGet(BlameOids[I], K) then
      begin
        EnsureCommit(K);
        Info := Infos[K];
      end;
      Entry.LineNo := I + 1;
      Entry.Line := HeadLines[I];
      Entry.CommitOid := BlameOids[I];
      Entry.ShortOid := GitShortHex(BlameOids[I]);
      Entry.AuthorName := Info.Author.Name;
      Entry.AuthorEmail := Info.Author.Email;
      Entry.CommitTime := Info.Committer.UnixTime;
      Result[I] := Entry;
    end;
  finally
    OidIdx.Free;
    CacheMap.Free;
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
