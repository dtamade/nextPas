unit nextpas.core.js.pure.host;
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.js.pure.hash,
  nextpas.core.js.pure.base;
type
  TJsPureHostRec = nextpas.core.js.pure.base.TJsPureHostRec;
  TJsPureHostArray = nextpas.core.js.pure.base.TJsPureHostArray;
  // per-Context resident bucket index — instance-isolated, no global sharing (Owner nextpas.core.js.pure.host, L2, canonical via pure.base)
  TJsPureHostBuckets = nextpas.core.js.pure.base.TJsPureHostBuckets;
procedure JsPureHostReserve(var Hosts: TJsPureHostArray; AAdditional: Integer);
function JsPureValidateHostName(const AName: string): Boolean;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer; overload;
function JsPureFindHost(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer; overload;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer; overload;
function JsPureFindHostView(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: TStringView): Integer; overload;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer; overload;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer; overload;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload;
function JsPureCheckHostName(const AName: string; ABackend: TJsBackendKind): Boolean; inline;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline; overload;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string); overload;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string); overload;
procedure JsPureHostBucketsInvalidate(var Buckets: TJsPureHostBuckets); inline;
procedure JsPureHostBucketsRebuild(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets);
// Host dispatch — single source via pure.host, inline zero-copy, bytes.ops single source, L0-L3 kept, resource try-finally via exception wrap
function JsPureHostInvoke(const AHost: TJsPureHostRec; ACtx: IJsContext; const AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; inline;
const JS_PURE_FILE_MAX_BYTES = BYTES_BULK_PARSE_MAX_BYTES; // 64MiB canonical single source via bytes.ops BYTES_BULK_PARSE_MAX_BYTES (L1 owner, Format/JS single source, no L2→L2, bytes.ops BytesCopy zero-copy single source, L0-L3 kept, try-finally not丢)
procedure JsPureHostsClear(var Hosts: TJsPureHostArray);
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean;
// HostState — per-Context聚合态收敛 (奢华度收敛, 守bytes.ops单源, inline+零拷贝, 资源幂等不丢, Owner pure.host, canonical via pure.base)
type
  TJsPureHostState = nextpas.core.js.pure.base.TJsPureHostState;
function JsPureHostStateFind(var S: TJsPureHostState; const AName: string): Integer; inline;
function JsPureHostStateFindView(var S: TJsPureHostState; const AName: TStringView): Integer; inline;
function JsPureHostStateFindViewBucketed(var S: TJsPureHostState; const AName: TStringView): Integer; inline;
procedure JsPureHostStateClear(var S: TJsPureHostState); inline;
procedure JsPureHostStateSetFunc(var S: TJsPureHostState; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
procedure JsPureHostStateSetMethod(var S: TJsPureHostState; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
procedure JsPureHostStateSetProc(var S: TJsPureHostState; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
procedure JsPureHostStateRemove(var S: TJsPureHostState; const AName: string); inline;
// Call — single source dispatch via pure.host, PBuckets nil=linear else bucketed single template, inline zero-copy, bytes.ops single source, L0-L3 kept, resource try-finally via HostInvoke
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; overload;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; overload;
function JsPureCall(ACtx: IJsContext; var AState: TJsPureHostState; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; overload; inline;
implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.ops.text,
  nextpas.core.mem.dynarray,
  nextpas.core.js.pure.base,
  nextpas.core.js.pure.value,
  nextpas.core.platform.fs;
function JsPureCategoryFromErrorCategory(const ACategory: TErrorCategory): TJsErrorCategory; inline;
begin
  case ACategory of
    ecParse: Result := jecSyntax;
    ecNullReference: Result := jecReference;
    ecInvalidArgument, ecInvalidOperation: Result := jecType;
    ecNotImplemented, ecNotSupported: Result := jecNotSupported;
    ecTimeout: Result := jecTimeout;
    ecResourceExhausted: Result := jecMemory;
    ecInternal: Result := jecUnknown;
  else Result := jecUnknown; end;
end;

function JsPureHostInvoke(const AHost: TJsPureHostRec; ACtx: IJsContext; const AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; inline;
begin
  // single source Host Kind dispatch via pure.host, inline zero-copy, bytes.ops single source via host view not needed here, resource try-finally via exception wrap, L0-L3 kept
  try
    case AHost.Kind of
      0: Result := AHost.Func(ACtx, AThis, AArgs);
      1: Result := AHost.Method(ACtx, AThis, AArgs);
      2: Result := AHost.Proc(ACtx, AThis, AArgs);
    else
      Result := JsUndefinedValue;
    end;
  except
    on E: EJsError do raise;
    on E: ENextPasError do raise EJsError.Create(E.Message, JsPureCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend);
    on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend);
  end;
end;

type PJsPureHostBuckets = ^TJsPureHostBuckets;
// PBuckets single template — dual overloads converged to PBuckets nil=linear else bucketed, inline zero-copy via host view, bytes.ops single source
function _JsPureCallImpl(ACtx: IJsContext; const Hosts: TJsPureHostArray; Buckets: PJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue;
var LIdx: Integer; LName: string;
begin
  Result := JsUndefinedValue;
  if not AFunc.IsFunction then Exit;
  LName := JsFunctionName(AFunc);
  if LName = '' then Exit;
  if Buckets <> nil then LIdx := JsPureFindHost(Hosts, Buckets^, LName) else LIdx := JsPureFindHost(Hosts, LName);
  if LIdx < 0 then Exit;
  Result := JsPureHostInvoke(Hosts[LIdx], ACtx, AThis, AArgs, ABackend);
end;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue;
begin Result := _JsPureCallImpl(ACtx, Hosts, nil, AFunc, AThis, AArgs, ABackend); end;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue;
begin Result := _JsPureCallImpl(ACtx, Hosts, @Buckets, AFunc, AThis, AArgs, ABackend); end;
function JsPureCall(ACtx: IJsContext; var AState: TJsPureHostState; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; inline;
begin Result := _JsPureCallImpl(ACtx, AState.Hosts, @AState.Buckets, AFunc, AThis, AArgs, ABackend); end;

function HostCapacity(const Hosts: TJsPureHostArray): SizeUInt; inline;
begin
  // single source via mem.dynarray DynArrayCapacityElem, heap probe converged via HeapCapacity, inline zero-copy header, amortized O(1)
  Result := nextpas.core.mem.dynarray.DynArrayCapacityElem(Pointer(Hosts), SizeUInt(Length(Hosts)), SizeOf(TJsPureHostRec));
end;
procedure PokeHostLen(var Hosts: TJsPureHostArray; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute Hosts;
begin
  // single source geometric via bytes.ops + exactly-once poke via mem.dynarray, amortized O(1), no double alloc
  nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen);
end;
procedure JsPureHostReserve(var Hosts: TJsPureHostArray; AAdditional: Integer);
var LOld, LNeed, LCap: SizeUInt; LCurCap: SizeUInt;
begin
  // batch geometric pre扩: single alloc via bytes.ops BytesNextCapacity single source + single poke, amortized O(1), zero per-insert SetLength+Poke thrash for bulk registration
  if AAdditional <= 0 then Exit;
  LOld := SizeUInt(Length(Hosts));
  LNeed := LOld + SizeUInt(AAdditional);
  LCurCap := HostCapacity(Hosts);
  if LCurCap >= LNeed then Exit;
  LCap := BytesNextCapacity(LOld, LNeed);
  SetLength(Hosts, LCap);
  if LCap <> LOld then PokeHostLen(Hosts, LOld);
end;
function HostHashView(const V: TStringView): UInt32; inline;
begin
  // single source via pure.hash JsPureHashView (bytes.ops FNV1a32), inline zero-copy, no heap alloc, converged with PropHashStr via pure.hash
  Result := JsPureHashView(V);
end;
function HostHashStr(const S: string): UInt32; inline;
begin
  // single source via pure.hash JsPureHashStr (zero-copy view), converges with PropHashStr, no duplicate FNV
  Result := JsPureHashStr(S);
end;
function HostCount(const Hosts: TJsPureHostArray): Integer; inline;
begin
  // perf: O(1) via Length — dense packed, no linear scan, amortized O(1) with poke, single source Length
  Result := Length(Hosts);
end;
function HostEquals(const ARec: TJsPureHostRec; AHash: UInt32; const AView: TStringView): Boolean; inline;
begin
  // single source equality: hash filter + zero-copy TStringView.Equals via bytes.ops SpanEqual SIMD
  Result := (ARec.Hash = AHash) and TStringView.FromStr(ARec.Name).Equals(AView);
end;
procedure JsPureHostBucketsInvalidate(var Buckets: TJsPureHostBuckets); inline;
begin
  // per-Context invalidate — zero alloc, inline, no global sharing, instance-isolated thread-safe
  SetLength(Buckets.Buckets, 0);
  Buckets.Mask := 0;
  Buckets.Count := 0;
end;
procedure JsPureHostBucketsRebuild(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets);
var
  LCount, LCap, I: Integer;
begin
  // perf: O(1) count via Length, no scan, amortized O(1) rebuild only when >64 and invalid; single source bucket template via pure.hash
  LCount := Length(Hosts);
  if LCount <= JS_PURE_HASH_THRESHOLD then
  begin
    JsPureHostBucketsInvalidate(Buckets);
    Exit;
  end;
  // single source geometric via pure.hash JsPureBucketCapacity (bytes.ops BytesNextCapacity 0→64→2×) + Prepare/Put template converged, shared single template with PropBucketsRebuild, bytes.ops single source amortized O(1)
  LCap := JsPureBucketCapacity(LCount);
  SetLength(Buckets.Buckets, LCap);
  JsPureBucketsPrepare(Buckets.Buckets, Buckets.Mask, Buckets.Count, LCap, LCount);
  for I := 0 to LCount - 1 do
    JsPureBucketPut(Buckets.Buckets, Buckets.Mask, Hosts[I].Hash, I);
end;
function HostFindCoreLinear(const Hosts: TJsPureHostArray; AHash: UInt32; const AView: TStringView): Integer;
var I: Integer;
begin
  // perf: not inline per design-conventions §2 red-line 2 (loop body禁inline, I-Cache不膨胀) — zero-copy view + HostEquals single source (hash filter + SpanEqual), O(n) for <=64, no extra HostCount scan
  for I := 0 to High(Hosts) do
    if HostEquals(Hosts[I], AHash, AView) then Exit(I);
  Result := -1;
end;
function HostFindCoreBucketed(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; AHash: UInt32; const AView: TStringView): Integer;
var I, LIdx, LProbe, LCount: Integer;
begin
  // perf: unified template — O(1) count via Length, single-branch bucket valid check, inline hash via bytes.ops single source
  LCount := Length(Hosts);
  if LCount <= JS_PURE_HASH_THRESHOLD then
    Exit(HostFindCoreLinear(Hosts, AHash, AView));
  if (Length(Buckets.Buckets) = 0) or (Buckets.Count <> LCount) then
    JsPureHostBucketsRebuild(Hosts, Buckets);
  if (Length(Buckets.Buckets) > 0) and (Buckets.Count = LCount) then
  begin
    LIdx := Integer(AHash and Buckets.Mask);
    for LProbe := 0 to High(Buckets.Buckets) do
    begin
      if Buckets.Buckets[LIdx] = -1 then Exit(-1);
      I := Buckets.Buckets[LIdx];
      if HostEquals(Hosts[I], AHash, AView) then Exit(I);
      LIdx := (LIdx + 1) and Integer(Buckets.Mask);
    end;
    Exit(-1);
  end;
  Result := HostFindCoreLinear(Hosts, AHash, AView);
end;
function JsPureValidateHostName(const AName: string): Boolean;
var I: Integer; C: Char;
begin
  Result := False;
  if AName = '' then Exit;
  if Pos('..', AName) > 0 then Exit;
  if AName[1] = '.' then Exit;
  if AName[Length(AName)] = '.' then Exit;
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    if C = '.' then Continue;
    if not (C in ['A'..'Z', 'a'..'z', '_', '$', '0'..'9']) then Exit;
    if (I > 1) and (AName[I - 1] <> '.') then Continue;
    if (C in ['0'..'9']) and ((I = 1) or (AName[I - 1] = '.')) then Exit;
  end;
  Result := True;
end;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer;
var LView: TStringView;
begin
  // unified template: zero-copy view + single source hash via HostHashView, inline linear O(n) without bucket
  LView := TStringView.FromStr(AName);
  Result := HostFindCoreLinear(Hosts, HostHashView(LView), LView);
end;
function JsPureFindHost(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer;
var LView: TStringView;
begin
  // unified template: zero-copy view + single source hash, bucket O(1) when >64 single-branch rebuild
  LView := TStringView.FromStr(AName);
  Result := HostFindCoreBucketed(Hosts, Buckets, HostHashView(LView), LView);
end;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer;
begin
  // unified template: view zero-copy, single source hash inline
  Result := HostFindCoreLinear(Hosts, HostHashView(AName), AName);
end;
function JsPureFindHostView(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: TStringView): Integer;
begin
  // unified template: view zero-copy, single source hash, bucket O(1)
  Result := HostFindCoreBucketed(Hosts, Buckets, HostHashView(AName), AName);
end;
function HostAllocOne(var Hosts: TJsPureHostArray; const AName: string; AHash: UInt32): Integer;
var
  LCount: Integer;
  LArr: specialize nextpas.core.js.pure.base.TJsArray<TJsPureHostRec> absolute Hosts;
begin
  // single source via pure.value generic EnsureCapacityOne single seam — geometric via bytes.ops BytesNextCapacity + poke via mem.dynarray Exactly-Once, amortized O(1), bytes.ops single source, L0-L3 kept, not inline per red-line 2 (routing body)
  LCount := Length(Hosts);
  specialize nextpas.core.js.pure.value.EnsureCapacityOne<TJsPureHostRec>(LArr);
  Hosts[LCount].Name := AName;
  Hosts[LCount].Hash := AHash;
  Result := LCount;
end;

function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer;
var LView: TStringView; LHash: UInt32; LIdx: Integer;
begin
  // single source via HostAllocOne: Hash+几何扩容+Poke 复用单源, inline零拷贝, amortized O(1)
  LView := TStringView.FromStr(AName);
  LHash := HostHashView(LView);
  LIdx := HostFindCoreLinear(Hosts, LHash, LView);
  if LIdx >= 0 then Exit(LIdx);
  Result := HostAllocOne(Hosts, AName, LHash);
end;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer;
var LView: TStringView; LHash: UInt32; LIdx, LCountBefore: Integer; LWasValid: Boolean;
begin
  // single source via HostAllocOne + amortized O(1) bucket incremental put, batch千宿主单次rebuild+ O(1) puts vs 千次Invalidate重建
  LView := TStringView.FromStr(AName);
  LHash := HostHashView(LView);
  LIdx := HostFindCoreBucketed(Hosts, Buckets, LHash, LView);
  if LIdx >= 0 then Exit(LIdx);
  LCountBefore := Length(Hosts);
  LWasValid := (Length(Buckets.Buckets) > 0) and (Buckets.Count = LCountBefore);
  Result := HostAllocOne(Hosts, AName, LHash);
  // amortized O(1): valid+capacity足够→O(1)Put, capacity不足→lazy invalidate单次 rebuild, invalid→keep lazy避免千次失效
  if LWasValid then
  begin
    if Length(Buckets.Buckets) >= JsPureBucketCapacity(LCountBefore + 1) then
    begin
      Buckets.Count := LCountBefore + 1;
      JsPureBucketPut(Buckets.Buckets, Buckets.Mask, LHash, Result);
    end else
      JsPureHostBucketsInvalidate(Buckets);
  end else if (Length(Hosts) <= JS_PURE_HASH_THRESHOLD) and (Length(Buckets.Buckets) > 0) then
    JsPureHostBucketsInvalidate(Buckets);
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, AName);
  Hosts[LIdx].Func := AHandler;
  Hosts[LIdx].Kind := AKind;
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, AName);
  Hosts[LIdx].Method := AHandler;
  Hosts[LIdx].Kind := AKind;
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, AName);
  Hosts[LIdx].Proc := AHandler;
  Hosts[LIdx].Kind := AKind;
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, Buckets, AName);
  Hosts[LIdx].Func := AHandler;
  Hosts[LIdx].Kind := AKind;
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, Buckets, AName);
  Hosts[LIdx].Method := AHandler;
  Hosts[LIdx].Kind := AKind;
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, Buckets, AName);
  Hosts[LIdx].Proc := AHandler;
  Hosts[LIdx].Kind := AKind;
end;
function JsPureCheckHostName(const AName: string; ABackend: TJsBackendKind): Boolean; inline;
begin
  if not JsPureValidateHostName(AName) then
    raise EJsError.Create('Invalid host function name: ' + AName, jecSyntax, 'SyntaxError', '', ABackend);
  Result := True;
end;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
begin
  JsPureCheckHostName(AName, ABackend);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend);
  JsPureHostSet(Hosts, AName, AHandler, 0);
end;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
begin
  JsPureCheckHostName(AName, ABackend);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend);
  JsPureHostSet(Hosts, Buckets, AName, AHandler, 0);
end;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
begin
  JsPureCheckHostName(AName, ABackend);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend);
  JsPureHostSet(Hosts, AName, AHandler, 1);
end;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
begin
  JsPureCheckHostName(AName, ABackend);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend);
  JsPureHostSet(Hosts, Buckets, AName, AHandler, 1);
end;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
begin
  JsPureCheckHostName(AName, ABackend);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend);
  JsPureHostSet(Hosts, AName, AHandler, 2);
end;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
begin
  JsPureCheckHostName(AName, ABackend);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend);
  JsPureHostSet(Hosts, Buckets, AName, AHandler, 2);
end;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string);
var LIdx, LCount: Integer;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx < 0 then Exit;
  LCount := Length(Hosts);
  if LCount = 0 then Exit;
  // stability: managed assignment semantics — swap-last single assignment + clear duplicate last to release string/managed refs, avoids raw BytesCopy/BytesZero double-free/leak, resource not丢 via assignment refcount
  // perf: O(1) swap-last single refcount churn vs O(n) shift, bulk delete O(n) not O(n²), inline zero-copy view via HostFind, poke amortized O(1) via mem.dynarray single source
  if LIdx <> LCount - 1 then
    Hosts[LIdx] := Hosts[LCount - 1];
  Hosts[LCount - 1] := Default(TJsPureHostRec);
  PokeHostLen(Hosts, SizeUInt(LCount - 1));
end;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string);
var LIdx, LCount: Integer;
begin
  LIdx := JsPureFindHost(Hosts, Buckets, AName);
  if LIdx < 0 then Exit;
  LCount := Length(Hosts);
  if LCount = 0 then Exit;
  // stability: managed assignment semantics — swap-last single assignment + clear duplicate last to release string/managed refs, avoids raw BytesCopy/BytesZero fragility, resource not丢
  // perf: O(1) swap-last single refcount churn vs O(n) shift, bulk delete O(n) not O(n²), bucket invalidate single source, poke amortized O(1)
  if LIdx <> LCount - 1 then
    Hosts[LIdx] := Hosts[LCount - 1];
  Hosts[LCount - 1] := Default(TJsPureHostRec);
  PokeHostLen(Hosts, SizeUInt(LCount - 1));
  JsPureHostBucketsInvalidate(Buckets);
end;
{ HostState — inline thin-forward to pure.host single source, bytes.ops FNV1a+BytesCopy single source, per-Context isolated, O(1)桶+零拷贝, 资源幂等不丢 }
function JsPureHostStateFind(var S: TJsPureHostState; const AName: string): Integer; inline;
begin Result := JsPureFindHost(S.Hosts, S.Buckets, AName); end;
function JsPureHostStateFindView(var S: TJsPureHostState; const AName: TStringView): Integer; inline;
begin Result := JsPureFindHostView(S.Hosts, S.Buckets, AName); end;
function JsPureHostStateFindViewBucketed(var S: TJsPureHostState; const AName: TStringView): Integer; inline;
begin Result := JsPureFindHostView(S.Hosts, S.Buckets, AName); end;
procedure JsPureHostStateClear(var S: TJsPureHostState); inline;
begin
  // perf: SetLength 0 single-pass finalize managed Name/Func/Method/Proc O(n) vs prior O(2n) dual traversal; Close批量 O(n), inline零拷贝, 资源Finalize幂等不丢, 守bytes.ops单源+FNV1a+Buckets单源, L0-L3
  SetLength(S.Hosts, 0); JsPureHostBucketsInvalidate(S.Buckets);
end;
procedure JsPureHostStateSetFunc(var S: TJsPureHostState; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
begin JsPureHostSetFunc(S.Hosts, S.Buckets, AName, AHandler, ABackend); end;
procedure JsPureHostStateSetMethod(var S: TJsPureHostState; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
begin JsPureHostSetMethod(S.Hosts, S.Buckets, AName, AHandler, ABackend); end;
procedure JsPureHostStateSetProc(var S: TJsPureHostState; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
begin JsPureHostSetProc(S.Hosts, S.Buckets, AName, AHandler, ABackend); end;
procedure JsPureHostStateRemove(var S: TJsPureHostState; const AName: string); inline;
begin JsPureHostRemove(S.Hosts, S.Buckets, AName); end;
procedure JsPureHostsClear(var Hosts: TJsPureHostArray);
begin
  // perf: SetLength 0 single-pass finalize managed Name/Func/Method/Proc O(n) vs prior O(2n); Close批量 O(n) via single source, resource Finalize幂等不丢, bytes.ops单源, inline零拷贝, L0-L3
  SetLength(Hosts, 0);
end;
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean;
var LData: Pointer; LLen: PtrUInt; LErr: Int32;
begin
  AText := '';
  Result := False;
  if APath = '' then Exit;
  LData := nil; LLen := 0;
  LErr := platform_fs_read_file(PAnsiChar(APath), LData, LLen);
  if LErr <> 0 then Exit;
  try
    if LLen > JS_PURE_FILE_MAX_BYTES then Exit(False);
    if LLen > 0 then
    begin
      SetLength(AText, LLen);
      BytesCopy(Pointer(AText), LData, LLen);
    end else AText := '';
    Result := True;
  finally
    if LData <> nil then platform_fs_free_buf(LData);
  end;
end;
end.
