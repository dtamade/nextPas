program bench_text;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.text.view, nextpas.core.text.number,
  nextpas.core.text.escape, nextpas.core.text.scan, nextpas.core.text.utf8,
  nextpas.core.text.builder, nextpas.core.text.conv;
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
procedure BenchEscapeHtml(const ACtx: IBenchContext);
const DATA = '<script>alert("hello & goodbye")</script>';
var LS: string;
begin LS := EscapeHtml(DATA); GSink := GSink xor UInt64(Length(LS)); end;
procedure BenchTrimLeft(const ACtx: IBenchContext);
const DATA = '   hello world   ';
var LS: string;
begin LS := TrimLeft(DATA); GSink := GSink xor UInt64(Length(LS)); end;
var LSuite: IBenchSuite;
begin
  GSink := 0;
  LSuite := TBenchSuite.Create('text');
  LSuite.Add('IndexOf', @BenchIndexOf).Add('IntToStr', @BenchIntToStr).Add('UIntToStr', @BenchUIntToStr)
    .Add('HexStr', @BenchHexStr).Add('EscapeHtml', @BenchEscapeHtml).Add('TrimLeft', @BenchTrimLeft);
  WriteLn(LSuite.Run.PrintToConsole);
end.
