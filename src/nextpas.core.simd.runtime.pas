unit nextpas.core.simd.runtime;

{$mode objfpc}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.dispatch;

// Runtime/control-plane view of SIMD backend state.
// CPU capability-only queries stay in nextpas.core.simd.cpuinfo.

type
  TSimdRuntimeSnapshot = record
    CurrentBackend: TSimdBackend;
    CurrentBackendInfo: TSimdBackendInfo;
    RegisteredBackends: TSimdBackendArray;
    DispatchableBackends: TSimdBackendArray;
    BestDispatchableBackend: TSimdBackend;
  end;

// Canonical runtime/control-plane snapshot getter.
function GetCurrentRuntimeSnapshot: TSimdRuntimeSnapshot;

// Compatibility alias kept for older call sites.
function GetCurrentSimdRuntimeSnapshot: TSimdRuntimeSnapshot;

// Returns the currently published backend.
function GetCurrentBackend: TSimdBackend;

// Returns metadata for the currently published backend snapshot.
function GetCurrentBackendInfo: TSimdBackendInfo;

// Returns True when the backend has been registered into this binary.
function IsBackendRegisteredInBinary(aBackend: TSimdBackend): Boolean;

// Enumerates every backend currently registered in this binary.
function GetRegisteredBackendList: TSimdBackendArray;

// Enumerates backends that are both registered and dispatchable now.
function GetDispatchableBackendList: TSimdBackendArray;

// Compatibility alias for the runtime dispatchable view.
// This is not the CPU-capability-only list from nextpas.core.simd.cpuinfo.
function GetAvailableBackendList: TSimdBackendArray;

// Returns the best dispatchable backend in the current runtime state.
function GetBestDispatchableBackend: TSimdBackend;

// Control-plane setter that reports whether the requested backend became active.
function TrySetCurrentBackend(aBackend: TSimdBackend): Boolean;

// Control-plane setter with legacy scalar fallback semantics.
procedure SetCurrentBackend(aBackend: TSimdBackend);

// Returns runtime backend selection to automatic mode.
procedure ResetCurrentBackendSelection;

implementation

uses
  nextpas.core.atomic;

type
  TSimdRuntimePublishedState = record
    Dispatch: PSimdDispatchTable;
    TargetVersion: UInt32;
    Snapshot: TSimdRuntimeSnapshot;
    Valid: Boolean;
  end;

var
  g_SimdRuntimeState: TSimdRuntimePublishedState;
  g_SimdRuntimeTargetDispatchPtr: Pointer = nil;
  g_SimdRuntimeTargetVersion: UInt32 = 0;
  g_SimdRuntimeRebindLock: TRTLCriticalSection;

procedure InitializeSimdRuntimePublishedState(out aState: TSimdRuntimePublishedState);
begin
  aState := Default(TSimdRuntimePublishedState);
  aState.Dispatch := nil;
  aState.TargetVersion := 0;
  aState.Snapshot.CurrentBackend := sbScalar;
  aState.Snapshot.BestDispatchableBackend := sbScalar;
  aState.Valid := False;
end;

procedure ClearSimdRuntimePublishedState(var aState: TSimdRuntimePublishedState);
begin
  aState.Dispatch := nil;
  aState.TargetVersion := 0;
  aState.Snapshot.CurrentBackend := sbScalar;
  aState.Snapshot.CurrentBackendInfo := Default(TSimdBackendInfo);
  aState.Snapshot.RegisteredBackends := nil;
  aState.Snapshot.DispatchableBackends := nil;
  aState.Snapshot.BestDispatchableBackend := sbScalar;
  aState.Valid := False;
end;

procedure BuildDefaultRuntimeSnapshot(out aSnapshot: TSimdRuntimeSnapshot);
begin
  aSnapshot.CurrentBackend := sbScalar;
  aSnapshot.CurrentBackendInfo := GetBackendInfo(sbScalar);
  aSnapshot.RegisteredBackends := nil;
  aSnapshot.DispatchableBackends := nil;
  aSnapshot.BestDispatchableBackend := sbScalar;
end;

procedure EnsureUniqueBackendInfoText(var aInfo: TSimdBackendInfo); inline;
begin
  if aInfo.Name <> '' then
    UniqueString(aInfo.Name);
  if aInfo.Description <> '' then
    UniqueString(aInfo.Description);
end;

function CloneBackendArray(const aBackends: TSimdBackendArray): TSimdBackendArray; inline;
begin
  Result := Copy(aBackends);
end;

function CloneBackendInfo(const aInfo: TSimdBackendInfo): TSimdBackendInfo; inline;
begin
  Result := aInfo;
  EnsureUniqueBackendInfoText(Result);
end;

function CloneRuntimeSnapshot(const aSnapshot: TSimdRuntimeSnapshot): TSimdRuntimeSnapshot;
begin
  Result.CurrentBackend := aSnapshot.CurrentBackend;
  Result.CurrentBackendInfo := CloneBackendInfo(aSnapshot.CurrentBackendInfo);
  Result.RegisteredBackends := CloneBackendArray(aSnapshot.RegisteredBackends);
  Result.DispatchableBackends := CloneBackendArray(aSnapshot.DispatchableBackends);
  Result.BestDispatchableBackend := aSnapshot.BestDispatchableBackend;
end;

function ContainsBackend(const aBackends: TSimdBackendArray;
  aBackend: TSimdBackend): Boolean; inline;
var
  LBackend: TSimdBackend;
begin
  for LBackend in aBackends do
    if LBackend = aBackend then
      Exit(True);
  Result := False;
end;

function BuildCurrentBackendInfoFromDispatch(aDispatch: PSimdDispatchTable): TSimdBackendInfo;
var
  LCanonicalInfo: TSimdBackendInfo;
  LBackend: TSimdBackend;
begin
  if aDispatch <> nil then
  begin
    Result := aDispatch^.BackendInfo;
    Result.Backend := aDispatch^.Backend;
    if (Result.Name = '') or (Result.Description = '') then
    begin
      LCanonicalInfo := GetBackendInfo(aDispatch^.Backend);
      if Result.Name = '' then
        Result.Name := LCanonicalInfo.Name;
      if Result.Description = '' then
        Result.Description := LCanonicalInfo.Description;
    end;
    EnsureUniqueBackendInfoText(Result);
    Exit;
  end;

  LBackend := GetActiveBackend;
  Result := GetBackendInfo(LBackend);
  EnsureUniqueBackendInfoText(Result);
end;

function BuildRegisteredBackendList: TSimdBackendArray;
var
  LBackend: TSimdBackend;
  LCount: Integer;
begin
  SetLength(Result,
    Ord(High(TSimdBackend)) - Ord(Low(TSimdBackend)) + 1);
  LCount := 0;
  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    if IsBackendRegistered(LBackend) then
    begin
      Result[LCount] := LBackend;
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

procedure BuildSimdRuntimePublishedState(out aState: TSimdRuntimePublishedState);
var
  LDispatch: PSimdDispatchTable;
begin
  InitializeSimdRuntimePublishedState(aState);
  LDispatch := GetDispatchTable;
  aState.Dispatch := LDispatch;
  if LDispatch <> nil then
    aState.Snapshot.CurrentBackend := LDispatch^.Backend
  else
    aState.Snapshot.CurrentBackend := GetActiveBackend;
  aState.Snapshot.CurrentBackendInfo := BuildCurrentBackendInfoFromDispatch(LDispatch);
  aState.Snapshot.RegisteredBackends := BuildRegisteredBackendList;
  aState.Snapshot.DispatchableBackends := GetDispatchableBackends;
  aState.Snapshot.BestDispatchableBackend := nextpas.core.simd.dispatch.GetBestDispatchableBackend;
  aState.Valid := True;
end;

function GetCurrentSimdRuntimeTargetDispatch: PSimdDispatchTable; inline;
begin
  Result := PSimdDispatchTable(atomic_load(g_SimdRuntimeTargetDispatchPtr, mo_acquire));
end;

function GetCurrentSimdRuntimeTargetVersion: UInt32; inline;
begin
  Result := atomic_load(g_SimdRuntimeTargetVersion, mo_acquire);
end;

function RuntimeStateMatchesTarget(const aState: TSimdRuntimePublishedState;
  aTargetDispatch: PSimdDispatchTable; aTargetVersion: UInt32): Boolean; inline;
begin
  Result := aState.Valid and
    (aState.TargetVersion = aTargetVersion) and
    ((aTargetDispatch = nil) or (aState.Dispatch = aTargetDispatch));
end;

procedure InvalidateSimdRuntimeState;
begin
  // Runtime snapshot is control-plane facing and returned by value, so it can
  // use a single cached state instead of process-lifetime published snapshots.
  atomic_store(g_SimdRuntimeTargetDispatchPtr, Pointer(GetDispatchTable), mo_release);
  atomic_increment(g_SimdRuntimeTargetVersion);
  EnterCriticalSection(g_SimdRuntimeRebindLock);
  try
    g_SimdRuntimeState.Valid := False;
  finally
    LeaveCriticalSection(g_SimdRuntimeRebindLock);
  end;
end;

function TryGetPublishedRuntimeSnapshot(out aSnapshot: TSimdRuntimeSnapshot): Boolean; inline;
begin
  EnterCriticalSection(g_SimdRuntimeRebindLock);
  try
    Result := g_SimdRuntimeState.Valid;
    if Result then
      aSnapshot := CloneRuntimeSnapshot(g_SimdRuntimeState.Snapshot);
  finally
    LeaveCriticalSection(g_SimdRuntimeRebindLock);
  end;
end;

function TryGetPublishedRuntimeSnapshotAfterRefresh(out aSnapshot: TSimdRuntimeSnapshot): Boolean; inline;
begin
  Result := TryGetPublishedRuntimeSnapshot(aSnapshot);
  if not Result then
  begin
    GetCurrentRuntimeSnapshot;
    Result := TryGetPublishedRuntimeSnapshot(aSnapshot);
  end;
end;

function GetCurrentRuntimeSnapshot: TSimdRuntimeSnapshot;
var
  LBuiltState: TSimdRuntimePublishedState;
  LTargetDispatch: PSimdDispatchTable;
  LTargetVersion: UInt32;
  LCurrentTargetVersion: UInt32;
  LRetry: Boolean;
begin
  repeat
    EnterCriticalSection(g_SimdRuntimeRebindLock);
    try
      LTargetVersion := GetCurrentSimdRuntimeTargetVersion;
      LTargetDispatch := GetCurrentSimdRuntimeTargetDispatch;
      if RuntimeStateMatchesTarget(g_SimdRuntimeState, LTargetDispatch, LTargetVersion) then
      begin
        Result := CloneRuntimeSnapshot(g_SimdRuntimeState.Snapshot);
        Exit;
      end;
    finally
      LeaveCriticalSection(g_SimdRuntimeRebindLock);
    end;

    BuildSimdRuntimePublishedState(LBuiltState);

    LRetry := False;
    EnterCriticalSection(g_SimdRuntimeRebindLock);
    try
      LCurrentTargetVersion := GetCurrentSimdRuntimeTargetVersion;
      LTargetDispatch := GetCurrentSimdRuntimeTargetDispatch;
      if (LCurrentTargetVersion <> LTargetVersion) or
         ((LTargetDispatch <> nil) and (LBuiltState.Dispatch <> LTargetDispatch)) then
        LRetry := True
      else
      begin
        LBuiltState.TargetVersion := LCurrentTargetVersion;
        g_SimdRuntimeState := LBuiltState;
        Result := CloneRuntimeSnapshot(g_SimdRuntimeState.Snapshot);
        Exit;
      end;
    finally
      LeaveCriticalSection(g_SimdRuntimeRebindLock);
    end;
  until not LRetry;

  BuildDefaultRuntimeSnapshot(Result);
end;

function GetCurrentSimdRuntimeSnapshot: TSimdRuntimeSnapshot;
begin
  Result := GetCurrentRuntimeSnapshot;
end;

function GetCurrentBackend: TSimdBackend;
var
  LSnapshot: TSimdRuntimeSnapshot;
begin
  if TryGetPublishedRuntimeSnapshotAfterRefresh(LSnapshot) then
    Exit(LSnapshot.CurrentBackend);

  Result := GetCurrentRuntimeSnapshot.CurrentBackend;
end;

function GetCurrentBackendInfo: TSimdBackendInfo;
var
  LSnapshot: TSimdRuntimeSnapshot;
begin
  if TryGetPublishedRuntimeSnapshotAfterRefresh(LSnapshot) then
    Exit(LSnapshot.CurrentBackendInfo);

  Result := GetCurrentRuntimeSnapshot.CurrentBackendInfo;
end;

function IsBackendRegisteredInBinary(aBackend: TSimdBackend): Boolean;
var
  LSnapshot: TSimdRuntimeSnapshot;
begin
  if TryGetPublishedRuntimeSnapshotAfterRefresh(LSnapshot) then
    Exit(ContainsBackend(LSnapshot.RegisteredBackends, aBackend));

  Result := ContainsBackend(GetCurrentRuntimeSnapshot.RegisteredBackends, aBackend);
end;

function GetRegisteredBackendList: TSimdBackendArray;
var
  LSnapshot: TSimdRuntimeSnapshot;
begin
  if TryGetPublishedRuntimeSnapshotAfterRefresh(LSnapshot) then
    Exit(LSnapshot.RegisteredBackends);

  Result := GetCurrentRuntimeSnapshot.RegisteredBackends;
end;

function GetDispatchableBackendList: TSimdBackendArray;
var
  LSnapshot: TSimdRuntimeSnapshot;
begin
  if TryGetPublishedRuntimeSnapshotAfterRefresh(LSnapshot) then
    Exit(LSnapshot.DispatchableBackends);

  Result := GetCurrentRuntimeSnapshot.DispatchableBackends;
end;

function GetAvailableBackendList: TSimdBackendArray;
begin
  Result := GetDispatchableBackendList;
end;

function GetBestDispatchableBackend: TSimdBackend;
var
  LSnapshot: TSimdRuntimeSnapshot;
begin
  if TryGetPublishedRuntimeSnapshotAfterRefresh(LSnapshot) then
    Exit(LSnapshot.BestDispatchableBackend);

  Result := GetCurrentRuntimeSnapshot.BestDispatchableBackend;
end;

function TrySetCurrentBackend(aBackend: TSimdBackend): Boolean;
begin
  Result := TrySetActiveBackend(aBackend);
end;

procedure SetCurrentBackend(aBackend: TSimdBackend);
begin
  SetActiveBackend(aBackend);
end;

procedure ResetCurrentBackendSelection;
begin
  ResetToAutomaticBackend;
end;

procedure FinalizeSimdRuntimePublishedState;
begin
  EnterCriticalSection(g_SimdRuntimeRebindLock);
  try
    ClearSimdRuntimePublishedState(g_SimdRuntimeState);
  finally
    LeaveCriticalSection(g_SimdRuntimeRebindLock);
  end;
end;

initialization
  InitCriticalSection(g_SimdRuntimeRebindLock);
  InitializeSimdRuntimePublishedState(g_SimdRuntimeState);
  atomic_store(g_SimdRuntimeTargetDispatchPtr, nil, mo_release);
  atomic_store(g_SimdRuntimeTargetVersion, 0, mo_release);
  AddDispatchChangedHook(@InvalidateSimdRuntimeState);
  GetCurrentRuntimeSnapshot;

finalization
  RemoveDispatchChangedHook(@InvalidateSimdRuntimeState);
  FinalizeSimdRuntimePublishedState;
  atomic_store(g_SimdRuntimeTargetDispatchPtr, nil, mo_release);
  atomic_store(g_SimdRuntimeTargetVersion, 0, mo_release);
  DoneCriticalSection(g_SimdRuntimeRebindLock);

end.
