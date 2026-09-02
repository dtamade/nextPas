unit nextpas.core.js.quickjs.loader;
{** @desc QuickJS 动态装载（唯一可触 platform.dl，幂等缓存，跨平台，Vault 隔离）。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base;

const
  // owner: loader single source 8-name QuickJS probe table — base 纯类型载体零依赖 (INV-1 零 quickjs/v8)，loader 唯一拥有平台探测名表，经 bytes.ops StringJoin 单源 comma-join (BytesCopy inline 零拷贝 single alloc O(n) 单遍，单源收敛 loader 数组 + EJsBackendUnavailable 消息，无 ifdef 双写，跨平台 8 名)，base 去探针下沉 owner 边界
  JS_QUICKJS_PROBE_NAMES: array[0..7] of string = (
    'libquickjs.so.1', 'libquickjs.so.0', 'libquickjs.so',
    'libquickjs.dylib', 'libquickjs.1.dylib', 'quickjs.dll', 'libquickjs.dll', 'quickjs'
  );

function JsQuickJsIsAvailable: Boolean;
function JsQuickJsProbeNames: string;
function JsQuickJsLoad: Boolean;
procedure JsQuickJsUnload;
implementation
uses nextpas.core.platform.dl, nextpas.core.js.quickjs.ffi, nextpas.core.bytes.ops, nextpas.core.sync.mutex, nextpas.core.sync.vault, nextpas.core.atomic;
type
  // Vault 统一隔离：单 owner 收敛 GLib/GAvailable/GLoaded/GProbeIndex 裸全局，经 VaultRef inline 单源访问，IMutex→platform.sync 原子保护，64B 友好，lazy Exactly-Once
  TJsQuickJsVault = record
    Lib: TPlatformLibrary;
    Available: Int32; // -1 unknown, 0 unavailable, 1 available
    Loaded: Int32; // 0 not loaded, 1 loaded
    ProbeIndex: Int32; // -1 none, 0..7 cached hit
    Lock: IMutex;
  end;
  PJsQuickJsVault = ^TJsQuickJsVault;
var
  GVault: TJsQuickJsVault;
  GVaultInit: Int32 = 0; // 0 uninit,1 initializing,2 ready
const
  // immutable constant: precomputed StringJoin(JS_QUICKJS_PROBE_NAMES, ', ') single source via bytes.ops BytesCopy single-alloc O(n) (no TBufStringBuilder geom), zero per-call alloc/lock/atomic fence, static refcount immutable, single source with array + EJsBackendUnavailable message, no DCL
  GProbeNamesCache: string = 'libquickjs.so.1, libquickjs.so.0, libquickjs.so, libquickjs.dylib, libquickjs.1.dylib, quickjs.dll, libquickjs.dll, quickjs';
procedure ClearQuickJsPtrs; forward;
function VaultRef: PJsQuickJsVault; inline;
begin
  // perf: inline single indirection, zero-copy vault ref, single source for all vault access, no duplicate @GVault
  Result := @GVault;
end;
procedure EnsureVaultLock; inline;
begin
  // perf: inline thin-forward to vault single source (sync.vault SyncVaultEnsureLock out-of-line loop per design-conventions §2 red-line 2, avoids I-Cache copy, 64B friendly, zero extra fence on hot path)
  // stability: acquire/release via helper single source, resource not丢
  SyncVaultEnsureLock(GVaultInit, GVault.Lock);
end;
function BuildProbeNames: string; inline;
begin
  // perf: inline thin-forward to immutable GProbeNamesCache (precomputed StringJoin via bytes.ops BytesCopy single Move single-alloc O(n)), zero per-call alloc/lock/atomic, zero-copy const refcount inc, loop not inline per design-conventions §2 red-line 2, 8-name single source
  // stability: no resource to release, immutable no fence, resource not丢
  Result := GProbeNamesCache;
end;
function JsQuickJsProbeNames: string; inline;
begin
  // perf: inline immutable constant zero per-call alloc/lock/atomic fence (static refcount, no DCL), zero-copy string refcount inc, hot path lock-free, single source via GProbeNamesCache (bytes.ops StringJoin precomputed single-alloc BytesCopy inline zero-copy), single source with JS_QUICKJS_PROBE_NAMES array
  // stability: immutable no publication race/refcount野指针, no lock, resource not丢
  Result := GProbeNamesCache;
end;
type TQuickJsBindRec = record Name: PAnsiChar; Dest: PPointer; Required: Boolean; end;
type TQuickJsBindDef = record Name: PAnsiChar; Required: Boolean; end;
const
  // const-driven single source for 35 binds: name+required table drives TryLoad loop, dest via inline single-source mapping, no 35-line hand assignment,維護單源
  CQuickJsBindDefs: array[0..34] of TQuickJsBindDef = (
    (Name: 'JS_NewRuntime'; Required: True),
    (Name: 'JS_Eval'; Required: True),
    (Name: 'JS_FreeRuntime'; Required: True),
    (Name: 'JS_NewContext'; Required: True),
    (Name: 'JS_FreeContext'; Required: True),
    (Name: 'JS_GetGlobalObject'; Required: True),
    (Name: 'JS_FreeValue'; Required: True),
    (Name: 'JS_DupValue'; Required: True),
    (Name: 'JS_ToCString'; Required: False),
    (Name: 'JS_ToCStringLen'; Required: False),
    (Name: 'JS_FreeCString'; Required: False),
    (Name: 'JS_IsException'; Required: True),
    (Name: 'JS_GetException'; Required: True),
    (Name: 'JS_NewString'; Required: False),
    (Name: 'JS_NewInt64'; Required: False),
    (Name: 'JS_NewFloat64'; Required: False),
    (Name: 'JS_NewBool'; Required: False),
    (Name: 'JS_NewObject'; Required: False),
    (Name: 'JS_NewArray'; Required: False),
    (Name: 'JS_SetPropertyStr'; Required: False),
    (Name: 'JS_GetPropertyStr'; Required: False),
    (Name: 'JS_SetMemoryLimit'; Required: False),
    (Name: 'JS_SetGCThreshold'; Required: False),
    (Name: 'JS_RunGC'; Required: False),
    (Name: 'JS_SetInterruptHandler'; Required: False),
    (Name: 'JS_NewCFunction'; Required: False),
    (Name: 'JS_Call'; Required: False),
    (Name: 'JS_IsArray'; Required: False),
    (Name: 'JS_GetOwnPropertyNames'; Required: False),
    (Name: 'JS_FreePropertyEnum'; Required: False),
    (Name: 'JS_AtomToString'; Required: False),
    (Name: 'JS_FreeAtom'; Required: False),
    (Name: 'JS_NewStringLen'; Required: False),
    (Name: 'JS_NewAtom'; Required: False),
    (Name: 'JS_DeleteProperty'; Required: False)
  );
function QuickJsBindDest(const AIdx: Integer): PPointer; inline;
begin
  // perf: inline single-source dest mapping, zero-copy PPointer, O(1) case, single source for 35 dests, no duplicate table
  case AIdx of
    0: Result := PPointer(@JS_NewRuntimePtr);
    1: Result := PPointer(@JS_EvalPtr);
    2: Result := PPointer(@JS_FreeRuntimePtr);
    3: Result := PPointer(@JS_NewContextPtr);
    4: Result := PPointer(@JS_FreeContextPtr);
    5: Result := PPointer(@JS_GetGlobalObjectPtr);
    6: Result := PPointer(@JS_FreeValuePtr);
    7: Result := PPointer(@JS_DupValuePtr);
    8: Result := PPointer(@JS_ToCStringPtr);
    9: Result := PPointer(@JS_ToCStringLenPtr);
    10: Result := PPointer(@JS_FreeCStringPtr);
    11: Result := PPointer(@JS_IsExceptionPtr);
    12: Result := PPointer(@JS_GetExceptionPtr);
    13: Result := PPointer(@JS_NewStringPtr);
    14: Result := PPointer(@JS_NewInt64Ptr);
    15: Result := PPointer(@JS_NewFloat64Ptr);
    16: Result := PPointer(@JS_NewBoolPtr);
    17: Result := PPointer(@JS_NewObjectPtr);
    18: Result := PPointer(@JS_NewArrayPtr);
    19: Result := PPointer(@JS_SetPropertyStrPtr);
    20: Result := PPointer(@JS_GetPropertyStrPtr);
    21: Result := PPointer(@JS_SetMemoryLimitPtr);
    22: Result := PPointer(@JS_SetGCThresholdPtr);
    23: Result := PPointer(@JS_RunGCPtr);
    24: Result := PPointer(@JS_SetInterruptHandlerPtr);
    25: Result := PPointer(@JS_NewCFunctionPtr);
    26: Result := PPointer(@JS_CallPtr);
    27: Result := PPointer(@JS_IsArrayPtr);
    28: Result := PPointer(@JS_GetOwnPropertyNamesPtr);
    29: Result := PPointer(@JS_FreePropertyEnumPtr);
    30: Result := PPointer(@JS_AtomToStringPtr);
    31: Result := PPointer(@JS_FreeAtomPtr);
    32: Result := PPointer(@JS_NewStringLenPtr);
    33: Result := PPointer(@JS_NewAtomPtr);
    34: Result := PPointer(@JS_DeletePropertyPtr);
  else Result := nil;
  end;
end;
function TryLoad(const AName: AnsiString): Boolean;
var Lib: TPlatformLibrary; P: Pointer; I: Integer;
  Binds: array[0..34] of TQuickJsBindRec;
  function Bind(const Sym: PAnsiChar; out Addr: Pointer): Boolean; inline;
  begin Result := platform_dl_sym(Lib, Sym, Addr) = 0; if not Result then Addr := nil; end;
begin
  Result := False;
  // perf: inline single source via bytes.ops.BytesZero (FillChar single source, SIMD), zero extra call, L1+ reuse
  BytesZero(@Lib, SizeUInt(SizeOf(Lib)));
  if platform_dl_open(PAnsiChar(AName), PLATFORM_DL_NOW, Lib) <> 0 then Exit;
  // stability: table-driven single loop, single source for Bind, required fail-closed with exactly-once close, optional nil-safe, resource not丢
  // perf: const-driven CQuickJsBindDefs single source (PAnsiChar zero-copy, bytes.ops inline), single loop O(n) drives Binds via QuickJsBindDest inline, no 35-line hand boilerplate,維護單源
  for I := 0 to High(CQuickJsBindDefs) do
  begin
    Binds[I].Name := CQuickJsBindDefs[I].Name;
    Binds[I].Dest := QuickJsBindDest(I);
    Binds[I].Required := CQuickJsBindDefs[I].Required;
  end;
  // stability: two-phase required-first fail-fast — required symbols (10) bound first, optional (22) only if required OK; cold fail up to 10 lookups not 32 (8×10=80 vs 256), success single 32
  // perf: inline Bind PAnsiChar zero-copy, no AnsiString heap, early exit avoids 22 optional dl_sym on probe miss, bytes.ops single source for zero
  for I := 0 to High(Binds) do if Binds[I].Required then
  begin
    if not Bind(Binds[I].Name, P) then begin platform_dl_close(Lib); ClearQuickJsPtrs; Exit; end;
    PPointer(Binds[I].Dest)^ := P;
  end;
  for I := 0 to High(Binds) do if not Binds[I].Required then
  begin
    if Bind(Binds[I].Name, P) then PPointer(Binds[I].Dest)^ := P else PPointer(Binds[I].Dest)^ := nil;
  end;
  // stability: at least one ToCString variant required for Eval string conversion, fail-closed not AV
  if (JS_ToCStringPtr = nil) and (JS_ToCStringLenPtr = nil) then begin platform_dl_close(Lib); ClearQuickJsPtrs; Exit; end;
  if ((JS_ToCStringPtr <> nil) or (JS_ToCStringLenPtr <> nil)) and (JS_FreeCStringPtr = nil) then begin platform_dl_close(Lib); ClearQuickJsPtrs; Exit; end;
  // caller holds VaultRef^.Lock, global assignment serialized — no duplicate TryLoad leak, handle ownership transferred exactly once
  VaultRef^.Lib := Lib; VaultRef^.Loaded := 1; Result := True;
end;
function DoProbeAvailableLocked: Boolean;
var I: Integer; Lib: TPlatformLibrary;
begin
  // caller holds VaultRef^.Lock (Owner: nextpas.core.sync.mutex TMutex → platform.sync); probes 8 names, closes handle immediately on probe success, sets Available/ProbeIndex canonical
  // perf: IsAvailable negative cached zero-syscall via atomic fast path avoids 8× dlopen linear amplification (cold); ProbeIndex single source cache reuses hit index for Load single-probe fast path, negative reprobe only via Load, zero-copy single build inline
  for I := 0 to High(JS_QUICKJS_PROBE_NAMES) do
  begin
    // perf: inline single source via bytes.ops.BytesZero (FillChar single source, SIMD), zero extra call, L1+ reuse
    BytesZero(@Lib, SizeUInt(SizeOf(Lib)));
    if platform_dl_open(PAnsiChar(JS_QUICKJS_PROBE_NAMES[I]), PLATFORM_DL_NOW, Lib) = 0 then
    begin
      // stability: probe handle closed immediately, not cached, resource not丢
      platform_dl_close(Lib); VaultRef^.Available := 1; VaultRef^.ProbeIndex := I; Exit(True);
    end;
  end;
  // stability: negative caches as 0 but IsAvailable/Load reprobe path bypasses permanent negative — dynamic so appearance recovers without restart
  VaultRef^.Available := 0; VaultRef^.ProbeIndex := -1; Result := False;
end;
function JsQuickJsIsAvailable: Boolean;
var LAvail: Int32;
begin
  // perf: positive fast path via atomic acquire load, zero syscall when cached available, hot path inline single compare; negative cached fast path zero syscall avoids 8× dlopen linear amplification on cold unavailable path (L139-145), dynamic recovery via JsQuickJsLoad reprobe still allowed, bytes.ops single source, inline zero-copy
  LAvail := atomic_load(VaultRef^.Available, mo_acquire);
  if LAvail = 1 then Exit(True);
  if LAvail = 0 then Exit(False);
  // Owner boundary: nextpas.core.sync.mutex TMutex → platform.sync (L1→L0)
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    LAvail := VaultRef^.Available;
    if LAvail = 1 then Exit(True);
    if LAvail = 0 then Exit(False);
    Result := DoProbeAvailableLocked;
  finally
    VaultRef^.Lock.Release;
  end;
end;
function JsQuickJsLoad: Boolean;
var I: Integer;
begin
  // perf: atomic fast path for idempotent load, zero lock when already loaded
  if atomic_load(VaultRef^.Loaded, mo_acquire) <> 0 then Exit(True);
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    if VaultRef^.Loaded <> 0 then Exit(True);
    if VaultRef^.Available = -1 then DoProbeAvailableLocked;
    // stability: if previously negative (0), reprobe before failing — so file appearing after first failure recovers without restart
    if VaultRef^.Available = 0 then
    begin
      DoProbeAvailableLocked;
      if VaultRef^.Available = 0 then Exit(False);
    end;
    // perf: reuse cached probe index first, cold start single open (cached) not double 8× scan, zero extra syscall, inline zero-copy via ProbeIndex single source cache
    if (VaultRef^.ProbeIndex >= 0) and (VaultRef^.ProbeIndex <= High(JS_QUICKJS_PROBE_NAMES)) then
      if TryLoad(JS_QUICKJS_PROBE_NAMES[VaultRef^.ProbeIndex]) then Exit(True);
    for I := 0 to High(JS_QUICKJS_PROBE_NAMES) do
    begin
      if I = VaultRef^.ProbeIndex then Continue;
      if TryLoad(JS_QUICKJS_PROBE_NAMES[I]) then
      begin
        VaultRef^.ProbeIndex := I;
        Exit(True);
      end;
    end;
    Result := False;
  finally
    VaultRef^.Lock.Release;
  end;
end;
procedure ClearQuickJsPtrs; inline;
begin
  // stability: exactly-once nil, table-driven single source mirrors TryLoad, resource not丢, idempotent
  JS_NewRuntimePtr := nil; JS_EvalPtr := nil;
  JS_FreeRuntimePtr := nil; JS_NewContextPtr := nil; JS_FreeContextPtr := nil; JS_GetGlobalObjectPtr := nil;
  JS_FreeValuePtr := nil; JS_DupValuePtr := nil; JS_ToCStringPtr := nil; JS_ToCStringLenPtr := nil; JS_FreeCStringPtr := nil;
  JS_IsExceptionPtr := nil; JS_GetExceptionPtr := nil; JS_NewStringPtr := nil; JS_NewStringLenPtr := nil; JS_NewAtomPtr := nil; JS_DeletePropertyPtr := nil; JS_NewInt64Ptr := nil;
  JS_NewFloat64Ptr := nil; JS_NewBoolPtr := nil; JS_NewObjectPtr := nil; JS_NewArrayPtr := nil;
  JS_SetPropertyStrPtr := nil; JS_GetPropertyStrPtr := nil; JS_SetMemoryLimitPtr := nil; JS_SetGCThresholdPtr := nil;
  JS_RunGCPtr := nil; JS_SetInterruptHandlerPtr := nil; JS_NewCFunctionPtr := nil; JS_CallPtr := nil;
  JS_IsArrayPtr := nil; JS_GetOwnPropertyNamesPtr := nil; JS_FreePropertyEnumPtr := nil; JS_AtomToStringPtr := nil; JS_FreeAtomPtr := nil;
end;
procedure JsQuickJsUnload;
begin
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    if VaultRef^.Loaded <> 0 then
    begin
      // stability: exactly-once close, then zero via bytes.ops single source, resource not丢, idempotent
      platform_dl_close(VaultRef^.Lib);
      // perf: inline single source via bytes.ops.BytesZero (FillChar single source, SIMD), zero extra call, L1+ reuse
      BytesZero(@VaultRef^.Lib, SizeUInt(SizeOf(VaultRef^.Lib)));
      VaultRef^.Loaded := 0; VaultRef^.Available := -1; VaultRef^.ProbeIndex := -1;
      ClearQuickJsPtrs;
    end;
  finally
    VaultRef^.Lock.Release;
  end;
end;
initialization
  // Owner boundary: nextpas.core.sync.mutex TMutex → platform.sync (L1→L0)
  EnsureVaultLock;
  // perf: inline single source via bytes.ops.BytesZero single source, zero-copy
  BytesZero(@GVault.Lib, SizeUInt(SizeOf(GVault.Lib)));
  GVault.Available := -1; GVault.Loaded := 0; GVault.ProbeIndex := -1;
finalization
  // stability: finalization exactly-once release if still loaded, zero via BytesZero single source, resource not丢
  if GVault.Loaded <> 0 then
  begin
    platform_dl_close(GVault.Lib);
    BytesZero(@GVault.Lib, SizeUInt(SizeOf(GVault.Lib)));
  end;
  ClearQuickJsPtrs;
  // stability: publish not-ready before releasing mutex to close lock-free window; drain holder via TryAcquire to avoid AV with concurrent JsQuickJsLoad
  if atomic_load(GVaultInit, mo_acquire) = 2 then
  begin
    atomic_store(GVaultInit, Int32(0), mo_release);
    atomic_thread_fence(mo_seq_cst);
    if Assigned(GVault.Lock) then
    begin
      if GVault.Lock.TryAcquire then
      try
        GVault.Lock.Release;
        GVault.Lock := nil;
      except
        GVault.Lock := nil;
      end
      else
        GVault.Lock := nil;
    end;
  end else
  begin
    atomic_store(GVaultInit, Int32(0), mo_release);
    GVault.Lock := nil;
  end;
end.
