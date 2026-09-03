unit nextpas.core.window.live.table;

{ window.live.table — generic live table helpers (family shard, owner window.impl).
  Family shard, Public facade=no, only window.live uses via TWindowFamilyToken.
  Consolidates dual-registry duplication: list+hash capacity sync & swap-remove.
  Single source via bytes.ops & window.hash, inline zero-copy O(1). }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.impl,
  nextpas.core.window.hash,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.ops.snapshot;

type
  TLivePtrHash = specialize TWindowOpenHash<Pointer, Integer>;
  TLiveU32Hash = specialize TWindowOpenHash<UInt32, Pointer>;

procedure LiveTableSyncListPtr(var AList: TSnapshotPointers; var AHash: TLivePtrHash; ANewCap: Integer; ACount: Integer); inline;
procedure LiveTableSyncIDs(var AIDs: TSnapshotUInt32s; var AList: TSnapshotPointers; var AHash: TLiveU32Hash; ANewCap: Integer; ACount: Integer); inline;

procedure LiveTableSwapRemovePtrRaw(var AList: TSnapshotPointers; var AHash: TLivePtrHash; AIdx, ALast: Integer); inline;
procedure LiveTableSwapRemoveIDsRaw(var AIDs: TSnapshotUInt32s; AIdx, ALast: Integer); inline;
procedure LiveTableClearPtr(var AList: TSnapshotPointers; var AHash: TLivePtrHash; ACount: Integer); inline;
procedure LiveTableClearSdl(var AList: TSnapshotPointers; var AIDs: TSnapshotUInt32s; var AHashU32: TLiveU32Hash; var AHashPtr: TLivePtrHash; ACount: Integer); inline;
procedure LiveTableUnregisterPtr(var AList: TSnapshotPointers; var AHash: TLivePtrHash; AIdx, ALast: Integer; APtr: Pointer); inline;
procedure LiveTableUnregisterSdl(var AList: TSnapshotPointers; var AIDs: TSnapshotUInt32s; var AHashU32: TLiveU32Hash; var AHashPtr: TLivePtrHash; AIdx, ALast: Integer; APtr: Pointer; AID: UInt32); inline;

implementation

procedure LiveTableSyncListPtr(var AList: TSnapshotPointers; var AHash: TLivePtrHash; ANewCap: Integer; ACount: Integer); inline;
var LHashCap: Integer;
begin
  // capacity sync single source via bytes.ops WindowGrowCapacity 0→32→2×; hash resize + rebuild, inline zero-copy O(1)
  SetLength(AList, ANewCap);
  if ANewCap = 0 then LHashCap := 0 else LHashCap := WindowGrowCapacity(ANewCap);
  if LHashCap <> AHash.Cap then AHash.Resize(WindowFamilyToken, LHashCap);
  WindowHashRebuild(AHash, WindowFamilyToken, AList, ACount);
end;

procedure LiveTableSyncIDs(var AIDs: TSnapshotUInt32s; var AList: TSnapshotPointers; var AHash: TLiveU32Hash; ANewCap: Integer; ACount: Integer); inline;
var LHashCap: Integer;
begin
  // IDs capacity sync single source via bytes.ops; triple resize + rebuild, inline zero-copy O(1)
  SetLength(AIDs, ANewCap);
  if ANewCap = 0 then LHashCap := 0 else LHashCap := WindowGrowCapacity(ANewCap);
  if LHashCap <> AHash.Cap then AHash.Resize(WindowFamilyToken, LHashCap);
  WindowHashRebuild(AHash, WindowFamilyToken, AIDs, AList, ACount);
end;

procedure LiveTableSwapRemovePtrRaw(var AList: TSnapshotPointers; var AHash: TLivePtrHash; AIdx, ALast: Integer); inline;
var LMoved: Pointer;
begin
  // swap-remove single source via bytes.ops ArraySwapRemoveRaw inline zero-copy O(1), hash remap single source via window.hash
  if AIdx <> ALast then
  begin
    LMoved := AList[ALast];
    specialize ArraySwapRemoveRaw<Pointer>(AList, AIdx, ALast);
    if LMoved <> nil then
    begin
      AHash.Remove(WindowFamilyToken, LMoved);
      AHash.Insert(WindowFamilyToken, LMoved, AIdx);
    end;
  end else
    specialize ArraySwapRemoveRaw<Pointer>(AList, ALast, ALast);
end;

procedure LiveTableSwapRemoveIDsRaw(var AIDs: TSnapshotUInt32s; AIdx, ALast: Integer); inline;
begin
  // IDs swap single source via bytes.ops, inline zero-copy O(1)
  if AIdx <> ALast then
    specialize ArraySwapRemoveRaw<UInt32>(AIDs, AIdx, ALast)
  else
    specialize ArraySwapRemoveRaw<UInt32>(AIDs, ALast, ALast);
end;

procedure LiveTableClearPtr(var AList: TSnapshotPointers; var AHash: TLivePtrHash; ACount: Integer); inline;
var I: Integer;
begin
  // batch clear single source via bytes.ops refill zero + hash clear, inline zero-copy
  for I := 0 to ACount - 1 do AList[I] := nil;
  SetLength(AList, 0);
  AHash.Clear;
end;

procedure LiveTableClearSdl(var AList: TSnapshotPointers; var AIDs: TSnapshotUInt32s; var AHashU32: TLiveU32Hash; var AHashPtr: TLivePtrHash; ACount: Integer); inline;
begin
  // sdl batch clear single source: list+ids dual arrays + dual hashes, inline zero-copy
  LiveTableClearPtr(AList, AHashPtr, ACount);
  if Length(AIDs) > 0 then FillChar(AIDs[0], Length(AIDs) * SizeOf(UInt32), 0);
  SetLength(AIDs, 0);
  AHashU32.Clear;
end;

procedure LiveTableUnregisterPtr(var AList: TSnapshotPointers; var AHash: TLivePtrHash; AIdx, ALast: Integer; APtr: Pointer); inline;
begin
  // single source batch: hash remove + swap remap via bytes.ops inline zero-copy
  AHash.Remove(WindowFamilyToken, APtr);
  LiveTableSwapRemovePtrRaw(AList, AHash, AIdx, ALast);
end;

procedure LiveTableUnregisterSdl(var AList: TSnapshotPointers; var AIDs: TSnapshotUInt32s; var AHashU32: TLiveU32Hash; var AHashPtr: TLivePtrHash; AIdx, ALast: Integer; APtr: Pointer; AID: UInt32); inline;
begin
  // single source sdl batch: dual hash remove + dual swap via bytes.ops inline zero-copy
  AHashU32.Remove(WindowFamilyToken, AID);
  AHashPtr.Remove(WindowFamilyToken, APtr);
  LiveTableSwapRemoveIDsRaw(AIDs, AIdx, ALast);
  LiveTableSwapRemovePtrRaw(AList, AHashPtr, AIdx, ALast);
end;

end.
