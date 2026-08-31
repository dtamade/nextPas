program demo_js;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.json,
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js;

function HostHello(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
begin
  Result := ACtx.NewString('hello from host');
end;

var
  RT: IJsRuntime;
  Ctx: IJsContext;
  V: TJsValue;
  Doc: IJsonDocument;
  Backend: TJsBackendKind;
begin
  // 一行切换后端：jsbkFake（CI 恒绿） / jsbkQuickJs（本地有 libquickjs 时） / jsbkJs888（未来纯）
  Backend := jsbkFake;
  WriteLn('backend: ', JsBackendKindToString(Backend), ' available=', JsBackendAvailable(Backend));

  RT := CreateJsRuntime(Backend);
  Ctx := RT.NewContext;

  // 1+2
  V := Ctx.Eval('1+2');
  WriteLn('1+2 = ', V.AsInt);

  // echo
  Ctx.SetHostFunction('hello', @HostHello);
  V := Ctx.Eval('hello()');
  WriteLn('hello() = ', V.AsString);

  // JSON 互通
  Doc := JsonParse('{"x":1}');
  V := Ctx.NewJson(Doc.Root);
  WriteLn('NewJson kind=', JsValueKindToString(V.Kind));
  V := Ctx.Eval('JSON.stringify({x:1})');
  WriteLn('JSON.stringify = ', V.AsString);

  // TryEvalFile 演示（可选）
  WriteLn('demo done');
end.
