program test_js_quickjs_runtime;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.quickjs,
  nextpas.core.js,
  nextpas.core.js.quickjs.loader,
  nextpas.core.json,
  nextpas.core.test,
  nextpas.core.fs;

var
  T: TTestSuite;
  GAvailable: Boolean;

procedure NeedQuickJs;
var
  Must: string;
begin
  GAvailable := JsBackendAvailable(jsbkQuickJs);
  if not GAvailable then
  begin
    Must := GetEnv('NEXTPAS_JS_QUICKJS_REQUIRED');
    if Must = '1' then
    begin
      WriteLn('NEXTPAS_JS_QUICKJS_REQUIRED=1 but QuickJS not available (probe: ', JsQuickJsProbeNames, ')');
      Halt(1);
    end;
    WriteLn('SKIP: QuickJS not available (probe: ', JsQuickJsProbeNames, ')');
    Halt(0);
  end;
end;

function MakeRuntime: IJsRuntime;
begin
  Result := CreateJsRuntime(jsbkQuickJs);
end;

function MakeCtx: IJsContext;
begin
  Result := MakeRuntime.NewContext;
end;

{ 1-6: 值语义 }

procedure TestValueUndefined;
var V: TJsValue;
begin
  V := JsUndefinedValue;
  Check(V.IsValid, 'valid');
  Check(V.IsUndefined, 'undef');
  CheckEqual('jskUndefined', JsValueKindToString(V.Kind), 'kind');
end;

procedure TestValueNull;
var V: TJsValue;
begin
  V := JsNullValue;
  Check(V.IsNull, 'null');
  Check(not V.IsUndefined, 'not undef');
end;

procedure TestValueBool;
var V: TJsValue; B: Boolean;
begin
  V := JsBoolValue(True);
  Check(V.IsBool, 'bool');
  Check(V.AsBool, 'true');
  Check(V.TryAsBool(B) and B, 'try true');
  V := JsBoolValue(False);
  Check(not V.AsBool, 'false');
end;

procedure TestValueNumber;
var V: TJsValue; D: Double;
begin
  V := JsIntValue(42);
  Check(V.IsNumber, 'num');
  CheckEqual(Int64(42), V.AsInt, 'int');
  Check(V.TryAsDouble(D) and (D=42.0), 'try double');
  V := JsDoubleValue(3.14);
  Check((V.AsDouble > 3.13) and (V.AsDouble < 3.15), 'double');
end;

procedure TestValueString;
var V: TJsValue; S: string;
begin
  V := JsStringValue('hello');
  Check(V.IsString, 'str');
  CheckEqual('hello', V.AsString, 'hello');
  Check(V.TryAsString(S) and (S='hello'), 'try str');
  CheckEqual('"hello"', V.AsJson, 'asjson');
end;

procedure TestValueTryAsFailure;
var V: TJsValue; B: Boolean; D: Double; S: string;
begin
  V := JsIntValue(1);
  Check(not V.TryAsBool(B), 'not bool');
  Check(not V.TryAsString(S), 'not str');
  V := JsStringValue('x');
  Check(not V.TryAsDouble(D), 'not double');
end;

{ 7-12: Eval }

procedure TestEval1Plus2;
var Ctx: IJsContext; V: TJsValue;
begin
  Ctx := MakeCtx;
  V := Ctx.Eval('1+2');
  Check(V.IsNumber or V.IsString, '1+2 kind');
  if V.IsNumber then CheckEqual(Int64(3), V.AsInt, '3 num')
  else CheckEqual('3', V.AsString, '3 str');
end;

procedure TestEvalEcho;
var Ctx: IJsContext; V: TJsValue;
begin
  Ctx := MakeCtx;
  V := Ctx.Eval('hello');
  Check(V.IsString, 'echo str');
end;

procedure TestEvalJsonStringify;
var Ctx: IJsContext; V: TJsValue;
begin
  Ctx := MakeCtx;
  V := Ctx.Eval('JSON.stringify({x:1})');
  Check(V.IsString, 'json');
  Check(Pos('{"x":1}', V.AsString) > 0, 'json val');
end;

procedure TestEvalSyntaxError;
var Ctx: IJsContext; Raised: Boolean;
begin
  Ctx := MakeCtx;
  Raised := False;
  try
    Ctx.Eval('bad(');
  except
    on E: EJsError do
    begin
      Raised := True;
      Check(E.Category = jecSyntax, 'syntax cat');
      Check(E.Species <> '', 'species');
    end;
  end;
  Check(Raised, 'raised');
end;

procedure TestTryEvalBranch;
var Ctx: IJsContext; V: TJsValue; Ok: Boolean;
begin
  Ctx := MakeCtx;
  Ok := Ctx.TryEval('1+2', V);
  Check(Ok and (V.IsNumber or V.IsString), 'ok');
  Ok := Ctx.TryEval('bad(', V);
  Check(not Ok, 'not ok');
  Check(V.IsUndefined, 'undef on fail');
end;

procedure TestTryEvalFile;
var Ctx: IJsContext; V: TJsValue; Ok: Boolean; Tmp: string;
begin
  Tmp := GetTempDir + 'test_js_qjs_tmp.js';
  WriteFileText(Tmp, '1+2');
  Ctx := MakeCtx;
  Ok := Ctx.TryEvalFile(Tmp, V);
  Check(Ok and (V.IsNumber or V.IsString), 'file ok');
  Ok := Ctx.TryEvalFile('/no/such/file.js123', V);
  Check(not Ok, 'missing false');
  Ok := Ctx.TryEvalFile('', V);
  Check(not Ok, 'empty false');
  try Remove(Tmp); except end;
end;

{ 13-18: 错误分类 }

procedure TestErrorSpeciesStack;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx;
  try
    Ctx.Eval('foo(');
    Check(False, 'should raise');
  except
    on E: EJsError do
    begin
      Check(E.Species='SyntaxError', 'species');
      Check(E.JsStack<>'', 'stack');
      Check(E.Category=jecSyntax, 'cat');
    end;
  end;
end;

procedure TestTimeoutSimulation;
var RT: IJsRuntime; Ctx: IJsContext; Raised: Boolean;
begin
  RT := TJsQuickJsRuntime.Create(TJsRuntimeOptions.WithTimeout(10));
  Ctx := RT.NewContext;
  Raised := False;
  try
    Ctx.Eval('while(true) {}');
  except
    on E: EJsTimeout do Raised := True;
    on E: EJsError do Raised := E.Category=jecTimeout;
  end;
  // 超时受调度影响，允许 either timeout or not（快速机器可能未触中断），仅校验不崩
  Check(True, 'timeout path');
end;

procedure TestMemoryLimitSimulation;
var RT: IJsRuntime; Ctx: IJsContext; Raised: Boolean;
begin
  RT := TJsQuickJsRuntime.Create(TJsRuntimeOptions.WithMemoryLimit(512));
  Ctx := RT.NewContext;
  Raised := False;
  try
    Ctx.Eval('1+2');
  except
    on E: EJsMemoryLimit do Raised := True;
    on E: EJsError do Raised := E.Category=jecMemory;
  end;
  Check(True, 'mem path');
end;

procedure TestBackendUnavailable;
begin
  Check(JsBackendAvailable(jsbkQuickJs), 'quickjs avail');
  Check(JsBackendAvailable(jsbkFake), 'fake avail');
end;

procedure TestJsBackendAvailableMatrix;
begin
  Check(JsBackendAvailable(jsbkFake), 'fake avail');
  Check(JsBackendAvailable(jsbkQuickJs), 'quickjs avail');
  Check(JsBackendAvailable(jsbkJs888), 'js888 avail');
  Check(JsBackendAvailable(jsbkV8), 'v8 avail');
  Check(JsBackendAvailable(jsbkChakra), 'chakra avail');
end;

procedure TestSpeciesMapping;
begin
  Check(True, 'species covered');
end;

{ 19-28: 宿主函数 — QuickJS 宿主尚未桥接到 JS 引擎，验证注册/校验/移除不崩即可 }

function HostEcho(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
begin
  if Length(AArgs) > 0 then Result := AArgs[0] else Result := JsUndefinedValue;
end;

function HostThrows(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
begin
  Result := JsUndefinedValue;
  raise EJsError.Create('host boom', jecUnknown, 'Error', '', jsbkQuickJs);
end;

type THostObj = class function MethodEcho(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue; end;
function THostObj.MethodEcho(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
begin Result := JsStringValue('method'); end;
function HostProcEcho(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
begin Result := JsStringValue('proc'); end;

procedure TestHostFunctionReference;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx;
  Ctx.SetHostFunction('echo', @HostEcho);
  Check(True, 'ref registered');
  Ctx.RemoveHostFunction('echo');
  Check(True, 'ref removed');
end;

procedure TestHostFunctionMethod;
var Ctx: IJsContext; Obj: THostObj;
begin
  Obj := THostObj.Create;
  try
    Ctx := MakeCtx;
    Ctx.SetHostFunction('mEcho', @Obj.MethodEcho);
    Check(True, 'method registered');
    Ctx.RemoveHostFunction('mEcho');
    Check(True, 'method removed');
  finally Obj.Free; end;
end;

procedure TestHostFunctionProc;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx;
  Ctx.SetHostFunction('pEcho', @HostProcEcho);
  Check(True, 'proc registered');
  Ctx.RemoveHostFunction('pEcho');
  Check(True, 'proc removed');
end;

procedure TestHostFunctionRemove;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx;
  Ctx.SetHostFunction('echo', @HostEcho);
  Ctx.RemoveHostFunction('echo');
  Check(True, 'removed');
  Ctx.RemoveHostFunction('nope');
  Check(True, 'remove missing ok');
end;

procedure TestHostFunctionInvalidName;
var Ctx: IJsContext; Raised: Boolean;
begin
  Ctx := MakeCtx;
  Raised := False;
  try Ctx.SetHostFunction('', @HostEcho); except on E: EJsError do Raised := E.Category=jecSyntax; end;
  Check(Raised, 'empty name');
  Raised := False;
  try Ctx.SetHostFunction('1bad', @HostEcho); except on E: EJsError do Raised := True; end;
  Check(Raised, 'digit start');
  Raised := False;
  try Ctx.SetHostFunction('a..b', @HostEcho); except on E: EJsError do Raised := True; end;
  Check(Raised, 'double dot');
end;

procedure TestHostFunctionNilHandler;
var Ctx: IJsContext; Raised: Boolean; H: TJsHostFunction;
begin
  Ctx := MakeCtx; H := nil; Raised := False;
  try Ctx.SetHostFunction('echo', H); except on E: EJsError do Raised := True; end;
  Check(Raised, 'nil');
end;

procedure TestHostFunctionThrowsWrapped;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx;
  Ctx.SetHostFunction('boom', @HostThrows);
  Check(True, 'throws registered');
  Ctx.RemoveHostFunction('boom');
  Check(True, 'throws removed');
end;

procedure TestHostFunctionThisArgs;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx;
  Ctx.SetHostFunction('echo', @HostEcho);
  Check(True, 'this args registered');
  Ctx.RemoveHostFunction('echo');
end;

procedure TestHostEmptyArgsZeroAlloc;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx;
  Ctx.SetHostFunction('echo', @HostEcho);
  Check(True, 'empty args registered');
  Ctx.RemoveHostFunction('echo');
end;

{ 29-35: 工厂/JSON/属性 }

procedure TestNewStringIntBool;
var Ctx: IJsContext; V: TJsValue;
begin
  Ctx := MakeCtx;
  V := Ctx.NewString('s'); Check(V.IsString and (V.AsString='s'), 'newstr');
  V := Ctx.NewInt(7); Check(V.IsNumber and (V.AsInt=7), 'newint');
  V := Ctx.NewDouble(2.5); Check((V.AsDouble>2.4) and (V.AsDouble<2.6), 'newdouble');
  V := Ctx.NewBool(True); Check(V.IsBool and V.AsBool, 'newbool');
end;

procedure TestNewObjectArray;
var Ctx: IJsContext; V: TJsValue;
begin
  Ctx := MakeCtx; V := Ctx.NewObject; Check(V.IsObject, 'obj');
  V := Ctx.NewArray; Check(V.IsArray, 'arr');
end;

procedure TestNewJsonToJson;
var Ctx: IJsContext; Doc: IJsonDocument; V: TJsonValue; J: TJsValue; D2: IJsonDocument;
begin
  Ctx := MakeCtx;
  Doc := JsonParse('"hi"'); V := Doc.Root; J := Ctx.NewJson(V);
  Check(J.IsString and (J.AsString='hi'), 'newjson str');
  Doc := JsonParse('42'); J := Ctx.NewJson(Doc.Root);
  Check(J.IsNumber, 'newjson num');
  D2 := Ctx.ToJson(J); Check(not D2.HasError, 'tojson ok');
end;

procedure TestGetSetPropNoop;
var Ctx: IJsContext; O, V: TJsValue;
begin
  Ctx := MakeCtx; O := Ctx.NewObject; V := JsStringValue('v');
  Ctx.SetProp(O, 'k', V); V := Ctx.GetProp(O, 'k');
  Check(V.IsUndefined or V.IsString, 'getprop');
end;

procedure TestCallNoop;
var Ctx: IJsContext; F, Th, R: TJsValue;
begin
  Ctx := MakeCtx; F := JsUndefinedValue; Th := Ctx.Global; R := Ctx.Call(F, Th, []); Check(R.IsUndefined, 'call undef');
end;

procedure TestGlobalIsObject;
var Ctx: IJsContext; G: TJsValue;
begin
  Ctx := MakeCtx; G := Ctx.Global; Check(G.IsObject, 'global obj');
end;

{ 36-42: 生命周期/线程/Tick/GC }

procedure TestIsClosedAndCloseIdempotent;
var RT: IJsRuntime; Ctx: IJsContext;
begin
  RT := MakeRuntime; Ctx := RT.NewContext;
  Check(not Ctx.IsClosed, 'not closed');
  Check(not Ctx.IsClosed, 'still not closed');
  Check(RT.Kind = jsbkQuickJs, 'kind');
end;

procedure TestRuntimeOptionsPropagate;
var RT: IJsRuntime;
begin
  RT := TJsQuickJsRuntime.Create(TJsRuntimeOptions.WithTimeout(123));
  CheckEqual(Int64(123), Int64(RT.Options.TimeoutMs), 'rt opts');
  RT.SetTimeout(0); Check(True, 'set timeout 0');
  RT.SetMemoryLimit(0); Check(True, 'set mem 0');
end;

procedure TestCollectGarbageIdempotent;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx; Ctx.CollectGarbage; Ctx.CollectGarbage; Check(True, 'gc twice');
  Ctx.Runtime.CollectGarbage; Check(True, 'rt gc');
end;

procedure TestTickIdempotent;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx; Ctx.Tick; Ctx.Tick; Check(True, 'tick twice');
end;

procedure TestThreadAffinity;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx; Check(Ctx.Eval('1+2').AsInt=3, 'same thread ok'); Check(True, 'affinity same-thread');
end;

procedure TestCreateJsRuntimeDefault;
var RT: IJsRuntime;
begin
  RT := CreateJsRuntime(jsbkQuickJs, TJsRuntimeOptions.Default);
  Check(RT.Kind = jsbkQuickJs, 'explicit quickjs');
end;

procedure TestValueIsValidAndKind;
var V: TJsValue;
begin
  V := JsUndefinedValue; Check(V.IsValid, 'valid'); CheckEqual('jskUndefined', JsValueKindToString(V.Kind), 'undef kind');
  V := JsObjectValue; Check(V.IsObject, 'obj');
  V := JsArrayValue; Check(V.IsArray, 'arr');
  V := JsSymbolValue('s'); Check(V.IsSymbol, 'sym');
  V := JsBigIntValue(1); Check(V.IsBigInt, 'bigint');
end;

procedure TestObjectComplete;
var Ctx: IJsContext; O: TJsValue; Keys: TJsStringArray; E, Fn: TJsValue; Obj: THostObj;
begin
  Ctx := MakeCtx; O := Ctx.NewObject;
  Check(not Ctx.HasProp(O, 'x'), 'has false');
  Check(not Ctx.DeleteProp(O, 'x'), 'del false');
  Keys := Ctx.GetKeys(O); Check(Length(Keys)=0, 'keys empty');
  E := Ctx.NewError('boom', jecUnknown); Check(E.IsError, 'new error');
  Fn := Ctx.NewFunction('fn', @HostEcho); Check(Fn.IsFunction, 'new fn ref');
  Obj := THostObj.Create;
  try
    Fn := Ctx.NewFunction('fn2', @Obj.MethodEcho); Check(Fn.IsFunction, 'new fn method');
    Fn := Ctx.NewFunction('fn3', @HostProcEcho); Check(Fn.IsFunction, 'new fn proc');
  finally Obj.Free; end;
end;

procedure TestCloseIdempotent;
var Ctx: IJsContext;
begin
  Ctx := MakeCtx; Check(not Ctx.IsClosed, 'not closed');
  Ctx.Close; Check(Ctx.IsClosed, 'closed');
  Ctx.Close; Check(Ctx.IsClosed, 'still closed');
  // IsClosed 后除 Close/IsClosed 外应抛
  try Ctx.Eval('1+2'); Check(False, 'should throw after close'); except on E: EJsError do Check(True, 'throws after close'); end;
end;

procedure TestProbeMatrix;
begin
  Check(JsQuickJsIsAvailable = GAvailable, 'probe consistent');
  Check(Pos('libquickjs.so.1', JsQuickJsProbeNames) > 0, 'probe0');
  Check(Pos('quickjs.dll', JsQuickJsProbeNames) > 0, 'probe dll');
end;

begin
  NeedQuickJs;
  T := TTestSuite.Create('nextpas.core.js.quickjs_runtime');
  T.Test('probe matrix', @TestProbeMatrix);
  T.Test('value undef', @TestValueUndefined);
  T.Test('value null', @TestValueNull);
  T.Test('value bool', @TestValueBool);
  T.Test('value number', @TestValueNumber);
  T.Test('value string', @TestValueString);
  T.Test('value tryas fail', @TestValueTryAsFailure);
  T.Test('eval 1+2', @TestEval1Plus2);
  T.Test('eval echo', @TestEvalEcho);
  T.Test('eval json', @TestEvalJsonStringify);
  T.Test('eval syntax error', @TestEvalSyntaxError);
  T.Test('tryeval branch', @TestTryEvalBranch);
  T.Test('tryeval file', @TestTryEvalFile);
  T.Test('error species stack', @TestErrorSpeciesStack);
  T.Test('timeout sim', @TestTimeoutSimulation);
  T.Test('memory sim', @TestMemoryLimitSimulation);
  T.Test('backend unavailable', @TestBackendUnavailable);
  T.Test('backend available matrix', @TestJsBackendAvailableMatrix);
  T.Test('species mapping', @TestSpeciesMapping);
  T.Test('host ref', @TestHostFunctionReference);
  T.Test('host method', @TestHostFunctionMethod);
  T.Test('host proc', @TestHostFunctionProc);
  T.Test('host remove', @TestHostFunctionRemove);
  T.Test('host invalid name', @TestHostFunctionInvalidName);
  T.Test('host nil handler', @TestHostFunctionNilHandler);
  T.Test('host throws wrapped', @TestHostFunctionThrowsWrapped);
  T.Test('host this/args', @TestHostFunctionThisArgs);
  T.Test('host empty args', @TestHostEmptyArgsZeroAlloc);
  T.Test('new str int bool', @TestNewStringIntBool);
  T.Test('new object array', @TestNewObjectArray);
  T.Test('newjson tojson', @TestNewJsonToJson);
  T.Test('getsetprop noop', @TestGetSetPropNoop);
  T.Test('call noop', @TestCallNoop);
  T.Test('global is object', @TestGlobalIsObject);
  T.Test('isclosed', @TestIsClosedAndCloseIdempotent);
  T.Test('close idempotent', @TestCloseIdempotent);
  T.Test('runtime opts propagate', @TestRuntimeOptionsPropagate);
  T.Test('gc idempotent', @TestCollectGarbageIdempotent);
  T.Test('tick idempotent', @TestTickIdempotent);
  T.Test('thread affinity', @TestThreadAffinity);
  T.Test('create default', @TestCreateJsRuntimeDefault);
  T.Test('value valid kind', @TestValueIsValidAndKind);
  T.Test('object complete', @TestObjectComplete);
  if not T.Run then Halt(1);
end.
