unit nextpas.core.git.native.commitgraph.writer;

{$I nextpas.core.settings.inc}

{ commit-graph v1 写入域: 排序 + BuildGraphBytes + Build/Write.
  WriteAll (全量收集) 归 collect 域, 经本域 BuildGraphBytes 落盘.
  依赖: base/reader/cache (commitgraph.*) + L0-L1 owner + repo/objmodel. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.commitgraph.base;

function BuildGraphBytes(const ARaw: TRawCommitArray): TBytes;
function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes;
function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1,
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.commitgraph.reader,
  nextpas.core.git.native.commitgraph.cache;

{ ── History.Writer: BuildGraphBytes (sort fanout/CDAT/EDGE + GDA2 skip) + Write* atomic+verify ── }

function CompareRawOid(const AA, AB: TRawCommit): Integer; inline;
begin
  // perf: inline + zero-copy TByteSpan view single-source via bytes.ops SpanCompare (→ CompareBytesOrdered single source, 20B ≈ 3×QWord), no temp copy, no dual track
  Result := SpanCompare(
    TByteSpan.Create(@AA.Oid.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AB.Oid.Bytes[0], GitOidRawLen));
end;

// owner: collections.arr.sort generic candidate closed — TRawCommit carries managed Parents: TGitOidArray
//   requires index-indirect hybrid quicksort (median-of-three + insertion cutoff 16, tail-recursion elimination)
//   to avoid O(n log n) AddRef/Release churn (20B int swaps + O(n) reorder vs record swaps); primitive
//   SortI32/U32 etc operate on pod ints only, not applicable; reuse satisfied via bytes.ops SpanCompare
//   single source + GrowArrayCapacity single source, not inline per red line 2 (loops/SIMD guard I-Cache)
procedure SortRawByOid(var A: TRawCommitArray);
var
  Idx: array of Integer;
  Tmp: TRawCommitArray;
  I: Integer;

  procedure SortIdxInsertion(AL, AR: Integer);
  var II, JJ, TT: Integer;
  begin
    for II := AL + 1 to AR do
    begin
      TT := Idx[II];
      JJ := II;
      while (JJ > AL) and (SpanCompare(
        TByteSpan.Create(@A[Idx[JJ - 1]].Oid.Bytes[0], GitOidRawLen),
        TByteSpan.Create(@A[TT].Oid.Bytes[0], GitOidRawLen)) > 0) do
      begin
        Idx[JJ] := Idx[JJ - 1];
        Dec(JJ);
      end;
      Idx[JJ] := TT;
    end;
  end;

  procedure SortIdxQuick(AL, AR: Integer);
  var II, JJ: Integer; Pivot: TGitOid; TT: Integer;
  begin
    // hybrid quicksort on indices: median-of-three + insertion cutoff 16, tail recursion elimination
    // perf: index-indirect avoids TRawCommit managed Parents AddRef/Release per swap (20B int vs record with dynamic array),
    //   O(n log n) integer swaps + single O(n) reorder (one AddRef per element) vs O(n log n) record swaps
    while AL < AR do
    begin
      if AR - AL < 16 then
      begin
        SortIdxInsertion(AL, AR);
        Exit;
      end;
      II := AL;
      JJ := AR;
      if SpanCompare(TByteSpan.Create(@A[Idx[AL]].Oid.Bytes[0], GitOidRawLen),
        TByteSpan.Create(@A[Idx[(AL + AR) shr 1]].Oid.Bytes[0], GitOidRawLen)) > 0 then
      begin TT := Idx[AL]; Idx[AL] := Idx[(AL + AR) shr 1]; Idx[(AL + AR) shr 1] := TT; end;
      if SpanCompare(TByteSpan.Create(@A[Idx[(AL + AR) shr 1]].Oid.Bytes[0], GitOidRawLen),
        TByteSpan.Create(@A[Idx[AR]].Oid.Bytes[0], GitOidRawLen)) > 0 then
      begin TT := Idx[(AL + AR) shr 1]; Idx[(AL + AR) shr 1] := Idx[AR]; Idx[AR] := TT; end;
      if SpanCompare(TByteSpan.Create(@A[Idx[AL]].Oid.Bytes[0], GitOidRawLen),
        TByteSpan.Create(@A[Idx[(AL + AR) shr 1]].Oid.Bytes[0], GitOidRawLen)) > 0 then
      begin TT := Idx[AL]; Idx[AL] := Idx[(AL + AR) shr 1]; Idx[(AL + AR) shr 1] := TT; end;
      Pivot := A[Idx[(AL + AR) shr 1]].Oid; // pivot by value (20B), zero-copy via stack
      repeat
        while SpanCompare(TByteSpan.Create(@A[Idx[II]].Oid.Bytes[0], GitOidRawLen),
          TByteSpan.Create(@Pivot.Bytes[0], GitOidRawLen)) < 0 do Inc(II);
        while SpanCompare(TByteSpan.Create(@A[Idx[JJ]].Oid.Bytes[0], GitOidRawLen),
          TByteSpan.Create(@Pivot.Bytes[0], GitOidRawLen)) > 0 do Dec(JJ);
        if II <= JJ then
        begin
          TT := Idx[II]; Idx[II] := Idx[JJ]; Idx[JJ] := TT; // integer swap, zero managed churn
          Inc(II); Dec(JJ);
        end;
      until II > JJ;
      if (JJ - AL) < (AR - II) then
      begin
        if AL < JJ then SortIdxQuick(AL, JJ);
        AL := II;
      end
      else
      begin
        if II < AR then SortIdxQuick(II, AR);
        AR := JJ;
      end;
    end;
  end;

begin
  if Length(A) < 2 then Exit;
  SetLength(Idx, Length(A));
  for I := 0 to High(Idx) do Idx[I] := I;
  SortIdxQuick(0, High(Idx));
  // single O(n) reorder: one AddRef per element vs O(n log n) swaps (TRawCommit contains Parents: TGitOidArray managed)
  Tmp := Copy(A, 0, Length(A));
  for I := 0 to High(A) do
    A[I] := Tmp[Idx[I]];
end;

function FindOidIndex(const ASorted: TRawCommitArray; const AOid: TGitOid): Integer;
var Lo, Hi, Mid, Cmp: Integer;
begin
  // not inline: binary-search loop per design-conventions inline red line 2 — I-Cache guard
  // perf: zero-copy TByteSpan view single-source via bytes.ops SpanCompare (→ CompareBytesOrdered, 20B ≈ 3×QWord), no per-byte loop
  Lo := 0; Hi := High(ASorted);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    Cmp := SpanCompare(
      TByteSpan.Create(@ASorted[Mid].Oid.Bytes[0], GitOidRawLen),
      TByteSpan.Create(@AOid.Bytes[0], GitOidRawLen));
    if Cmp = 0 then Exit(Mid);
    if Cmp < 0 then Lo := Mid + 1 else Hi := Mid - 1;
  end;
  Result := -1;
end;

procedure WriteBE32(var ADst: TBytes; var APos: SizeInt; AVal: Cardinal);
begin
  ADst[APos] := Byte(AVal shr 24); ADst[APos+1] := Byte(AVal shr 16);
  ADst[APos+2] := Byte(AVal shr 8); ADst[APos+3] := Byte(AVal);
  Inc(APos, 4);
end;

function BuildGraphBytes(const ARaw: TRawCommitArray): TBytes;
var N, NumExtra, I, J, K, PIdx, ParentIdx: Integer;
    Extra: array of Cardinal;
    Fanout: array[0..255] of Cardinal;
    RawSorted: TRawCommitArray;
    Counts: array[0..255] of Cardinal;
    HasEdge: Boolean;
    ChunkCount: Integer;
    DataStart, OidfOff, OidlOff, CdatOff, Gda2Off, EdgeOff, TrailerOff, TotalSize: SizeInt;
    Pos: SizeInt;
    GenField, TimeLow: Cardinal;
    P1, P2: Cardinal;
    TmpHash: TBytes;
    H: IHasher;
    TmpIdx: Integer;
    ParentCache: array of array of Integer;
    GenState: array of Byte;
    Stack: array of Integer;
    CurIdx, PMax, CntP: Integer;
    HasPending: Boolean;
    StackLen, StackCap: SizeUInt;
begin
  Result := nil;
  N := Length(ARaw);
  if N = 0 then
    raise EGitError.Create('commit-graph: empty commit set');
  RawSorted := Copy(ARaw, 0, N);
  SortRawByOid(RawSorted);
  // compute fanout counts
  for I := 0 to 255 do Counts[I] := 0;
  for I := 0 to N-1 do Inc(Counts[RawSorted[I].Oid.Bytes[0]]);
  Fanout[0] := Counts[0];
  for I := 1 to 255 do Fanout[I] := Fanout[I-1] + Counts[I];
  // collect extra edges
  SetLength(Extra, 0);
  NumExtra := 0;
  for I := 0 to N-1 do
  begin
    if Length(RawSorted[I].Parents) > 2 then
      Inc(NumExtra, Length(RawSorted[I].Parents) - 1); // need extra entries for parents 1..N-1 except first? Actually need N-1 entries after first? For octopus with k parents, need k-1 extra entries (all except first)
  end;
  // compute generations O(n log n) via memo DFS + parent-index cache (replaces N*4 fixpoint O(n²))
  // zero-copy: FindOidIndex binary search on OID bytes (no OID copy, not inline per red line 2); DP uses indices only
  // state-array + explicit stack: O(n) after sort, stable, EGitError propagates (no swallow)
  for I := 0 to N-1 do
    if RawSorted[I].Generation = 0 then
    begin
      if Length(RawSorted[I].Parents) = 0 then
        RawSorted[I].Generation := 1
      else
        RawSorted[I].Generation := 0; // placeholder, computed below
    end;
  // parent index cache: O(n log n) total instead of O(n² log n)
  // managed dynamic arrays: auto released on exception, no leak
  if N > 0 then
  begin
    SetLength(ParentCache, N);
    SetLength(GenState, N);
    for I := 0 to N-1 do
    begin
      CntP := Length(RawSorted[I].Parents);
      SetLength(ParentCache[I], CntP);
      for K := 0 to CntP - 1 do
        ParentCache[I][K] := FindOidIndex(RawSorted, RawSorted[I].Parents[K]);
      if RawSorted[I].Generation <> 0 then
        GenState[I] := 2
      else
        GenState[I] := 0;
    end;
    // perf: geometric growth via bytes.ops GrowArrayCapacity (single source BYTES_BUILDER_MIN_GROW + *2), amortized O(1) push, avoids O(n²) SetLength(Length+1) churn, managed free on exception
    StackLen := 0; StackCap := 0; SetLength(Stack, 0);
    for I := 0 to N-1 do
    begin
      if GenState[I] = 2 then Continue;
      // push root of DFS — amortized geometric grow, inline
      if StackLen >= StackCap then
      begin
        StackCap := GrowArrayCapacity(StackCap, StackLen + 1);
        SetLength(Stack, StackCap);
      end;
      Stack[StackLen] := I; Inc(StackLen);
      while StackLen > 0 do
      begin
        CurIdx := Stack[StackLen - 1];
        if GenState[CurIdx] = 2 then
        begin
          Dec(StackLen);
          Continue;
        end;
        if GenState[CurIdx] = 0 then
        begin
          GenState[CurIdx] := 1;
          HasPending := False;
          for K := 0 to High(ParentCache[CurIdx]) do
          begin
            ParentIdx := ParentCache[CurIdx][K];
            if (ParentIdx >= 0) and (GenState[ParentIdx] = 0) then
            begin
              if StackLen >= StackCap then
              begin
                StackCap := GrowArrayCapacity(StackCap, StackLen + 1);
                SetLength(Stack, StackCap);
              end;
              Stack[StackLen] := ParentIdx; Inc(StackLen);
              HasPending := True;
            end
            else if (ParentIdx >= 0) and (GenState[ParentIdx] = 1) then
            begin
              // cycle: break by treating parent as generation 0 (will fallback to 2)
            end;
          end;
          if HasPending then Continue; // parents will be resolved first
        end;
        // all parents resolved or missing: compute max
        PMax := 0;
        for K := 0 to High(ParentCache[CurIdx]) do
        begin
          ParentIdx := ParentCache[CurIdx][K];
          if (ParentIdx >= 0) and (RawSorted[ParentIdx].Generation > Cardinal(PMax)) then
            PMax := Integer(RawSorted[ParentIdx].Generation);
        end;
        if PMax > 0 then
          RawSorted[CurIdx].Generation := Cardinal(PMax + 1)
        else if Length(RawSorted[CurIdx].Parents) = 0 then
          RawSorted[CurIdx].Generation := 1
        else
          RawSorted[CurIdx].Generation := 2;
        GenState[CurIdx] := 2;
        Dec(StackLen);
      end;
    end;
    // ParentCache/GenState/Stack are managed types, freed on exit even if EGitError; Stack capacity retained until scope exit, no leak, zero-copy Move in Push
  end;
  for I := 0 to N-1 do
    if RawSorted[I].Generation = 0 then
      RawSorted[I].Generation := 1;
  HasEdge := NumExtra > 0;
  ChunkCount := 3 + Ord(HasEdge);
  DataStart := 8 + ChunkCount * 12 + 12;
  OidfOff := DataStart;
  OidlOff := OidfOff + 256*4;
  CdatOff := OidlOff + N*20;
  // no GDA2 for minimal compatibility; git verify accepts missing GDA2
  Gda2Off := 0;
  EdgeOff := CdatOff + N*36;
  if not HasEdge then
    TrailerOff := EdgeOff
  else
    TrailerOff := EdgeOff + NumExtra*4;
  TotalSize := TrailerOff + 20;
  SetLength(Result, TotalSize);
  Pos := 0;
  // header
  WriteBE32(Result, Pos, CGPH_MAGIC);
  Result[Pos] := CGPH_VERSION; Inc(Pos);
  Result[Pos] := CGPH_OID_VERSION; Inc(Pos);
  Result[Pos] := Byte(ChunkCount); Inc(Pos);
  Result[Pos] := 0; Inc(Pos);
  // chunk TOC
  WriteBE32(Result, Pos, CHUNK_OIDF);
  WriteBE32(Result, Pos, Cardinal(OidfOff shr 32));
  WriteBE32(Result, Pos, Cardinal(OidfOff and $FFFFFFFF));
  WriteBE32(Result, Pos, CHUNK_OIDL);
  WriteBE32(Result, Pos, Cardinal(OidlOff shr 32));
  WriteBE32(Result, Pos, Cardinal(OidlOff and $FFFFFFFF));
  WriteBE32(Result, Pos, CHUNK_CDAT);
  WriteBE32(Result, Pos, Cardinal(CdatOff shr 32));
  WriteBE32(Result, Pos, Cardinal(CdatOff and $FFFFFFFF));
  if HasEdge then
  begin
    WriteBE32(Result, Pos, CHUNK_EDGE);
    WriteBE32(Result, Pos, Cardinal(EdgeOff shr 32));
    WriteBE32(Result, Pos, Cardinal(EdgeOff and $FFFFFFFF));
  end;
  // terminator: id 0 + trailer offset
  WriteBE32(Result, Pos, 0);
  WriteBE32(Result, Pos, Cardinal(TrailerOff shr 32));
  WriteBE32(Result, Pos, Cardinal(TrailerOff and $FFFFFFFF));
  // OIDF
  for I := 0 to 255 do WriteBE32(Result, Pos, Fanout[I]);
  // OIDL
  for I := 0 to N-1 do
  begin
    // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, no heap, 20B Oid), replaces scattered Move dual path
    SpanCopy(TByteSpan.Create(@Result[Pos], 20),
      TByteSpan.Create(@RawSorted[I].Oid.Bytes[0], 20));
    Inc(Pos, 20);
  end;
  // prepare extra offsets map: for each commit with octopus, record start index in Extra
  // we need to fill CDAT and EDGE together
  // first compute Extra array with proper last-bit
  SetLength(Extra, NumExtra);
  J := 0;
  for I := 0 to N-1 do
  begin
    if Length(RawSorted[I].Parents) > 2 then
    begin
      // parents 1..k-1 go to extra (all except first)
      for PIdx := 1 to High(RawSorted[I].Parents) do
      begin
        TmpIdx := FindOidIndex(RawSorted, RawSorted[I].Parents[PIdx]);
        if TmpIdx < 0 then
          TmpIdx := Integer(MISSING_PARENT);
        Extra[J] := Cardinal(TmpIdx);
        if PIdx = High(RawSorted[I].Parents) then
          Extra[J] := Extra[J] or EDGE_LAST_MASK;
        Inc(J);
      end;
    end;
  end;
  // CDAT
  J := 0; // extra cursor for start offset
  // need start offsets for each octopus commit
  // compute start per commit by scanning
  for I := 0 to N-1 do
  begin
    // tree oid — perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces scattered Move
    SpanCopy(TByteSpan.Create(@Result[Pos], 20),
      TByteSpan.Create(@RawSorted[I].TreeOid.Bytes[0], 20));
    Inc(Pos, 20);
    // parents
    if Length(RawSorted[I].Parents) = 0 then
    begin
      P1 := MISSING_PARENT; P2 := MISSING_PARENT;
    end
    else if Length(RawSorted[I].Parents) = 1 then
    begin
      PIdx := FindOidIndex(RawSorted, RawSorted[I].Parents[0]);
      if PIdx < 0 then P1 := MISSING_PARENT else P1 := Cardinal(PIdx);
      P2 := MISSING_PARENT;
    end
    else if Length(RawSorted[I].Parents) = 2 then
    begin
      PIdx := FindOidIndex(RawSorted, RawSorted[I].Parents[0]);
      if PIdx < 0 then P1 := MISSING_PARENT else P1 := Cardinal(PIdx);
      PIdx := FindOidIndex(RawSorted, RawSorted[I].Parents[1]);
      if PIdx < 0 then P2 := MISSING_PARENT else P2 := Cardinal(PIdx);
    end
    else
    begin
      PIdx := FindOidIndex(RawSorted, RawSorted[I].Parents[0]);
      if PIdx < 0 then P1 := MISSING_PARENT else P1 := Cardinal(PIdx);
      // find start offset for this commit in Extra
      // start = cumulative extra before this commit
      // compute by scanning previous octopus commits
      P2 := 0;
      // compute start index
      // we can precompute by walking
      // simplest: maintain running extraIdx
      // But we already have J cursor marking start for this commit if octopus
      // For octopus, we need to know start offset = number of extra entries before this commit
      // We'll compute on the fly by counting extra before
      // To avoid double calc, we can keep variable ExtraStart
      // Use J as start
      P2 := Cardinal(J) or EDGE_LAST_MASK; // high bit indicates extra
      J := J + (Length(RawSorted[I].Parents) - 1);
    end;
    WriteBE32(Result, Pos, P1);
    WriteBE32(Result, Pos, P2);
    GenField := (RawSorted[I].Generation shl 2) or Cardinal((RawSorted[I].CommitTime shr 32) and $3);
    TimeLow := Cardinal(RawSorted[I].CommitTime and $FFFFFFFF);
    WriteBE32(Result, Pos, GenField);
    WriteBE32(Result, Pos, TimeLow);
  end;
  // EDGE
  for I := 0 to High(Extra) do WriteBE32(Result, Pos, Extra[I]);
  // trailer SHA-1
  H := NewSHA1;
  H.Write(Result[0], SizeUInt(TrailerOff));
  TmpHash := H.SumBytes;
  // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B hash), replaces scattered Move
  SpanCopy(TByteSpan.Create(@Result[Pos], 20),
    TByteSpan.Create(@TmpHash[0], 20));
end;

function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes;
var Raw: TRawCommitArray;
    Repo: TNativeRepository;
    I: Integer;
    Kind: TGitObjectKind;
    Data: TBytes;
    Info: TGitCommitInfo;
begin
  if Length(AOids) = 0 then
    raise EGitError.Create('commit-graph: empty oid set');
  Repo := TNativeRepository.Create(AGitDir);
  try
    SetLength(Raw, Length(AOids));
    for I := 0 to High(AOids) do
    begin
      Data := Repo.ReadObject(AOids[I], Kind);
      if Kind = gokTag then Data := Repo.ReadObject(GitParseTag(Data).Target, Kind);
      if Kind <> gokCommit then
        raise EGitError.CreateFmt('commit-graph: oid %s is not a commit', [GitOidToHex(AOids[I])]);
      Info := GitParseCommit(Data);
      Raw[I].Oid := AOids[I];
      Raw[I].TreeOid := Info.Tree;
      Raw[I].CommitTime := Info.Committer.UnixTime;
      Raw[I].Parents := Info.Parents;
      Raw[I].Generation := 0;
    end;
    Result := BuildGraphBytes(Raw);
  finally
    Repo.Free;
  end;
end;

function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string;
var Data: TBytes;
    Path: string;
    G: TCommitGraph;
begin
  Data := GitBuildCommitGraph(AGitDir, AOids);
  Path := PathJoin([AGitDir, 'objects', 'info', 'commit-graph']);
  MkdirAll(PathDir(Path), PermDirDefault);
  WriteAtomic(Path, Data);
  InvalidateCommitGraphCache(AGitDir);
  // deep verify: reload and checksum
  G := TCommitGraph.Create(Data);
  try
    if G.NumCommits <> Cardinal(Length(AOids)) then
      raise EGitError.Create('commit-graph verify: count mismatch');
  finally
    G.Free;
  end;
  if not GitVerifyCommitGraph(AGitDir) then
    raise EGitError.Create('commit-graph verify failed');
  Result := Path;
end;

end.
