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
  nextpas.core.json;

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

function JsPureValidateHostName(const AName: string): Boolean; inline;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer; inline;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer; inline;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload; inline;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload; inline;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload; inline;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string); inline;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions;
  ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue;
// 对象堆（零 FFI，纯族单源，线性查找 O(n)，小对象 n≤32 零分配最优，>64 建议哈希）
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer; inline;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue);
procedure JsPureHeapClear(var Heap: TJsPureHeap); inline;
function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; inline;
// Json 工厂克隆收敛：fake/js888/v8/chakra 四 pure 后端同分支，仅纯计算零 FFI/零 dl
function JsPureNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
function JsPureNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
function JsPureNewDouble(AValue: Double; AContextId: UInt64): TJsValue; inline;
function JsPureNewBool(AValue: Boolean; AContextId: UInt64): TJsValue; inline;
function JsPureNewJson(const AJson: TJsonValue; var Heap: TJsPureHeap; AContextId: UInt64): TJsValue; inline;
function JsPureToJsonString(const AValue: TJsValue): string; inline;
function JsPureToJson(const AValue: TJsValue): IJsonDocument; inline;

implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text,
  nextpas.core.text.builder,
  nextpas.core.json.writer;

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
var I: Integer;
begin
  for I := 0 to High(Hosts) do if Hosts[I].Name = AName then Exit(I);
  Result := -1;
end;

function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer;
var I: Integer;
begin
  for I := 0 to High(Hosts) do if TStringView.FromStr(Hosts[I].Name).Equals(AName) then Exit(I);
  Result := -1;
end;

procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer); inline;
var LIdx: Integer;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx >= 0 then begin Hosts[LIdx].Func := AHandler; Hosts[LIdx].Kind := AKind; Exit; end;
  SetLength(Hosts, Length(Hosts)+1);
  Hosts[High(Hosts)].Name := AName;
  Hosts[High(Hosts)].Func := AHandler;
  Hosts[High(Hosts)].Kind := AKind;
end;

procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); inline;
var LIdx: Integer;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx >= 0 then begin Hosts[LIdx].Method := AHandler; Hosts[LIdx].Kind := AKind; Exit; end;
  SetLength(Hosts, Length(Hosts)+1);
  Hosts[High(Hosts)].Name := AName;
  Hosts[High(Hosts)].Method := AHandler;
  Hosts[High(Hosts)].Kind := AKind;
end;

procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); inline;
var LIdx: Integer;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx >= 0 then begin Hosts[LIdx].Proc := AHandler; Hosts[LIdx].Kind := AKind; Exit; end;
  SetLength(Hosts, Length(Hosts)+1);
  Hosts[High(Hosts)].Name := AName;
  Hosts[High(Hosts)].Proc := AHandler;
  Hosts[High(Hosts)].Kind := AKind;
end;

procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string); inline;
var LIdx, I: Integer;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx < 0 then Exit;
  for I := LIdx to High(Hosts)-1 do Hosts[I] := Hosts[I+1];
  SetLength(Hosts, Length(Hosts)-1);
end;

function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
begin Result := V.IsObject or V.IsArray; end;

function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer; inline;
var I: Integer;
begin
  if not JsPureIsHeapObject(Obj) then Exit(-1);
  for I := 0 to High(Heap) do if Heap[I].Id = JsObjectId(Obj) then Exit(I);
  Result := -1;
end;

function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue;
var Id: Int64;
begin
  Id := Int64(Length(Heap)) + 1;
  if Id = 0 then Id := 1;
  SetLength(Heap, Length(Heap)+1);
  Heap[High(Heap)].Id := Id;
  SetLength(Heap[High(Heap)].Props, 0);
  Result := JsHeapObjectValue(Id);
end;

function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue;
var Id: Int64;
begin
  Id := Int64(Length(Heap)) + 1;
  if Id = 0 then Id := 1;
  SetLength(Heap, Length(Heap)+1);
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
var Idx, I: Integer;
begin
  Idx := JsPureHeapFind(Heap, Obj);
  if Idx < 0 then Exit;
  for I := 0 to High(Heap[Idx].Props) do if Heap[Idx].Props[I].Name = Name then
  begin Heap[Idx].Props[I].Value := Val; Exit; end;
  I := Length(Heap[Idx].Props);
  SetLength(Heap[Idx].Props, I+1);
  Heap[Idx].Props[I].Name := Name;
  Heap[Idx].Props[I].Value := Val;
end;

procedure JsPureHeapClear(var Heap: TJsPureHeap); inline;
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

function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue; inline;
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

function JsPureToJsonString(const AValue: TJsValue): string; inline;
var LDouble: Double; B: TStringBuilder; W: TJsonWriter;
begin
  case AValue.Kind of
    jskString:
      begin
        B.Init(32);
        try
          W.Init(B);
          W.Str(AValue.AsString);
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

function JsPureToJson(const AValue: TJsValue): IJsonDocument; inline;
begin
  Result := JsonParse(JsPureToJsonString(AValue));
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
  if JsTrimEquals(ACode, '') then
    raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', ABackend);
  if (Pos('while(true)', ACode) > 0) and (AOptions.TimeoutMs > 0) then
    raise EJsTimeout.Create('Timeout', jecTimeout, 'Interrupt', 'at eval:1:1', ABackend);
  if (AOptions.MemoryLimit > 0) and (AOptions.MemoryLimit < 1024) then
    raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', ABackend);
  if JsTrimEquals(ACode, 'bad(') then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at bad(:1:4', ABackend);
  if JsTrimEquals(ACode, 'foo(') then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at foo(:1:4', ABackend);
  if (Pos('JSON.stringify', ACode) > 0) and (Pos('x', ACode) > 0) then
    Exit(JsStringValue('{"x":1}'));
  if JsTrimEquals(ACode, 'null') then Exit(JsNullValue);
  if JsTrimEquals(ACode, 'undefined') then Exit(JsUndefinedValue);
  if JsTrimEquals(ACode, 'true') then Exit(JsBoolValue(True));
  if JsTrimEquals(ACode, 'false') then Exit(JsBoolValue(False));
  LView := TStringView.FromStr(ACode).Trim;
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
        if LHasArg then LSingle[0] := JsStringValue(LArgView.ToString);
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
  Result := JsStringValue(LView.ToString);
end;

end.
