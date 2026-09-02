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
  GProbeNamesCache: string = ''; // cached handle reuse: one-time build, zero per-call alloc/geom expand on error path
  GProbeNamesReady: Int32 = 0; // atomic publication flag: 0 uninit,1 ready — guards non-atomic string via acquire/release
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
function BuildProbeNames: string;
begin
  // perf: single source via bytes.ops StringJoin single source (BytesCopy inline zero-copy single Move, single alloc O(n) precompute total, no TBufStringBuilder geometric alloc/try-finally per call, loop not inline per design-conventions §2 red-line 2, 8-name table single source)
  // stability: no resource to release, exception-safe single SetLength, single source for 8-name probe table via bytes.ops, resource not丢
  Result := StringJoin(JS_QUICKJS_PROBE_NAMES, ', ');
end;
function JsQuickJsProbeNames: string;
begin
  // perf: fast path atomic acquire load of Ready flag (single atomic, no lock/StringJoin alloc), zero-copy immutable string refcount inc only when ready, hot path lock-free after init, single source via bytes.ops StringJoin
  // stability: DCL with acquire/release fences guards non-atomic string publication (refcount野指针 fix), Exactly-Once via VaultRef^.Lock→platform.sync, GProbeNamesReady acquire before string read + release after string write
  if atomic_load(GProbeNamesReady, mo_acquire) <> 0 then Exit(GProbeNamesCache);
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    if atomic_load(GProbeNamesReady, mo_acquire) <> 0 then Exit(GProbeNamesCache);
    Result := BuildProbeNames;
    GProbeNamesCache := Result;
    atomic_store(GProbeNamesReady, Int32(1), mo_release);
  finally
    VaultRef^.Lock.Release;
  end;
end;
type TQuickJsBindRec = record Name: PAnsiChar; Dest: PPointer; Required: Boolean; end;
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
  // perf: single table loop, inline Bind, zero-copy PPointer dest, no 20+ duplicate Bind pattern, O(1) dispatch, bytes.ops single source
  // perf: PAnsiChar literals zero-copy (no AnsiString heap 32× alloc), single source table, inline Bind via platform.dl single source, zero per-probe string alloc
  Binds[0].Name := 'JS_NewRuntime'; Binds[0].Dest := PPointer(@JS_NewRuntimePtr); Binds[0].Required := True;
  Binds[1].Name := 'JS_Eval'; Binds[1].Dest := PPointer(@JS_EvalPtr); Binds[1].Required := True;
  Binds[2].Name := 'JS_FreeRuntime'; Binds[2].Dest := PPointer(@JS_FreeRuntimePtr); Binds[2].Required := True;
  Binds[3].Name := 'JS_NewContext'; Binds[3].Dest := PPointer(@JS_NewContextPtr); Binds[3].Required := True;
  Binds[4].Name := 'JS_FreeContext'; Binds[4].Dest := PPointer(@JS_FreeContextPtr); Binds[4].Required := True;
  Binds[5].Name := 'JS_GetGlobalObject'; Binds[5].Dest := PPointer(@JS_GetGlobalObjectPtr); Binds[5].Required := True;
  Binds[6].Name := 'JS_FreeValue'; Binds[6].Dest := PPointer(@JS_FreeValuePtr); Binds[6].Required := True;
  Binds[7].Name := 'JS_DupValue'; Binds[7].Dest := PPointer(@JS_DupValuePtr); Binds[7].Required := True;
  Binds[8].Name := 'JS_ToCString'; Binds[8].Dest := PPointer(@JS_ToCStringPtr); Binds[8].Required := False;
  Binds[9].Name := 'JS_ToCStringLen'; Binds[9].Dest := PPointer(@JS_ToCStringLenPtr); Binds[9].Required := False;
  Binds[10].Name := 'JS_FreeCString'; Binds[10].Dest := PPointer(@JS_FreeCStringPtr); Binds[10].Required := False;
  Binds[11].Name := 'JS_IsException'; Binds[11].Dest := PPointer(@JS_IsExceptionPtr); Binds[11].Required := True;
  Binds[12].Name := 'JS_GetException'; Binds[12].Dest := PPointer(@JS_GetExceptionPtr); Binds[12].Required := True;
  Binds[13].Name := 'JS_NewString'; Binds[13].Dest := PPointer(@JS_NewStringPtr); Binds[13].Required := False;
  Binds[14].Name := 'JS_NewInt64'; Binds[14].Dest := PPointer(@JS_NewInt64Ptr); Binds[14].Required := False;
  Binds[15].Name := 'JS_NewFloat64'; Binds[15].Dest := PPointer(@JS_NewFloat64Ptr); Binds[15].Required := False;
  Binds[16].Name := 'JS_NewBool'; Binds[16].Dest := PPointer(@JS_NewBoolPtr); Binds[16].Required := False;
  Binds[17].Name := 'JS_NewObject'; Binds[17].Dest := PPointer(@JS_NewObjectPtr); Binds[17].Required := False;
  Binds[18].Name := 'JS_NewArray'; Binds[18].Dest := PPointer(@JS_NewArrayPtr); Binds[18].Required := False;
  Binds[19].Name := 'JS_SetPropertyStr'; Binds[19].Dest := PPointer(@JS_SetPropertyStrPtr); Binds[19].Required := False;
  Binds[20].Name := 'JS_GetPropertyStr'; Binds[20].Dest := PPointer(@JS_GetPropertyStrPtr); Binds[20].Required := False;
  Binds[21].Name := 'JS_SetMemoryLimit'; Binds[21].Dest := PPointer(@JS_SetMemoryLimitPtr); Binds[21].Required := False;
  Binds[22].Name := 'JS_SetGCThreshold'; Binds[22].Dest := PPointer(@JS_SetGCThresholdPtr); Binds[22].Required := False;
  Binds[23].Name := 'JS_RunGC'; Binds[23].Dest := PPointer(@JS_RunGCPtr); Binds[23].Required := False;
  Binds[24].Name := 'JS_SetInterruptHandler'; Binds[24].Dest := PPointer(@JS_SetInterruptHandlerPtr); Binds[24].Required := False;
  Binds[25].Name := 'JS_NewCFunction'; Binds[25].Dest := PPointer(@JS_NewCFunctionPtr); Binds[25].Required := False;
  Binds[26].Name := 'JS_Call'; Binds[26].Dest := PPointer(@JS_CallPtr); Binds[26].Required := False;
  Binds[27].Name := 'JS_IsArray'; Binds[27].Dest := PPointer(@JS_IsArrayPtr); Binds[27].Required := False;
  Binds[28].Name := 'JS_GetOwnPropertyNames'; Binds[28].Dest := PPointer(@JS_GetOwnPropertyNamesPtr); Binds[28].Required := False;
  Binds[29].Name := 'JS_FreePropertyEnum'; Binds[29].Dest := PPointer(@JS_FreePropertyEnumPtr); Binds[29].Required := False;
  Binds[30].Name := 'JS_AtomToString'; Binds[30].Dest := PPointer(@JS_AtomToStringPtr); Binds[30].Required := False;
  Binds[31].Name := 'JS_FreeAtom'; Binds[31].Dest := PPointer(@JS_FreeAtomPtr); Binds[31].Required := False;
  Binds[32].Name := 'JS_NewStringLen'; Binds[32].Dest := PPointer(@JS_NewStringLenPtr); Binds[32].Required := False;
  Binds[33].Name := 'JS_NewAtom'; Binds[33].Dest := PPointer(@JS_NewAtomPtr); Binds[33].Required := False;
  Binds[34].Name := 'JS_DeleteProperty'; Binds[34].Dest := PPointer(@JS_DeletePropertyPtr); Binds[34].Required := False;
  // stability: two-phase required-first fail-fast — required symbols (10) bound first, optional (22) only if required OK; cold fail up to 10 lookups not 32 (8×10=80 vs 256), success single 32
  // perf: inline Bind PAnsiChar zero-copy, no AnsiString heap, early exit avoids 22 optional dl_sym on probe miss, bytes.ops single source for zero
  for I := 0 to High(Binds) do if Binds[I].Required then
  begin
    if not Bind(Binds[I].Name, P) then begin platform_dl_close(Lib); Exit; end;
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
  // perf: ProbeIndex single source cache reuses hit index, but negative not permanently cached — reprobe allowed on next call without restart, zero-copy single build inline
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
begin
  // perf: positive fast path via atomic acquire load, zero syscall when cached available, hot path inline single compare, negative reprobes under lock (dynamic so appearance without restart)
  if atomic_load(VaultRef^.Available, mo_acquire) = 1 then Exit(True);
  // Owner boundary: nextpas.core.sync.mutex TMutex → platform.sync (L1→L0)
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    if VaultRef^.Available = 1 then Exit(True);
    // stability: if Available=0 (negative) still reprobe to handle so dynamically appearing; not permanently cached, no restart needed
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
procedure InitProbeCache;
var LTmp: string;
begin
  // perf: double-checked locking via VaultRef^.Lock Exactly-Once + atomic Ready flag fast path (single acquire load, zero-copy Move, StringJoin single alloc via bytes.ops BytesCopy single source, no TBufStringBuilder try-finally)
  // stability: acquire/release fences guard non-atomic string publication (refcount野指针 fix), lock protects GProbeNamesCache heap alloc/overwrite, immutable after init, GProbeNamesReady release after write / acquire before read
  if atomic_load(GProbeNamesReady, mo_acquire) <> 0 then Exit;
  EnsureVaultLock;
  VaultRef^.Lock.Acquire;
  try
    if atomic_load(GProbeNamesReady, mo_acquire) <> 0 then Exit;
    LTmp := BuildProbeNames;
    GProbeNamesCache := LTmp;
    atomic_store(GProbeNamesReady, Int32(1), mo_release);
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
  // perf: one-time probe names cache, bytes.ops single source via InitProbeCache, zero per-call heap on error path, atomic Ready flag single source
  if atomic_load(GProbeNamesReady, mo_acquire) = 0 then InitProbeCache;
finalization
  // stability: finalization exactly-once release if still loaded, zero via BytesZero single source, resource not丢
  if GVault.Loaded <> 0 then
  begin
    platform_dl_close(GVault.Lib);
    BytesZero(@GVault.Lib, SizeUInt(SizeOf(GVault.Lib)));
  end;
  ClearQuickJsPtrs;
  // Owner: IMutex refcnt release, platform_mutex_destroy via TMutex single source, resource not丢, idempotent
  if GVaultInit = 2 then
  begin
    VaultRef^.Lock := nil;
    atomic_store(GVaultInit, Int32(0), mo_release);
  end else
    GVault.Lock := nil;
end.
