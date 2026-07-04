program bench_utf8_unicode;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.text.utf8, nextpas.core.text.unicode, nextpas.core.text.compare;
var GSink: UInt64;
procedure BenchUtf8ValidateAscii(const ACtx: IBenchContext);
const DATA = 'The quick brown fox jumps over the lazy dog 0123456789 ABCDEF abcdef';
begin GSink := GSink xor Byte(Utf8Validate(@DATA[1], Length(DATA))); end;
procedure BenchUtf8ValidateCjk(const ACtx: IBenchContext);
const DATA = #228#184#173#230#150#135#229#173#151#231#172#166#228#184#178#230#181#139#232#174#174;
begin GSink := GSink xor Byte(Utf8Validate(@DATA[1], Length(DATA))); end;
procedure BenchUtf8ValidateEmoji(const ACtx: IBenchContext);
const DATA = #240#159#152#128#240#159#152#129#240#159#152#130;
begin GSink := GSink xor Byte(Utf8Validate(@DATA[1], Length(DATA))); end;
procedure BenchUnicodeToUpperAscii(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(UnicodeToUpper(Ord('a'))); end;
procedure BenchUnicodeToLowerAscii(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(UnicodeToLower(Ord('A'))); end;
procedure BenchUnicodeCaseFold(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(UnicodeCaseFold(Ord('A'))); end;
var LSuite: IBenchSuite;
begin
  GSink := 0;
  LSuite := TBenchSuite.Create('utf8-unicode');
  LSuite.Add('Utf8Validate/ASCII', @BenchUtf8ValidateAscii).Add('Utf8Validate/CJK', @BenchUtf8ValidateCjk)
    .Add('Utf8Validate/Emoji', @BenchUtf8ValidateEmoji)
    .Add('ToUpper/ASCII', @BenchUnicodeToUpperAscii).Add('ToLower/ASCII', @BenchUnicodeToLowerAscii).Add('CaseFold/ASCII', @BenchUnicodeCaseFold);
  WriteLn(LSuite.Run.PrintToConsole);
end.
