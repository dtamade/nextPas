program bench_text;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.base,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.text.view, nextpas.core.text.number,
  nextpas.core.text.escape, nextpas.core.text.scan, nextpas.core.text.utf8,
  nextpas.core.text.builder, nextpas.core.text.conv,
  nextpas.core.fs;
var GSink: UInt64;
procedure BenchIndexOf(const ACtx: IBenchContext);
const DATA = 'The quick brown fox jumps over the lazy dog and finds the hidden treasure at the end';
var LView: TStringView; LDummy: PtrInt;
begin LView := TStringView.Create(PAnsiChar(DATA), Length(DATA)); LDummy := LView.IndexOf('t'); GSink := GSink xor UInt64(LDummy); end;
procedure BenchIntToStr(const ACtx: IBenchContext);
var LS: string;
begin LS := IntToStr(-1234567890123456789); GSink := GSink xor UInt64(Length(LS)); end;
procedure BenchUIntToStr(const ACtx: IBenchContext);
var LS: string;
begin LS := UIntToStr(High(UInt64)); GSink := GSink xor UInt64(Length(LS)); end;
procedure BenchHexStr(const ACtx: IBenchContext);
var LS: string;
begin LS := HexStr($DEADBEEFCAFEBABE, 16); GSink := GSink xor UInt64(Length(LS)); end;
procedure BenchJsonEscape(const ACtx: IBenchContext);
const DATA = '<script>alert("hello & goodbye")</script>';
var LBuilder: TStringBuilder; LView: TStringView;
begin
  LBuilder.Init(Length(DATA) * 2);
  LView := TStringView.FromStr(DATA);
  JsonEscapeToBuilder(LView, LBuilder);
  GSink := GSink xor UInt64(LBuilder.Len);
  LBuilder.Done;
end;
procedure BenchTrimLeft(const ACtx: IBenchContext);
const DATA = '   hello world   ';
var LS: string;
begin LS := TrimLeft(DATA); GSink := GSink xor UInt64(Length(LS)); end;
var LResults: IBenchResults;
begin
  GSink := 0;
  LResults := TBenchSuite.Create('text')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('text/IndexOf', @BenchIndexOf).Add('text/IntToStr', @BenchIntToStr).Add('text/UIntToStr', @BenchUIntToStr)
    .Add('text/HexStr', @BenchHexStr).Add('text/JsonEscape', @BenchJsonEscape).Add('text/TrimLeft', @BenchTrimLeft)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-text.json');
end.
