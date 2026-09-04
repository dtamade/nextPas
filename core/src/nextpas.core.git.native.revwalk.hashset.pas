unit nextpas.core.git.native.revwalk.hashset;

{$I nextpas.core.settings.inc}

{ revwalk 哈希集合域: 开放寻址 Oid 集合与 Oid→索引映射.
  探针/哈希 helpers 为 parsecache/walker/topo 复用单源.
  依赖只向下 (base/git.native.base + bytes.ops). }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

{ ── History.HashSet: O(1) FNV hash set, inline zero-copy via bytes.ops ── }
{ hash set, O(1) avg }
type
  TGitOidSet = class
  private
    FBuckets: array of TGitOid;
    FHashes: array of UInt32; { cached FNV, avoids rehash recompute at 4096 cap }
    FStates: array of Byte; { 0 empty, 1 occupied }
    FCount: SizeInt;
    FCap: SizeInt;
    FMask: SizeInt;
    procedure EnsureCapacity;
    procedure Rehash(ANewCap: SizeInt);
  public
    { no-op when already present }
    procedure Add(const AOid: TGitOid);
    function Contains(const AOid: TGitOid): Boolean; inline;
    function Count: SizeInt; inline;
  end;

{ O(1) hash map: Oid -> node index, via bytes.ops SpanHashFNV1a single source }
type
  TOidIndexMap = class
  private
    FBuckets: array of TGitOid;
    FHashes: array of UInt32;
    FValues: array of Integer;
    FStates: array of Byte;
    FCount: SizeInt;
    FCap: SizeInt;
    FMask: SizeInt;
    procedure EnsureCapacity;
    procedure Rehash(ANewCap: SizeInt);
  public
    procedure Add(const AOid: TGitOid; AValue: Integer);
    function TryGet(const AOid: TGitOid; out AValue: Integer): Boolean; inline;
  end;

function OidLess(const AA, AB: TGitOid): Boolean; inline;
function OidProbeEmpty(const AStates: array of Byte; AMask: SizeInt; AHash: UInt32): SizeInt;
function OidLocate(const ABuckets: array of TGitOid; const AStates: array of Byte;
  AMask: SizeInt; const AOid: TGitOid; AHash: UInt32; out AIdx: SizeInt): Boolean;
function OidShouldGrow(ACount, ACap: SizeInt): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

function OidLess(const AA, AB: TGitOid): Boolean; inline;
begin
  { ordered by OID bytes via bytes.ops, zero-copy view, inline }
  Result := SpanCompare(
    TByteSpan.Create(@AA.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AB.Bytes[0], GitOidRawLen)) < 0;
end;

{ open-addressing helpers; probe capped at cap+1, avg O(1) at 70% load }
function OidProbeEmpty(const AStates: array of Byte; AMask: SizeInt; AHash: UInt32): SizeInt;
var
  LProbe: SizeInt;
begin
  Result := SizeInt(AHash and UInt32(AMask));
  LProbe := 0;
  while AStates[Result] = 1 do
  begin
    if LProbe > AMask then
      Exit(-1); // probe upper limit: table full, caller will rehash
    Result := (Result + 1) and AMask;
    Inc(LProbe);
  end;
end;

function OidLocate(const ABuckets: array of TGitOid; const AStates: array of Byte;
  AMask: SizeInt; const AOid: TGitOid; AHash: UInt32; out AIdx: SizeInt): Boolean;
var
  LProbe: SizeInt;
begin
  AIdx := SizeInt(AHash and UInt32(AMask));
  LProbe := 0;
  while AStates[AIdx] <> 0 do
  begin
    if GitOidSame(ABuckets[AIdx], AOid) then
      Exit(True);
    if LProbe > AMask then
    begin
      AIdx := -1; // probe upper limit: bounded scan, avoid O(n) degenerate, signal no slot
      Break;
    end;
    AIdx := (AIdx + 1) and AMask;
    Inc(LProbe);
  end;
  Result := False;
end;

function OidShouldGrow(ACount, ACap: SizeInt): Boolean; inline;
begin
  Result := (ACap = 0) or (ACount * 10 >= ACap * 7);
end;

procedure TGitOidSet.EnsureCapacity;
begin
  if not OidShouldGrow(FCount, FCap) then Exit;
  if FCap = 0 then Rehash(16) else Rehash(FCap * 2);
end;

procedure TGitOidSet.Rehash(ANewCap: SizeInt);
var
  LOldBuckets: array of TGitOid;
  LOldHashes: array of UInt32;
  LOldStates: array of Byte;
  LOldCap: SizeInt;
  I: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
begin
  LOldBuckets := FBuckets;
  LOldHashes := FHashes;
  LOldStates := FStates;
  LOldCap := FCap;
  SetLength(FBuckets, ANewCap);
  SetLength(FHashes, ANewCap);
  SetLength(FStates, ANewCap);
  FCap := ANewCap;
  FMask := ANewCap - 1;
  FCount := 0;
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      LHash := LOldHashes[I]; { reuse cached hash, no recompute }
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
      FBuckets[LIdx] := LOldBuckets[I];
      FHashes[LIdx] := LHash;
      FStates[LIdx] := 1;
      Inc(FCount);
    end;
end;

procedure TGitOidSet.Add(const AOid: TGitOid);
var
  LHash: UInt32;
  LIdx: SizeInt;
begin
  EnsureCapacity;
  LHash := GitOidHash(AOid); { single hash, reused on rehash path }
  if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
    Exit;
  if (LIdx < 0) or (LIdx >= FCap) or (FStates[LIdx] = 1) then
  begin
    Rehash(FCap * 2);
    { reuse LHash, no recompute }
    if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
      Exit;
    if (LIdx < 0) or (FStates[LIdx] = 1) then
    begin
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
    end;
  end;
  FBuckets[LIdx] := AOid;
  FHashes[LIdx] := LHash;
  FStates[LIdx] := 1;
  Inc(FCount);
end;

function TGitOidSet.Contains(const AOid: TGitOid): Boolean;
var
  LHash: UInt32;
  LIdx: SizeInt;
begin
  if FCount = 0 then
    Exit(False);
  LHash := GitOidHash(AOid);
  Result := OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx);
end;

function TGitOidSet.Count: SizeInt;
begin
  Result := FCount;
end;

procedure TOidIndexMap.EnsureCapacity;
begin
  if not OidShouldGrow(FCount, FCap) then Exit;
  if FCap = 0 then Rehash(16) else Rehash(FCap * 2);
end;

procedure TOidIndexMap.Rehash(ANewCap: SizeInt);
var
  LOldBuckets: array of TGitOid;
  LOldHashes: array of UInt32;
  LOldValues: array of Integer;
  LOldStates: array of Byte;
  LOldCap: SizeInt;
  I: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
begin
  LOldBuckets := FBuckets;
  LOldHashes := FHashes;
  LOldValues := FValues;
  LOldStates := FStates;
  LOldCap := FCap;
  SetLength(FBuckets, ANewCap);
  SetLength(FHashes, ANewCap);
  SetLength(FValues, ANewCap);
  SetLength(FStates, ANewCap);
  FCap := ANewCap;
  FMask := ANewCap - 1;
  FCount := 0;
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      LHash := LOldHashes[I];
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
      FBuckets[LIdx] := LOldBuckets[I];
      FHashes[LIdx] := LHash;
      FValues[LIdx] := LOldValues[I];
      FStates[LIdx] := 1;
      Inc(FCount);
    end;
end;

procedure TOidIndexMap.Add(const AOid: TGitOid; AValue: Integer);
var LHash: UInt32; LIdx: SizeInt;
begin
  EnsureCapacity;
  LHash := GitOidHash(AOid);
  if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
  begin
    FValues[LIdx] := AValue;
    Exit;
  end;
  if (LIdx < 0) or (LIdx >= FCap) or (FStates[LIdx] = 1) then
  begin
    Rehash(FCap * 2);
    if OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then
    begin
      FValues[LIdx] := AValue;
      Exit;
    end;
    if (LIdx < 0) or (FStates[LIdx] = 1) then
    begin
      LIdx := OidProbeEmpty(FStates, FMask, LHash);
      if LIdx < 0 then
      begin
        Rehash(FCap * 2);
        LIdx := OidProbeEmpty(FStates, FMask, LHash);
      end;
    end;
  end;
  FBuckets[LIdx] := AOid;
  FHashes[LIdx] := LHash;
  FValues[LIdx] := AValue;
  FStates[LIdx] := 1;
  Inc(FCount);
end;

function TOidIndexMap.TryGet(const AOid: TGitOid; out AValue: Integer): Boolean;
var LHash: UInt32; LIdx: SizeInt;
begin
  Result := False;
  if FCount = 0 then Exit;
  LHash := GitOidHash(AOid);
  if not OidLocate(FBuckets, FStates, FMask, AOid, LHash, LIdx) then Exit;
  AValue := FValues[LIdx];
  Result := True;
end;

end.
