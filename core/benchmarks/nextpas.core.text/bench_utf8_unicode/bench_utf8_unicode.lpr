program bench_utf8_unicode;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.text.utf8, nextpas.core.text.unicode, nextpas.core.text.compare;
var GSink: UInt64;
procedure BenchUtf8ValidateAscii(const ACtx: IBenchContext);
const DATA = 'The quick brown fox jumps over the lazy dog 0123456789 ABCDEF abcdef';
begin GSink := GSink xor Byte(UTF8IsValid(@DATA[1], Length(DATA))); end;
procedure BenchUtf8ValidateCjk(const ACtx: IBenchContext);
const DATA = #228#184#173#230#150#135#229#173#151#231#172#166#228#184#178#230#181#139#232#174#174;
begin GSink := GSink xor Byte(UTF8IsValid(@DATA[1], Length(DATA))); end;
procedure BenchUtf8ValidateEmoji(const ACtx: IBenchContext);
const DATA = #240#159#152#128#240#159#152#129#240#159#152#130;
begin GSink := GSink xor Byte(UTF8IsValid(@DATA[1], Length(DATA))); end;
procedure BenchCodepointToUpperAscii(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(CodepointToUpper(Ord('a'))); end;
procedure BenchCodepointToLowerAscii(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(CodepointToLower(Ord('A'))); end;
procedure BenchCaseFoldSimpleAscii(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(CaseFoldSimple(Ord('A'))); end;
procedure BenchGetScriptAscii(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(Ord(GetScript(Ord('A')))); end;
procedure BenchGetBlockAscii(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(Ord(GetBlock(Ord('A')))); end;
var LSuite: IBenchSuite;
begin
  GSink := 0;
  LSuite := TBenchSuite.Create('utf8-unicode');
  LSuite.Add('Utf8Validate/ASCII', @BenchUtf8ValidateAscii).Add('Utf8Validate/CJK', @BenchUtf8ValidateCjk)
    .Add('Utf8Validate/Emoji', @BenchUtf8ValidateEmoji)
    .Add('ToUpper/ASCII', @BenchCodepointToUpperAscii).Add('ToLower/ASCII', @BenchCodepointToLowerAscii)
    .Add('CaseFold/ASCII', @BenchCaseFoldSimpleAscii)
    .Add('GetScript/ASCII', @BenchGetScriptAscii).Add('GetBlock/ASCII', @BenchGetBlockAscii);
  WriteLn(LSuite.Run.PrintToConsole);
end.
