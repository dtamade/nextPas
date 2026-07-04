program bench_facade_breakdown;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.platform.time, nextpas.core.text.view,
  nextpas.core.mem.intf, nextpas.core.mem.default,
  nextpas.core.json.types, nextpas.core.json.parser, nextpas.core.json;
const SMALL_JSON = '{"name":"Alice","age":30,"active":true,"score":3.14}';
var GSink: UInt64;
procedure BenchRawReuse(const ACtx: IBenchContext);
var Doc: TJsonDocument; LView: TStringView;
begin LView := TStringView.FromStr(SMALL_JSON); Doc.Init(DefaultAllocator); Doc.Parse(LView); Doc.Done; GSink := GSink xor UInt64(Length(SMALL_JSON)); end;
procedure BenchRawInitDone(const ACtx: IBenchContext);
var Doc: TJsonDocument; LView: TStringView;
begin LView := TStringView.FromStr(SMALL_JSON); Doc.Init(DefaultAllocator); Doc.Parse(LView); Doc.Done; GSink := GSink xor UInt64(Length(SMALL_JSON)); end;
procedure BenchFacadeString(const ACtx: IBenchContext);
var Doc: IJsonDocument;
begin Doc := JsonParse(SMALL_JSON); GSink := GSink xor UInt64(Length(SMALL_JSON)); end;
procedure BenchFacadeView(const ACtx: IBenchContext);
var Doc: IJsonDocument; LView: TStringView;
begin LView := TStringView.FromStr(SMALL_JSON); Doc := JsonParse(LView); GSink := GSink xor UInt64(Length(SMALL_JSON)); end;
var LSuite: IBenchSuite;
begin
  GSink := 0;
  LSuite := TBenchSuite.Create('facade-breakdown');
  LSuite.Add('Raw/Reuse', @BenchRawReuse).Add('Raw/InitDone', @BenchRawInitDone)
    .Add('Facade/String', @BenchFacadeString).Add('Facade/View', @BenchFacadeView);
  WriteLn(LSuite.Run.PrintToConsole);
end.
