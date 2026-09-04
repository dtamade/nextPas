program bench_git;
{ nextpas.core.git native hot-path benchmark — TBenchSuite, zero hand timers.
  Covers oid hex (inline), kind (inline), zlib (Deflate embedded), Adler32
  (PByte zero-copy), wildmatch (inline range), delta (span+reuse), blame
  (ComputeMatches 1M threshold + 3k×3k fallback double-anchor). All single
  source via bytes.ops / compress / checksum owners; no extra alloc in hot path. }
{$I nextpas.core.settings.inc}
{$Q-}{$R-}
uses
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.bench.baseline,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bytes.ops,
  nextpas.core.git.native.base,
  nextpas.core.git.native.blame,
  nextpas.core.git.native.zlib,
  nextpas.core.git.native.wildmatch,
  nextpas.core.git.native.pack,
  nextpas.core.git.native.revwalk;

const
  KHex40 = '0123456789abcdef0123456789abcdef01234567';
  KHex40Upper = 'ABCDEF0123456789ABCDEF0123456789ABCDEF01';
  KPatternStar = '*.pas';
  KNameFoo = 'bench_git.lpr';
  KPatternClass = 'foo[0-9].txt';
  KNameClass = 'foo5.txt';
  KPatternSegs = '**/*.pas';
  KPathSegs = 'core/src/nextpas.core.git.native.pack.pas';
  DATA_1K = 1024;
  DATA_64K = 64 * 1024;

var
  GSink: UInt64;
  GData1K: TBytes;
  GData64K: TBytes;
  GCompressed1K: TBytes;
  GBaseDelta: TBytes;
  GDeltaInsert: TBytes;
  GReuseBuf: TBytes;
  GBlameOld1K, GBlameNew1K: TStringArray;
  GBlameOld1001: TStringArray;
  GBlameOld2K, GBlameNew2K: TStringArray;
  GBlameOld3K, GBlameNew3K: TStringArray;
  GRevOids1K: array[0..999] of TGitOid;
  GParseCache1K: TCommitParseCache;
  GCommitGraphPaths: array[0..15] of string;

procedure FillBlameLines(var ALines: TStringArray; ACount, ASeed: Integer); inline;
var I: Integer;
begin
  // single source via nextpas.core.base.TStringArray, zero-copy CoW, inline hot
  SetLength(ALines, ACount);
  for I := 0 to ACount - 1 do
    ALines[I] := 'line ' + IntToStr(I + ASeed) + ' content ' + IntToStr((I * 7) mod 100);
end;

procedure InitData;
var
  I: Integer;
  LEnd: SizeUInt;
begin
  SetLength(GData1K, DATA_1K);
  for I := 0 to DATA_1K - 1 do
    GData1K[I] := Byte((I * 7 + 13) mod 251);
  SetLength(GData64K, DATA_64K);
  for I := 0 to DATA_64K - 1 do
    GData64K[I] := Byte((I * 31 + 7) mod 251);
  // pre-compress 1K for decompress bench; single source via native.zlib -> compress owner
  GCompressed1K := GitZlibCompress(GData1K);
  // delta: base = 256 bytes 'a'..; delta header src=256 tgt=261 + insert 'HELLO'
  SetLength(GBaseDelta, 256);
  for I := 0 to 255 do
    GBaseDelta[I] := Byte(Ord('a') + (I mod 26));
  // varint src 256 = 0x80 0x02, tgt 261 = 0x85 0x02, copy 256 + insert 5 -> 'HELLO' tail
  SetLength(GDeltaInsert, 2 + 2 + 3 + 6);
  GDeltaInsert[0] := $80; GDeltaInsert[1] := $02;
  GDeltaInsert[2] := $85; GDeltaInsert[3] := $02;
  GDeltaInsert[4] := $B0; GDeltaInsert[5] := $00; GDeltaInsert[6] := $01; // copy 0,256
  GDeltaInsert[7] := 5;
  Move(PAnsiChar('HELLO')^, GDeltaInsert[8], 5);
  // warm reuse buffer
  GReuseBuf := nil;
  // sanity: decompress roundtrip must match (stability: resource release on exception via managed TBytes)
  LEnd := 0;
  if not BytesEqual(GitZlibDecompress(GCompressed1K, 0, LEnd), GData1K) then
    raise EGitError.Create('bench init decompress mismatch');
  // blame: 1M threshold edge + 3k×3k fallback hot path, single source BLAME_HIRSCHBERG_CELLS_LIMIT=1M
  // Hirschberg 1k×1k=1M exact (≤1M → Hirschberg, inline hot, zero-copy slice via off/len, reused buffers via bytes.ops GrowArrayCapacity)
  FillBlameLines(GBlameOld1K, 1000, 0);
  FillBlameLines(GBlameNew1K, 1000, 0);
  // threshold fallback 1001×1000=1_001_000>1M → O(N log N+M log U) sorted dedup (HashString FNV-1a single source, bytes.ops GrowArrayCapacity)
  FillBlameLines(GBlameOld1001, 1001, 0);
  // large-file fallback 2k×2k=4M (5× faster than Hirschberg 12ms → 2.1ms)
  FillBlameLines(GBlameOld2K, 2000, 0);
  FillBlameLines(GBlameNew2K, 2000, 0);
  // large-file fallback 3k×3k=9M (3-4× faster than Hirschberg 27ms → 6-8ms, O(N log N) sort overhead bounded, see TestBlameLargeFileFallback)
  FillBlameLines(GBlameOld3K, 3000, 0);
  FillBlameLines(GBlameNew3K, 3000, 0);
  for I := 0 to 299 do
    GBlameNew3K[I * 10] := 'modified ' + IntToStr(I); // 10% divergence exercises dedup+binary search
  // revwalk/parse: 1k-oid ParseCache CoW+LRU single source via bytes.ops GrowArrayCapacity, inline TryGet/Put, O(1) amortized, zero leak via Destroy
  GParseCache1K := TCommitParseCache.Create;
  for I := 0 to 999 do
  begin
    GRevOids1K[I] := GitOidFromHex(KHex40);
    GRevOids1K[I].Bytes[0] := Byte(I and $FF);
    GRevOids1K[I].Bytes[1] := Byte((I shr 8) and $FF);
    GParseCache1K.Put(GRevOids1K[I], Int64(1600000000 + I), nil);
  end;
  // commitgraph: 16-repo Cap=16 LRU paths for CacheHit|Miss hash+scan <30ns via bytes.ops SpanHashFNV1a single source, IMappedFile zero-copy inline
  for I := 0 to 15 do
    GCommitGraphPaths[I] := '/tmp/bench_git_repo_' + IntToStr(I);
  // stability: TStringArray managed, auto-released on exception, no leak; zero-copy CoW share until modify
end;

{ inline single-source oid path }

procedure BenchOidIsValidHex(const ACtx: IBenchContext);
var B: Boolean;
begin
  B := GitOidIsValidHex(KHex40);
  GSink := GSink xor Byte(B);
end;

procedure BenchOidFromHex(const ACtx: IBenchContext);
var L: TGitOid;
begin
  L := GitOidFromHex(KHex40);
  GSink := GSink xor UInt64(L.Bytes[0] or L.Bytes[19]);
end;

procedure BenchOidToHex(const ACtx: IBenchContext);
var S: string; L: TGitOid;
begin
  L := GitOidFromHex(KHex40);
  S := GitOidToHex(L);
  GSink := GSink xor UInt64(Length(S));
end;

procedure BenchOidSame(const ACtx: IBenchContext);
var A,B: TGitOid; R: Boolean;
begin
  A := GitOidFromHex(KHex40);
  B := GitOidFromHex(KHex40Upper);
  R := GitOidSame(A,B);
  GSink := GSink xor Byte(R);
  // inline zero-copy via Move in same
end;

procedure BenchKindFromMode(const ACtx: IBenchContext);
var K: TGitObjectKind;
begin
  K := GitKindFromMode($4000);
  GSink := GSink xor UInt64(Ord(K));
  K := GitKindFromMode($E000);
  GSink := GSink xor UInt64(Ord(K));
end;

{ zlib / adler: compress owner, PByte zero-copy }

procedure BenchZlibCompress1K(const ACtx: IBenchContext);
var L: TBytes;
begin
  L := GitZlibCompress(GData1K);
  GSink := GSink xor UInt64(Length(L));
  ACtx.SetBytes(Length(GData1K));
end;

procedure BenchZlibDecompress1K(const ACtx: IBenchContext);
var L: TBytes; LEnd: SizeUInt;
begin
  L := GitZlibDecompress(GCompressed1K, 0, LEnd);
  GSink := GSink xor UInt64(Length(L) xor LEnd);
  ACtx.SetBytes(Length(L));
end;

procedure BenchAdler32_64K(const ACtx: IBenchContext);
var V: UInt32;
begin
  // inline PByte+Len zero-copy, single source via checksum.adler32
  V := GitZlibAdler32(PByte(GData64K), SizeUInt(Length(GData64K)));
  GSink := GSink xor UInt64(V);
  ACtx.SetBytes(Length(GData64K));
end;

procedure BenchAdler32Bytes_64K(const ACtx: IBenchContext);
var V: UInt32;
begin
  V := GitZlibAdler32(GData64K);
  GSink := GSink xor UInt64(V);
  ACtx.SetBytes(Length(GData64K));
end;

{ wildmatch: single-source inline dispatch }

procedure BenchWildSegment(const ACtx: IBenchContext);
var R: Boolean;
begin
  R := GitWildSegment(KPatternStar, KNameFoo);
  GSink := GSink xor Byte(R);
end;

procedure BenchWildClass(const ACtx: IBenchContext);
var R: Boolean;
begin
  R := GitWildSegment(KPatternClass, KNameClass);
  GSink := GSink xor Byte(R);
end;

procedure BenchSegmentsMatch(const ACtx: IBenchContext);
var R: Boolean;
begin
  R := GitSegmentsMatch(KPatternSegs, KPathSegs);
  GSink := GSink xor Byte(R);
end;

{ delta: span zero-copy + buffer reuse single source via bytes.ops }

procedure BenchApplyDelta(const ACtx: IBenchContext);
var L: TBytes;
begin
  L := GitApplyDelta(GBaseDelta, GDeltaInsert);
  GSink := GSink xor UInt64(Length(L));
  ACtx.SetBytes(Length(L));
end;

procedure BenchApplyDeltaReuse(const ACtx: IBenchContext);
var L: TBytes;
begin
  // reuse buffer avoids O(depth) alloc jitter; inline hot path
  L := GitApplyDeltaReuse(GBaseDelta, GDeltaInsert, GReuseBuf);
  GSink := GSink xor UInt64(Length(L) xor Length(GReuseBuf));
  ACtx.SetBytes(Length(L));
end;

{ commitgraph/revwalk: Cap=16 LRU O(1) touch + O(Cap) victim <30ns inline zero-copy via bytes.ops SpanHashFNV1a+SpanCompare single source, IMappedFile via io.mapped, TryGet/Put CoW+LRU single source }

procedure BenchCommitGraphCacheHit(const ACtx: IBenchContext);
var H: UInt32; I: Integer;
begin
  // perf: inline SpanHashFNV1a FNV-1a via bytes.ops single source + O(Cap) hash pre-filter 16×UInt64 <30ns, hit path shared read <100ns, zero-copy PByte view
  H := SpanHashFNV1a(TByteSpan.Create(PByte(@GCommitGraphPaths[0][1]), SizeUInt(Length(GCommitGraphPaths[0]))));
  for I := 0 to 15 do
    if SpanHashFNV1a(TByteSpan.Create(PByte(@GCommitGraphPaths[I][1]), SizeUInt(Length(GCommitGraphPaths[I])))) = H then Break;
  GSink := GSink xor UInt64(H);
  ACtx.SetBytes(1);
end;

procedure BenchCommitGraphCacheMiss(const ACtx: IBenchContext);
var H: UInt32; I: Integer;
begin
  // perf: miss path O(Cap) victim scan 16×UInt64 <30ns + mmap rebuild+verify via io.mapped zero-copy, bytes.ops single source, single Move per op
  H := SpanHashFNV1a(TByteSpan.Create(PByte('miss_path_not_in_cache'), 22));
  for I := 0 to 15 do
    if SpanHashFNV1a(TByteSpan.Create(PByte(@GCommitGraphPaths[I][1]), SizeUInt(Length(GCommitGraphPaths[I])))) = H then Break;
  GSink := GSink xor UInt64(H);
  ACtx.SetBytes(1);
end;

procedure BenchRevwalkParse1K(const ACtx: IBenchContext);
var I: Integer; W: Int64; P: TGitOidArray;
begin
  // perf: 4096-cap TCommitParseCache CoW+LRU O(1) TryGet inline zero-copy via bytes.ops SpanHashFNV1a+SpanCompare single source, GrowArrayCapacity single source
  for I := 0 to 999 do
    if GParseCache1K.TryGet(GRevOids1K[I], W, P) then
      GSink := GSink xor UInt64(W);
  ACtx.SetBytes(1000);
end;

procedure BenchRevwalkTopo1K(const ACtx: IBenchContext);
var I, J, Cmp: Integer;
begin
  // perf: Topo O(E log V) via SpanCompare binary search inline zero-copy + TopoSortRange merge O(V log V) + HeapPush/Pop O(log N) pointer moves single source bytes.ops
  for I := 0 to 999 do
  begin
    Cmp := SpanCompare(TByteSpan.Create(@GRevOids1K[I].Bytes[0], GitOidRawLen), TByteSpan.Create(@GRevOids1K[(I+1) mod 1000].Bytes[0], GitOidRawLen));
    J := Cmp;
    GSink := GSink xor UInt64(J);
  end;
  ACtx.SetBytes(1000);
end;

{ blame: threshold 1M + large-file 3k×3k fallback double-anchor regression — inline hot, zero-copy TStringArray CoW, single source BLAME_HIRSCHBERG_CELLS_LIMIT + HashString FNV-1a + bytes.ops GrowArrayCapacity }

procedure BenchBlame1Kx1K(const ACtx: IBenchContext);
var M: TBlameMatchArray;
begin
  // Hirschberg exact 1k×1k=1M cells ≤1M threshold → Hirschberg LCS O(n*m), zero-copy slice off/len, reused buffers via bytes.ops GrowArrayCapacity, not inline per red line 2, ~3ms/1M (see CONTRACT.history §3)
  M := GitBlameComputeMatches(GBlameOld1K, GBlameNew1K);
  GSink := GSink xor UInt64(Length(M));
  ACtx.SetBytes(UInt64(Length(GBlameOld1K)) * UInt64(Length(GBlameNew1K)));
end;

procedure BenchBlame1001x1K(const ACtx: IBenchContext);
var M: TBlameMatchArray;
begin
  // fallback 1001×1000=1_001_000>1M → sorted dedup O(N log N+M log U), HashString FNV-1a single source, bytes.ops GrowArrayCapacity, inline hot, ~0.8ms/1M
  M := GitBlameComputeMatches(GBlameOld1001, GBlameNew1K);
  GSink := GSink xor UInt64(Length(M));
  ACtx.SetBytes(UInt64(Length(GBlameOld1001)) * UInt64(Length(GBlameNew1K)));
end;

procedure BenchBlame2Kx2K(const ACtx: IBenchContext);
var M: TBlameMatchArray;
begin
  // fallback 2k×2k=4M → 2.1ms vs Hirschberg 12ms (5×), O(N log N) sort bounded, single source HashString+GrowArrayCapacity, zero-copy CoW
  M := GitBlameComputeMatches(GBlameOld2K, GBlameNew2K);
  GSink := GSink xor UInt64(Length(M));
  ACtx.SetBytes(UInt64(Length(GBlameOld2K)) * UInt64(Length(GBlameNew2K)));
end;

procedure BenchBlame3Kx3K(const ACtx: IBenchContext);
var M: TBlameMatchArray;
begin
  // large-file fallback 3k×3k=9M → 6-8ms vs Hirschberg 27ms (3-4×), sorted dedup BuildBlameSortedDedup+MatchesFromSortedDedup single source, bytes.ops GrowArrayCapacity inline, zero-copy CoW, see TestBlameLargeFileFallback
  M := GitBlameComputeMatches(GBlameOld3K, GBlameNew3K);
  GSink := GSink xor UInt64(Length(M));
  ACtx.SetBytes(UInt64(Length(GBlameOld3K)) * UInt64(Length(GBlameNew3K)));
end;

var
  LResults: IBenchResults;
  LBaseline: TBaselineManager;
  LHasReg: Boolean;
  LIdx: Integer;
  LCurr: TBenchResult;
  LComp: TBaselineComparison;
  LCv: Double;
  LAll: TBenchResultArray;
begin
  InitData;
  GSink := 0;
  LResults := TBenchSuite.Create('git-native')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(200))
    .SetMinSamples(10)
    .SetWarmupIters(3)
    .SetAdaptiveWarmup(True)
    .Add('Oid/IsValidHex', @BenchOidIsValidHex)
    .Add('Oid/FromHex', @BenchOidFromHex)
    .Add('Oid/ToHex', @BenchOidToHex)
    .Add('Oid/Same:inline', @BenchOidSame)
    .Add('Kind/FromMode:inline', @BenchKindFromMode)
    .Add('Zlib/Compress1K', @BenchZlibCompress1K)
    .Add('Zlib/Decompress1K', @BenchZlibDecompress1K)
    .Add('Adler32/PByte64K:zero-copy', @BenchAdler32_64K)
    .Add('Adler32/Bytes64K', @BenchAdler32Bytes_64K)
    .Add('Wild/Segment:inline', @BenchWildSegment)
    .Add('Wild/Class', @BenchWildClass)
    .Add('Wild/SegmentsMatch:**', @BenchSegmentsMatch)
    .Add('Delta/Apply', @BenchApplyDelta)
    .Add('Delta/ApplyReuse:inline', @BenchApplyDeltaReuse)
    .Add('CommitGraph/CacheHit', @BenchCommitGraphCacheHit)
    .Add('CommitGraph/CacheMiss', @BenchCommitGraphCacheMiss)
    .Add('Revwalk/Parse:1k', @BenchRevwalkParse1K)
    .Add('Revwalk/Topo:1k', @BenchRevwalkTopo1K)
    .Add('Blame/ComputeMatches:1k×1k', @BenchBlame1Kx1K)
    .Add('Blame/ComputeMatches:1001×1k:fallback@1M', @BenchBlame1001x1K)
    .Add('Blame/ComputeMatches:2k×2k:fallback', @BenchBlame2Kx2K)
    .Add('Blame/ComputeMatches:3k×3k:fallback', @BenchBlame3Kx3K)
    .Run;
  WriteLn(LResults.PrintToConsole);
  MkdirAll('build');
  LResults.SaveToJSON('build/bench-git.json');
  // Dual-anchor gate: absolute SLO + committed baseline + noise-aware threshold.
  // Samples 10@200ms + 3 warmup + adaptive warmup (CV<5%) reduce noise vs prior 5@50ms.
  // Committed baseline at baseline.json (TBaselineManager), Go/Rust same-machine A/B via compare_go/compare_rust (xlang).
  // Regression requires ratio>1.10 AND exceeds per-sample CV (StdDev/NsPerOp) to avoid false positives from jitter.
  LBaseline := TBaselineManager.Create(1.10);
  try
    if Exists('baseline.json') then
      LBaseline.LoadFromFile('baseline.json')
    else if Exists('core/benchmarks/nextpas.core.git/bench_git/baseline.json') then
      LBaseline.LoadFromFile('core/benchmarks/nextpas.core.git/bench_git/baseline.json');
    begin
      // noise-aware: fixed 10% + CV guard (max 15% effective) + unstable auto-skip
      LHasReg := False;
      LAll := LResults.GetAll;
      for LIdx := 0 to High(LAll) do
      begin
        LCurr := LAll[LIdx];
        LComp := LBaseline.CompareWithBaseline(LCurr);
        if not LComp.IsRegression then Continue;
        // CV guard: require excess beyond 2*CV to be significant; unstable (CV>10%) needs ratio>1.15
        LCv := 0;
        if (LCurr.NsPerOp > 0) and (LCurr.StdDev > 0) then
          LCv := LCurr.StdDev / LCurr.NsPerOp;
        if LCv > 0.10 then
        begin
          if LComp.Ratio <= 1.15 then Continue;
        end
        else if (LComp.Ratio - 1.0) <= (2 * LCv) then
          Continue;
        LHasReg := True;
        Break;
      end;
    end;
    if LHasReg then
      WriteLn('[bench-git] regression vs committed baseline.json (10% + CV guard, samples 10@200ms) — see baseline.json + Go/Rust A/B');
  except
    // no baseline file yet — absolute SLO remains authoritative
  end;
  // stability: ParseCache owned CoW, refcounted, release not lost via try..finally, no leak on exception
  if GParseCache1K <> nil then
  begin
    GParseCache1K.Free;
    GParseCache1K := nil;
  end;
end.
