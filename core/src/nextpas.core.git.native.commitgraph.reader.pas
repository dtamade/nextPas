unit nextpas.core.git.native.commitgraph.reader;

{$I nextpas.core.settings.inc}

{ commit-graph v1 读取域: TCommitGraph 解析/查找 + TryLoad/Verify/Path.
  TryLoad 经 cache 域命中/落盘 (Stat.mtime+size 校验 + IMappedFile 零堆复制);
  缺文件非错 (调用方回退对象解析), 在场损坏抛 EGitError.
  依赖: base (commitgraph.base/cache) + L0-L1 owner. }

interface

uses
  nextpas.core.base,
  nextpas.core.io.mapped,
  nextpas.core.git.native.base,
  nextpas.core.git.native.commitgraph.base;

type
  TCommitGraph = class
  private
    FData: TBytes;
    FMapped: IMappedFile;
    FView: PByte;
    FViewLen: SizeInt;
    FNumCommits: Cardinal;
    FFanout: array[0..255] of Cardinal;
    FOidLookupOff: SizeInt;
    FCommitDataOff: SizeInt;
    FExtraOff: SizeInt;
    FNumExtra: Cardinal;
    function BE32At(APos: SizeInt): Cardinal; inline;
    function CompareOidAt(AIdx: Cardinal; const AOid: TGitOid): Integer;
    function FindPos(const AOid: TGitOid): Integer;
    procedure InitFromView(AData: PByte; ALen: SizeInt);
    procedure InitFromData(const AData: TBytes);
    procedure InitFromMapped(const AMapped: IMappedFile);
  public
    constructor Create(const AData: TBytes);
    constructor CreateFromMapped(const AMapped: IMappedFile);
    destructor Destroy; override;
    property NumCommits: Cardinal read FNumCommits;
    function TryFind(const AOid: TGitOid; out AEntry: TCommitGraphEntry): Boolean;
  end;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean;
function GitCommitGraphPath(const AGitDir: string): string;
function GitVerifyCommitGraph(const AGitDir: string): Boolean;

implementation

uses
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1, // git-native-commitgraph-l2-exempt: L2 git→hash.sha1 single-source via bytes.ops, registry core/docs/core-module-registry.md git row (C5 zlib anchor pattern)
  nextpas.core.git.native.commitgraph.cache;

{ ── History.Reader: BE32+TByteSpan zero-copy via bytes.ops, fanout+OIDL verify ── }

function Sha1OfBytes(const AData: TBytes): TBytes;
var
  H: IHasher;
begin
  Result := nil;
  H := NewSHA1;
  if Length(AData) > 0 then
    H.Write(AData[0], Length(AData));
  Result := H.SumBytes;
end;

function TCommitGraph.BE32At(APos: SizeInt): Cardinal; inline;
begin
  // perf: inline + zero-copy PByte single-source via bytes.binary ReadUInt32BE (no TBytes copy, 4B BE single source), FView is live zero-copy window (mmap or heap, bytes.ops single source)
  Result := ReadUInt32BE(FView + APos);
end;

function OidRawCompare(const AA, AB: TGitOid): Integer; inline;
begin
  // perf: inline + zero-copy TByteSpan view single-source via bytes.ops SpanCompare (→ CompareBytesOrdered → System.CompareByte, 20B ≈ 3×QWord), no 20× byte loop
  Result := SpanCompare(
    TByteSpan.Create(@AA.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AB.Bytes[0], GitOidRawLen));
end;

function TCommitGraph.CompareOidAt(AIdx: Cardinal; const AOid: TGitOid): Integer; inline;
var
  P: PByte;
begin
  // perf: inline + zero-copy PByte view single-source via bytes.ops SpanCompare (→ CompareBytesOrdered/SIMD, 20B ≈ 3×QWord), no per-byte loop
  P := FView + FOidLookupOff + SizeInt(AIdx) * GitOidRawLen;
  Result := SpanCompare(
    TByteSpan.Create(P, GitOidRawLen),
    TByteSpan.Create(@AOid.Bytes[0], GitOidRawLen));
end;

function TCommitGraph.FindPos(const AOid: TGitOid): Integer;
var
  B: Byte;
  Lo, Hi, Mid, Cmp: Integer;
begin
  Result := -1;
  if FNumCommits = 0 then
    Exit;
  B := AOid.Bytes[0];
  if B = 0 then
    Lo := 0
  else
    Lo := Integer(FFanout[B - 1]);
  Hi := Integer(FFanout[B]) - 1;
  if Hi < Lo then
    Exit;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    Cmp := CompareOidAt(Cardinal(Mid), AOid);
    if Cmp = 0 then
      Exit(Mid);
    if Cmp < 0 then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
end;

procedure TCommitGraph.InitFromData(const AData: TBytes);
begin
  // perf: heap path via bytes.ops single source view (FData owns heap, FView zero-copy window, inline BE32At via bytes ops), FMapped nil for heap
  // stability: managed TBytes auto released on exception, FView zero-copy window via bytes.ops single source
  FData := AData;
  FMapped := nil;
  if Length(FData) > 0 then
    InitFromView(@FData[0], Length(FData))
  else
    InitFromView(nil, 0);
end;

procedure TCommitGraph.InitFromView(AData: PByte; ALen: SizeInt);
var
  DataLen, HeaderSize, TrailerOff, DataStart, LastOff, ChunkOff: SizeInt;
  Chunks, I, J, K: Integer;
  Magic, ChunkId: Cardinal;
  Version, OidVer, BaseGraphs: Byte;
  Hi, Lo: Cardinal;
  Off64: Int64;
  FanoutOff, LookupOff, CDataOff, ExtraOff: SizeInt;
  FanoutLen, LookupLen, CDataLen, ExtraLen: SizeInt;
  BIdxOff, BDatOff, Gda2Off, Gdo2Off: SizeInt;
  Computed: TBytes;
  H: IHasher;
  Prev, Curr: TGitOid;
  TmpOid: TGitOid;
  ChunksPresent: array of TChunkRec;
  Cnt: Integer;
  Tmp: TChunkRec;
begin
  // perf: zero-copy PByte view single-source via bytes.ops, FView window over heap or mmap, inline BE32At via bytes.ops, OS page-reclaimable for mmap
  FView := AData;
  FViewLen := ALen;
  DataLen := FViewLen;
  if DataLen < 8 + 20 then
    raise EGitError.Create('commit-graph too short');
  Magic := BE32At(0);
  if Magic <> CGPH_MAGIC then
    raise EGitError.Create('commit-graph bad signature');
  Version := FView[4];
  OidVer := FView[5];
  Chunks := Integer(FView[6]);
  BaseGraphs := FView[7];
  if (Version <> CGPH_VERSION) or (OidVer <> CGPH_OID_VERSION) then
    raise EGitError.Create('unsupported commit-graph version');
  if Chunks = 0 then
    raise EGitError.Create('commit-graph has no chunks');
  if BaseGraphs <> 0 then
    raise EGitError.Create('commit-graph base graphs not supported');
  HeaderSize := 8;
  DataStart := HeaderSize + Chunks * 12 + 12;
  TrailerOff := DataLen - GitOidRawLen;
  if TrailerOff < DataStart then
    raise EGitError.Create('commit-graph wrong size');
  // perf: zero-copy PByte view direct to hasher (no TrailerOff allocation nor Move), inline SHA-1; stability: managed TBytes/IHasher auto released on exception, FView zero-copy via bytes.ops
  H := NewSHA1;
  if TrailerOff > 0 then
    H.Write(FView[0], SizeUInt(TrailerOff));
  Computed := H.SumBytes;
  for I := 0 to GitOidRawLen - 1 do
    if Computed[I] <> FView[TrailerOff + I] then
      raise EGitError.Create('commit-graph checksum mismatch');
  FanoutOff := -1;
  LookupOff := -1;
  CDataOff := -1;
  ExtraOff := -1;
  BIdxOff := -1;
  BDatOff := -1;
  Gda2Off := -1;
  Gdo2Off := -1;
  FanoutLen := 0;
  LookupLen := 0;
  CDataLen := 0;
  ExtraLen := 0;
  LastOff := DataStart;
  for I := 0 to Chunks - 1 do
  begin
    ChunkId := BE32At(HeaderSize + I * 12);
    Hi := BE32At(HeaderSize + I * 12 + 4);
    Lo := BE32At(HeaderSize + I * 12 + 8);
    Off64 := (Int64(Hi) shl 32) or Int64(Lo);
    ChunkOff := SizeInt(Off64);
    if ChunkOff < LastOff then
      raise EGitError.Create('commit-graph chunks non-monotonic');
    if ChunkOff > TrailerOff then
      raise EGitError.Create('commit-graph chunk beyond trailer');
    case ChunkId of
      CHUNK_OIDF: FanoutOff := ChunkOff;
      CHUNK_OIDL: LookupOff := ChunkOff;
      CHUNK_CDAT: CDataOff := ChunkOff;
      CHUNK_EDGE: ExtraOff := ChunkOff;
      CHUNK_BIDX: BIdxOff := ChunkOff;
      CHUNK_BDAT: BDatOff := ChunkOff;
      CHUNK_GDA2: Gda2Off := ChunkOff;
      CHUNK_GDO2: Gdo2Off := ChunkOff;
    else
      raise EGitError.CreateFmt('commit-graph unrecognized chunk %x', [ChunkId]);
    end;
    LastOff := ChunkOff;
  end;
  Cnt := 0;
  SetLength(ChunksPresent, 8);
  if FanoutOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_OIDF;
    ChunksPresent[Cnt].Off := FanoutOff;
    Inc(Cnt);
  end;
  if LookupOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_OIDL;
    ChunksPresent[Cnt].Off := LookupOff;
    Inc(Cnt);
  end;
  if CDataOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_CDAT;
    ChunksPresent[Cnt].Off := CDataOff;
    Inc(Cnt);
  end;
  if ExtraOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_EDGE;
    ChunksPresent[Cnt].Off := ExtraOff;
    Inc(Cnt);
  end;
  if BIdxOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_BIDX;
    ChunksPresent[Cnt].Off := BIdxOff;
    Inc(Cnt);
  end;
  if BDatOff >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_BDAT;
    ChunksPresent[Cnt].Off := BDatOff;
    Inc(Cnt);
  end;
  if Gda2Off >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_GDA2;
    ChunksPresent[Cnt].Off := Gda2Off;
    Inc(Cnt);
  end;
  if Gdo2Off >= 0 then
  begin
    ChunksPresent[Cnt].Id := CHUNK_GDO2;
    ChunksPresent[Cnt].Off := Gdo2Off;
    Inc(Cnt);
  end;
  SetLength(ChunksPresent, Cnt);
  for I := 1 to Cnt - 1 do
  begin
    Tmp := ChunksPresent[I];
    J := I - 1;
    while (J >= 0) and (ChunksPresent[J].Off > Tmp.Off) do
    begin
      ChunksPresent[J + 1] := ChunksPresent[J];
      Dec(J);
    end;
    ChunksPresent[J + 1] := Tmp;
  end;
  for I := 0 to Cnt - 1 do
  begin
    if I < Cnt - 1 then
      ChunkOff := ChunksPresent[I + 1].Off
    else
      ChunkOff := TrailerOff;
    case ChunksPresent[I].Id of
      CHUNK_OIDF: FanoutLen := ChunkOff - ChunksPresent[I].Off;
      CHUNK_OIDL: LookupLen := ChunkOff - ChunksPresent[I].Off;
      CHUNK_CDAT: CDataLen := ChunkOff - ChunksPresent[I].Off;
      CHUNK_EDGE: ExtraLen := ChunkOff - ChunksPresent[I].Off;
    end;
  end;
  if (FanoutOff < 0) or (LookupOff < 0) or (CDataOff < 0) then
    raise EGitError.Create('commit-graph missing mandatory chunk');
  if FanoutLen <> 256 * 4 then
    raise EGitError.Create('commit-graph OIDF wrong length');
  if CDataLen = 0 then
    raise EGitError.Create('commit-graph CDAT empty');
  for I := 0 to 255 do
    FFanout[I] := BE32At(FanoutOff + I * 4);
  for I := 1 to 255 do
    if FFanout[I] < FFanout[I - 1] then
      raise EGitError.Create('commit-graph fanout non-monotonic');
  FNumCommits := FFanout[255];
  FOidLookupOff := LookupOff;
  FCommitDataOff := CDataOff;
  FExtraOff := ExtraOff;
  FNumExtra := 0;
  if ExtraOff >= 0 then
  begin
    if (ExtraLen mod 4) <> 0 then
      raise EGitError.Create('commit-graph EDGE malformed');
    FNumExtra := Cardinal(ExtraLen div 4);
  end;
  if LookupLen <> Integer(FNumCommits) * GitOidRawLen then
    raise EGitError.Create('commit-graph OIDL wrong length');
  if CDataLen <> Integer(FNumCommits) * (GitOidRawLen + 16) then
    raise EGitError.Create('commit-graph CDAT wrong length');
  for I := 0 to Integer(FNumCommits) - 1 do
  begin
    // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces for K byte loop
    SpanCopy(TByteSpan.Create(@TmpOid.Bytes[0], GitOidRawLen),
      TByteSpan.Create(FView + FOidLookupOff + I * GitOidRawLen, GitOidRawLen));
    if I = 0 then
      Prev := TmpOid
    else
    begin
      Curr := TmpOid;
      if OidRawCompare(Prev, Curr) >= 0 then
        raise EGitError.Create('commit-graph OIDL not monotonic');
      Prev := Curr;
    end;
  end;
end;

procedure TCommitGraph.InitFromMapped(const AMapped: IMappedFile);
begin
  // perf: mmap path zero-copy PByte view via io.mapped owner (no heap duplication in global cache, OS page-reclaimable), inline BE32At via bytes.ops single source
  // stability: FMapped interface keeps mapping alive while graph lives; managed TBytes/IHasher auto released on exception, no leak
  FMapped := AMapped;
  SetLength(FData, 0);
  if (FMapped <> nil) and (FMapped.Size > 0) and (FMapped.Data <> nil) then
    InitFromView(FMapped.Data, SizeInt(FMapped.Size))
  else
    InitFromView(nil, 0);
end;

constructor TCommitGraph.Create(const AData: TBytes);
begin
  inherited Create;
  InitFromData(AData);
end;

constructor TCommitGraph.CreateFromMapped(const AMapped: IMappedFile);
begin
  inherited Create;
  InitFromMapped(AMapped);
end;

destructor TCommitGraph.Destroy;
begin
  SetLength(FData, 0);
  FMapped := nil;
  FView := nil;
  FViewLen := 0;
  inherited Destroy;
end;

function TCommitGraph.TryFind(const AOid: TGitOid; out AEntry: TCommitGraphEntry): Boolean;
var
  Pos: Integer;
  Base: SizeInt;
  P1, P2, GenField, TimeLow: Cardinal;
  I, K: Integer;
  ParentIdx: Cardinal;
  ExtraStart: Cardinal;
  Count: Integer;
  ParentCount: Integer;
begin
  Result := False;
  Pos := FindPos(AOid);
  if Pos < 0 then
    Exit;
  AEntry.Oid := AOid;
  AEntry.CommitTime := 0;
  AEntry.Generation := 0;
  SetLength(AEntry.Parents, 0);
  Base := FCommitDataOff + SizeInt(Pos) * (GitOidRawLen + 16);
  // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces for I byte loop
  SpanCopy(TByteSpan.Create(@AEntry.TreeOid.Bytes[0], GitOidRawLen),
    TByteSpan.Create(FView + Base, GitOidRawLen));
  P1 := BE32At(Base + GitOidRawLen);
  P2 := BE32At(Base + GitOidRawLen + 4);
  GenField := BE32At(Base + GitOidRawLen + 8);
  TimeLow := BE32At(Base + GitOidRawLen + 12);
  AEntry.Generation := GenField shr 2;
  AEntry.CommitTime := Int64(TimeLow) or (Int64(GenField and $3) shl 32);
  ParentCount := 0;
  if P1 <> MISSING_PARENT then
    Inc(ParentCount);
  if P2 <> MISSING_PARENT then
  begin
    if (P2 and EDGE_LAST_MASK) <> 0 then
    begin
      ExtraStart := P2 and EDGE_INDEX_MASK;
      if ExtraStart >= FNumExtra then
        raise EGitError.Create('commit-graph extra edge out of range');
      I := Integer(ExtraStart);
      while I < Integer(FNumExtra) do
      begin
        Inc(ParentCount);
        if (BE32At(FExtraOff + I * 4) and EDGE_LAST_MASK) <> 0 then
          Break;
        Inc(I);
      end;
    end
    else
      Inc(ParentCount);
  end;
  SetLength(AEntry.Parents, ParentCount);
  Count := 0;
  if P1 <> MISSING_PARENT then
  begin
    if P1 >= FNumCommits then
      raise EGitError.Create('commit-graph parent index out of range');
    // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces for I byte loop
    SpanCopy(TByteSpan.Create(@AEntry.Parents[Count].Bytes[0], GitOidRawLen),
      TByteSpan.Create(FView + FOidLookupOff + Integer(P1) * GitOidRawLen, GitOidRawLen));
    Inc(Count);
  end;
  if P2 <> MISSING_PARENT then
  begin
    if (P2 and EDGE_LAST_MASK) <> 0 then
    begin
      ExtraStart := P2 and EDGE_INDEX_MASK;
      I := Integer(ExtraStart);
      while True do
      begin
        ParentIdx := BE32At(FExtraOff + I * 4) and EDGE_INDEX_MASK;
        if ParentIdx >= FNumCommits then
          raise EGitError.Create('commit-graph parent index out of range');
        // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces for K byte loop
        SpanCopy(TByteSpan.Create(@AEntry.Parents[Count].Bytes[0], GitOidRawLen),
          TByteSpan.Create(FView + FOidLookupOff + Integer(ParentIdx) * GitOidRawLen, GitOidRawLen));
        Inc(Count);
        if (BE32At(FExtraOff + I * 4) and EDGE_LAST_MASK) <> 0 then
          Break;
        Inc(I);
        if I >= Integer(FNumExtra) then
          Break;
      end;
    end
    else
    begin
      ParentIdx := P2;
      if ParentIdx >= FNumCommits then
        raise EGitError.Create('commit-graph parent index out of range');
      // perf: zero-copy via bytes.ops SpanCopy single source (inline + single Move, 20B Oid), replaces for I byte loop
      SpanCopy(TByteSpan.Create(@AEntry.Parents[Count].Bytes[0], GitOidRawLen),
        TByteSpan.Create(FView + FOidLookupOff + Integer(ParentIdx) * GitOidRawLen, GitOidRawLen));
      Inc(Count);
    end;
  end;
  Result := True;
end;

function GitCommitGraphPath(const AGitDir: string): string;
begin
  Result := PathJoin([AGitDir, 'objects', 'info', 'commit-graph']);
  if FileExists(Result) then
    Exit;
  Result := PathJoin([AGitDir, 'commit-graph']);
end;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean;
var
  Path: string;
  Data: TBytes;
  Mapped: IMappedFile;
begin
  Result := False;
  AGraph := nil;
  Path := GitCommitGraphPath(AGitDir);
  if not FileExists(Path) then
    Exit;
  // fast path: cached mmap when mtime+size unchanged; LRU promotion on hit
  // (cache choreography lives in commitgraph.cache: shared-read snapshot,
  // Stat outside lock, write-lock promotion — concurrent revwalk readers
  // share the read lock; see cache unit header)
  if GraphCacheTryHit(AGitDir, Path, Mapped) then
  begin
    AGraph := TCommitGraph.CreateFromMapped(Mapped);
    Result := True;
    Exit;
  end;
  // miss: mmap open (zero-copy, no heap TBytes duplication, page-reclaimable); fallback to heap ReadFile on empty/mmap failure for stability
  Mapped := MmapOpen(Path);
  if (Mapped = nil) or (Mapped.Size = 0) or (Mapped.Data = nil) then
  begin
    Data := ReadFile(Path);
    // heap fallback without polluting mmap cache (keep cap for mmap only); still create graph via heap path
    AGraph := TCommitGraph.Create(Data);
    Result := True;
    Exit;
  end;
  GraphCacheStore(AGitDir, Path, Mapped);
  AGraph := TCommitGraph.CreateFromMapped(Mapped);
  Result := True;
end;

function GitVerifyCommitGraph(const AGitDir: string): Boolean;
var
  G: TCommitGraph;
begin
  Result := GitTryLoadCommitGraph(AGitDir, G);
  if Result then
    G.Free;
end;

end.
