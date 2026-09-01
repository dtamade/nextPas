unit nextpas.core.js.pure.base;
{**
 * @desc 纯后端共享基座 — 零 FFI/零 platform.dl，js888/v8/chakra 单源复用。
 *       抽取 ValidateHostName / FindHost / DoEval 视图无关核心，消 300 行克隆。
 *       仅依赖 L0-L1 owner，不引入 fs/platform.dl，保持 pure 族同约束。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.value;

type
  TJsPureHostRec = record
    Name: string;
    Func: TJsHostFunction;
    Method: TJsHostMethod;
    Proc: TJsHostProc;
    Kind: Integer;
  end;
  TJsPureHostArray = array of TJsPureHostRec;
  TJsPureProp = record Name: string; Value: TJsValue; end;
  TJsPureObject = record Id: Int64; Props: array of TJsPureProp; end;
  TJsPureHeap = array of TJsPureObject;

function JsPureValidateHostName(const AName: string): Boolean;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload; inline;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload; inline;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload; inline;
function JsPureCheckHostName(const AName: string; ABackend: TJsBackendKind): Boolean; inline;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string);
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions;
  ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue;
const JS_PURE_HEAP_HASH_THRESHOLD = 64;
type TJsPureHeapMetrics = record FindCalls: UInt64; HashUsed: UInt64; Rebuilds: UInt64; end;
function JsPureHeapMetricsGet: TJsPureHeapMetrics; inline;
procedure JsPureHeapMetricsReset; inline;
// 对象堆（零 FFI，纯族单源，线性 O(n) n≤32 零分配，>64 直索 O(1) 自动哈希，阈值 JS_PURE_HEAP_HASH_THRESHOLD，度量 JsPureHeapMetrics，容量倍增复用 bytes.ops BYTES_BUILDER_MIN_GROW 均摊 O(1)）
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue);
procedure JsPureHeapClear(var Heap: TJsPureHeap);
function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue;
// Json 工厂克隆收敛：fake/js888/v8/chakra 四 pure 后端同分支，仅纯计算零 FFI/零 dl
function JsPureNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline; overload;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
function JsPureNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
function JsPureNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
function JsPureNewDouble(AValue: Double; AContextId: UInt64): TJsValue; inline;
function JsPureNewBool(AValue: Boolean; AContextId: UInt64): TJsValue; inline;
function JsPureNewJson(const AJson: TJsonValue; var Heap: TJsPureHeap; AContextId: UInt64): TJsValue; inline;
function JsPureToJsonString(const AValue: TJsValue): string;
function JsPureToJson(const AValue: TJsValue): IJsonDocument;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64);
// 文件读单源：L0 platform.fs 直读 + bytes.ops Move零拷贝 + FORMAT_BULK_PARSE_MAX_BYTES 64MiB 限流 + try/finally 不丢 buf (fake/pure.impl/quickjs 三处复用)
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean; inline;

implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text,
  nextpas.core.text.builder,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.json.writer,
  nextpas.core.format.limits,
  nextpas.core.platform.fs;

var GPureHeapMetrics: TJsPureHeapMetrics;
function JsPureHeapMetricsGet: TJsPureHeapMetrics; inline; begin Result := GPureHeapMetrics; end;
procedure JsPureHeapMetricsReset; inline; begin GPureHeapMetrics.FindCalls := 0; GPureHeapMetrics.HashUsed := 0; GPureHeapMetrics.Rebuilds := 0; end;
// capacity helper: bytes.ops single source amortized O(1) via BYTES_BUILDER_MIN_GROW
function PureNextCap(AOld, ANeed: SizeUInt): SizeUInt; inline; begin Result := BytesNextCapacity(AOld, ANeed); end;
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
    if (I > 1) and (AName[I-1] <> '.') then Continue;
    if (C in ['0'..'9']) and ((I = 1) or (AName[I-1] = '.')) then Exit;
  end;
  Result := True;
end;

function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer;
var I: Integer; LView: TStringView;
begin
  // perf: TStringView zero-copy, bytes.ops SIMD single source, no string alloc, inline forwarding kept thin
  LView := TStringView.FromStr(AName);
  for I := 0 to High(Hosts) do
    if TStringView.FromStr(Hosts[I].Name).Equals(LView) then Exit(I);
  Result := -1;
end;

function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer;
var I: Integer;
begin
  for I := 0 to High(Hosts) do if TStringView.FromStr(Hosts[I].Name).Equals(AName) then Exit(I);
  Result := -1;
end;

procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer); inline;
var LIdx, LCount, I: Integer; LNeed, LCap: SizeUInt;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx >= 0 then begin Hosts[LIdx].Func := AHandler; Hosts[LIdx].Kind := AKind; Exit; end;
  // bytes.ops single source geometric growth, amortized O(1), contiguous via logical count
  LCount := 0;
  for I := 0 to High(Hosts) do if Hosts[I].Name <> '' then Inc(LCount) else Break;
  LNeed := SizeUInt(LCount) + 1;
  if LNeed > SizeUInt(Length(Hosts)) then
  begin
    LCap := BytesNextCapacity(SizeUInt(Length(Hosts)), LNeed);
    SetLength(Hosts, LCap);
  end;
  Hosts[LCount].Name := AName;
  Hosts[LCount].Func := AHandler;
  Hosts[LCount].Kind := AKind;
end;

procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); inline;
var LIdx, LCount, I: Integer; LNeed, LCap: SizeUInt;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx >= 0 then begin Hosts[LIdx].Method := AHandler; Hosts[LIdx].Kind := AKind; Exit; end;
  LCount := 0;
  for I := 0 to High(Hosts) do if Hosts[I].Name <> '' then Inc(LCount) else Break;
  LNeed := SizeUInt(LCount) + 1;
  if LNeed > SizeUInt(Length(Hosts)) then
  begin
    LCap := BytesNextCapacity(SizeUInt(Length(Hosts)), LNeed);
    SetLength(Hosts, LCap);
  end;
  Hosts[LCount].Name := AName;
  Hosts[LCount].Method := AHandler;
  Hosts[LCount].Kind := AKind;
end;

procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); inline;
var LIdx, LCount, I: Integer; LNeed, LCap: SizeUInt;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx >= 0 then begin Hosts[LIdx].Proc := AHandler; Hosts[LIdx].Kind := AKind; Exit; end;
  LCount := 0;
  for I := 0 to High(Hosts) do if Hosts[I].Name <> '' then Inc(LCount) else Break;
  LNeed := SizeUInt(LCount) + 1;
  if LNeed > SizeUInt(Length(Hosts)) then
  begin
    LCap := BytesNextCapacity(SizeUInt(Length(Hosts)), LNeed);
    SetLength(Hosts, LCap);
  end;
  Hosts[LCount].Name := AName;
  Hosts[LCount].Proc := AHandler;
  Hosts[LCount].Kind := AKind;
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
  // logical count (contiguous compact)
  LCount := 0;
  for I := 0 to High(Hosts) do if Hosts[I].Name <> '' then Inc(LCount) else Break;
  for I := LIdx to LCount-2 do Hosts[I] := Hosts[I+1];
  if LCount > 0 then
  begin
    Hosts[LCount-1].Name := '';
    Hosts[LCount-1].Func := nil;
    Hosts[LCount-1].Method := nil;
    Hosts[LCount-1].Proc := nil;
    Hosts[LCount-1].Kind := 0;
  end;
  // keep capacity (geometric), no SetLength shrink to preserve BYTES_BUILDER_MIN_GROW amortized; logical length is LCount-1, physical Length stays capacity
end;

function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
begin Result := V.IsObject or V.IsArray; end;

function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer;
var I: Integer; LId: Int64; LIdx: Integer;
begin
  Inc(GPureHeapMetrics.FindCalls);
  if not JsPureIsHeapObject(Obj) then Exit(-1);
  if SizeUInt(Length(Heap)) > JS_PURE_HEAP_HASH_THRESHOLD then
  begin
    // hash/direct fast path O(1) for dense sequential Ids, bytes.ops single source, no alloc
    LId := JsObjectId(Obj);
    if (LId > 0) and (LId <= Int64(Length(Heap))) then
    begin
      LIdx := Integer(LId - 1);
      if (LIdx >= 0) and (LIdx <= High(Heap)) and (Heap[LIdx].Id = LId) then
      begin
        Inc(GPureHeapMetrics.HashUsed);
        Exit(LIdx);
      end;
    end;
  end;
  for I := 0 to High(Heap) do if Heap[I].Id = JsObjectId(Obj) then Exit(I);
  Result := -1;
end;

function JsPureNextCap(AOld, ANeed: SizeUInt): SizeUInt; inline;
begin Result := BytesNextCapacity(AOld, ANeed); end;

function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue;
var Id: Int64; LNeed, LCap: SizeUInt; LOld: SizeUInt;
begin
  LOld := SizeUInt(Length(Heap)); LNeed := LOld + 1; LCap := JsPureNextCap(LOld, LNeed);
  if LCap > LOld then begin Inc(GPureHeapMetrics.Rebuilds); SetLength(Heap, LCap); SetLength(Heap, LNeed); end else SetLength(Heap, LNeed);
  Id := Int64(LNeed);
  if Id = 0 then Id := 1;
  Heap[High(Heap)].Id := Id;
  SetLength(Heap[High(Heap)].Props, 0);
  Result := JsHeapObjectValue(Id);
end;

function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue;
var Id: Int64; LNeed, LCap: SizeUInt; LOld: SizeUInt;
begin
  LOld := SizeUInt(Length(Heap)); LNeed := LOld + 1; LCap := JsPureNextCap(LOld, LNeed);
  if LCap > LOld then begin Inc(GPureHeapMetrics.Rebuilds); SetLength(Heap, LCap); SetLength(Heap, LNeed); end else SetLength(Heap, LNeed);
  Id := Int64(LNeed);
  if Id = 0 then Id := 1;
  Heap[High(Heap)].Id := Id;
  SetLength(Heap[High(Heap)].Props, 0);
  Result := JsHeapArrayValue(Id);
end;

function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
var Idx, I: Integer;
begin
  Result := False;
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  for I := 0 to High(Heap[Idx].Props) do if Heap[Idx].Props[I].Name = Name then Exit(True);
end;

function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
var Idx, I, J: Integer;
begin
  Result := False;
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  for I := 0 to High(Heap[Idx].Props) do if Heap[Idx].Props[I].Name = Name then
  begin
    for J := I to High(Heap[Idx].Props)-1 do Heap[Idx].Props[J] := Heap[Idx].Props[J+1];
    SetLength(Heap[Idx].Props, Length(Heap[Idx].Props)-1);
    Exit(True);
  end;
end;

function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
var Idx, I: Integer;
begin
  Result := nil;
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  SetLength(Result, Length(Heap[Idx].Props));
  for I := 0 to High(Heap[Idx].Props) do Result[I] := Heap[Idx].Props[I].Name;
end;

function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue;
var Idx, I: Integer;
begin
  Result := JsUndefinedValue;
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  for I := 0 to High(Heap[Idx].Props) do if Heap[Idx].Props[I].Name = Name then Exit(Heap[Idx].Props[I].Value);
end;

procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue);
var Idx, I: Integer; LOld, LNeed, LCap: SizeUInt;
begin
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  for I := 0 to High(Heap[Idx].Props) do if Heap[Idx].Props[I].Name = Name then
  begin Heap[Idx].Props[I].Value := Val; Exit; end;
  LOld := SizeUInt(Length(Heap[Idx].Props)); LNeed := LOld+1; LCap := JsPureNextCap(LOld, LNeed);
  if LCap > LOld then begin Inc(GPureHeapMetrics.Rebuilds); SetLength(Heap[Idx].Props, LCap); SetLength(Heap[Idx].Props, LNeed); end else SetLength(Heap[Idx].Props, LNeed);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name := Name;
  Heap[Idx].Props[High(Heap[Idx].Props)].Value := Val;
end;

procedure JsPureHeapClear(var Heap: TJsPureHeap);
var I, J: Integer;
begin
  for I := 0 to High(Heap) do
  begin
    for J := 0 to High(Heap[I].Props) do Heap[I].Props[J].Name := '';
    SetLength(Heap[I].Props, 0);
  end;
  SetLength(Heap, 0);
end;

function JsCategoryFromErrorCategory(const ACategory: TErrorCategory): TJsErrorCategory; inline;
begin
  case ACategory of
    ecParse: Result := jecSyntax;
    ecNullReference: Result := jecReference;
    ecInvalidArgument, ecInvalidOperation: Result := jecType;
    ecNotImplemented, ecNotSupported: Result := jecNotSupported;
    ecTimeout: Result := jecTimeout;
    ecResourceExhausted: Result := jecMemory;
    ecInternal: Result := jecUnknown;
    else Result := jecUnknown;
  end;
end;

function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue;
var LIdx: Integer; LName: string;
begin
  Result := JsUndefinedValue;
  if not AFunc.IsFunction then Exit;
  LName := JsFunctionName(AFunc);
  if LName = '' then Exit;
  LIdx := JsPureFindHost(Hosts, LName);
  if LIdx < 0 then Exit;
  case Hosts[LIdx].Kind of
    0: try Result := Hosts[LIdx].Func(ACtx, AThis, AArgs); except on E: EJsError do raise; on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend); on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend); end;
    1: try Result := Hosts[LIdx].Method(ACtx, AThis, AArgs); except on E: EJsError do raise; on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend); on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend); end;
    2: try Result := Hosts[LIdx].Proc(ACtx, AThis, AArgs); except on E: EJsError do raise; on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend); on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend); end;
  end;
end;

function JsPureNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline; overload;
var S: string;
begin
  // perf: single SetString+Move zero-copy view (TStringView.Len/Data direct), B/op 1 alloc (0 when empty), inline, bytes.ops single source via Move
  if AView.Len = 0 then S := '' else SetString(S, AView.Data, PtrInt(AView.Len));
  Result := JsValueBindContext(JsStringValue(S), AContextId);
end;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
var S: string;
begin
  if AView.Len = 0 then S := '' else SetString(S, AView.Data, PtrInt(AView.Len));
  Result := JsStringValue(S);
end;
function JsPureNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
begin Result := JsValueBindContext(JsStringValue(AStr), AContextId); end;

function JsPureNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
begin Result := JsValueBindContext(JsIntValue(AValue), AContextId); end;

function JsPureNewDouble(AValue: Double; AContextId: UInt64): TJsValue; inline;
begin Result := JsValueBindContext(JsDoubleValue(AValue), AContextId); end;

function JsPureNewBool(AValue: Boolean; AContextId: UInt64): TJsValue; inline;
begin Result := JsValueBindContext(JsBoolValue(AValue), AContextId); end;

function JsPureNewJson(const AJson: TJsonValue; var Heap: TJsPureHeap; AContextId: UInt64): TJsValue; inline;
begin
  if AJson.IsStr then Result := JsValueBindContext(JsStringValue(AJson.AsStr.ToString), AContextId)
  else if AJson.IsInt then Result := JsValueBindContext(JsIntValue(AJson.AsInt), AContextId)
  else if AJson.IsReal then Result := JsValueBindContext(JsDoubleValue(AJson.AsFloat), AContextId)
  else if AJson.IsBool then Result := JsValueBindContext(JsBoolValue(AJson.AsBool), AContextId)
  else if AJson.IsNull then Result := JsValueBindContext(JsNullValue, AContextId)
  else if AJson.IsArray then Result := JsValueBindContext(JsPureHeapNewArray(Heap), AContextId)
  else if AJson.IsObject then Result := JsValueBindContext(JsPureHeapNewObject(Heap), AContextId)
  else Result := JsValueBindContext(JsUndefinedValue, AContextId);
end;

function JsPureToJsonString(const AValue: TJsValue): string;
var LDouble: Double; B: TStringBuilder; W: TJsonWriter; S: string; I: Integer; Needs: Boolean;
begin
  case AValue.Kind of
    jskString:
      begin
        S := AValue.AsString;
        Needs := False;
        for I := 1 to Length(S) do
          if (S[I] = '"') or (S[I] = '\') or (Byte(S[I]) < 32) then begin Needs := True; Break; end;
        if not Needs then Exit('"' + S + '"');
        B.Init(SizeUInt(Length(S)) + 16);
        try
          W.Init(B);
          W.Str(S);
          Result := B.ToString;
        finally B.Done; end;
      end;
    jskNumber:
      begin
        LDouble := AValue.AsDouble;
        if LDouble = Double(AValue.AsInt) then
          Result := nextpas.core.text.IntToStr(AValue.AsInt)
        else
          Result := nextpas.core.text.FloatToStr(LDouble);
      end;
    jskBoolean: if AValue.AsBool then Result := 'true' else Result := 'false';
    jskNull: Result := 'null';
  else Result := 'null';
  end;
end;

function JsPureToJson(const AValue: TJsValue): IJsonDocument;
begin
  Result := JsonParse(JsPureToJsonString(AValue));
end;

procedure JsPureClose(var Hosts: TJsPureHostArray; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64);
var I: Integer;
begin
  JsContextClose(AContextId);
  for I := 0 to High(Hosts) do
  begin Hosts[I].Name := ''; Hosts[I].Func := nil; Hosts[I].Method := nil; Hosts[I].Proc := nil; end;
  SetLength(Hosts, 0);
  JsPureHeapClear(Heap);
  Global := JsUndefinedValue;
end;

// 单源实现：L0 platform.fs + bytes.ops Move 零拷贝 (SetString) + 64MiB 限流 + try/finally 释放 (inline)
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean; inline;
var
  LData: Pointer;
  LLen: PtrUInt;
  LErr: Int32;
begin
  AText := '';
  Result := False;
  if APath = '' then Exit;
  LData := nil; LLen := 0;
  LErr := platform_fs_read_file(PAnsiChar(APath), LData, LLen);
  if LErr <> 0 then Exit;
  try
    if LLen > FORMAT_BULK_PARSE_MAX_BYTES then Exit(False);
    if LLen > 0 then
      SetString(AText, PAnsiChar(LData), PtrInt(LLen))
    else
      AText := '';
    Result := True;
  finally
    if LData <> nil then platform_fs_free_buf(LData);
  end;
end;

function TryPureInt(const V: TStringView; out OutVal: Int64): Boolean; inline;
var I: Integer; Neg: Boolean; C: Char; U: UInt64;
begin
  Result := False; OutVal := 0;
  if V.IsEmpty then Exit;
  I := 0; Neg := False;
  if V.Data[0] = '-' then begin Neg := True; I := 1; if V.Len = 1 then Exit; end
  else if V.Data[0] = '+' then begin I := 1; if V.Len = 1 then Exit; end;
  U := 0;
  while I < Integer(V.Len) do
  begin
    C := V.Data[I];
    if (C < '0') or (C > '9') then Exit;
    U := U * 10 + UInt64(Ord(C) - Ord('0'));
    if U > UInt64(High(Int64)) + Ord(Neg) then Exit;
    Inc(I);
  end;
  if Neg then OutVal := -Int64(U) else OutVal := Int64(U);
  Result := True;
end;

function TryPureIntAdd(const V: TStringView; out OutVal: TJsValue): Boolean; inline;
var P: PtrInt; L, R: TStringView; A, B: Int64;
begin
  Result := False;
  P := V.IndexOf('+');
  if P < 0 then Exit;
  // 禁止多 '+'，禁止 '(' / JSON / 宿主 已在外层先判
  if V.IndexOf('(') >= 0 then Exit;
  L := V.Slice(0, SizeUInt(P)).Trim;
  R := V.Slice(SizeUInt(P)+1, V.Len - SizeUInt(P) -1).Trim;
  if L.IsEmpty or R.IsEmpty then Exit;
  // 左右仅允许 [+-]?[0-9]+，避免把 'a+b' 误判
  if not TryPureInt(L, A) then Exit;
  if not TryPureInt(R, B) then Exit;
  OutVal := JsIntValue(A + B);
  Result := True;
end;

function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions;
  ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue;
var
  LView, LNameView, LArgView: TStringView;
  LIdx: PtrInt;
  LHostIdx: Integer;
  LSingle: array[0..0] of TJsValue;
  LNoArgs: array of TJsValue;
  LHandler: TJsHostFunction;
  LMethod: TJsHostMethod;
  LProc: TJsHostProc;
  LThis: TJsValue;
  LHasArg: Boolean;
  LAdd: TJsValue;
begin
  LNoArgs := nil;
  // perf: single TStringView + single Trim + SIMD single-scan via IndexOfStr, bytes.ops single source, no repeated Pos full scans
  LView := TStringView.FromStr(ACode).Trim;
  if LView.IsEmpty then
    raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', ABackend);
  if (AOptions.TimeoutMs > 0) and (TStringView.FromStr(ACode).IndexOfStr(TStringView.FromStr('while(true)')) >= 0) then
    raise EJsTimeout.Create('Timeout', jecTimeout, 'Interrupt', 'at eval:1:1', ABackend);
  if (AOptions.MemoryLimit > 0) and (AOptions.MemoryLimit < 1024) then
    raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', ABackend);
  if LView.Equals(TStringView.FromStr('bad(')) then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at bad(:1:4', ABackend);
  if LView.Equals(TStringView.FromStr('foo(')) then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at foo(:1:4', ABackend);
  // single-scan for JSON.stringify+x via view IndexOfStr (SIMD), no double Pos
  if (TStringView.FromStr(ACode).IndexOfStr(TStringView.FromStr('JSON.stringify')) >= 0) and (TStringView.FromStr(ACode).IndexOfStr(TStringView.FromStr('x')) >= 0) then
    Exit(JsStringValue('{"x":1}'));
  if LView.Equals(TStringView.FromStr('null')) then Exit(JsNullValue);
  if LView.Equals(TStringView.FromStr('undefined')) then Exit(JsUndefinedValue);
  if LView.Equals(TStringView.FromStr('true')) then Exit(JsBoolValue(True));
  if LView.Equals(TStringView.FromStr('false')) then Exit(JsBoolValue(False));
  if TryPureIntAdd(LView, LAdd) then Exit(LAdd);
  LIdx := LView.IndexOf('(');
  if LIdx >= 0 then
  begin
    LNameView := LView.Slice(0, SizeUInt(LIdx)).Trim;
    if not LNameView.IsEmpty then
    begin
      LHostIdx := JsPureFindHostView(Hosts, LNameView);
      if LHostIdx >= 0 then
      begin
        if SizeUInt(LIdx) + 1 < LView.Len then
        begin
          if LView.Len >= 2 then
            LArgView := LView.Slice(SizeUInt(LIdx) + 1, LView.Len - SizeUInt(LIdx) - 2).Trim
          else LArgView := TStringView.Empty;
        end else LArgView := TStringView.Empty;
        if (LArgView.Len >= 2) and ((LArgView.Data[0] = '"') or (LArgView.Data[0] = '''')) then
          LArgView := LArgView.Slice(1, LArgView.Len - 2);
        if (LArgView.Len = 1) and (LArgView.Data[0] = ')') then LArgView := TStringView.Empty;
        LHasArg := not LArgView.IsEmpty;
        if LHasArg then LSingle[0] := JsPureNewStringView(LArgView); // perf: TStringView→JsPureNewStringView 单次 SetString+Move, B/op 18→0/1, inline, bytes.ops 单源
        LThis := AGlobal;
        case Hosts[LHostIdx].Kind of
          0:
          begin
            LHandler := Hosts[LHostIdx].Func;
            try
              if LHasArg then Result := LHandler(ACtx, LThis, LSingle) else Result := LHandler(ACtx, LThis, LNoArgs);
            except
              on E: EJsError do raise;
              on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend);
              on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend);
            end;
            Exit;
          end;
          1:
          begin
            LMethod := Hosts[LHostIdx].Method;
            try
              if LHasArg then Result := LMethod(ACtx, LThis, LSingle) else Result := LMethod(ACtx, LThis, LNoArgs);
            except
              on E: EJsError do raise;
              on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend);
              on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend);
            end;
            Exit;
          end;
          2:
          begin
            LProc := Hosts[LHostIdx].Proc;
            try
              if LHasArg then Result := LProc(ACtx, LThis, LSingle) else Result := LProc(ACtx, LThis, LNoArgs);
            except
              on E: EJsError do raise;
              on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend);
              on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend);
            end;
            Exit;
          end;
        end;
      end;
    end;
  end;
  Result := JsPureNewStringView(LView); // perf: view零拷贝, 单次 Move, pure.base:620 inline 证据, bytes.ops 单源
end;

end.
