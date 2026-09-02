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
  nextpas.core.bytes.ops.text;
function HostHashStr(const S: string): UInt32; inline;
begin
  Result := FNV1a32(PByte(PAnsiChar(S)), SizeUInt(Length(S)));
end;
function HostHashView(const V: TStringView): UInt32; inline;
begin
  if V.Len = 0 then Exit(0);
  Result := FNV1a32(PByte(V.Data), V.Len);
end;
function HostCount(const Hosts: TJsPureHostArray): Integer; inline;
var I: Integer;
begin
  Result := 0;
  for I := 0 to High(Hosts) do
    if Hosts[I].Name <> '' then Inc(Result) else Break;
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
  LCount := HostCount(Hosts);
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
var I, LCount: Integer;
begin
  LCount := HostCount(Hosts);
  for I := 0 to LCount - 1 do
    if (Hosts[I].Hash = AHash) and TStringView.FromStr(Hosts[I].Name).Equals(AView) then Exit(I);
  Result := -1;
end;
function HostFindCoreBucketed(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; AHash: UInt32; const AView: TStringView): Integer; inline;
var I, LIdx, LProbe, LCount: Integer;
begin
  LCount := HostCount(Hosts);
  if LCount <= JS_PURE_HOST_THRESHOLD then
    Exit(HostFindCoreLinear(Hosts, AHash, AView));
  // single-branch: ensure resident bucket valid (one rebuild at most), then single probe — no double lookup jitter
  if (Length(Buckets.Buckets) = 0) or (Buckets.Count <> LCount) then
    JsPureHostBucketsRebuild(Hosts, Buckets);
  if (Length(Buckets.Buckets) > 0) and (Buckets.Count = LCount) then
  begin
    LIdx := Integer(AHash and Buckets.Mask);
    for LProbe := 0 to High(Buckets.Buckets) do
    begin
      if Buckets.Buckets[LIdx] = -1 then Exit(-1);
      I := Buckets.Buckets[LIdx];
      if (Hosts[I].Hash = AHash) and TStringView.FromStr(Hosts[I].Name).Equals(AView) then Exit(I);
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
var LView: TStringView; LHash: UInt32;
begin
  // zero-copy view + hash, linear path (no global bucket) — per-Context isolation keeps correctness, bucket overload used by Context for O(1)
  LView := TStringView.FromStr(AName);
  LHash := HostHashStr(AName);
  Result := HostFindCoreLinear(Hosts, LHash, LView);
end;
function JsPureFindHost(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer;
var LView: TStringView; LHash: UInt32;
begin
  // per-Context bucket O(1) when >64, single-branch rebuild, inline hash via bytes.ops FNV1a single source, zero-copy view
  LView := TStringView.FromStr(AName);
  LHash := HostHashStr(AName);
  Result := HostFindCoreBucketed(Hosts, Buckets, LHash, LView);
end;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer;
var LHash: UInt32;
begin
  LHash := HostHashView(AName);
  Result := HostFindCoreLinear(Hosts, LHash, AName);
end;
function JsPureFindHostView(const Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: TStringView): Integer;
var LHash: UInt32;
begin
  LHash := HostHashView(AName);
  Result := HostFindCoreBucketed(Hosts, Buckets, LHash, AName);
end;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer;
var LIdx, LCount, I: Integer; LNeed, LCap: SizeUInt;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx >= 0 then Exit(LIdx);
  LCount := HostCount(Hosts);
  LNeed := SizeUInt(LCount) + 1;
  if LNeed > SizeUInt(Length(Hosts)) then
  begin
    LCap := BytesNextCapacity(SizeUInt(Length(Hosts)), LNeed);
    SetLength(Hosts, LCap);
  end;
  Hosts[LCount].Name := AName;
  Hosts[LCount].Hash := HostHashStr(AName);
  Result := LCount;
end;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string): Integer;
var LIdx, LCount, I: Integer; LNeed, LCap: SizeUInt;
begin
  LIdx := JsPureFindHost(Hosts, Buckets, AName);
  if LIdx >= 0 then Exit(LIdx);
  LCount := HostCount(Hosts);
  LNeed := SizeUInt(LCount) + 1;
  if LNeed > SizeUInt(Length(Hosts)) then
  begin
    LCap := BytesNextCapacity(SizeUInt(Length(Hosts)), LNeed);
    SetLength(Hosts, LCap);
  end;
  Hosts[LCount].Name := AName;
  Hosts[LCount].Hash := HostHashStr(AName);
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
  if SizeUInt(Length(Hosts)) > JS_PURE_HOST_THRESHOLD then JsPureHostBucketsInvalidate(Buckets);
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostMethod; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, Buckets, AName);
  Hosts[LIdx].Method := AHandler;
  Hosts[LIdx].Kind := AKind;
  if SizeUInt(Length(Hosts)) > JS_PURE_HOST_THRESHOLD then JsPureHostBucketsInvalidate(Buckets);
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string; AHandler: TJsHostProc; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, Buckets, AName);
  Hosts[LIdx].Proc := AHandler;
  Hosts[LIdx].Kind := AKind;
  if SizeUInt(Length(Hosts)) > JS_PURE_HOST_THRESHOLD then JsPureHostBucketsInvalidate(Buckets);
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
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx < 0 then Exit;
  LCount := HostCount(Hosts);
  for I := LIdx to LCount - 2 do Hosts[I] := Hosts[I + 1];
  if LCount > 0 then
  begin
    Hosts[LCount - 1].Name := '';
    Hosts[LCount - 1].Func := nil;
    Hosts[LCount - 1].Method := nil;
    Hosts[LCount - 1].Proc := nil;
    Hosts[LCount - 1].Kind := 0;
    Hosts[LCount - 1].Hash := 0;
  end;
end;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; var Buckets: TJsPureHostBuckets; const AName: string);
var LIdx, I, LCount: Integer;
begin
  LIdx := JsPureFindHost(Hosts, Buckets, AName);
  if LIdx < 0 then Exit;
  LCount := HostCount(Hosts);
  for I := LIdx to LCount - 2 do Hosts[I] := Hosts[I + 1];
  if LCount > 0 then
  begin
    Hosts[LCount - 1].Name := '';
    Hosts[LCount - 1].Func := nil;
    Hosts[LCount - 1].Method := nil;
    Hosts[LCount - 1].Proc := nil;
    Hosts[LCount - 1].Kind := 0;
    Hosts[LCount - 1].Hash := 0;
  end;
  JsPureHostBucketsInvalidate(Buckets);
end;
end.
