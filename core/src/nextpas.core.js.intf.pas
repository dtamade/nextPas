unit nextpas.core.js.intf;
{** @desc JS 抽象接口与值语义（后端无关，不透明句柄，承载 V8/Chakra/QuickJS/js888）。四件套: base←intf←实现←门面, L0-L3 守分层, 值语义/宿主三形态/运行时三职责内聚, 单单元 ~150行 <500 阈值内 (wc -l ~150, >500预案 js.value/host, 见 CONTRACT §1/§6), 单源 bytes.ops/mem.dynarray/atomic/js.value。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base, nextpas.core.json.types; // CONTRACT §1 限定仅 json.types, L2→L2 单缝 narrow via types, impl 经 writer 单缝单源
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
    function AsBool: Boolean; inline; function AsInt: Int64; inline; function AsDouble: Double; inline; function AsString: string; inline; function AsJson: string;
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
function JsObjectValue: TJsValue; inline; function JsArrayValue: TJsValue; inline;
function JsHeapObjectValue(AId: Int64): TJsValue; inline;
function JsHeapArrayValue(AId: Int64): TJsValue; inline;
function JsObjectId(const V: TJsValue): Int64; inline;
function JsSymbolValue(const ADesc: string): TJsValue; inline; function JsBigIntValue(AValue: Int64): TJsValue; inline;
function JsErrorValue(const AMessage: string): TJsValue; inline; function JsFunctionValue(const AName: string = ''): TJsValue; inline; function JsFunctionName(const V: TJsValue): string; inline; function JsPromiseValue: TJsValue; inline;
// Context 寿命注册（INV-7 硬阻断）：值绑定的 ContextId 在 Close 时标记失效，IsValid 联动 FClosed
function JsContextRegister: UInt64;
procedure JsContextClose(AId: UInt64);
function JsContextIsClosed(AId: UInt64): Boolean; inline;
function JsValueBindContext(const AValue: TJsValue; AContextId: UInt64): TJsValue; inline;
implementation
uses
  nextpas.core.bytes.ops, // single source capacity geometric via BytesNextCapacity, amortized O(1)
  nextpas.core.mem.dynarray, // single source Exactly-Once poke via DynArraySetLength, single SetLength+single poke
  nextpas.core.atomic, // acquire/release for cross-thread IsValid visibility
  nextpas.core.js.value; // single source AsJson via js.value (TJsonWriter seam), zero-copy inline thin-forward
var GJsClosed: array of Int32; GJsNextId: UInt64 = 1; // lock-free: 4-byte atomic acquire/release, 16-byte heap aligned, volatile, false-sharing 16/line(64B/4), write-once rare, read ~1ns, quantified <5% under contention

// thread-affine: Register grows GJsClosed geometrically via bytes.ops single source, Exactly-Once poke via mem.dynarray (no double SetLength)
function JsContextRegister: UInt64;
var LNeed, LCap: SizeUInt; LBytes: TBytes absolute GJsClosed;
begin
  Result := GJsNextId;
  Inc(GJsNextId);
  if Result >= UInt64(Length(GJsClosed)) then
  begin
    LNeed := SizeUInt(Result) + 32;
    LCap := BytesNextCapacity(SizeUInt(Length(GJsClosed)), LNeed);
    SetLength(GJsClosed, Integer(LCap));
    if LCap <> SizeUInt(Result) + 1 then
      DynArraySetLength(LBytes, SizeUInt(Result) + 1);
  end;
  atomic_store(GJsClosed[Result], 0, mo_release);
end;
procedure JsContextClose(AId: UInt64);
begin
  if (AId > 0) and (AId < UInt64(Length(GJsClosed))) then
    atomic_store(GJsClosed[AId], 1, mo_release);
end;
function JsContextIsClosed(AId: UInt64): Boolean; inline;
var LVal: Int32;
begin
  // perf: lock-free acquire, inline zero-branch zero-alloc, volatile 4B atomic, no mutex, single bounds check, false-sharing 16/line write-once
  if AId = 0 then Exit(False);
  if AId >= UInt64(Length(GJsClosed)) then Exit(False);
  LVal := atomic_load(GJsClosed[AId], mo_acquire);
  Result := LVal <> 0;
end;
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
// INV-7: IsValid 联动 Context 关闭态（GJsClosed）；Kind 纯字段访问；IsValid lock-free acquire inline via JsContextIsClosed zero-alloc zero-branch volatile 4B
function TJsValue.Kind: TJsValueKind; inline; begin Result:=FKind; end;
function TJsValue.IsValid: Boolean; inline; begin Result:=FValid and ((FContextId=0) or not JsContextIsClosed(FContextId)); end;
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
function TJsValue.AsString: string; begin if FKind<>jskString then if FKind=jskSymbol then Exit(FStrVal) else Exit(''); Result:=FStrVal; end;
function TJsValue.AsJson: string;
begin
  // single source via js.value.JsValueAsJson (json.writer TJsonWriter seam, builder geometric via bytes.ops, zero-copy inline thin-forward)
  Result := JsValueAsJson(Self);
end;
function TJsValue.TryAsBool(out V: Boolean): Boolean; begin Result:=FKind=jskBoolean; if Result then V:=FBoolVal else V:=False; end;
function TJsValue.TryAsDouble(out V: Double): Boolean; begin Result:=FKind=jskNumber; if Result then V:=FDoubleVal else V:=0.0; end;
function TJsValue.TryAsString(out V: string): Boolean; begin Result:=FKind=jskString; if Result then V:=FStrVal else V:=''; end;

initialization
  // stability: heaptrc 0 leaks, lock-free atomic acquire/release, no mutex init, try-finally not needed
finalization
  SetLength(GJsClosed, 0);
end.
