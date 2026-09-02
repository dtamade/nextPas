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
    FViewData: PAnsiChar;
    FViewLen: SizeUInt;
    function IsKind(AKind: TJsValueKind): Boolean; inline;
    function IsKindIn(A, B: TJsValueKind): Boolean; inline;
  public
    // core
    function Kind: TJsValueKind; inline;
    // validity dual-track per INV-7: bulk zero barrier vs strong acquire
    function IsValid: Boolean; inline; // bulk: FValid only, zero atomic, thread-affine hot bulk
    function IsAlive: Boolean; // strong: FValid + acquire GPureClosed via lifecycle, not inline per red-line 2
    function IsClosed: Boolean; // strong explicit closed via acquire, not inline per red-line 2
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
    // accessors: inline zero-copy via hosted FStrVal / view single source (bytes.ops)
    function AsBool: Boolean; inline;
    function AsInt: Int64; inline;
    function AsDouble: Double; inline;
    function AsString: string; // not inline per red-line 2 (branch+SpanToString alloc), lazy cache B/op=0 repeat
    function AsJson: string; inline;
    function TryAsBool(out V: Boolean): Boolean;
    function TryAsDouble(out V: Double): Boolean;
    function TryAsString(out V: string): Boolean;
    // view — zero-copy extent via bytes.ops TByteSpan single source, inline, B/op=0 at view creation
    function IsStringView: Boolean; inline;
    function AsViewLen: SizeUInt; inline;
    function TryGetView(out AData: PAnsiChar; out ALen: SizeUInt): Boolean; inline;
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
// Context 寿命：状态下沉 js.lifecycle single source
function JsValueBindContext(const AValue: TJsValue; AContextId: UInt64): TJsValue; inline;
implementation
// intf 薄层：零可变全局，四件套，L0-L3 单向，状态下沉 lifecycle single source via js.lifecycle
uses
  nextpas.core.bytes.ops,
  nextpas.core.js.pure.value,
  nextpas.core.js.lifecycle;
function JsValueBindContext(const AValue: TJsValue; AContextId: UInt64): TJsValue; inline;
begin
  Result := AValue;
  Result.FContextId := AContextId;
end;
function JsUndefinedValue: TJsValue; begin Result.FKind:=jskUndefined; Result.FValid:=True; Result.FBoolVal:=False; Result.FIntVal:=0; Result.FDoubleVal:=0.0; Result.FStrVal:=''; Result.FContextId:=0; Result.FViewData:=nil; Result.FViewLen:=0; end;
function JsNullValue: TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskNull; end;
function JsBoolValue(AValue: Boolean): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskBoolean; Result.FBoolVal:=AValue; end;
function JsIntValue(AValue: Int64): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskInteger; Result.FIntVal:=AValue; Result.FDoubleVal:=Double(AValue); end;
function JsDoubleValue(AValue: Double): TJsValue; inline; begin Result:=JsUndefinedValue; Result.FKind:=jskNumber; Result.FDoubleVal:=AValue; end;
function JsStringValue(const AValue: string): TJsValue; begin Result:=JsUndefinedValue; Result.FKind:=jskString; Result.FStrVal:=AValue; end;
function JsStringViewValue(const AData: PAnsiChar; ALen: SizeUInt): TJsValue; inline;
begin
  // perf: inline zero-copy view via bytes.ops TByteSpan single source, B/op=0 at creation (no heap alloc, no Move), AsString materializes lazily via SpanToString single source
  // single source: view extent via TByteSpan.Create(PByte+Len) zero-copy, owner bytes.ops, L0-L3 kept, four-piece intact
  // stability: view borrows caller's buffer (Eval/Host hot path zero-copy pass-through); caller must keep buffer alive until AsString/TryAsString materializes; empty nil/0 fast path via JsStringValue('')
  // resource: no allocation, no try-finally, FStrVal stays '' until lazy materialize, heaptrc 0 for NewStringView creation
  if (AData=nil) or (ALen=0) then Result:=JsStringValue('')
  else begin Result:=JsUndefinedValue; Result.FKind:=jskString; Result.FStrVal:=''; Result.FViewData:=AData; Result.FViewLen:=ALen; end;
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

function TJsValue.IsAlive: Boolean;
begin
  // not inline per red-line 2 (branch+atomic acquire via js.lifecycle single source, I-Cache avoid)
  // perf: single acquire via GPureClosed compact 4B epoch*2+closed (atomic_load mo_acquire) single source via js.lifecycle, bulk IsValid zero barrier kept, inline zero-copy acquire
  Result := FValid and not JsPureContextIsClosed(FContextId);
end;

function TJsValue.IsClosed: Boolean;
begin
  // not inline per red-line 2 (branch+atomic acquire, I-Cache avoid)
  // perf: single acquire via js.lifecycle single source, generation mismatch => closed, inline zero-copy
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
function TJsValue.AsString: string;
begin
  // not inline per red-line 2 (branch+SpanToString alloc would bloat I-Cache if inlined)
  // perf: single source via bytes.ops SpanToString (SetString+Move single source), zero-copy view extent, bytes.ops single source, L0-L3 kept
  // cache: first materialize lazily via SpanToString single Move, repeat B/op=0 via FStrVal cache (hosted path), view borrow zero-copy, resource not丢
  if FKind=jskSymbol then Exit(FStrVal);
  if FKind<>jskString then Exit('');
  if FViewLen > 0 then
  begin
    if Length(FStrVal) <> 0 then Exit(FStrVal);
    FStrVal := SpanToString(TByteSpan.Create(PByte(FViewData), FViewLen));
    Result := FStrVal;
    Exit;
  end;
  Result:=FStrVal;
end;

function TJsValue.IsStringView: Boolean; inline;
begin
  // perf: inline single branch, zero-copy view check, B/op=0
  Result := (FKind = jskString) and (FViewLen > 0) and (FViewData <> nil);
end;

function TJsValue.AsViewLen: SizeUInt; inline;
begin
  if FViewLen > 0 then Result := FViewLen else Result := SizeUInt(Length(FStrVal));
end;

function TJsValue.TryGetView(out AData: PAnsiChar; out ALen: SizeUInt): Boolean; inline;
begin
  // perf: inline zero-copy view extent, bytes.ops single source via TByteSpan, no alloc, B/op=0
  if (FKind <> jskString) then begin AData:=nil; ALen:=0; Exit(False); end;
  if FViewLen > 0 then begin AData:=FViewData; ALen:=FViewLen; Exit(True); end;
  if Length(FStrVal) > 0 then begin AData:=PAnsiChar(FStrVal); ALen:=SizeUInt(Length(FStrVal)); Exit(True); end;
  AData:=nil; ALen:=0; Result:=False;
end;
function TJsValue.AsJson: string; inline;
begin
  // inline thin-forward to pure.value single source via BytesCopy
  Result := JsPureToJsonString(Self);
end;
function TJsValue.TryAsBool(out V: Boolean): Boolean; begin Result:=FKind=jskBoolean; if Result then V:=FBoolVal else V:=False; end;
function TJsValue.TryAsDouble(out V: Double): Boolean; begin Result:=(FKind=jskNumber) or (FKind=jskInteger); if Result then V:=FDoubleVal else V:=0.0; end;
function TJsValue.TryAsString(out V: string): Boolean; begin
  // not inline per red-line 2 (branch+SpanToString alloc, I-Cache avoid); cache B/op=0 repeat via FStrVal single source
  // perf: single source via bytes.ops SpanToString, zero-copy view extent, lazy cache into FStrVal for AsString/TryAsString shared B/op=0 repeat, resource not丢
  Result:=FKind=jskString;
  if Result then
  begin
    if FViewLen > 0 then
    begin
      if Length(FStrVal) <> 0 then V:=FStrVal
      else begin V:=SpanToString(TByteSpan.Create(PByte(FViewData), FViewLen)); FStrVal:=V; end;
    end else V:=FStrVal;
  end else V:='';
end;
end.
