unit nextpas.core.js.intf;
{**
 * @desc JS 抽象接口与值语义（后端无关，不透明句柄）。
 * @note TJsValue 为 16B 以内不透明句柄，寿命绑所属 IJsContext。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.js.base,
  nextpas.core.json;

type
  IJsRuntime = interface;
  IJsContext = interface;

  {** TJsValue 不透明轻量句柄（≤16B，零接口开销）。}
  TJsValue = record
  private
    FKind: TJsValueKind;
    FValid: Boolean;
    FBoolVal: Boolean;
    FIntVal: Int64;
    FDoubleVal: Double;
    FStrVal: string;
    FContextId: UInt64;
  public
    function Kind: TJsValueKind; inline;
    function IsValid: Boolean; inline;
    function IsUndefined: Boolean; inline;
    function IsNull: Boolean; inline;
    function IsBool: Boolean; inline;
    function IsNumber: Boolean; inline;
    function IsString: Boolean; inline;
    function IsObject: Boolean; inline;
    function IsArray: Boolean; inline;
    function IsFunction: Boolean; inline;
    function IsError: Boolean; inline;
    function IsPromise: Boolean; inline;
    function AsBool: Boolean; inline;
    function AsInt: Int64; inline;
    function AsDouble: Double; inline;
    function AsString: string; inline;
    function AsJson: string;
    function TryAsBool(out V: Boolean): Boolean;
    function TryAsDouble(out V: Double): Boolean;
    function TryAsString(out V: string): Boolean;
  end;

  IJsValueRef = interface
    ['{A7B2C9E1-4F8D-4A1E-9C3B-5D7E8F1A2B3C}']
    function Value: TJsValue;
  end;

  TJsHostFunction = reference to function(ACtx: IJsContext; AThis: TJsValue;
    const AArgs: array of TJsValue): TJsValue;
  TJsHostMethod = function(ACtx: IJsContext; AThis: TJsValue;
    const AArgs: array of TJsValue): TJsValue of object;
  TJsHostProc = function(ACtx: IJsContext; AThis: TJsValue;
    const AArgs: array of TJsValue): TJsValue;

  IJsRuntime = interface
    ['{B1C2D3E4-F5A6-7890-ABCD-EF1234567890}']
    function Kind: TJsBackendKind;
    function Options: TJsRuntimeOptions;
    function NewContext: IJsContext;
    procedure SetMemoryLimit(ALimit: SizeUInt);
    procedure SetTimeout(ATimeoutMs: Integer);
    procedure CollectGarbage;
  end;

  IJsContext = interface
    ['{C2D3E4F5-A6B7-8901-BCDE-F12345678901}']
    function Runtime: IJsRuntime;
    function Eval(const ACode: string; const AFileName: string = ''): TJsValue;
    function TryEval(const ACode: string; out AValue: TJsValue): Boolean;
    function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
    function Global: TJsValue;
    function NewString(const AStr: string): TJsValue;
    function NewInt(AValue: Int64): TJsValue;
    function NewDouble(AValue: Double): TJsValue;
    function NewBool(AValue: Boolean): TJsValue;
    function NewObject: TJsValue;
    function NewArray: TJsValue;
    function NewJson(const AJson: TJsonValue): TJsValue;
    function ToJson(const AValue: TJsValue): IJsonDocument;
    function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
    procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
    function Call(const AFunc: TJsValue; const AThis: TJsValue;
      const AArgs: array of TJsValue): TJsValue;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
    procedure RemoveHostFunction(const AName: string);
    procedure Tick;
    procedure CollectGarbage;
    function IsClosed: Boolean;
  end;

function JsUndefinedValue: TJsValue; inline;
function JsNullValue: TJsValue; inline;
function JsBoolValue(AValue: Boolean): TJsValue; inline;
function JsIntValue(AValue: Int64): TJsValue; inline;
function JsDoubleValue(AValue: Double): TJsValue; inline;
function JsStringValue(const AValue: string): TJsValue; inline;
function JsObjectValue: TJsValue; inline;
function JsArrayValue: TJsValue; inline;

implementation

uses
  nextpas.core.base;

function JsUndefinedValue: TJsValue;
begin
  Result.FKind := jskUndefined;
  Result.FValid := True;
  Result.FBoolVal := False;
  Result.FIntVal := 0;
  Result.FDoubleVal := 0.0;
  Result.FStrVal := '';
  Result.FContextId := 0;
end;

function JsNullValue: TJsValue;
begin
  Result := JsUndefinedValue;
  Result.FKind := jskNull;
end;

function JsBoolValue(AValue: Boolean): TJsValue;
begin
  Result := JsUndefinedValue;
  Result.FKind := jskBoolean;
  Result.FBoolVal := AValue;
end;

function JsIntValue(AValue: Int64): TJsValue;
begin
  Result := JsUndefinedValue;
  Result.FKind := jskNumber;
  Result.FIntVal := AValue;
  Result.FDoubleVal := Double(AValue);
end;

function JsDoubleValue(AValue: Double): TJsValue;
begin
  Result := JsUndefinedValue;
  Result.FKind := jskNumber;
  Result.FDoubleVal := AValue;
  Result.FIntVal := Int64(Trunc(AValue));
end;

function JsStringValue(const AValue: string): TJsValue;
begin
  Result := JsUndefinedValue;
  Result.FKind := jskString;
  Result.FStrVal := AValue;
end;

function JsObjectValue: TJsValue;
begin
  Result := JsUndefinedValue;
  Result.FKind := jskObject;
end;

function JsArrayValue: TJsValue;
begin
  Result := JsUndefinedValue;
  Result.FKind := jskArray;
end;

{ TJsValue }

function TJsValue.Kind: TJsValueKind;
begin
  if not FValid then
    Result := jskUndefined
  else
    Result := FKind;
end;

function TJsValue.IsValid: Boolean;
begin
  Result := FValid;
end;

function TJsValue.IsUndefined: Boolean;
begin
  Result := Kind = jskUndefined;
end;

function TJsValue.IsNull: Boolean;
begin
  Result := Kind = jskNull;
end;

function TJsValue.IsBool: Boolean;
begin
  Result := Kind = jskBoolean;
end;

function TJsValue.IsNumber: Boolean;
begin
  Result := Kind = jskNumber;
end;

function TJsValue.IsString: Boolean;
begin
  Result := Kind = jskString;
end;

function TJsValue.IsObject: Boolean;
begin
  Result := Kind = jskObject;
end;

function TJsValue.IsArray: Boolean;
begin
  Result := Kind = jskArray;
end;

function TJsValue.IsFunction: Boolean;
begin
  Result := Kind = jskFunction;
end;

function TJsValue.IsError: Boolean;
begin
  Result := Kind = jskError;
end;

function TJsValue.IsPromise: Boolean;
begin
  Result := Kind = jskPromise;
end;

function TJsValue.AsBool: Boolean;
begin
  if Kind <> jskBoolean then
    Exit(False);
  Result := FBoolVal;
end;

function TJsValue.AsInt: Int64;
begin
  if Kind <> jskNumber then
    Exit(0);
  Result := FIntVal;
end;

function TJsValue.AsDouble: Double;
begin
  if Kind <> jskNumber then
    Exit(0.0);
  Result := FDoubleVal;
end;

function TJsValue.AsString: string;
begin
  if Kind <> jskString then
    Exit('');
  Result := FStrVal;
end;

function TJsValue.AsJson: string;
begin
  case Kind of
    jskUndefined: Result := 'undefined';
    jskNull: Result := 'null';
    jskBoolean:
      if FBoolVal then Result := 'true' else Result := 'false';
    jskNumber:
      Result := nextpas.core.base.IntToStr(FIntVal);
    jskString:
      Result := '"' + FStrVal + '"';
  else
    Result := '';
  end;
end;

function TJsValue.TryAsBool(out V: Boolean): Boolean;
begin
  Result := Kind = jskBoolean;
  if Result then
    V := FBoolVal
  else
    V := False;
end;

function TJsValue.TryAsDouble(out V: Double): Boolean;
begin
  Result := Kind = jskNumber;
  if Result then
    V := FDoubleVal
  else
    V := 0.0;
end;

function TJsValue.TryAsString(out V: string): Boolean;
begin
  Result := Kind = jskString;
  if Result then
    V := FStrVal
  else
    V := '';
end;

end.
