unit nextpas.core.simd.dispatch;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.cpuinfo;

// === Dispatch System ===

// Initialize the dispatch system (called automatically)
procedure InitializeDispatch;

// Get current active backend
function GetActiveBackend: TSimdBackend;

// Force a specific backend (for testing)
// 添加安全性检查 - 如果后端不可用则回退到 Scalar
procedure SetActiveBackend(backend: TSimdBackend);

// Try to set a specific backend, returns True if successful
// 新增函数 - 允许调用者检查是否成功
function TrySetActiveBackend(backend: TSimdBackend): Boolean;

// Low-level compatibility alias for cpuinfo.IsBackendSupportedOnCPU.
// New public call sites should prefer nextpas.core.simd.cpuinfo.
function IsBackendAvailableOnCPU(backend: TSimdBackend): Boolean;

// Check if a backend is both CPU-supported and dispatchable in this binary.
function IsBackendDispatchable(backend: TSimdBackend): Boolean;

// Enumerate backends that can actually be selected by dispatch.
function GetDispatchableBackends: TSimdBackendArray;

// Get the best backend that is both CPU-supported and dispatchable.
function GetBestDispatchableBackend: TSimdBackend;

// Reset to automatic backend selection
procedure ResetToAutomaticBackend;

// === SIMD Vector ASM Feature Toggle ===
// SIMD vector ASM implementations are enabled by default.
// To disable at compile-time, define SIMD_VECTOR_ASM_DISABLED.
// To disable at runtime, call SetVectorAsmEnabled(False).
function IsVectorAsmEnabled: Boolean;
procedure SetVectorAsmEnabled(enabled: Boolean);

// === Dispatch Change Hook ===
// Used by higher-level facades to bind a fast access path once per (re)initialization.
{$I nextpas.core.simd.dispatch.hooks.intf.inc}

// === Backend Rebuilder Registration ===
// Register per-backend rebuild callbacks so feature toggles (e.g. vector asm)
// can rebuild backend tables after initialization.
type
  TBackendRebuilder = procedure;

// Rebuilder callbacks should be registration-only and idempotent.
procedure RegisterBackendRebuilder(backend: TSimdBackend; rebuilder: TBackendRebuilder);

// === Function Dispatch Tables ===
type
  // Dispatch table for all SIMD operations.
  // This is a stable in-repo dispatch contract for nextpas.core itself, but not
  // a public binary ABI: BackendInfo carries managed string fields.
  {$I nextpas.core.simd.dispatch.table.inc}

// Pointer to dispatch table
type
  PSimdDispatchTable = ^TSimdDispatchTable;

// Get current dispatch table
function GetDispatchTable: PSimdDispatchTable; inline;

// === Backend Registration ===

// Register a backend implementation
procedure RegisterBackend(backend: TSimdBackend; const dispatchTable: TSimdDispatchTable);

// Check if backend is registered
function IsBackendRegistered(backend: TSimdBackend): Boolean;

// Get backend info
function GetBackendInfo(backend: TSimdBackend): TSimdBackendInfo;

// Return a stable pointer to the published backend name text.
// The returned pointer stays valid until process finalization.
function GetBackendNameTextPtr(backend: TSimdBackend): PAnsiChar;

// Return a stable pointer to the published backend description text.
// The returned pointer stays valid until process finalization.
function GetBackendDescriptionTextPtr(backend: TSimdBackend): PAnsiChar;

// Get a copy of a registered backend's dispatch table.
// Useful for diagnostics/tests (e.g. validating wiring on machines without that CPU feature).
// Returns False and clears `dispatchTable` if the backend is not registered.
function TryGetRegisteredBackendDispatchTable(backend: TSimdBackend; out dispatchTable: TSimdDispatchTable): Boolean;

// === Dispatch Table Helpers ===

{**
 * FillBaseDispatchTable
 *
 * @desc
 *   Fills a dispatch table with scalar reference implementations for all operations.
 *   This provides a complete baseline that SIMD backends can override selectively.
 *   填充派发表，使用标量参考实现作为所有操作的基础。
 *   为 SIMD 后端提供完整的基线，以便它们可以选择性地覆盖。
 *
 * @note
 *   Call this before setting backend-specific implementations.
 *   Backend info is NOT set by this function - caller must set it.
 *   在设置后端特定实现之前调用此函数。
 *   此函数不设置后端信息 - 调用者必须自行设置。
 *}
procedure FillBaseDispatchTable(var dispatchTable: TSimdDispatchTable);

{**
 * CloneDispatchTable
 *
 * @desc
 *   Clones a dispatch table from an already registered backend.
 *   This allows tier backends (SSE3/SSSE3/SSE4.1/SSE4.2) to inherit
 *   implementations from a lower tier (SSE2) instead of starting from scalar.
 *   从已注册的后端克隆派发表。
 *   这允许 tier 后端（SSE3/SSSE3/SSE4.1/SSE4.2）从低级后端（SSE2）
 *   继承实现，而不是从标量基线开始。
 *
 * @param fromBackend
 *   The backend to clone from. Must be already registered.
 *   要克隆的源后端。必须已注册。
 *
 * @param dispatchTable
 *   The dispatch table to fill with cloned implementations.
 *   要填充克隆实现的派发表。
 *
 * @returns
 *   True if clone succeeded (source backend was registered), False otherwise.
 *   如果克隆成功（源后端已注册）返回 True，否则返回 False。
 *
 * @note
 *   If the source backend is not registered, falls back to FillBaseDispatchTable.
 *   Backend info is NOT copied - caller must set it appropriately.
 *   如果源后端未注册，回退到 FillBaseDispatchTable。
 *   后端信息不会被复制 - 调用者必须自行设置。
 *}
function CloneDispatchTable(fromBackend: TSimdBackend; var dispatchTable: TSimdDispatchTable): Boolean;

implementation

uses
  nextpas.core.simd.scalar,
  nextpas.core.atomic,
  nextpas.core.simd.backend.priority; // atomic_thread_fence (MemoryBarrier replacement)

type
  PSimdDispatchPublishedState = ^TSimdDispatchPublishedState;
  TSimdDispatchPublishedState = record
    NextOwned: PSimdDispatchPublishedState;
    Table: TSimdDispatchTable;
  end;

const
  SIMD_MAX_CONTROL_PLANE_RESTORE_ATTEMPTS = 8;

var
  // Current active dispatch table
  g_CurrentDispatch: PSimdDispatchTable;
  g_CurrentDispatchStatePtr: Pointer = nil;
  g_CurrentDispatchOwnedHead: PSimdDispatchPublishedState = nil;
  g_BackendDispatchStatePtrs: array[TSimdBackend] of Pointer;
  
  // Registered backend dispatch tables
  g_BackendTables: array[TSimdBackend] of TSimdDispatchTable;
  g_BackendRegistered: array[TSimdBackend] of Boolean;
  g_DefaultBackendNames: array[TSimdBackend] of AnsiString;
  g_DefaultBackendDescriptions: array[TSimdBackend] of AnsiString;
  
  // Initialization state
  g_DispatchInitialized: Boolean = False;
  g_DispatchState: LongInt = 0;  // 0=未初始化, 1=初始化中, 2=已完成
  g_ForcedBackend: TSimdBackend;
  g_BackendForced: Boolean = False;

  // Feature toggles
  // 默认启用 SIMD 向量操作
  // 如需禁用，编译时定义 SIMD_VECTOR_ASM_DISABLED
  // 0 = disabled, 1 = enabled
  {$IFNDEF SIMD_VECTOR_ASM_DISABLED}
  g_VectorAsmEnabledState: LongInt = 1;
  {$ELSE}
  g_VectorAsmEnabledState: LongInt = 0;
  {$ENDIF}

  // Serialize runtime toggle writers so backend rebuild is single-threaded.
  g_VectorAsmToggleLock: TRTLCriticalSection;

  // Serialize hook list mutation without holding the lock during callbacks.
  g_DispatchHooksLock: TRTLCriticalSection;

  // Dispatch change hooks (e.g., for direct-dispatch fast path binding)
  g_DispatchChangedHooks: array of TSimdDispatchChangedHook;

  // Optional per-backend callback to rebuild dispatch tables when runtime feature
  // toggles change (e.g. vector-asm on/off).
  g_BackendRebuilders: array[TSimdBackend] of TBackendRebuilder;

  // Batch control-plane rebuilds (for example vector-asm toggles) should not
  // let each intermediate RegisterBackend call re-select a transient active
  // backend. Reinitialize once after the batch completes instead.
  g_RegisterBackendReinitializeSuspendDepth: LongInt = 0;

  // Readers that see g_DispatchState=0 during a control-plane batch rebuild
  // must not initialize against the half-rebuilt backend set.
  g_DispatchBatchRebuildState: LongInt = 0;
  g_DispatchControlPlaneInitialized: Boolean = False;

// === Initialization ===

function DefaultBackendName(const aBackend: TSimdBackend): string; inline;
begin
  Result := '';
  case aBackend of
    sbScalar: Result := 'Scalar';
    sbSSE2: Result := 'SSE2';
    sbSSE3: Result := 'SSE3';
    sbSSSE3: Result := 'SSSE3';
    sbSSE41: Result := 'SSE4.1';
    sbSSE42: Result := 'SSE4.2';
    sbAVX2: Result := 'AVX2';
    sbAVX512: Result := 'AVX-512';
    sbNEON: Result := 'NEON';
    sbRISCVV: Result := 'RISC-V V';
  end;
end;

function DefaultBackendDescription(const aBackend: TSimdBackend): string; inline;
begin
  Result := '';
  case aBackend of
    sbScalar: Result := 'Pure scalar reference implementation';
    sbSSE2: Result := 'x86-64 SSE2 SIMD implementation';
    sbSSE3: Result := 'x86-64 SSE3 SIMD implementation';
    sbSSSE3: Result := 'x86-64 SSSE3 SIMD implementation';
    sbSSE41: Result := 'x86-64 SSE4.1 SIMD implementation';
    sbSSE42: Result := 'x86-64 SSE4.2 SIMD implementation';
    sbAVX2: Result := 'x86-64 AVX2 SIMD implementation';
    sbAVX512: Result := 'x86-64 AVX-512 SIMD implementation';
    sbNEON: Result := 'ARM NEON 128-bit SIMD';
    sbRISCVV: Result := 'RISC-V Vector Extension (RVV)';
  end;
end;

procedure InitializeDefaultBackendTexts;
var
  LBackend: TSimdBackend;
begin
  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    g_DefaultBackendNames[LBackend] := AnsiString(DefaultBackendName(LBackend));
    g_DefaultBackendDescriptions[LBackend] := AnsiString(DefaultBackendDescription(LBackend));
  end;
end;

procedure EnsureDispatchControlPlaneInitialized;
begin
  if g_DispatchControlPlaneInitialized then
    Exit;

  InitializeDefaultBackendTexts;
  g_VectorAsmToggleLock := Default(TRTLCriticalSection);
  g_DispatchHooksLock := Default(TRTLCriticalSection);
  InitCriticalSection(g_VectorAsmToggleLock);
  InitCriticalSection(g_DispatchHooksLock);
  g_DispatchControlPlaneInitialized := True;
end;

procedure EnsureUniqueBackendInfoText(var aInfo: TSimdBackendInfo); inline;
begin
  if aInfo.Name <> '' then
    UniqueString(aInfo.Name);
  if aInfo.Description <> '' then
    UniqueString(aInfo.Description);
end;

function GetCurrentDispatchPublishedState: PSimdDispatchPublishedState; inline;
begin
  Result := PSimdDispatchPublishedState(atomic_load(g_CurrentDispatchStatePtr, mo_acquire));
end;

function GetCurrentPublishedDispatchTable: PSimdDispatchTable; inline;
var
  LState: PSimdDispatchPublishedState;
begin
  LState := GetCurrentDispatchPublishedState;
  if LState <> nil then
    Result := @LState^.Table
  else
    Result := nil;
end;

function GetPublishedBackendDispatchState(const aBackend: TSimdBackend): PSimdDispatchPublishedState; inline;
begin
  Result := PSimdDispatchPublishedState(atomic_load(g_BackendDispatchStatePtrs[aBackend], mo_acquire));
end;

function GetPublishedBackendDispatchTable(const aBackend: TSimdBackend): PSimdDispatchTable; inline;
var
  LState: PSimdDispatchPublishedState;
begin
  LState := GetPublishedBackendDispatchState(aBackend);
  if LState <> nil then
    Result := @LState^.Table
  else
    Result := nil;
end;

function CreateDispatchPublishedState: PSimdDispatchPublishedState;
begin
  New(Result);
  FillChar(Result^, SizeOf(Result^), 0);
  Result^.NextOwned := g_CurrentDispatchOwnedHead;
  g_CurrentDispatchOwnedHead := Result;
end;

function DispatchTableMetadataEquals(const aLeft, aRight: TSimdDispatchTable): Boolean; inline;
begin
  Result := (aLeft.Backend = aRight.Backend) and
    (aLeft.BackendInfo.Backend = aRight.BackendInfo.Backend) and
    (aLeft.BackendInfo.Name = aRight.BackendInfo.Name) and
    (aLeft.BackendInfo.Description = aRight.BackendInfo.Description) and
    (aLeft.BackendInfo.Available = aRight.BackendInfo.Available) and
    (aLeft.BackendInfo.Priority = aRight.BackendInfo.Priority) and
    (aLeft.BackendInfo.Capabilities = aRight.BackendInfo.Capabilities);
end;

function DispatchTableSlotPointersEqual(const aLeft, aRight: TSimdDispatchTable): Boolean;
var
  LOffset: PtrUInt;
  LSize: SizeUInt;
  LLeftSlots: PByte;
  LRightSlots: PByte;
begin
  {$PUSH}{$WARN 4055 OFF} // pointer-sized offset math over immutable dispatch snapshots
  LOffset := PtrUInt(@aLeft.AddF32x4) - PtrUInt(@aLeft);
  LLeftSlots := PByte(PtrUInt(@aLeft) + LOffset);
  LRightSlots := PByte(PtrUInt(@aRight) + LOffset);
  {$POP}
  LSize := SizeOf(TSimdDispatchTable) - LOffset;
  if LSize = 0 then
    Exit(True);
  Result := CompareByte(LLeftSlots^, LRightSlots^, LSize) = 0;
end;

function DispatchTablesEquivalent(const aLeft, aRight: TSimdDispatchTable): Boolean; inline;
begin
  Result := DispatchTableMetadataEquals(aLeft, aRight) and
    DispatchTableSlotPointersEqual(aLeft, aRight);
end;

function FindPublishedDispatchStateByTable(
  const aDispatchTable: TSimdDispatchTable): PSimdDispatchPublishedState;
begin
  Result := g_CurrentDispatchOwnedHead;
  while Result <> nil do
  begin
    if DispatchTablesEquivalent(Result^.Table, aDispatchTable) then
      Exit;
    Result := Result^.NextOwned;
  end;
end;

procedure PublishBackendDispatchTable(const aBackend: TSimdBackend; const aDispatchTable: TSimdDispatchTable);
var
  LState: PSimdDispatchPublishedState;
begin
  LState := FindPublishedDispatchStateByTable(aDispatchTable);
  if LState = nil then
  begin
    LState := CreateDispatchPublishedState;
    LState^.Table := aDispatchTable;
  end;
  atomic_store(g_BackendDispatchStatePtrs[aBackend], Pointer(LState), mo_release);
end;

procedure PublishCurrentDispatchState(const aState: PSimdDispatchPublishedState);
begin
  if aState = nil then
  begin
    g_CurrentDispatch := nil;
    atomic_store(g_CurrentDispatchStatePtr, nil, mo_release);
    Exit;
  end;

  // The active/current dispatch view does not need its own cloned publication:
  // the selected backend snapshot is already immutable and process-owned.
  g_CurrentDispatch := @aState^.Table;
  atomic_store(g_CurrentDispatchStatePtr, Pointer(aState), mo_release);
end;

procedure FinalizeDispatchPublishedStates;
var
  LState: PSimdDispatchPublishedState;
  LNext: PSimdDispatchPublishedState;
begin
  atomic_store(g_CurrentDispatchStatePtr, nil, mo_release);
  g_CurrentDispatch := nil;
  LState := g_CurrentDispatchOwnedHead;
  g_CurrentDispatchOwnedHead := nil;
  while LState <> nil do
  begin
    LNext := LState^.NextOwned;
    Dispose(LState);
    LState := LNext;
  end;
end;

function IsBackendMarkedAvailableForDispatch(backend: TSimdBackend): Boolean; inline;
var
  LDispatchTable: PSimdDispatchTable;
begin
  // Scalar is always usable.
  if backend = sbScalar then
    Exit(True);

  // Observe registration + published backend snapshot with a single read barrier.
  ReadBarrier;
  if not g_BackendRegistered[backend] then
    Exit(False);

  LDispatchTable := GetPublishedBackendDispatchTable(backend);
  Result := (LDispatchTable <> nil) and LDispatchTable^.BackendInfo.Available;
end;

{$I nextpas.core.simd.dispatch.hooks.impl.inc}

procedure RebuildBackendsAfterFeatureToggle(const aReinitializeDispatch: Boolean);
var
  LBackend: TSimdBackend;
  LRebuilder: TBackendRebuilder;
begin
  InterlockedExchange(g_DispatchBatchRebuildState, 1);
  InterlockedIncrement(g_RegisterBackendReinitializeSuspendDepth);
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      LRebuilder := g_BackendRebuilders[LBackend];
      if Assigned(LRebuilder) then
        LRebuilder;
    end;
  finally
    InterlockedDecrement(g_RegisterBackendReinitializeSuspendDepth);
    WriteBarrier;
    InterlockedExchange(g_DispatchBatchRebuildState, 0);
  end;

  // Ensure best-backend selection is recalculated once rebuilders finish.
  g_DispatchInitialized := False;
  InterlockedExchange(g_DispatchState, 0);
  atomic_thread_fence(mo_seq_cst);
  if aReinitializeDispatch then
    InitializeDispatch;
end;

// Thread-safe dispatch initialization using atomic operations
procedure DoInitializeDispatch;
var
  LBestBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LBestDispatchState: PSimdDispatchPublishedState;
  LCandidateDispatchState: PSimdDispatchPublishedState;
  LBackendSupportedOnCPU: array[TSimdBackend] of Boolean;
  LIndex: Integer;
  LOldState: LongInt;
begin
  // 快速路径: 已完成初始化
  if g_DispatchState = 2 then
    Exit;

  while InterlockedCompareExchange(g_DispatchBatchRebuildState, 0, 0) <> 0 do
  begin
    ReadBarrier;
    ThreadSwitch;
  end;

  LOldState := InterlockedCompareExchange(g_DispatchState, 1, 0);
  if LOldState = 0 then
  begin
    // 我们是第一个初始化者
    // Note: Do NOT reset g_BackendRegistered here!
    // Backends register themselves during unit initialization,
    // and we don't want to lose that registration.

    // Precompute CPU/OS capability once, then use O(1) lookup during selection.
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
      LBackendSupportedOnCPU[LBackend] := IsBackendAvailableOnCPU(LBackend);

    // Find best available backend
    if g_BackendForced then
    begin
      LBestBackend := g_ForcedBackend;
      LBestDispatchState := nil;

      // Forced backend must be:
      // - registered in this binary
      // - available on current CPU/OS (cpuinfo)
      // - marked available by the backend implementation (BackendInfo.Available)
      if LBestBackend <> sbScalar then
      begin
        if not LBackendSupportedOnCPU[LBestBackend] then
          LBestBackend := sbScalar
        else
        begin
          LBestDispatchState := GetPublishedBackendDispatchState(LBestBackend);
          if (LBestDispatchState = nil) or
             (not LBestDispatchState^.Table.BackendInfo.Available) then
            LBestBackend := sbScalar;
        end;
      end;

      if LBestBackend = sbScalar then
        LBestDispatchState := GetPublishedBackendDispatchState(sbScalar);
    end
    else
    begin
      LBestBackend := sbScalar;
      LBestDispatchState := GetPublishedBackendDispatchState(sbScalar);

      for LIndex := Low(SIMD_BACKEND_PRIORITY_ORDER) to High(SIMD_BACKEND_PRIORITY_ORDER) do
      begin
        LBackend := SIMD_BACKEND_PRIORITY_ORDER[LIndex];
        if LBackendSupportedOnCPU[LBackend] then
        begin
          LCandidateDispatchState := GetPublishedBackendDispatchState(LBackend);
          if (LCandidateDispatchState <> nil) and
             LCandidateDispatchState^.Table.BackendInfo.Available then
          begin
            LBestBackend := LBackend;
            LBestDispatchState := LCandidateDispatchState;
            Break;
          end;
        end;
      end;
    end;

    // Publish the exact backend snapshot selected above so readers never observe
    // a newer backend-state rewrite under the same backend id.
    if LBestDispatchState <> nil then
    begin
      PublishCurrentDispatchState(LBestDispatchState);
    end
    else
    begin
      PublishCurrentDispatchState(nil);
    end;

    g_DispatchInitialized := True;
    WriteBarrier;
    InterlockedExchange(g_DispatchState, 2);

    // Notify listeners after dispatch state is fully published.
    NotifyDispatchChangedHooks;
  end
  else if LOldState = 1 then
  begin
    // 另一个线程正在初始化，自旋等待
    while g_DispatchState <> 2 do
    begin
      ReadBarrier;
      ThreadSwitch;
    end;
  end;
  // LOldState = 2: 已完成，直接返回
end;

procedure InitializeDispatch;
begin
  // Always call DoInitializeDispatch - it has its own guard
  DoInitializeDispatch;
end;

function MatchesControlPlaneIntentLocked(const aExpectForced: Boolean;
  const aExpectedBackend: TSimdBackend): Boolean; inline;
begin
  Result := (g_BackendForced = aExpectForced) and
    ((not aExpectForced) or (g_ForcedBackend = aExpectedBackend));
end;

procedure ApplyControlPlaneIntentLocked(const aExpectForced: Boolean;
  const aExpectedBackend: TSimdBackend); inline;
begin
  g_BackendForced := aExpectForced;
  if aExpectForced then
    g_ForcedBackend := aExpectedBackend
  else
    g_ForcedBackend := sbScalar;
  WriteBarrier;
end;

procedure ReinitializeDispatchLocked; inline;
begin
  g_DispatchInitialized := False;
  InterlockedExchange(g_DispatchState, 0);
  atomic_thread_fence(mo_seq_cst);
  InitializeDispatch;
end;

function RestoreControlPlaneIntentUntilStableLocked(const aExpectForced: Boolean;
  const aExpectedBackend: TSimdBackend): Boolean;
var
  LAttempt: Integer;
begin
  for LAttempt := 1 to SIMD_MAX_CONTROL_PLANE_RESTORE_ATTEMPTS do
  begin
    ApplyControlPlaneIntentLocked(aExpectForced, aExpectedBackend);
    ReinitializeDispatchLocked;
    ReadBarrier;
    if MatchesControlPlaneIntentLocked(aExpectForced, aExpectedBackend) then
      Exit(True);
  end;

  Result := False;
end;

// === Public Interface ===

function GetActiveBackend: TSimdBackend;
var
  LDispatch: PSimdDispatchTable;
begin
  InitializeDispatch;
  LDispatch := GetCurrentPublishedDispatchTable;
  if LDispatch <> nil then
    Result := LDispatch^.Backend
  else
    Result := sbScalar;
end;

// Check if a backend is available on current CPU
function IsBackendAvailableOnCPU(backend: TSimdBackend): Boolean;
begin
  // Delegate to cpuinfo facade (O(1) predicate, no temporary array allocation).
  Result := nextpas.core.simd.cpuinfo.IsBackendSupportedOnCPU(backend);
end;

function IsBackendDispatchable(backend: TSimdBackend): Boolean;
begin
  Result := IsBackendMarkedAvailableForDispatch(backend) and IsBackendAvailableOnCPU(backend);
end;

function GetDispatchableBackends: TSimdBackendArray;
var
  LBackend: TSimdBackend;
  LCount: Integer;
begin
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    Result := nil;
    SetLength(Result, Length(SIMD_BACKEND_PRIORITY_ORDER));
    LCount := 0;
    for LBackend in SIMD_BACKEND_PRIORITY_ORDER do
    begin
      if IsBackendDispatchable(LBackend) then
      begin
        Result[LCount] := LBackend;
        Inc(LCount);
      end;
    end;
    SetLength(Result, LCount);
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

function GetBestDispatchableBackend: TSimdBackend;
var
  LBackend: TSimdBackend;
begin
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    for LBackend in SIMD_BACKEND_PRIORITY_ORDER do
      if IsBackendDispatchable(LBackend) then
        Exit(LBackend);

    Result := sbScalar;
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

function TrySetActiveBackendInternal(backend: TSimdBackend; out aAttemptedSelection: Boolean): Boolean;
var
  LDispatch: PSimdDispatchTable;
  LAutomaticIntentStable: Boolean;
  LPreviousBackendForced: Boolean;
  LPreviousForcedBackend: TSimdBackend;
  LForcedIntentStable: Boolean;
begin
  aAttemptedSelection := False;
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    // Fast fail on backends that are not registered or not wired available.
    if not IsBackendMarkedAvailableForDispatch(backend) then
      Exit(False);

    // CPU/OS capability gate (independent from dispatch-table wiring gate).
    if not IsBackendAvailableOnCPU(backend) then
      Exit(False);

    aAttemptedSelection := True;
    LPreviousBackendForced := g_BackendForced;
    LPreviousForcedBackend := g_ForcedBackend;

    // Backend is valid, force it
    ApplyControlPlaneIntentLocked(True, backend);
    ReinitializeDispatchLocked;
    ReadBarrier;
    LDispatch := GetCurrentPublishedDispatchTable;
    Result := (LDispatch <> nil) and (LDispatch^.Backend = backend);
    if not Result then
    begin
      // A failed TrySetActiveBackend must not leave a stale forced-selection
      // intent behind; otherwise later re-register/rebuild events can revive a
      // backend that this call already reported as not successfully selected.
      // It also must not leave the active dispatch stuck on the transient
      // scalar fallback chosen during the failed forced-selection attempt.
      LAutomaticIntentStable := RestoreControlPlaneIntentUntilStableLocked(False, sbScalar);
      ReadBarrier;
      LDispatch := GetCurrentPublishedDispatchTable;
      Result := (LDispatch <> nil) and (LDispatch^.Backend = backend);
      if Result then
      begin
        // Rollback-time automatic selection may already have reselected the
        // requested backend before this API returns. Preserve the success
        // contract by restoring forced intent as well, so later backend
        // re-register/rebuild events cannot drift to a higher-priority backend.
        LForcedIntentStable := False;
        if RestoreControlPlaneIntentUntilStableLocked(True, backend) then
        begin
          ReadBarrier;
          LDispatch := GetCurrentPublishedDispatchTable;
          LForcedIntentStable := (LDispatch <> nil) and (LDispatch^.Backend = backend) and
            MatchesControlPlaneIntentLocked(True, backend);
        end;

        Result := LForcedIntentStable;
        if not Result then
        begin
          // Once forced-intent stabilization itself exhausts the bounded
          // restore budget, report failure and return to the caller's pre-call
          // stable intent instead of leaking the transient late-force state.
          if LPreviousBackendForced then
          begin
            if not RestoreControlPlaneIntentUntilStableLocked(True, LPreviousForcedBackend) then
            begin
              ApplyControlPlaneIntentLocked(True, LPreviousForcedBackend);
              ReinitializeDispatchLocked;
            end;
          end
          else if not RestoreControlPlaneIntentUntilStableLocked(False, sbScalar) then
          begin
            ApplyControlPlaneIntentLocked(False, sbScalar);
            ReinitializeDispatchLocked;
          end;
        end;
      end
      else if LPreviousBackendForced then
      begin
        // A failed switch must not destroy the caller's previously established
        // forced-selection intent. Restore both the control-plane intent and
        // the published dispatch snapshot to the pre-call forced backend.
        if not RestoreControlPlaneIntentUntilStableLocked(True, LPreviousForcedBackend) then
        begin
          // If repeated late-force mutations spend the bounded rollback budget,
          // issue one last explicit restore to the caller's pre-call forced
          // backend after the mutation storm has exhausted itself.
          ApplyControlPlaneIntentLocked(True, LPreviousForcedBackend);
          ReinitializeDispatchLocked;
        end;
      end
      else if not LAutomaticIntentStable then
      begin
        // Mirror the previous-forced post-cap closeout for automatic callers:
        // once repeated late-force mutations have spent the bounded restore
        // budget, perform one last explicit automatic restore before returning.
        ApplyControlPlaneIntentLocked(False, sbScalar);
        ReinitializeDispatchLocked;
      end;
    end;
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

// TrySetActiveBackend - returns True if backend was successfully set
function TrySetActiveBackend(backend: TSimdBackend): Boolean;
var
  LAttemptedSelection: Boolean;
begin
  Result := TrySetActiveBackendInternal(backend, LAttemptedSelection);
end;

// SetActiveBackend - now with safety check, falls back to Scalar if unavailable
procedure SetActiveBackend(backend: TSimdBackend);
var
  LAttemptedSelection: Boolean;
begin
  // Try to set the requested backend
  if TrySetActiveBackendInternal(backend, LAttemptedSelection) then
    Exit;

  // Only precondition-unavailable requests should silently degrade to Scalar.
  // If the backend was initially selectable but failed later during hook-driven
  // rebuild/rollback, preserve the state that TrySetActiveBackend already
  // restored instead of clobbering it with a scalar forced-selection.
  if not LAttemptedSelection then
    TrySetActiveBackend(sbScalar);
end;

procedure ResetToAutomaticBackend;
begin
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    if not RestoreControlPlaneIntentUntilStableLocked(False, sbScalar) then
    begin
      // If repeated late-force mutations exhaust the bounded restore helper,
      // issue one final explicit automatic closeout before returning.
      ApplyControlPlaneIntentLocked(False, sbScalar);
      ReinitializeDispatchLocked;
    end;
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

function IsVectorAsmEnabled: Boolean;
begin
  Result := InterlockedCompareExchange(g_VectorAsmEnabledState, 0, 0) <> 0;
end;

// ⚠️ THREAD SAFETY: runtime toggling rebuilds backend tables.
// Call this only in controlled phases (startup/tests), not concurrently with
// hot SIMD traffic from worker threads.
procedure SetVectorAsmEnabled(enabled: Boolean);
var
  LExpectedState: LongInt;
  LCurrentState: LongInt;
  LDispatchWasInitialized: Boolean;
  LPreviousBackendForced: Boolean;
  LPreviousForcedBackend: TSimdBackend;
begin
  if enabled then
    LExpectedState := 1
  else
    LExpectedState := 0;

  // Fast path for stable state without taking lock.
  if InterlockedCompareExchange(g_VectorAsmEnabledState, LExpectedState, LExpectedState) = LExpectedState then
    Exit;

  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    // Re-check after acquiring lock (another writer may have already updated).
    LCurrentState := InterlockedCompareExchange(g_VectorAsmEnabledState, LExpectedState, LExpectedState);
    if LCurrentState = LExpectedState then
      Exit;

    LDispatchWasInitialized := g_DispatchState <> 0;
    LPreviousBackendForced := g_BackendForced;
    LPreviousForcedBackend := g_ForcedBackend;

    InterlockedExchange(g_VectorAsmEnabledState, LExpectedState);
    WriteBarrier;

    // Backend tables are published during unit initialization, so a pre-init
    // runtime toggle still needs to rebuild their Available/capability view.
    RebuildBackendsAfterFeatureToggle(LDispatchWasInitialized);

    if LDispatchWasInitialized then
    begin
      ReadBarrier;
      if (g_BackendForced <> LPreviousBackendForced) or
         (LPreviousBackendForced and (g_ForcedBackend <> LPreviousForcedBackend)) then
      begin
        // A feature toggle should preserve the caller's pre-existing
        // forced-vs-automatic selection intent. Late dispatch hooks may
        // temporarily reset or replace it during notification, so reapply the
        // original control-plane mode before returning.
        if not RestoreControlPlaneIntentUntilStableLocked(LPreviousBackendForced, LPreviousForcedBackend) then
        begin
          ApplyControlPlaneIntentLocked(LPreviousBackendForced, LPreviousForcedBackend);
          ReinitializeDispatchLocked;
        end;
      end;
    end;
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

function GetDispatchTable: PSimdDispatchTable; inline;
begin
  if g_DispatchState <> 2 then
    InitializeDispatch
  else
    ReadBarrier;
  Result := GetCurrentPublishedDispatchTable;
end;

// === Backend Registration ===

procedure RegisterBackend(backend: TSimdBackend; const dispatchTable: TSimdDispatchTable);
var
  LCanonicalTable: TSimdDispatchTable;
  LShouldReinitialize: Boolean;
  LPreviousBackendForced: Boolean;
  LPreviousForcedBackend: TSimdBackend;
begin
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    // RegisterBackend mutates managed-string metadata, published dispatch-state
    // ownership lists, and dispatch selection state. Serialize all control-plane
    // writers so concurrent re-register tests cannot tear record assignment or
    // corrupt the owned published-state chain.
    LCanonicalTable := dispatchTable;
    LCanonicalTable.Backend := backend;
    LCanonicalTable.BackendInfo.Backend := backend;
    LCanonicalTable.BackendInfo.Priority := GetSimdBackendPriorityValue(backend);
    if backend = sbScalar then
      LCanonicalTable.BackendInfo.Available := True;
    if LCanonicalTable.BackendInfo.Name = '' then
      LCanonicalTable.BackendInfo.Name := DefaultBackendName(backend);
    if LCanonicalTable.BackendInfo.Description = '' then
      LCanonicalTable.BackendInfo.Description := DefaultBackendDescription(backend);
    EnsureUniqueBackendInfoText(LCanonicalTable.BackendInfo);
    LPreviousBackendForced := g_BackendForced;
    LPreviousForcedBackend := g_ForcedBackend;

    g_BackendTables[backend] := LCanonicalTable;
    PublishBackendDispatchTable(backend, LCanonicalTable);
    WriteBarrier;  // Ensure published snapshot is visible before marking as registered
    g_BackendRegistered[backend] := True;
    WriteBarrier;  // Ensure registration is visible before clearing initialized flag

    // Re-select immediately only after dispatch has already been initialized.
    LShouldReinitialize := (g_DispatchState = 2) and
      (InterlockedCompareExchange(g_RegisterBackendReinitializeSuspendDepth, 0, 0) = 0);
    g_DispatchInitialized := False;
    InterlockedExchange(g_DispatchState, 0);  // Reset atomic state
    atomic_thread_fence(mo_seq_cst); // Full barrier before re-initialization
    if LShouldReinitialize then
    begin
      InitializeDispatch;
      ReadBarrier;
      if (g_BackendForced <> LPreviousBackendForced) or
         (LPreviousBackendForced and (g_ForcedBackend <> LPreviousForcedBackend)) then
      begin
        // RegisterBackend is a data/control publication helper, not a
        // user-visible control-plane selection API. If a dispatch-changed hook
        // mutates forced-vs-automatic mode during notification, restore the
        // caller's pre-call intent before returning.
        if not RestoreControlPlaneIntentUntilStableLocked(LPreviousBackendForced, LPreviousForcedBackend) then
        begin
          ApplyControlPlaneIntentLocked(LPreviousBackendForced, LPreviousForcedBackend);
          ReinitializeDispatchLocked;
        end;
      end;
    end;
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

function IsBackendRegistered(backend: TSimdBackend): Boolean;
begin
  ReadBarrier;
  Result := g_BackendRegistered[backend];
end;

function GetBackendInfo(backend: TSimdBackend): TSimdBackendInfo;
var
  LDispatchTable: PSimdDispatchTable;
begin
  Result := Default(TSimdBackendInfo);

  // Ensure consistent view of registration flag and published table contents.
  ReadBarrier;
  if g_BackendRegistered[backend] then
  begin
    LDispatchTable := GetPublishedBackendDispatchTable(backend);
    if LDispatchTable <> nil then
      Result := LDispatchTable^.BackendInfo
    else
      Result.Backend := backend;
    Result.Priority := GetSimdBackendPriorityValue(backend);
  end
  else
  begin
    // Preserve canonical metadata for unregistered backends too so dispatch and
    // public ABI text getters do not drift apart.
    Result.Backend := backend;
    Result.Available := False;
    Result.Priority := GetSimdBackendPriorityValue(backend);
  end;

  Result.Backend := backend;
  Result.Priority := GetSimdBackendPriorityValue(backend);
  if Result.Name = '' then
    Result.Name := DefaultBackendName(backend);
  if Result.Description = '' then
    Result.Description := DefaultBackendDescription(backend);
  EnsureUniqueBackendInfoText(Result);
end;

function GetBackendNameTextPtr(backend: TSimdBackend): PAnsiChar;
var
  LDispatchTable: PSimdDispatchTable;
begin
  ReadBarrier;
  if g_BackendRegistered[backend] then
  begin
    LDispatchTable := GetPublishedBackendDispatchTable(backend);
    if (LDispatchTable <> nil) and (LDispatchTable^.BackendInfo.Name <> '') then
      Exit(PAnsiChar(LDispatchTable^.BackendInfo.Name));
  end;
  Result := PAnsiChar(g_DefaultBackendNames[backend]);
end;

function GetBackendDescriptionTextPtr(backend: TSimdBackend): PAnsiChar;
var
  LDispatchTable: PSimdDispatchTable;
begin
  ReadBarrier;
  if g_BackendRegistered[backend] then
  begin
    LDispatchTable := GetPublishedBackendDispatchTable(backend);
    if (LDispatchTable <> nil) and (LDispatchTable^.BackendInfo.Description <> '') then
      Exit(PAnsiChar(LDispatchTable^.BackendInfo.Description));
  end;
  Result := PAnsiChar(g_DefaultBackendDescriptions[backend]);
end;

function TryGetRegisteredBackendDispatchTable(backend: TSimdBackend; out dispatchTable: TSimdDispatchTable): Boolean;
var
  LPublishedTable: PSimdDispatchTable;
begin
  dispatchTable := Default(TSimdDispatchTable);

  // Ensure we see a consistent snapshot of the registration + published table.
  ReadBarrier;

  if g_BackendRegistered[backend] then
  begin
    LPublishedTable := GetPublishedBackendDispatchTable(backend);
    if LPublishedTable <> nil then
    begin
      dispatchTable := LPublishedTable^;
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure RegisterBackendRebuilder(backend: TSimdBackend; rebuilder: TBackendRebuilder);
begin
  g_BackendRebuilders[backend] := rebuilder;
  WriteBarrier;
end;

// === Dispatch Table Helpers ===

{$I nextpas.core.simd.dispatch.baseline.inc}

// 修复 允许 tier 后端从 SSE2 继承实现，而非从标量基线开始
function CloneDispatchTable(fromBackend: TSimdBackend; var dispatchTable: TSimdDispatchTable): Boolean;
var
  savedBackend: TSimdBackend;
  savedInfo: TSimdBackendInfo;
begin
  // 保存当前后端信息（调用者可能已经设置）
  savedBackend := dispatchTable.Backend;
  savedInfo := dispatchTable.BackendInfo;

  if g_BackendRegistered[fromBackend] then
  begin
    if GetPublishedBackendDispatchTable(fromBackend) <> nil then
    begin
      // 从源后端复制整个派发表
      dispatchTable := GetPublishedBackendDispatchTable(fromBackend)^;
      Result := True;
    end
    else
    begin
      FillBaseDispatchTable(dispatchTable);
      Result := False;
    end;
  end
  else
  begin
    // 源后端未注册，回退到标量基线
    FillBaseDispatchTable(dispatchTable);
    Result := False;
  end;

  // 恢复后端信息（不复制源后端的信息）
  dispatchTable.Backend := savedBackend;
  dispatchTable.BackendInfo := savedInfo;
end;

// === Initialization ===

initialization
  EnsureDispatchControlPlaneInitialized;

finalization
  FinalizeDispatchPublishedStates;
  SetLength(g_DispatchChangedHooks, 0);
  if g_DispatchControlPlaneInitialized then
  begin
    DoneCriticalSection(g_DispatchHooksLock);
    DoneCriticalSection(g_VectorAsmToggleLock);
    g_DispatchControlPlaneInitialized := False;
  end;

end.
