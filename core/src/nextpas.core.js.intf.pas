unit nextpas.core.js.intf;
{** @desc JS 抽象接口与值语义（后端无关，不透明句柄，承载 V8/Chakra/QuickJS/js888）。四件套: base←intf←实现←门面, L0-L3 守分层, 值语义/宿主三形态/运行时三职责内聚, 单单元 ~125行 <500 阈值内 (wc -l ~125, 纯族 host/value 已收敛至 pure.host/pure.value 单源 owner, 见 CONTRACT §1/§6), 奢华薄 intf 零可变全局, AsJson inline 薄转发至 pure.value 单源 owner (json.writer/bytes.ops+text.view+text.escape+text.number+text.builder 单缝 via bytes.ops 几何 via pure.value), 零 intf→实现重逻辑, 状态下沉 lifecycle。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base, nextpas.core.json.types; // CONTRACT §1 限定仅 json.types, L2→L2 单缝 narrow via types, 单源 via pure.value owner (json.writer/bytes.ops single source), 零重逻辑反向依赖
type
  IJsRuntime = interface; IJsContext = interface;
  TJsStringArray = array of string;
  TJsValue = record
  private FKind: TJsValueKind; FValid: Boolean; FBoolVal: Boolean; FIntVal: Int64; FDoubleVal: Double; FStrVal: string; FContextId: UInt64;
  public
    function Kind: TJsValueKind; inline; function IsValid: Boolean; inline;
    function IsUndefined: Boolean; inline; function IsNull: Boolean; inline;
    function IsBool: Boolean; inline; function IsNumber: Boolean; inline; function IsString: Boolean; inline;
    function IsObject: Boolean; inline; function IsArray: Boolean; inline; function IsFunction: Boolean; inline;
    function IsError: Boolean; inline; function IsPromise: Boolean; inline; function IsSymbol: Boolean; inline; function IsBigInt: Boolean; inline;
    function AsBool: Boolean; inline; function AsInt: Int64; inline; function AsDouble: Double; inline; function AsString: string; inline; function AsJson: string; inline;
    function TryAsBool(out V: Boolean): Boolean; function TryAsDouble(out V: Double): Boolean; function TryAsString(out V: string): Boolean;
  end;
  IJsValueRef = interface ['{A7B2C9E1-4F8D-4A1E-9C3B-5D7E8F1A2B3C}'] function Value: TJsValue; end;
  TJsHostFunction = reference to function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
  TJsHostMethod = function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue of object;
  TJsHostProc = function(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
  IJsRuntime = interface ['{B1C2D3E4-F5A6-7890-ABCD-EF1234567890}']
    function Kind: TJsBackendKind; function Options: TJsRuntimeOptions; function NewContext: IJsContext;
    procedure SetMemoryLimit(ALimit: SizeUInt); procedure SetTimeout(ATimeoutMs: Integer); procedure CollectGarbage;
  end;
  IJsContext = interface ['{C2D3E4F5-A6B7-8901-BCDE-F12345678901}']
    function Runtime: IJsRuntime;
    function Eval(const ACode: string; const AFileName: string = ''): TJsValue;
    function TryEval(const ACode: string; out AValue: TJsValue): Boolean;
    function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
    function Global: TJsValue;
    function NewString(const AStr: string): TJsValue; function NewInt(AValue: Int64): TJsValue; function NewDouble(AValue: Double): TJsValue;
    function NewBool(AValue: Boolean): TJsValue; function NewObject: TJsValue; function NewArray: TJsValue;
    function NewJson(const AJson: TJsonValue): TJsValue; function ToJson(const AValue: TJsValue): IJsonDocument;
    // 完备对象能力（V8/Chakra/QuickJS 均可实现，fake 侧为确定性桩）
    function HasProp(const AObj: TJsValue; const AName: string): Boolean;
    function DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
    function GetKeys(const AObj: TJsValue): TJsStringArray;
    function NewError(const AMessage: string; ACategory: TJsErrorCategory = jecUnknown): TJsValue;
    function NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; overload;
    function NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; overload;
    function NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; overload;
    function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
    procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
    function Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
    procedure RemoveHostFunction(const AName: string);
    procedure Tick; procedure CollectGarbage; procedure Close; function IsClosed: Boolean;
  end;
function JsUndefinedValue: TJsValue; inline; function JsNullValue: TJsValue; inline; function JsBoolValue(AValue: Boolean): TJsValue; inline;
function JsIntValue(AValue: Int64): TJsValue; inline; function JsDoubleValue(AValue: Double): TJsValue; inline; function JsStringValue(const AValue: string): TJsValue; inline;
function JsStringViewValue(const AData: PAnsiChar; ALen: SizeUInt): TJsValue; inline;
function JsObjectValue: TJsValue; inline; function JsArrayValue: TJsValue; inline;
function JsHeapObjectValue(AId: Int64): TJsValue; inline;
function JsHeapArrayValue(AId: Int64): TJsValue; inline;
function JsObjectId(const V: TJsValue): Int64; inline;
function JsSymbolValue(const ADesc: string): TJsValue; inline; function JsBigIntValue(AValue: Int64): TJsValue; inline;
function JsErrorValue(const AMessage: string): TJsValue; inline; function JsFunctionValue(const AName: string = ''): TJsValue; inline; function JsFunctionName(const V: TJsValue): string; inline; function JsPromiseValue: TJsValue; inline;
// Context 寿命（INV-7）：状态单源下沉至 js.lifecycle (GPureClosed/GPureNextId 4B atomic acquire/release, 自然4B对齐, 64B/4 伪共享, write-once rare, geometric via bytes.ops single source, 零双注册), pure.base thin-forward, intf 零可变全局奢华薄, 不暴露 JsContextRegister/Close/IsClosed 桩 (需强一致时直调 js.lifecycle/pure.base.JsPureContextIsClosed acquire), 生命周期由 IJsContext.IsClosed 显式检查
function JsValueBindContext(const AValue: TJsValue; AContextId: UInt64): TJsValue; inline;
implementation
// intf 奢华薄：零可变全局，守四件套 base←intf←pure.impl←factory←门面，L0-L3 单向，热点 inline 零拷贝，状态下沉 owner js.lifecycle (THREAD-AFFINE, bulk 零原子)，单源 pure.value owner via bytes.ops 几何/零拷贝 (json.writer+text.escape+text.number+text.builder+text.view via pure.value 单缝)，零 intf→实现重逻辑反向依赖，资源 try-finally Done 在 owner 不丢
uses
  nextpas.core.bytes.ops,
  nextpas.core.js.pure.value;
function JsValueBindContext(const AValue: TJsValue; AContextId: UInt64): TJsValue; inline;
begin
  Result := AValue;
  Result.FContextId := AContextId;
end;
function JsUndefinedValue: TJsValue; begin Result.FKind:=jskUndefined; Result.FValid:=True; Result.FBoolVal:=False; Result.FIntVal:=0; Result.FDoubleVal:=0.0; Result.FStrVal:=''; Result.FContextId:=0; end;
function JsNullValue: TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskNull; end;
function JsBoolValue(AValue: Boolean): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskBoolean; Result.FBoolVal:=AValue; end;
function JsIntValue(AValue: Int64): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskNumber; Result.FIntVal:=AValue; Result.FDoubleVal:=Double(AValue); end;
function JsDoubleValue(AValue: Double): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskNumber; Result.FDoubleVal:=AValue; Result.FIntVal:=Int64(Trunc(AValue)); end;
function JsStringValue(const AValue: string): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskString; Result.FStrVal:=AValue; end;
function JsStringViewValue(const AData: PAnsiChar; ALen: SizeUInt): TJsValue; inline;
begin
  // perf: inline eager materialize via bytes.ops SpanToString single source, single string hosted owner, zero dangling view, lifecycle single-state, B/op=1 alloc
  if (AData=nil) or (ALen=0) then Result:=JsStringValue('')
  else begin Result:=JsUndefinedValue; Result.FKind:=jskString; Result.FStrVal:=SpanToString(TByteSpan.Create(PByte(AData), ALen)); end;
end;
function JsObjectValue: TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskObject; end;
function JsArrayValue: TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskArray; end;
function JsHeapObjectValue(AId: Int64): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskObject; Result.FIntVal:=AId; end;
function JsHeapArrayValue(AId: Int64): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskArray; Result.FIntVal:=AId; end;
function JsObjectId(const V: TJsValue): Int64; begin Result:=V.FIntVal; end;
function JsSymbolValue(const ADesc: string): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskSymbol; Result.FStrVal:=ADesc; end;
function JsBigIntValue(AValue: Int64): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskBigInt; Result.FIntVal:=AValue; Result.FDoubleVal:=Double(AValue); end;
function JsErrorValue(const AMessage: string): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskError; Result.FStrVal:=AMessage; end;
function JsFunctionValue(const AName: string = ''): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskFunction; Result.FStrVal:=AName; end;
function JsPromiseValue: TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskPromise; end;
function JsFunctionName(const V: TJsValue): string; begin if V.IsFunction then Result:=V.FStrVal else Result:=''; end;
// INV-7: IsValid 仅 FValid 字段访问，零原子零分支，bulk GetProp/HasProp 零屏障；Context 关闭态由 IJsContext.IsClosed 显式检查（pure.base 原子 release/acquire 保障跨线程可见性），thread-affine 零成本
function TJsValue.Kind: TJsValueKind; inline; begin Result:=FKind; end;
function TJsValue.IsValid: Boolean; inline; begin Result:=FValid; end;
function TJsValue.IsUndefined: Boolean; begin Result:=FKind=jskUndefined; end;
function TJsValue.IsNull: Boolean; begin Result:=FKind=jskNull; end;
function TJsValue.IsBool: Boolean; begin Result:=FKind=jskBoolean; end;
function TJsValue.IsNumber: Boolean; begin Result:=FKind=jskNumber; end;
function TJsValue.IsString: Boolean; begin Result:=FKind=jskString; end;
function TJsValue.IsObject: Boolean; begin Result:=FKind=jskObject; end;
function TJsValue.IsArray: Boolean; begin Result:=FKind=jskArray; end;
function TJsValue.IsFunction: Boolean; begin Result:=FKind=jskFunction; end;
function TJsValue.IsError: Boolean; begin Result:=FKind=jskError; end;
function TJsValue.IsPromise: Boolean; begin Result:=FKind=jskPromise; end;
function TJsValue.IsSymbol: Boolean; begin Result:=FKind=jskSymbol; end;
function TJsValue.IsBigInt: Boolean; begin Result:=FKind=jskBigInt; end;
function TJsValue.AsBool: Boolean; begin if FKind<>jskBoolean then Exit(False); Result:=FBoolVal; end;
function TJsValue.AsInt: Int64; begin if FKind<>jskNumber then if FKind=jskBigInt then Exit(FIntVal) else Exit(0); Result:=FIntVal; end;
function TJsValue.AsDouble: Double; begin if FKind<>jskNumber then Exit(0.0); Result:=FDoubleVal; end;
function TJsValue.AsString: string; inline;
begin
  // single source: FStrVal hosted string, inline zero-copy return, bytes.ops SpanToString single source at creation via JsStringViewValue, lifecycle single-state, resource not丢
  if FKind=jskSymbol then Exit(FStrVal);
  if FKind<>jskString then Exit('');
  Result:=FStrVal;
end;
function TJsValue.AsJson: string; inline;
begin
  // perf: inline thin-forward to pure.value owner single source JsPureToJsonString via json.writer TStringBuilder+text.escape SIMD+text.number stack single source, bytes.ops single source via BytesCopy single Move, text.view zero-copy, 单源单缝 via pure.value, 热点 inline 零拷贝, 资源 try-finally Done 在 owner 不丢, 守 L0-L3 单向 base←intf 薄 intf 零重逻辑
  Result := JsPureToJsonString(Self);
end;
function TJsValue.TryAsBool(out V: Boolean): Boolean; begin Result:=FKind=jskBoolean; if Result then V:=FBoolVal else V:=False; end;
function TJsValue.TryAsDouble(out V: Double): Boolean; begin Result:=FKind=jskNumber; if Result then V:=FDoubleVal else V:=0.0; end;
function TJsValue.TryAsString(out V: string): Boolean; begin
  // single source: hosted FStrVal, inline, bytes.ops single source at creation, zero view caching complexity, resource not丢
  Result:=FKind=jskString;
  if Result then V:=FStrVal else V:='';
end;
end.
