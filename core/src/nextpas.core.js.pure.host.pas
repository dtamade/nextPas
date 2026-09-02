unit nextpas.core.js.pure.host;
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view;
type
  TJsPureHostRec = record
    Name: string;
    Func: TJsHostFunction;
    Method: TJsHostMethod;
    Proc: TJsHostProc;
    Kind: Integer;
    Hash: UInt32;
  end;
  TJsPureHostArray = array of TJsPureHostRec;
  // per-Context resident bucket index — instance-isolated, no global sharing (Owner nextpas.core.js.pure.host, L2)
  TJsPureHostBuckets = record
    Buckets: array of Integer;
    Mask: UInt32;
    Count: Integer;
  end;
const JS_PURE_HOST_THRESHOLD = 64;
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
implementation
uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.ops.text,
  nextpas.core.mem.dynarray,
  nextpas.core.system.heap;
type
  PDynArrayHeader = ^TDynArrayHeader;
  TDynArrayHeader = record RefCnt: PtrInt; High: PtrInt; end;
function HostCapacity(const Hosts: TJsPureHostArray): SizeUInt; inline;
var LP: Pointer; LBlock: Pointer; LSize: SizeUInt;
begin
  LP := Pointer(Hosts);
  if LP = nil then Exit(0);
  LBlock := PByte(LP) - SizeOf(TDynArrayHeader);
  LSize := NpSystemMemSize(LBlock);
  if LSize < SizeOf(TDynArrayHeader) then Exit(SizeUInt(Length(Hosts)));
  Result := (LSize - SizeOf(TDynArrayHeader)) div SizeOf(TJsPureHostRec);
end;
procedure PokeHostLen(var Hosts: TJsPureHostArray; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute Hosts;
begin
  // single source geometric via bytes.ops + exactly-once poke via mem.dynarray, amortized O(1), no double alloc
  nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen);
end;
function HostHashView(const V: TStringView): UInt32; inline;
begin
  // single source FNV1a via bytes.ops, inline + zero-copy view, no heap alloc
  if V.Len = 0 then Exit(0);
  Result := FNV1a32(PByte(V.Data), V.Len);
end;
function HostHashStr(const S: string): UInt32; inline;
var V: TStringView;
begin
  // single source: delegate to HostHashView via TStringView.FromStr zero-copy, no duplicate FNV
  V := TStringView.FromStr(S);
  Result := HostHashView(V);
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
  LCount, LCap, I, LIdx: Integer;
  LHash: UInt32;
begin
  // perf: O(1) count via Length, no scan, amortized O(1) rebuild only when >64 and invalid
  LCount := Length(Hosts);
  if LCount <= JS_PURE_HOST_THRESHOLD then
  begin
    JsPureHostBucketsInvalidate(Buckets);
    Exit;
  end;
  LCap := 1;
  while LCap < LCount * 2 do LCap := LCap shl 1;
  SetLength(Buckets.Buckets, LCap);
  for I := 0 to LCap - 1 do Buckets.Buckets[I] := -1;
  Buckets.Mask := UInt32(LCap - 1);
  Buckets.Count := LCount;
  for I := 0 to LCount - 1 do
  begin
    LHash := Hosts[I].Hash;
    LIdx := Integer(LHash and Buckets.Mask);
    while Buckets.Buckets[LIdx] <> -1 do LIdx := (LIdx + 1) and Integer(Buckets.Mask);
    Buckets.Buckets[LIdx] := I;
  end;
end;
function HostFindCoreLinear(const Hosts: TJsPureHostArray; AHash: UInt32; const AView: TStringView): Integer; inline;
var I: Integer;
begin
  // perf: inline + zero-copy view + HostEquals single source (hash filter + SpanEqual), O(n) for <=64, no extra HostCount scan
  for I := 0 to High(Hosts) do
    if HostEquals(Hosts[I], AHash, AView) then Exit(I);
  Result := -1;
end;
function HostFindCoreBucketed(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; AHash: UInt32; const AView: TStringView): Integer; inline;
var I, LIdx, LProbe, LCount: Integer;
begin
  // perf: unified template — O(1) count via Length, single-branch bucket valid check, inline hash via bytes.ops single source
  LCount := Length(Hosts);
  if LCount <= JS_PURE_HOST_THRESHOLD then
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
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer;
var LIdx, LCount: Integer; LNeed, LCap, LCurCap: SizeUInt; LView: TStringView; LHash: UInt32;
begin
  // perf: unified hash/view single source, O(1) count via Length, amortized O(1) geometric via bytes.ops + poke
  LView := TStringView.FromStr(AName);
  LHash := HostHashView(LView);
  LIdx := HostFindCoreLinear(Hosts, LHash, LView);
  if LIdx >= 0 then Exit(LIdx);
  LCount := Length(Hosts);
  LNeed := SizeUInt(LCount) + 1;
  LCurCap := HostCapacity(Hosts);
  if LCurCap >= LNeed then
  begin
    if SizeUInt(LCount) <> LNeed then PokeHostLen(Hosts, LNeed);
  end else
  begin
    LCap := BytesNextCapacity(SizeUInt(Length(Hosts)), LNeed);
    SetLength(Hosts, LCap);
    if LCap <> LNeed then PokeHostLen(Hosts, LNeed);
  end;
  Hosts[LCount].Name := AName;
  Hosts[LCount].Hash := LHash;
  Result := LCount;
end;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer;
var LIdx, LCount: Integer; LNeed, LCap, LCurCap: SizeUInt; LView: TStringView; LHash: UInt32;
begin
  LView := TStringView.FromStr(AName);
  LHash := HostHashView(LView);
  LIdx := HostFindCoreBucketed(Hosts, Buckets, LHash, LView);
  if LIdx >= 0 then Exit(LIdx);
  LCount := Length(Hosts);
  LNeed := SizeUInt(LCount) + 1;
  LCurCap := HostCapacity(Hosts);
  if LCurCap >= LNeed then
  begin
    if SizeUInt(LCount) <> LNeed then PokeHostLen(Hosts, LNeed);
  end else
  begin
    LCap := BytesNextCapacity(SizeUInt(Length(Hosts)), LNeed);
    SetLength(Hosts, LCap);
    if LCap <> LNeed then PokeHostLen(Hosts, LNeed);
  end;
  Hosts[LCount].Name := AName;
  Hosts[LCount].Hash := LHash;
  JsPureHostBucketsInvalidate(Buckets);
  Result := LCount;
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
  if Length(Hosts) > JS_PURE_HOST_THRESHOLD then JsPureHostBucketsInvalidate(Buckets);
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, Buckets, AName);
  Hosts[LIdx].Method := AHandler;
  Hosts[LIdx].Kind := AKind;
  if Length(Hosts) > JS_PURE_HOST_THRESHOLD then JsPureHostBucketsInvalidate(Buckets);
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, Buckets, AName);
  Hosts[LIdx].Proc := AHandler;
  Hosts[LIdx].Kind := AKind;
  if Length(Hosts) > JS_PURE_HOST_THRESHOLD then JsPureHostBucketsInvalidate(Buckets);
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
var LIdx, I, LCount: Integer;
begin
  // perf: O(1) count via Length, single HostFind (no nested HostCount), shift O(n) but not O(n²), poke amortized O(1)
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx < 0 then Exit;
  LCount := Length(Hosts);
  for I := LIdx to LCount - 2 do Hosts[I] := Hosts[I + 1];
  if LCount > 0 then
  begin
    // stability: clear last duplicate to release string/managed refs, avoid leak
    Hosts[LCount - 1].Name := '';
    Hosts[LCount - 1].Func := nil;
    Hosts[LCount - 1].Method := nil;
    Hosts[LCount - 1].Proc := nil;
    Hosts[LCount - 1].Kind := 0;
    Hosts[LCount - 1].Hash := 0;
    PokeHostLen(Hosts, SizeUInt(LCount - 1));
  end;
end;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string);
var LIdx, I, LCount: Integer;
begin
  LIdx := JsPureFindHost(Hosts, Buckets, AName);
  if LIdx < 0 then Exit;
  LCount := Length(Hosts);
  for I := LIdx to LCount - 2 do Hosts[I] := Hosts[I + 1];
  if LCount > 0 then
  begin
    Hosts[LCount - 1].Name := '';
    Hosts[LCount - 1].Func := nil;
    Hosts[LCount - 1].Method := nil;
    Hosts[LCount - 1].Proc := nil;
    Hosts[LCount - 1].Kind := 0;
    Hosts[LCount - 1].Hash := 0;
    PokeHostLen(Hosts, SizeUInt(LCount - 1));
  end;
  JsPureHostBucketsInvalidate(Buckets);
end;
end.
