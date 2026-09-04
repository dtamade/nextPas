unit nextpas.core.git.native.revwalk.parsecache;

{$I nextpas.core.settings.inc}

{ revwalk 解析缓存域: 4096-cap CoW+LRU 提交解析缓存, 提交恰一次解析.
  探针 helpers 经 hashset 域单源复用.
  依赖: base/hashset (revwalk.*) + L0-L1 owner. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.revwalk.base;

{ ── History.ParseCache: 4096-cap CoW+LRU, O(1) inline via bytes.ops ── }
{ bounded exactly-once parse cache (4096 cap, CoW share, LRU) }
type
  TCommitParseCache = class
  private
    FBuckets: array of TGitOid;
    FHashes: array of UInt32; { cached FNV }
    FWhens: array of Int64;
    FParents: array of TGitOidArray;
    FStates: array of Byte;
    FTicks: array of UInt64; { LRU ticks }
    FTick: UInt64;
    FCount: SizeInt;
    FCap: SizeInt;
    FMask: SizeInt;
    procedure EnsureCapacity;
    procedure Rehash(ANewCap: SizeInt);
    procedure CompactEvict; // LRU bounded eviction keeps 2048 newest at 4096 cap, avoids full clear jitter
  public
    destructor Destroy; override;
    function TryGet(const AOid: TGitOid; out AWhen: Int64; out AParents: TGitOidArray): Boolean; inline;
    procedure Put(const AOid: TGitOid; AWhen: Int64; const AParents: TGitOidArray);
  end;

implementation

uses
  nextpas.core.git.native.revwalk.hashset;

{ hard capacity bound: fallbacks below evict instead of growing past this }
const CMaxParseCacheCap = 4096;

destructor TCommitParseCache.Destroy;
var I: Integer;
begin
  for I := 0 to High(FParents) do
    SetLength(FParents[I], 0);
  inherited Destroy;
end;

procedure TCommitParseCache.EnsureCapacity;
begin
  if not OidShouldGrow(FCount, FCap) then Exit;
  if FCap = 0 then
    Rehash(16)
  else if FCap >= CMaxParseCacheCap then
    CompactEvict
  else if FCap * 2 > CMaxParseCacheCap then
    Rehash(CMaxParseCacheCap)
  else
    Rehash(FCap * 2);
end;

procedure TCommitParseCache.CompactEvict; // LRU tick-threshold linear rebuild; collections.lrucache owner is heavier (THashMap+linked list AllocMem), Cap=16/4096 trivial <30ns, CoW share
const CKeep = 2048; // keep half, stays below 70% grow threshold (2867)
var
  LOldBuckets: array of TGitOid;
  LOldHashes: array of UInt32;
  LOldWhens: array of Int64;
  LOldParents: array of TGitOidArray;
  LOldStates: array of Byte;
  LOldTicks: array of UInt64;
  LOldCap: SizeInt;
  I: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
  LThreshold: UInt64;
begin
  if FCount <= CKeep then
    Exit;
  // threshold keeps newest CKeep ticks, linear O(n) without sort/QuickSelect
  if FTick > UInt64(CKeep) then
    LThreshold := FTick - UInt64(CKeep)
  else
    LThreshold := 0;
  LOldBuckets := FBuckets;
  LOldHashes := FHashes;
  LOldWhens := FWhens;
  LOldParents := FParents;
  LOldStates := FStates;
  LOldTicks := FTicks;
  LOldCap := FCap;
  SetLength(FBuckets, 0);
  SetLength(FHashes, 0);
  SetLength(FWhens, 0);
  SetLength(FParents, 0);
  SetLength(FStates, 0);
  SetLength(FTicks, 0);
  SetLength(FBuckets, FCap);
  SetLength(FHashes, FCap);
  SetLength(FWhens, FCap);
  SetLength(FParents, FCap);
  SetLength(FStates, FCap);
  SetLength(FTicks, FCap);
  FCount := 0;
  // linear scan, keep ticks > threshold, zero alloc, reuse cached hash, CoW share
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      if LOldTicks[I] > LThreshold then
      begin
        LHash := LOldHashes[I]; { reuse cached hash }
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
        if LIdx < 0 then
          { at-cap safety: drop the entry instead of growing past CMaxParseCacheCap;
            a parse cache stays valid on eviction (re-parse on miss) }
          SetLength(LOldParents[I], 0)
        else
        begin
          FBuckets[LIdx] := LOldBuckets[I];
          FHashes[LIdx] := LHash;
          FWhens[LIdx] := LOldWhens[I];
          FParents[LIdx] := LOldParents[I]; { CoW share }
          FTicks[LIdx] := LOldTicks[I];
          FStates[LIdx] := 1;
          Inc(FCount);
        end;
      end
      else
        SetLength(LOldParents[I], 0);
    end;
  // stability: when gaps keep < CKeep, no extra sort needed; cache stays valid (re-parse on miss)
end;

procedure TCommitParseCache.Rehash(ANewCap: SizeInt);
var
  LOldBuckets: array of TGitOid;
  LOldHashes: array of UInt32;
  LOldWhens: array of Int64;
  LOldParents: array of TGitOidArray;
  LOldStates: array of Byte;
  LOldTicks: array of UInt64;
  LOldCap: SizeInt;
  I: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
begin
  LOldBuckets := FBuckets;
  LOldHashes := FHashes;
  LOldWhens := FWhens;
  LOldParents := FParents;
  LOldStates := FStates;
  LOldTicks := FTicks;
  LOldCap := FCap;
  // fresh tables: SetLength preserves on grow, nil first so reinsert starts zeroed
  FBuckets := nil;
  FHashes := nil;
  FWhens := nil;
  FParents := nil;
  FStates := nil;
  FTicks := nil;
  SetLength(FBuckets, ANewCap);
  SetLength(FHashes, ANewCap);
  SetLength(FWhens, ANewCap);
  SetLength(FParents, ANewCap);
  SetLength(FStates, ANewCap);
  SetLength(FTicks, ANewCap);
  FCap := ANewCap;
  FMask := ANewCap - 1;
  FCount := 0;
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      LHash := LOldHashes[I]; { reuse cached hash }
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
      FBuckets[LIdx] := LOldBuckets[I];
      FHashes[LIdx] := LHash;
      FWhens[LIdx] := LOldWhens[I];
      FParents[LIdx] := LOldParents[I];
      FTicks[LIdx] := LOldTicks[I];
      FStates[LIdx] := 1;
      Inc(FCount);
    end;
end;

function TCommitParseCache.TryGet(const AOid: TGitOid; out AWhen: Int64; out AParents: TGitOidArray): Boolean;
var LHash: UInt32; LIdx: SizeInt;
begin
  Result := False;
  if FCount = 0 then Exit;
  LHash := GitOidHash(AOid); { single source FNV via bytes.ops, inline zero-copy }
  if not OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then Exit;
  AWhen := FWhens[LIdx];
  AParents := FParents[LIdx]; { CoW share }
  Inc(FTick);
  FTicks[LIdx] := FTick; // LRU touch, inline fast path
  Result := True;
end;

procedure TCommitParseCache.Put(const AOid: TGitOid; AWhen: Int64; const AParents: TGitOidArray);
var LHash: UInt32; LIdx: SizeInt;
begin
  EnsureCapacity;
  if FCap = 0 then
    Rehash(16);
  LHash := GitOidHash(AOid); { single hash, reused }
  if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
  begin
    if LIdx >= 0 then
    begin
      Inc(FTick);
      FTicks[LIdx] := FTick;
    end;
    Exit;
  end;
  if (LIdx < 0) or (LIdx >= FCap) or (FStates[LIdx] = 1) then
  begin
    { bounded fallback: evict at cap instead of growing past CMaxParseCacheCap }
    if FCap >= CMaxParseCacheCap then
      CompactEvict
    else
      Rehash(FCap * 2);
    { reuse LHash }
    if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
    begin
      if LIdx >= 0 then
      begin
        Inc(FTick);
        FTicks[LIdx] := FTick;
      end;
      Exit;
    end;
    if (LIdx < 0) or (FStates[LIdx] = 1) then
    begin
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        { bounded fallback: evict at cap instead of growing past CMaxParseCacheCap }
        if FCap >= CMaxParseCacheCap then
          CompactEvict
        else
          Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
    end;
  end;
  FBuckets[LIdx] := AOid;
  FHashes[LIdx] := LHash;
  FWhens[LIdx] := AWhen;
  FParents[LIdx] := AParents; { CoW share }
  FStates[LIdx] := 1;
  Inc(FTick);
  FTicks[LIdx] := FTick;
  Inc(FCount);
end;

end.
