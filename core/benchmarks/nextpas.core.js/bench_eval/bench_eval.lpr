program bench_eval;
{$I nextpas.core.settings.inc}
uses nextpas.core.exception, nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.json, nextpas.core.time.base,
  nextpas.core.fs, nextpas.core.js.base, nextpas.core.js.intf, nextpas.core.js,
  nextpas.core.js.quickjs.loader, nextpas.core.js.pure.value;
var GCounter: UInt64; GRuntime: IJsRuntime; GCtx: IJsContext;
var GBatchHeap: TJsPureHeap; GBatchObjs: array of TJsValue; GBatchVals: array of TJsValue;
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
procedure BenchBatchLoopGet(const ACtx: IBenchContext);
var I: Integer; V: TJsValue; begin for I:=0 to High(GBatchObjs) do begin V:=JsPureHeapGetProp(GBatchHeap, GBatchObjs[I], 'x'); GCounter:=GCounter xor UInt64(V.AsInt); end; end;
procedure BenchBatchGet(const ACtx: IBenchContext);
var Vs: TJsValueArray; I: Integer; begin Vs:=JsPureHeapGetBatch(GBatchHeap, GBatchObjs, 'x'); for I:=0 to High(Vs) do GCounter:=GCounter xor UInt64(Vs[I].AsInt); end;
procedure BenchBatchLoopSet(const ACtx: IBenchContext);
var I: Integer; begin for I:=0 to High(GBatchObjs) do JsPureHeapSetProp(GBatchHeap, GBatchObjs[I], 'x', GBatchVals[I]); GCounter:=GCounter xor UInt64(Length(GBatchHeap)); end;
procedure BenchBatchSet(const ACtx: IBenchContext);
begin JsPureHeapSetBatch(GBatchHeap, GBatchObjs, 'x', GBatchVals); GCounter:=GCounter xor UInt64(Length(GBatchHeap)); end;
procedure PrepareBatch;
var I: Integer; LObj: TJsValue; begin SetLength(GBatchHeap,0); SetLength(GBatchObjs,1024); SetLength(GBatchVals,1024); for I:=0 to 1023 do begin LObj:=JsPureHeapNewObject(GBatchHeap); JsPureHeapSetProp(GBatchHeap, LObj, 'x', JsIntValue(I)); GBatchObjs[I]:=LObj; GBatchVals[I]:=JsIntValue(I+1); end; end;
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
      .Add('JSON/interop', @BenchSkipped).Add('Value/ops', @BenchSkipped)
      .Add('Batch/GetLoop', @BenchSkipped).Add('Batch/GetBatch', @BenchSkipped)
      .Add('Batch/SetLoop', @BenchSkipped).Add('Batch/SetBatch', @BenchSkipped).Run;
    WriteLn('=== ', ALabel, ' (skipped) ===');
    WriteLn(LResults.PrintToConsole);
    LFile := 'build/bench-eval-'+ALabel+'.json';
    ForceDirectories('build');
    try
      LResults.SaveToJSON(LFile);
    except
      on E: ENextPasError do WriteLn('[bench] save failed: ', E.Message);
      on E: TObject do WriteLn('[bench] save failed: ', E.ClassName);
    end;
    WriteLn('counter=', GCounter, ' file=', LFile, ' (skipped)');
    Exit;
  end;
  GRuntime := CreateJsRuntime(AKind);
  GCtx := GRuntime.NewContext;
  try
    GCtx.SetHostFunction('noop', @HostNoop);
    PrepareBatch;
    GCounter := 0;
    LResults := TBenchSuite.Create('js.eval.'+ALabel)
      .SetQuiet(True).SetMinDuration(TDuration.FromMilliseconds(50)).SetMinSamples(5)
      .Add('Eval/small', @BenchEvalSmall).Add('Eval/host', @BenchEvalHostCall)
      .Add('JSON/interop', @BenchJsonInterop).Add('Value/ops', @BenchValueOps)
      .Add('Batch/GetLoop', @BenchBatchLoopGet).Add('Batch/GetBatch', @BenchBatchGet)
      .Add('Batch/SetLoop', @BenchBatchLoopSet).Add('Batch/SetBatch', @BenchBatchSet).Run;
    WriteLn('=== ', ALabel, ' ===');
    WriteLn(LResults.PrintToConsole);
    LFile := 'build/bench-eval-'+ALabel+'.json';
    ForceDirectories('build');
    try
      LResults.SaveToJSON(LFile);
    except
      on E: ENextPasError do begin WriteLn('[bench] save failed: ', E.Message); raise; end;
      on E: TObject do begin WriteLn('[bench] save failed: ', E.ClassName); raise; end;
    end;
    WriteLn('counter=', GCounter, ' file=', LFile);
  finally
    // stability: batch heap resource release不丢, try-finally + Clear幂等, bytes.ops single source via SetLength 0 + DynArraySetLength poke
    try JsPureHeapClear(GBatchHeap); except end;
    SetLength(GBatchObjs,0); SetLength(GBatchVals,0); SetLength(GBatchHeap,0);
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
    on E: ENextPasError do begin WriteLn('[bench] fatal: ', E.ClassName, ': ', E.Message); Halt(1); end;
    on E: TObject do begin WriteLn('[bench] fatal: ', E.ClassName); Halt(1); end;
  end;
end.
