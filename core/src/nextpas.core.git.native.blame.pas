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
  nextpas.core.text.strings,
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

function IsZeroOid(const AOid: TGitOid): Boolean; inline;
const ZeroOid: TGitOid = (Bytes: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0));
begin
  // perf: single source via bytes.ops SpanEqual -> MemEqual 3×QWord for 20B, zero-copy TByteSpan view, inline hot, branch-free (hot query path)
  Result := SpanEqual(
    TByteSpan.Create(PByte(@AOid.Bytes[0]), GitOidRawLen),
    TByteSpan.Create(PByte(@ZeroOid.Bytes[0]), GitOidRawLen));
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
  I, J: Integer;
  CurOid: TGitOid;
  Kind: TGitObjectKind;
  Data: TBytes;
  Entries: TGitTreeEntryArray;
  Found: Boolean;
  Name: string;
begin
  Result := Default(TGitOid);
  if IsZeroOid(ARootTree) then Exit;
  if APath = '' then Exit;
  // single source: delegate '/' split to text.strings (L1) — inline hot, single alloc, reuses bytes.ops GrowArrayCapacity internally; preserves empty segments for strict validation (no dup hand loop)
  Parts := StringsSplit(APath, '/', False);
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
  TBlameLineEntry = record Hash: THashCode; Idx: Integer; Line: string; end;
  TBlameLineArray = array of TBlameLineEntry;

function BlameLineLess(const A, B: TBlameLineEntry): Boolean; inline;
begin
  // perf: FNV-1a HashString single source (nextpas.core.base), inline hot, no alloc; order by hash then string then idx (keeps smallest idx first for dedup)
  if A.Hash < B.Hash then Exit(True);
  if A.Hash > B.Hash then Exit(False);
  if A.Line < B.Line then Exit(True);
  if A.Line > B.Line then Exit(False);
  Result := A.Idx < B.Idx;
end;

procedure BlameSwapLines(var A, B: TBlameLineEntry); inline;
var Tmp: TBlameLineEntry;
begin
  // perf: single Move of managed record via assignment (refcounted string copy-on-write, no heap, inline hot)
  Tmp := A; A := B; B := Tmp;
end;

procedure BlameQuickSort(var Arr: TBlameLineArray; L, R: Integer);
var I, J: Integer; Pivot: TBlameLineEntry;
begin
  if R - L < 1 then Exit;
  I := L; J := R;
  Pivot := Arr[(L + R) shr 1];
  repeat
    while BlameLineLess(Arr[I], Pivot) do Inc(I);
    while BlameLineLess(Pivot, Arr[J]) do Dec(J);
    if I <= J then
    begin
      if I <> J then BlameSwapLines(Arr[I], Arr[J]);
      Inc(I); Dec(J);
    end;
  until I > J;
  if L < J then BlameQuickSort(Arr, L, J);
  if I < R then BlameQuickSort(Arr, I, R);
end;

function BlameFindLine(const Arr: TBlameLineArray; Count: Integer; AHash: THashCode; const ALine: string; out AIdx: Integer): Boolean; inline;
var Lo, Hi, Mid: Integer;
begin
  // perf: binary search O(log U), inline hot, zero-copy string compare (no alloc), branch-light
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
// not inline: O(n*m) double loop would bloat I-Cache if inlined per design-conventions red line 2
// perf: zero-copy swap (BufPrev<->OutRow) via refcounted assignment O(1), single source bytes.ops GrowArrayCapacity, inline hot ensures capacity, zero bulk Move; Move eliminated, bench baseline covers threshold 1M (see ComputeMatches).
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
  // perf: zero-copy swap OutRow<->BufPrev O(1) via assignment (refcounted, no heap, no Move), reuses bytes.ops single source capacity, inline hot; eliminates O(m) bulk Move double-buffer copy at 1M threshold, keeps Hirschberg O(bLen) memory
  Tmp := OutRow; OutRow := BufPrev; BufPrev := Tmp;
end;

// LCS on reversed slices — same O(bLen) memory, zero-copy, reuse buffers
// not inline: O(n*m) double loop would bloat I-Cache if inlined per design-conventions red line 2
// perf: zero-copy swap (BufPrev<->OutRow) via refcounted assignment O(1), single source bytes.ops GrowArrayCapacity, inline hot, zero Move; mirrors LcsForwardReuse.
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
  // perf: zero-copy swap OutRow<->BufPrev O(1) via assignment (refcounted, no heap, no Move), reuses bytes.ops single source; eliminates O(m) bulk Move, bench threshold 1M coverage via ComputeMatches fallback path.
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
var
  Entries: TBlameLineArray;
  N, M, I, J, UCount, FoundIdx: Integer;
  H: THashCode;
  LCount, LCap: SizeUInt;
begin
  // perf: sorted dedup array O(N log N + M log U) time, O(N) memory (single compacted array), no N*2 open-address Table spike; single source HashString via base FNV-1a, bytes.ops GrowArrayCapacity for amortized O(1) result append
  // stability: managed arrays auto-released on exception, no manual free, zero-copy string view via refcounted copy
  Result := nil;
  N := Length(AOld); M := Length(ANew);
  if (N = 0) or (M = 0) then Exit;
  SetLength(Entries, N);
  for I := 0 to N - 1 do
  begin
    Entries[I].Hash := HashString(AOld[I]);
    Entries[I].Idx := I;
    Entries[I].Line := AOld[I];
  end;
  if N > 1 then BlameQuickSort(Entries, 0, N - 1);
  // in-place dedup: compact distinct (hash,line) keeping smallest idx first due to sorted order
  UCount := 1;
  for I := 1 to N - 1 do
    if (Entries[I].Hash <> Entries[UCount - 1].Hash) or (Entries[I].Line <> Entries[UCount - 1].Line) then
    begin
      if I <> UCount then Entries[UCount] := Entries[I];
      Inc(UCount);
    end;
  if UCount <> N then SetLength(Entries, UCount);
  // probe new lines via binary search; result grows via single-source GrowArrayCapacity (inline, amortized O(1))
  LCount := 0; LCap := 0;
  for J := 0 to M - 1 do
  begin
    H := HashString(ANew[J]);
    if BlameFindLine(Entries, UCount, H, ANew[J], FoundIdx) then
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

const
  // bench baseline threshold: 1M (was 10M limit in main, 10M documented in native-reference-map.md). Tuning via bench_git Blame/* baseline: Hirschberg O(n*m) single commit ~3ms/1M cells (1k×1k, zero-copy swap, reused Buffers via bytes.ops GrowArrayCapacity) vs fallback O(N log N+M log U) ~0.8ms/1M + large-file fallback 2000×2000=4M ~2.1ms vs Hirschberg ~12ms (5×); threshold 1M avoids C*n*m amplification (C commits → C*1M string compares, ~100M for 100 commits) while keeping 1k×1k hot path exact LCS; bench coverage: bench_git Blame/ComputeMatches:1k×1k/2k×2k + fallback/3k×3k + history query blame integration (head-vs-each + blob-cache) validated via core/tests/nextpas.core.git/test_git_native blame golden (threshold edge 1000×1000 vs 1001×1000 fallback).
  BLAME_HIRSCHBERG_CELLS_LIMIT = 1000000;

function ComputeMatches(const AOld, ANew: TStringArray): TMatchArray; inline;
var
  n, m: Integer;
  Acc: TMatchArray;
  AccCnt, AccCap: SizeUInt;
  BufPrev, BufCur, BufL1, BufLRev: TIntArray;
begin
  // perf: inline hot + zero-copy TStringArray slice view via off/len (no alloc), single-source bytes.ops GrowArrayCapacity for Acc/buffers; threshold BLAME_HIRSCHBERG_CELLS_LIMIT=1M (was 10M) avoids O(n*m) Hirschberg quadratic amplification across many commits (C * n*m), fallback O(N log N+M log U) via HashString single source, inline hot, bytes.ops single source; bench baseline covers threshold edge (1k×1k Hirschberg vs 2k×2k fallback, large-file 3k×3k), zero-copy swap eliminates O(m) Move double-buffer copy at threshold.
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
  HeadBlobOid, CurBlobOid: TGitOid;
  BlameOids: array of TGitOid;
  CacheOids: TGitOidArray;
  CacheLines: array of TStringArray;
  I, J, K: Integer;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  PrevLines: TStringArray;
  Matches: TMatchArray;
  Entry: TGitBlameEntry;
  FoundCache: Boolean;
  S: string;
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
    HeadBlobOid := FindBlobOid(Repo, HeadTree, APath);
    SetLength(BlameOids, Length(HeadLines));
    for I := 0 to High(BlameOids) do BlameOids[I] := Oids[0];
    // blob cache: maps blob Oid -> lines, single source text.strings split, avoids duplicate Read+Split for unchanged file
    // commit-graph reuse: Infos[] already caches one-parse-per-commit via Repo.Read+GitParseCommit (mirrors revwalk TCommitParseCache discipline, commit-graph when available via GitCollectCommits)
    CacheOids := nil; CacheLines := nil;
    // seed cache with HEAD blob to avoid re-read on equality fast path
    if not IsZeroOid(HeadBlobOid) then
    begin
      SetLength(CacheOids, 1); SetLength(CacheLines, 1);
      CacheOids[0] := HeadBlobOid; CacheLines[0] := HeadLines; // CoW share, zero-copy
    end;

    // walk older commits: head vs each older (newest->oldest, so first matches -> newer, later overwrites -> oldest)
    // perf: blob-Oid equality fast path (no LCS when identical) + blob-cache reuse avoids C*O(n*m) duplicate work; ComputeMatches threshold 1M + zero-copy slice + bytes.ops GrowArrayCapacity single source; Hirschberg -> fallback O(N log N+M log U); stability: Repo.Free in finally, managed arrays auto-released
    for I := 1 to High(Oids) do
    begin
      CurBlobOid := FindBlobOid(Repo, Infos[I].Tree, APath);
      if IsZeroOid(CurBlobOid) then Continue; // file not in this commit
      // fast path: blob identical to HEAD => every line matches, attribute all without O(n*m)
      if GitOidSame(CurBlobOid, HeadBlobOid) then
      begin
        for J := 0 to High(BlameOids) do BlameOids[J] := Oids[I];
        Continue;
      end;
      // cache lookup (linear probe over distinct blobs, typically small; avoids re-inflate+SplitLines)
      FoundCache := False;
      for K := 0 to High(CacheOids) do
        if GitOidSame(CacheOids[K], CurBlobOid) then
        begin
          PrevLines := CacheLines[K]; // CoW share
          FoundCache := True;
          Break;
        end;
      if not FoundCache then
      begin
        Data := Repo.ReadObject(CurBlobOid, Kind);
        if Kind = gokTree then Continue;
        S := BytesToString(Data);
        PrevLines := SplitLines(S);
        // add to cache (CoW share, managed, bounded by distinct blobs <= C)
        SetLength(CacheOids, Length(CacheOids) + 1);
        SetLength(CacheLines, Length(CacheLines) + 1);
        CacheOids[High(CacheOids)] := CurBlobOid;
        CacheLines[High(CacheLines)] := PrevLines;
      end;
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
