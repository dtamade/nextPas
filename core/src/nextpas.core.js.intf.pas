unit nextpas.core.js.intf;
{**
 * @desc JS 抽象接口与值语义（后端无关，不透明句柄）。
 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base, nextpas.core.json.types; // CONTRACT §1 narrow: json.types only
type
  IJsRuntime = interface; IJsContext = interface;
  TJsStringArray = array of string;
  TJsValue = record
  private
    FKind: TJsValueKind;
    FValid: Boolean;
    FBoolVal: Boolean;
    FIntVal: Int64;
    FDoubleVal: Double;
    FStrVal: string;
    FContextId: UInt64;
    function IsKind(AKind: TJsValueKind): Boolean; inline;
    function IsKindIn(A, B: TJsValueKind): Boolean; inline;
  public
    // core
    function Kind: TJsValueKind; inline;
    // validity dual-track per INV-7: bulk zero barrier vs strong acquire
    function IsValid: Boolean; inline; // bulk: FValid only, zero atomic, thread-affine hot bulk
    function IsAlive: Boolean; inline; // strong: FValid + acquire GPureClosed via lifecycle
    function IsClosed: Boolean; inline; // strong explicit closed via acquire
    // type checks: thin via IsKind single source, inline
    function IsUndefined: Boolean; inline;
    function IsNull: Boolean; inline;
    function IsBool: Boolean; inline;
    function IsNumber: Boolean; inline;
    function IsInteger: Boolean; inline;
    function IsString: Boolean; inline;
    function IsObject: Boolean; inline;
    function IsArray: Boolean; inline;
    function IsFunction: Boolean; inline;
    function IsError: Boolean; inline;
    function IsPromise: Boolean; inline;
    function IsSymbol: Boolean; inline;
    function IsBigInt: Boolean; inline;
    // accessors: inline zero-copy via hosted FStrVal single source
    function AsBool: Boolean; inline;
    function AsInt: Int64; inline;
    function AsDouble: Double; inline;
    function AsString: string; inline;
    function AsJson: string; inline;
    function TryAsBool(out V: Boolean): Boolean;
    function TryAsDouble(out V: Double): Boolean;
    function TryAsString(out V: string): Boolean;
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
// Context 寿命：状态下沉 js.lifecycle，经 pure.base 透出
function JsValueBindContext(const AValue: TJsValue; AContextId: UInt64): TJsValue; inline;
implementation
// intf 薄层：零可变全局，四件套，L0-L3 单向，状态下沉 lifecycle
uses
  nextpas.core.bytes.ops,
  nextpas.core.js.pure.value,
  nextpas.core.js.pure.base;
function JsValueBindContext(const AValue: TJsValue; AContextId: UInt64): TJsValue; inline;
begin
  Result := AValue;
  Result.FContextId := AContextId;
end;
function JsUndefinedValue: TJsValue; begin Result.FKind:=jskUndefined; Result.FValid:=True; Result.FBoolVal:=False; Result.FIntVal:=0; Result.FDoubleVal:=0.0; Result.FStrVal:=''; Result.FContextId:=0; end;
function JsNullValue: TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskNull; end;
function JsBoolValue(AValue: Boolean): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskBoolean; Result.FBoolVal:=AValue; end;
function JsIntValue(AValue: Int64): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskInteger; Result.FIntVal:=AValue; Result.FDoubleVal:=Double(AValue); end;
function JsDoubleValue(AValue: Double): TJsValue; inline; begin Result:=JsUndefinedValue; Result.FKind:=jskNumber; Result.FDoubleVal:=AValue; end;
function JsStringValue(const AValue: string): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskString; Result.FStrVal:=AValue; end;
function JsStringViewValue(const AData: PAnsiChar; ALen: SizeUInt): TJsValue; inline;
begin
  // inline single-copy via bytes.ops SpanToString single source (BytesCopy Move, one allocation, zero dangling per CONTRACT §3.1)
  // perf: one heap alloc at creation (B/op=1 for NewStringView), AsString fast path B/op=0 via hosted FStrVal single source inline zero-copy
  // note: true zero-copy view would dangle if AData is stack/temp; single-copy keeps heaptrc 0 and B/op baseline honest (bench_value AsString B/op=0, NewStringView B/op=1)
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
// INV-7 dual-track: bulk IsValid zero barrier vs strong IsAlive/IsClosed via lifecycle acquire per CONTRACT §6
{ TJsValue - core }

function TJsValue.Kind: TJsValueKind; inline;
begin
  Result := FKind;
end;

function TJsValue.IsKind(AKind: TJsValueKind): Boolean; inline;
begin
  Result := FKind = AKind;
end;

function TJsValue.IsKindIn(A, B: TJsValueKind): Boolean; inline;
begin
  Result := (FKind = A) or (FKind = B);
end;

{ TJsValue - validity dual-track per INV-7 }

function TJsValue.IsValid: Boolean; inline;
begin
  // bulk zero barrier: FValid only, zero atomic, thread-affine hot bulk (zero fence, no cache coherence miss)
  // perf: inline single branch, no atomic_load, B/op=0 bulk
  Result := FValid;
end;

function TJsValue.IsAlive: Boolean; inline;
begin
  // strong: FValid + acquire GPureClosed compact 4B epoch*2+closed via lifecycle single source (atomic_load mo_acquire)
  // perf: inline acquire single bounds check via GPureClosedLen + generation mismatch => closed per INV-7
  Result := FValid and not JsPureContextIsClosed(FContextId);
end;

function TJsValue.IsClosed: Boolean; inline;
begin
  // strong explicit closed via acquire single source, generation mismatch => closed
  Result := FValid and JsPureContextIsClosed(FContextId);
end;

function TJsValue.IsUndefined: Boolean; inline;
begin
  Result := IsKind(jskUndefined);
end;

function TJsValue.IsNull: Boolean; inline;
begin
  Result := IsKind(jskNull);
end;

function TJsValue.IsBool: Boolean; inline;
begin
  Result := IsKind(jskBoolean);
end;

function TJsValue.IsNumber: Boolean; inline;
begin
  Result := IsKindIn(jskNumber, jskInteger);
end;

function TJsValue.IsInteger: Boolean; inline;
begin
  Result := IsKind(jskInteger);
end;

function TJsValue.IsString: Boolean; inline;
begin
  Result := IsKind(jskString);
end;

function TJsValue.IsObject: Boolean; inline;
begin
  Result := IsKind(jskObject);
end;

function TJsValue.IsArray: Boolean; inline;
begin
  Result := IsKind(jskArray);
end;

function TJsValue.IsFunction: Boolean; inline;
begin
  Result := IsKind(jskFunction);
end;

function TJsValue.IsError: Boolean; inline;
begin
  Result := IsKind(jskError);
end;

function TJsValue.IsPromise: Boolean; inline;
begin
  Result := IsKind(jskPromise);
end;

function TJsValue.IsSymbol: Boolean; inline;
begin
  Result := IsKind(jskSymbol);
end;

function TJsValue.IsBigInt: Boolean; inline;
begin
  Result := IsKind(jskBigInt);
end;
function TJsValue.AsBool: Boolean; begin if FKind<>jskBoolean then Exit(False); Result:=FBoolVal; end;
function TJsValue.AsInt: Int64; begin if (FKind=jskNumber) or (FKind=jskInteger) then Exit(FIntVal) else if FKind=jskBigInt then Exit(FIntVal) else Exit(0); Result:=FIntVal; end;
function TJsValue.AsDouble: Double; begin if (FKind=jskNumber) or (FKind=jskInteger) then Exit(FDoubleVal) else Exit(0.0); Result:=FDoubleVal; end;
function TJsValue.AsString: string; inline;
begin
  // inline zero-copy via hosted FStrVal, single source at creation
  if FKind=jskSymbol then Exit(FStrVal);
  if FKind<>jskString then Exit('');
  Result:=FStrVal;
end;
function TJsValue.AsJson: string; inline;
begin
  // inline thin-forward to pure.value single source via BytesCopy
  Result := JsPureToJsonString(Self);
end;
function TJsValue.TryAsBool(out V: Boolean): Boolean; begin Result:=FKind=jskBoolean; if Result then V:=FBoolVal else V:=False; end;
function TJsValue.TryAsDouble(out V: Double): Boolean; begin Result:=(FKind=jskNumber) or (FKind=jskInteger); if Result then V:=FDoubleVal else V:=0.0; end;
function TJsValue.TryAsString(out V: string): Boolean; begin
  Result:=FKind=jskString;
  if Result then V:=FStrVal else V:='';
end;
end.
