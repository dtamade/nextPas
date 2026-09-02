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
const JS_PURE_HOST_THRESHOLD = 64;
function JsPureValidateHostName(const AName: string): Boolean;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload;
function JsPureCheckHostName(const AName: string; ABackend: TJsBackendKind): Boolean; inline;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string);
implementation
uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.ops.text;
var
  GBuckets: array of Integer;
  GMask: UInt32;
  GCount: Integer;
function HostHashStr(const S: string): UInt32; inline;
begin
  Result := FNV1a32(PByte(PAnsiChar(S)), SizeUInt(Length(S)));
end;
function HostHashView(const V: TStringView): UInt32; inline;
begin
  if V.Len = 0 then Exit(0);
  Result := FNV1a32(PByte(V.Data), V.Len);
end;
procedure HostBucketsInvalidate; inline;
begin
  SetLength(GBuckets, 0);
  GMask := 0;
  GCount := 0;
end;
procedure HostBucketsRebuild(const Hosts: TJsPureHostArray);
var
  LCount, LCap, I, LIdx: Integer;
  LHash: UInt32;
begin
  LCount := 0;
  for I := 0 to High(Hosts) do
    if Hosts[I].Name <> '' then Inc(LCount) else Break;
  if LCount <= JS_PURE_HOST_THRESHOLD then
  begin
    HostBucketsInvalidate;
    Exit;
  end;
  LCap := 1;
  while LCap < LCount * 2 do LCap := LCap shl 1;
  SetLength(GBuckets, LCap);
  for I := 0 to LCap - 1 do GBuckets[I] := -1;
  GMask := UInt32(LCap - 1);
  GCount := LCount;
  for I := 0 to LCount - 1 do
  begin
    LHash := Hosts[I].Hash;
    LIdx := Integer(LHash and GMask);
    while GBuckets[LIdx] <> -1 do LIdx := (LIdx + 1) and Integer(GMask);
    GBuckets[LIdx] := I;
  end;
end;
function HostFindCore(const Hosts: TJsPureHostArray; AHash: UInt32; const AView: TStringView): Integer;
var
  I, LIdx, LProbe: Integer;
  LCount: Integer;
begin
  LCount := 0;
  for I := 0 to High(Hosts) do
    if Hosts[I].Name <> '' then Inc(LCount) else Break;
  // threshold split: >64 use resident bucket O(1)
  if (LCount > JS_PURE_HOST_THRESHOLD) and (Length(GBuckets) > 0) and (GCount = LCount) then
  begin
    LIdx := Integer(AHash and GMask);
    for LProbe := 0 to High(GBuckets) do
    begin
      if GBuckets[LIdx] = -1 then Exit(-1);
      I := GBuckets[LIdx];
      if (Hosts[I].Hash = AHash) and TStringView.FromStr(Hosts[I].Name).Equals(AView) then Exit(I);
      LIdx := (LIdx + 1) and Integer(GMask);
    end;
    Exit(-1);
  end;
  if (LCount > JS_PURE_HOST_THRESHOLD) and (Length(GBuckets) = 0) then
    HostBucketsRebuild(Hosts);
  if (LCount > JS_PURE_HOST_THRESHOLD) and (Length(GBuckets) > 0) and (GCount = LCount) then
  begin
    LIdx := Integer(AHash and GMask);
    for LProbe := 0 to High(GBuckets) do
    begin
      if GBuckets[LIdx] = -1 then Exit(-1);
      I := GBuckets[LIdx];
      if (Hosts[I].Hash = AHash) and TStringView.FromStr(Hosts[I].Name).Equals(AView) then Exit(I);
      LIdx := (LIdx + 1) and Integer(GMask);
    end;
    Exit(-1);
  end;
  for I := 0 to LCount - 1 do
    if (Hosts[I].Hash = AHash) and TStringView.FromStr(Hosts[I].Name).Equals(AView) then Exit(I);
  Result := -1;
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
  // hash filter + view equals, bucket O(1) when >64
  LView := TStringView.FromStr(AName);
  LHash := HostHashStr(AName);
  Result := HostFindCore(Hosts, LHash, LView);
end;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer;
var LHash: UInt32;
begin
  // zero-copy view + hash, bucket O(1) when >64
  LHash := HostHashView(AName);
  Result := HostFindCore(Hosts, LHash, AName);
end;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer;
var LIdx, LCount, I: Integer; LNeed, LCap: SizeUInt;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx >= 0 then Exit(LIdx);
  LCount := 0;
  for I := 0 to High(Hosts) do
    if Hosts[I].Name <> '' then Inc(LCount) else Break;
  LNeed := SizeUInt(LCount) + 1;
  if LNeed > SizeUInt(Length(Hosts)) then
  begin
    LCap := BytesNextCapacity(SizeUInt(Length(Hosts)), LNeed);
    SetLength(Hosts, LCap);
  end;
  Hosts[LCount].Name := AName;
  Hosts[LCount].Hash := HostHashStr(AName);
  HostBucketsInvalidate;
  Result := LCount;
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, AName);
  Hosts[LIdx].Func := AHandler;
  Hosts[LIdx].Kind := AKind;
  if Length(Hosts) > JS_PURE_HOST_THRESHOLD then HostBucketsInvalidate;
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, AName);
  Hosts[LIdx].Method := AHandler;
  Hosts[LIdx].Kind := AKind;
  if Length(Hosts) > JS_PURE_HOST_THRESHOLD then HostBucketsInvalidate;
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer);
var LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, AName);
  Hosts[LIdx].Proc := AHandler;
  Hosts[LIdx].Kind := AKind;
  if Length(Hosts) > JS_PURE_HOST_THRESHOLD then HostBucketsInvalidate;
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
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
begin
  JsPureCheckHostName(AName, ABackend);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend);
  JsPureHostSet(Hosts, AName, AHandler, 1);
end;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
begin
  JsPureCheckHostName(AName, ABackend);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', ABackend);
  JsPureHostSet(Hosts, AName, AHandler, 2);
end;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string);
var LIdx, I, LCount: Integer;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx < 0 then Exit;
  LCount := 0;
  for I := 0 to High(Hosts) do
    if Hosts[I].Name <> '' then Inc(LCount) else Break;
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
  HostBucketsInvalidate;
end;
end.
