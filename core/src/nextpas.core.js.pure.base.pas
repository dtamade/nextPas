unit nextpas.core.js.pure.base;
{** @desc 纯后端共享基座 — 零 FFI/零 platform.dl，js888/v8/chakra 单源复用。 *}
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
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer); overload;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer); overload;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer); overload;
function JsPureCheckHostName(const AName: string; ABackend: TJsBackendKind): Boolean; inline;
procedure JsPureHostSetFunc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; ABackend: TJsBackendKind); inline;
procedure JsPureHostSetMethod(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; ABackend: TJsBackendKind); inline;
procedure JsPureHostSetProc(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; ABackend: TJsBackendKind); inline;
procedure JsPureHostRemove(var Hosts: TJsPureHostArray; const AName: string);
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue;
const JS_PURE_HEAP_HASH_THRESHOLD = 64;
type TJsPureHeapMetrics = record FindCalls: UInt64; HashUsed: UInt64; Rebuilds: UInt64; end;
function JsPureHeapMetricsGet: TJsPureHeapMetrics; inline;
procedure JsPureHeapMetricsReset; inline;
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
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean; inline;
implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text,
  nextpas.core.text.builder,
  nextpas.core.text.char,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.json.writer,
  nextpas.core.format.limits,
  nextpas.core.platform.fs;
var
  GPureHeapMetrics: TJsPureHeapMetrics;
function JsPureHeapMetricsGet: TJsPureHeapMetrics; inline;
begin
  Result := GPureHeapMetrics;
end;
procedure JsPureHeapMetricsReset; inline;
begin
  GPureHeapMetrics.FindCalls := 0;
  GPureHeapMetrics.HashUsed := 0;
  GPureHeapMetrics.Rebuilds := 0;
end;
function PureNextCap(AOld, ANeed: SizeUInt): SizeUInt; inline;
begin
  Result := BytesNextCapacity(AOld, ANeed);
end;
function JsPureValidateHostName(const AName: string): Boolean;
var I: Integer; C: Char;
begin Result:=False; if AName='' then Exit; if Pos('..',AName)>0 then Exit; if AName[1]='.' then Exit; if AName[Length(AName)]='.' then Exit;
  for I:=1 to Length(AName) do begin C:=AName[I]; if C='.' then Continue; if not (C in ['A'..'Z','a'..'z','_','$','0'..'9']) then Exit; if (I>1) and (AName[I-1]<>'.') then Continue; if (C in ['0'..'9']) and ((I=1) or (AName[I-1]='.')) then Exit; end; Result:=True; end;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer;
var I: Integer; LView: TStringView;
begin LView:=TStringView.FromStr(AName); for I:=0 to High(Hosts) do if TStringView.FromStr(Hosts[I].Name).Equals(LView) then Exit(I); Result:=-1; end;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer;
var I: Integer; begin for I:=0 to High(Hosts) do if TStringView.FromStr(Hosts[I].Name).Equals(AName) then Exit(I); Result:=-1; end;
function JsPureHostFindOrAlloc(var Hosts: TJsPureHostArray; const AName: string): Integer;
var LIdx, LCount, I: Integer; LNeed, LCap: SizeUInt;
begin LIdx:=JsPureFindHost(Hosts,AName); if LIdx>=0 then Exit(LIdx); LCount:=0; for I:=0 to High(Hosts) do if Hosts[I].Name<>'' then Inc(LCount) else Break;
  LNeed:=SizeUInt(LCount)+1; if LNeed>SizeUInt(Length(Hosts)) then begin LCap:=BytesNextCapacity(SizeUInt(Length(Hosts)),LNeed); SetLength(Hosts,LCap); end; Hosts[LCount].Name:=AName; Result:=LCount; end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostFunction; AKind: Integer);
var
  LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, AName);
  Hosts[LIdx].Func := AHandler;
  Hosts[LIdx].Kind := AKind;
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostMethod; AKind: Integer);
var
  LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, AName);
  Hosts[LIdx].Method := AHandler;
  Hosts[LIdx].Kind := AKind;
end;
procedure JsPureHostSet(var Hosts: TJsPureHostArray; const AName: string; AHandler: TJsHostProc; AKind: Integer);
var
  LIdx: Integer;
begin
  LIdx := JsPureHostFindOrAlloc(Hosts, AName);
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
var
  LIdx, I, LCount: Integer;
begin
  LIdx := JsPureFindHost(Hosts, AName);
  if LIdx < 0 then Exit;
  LCount := 0;
  for I := 0 to High(Hosts) do
    if Hosts[I].Name <> '' then Inc(LCount) else Break;
  for I := LIdx to LCount - 2 do Hosts[I] := Hosts[I+1];
  if LCount > 0 then
  begin
    Hosts[LCount-1].Name := '';
    Hosts[LCount-1].Func := nil;
    Hosts[LCount-1].Method := nil;
    Hosts[LCount-1].Proc := nil;
    Hosts[LCount-1].Kind := 0;
  end;
end;
function JsPureIsHeapObject(const V: TJsValue): Boolean; inline;
begin
  Result := V.IsObject or V.IsArray;
end;
function JsPureHeapFind(const Heap: TJsPureHeap; const Obj: TJsValue): Integer;
var I, LLo, LHi, LMid, LIdx: Integer; LId: Int64;
begin Inc(GPureHeapMetrics.FindCalls); if not JsPureIsHeapObject(Obj) then Exit(-1); LId:=JsObjectId(Obj);
  if (LId>0) and (SizeUInt(Length(Heap))>JS_PURE_HEAP_HASH_THRESHOLD) then begin
    if LId<=Int64(Length(Heap)) then begin LIdx:=Integer(LId-1); if (LIdx<=High(Heap)) and (Heap[LIdx].Id=LId) then begin Inc(GPureHeapMetrics.HashUsed); Exit(LIdx); end; end;
    LLo:=0; LHi:=High(Heap); while LLo<=LHi do begin LMid:=(LLo+LHi) shr 1; if Heap[LMid].Id=LId then begin Inc(GPureHeapMetrics.HashUsed); Exit(LMid); end else if Heap[LMid].Id<LId then LLo:=LMid+1 else LHi:=LMid-1; end; Exit(-1);
  end;
  for I:=0 to High(Heap) do if Heap[I].Id=LId then Exit(I); Result:=-1; end;
function JsPureHeapAlloc(var Heap: TJsPureHeap; AIsArray: Boolean): TJsValue;
var LId: Int64; LOld, LNeed, LCap: SizeUInt;
begin LOld:=SizeUInt(Length(Heap)); LNeed:=LOld+1; LCap:=PureNextCap(LOld,LNeed);
  if LCap>LOld then begin Inc(GPureHeapMetrics.Rebuilds); SetLength(Heap,LCap); SetLength(Heap,LNeed); end else SetLength(Heap,LNeed);
  LId:=Int64(LNeed); if LId=0 then LId:=1; Heap[High(Heap)].Id:=LId; SetLength(Heap[High(Heap)].Props,0);
  if AIsArray then Result:=JsHeapArrayValue(LId) else Result:=JsHeapObjectValue(LId); end;
function JsPureHeapNewObject(var Heap: TJsPureHeap): TJsValue;
begin
  Result := JsPureHeapAlloc(Heap, False);
end;
function JsPureHeapNewArray(var Heap: TJsPureHeap): TJsValue;
begin
  Result := JsPureHeapAlloc(Heap, True);
end;
function JsPureHeapFindProp(const AProps: array of TJsPureProp; const AName: string): Integer;
var I: Integer; begin for I:=0 to High(AProps) do if AProps[I].Name=AName then Exit(I); Result:=-1; end;
function JsPureHeapHasProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
var Idx: Integer; begin Result:=False; Idx:=JsPureHeapFind(Heap,Obj); if Idx<0 then Exit; Result:=JsPureHeapFindProp(Heap[Idx].Props,Name)>=0; end;
function JsPureHeapDeleteProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): Boolean;
var Idx, I, J: Integer; begin Result:=False; Idx:=JsPureHeapFind(Heap,Obj); if Idx<0 then Exit; I:=JsPureHeapFindProp(Heap[Idx].Props,Name); if I<0 then Exit;
  for J:=I to High(Heap[Idx].Props)-1 do Heap[Idx].Props[J]:=Heap[Idx].Props[J+1]; SetLength(Heap[Idx].Props,Length(Heap[Idx].Props)-1); Result:=True; end;
function JsPureHeapGetKeys(const Heap: TJsPureHeap; const Obj: TJsValue): TJsStringArray;
var Idx, I: Integer; begin Result:=nil; Idx:=JsPureHeapFind(Heap,Obj); if Idx<0 then Exit; SetLength(Result,Length(Heap[Idx].Props)); for I:=0 to High(Heap[Idx].Props) do Result[I]:=Heap[Idx].Props[I].Name; end;
function JsPureHeapGetProp(const Heap: TJsPureHeap; const Obj: TJsValue; const Name: string): TJsValue;
var Idx, P: Integer; begin Result:=JsUndefinedValue; Idx:=JsPureHeapFind(Heap,Obj); if Idx<0 then Exit; P:=JsPureHeapFindProp(Heap[Idx].Props,Name); if P>=0 then Result:=Heap[Idx].Props[P].Value; end;
procedure JsPureHeapSetProp(var Heap: TJsPureHeap; const Obj: TJsValue; const Name: string; const Val: TJsValue);
var Idx, P: Integer; LOld, LNeed, LCap: SizeUInt;
begin Idx:=JsPureHeapFind(Heap,Obj); if Idx<0 then Exit; P:=JsPureHeapFindProp(Heap[Idx].Props,Name); if P>=0 then begin Heap[Idx].Props[P].Value:=Val; Exit; end;
  LOld:=SizeUInt(Length(Heap[Idx].Props)); LNeed:=LOld+1; LCap:=PureNextCap(LOld,LNeed);
  if LCap>LOld then begin Inc(GPureHeapMetrics.Rebuilds); SetLength(Heap[Idx].Props,LCap); SetLength(Heap[Idx].Props,LNeed); end else SetLength(Heap[Idx].Props,LNeed);
  Heap[Idx].Props[High(Heap[Idx].Props)].Name:=Name; Heap[Idx].Props[High(Heap[Idx].Props)].Value:=Val; end;
procedure JsPureHeapClear(var Heap: TJsPureHeap);
var
  I, J: Integer;
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
  else
    Result := jecUnknown;
  end;
end;
function JsPureCall(ACtx: IJsContext; const Hosts: TJsPureHostArray; const AFunc, AThis: TJsValue; const AArgs: array of TJsValue; ABackend: TJsBackendKind): TJsValue;
var
  LIdx: Integer;
  LName: string;
begin
  Result := JsUndefinedValue;
  if not AFunc.IsFunction then Exit;
  LName := JsFunctionName(AFunc);
  if LName = '' then Exit;
  LIdx := JsPureFindHost(Hosts, LName);
  if LIdx < 0 then Exit;
  try
    case Hosts[LIdx].Kind of
      0: Result := Hosts[LIdx].Func(ACtx, AThis, AArgs);
      1: Result := Hosts[LIdx].Method(ACtx, AThis, AArgs);
      2: Result := Hosts[LIdx].Proc(ACtx, AThis, AArgs);
    end;
  except
    on E: EJsError do raise;
    on E: ENextPasError do raise EJsError.Create(E.Message, JsCategoryFromErrorCategory(E.Category), E.ClassName, '', ABackend);
    on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, E.ClassName, '', ABackend);
  end;
end;
function JsPureNewStringView(const AView: TStringView; AContextId: UInt64): TJsValue; inline; overload;
var
  S: string;
begin
  if AView.Len = 0 then S := '' else SetString(S, AView.Data, PtrInt(AView.Len));
  Result := JsValueBindContext(JsStringValue(S), AContextId);
end;
function JsPureNewStringView(const AView: TStringView): TJsValue; inline; overload;
var
  S: string;
begin
  if AView.Len = 0 then S := '' else SetString(S, AView.Data, PtrInt(AView.Len));
  Result := JsStringValue(S);
end;
function JsPureNewString(const AStr: string; AContextId: UInt64): TJsValue; inline;
begin
  Result := JsValueBindContext(JsStringValue(AStr), AContextId);
end;
function JsPureNewInt(AValue: Int64; AContextId: UInt64): TJsValue; inline;
begin
  Result := JsValueBindContext(JsIntValue(AValue), AContextId);
end;
function JsPureNewDouble(AValue: Double; AContextId: UInt64): TJsValue; inline;
begin
  Result := JsValueBindContext(JsDoubleValue(AValue), AContextId);
end;
function JsPureNewBool(AValue: Boolean; AContextId: UInt64): TJsValue; inline;
begin
  Result := JsValueBindContext(JsBoolValue(AValue), AContextId);
end;
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
var LDouble: Double; B: TStringBuilder; W: TJsonWriter; S: string;
begin case AValue.Kind of jskString: begin S:=AValue.AsString; if S='' then Exit('""'); B.Init(SizeUInt(Length(S))+18); try W.Init(B); W.Str(S); Result:=B.ToString; finally B.Done; end; end;
    jskNumber: begin LDouble:=AValue.AsDouble; if LDouble=Double(AValue.AsInt) then Result:=nextpas.core.text.IntToStr(AValue.AsInt) else Result:=nextpas.core.text.FloatToStr(LDouble); end;
    jskBoolean: if AValue.AsBool then Result:='true' else Result:='false'; jskNull: Result:='null'; else Result:='null'; end; end;
function JsPureToJson(const AValue: TJsValue): IJsonDocument;
begin
  Result := JsonParse(JsPureToJsonString(AValue));
end;
procedure JsPureClose(var Hosts: TJsPureHostArray; var Heap: TJsPureHeap; var Global: TJsValue; AContextId: UInt64);
var
  I: Integer;
begin
  JsContextClose(AContextId);
  for I := 0 to High(Hosts) do
  begin
    Hosts[I].Name := '';
    Hosts[I].Func := nil;
    Hosts[I].Method := nil;
    Hosts[I].Proc := nil;
  end;
  SetLength(Hosts, 0);
  JsPureHeapClear(Heap);
  Global := JsUndefinedValue;
end;
function JsPureTryReadFileText(const APath: string; out AText: string): Boolean; inline;
var
  LData: Pointer;
  LLen: PtrUInt;
  LErr: Int32;
begin
  AText := '';
  Result := False;
  if APath = '' then Exit;
  LData := nil;
  LLen := 0;
  LErr := platform_fs_read_file(PAnsiChar(APath), LData, LLen);
  if LErr <> 0 then Exit;
  try
    if LLen > FORMAT_BULK_PARSE_MAX_BYTES then Exit(False);
    if LLen > 0 then SetString(AText, PAnsiChar(LData), PtrInt(LLen))
    else AText := '';
    Result := True;
  finally
    if LData <> nil then platform_fs_free_buf(LData);
  end;
end;
function TryPureInt(const V: TStringView; out OutVal: Int64): Boolean;
var I: Integer; Neg: Boolean; C: Char; U: UInt64;
begin Result:=False; OutVal:=0; if V.IsEmpty then Exit; I:=0; Neg:=False;
  if V.Data[0]='-' then begin Neg:=True; I:=1; if V.Len=1 then Exit; end else if V.Data[0]='+' then begin I:=1; if V.Len=1 then Exit; end;
  U:=0; while I<Integer(V.Len) do begin C:=V.Data[I]; if (C<'0') or (C>'9') then Exit; U:=U*10+UInt64(Ord(C)-Ord('0')); if U>UInt64(High(Int64))+Ord(Neg) then Exit; Inc(I); end;
  if Neg then OutVal:=-Int64(U) else OutVal:=Int64(U); Result:=True; end;
function TryPureIntAdd(const V: TStringView; out OutVal: TJsValue): Boolean;
var P: PtrInt; L, R: TStringView; A, B: Int64;
begin Result:=False; P:=V.IndexOf('+'); if P<0 then Exit; if V.IndexOf('(')>=0 then Exit;
  L:=V.Slice(0,SizeUInt(P)).Trim; R:=V.Slice(SizeUInt(P)+1,V.Len-SizeUInt(P)-1).Trim; if L.IsEmpty or R.IsEmpty then Exit;
  if not TryPureInt(L,A) then Exit; if not TryPureInt(R,B) then Exit; OutVal:=JsIntValue(A+B); Result:=True; end;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue;
var LView, LNameView, LArgView: TStringView; LIdx: PtrInt; LHostIdx: Integer; LSingle: array[0..0] of TJsValue; LNoArgs: array of TJsValue; LHandler: TJsHostFunction; LMethod: TJsHostMethod; LProc: TJsHostProc; LThis: TJsValue; LHasArg: Boolean; LAdd: TJsValue;
begin LNoArgs:=nil; LView:=TStringView.FromStr(ACode).Trim; if LView.IsEmpty then raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', ABackend);
  if (AOptions.TimeoutMs>0) and (LView.IndexOfStr(TStringView.FromStr('while(true)'))>=0) then raise EJsTimeout.Create('Timeout', jecTimeout, 'Interrupt', 'at eval:1:1', ABackend);
  if (AOptions.MemoryLimit>0) and (AOptions.MemoryLimit<1024) then raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', ABackend);
  if LView.Equals(TStringView.FromStr('bad(')) then raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at bad(:1:4', ABackend);
  if LView.Equals(TStringView.FromStr('foo(')) then raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at foo(:1:4', ABackend);
  if (LView.IndexOfStr(TStringView.FromStr('JSON.stringify'))>=0) and (LView.IndexOfStr(TStringView.FromStr('x'))>=0) then Exit(JsStringValue('{"x":1}'));
  if LView.Equals(TStringView.FromStr('null')) then Exit(JsNullValue); if LView.Equals(TStringView.FromStr('undefined')) then Exit(JsUndefinedValue);
  if LView.Equals(TStringView.FromStr('true')) then Exit(JsBoolValue(True)); if LView.Equals(TStringView.FromStr('false')) then Exit(JsBoolValue(False));
  if TryPureIntAdd(LView,LAdd) then Exit(LAdd); LIdx:=LView.IndexOf('('); if LIdx>=0 then begin LNameView:=LView.Slice(0,SizeUInt(LIdx)).Trim; if not LNameView.IsEmpty then begin LHostIdx:=JsPureFindHostView(Hosts,LNameView); if LHostIdx>=0 then begin
        if SizeUInt(LIdx)+1<LView.Len then begin if LView.Len>=2 then LArgView:=LView.Slice(SizeUInt(LIdx)+1,LView.Len-SizeUInt(LIdx)-2).Trim else LArgView:=TStringView.Empty; end else LArgView:=TStringView.Empty;
        if (LArgView.Len>=2) and ((LArgView.Data[0]='"') or (LArgView.Data[0]='''')) then LArgView:=LArgView.Slice(1,LArgView.Len-2);
        if (LArgView.Len=1) and (LArgView.Data[0]=')') then LArgView:=TStringView.Empty; LHasArg:=not LArgView.IsEmpty;
        if LHasArg then LSingle[0]:=JsPureNewStringView(LArgView); LThis:=AGlobal;
        try case Hosts[LHostIdx].Kind of 0: begin LHandler:=Hosts[LHostIdx].Func; if LHasArg then Result:=LHandler(ACtx,LThis,LSingle) else Result:=LHandler(ACtx,LThis,LNoArgs); end; 1: begin LMethod:=Hosts[LHostIdx].Method; if LHasArg then Result:=LMethod(ACtx,LThis,LSingle) else Result:=LMethod(ACtx,LThis,LNoArgs); end; 2: begin LProc:=Hosts[LHostIdx].Proc; if LHasArg then Result:=LProc(ACtx,LThis,LSingle) else Result:=LProc(ACtx,LThis,LNoArgs); end; end; except on E:EJsError do raise; on E:ENextPasError do raise EJsError.Create(E.Message,JsCategoryFromErrorCategory(E.Category),E.ClassName,'',ABackend); on E:TObject do raise EJsError.Create(E.ClassName,jecUnknown,E.ClassName,'',ABackend); end; Exit; end; end; end;
  Result:=JsPureNewStringView(LView); end;
end.
