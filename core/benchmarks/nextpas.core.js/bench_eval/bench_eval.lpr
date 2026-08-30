program bench_eval;
{$I nextpas.core.settings.inc}
uses SysUtils,
  nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.json, nextpas.core.time.base,
  nextpas.core.fs, nextpas.core.js.base, nextpas.core.js.intf, nextpas.core.js,
  nextpas.core.js.quickjs.loader;
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
procedure BenchSkipped(const ACtx: IBenchContext);
begin ACtx.Skip('backend not available (probe: '+JsQuickJsProbeNames+')'); end;
procedure RunForBackend(AKind: TJsBackendKind; const ALabel: string);
var LResults: IBenchResults; LFile: string;
begin
  if not JsBackendAvailable(AKind) then
  begin
    WriteLn('[bench] SKIP ', ALabel, ' not available (probe: ', JsBackendKindToString(AKind), ')');
    GCounter := 0;
    LResults := TBenchSuite.Create('js.eval.'+ALabel)
      .SetQuiet(True).SetMinDuration(TDuration.FromMilliseconds(50)).SetMinSamples(5)
      .Add('Eval/small', @BenchSkipped).Add('Eval/host', @BenchSkipped)
      .Add('JSON/interop', @BenchSkipped).Add('Value/ops', @BenchSkipped).Run;
    WriteLn('=== ', ALabel, ' (skipped) ===');
    WriteLn(LResults.PrintToConsole);
    LFile := 'build/bench-eval-'+ALabel+'.json';
    ForceDirectories('build');
    try
      LResults.SaveToJSON(LFile);
    except
      on E: Exception do WriteLn('[bench] save failed: ', E.Message);
    end;
    WriteLn('counter=', GCounter, ' file=', LFile, ' (skipped)');
    Exit;
  end;
  GRuntime := CreateJsRuntime(AKind);
  GCtx := GRuntime.NewContext;
  try
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
    try
      LResults.SaveToJSON(LFile);
    except
      on E: Exception do begin WriteLn('[bench] save failed: ', E.Message); raise; end;
    end;
    WriteLn('counter=', GCounter, ' file=', LFile);
  finally
    if Assigned(GCtx) then
      try GCtx.Close; except end;
    GCtx := nil;
    GRuntime := nil;
  end;
end;
begin
  try
    RunForBackend(jsbkFake, 'fake');
    RunForBackend(jsbkJs888, 'js888');
    RunForBackend(jsbkV8, 'v8');
    RunForBackend(jsbkChakra, 'chakra');
    RunForBackend(jsbkQuickJs, 'quickjs');
  except
    on E: Exception do begin WriteLn('[bench] fatal: ', E.ClassName, ': ', E.Message); Halt(1); end;
  end;
end.
