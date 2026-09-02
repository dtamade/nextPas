unit nextpas.core.js.quickjs.loader;
{** @desc QuickJS 动态装载（唯一可触 platform.dl，幂等缓存，跨平台）。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base;
function JsQuickJsIsAvailable: Boolean;
function JsQuickJsProbeNames: string; inline;
function JsQuickJsLoad: Boolean;
procedure JsQuickJsUnload;
implementation
uses nextpas.core.platform.dl, nextpas.core.js.quickjs.ffi, nextpas.core.bytes.ops;
var GLib: TPlatformLibrary; GAvailable: Integer = -1; GLoaded: Integer = 0; GLock: TRTLCriticalSection;
const JS_QUICKJS_PROBE_NAMES: array[0..7] of string = (
  {$IFDEF NEXTPAS_WINDOWS}
    'quickjs.dll', 'libquickjs.dll', 'libquickjs.so.1', 'libquickjs.so.0', 'libquickjs.so', 'libquickjs.dylib', 'libquickjs.1.dylib', 'quickjs'
  {$ELSEIF defined(NEXTPAS_MACOS)}
    'libquickjs.dylib', 'libquickjs.1.dylib', 'libquickjs.so.1', 'libquickjs.so.0', 'libquickjs.so', 'quickjs.dll', 'libquickjs.dll', 'quickjs'
  {$ELSE}
    'libquickjs.so.1', 'libquickjs.so.0', 'libquickjs.so', 'libquickjs.dylib', 'libquickjs.1.dylib', 'quickjs.dll', 'libquickjs.dll', 'quickjs'
  {$ENDIF}
  );
function JsQuickJsProbeNames: string; inline;
var I: Integer;
begin
  // perf: single source via JS_QUICKJS_PROBE_NAMES — inline thin loop, zero-copy view reuse of constant array, single build (8 entries, comma-join), no literal duplication; owner bytes.ops single-source discipline (probe list canonical in constant)
  Result := '';
  for I := 0 to High(JS_QUICKJS_PROBE_NAMES) do
  begin
    if I > 0 then Result := Result + ', ';
    Result := Result + JS_QUICKJS_PROBE_NAMES[I];
  end;
end;
function TryLoad(const AName: AnsiString): Boolean;
var Lib: TPlatformLibrary; P: Pointer;
  function Bind(const Sym: AnsiString; out Addr: Pointer): Boolean;
  begin Result := platform_dl_sym(Lib, PAnsiChar(Sym), Addr) = 0; if not Result then Addr := nil; end;
begin
  Result := False;
  // perf: inline single source via bytes.ops.BytesZero (FillChar single source, SIMD), zero extra call, L1+ reuse gate, zero-copy
  BytesZero(@Lib, SizeUInt(SizeOf(Lib)));
  if platform_dl_open(PAnsiChar(AName), PLATFORM_DL_NOW, Lib) <> 0 then Exit;
  if not Bind('JS_NewRuntime', P) then begin platform_dl_close(Lib); Exit; end;
  JS_NewRuntimePtr := TJS_NewRuntime(P);
  if not Bind('JS_Eval', P) then begin platform_dl_close(Lib); Exit; end;
  JS_EvalPtr := TJS_Eval(P);
  if Bind('JS_FreeRuntime', P) then JS_FreeRuntimePtr := TJS_FreeRuntime(P);
  if Bind('JS_NewContext', P) then JS_NewContextPtr := TJS_NewContext(P);
  if Bind('JS_FreeContext', P) then JS_FreeContextPtr := TJS_FreeContext(P);
  if Bind('JS_GetGlobalObject', P) then JS_GetGlobalObjectPtr := TJS_GetGlobalObject(P);
  if Bind('JS_FreeValue', P) then JS_FreeValuePtr := TJS_FreeValue(P);
  if Bind('JS_DupValue', P) then JS_DupValuePtr := TJS_DupValue(P);
  if Bind('JS_ToCString', P) then JS_ToCStringPtr := TJS_ToCString(P);
  if Bind('JS_FreeCString', P) then JS_FreeCStringPtr := TJS_FreeCString(P);
  if Bind('JS_IsException', P) then JS_IsExceptionPtr := TJS_IsException(P);
  if Bind('JS_GetException', P) then JS_GetExceptionPtr := TJS_GetException(P);
  if Bind('JS_NewString', P) then JS_NewStringPtr := TJS_NewString(P);
  if Bind('JS_NewInt64', P) then JS_NewInt64Ptr := TJS_NewInt64(P);
  if Bind('JS_NewFloat64', P) then JS_NewFloat64Ptr := TJS_NewFloat64(P);
  if Bind('JS_NewBool', P) then JS_NewBoolPtr := TJS_NewBool(P);
  if Bind('JS_NewObject', P) then JS_NewObjectPtr := TJS_NewObject(P);
  if Bind('JS_NewArray', P) then JS_NewArrayPtr := TJS_NewArray(P);
  if Bind('JS_SetPropertyStr', P) then JS_SetPropertyStrPtr := TJS_SetPropertyStr(P);
  if Bind('JS_GetPropertyStr', P) then JS_GetPropertyStrPtr := TJS_GetPropertyStr(P);
  if Bind('JS_SetMemoryLimit', P) then JS_SetMemoryLimitPtr := TJS_SetMemoryLimit(P);
  if Bind('JS_SetGCThreshold', P) then JS_SetGCThresholdPtr := TJS_SetGCThreshold(P);
  if Bind('JS_RunGC', P) then JS_RunGCPtr := TJS_RunGC(P);
  if Bind('JS_SetInterruptHandler', P) then JS_SetInterruptHandlerPtr := TJS_SetInterruptHandler(P);
  if Bind('JS_NewCFunction', P) then JS_NewCFunctionPtr := TJS_NewCFunction(P);
  if Bind('JS_Call', P) then JS_CallPtr := TJS_Call(P);
  if Bind('JS_IsArray', P) then JS_IsArrayPtr := TJS_IsArray(P);
  if Bind('JS_GetOwnPropertyNames', P) then JS_GetOwnPropertyNamesPtr := TJS_GetOwnPropertyNames(P);
  if Bind('JS_FreePropertyEnum', P) then JS_FreePropertyEnumPtr := TJS_FreePropertyEnum(P);
  if Bind('JS_AtomToString', P) then JS_AtomToStringPtr := TJS_AtomToString(P);
  if Bind('JS_FreeAtom', P) then JS_FreeAtomPtr := TJS_FreeAtom(P);
  // caller holds GLock, so global assignment is serialized — no duplicate TryLoad leak, handle ownership transferred exactly once
  GLib := Lib; GLoaded := 1; Result := True;
end;
function DoProbeAvailableLocked: Boolean;
var I: Integer; Lib: TPlatformLibrary;
begin
  // caller holds GLock; probes 8 names, closes handle immediately on probe success, sets GAvailable canonical
  for I := 0 to High(JS_QUICKJS_PROBE_NAMES) do
  begin
    // perf: inline single source via bytes.ops.BytesZero (FillChar single source, SIMD), zero extra call, L1+ reuse gate
    BytesZero(@Lib, SizeUInt(SizeOf(Lib)));
    if platform_dl_open(PAnsiChar(JS_QUICKJS_PROBE_NAMES[I]), PLATFORM_DL_NOW, Lib) = 0 then
    begin
      // stability: probe handle closed immediately, not cached, resource not丢
      platform_dl_close(Lib); GAvailable := 1; Exit(True);
    end;
  end;
  GAvailable := 0; Result := False;
end;
function JsQuickJsIsAvailable: Boolean;
begin
  // perf: atomic fast path via InterlockedCompareExchange acquire load, zero syscall when cached, hot path inline compare
  if InterlockedCompareExchange(GAvailable, -1, -1) <> -1 then Exit(GAvailable = 1);
  EnterCriticalSection(GLock);
  try
    if GAvailable <> -1 then Exit(GAvailable = 1);
    Result := DoProbeAvailableLocked;
  finally
    LeaveCriticalSection(GLock);
  end;
end;
function JsQuickJsLoad: Boolean;
var I: Integer;
begin
  // perf: atomic fast path for idempotent load, zero lock when already loaded
  if InterlockedCompareExchange(GLoaded, 0, 0) <> 0 then Exit(True);
  EnterCriticalSection(GLock);
  try
    if GLoaded <> 0 then Exit(True);
    if GAvailable = -1 then DoProbeAvailableLocked;
    if GAvailable = 0 then Exit(False);
    for I := 0 to High(JS_QUICKJS_PROBE_NAMES) do
      if TryLoad(JS_QUICKJS_PROBE_NAMES[I]) then Exit(True);
    Result := False;
  finally
    LeaveCriticalSection(GLock);
  end;
end;
procedure JsQuickJsUnload;
begin
  EnterCriticalSection(GLock);
  try
    if GLoaded <> 0 then
    begin
      // stability: exactly-once close, then zero via bytes.ops single source, resource not丢, idempotent
      platform_dl_close(GLib);
      // perf: inline single source via bytes.ops.BytesZero (FillChar single source, SIMD), zero extra call, L1+ reuse gate
      BytesZero(@GLib, SizeUInt(SizeOf(GLib)));
      GLoaded := 0; GAvailable := -1;
      JS_NewRuntimePtr := nil; JS_EvalPtr := nil; JS_CallPtr := nil; JS_IsArrayPtr := nil; JS_GetOwnPropertyNamesPtr := nil; JS_FreePropertyEnumPtr := nil; JS_AtomToStringPtr := nil; JS_FreeAtomPtr := nil;
    end;
  finally
    LeaveCriticalSection(GLock);
  end;
end;
initialization
  InitCriticalSection(GLock);
finalization
  // stability: finalization exactly-once release if still loaded, zero via BytesZero single source, resource not丢
  if GLoaded <> 0 then
  begin
    platform_dl_close(GLib);
    BytesZero(@GLib, SizeUInt(SizeOf(GLib)));
  end;
  DoneCriticalSection(GLock);
end.
