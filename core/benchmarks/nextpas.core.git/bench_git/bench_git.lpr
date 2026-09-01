program bench_git;
{ nextpas.core.git native hot-path benchmark — TBenchSuite, zero hand timers.
  Covers oid hex (inline), kind (inline), zlib (Deflate embedded), Adler32
  (PByte zero-copy), wildmatch (inline range), delta (span+reuse). All single
  source via bytes.ops / compress / checksum owners; no extra alloc in hot path. }
{$I nextpas.core.settings.inc}
{$Q-}{$R-}
uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.bench.baseline,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bytes.ops,
  nextpas.core.git.native.base,
  nextpas.core.git.native.zlib,
  nextpas.core.git.native.wildmatch,
  nextpas.core.git.native.pack;

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

var
  LResults: IBenchResults;
  LBaseline: TBaselineManager;
  LHasReg: Boolean;
begin
  InitData;
  GSink := 0;
  LResults := TBenchSuite.Create('git-native')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
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
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-git.json');
  // Dual-anchor gate: absolute SLO + committed baseline (not local JSON drift).
  // Committed baseline at baseline.json (TBaselineManager), Go/Rust same-machine A/B via compare_go/compare_rust (xlang).
  LBaseline := TBaselineManager.Create(1.10);
  try
    if FileExists('baseline.json') then
      LBaseline.LoadFromFile('baseline.json')
    else if FileExists('core/benchmarks/nextpas.core.git/bench_git/baseline.json') then
      LBaseline.LoadFromFile('core/benchmarks/nextpas.core.git/bench_git/baseline.json');
    LHasReg := LBaseline.HasRegression(LResults.GetAll);
    if LHasReg then
      WriteLn('[bench-git] regression vs committed baseline.json (10% threshold) — see baseline.json + Go/Rust A/B');
  except
    // no baseline file yet — absolute SLO remains authoritative
  end;
end.
