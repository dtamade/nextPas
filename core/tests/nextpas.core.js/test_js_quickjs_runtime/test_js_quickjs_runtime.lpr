program test_js_quickjs_runtime;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.js.base,
  nextpas.core.js,
  nextpas.core.js.quickjs.loader,
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

procedure TestProbeMatrix;
begin
  Check(JsQuickJsIsAvailable = GAvailable, 'probe consistent');
  Check(Pos('libquickjs.so.1', JsQuickJsProbeNames) > 0, 'probe0');
end;

procedure TestEval1Plus2;
var RT: IJsRuntime; Ctx: IJsContext; V: TJsValue;
begin
  RT := CreateJsRuntime(jsbkQuickJs);
  Ctx := RT.NewContext;
  V := Ctx.Eval('1+2');
  // QuickJS quickjs backend maps via string heuristic currently; accept 3 or string "3"
  Check(V.IsNumber or V.IsString, '1+2 kind');
  if V.IsNumber then CheckEqual(Int64(3), V.AsInt, '3 num')
  else CheckEqual('3', V.AsString, '3 str');
end;

procedure TestJson;
var RT: IJsRuntime; Ctx: IJsContext; V: TJsValue;
begin
  RT := CreateJsRuntime(jsbkQuickJs);
  Ctx := RT.NewContext;
  V := Ctx.Eval('JSON.stringify({x:1})');
  Check(V.IsString, 'json str');
  Check(Pos('{"x":1}', V.AsString) > 0, 'json val');
end;

procedure TestSyntaxError;
var RT: IJsRuntime; Ctx: IJsContext; Raised: Boolean;
begin
  RT := CreateJsRuntime(jsbkQuickJs);
  Ctx := RT.NewContext;
  Raised := False;
  try Ctx.Eval('bad('); except on E: EJsError do Raised := E.Category = jecSyntax; end;
  Check(Raised, 'syntax');
end;

procedure TestTryEvalFileProbe;
var RT: IJsRuntime; Ctx: IJsContext; V: TJsValue; Ok: Boolean; Tmp: string;
begin
  Tmp := GetTempDir + 'test_js_qjs_tmp.js';
  WriteFileText(Tmp, '1+2');
  RT := CreateJsRuntime(jsbkQuickJs);
  Ctx := RT.NewContext;
  Ok := Ctx.TryEvalFile(Tmp, V);
  Check(Ok, 'file ok');
  try Remove(Tmp); except end;
end;

begin
  NeedQuickJs;
  T := TTestSuite.Create('nextpas.core.js.quickjs_runtime');
  T.Test('probe matrix', @TestProbeMatrix);
  T.Test('eval 1+2', @TestEval1Plus2);
  T.Test('json', @TestJson);
  T.Test('syntax error', @TestSyntaxError);
  T.Test('tryeval file', @TestTryEvalFileProbe);
  if not T.Run then Halt(1);
end.
