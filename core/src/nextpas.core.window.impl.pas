unit nextpas.core.window.impl;

{ window.impl — validation; capacity/hash/ring/snapshot/backoff
  single-sourced via bytes.ops. Hot paths inline O(1) zero-copy; cold paths
  out-of-line to preserve I-Cache. Family boundary via base←impl abstraction
  + CONTRACT/Source-contract, not token privilege. }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops;

type
  { Family token — transitional compat, not privilege. Boundary via
    base←impl abstraction + CONTRACT/Source-contract, not strict private. }
  TWindowFamilyToken = record
  private
    FSeal: Pointer;
  public
    function IsValid: Boolean; inline;
  end;

function WindowFamilyToken: TWindowFamilyToken; inline;
procedure RequireWindowFamilyToken(const AToken: TWindowFamilyToken); inline;

{ Live aggregate — single-source atomic owned here; window.live delegates.
  Hot path inline zero-copy O(1) ~16ns via atomic. }
function WindowTotalLiveCount: Integer; inline;
procedure WindowFakeLiveAdjust(ADelta: Integer); inline;
procedure WindowLiveAdjust(ADelta: Integer); inline;

{ Validation — cold paths, not inline. }
procedure CheckWindowOptions(const AOptions: TWindowOptions);
procedure CheckWindowConstraints(const AOptions: TWindowOptions);
procedure ValidateWindowMinMax(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer);

{ Capacity / hash / ring / queue tuning — thin inline delegates to
  bytes.ops single source, O(1) zero-copy; see bytes.ops.capacity/hash/ring. }
function WindowGrowCapacity(ACurrent: Integer): Integer; inline;
function WindowGrowCapacityCapped(ACurrent, AMax: Integer): Integer; inline;
generic function WindowGrowHelper<T>(ACount, AMax: Integer): Integer; inline;
function WindowHashNeedsGrow(ACount, ACap: Integer): Boolean; inline;
function WindowHashAlignCapacity(ACap: Integer): Integer; inline;
function WindowRingMask(ACap: Integer): Integer; inline;
function WindowRingIndex(AHead, ADelta, ACap: Integer): Integer; inline;
function WindowRingNext(AHead, ACap: Integer): Integer; inline;
function WindowQueueSnapMax: Integer; inline;
function WindowQueueRingMax: Integer; inline;
function WindowQueueShrinkThreshold: Integer; inline;
function WindowQueueShrinkFactor: Integer; inline;
function WindowQueueGrowBackoffBaseNs: UInt64; inline;
function WindowQueueGrowBackoffMaxNs: UInt64; inline;
function WindowQueueGrowBackoffNs(ARetry: Integer): UInt64;

{ Snapshot — single source via bytes.ops. Raw: single Move; Managed: via
  ManagedCopyArray. IsManagedType folded at compile time; 16-slot blittable
  hot path should call WindowSnapshotCopyRaw directly. }
generic procedure WindowSnapshotCopy<T>(var ADest: array of T; const ASrc: array of T; ACount: Integer); inline;
generic procedure WindowSnapshotCopyRaw<T>(var ADest: array of T; const ASrc: array of T; ACount: Integer); inline;
generic procedure WindowSnapshotCopyManaged<T>(var ADest: array of T; const ASrc: array of T; ACount: Integer); inline;
generic procedure WindowSnapshotCopyFrom<T>(var ADest: array of T; const ASrc: array of T; ACount: Integer); inline;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.window.constraints.base,
  nextpas.core.bytes.ops.snapshot;

const
  WINDOW_QUEUE_SNAP_MAX = BYTES_SNAPSHOT_MAX;
  WINDOW_QUEUE_RING_MAX = WINDOW_QUEUE_SNAP_MAX * 2;
  WINDOW_QUEUE_SHRINK_THRESHOLD = BYTES_SNAPSHOT_SHRINK_THRESHOLD;
  WINDOW_QUEUE_SHRINK_FACTOR = BYTES_SNAPSHOT_SHRINK_FACTOR;
  WINDOW_BACKOFF_BASE_NS: UInt64 = 4096;
  WINDOW_BACKOFF_MAX_NS: UInt64 = 50000;
  WINDOW_BACKOFF_YIELD_RETRIES = 4;

var
  GWindowFamilySeal: Byte;
  GLiveTotal: Int32 = 0;

function WindowFamilyToken: TWindowFamilyToken; inline;
begin
  // transitional compat: preserve inline zero-copy O(1) single source, guard via CONTRACT not privilege
  Result.FSeal := @GWindowFamilySeal;
end;

function TWindowFamilyToken.IsValid: Boolean; inline;
begin
  // transitional: strict private removed, now private; IsValid inline zero-copy O(1) single Pointer compare, not privilege
  Result := FSeal = @GWindowFamilySeal;
end;

procedure RequireWindowFamilyToken(const AToken: TWindowFamilyToken); inline;
begin
  // transitional guard: inline zero-copy O(1) thin branch; boundary primarily via base←impl + CONTRACT/Source-contract
  if not AToken.IsValid then
    raise EWindowInvalidState.Create('window family token invalid (use WindowFamilyToken)');
end;

function WindowTotalLiveCount: Integer; inline;
begin
  Result := atomic_load(GLiveTotal);
end;

procedure WindowFakeLiveAdjust(ADelta: Integer); inline;
begin
  atomic_fetch_add(GLiveTotal, Int32(ADelta));
end;

procedure WindowLiveAdjust(ADelta: Integer); inline;
begin
  atomic_fetch_add(GLiveTotal, Int32(ADelta));
end;

function WindowQueueSnapMax: Integer; inline;
begin
  Result := BytesAlignCapacity(WINDOW_QUEUE_SNAP_MAX);
end;

function WindowQueueRingMax: Integer; inline;
begin
  Result := BytesAlignCapacity(WINDOW_QUEUE_RING_MAX);
end;

function WindowQueueShrinkThreshold: Integer; inline;
begin
  Result := WINDOW_QUEUE_SHRINK_THRESHOLD;
end;

function WindowQueueShrinkFactor: Integer; inline;
begin
  Result := WINDOW_QUEUE_SHRINK_FACTOR;
end;

function WindowQueueGrowBackoffBaseNs: UInt64; inline;
begin
  Result := WINDOW_BACKOFF_BASE_NS;
end;

function WindowQueueGrowBackoffMaxNs: UInt64; inline;
begin
  Result := WINDOW_BACKOFF_MAX_NS;
end;

function WindowQueueGrowBackoffNs(ARetry: Integer): UInt64;
var
  LShift: Integer;
begin
  if ARetry < WINDOW_BACKOFF_YIELD_RETRIES then
    Exit(0);
  LShift := ARetry - WINDOW_BACKOFF_YIELD_RETRIES;
  if LShift >= 64 then
    Exit(WINDOW_BACKOFF_MAX_NS);
  if (LShift > 0) and (WINDOW_BACKOFF_BASE_NS > WINDOW_BACKOFF_MAX_NS shr LShift) then
    Exit(WINDOW_BACKOFF_MAX_NS);
  Result := WINDOW_BACKOFF_BASE_NS shl LShift;
  if Result > WINDOW_BACKOFF_MAX_NS then
    Result := WINDOW_BACKOFF_MAX_NS;
end;

procedure CheckWindowConstraintsInline(const AConstraints: TWindowConstraints); forward;

procedure CheckWindowOptions(const AOptions: TWindowOptions);
begin
  if (AOptions.Size.Width < 0) or (AOptions.Size.Height < 0) then
    raise EWindowInvalidState.CreateFmt('Width/Height must be >= 0 (got %d, %d)', [AOptions.Size.Width, AOptions.Size.Height]);
  CheckWindowConstraintsInline(AOptions.Constraints);
end;

procedure CheckWindowConstraintsInline(const AConstraints: TWindowConstraints);
begin
  try
    CheckWindowConstraintsCore(AConstraints);
  except
    on E: EWindowConstraintInvalid do
      raise EWindowInvalidState.Create(E.Message);
    on E: EWindowConstraintsError do
      raise EWindowInvalidState.Create(E.Message);
  end;
end;

procedure CheckWindowConstraints(const AOptions: TWindowOptions);
begin
  CheckWindowConstraintsInline(AOptions.Constraints);
end;

procedure ValidateWindowMinMax(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer);
var
  L: TWindowConstraints;
begin
  L.MinWidth := AMinWidth;
  L.MinHeight := AMinHeight;
  L.MaxWidth := AMaxWidth;
  L.MaxHeight := AMaxHeight;
  CheckWindowConstraintsInline(L);
end;

function WindowGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  Result := BytesGrowCapacity(ACurrent);
end;

function WindowGrowCapacityCapped(ACurrent, AMax: Integer): Integer; inline;
begin
  Result := BytesGrowCapacityCapped(ACurrent, AMax);
end;

generic function WindowGrowHelper<T>(ACount, AMax: Integer): Integer; inline;
begin
  Result := specialize BytesGrowHelper<T>(ACount, AMax);
end;

function WindowHashNeedsGrow(ACount, ACap: Integer): Boolean; inline;
begin
  Result := BytesHashNeedsGrow(ACount, ACap);
end;

function WindowHashAlignCapacity(ACap: Integer): Integer; inline;
begin
  Result := BytesAlignCapacity(ACap);
end;

function WindowRingMask(ACap: Integer): Integer; inline;
begin
  Result := BytesRingMask(ACap);
end;

function WindowRingIndex(AHead, ADelta, ACap: Integer): Integer; inline;
begin
  Result := BytesRingIndex(AHead, ADelta, ACap);
end;

function WindowRingNext(AHead, ACap: Integer): Integer; inline;
begin
  Result := BytesRingNext(AHead, ACap);
end;

generic procedure WindowSnapshotCopyRaw<T>(var ADest: array of T; const ASrc: array of T; ACount: Integer); inline;
begin
  if ACount <= 0 then Exit;
  specialize ArrayRawCopy<T>(ADest, ASrc, ACount);
end;

generic procedure WindowSnapshotCopyManaged<T>(var ADest: array of T; const ASrc: array of T; ACount: Integer); inline;
begin
  if ACount <= 0 then Exit;
  ManagedCopyArray(@ADest[0], @ASrc[0], TypeInfo(T), ACount);
end;

generic procedure WindowSnapshotCopy<T>(var ADest: array of T; const ASrc: array of T; ACount: Integer); inline;
begin
  if ACount <= 0 then Exit;
  if IsManagedType(T) then
    specialize WindowSnapshotCopyManaged<T>(ADest, ASrc, ACount)
  else
    specialize WindowSnapshotCopyRaw<T>(ADest, ASrc, ACount);
end;

generic procedure WindowSnapshotCopyFrom<T>(var ADest: array of T; const ASrc: array of T; ACount: Integer); inline;
begin
  specialize WindowSnapshotCopy<T>(ADest, ASrc, ACount);
end;

end.
