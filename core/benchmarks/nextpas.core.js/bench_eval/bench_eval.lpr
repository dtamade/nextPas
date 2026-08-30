program bench_eval;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.json, nextpas.core.time.base,
  nextpas.core.fs, nextpas.core.js.base, nextpas.core.js.intf, nextpas.core.js;
var GCounter: UInt64; GRuntime: IJsRuntime; GCtx: IJsContext;
function HostNoop(ACtx: IJsContext; AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
begin Result := JsIntValue(1); end;
procedure BenchEvalSmall(const ACtx: IBenchContext);
var V: TJsValue; begin V := GCtx.Eval('1+2'); GCounter := GCounter xor UInt64(V.AsInt); end;
procedure BenchEvalHostCall(const ACtx: IBenchContext);
var V: TJsValue; begin V := GCtx.Eval('noop("x")'); GCounter := GCounter xor UInt64(V.AsInt); end;
procedure BenchJsonInterop(const ACtx: IBenchContext);
var V: TJsValue; Doc: IJsonDocument; begin V := GCtx.Eval('JSON.stringify({x:1})'); Doc := JsonParse(V.AsString); GCounter := GCounter xor UInt64(Doc.Root.ObjectGet('x').AsInt); end;
procedure BenchValueOps(const ACtx: IBenchContext);
var V: TJsValue; begin V := GCtx.NewInt(42); GCounter := GCounter xor UInt64(V.AsInt); V := GCtx.NewString('hello'); GCounter := GCounter xor UInt64(Length(V.AsString)); end;
procedure RunForBackend(AKind: TJsBackendKind; const ALabel: string);
var LResults: IBenchResults; LFile: string;
begin
  if not JsBackendAvailable(AKind) then
  begin WriteLn('[bench] SKIP ', ALabel, ' not available (probe: ', JsBackendKindToString(AKind), ')'); Exit; end;
  GRuntime := CreateJsRuntime(AKind);
  GCtx := GRuntime.NewContext;
  GCtx.SetHostFunction('noop', @HostNoop);
  GCounter := 0;
  LResults := TBenchSuite.Create('js.eval.'+ALabel)
    .SetQuiet(True).SetMinDuration(TDuration.FromMilliseconds(50)).SetMinSamples(5)
    .Add('Eval/small', @BenchEvalSmall).Add('Eval/host', @BenchEvalHostCall)
    .Add('JSON/interop', @BenchJsonInterop).Add('Value/ops', @BenchValueOps).Run;
  WriteLn('=== ', ALabel, ' ===');
  WriteLn(LResults.PrintToConsole);
  LFile := 'build/bench-eval-'+ALabel+'.json';
  ForceDirectories('build');
  LResults.SaveToJSON(LFile);
  WriteLn('counter=', GCounter, ' file=', LFile);
end;
begin
  RunForBackend(jsbkFake, 'fake');
  RunForBackend(jsbkJs888, 'js888');
  RunForBackend(jsbkQuickJs, 'quickjs');
end.
