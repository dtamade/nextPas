program bench_strings;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.text, nextpas.core.text.base, nextpas.core.text.compare;
var GSink: UInt64;
procedure BenchTrim(const ACtx: IBenchContext);
var LS: string;
begin LS := TextTrim('   hello world   '); GSink := GSink xor UInt64(Length(LS)); end;
procedure BenchSplit(const ACtx: IBenchContext);
var LParts: TStringArray;
begin LParts := TextSplit('a,b,c,d,e,f,g,h,i,j', ','); GSink := GSink xor UInt64(Length(LParts)); end;
procedure BenchJoin(const ACtx: IBenchContext);
var LParts: TStringArray; LS: string; LI: Integer;
begin
  SetLength(LParts, 10);
  for LI := 0 to 9 do LParts[LI] := 'item' + IntToStr(LI);
  LS := TextJoin(LParts, ',');
  GSink := GSink xor UInt64(Length(LS));
end;
procedure BenchReplace(const ACtx: IBenchContext);
var LS: string;
begin LS := TextReplace('hello world hello foo hello bar', 'hello', 'bye'); GSink := GSink xor UInt64(Length(LS)); end;
procedure BenchContains(const ACtx: IBenchContext);
var LB: Boolean;
begin LB := TextContains('The quick brown fox jumps over the lazy dog', 'fox'); GSink := GSink xor Byte(LB); end;
procedure BenchHasPrefix(const ACtx: IBenchContext);
var LB: Boolean;
begin LB := TextStartsWith('Hello World', 'Hello'); GSink := GSink xor Byte(LB); end;
procedure BenchHasSuffix(const ACtx: IBenchContext);
var LB: Boolean;
begin LB := TextEndsWith('Hello World', 'World'); GSink := GSink xor Byte(LB); end;
procedure BenchEqualFold(const ACtx: IBenchContext);
var LB: Boolean;
begin LB := TextEqualCaseFold('Hello World', 'hello world'); GSink := GSink xor Byte(LB); end;
procedure BenchToUpper(const ACtx: IBenchContext);
var LS: string;
begin LS := TextToUpper('hello world'); GSink := GSink xor UInt64(Length(LS)); end;
procedure BenchToLower(const ACtx: IBenchContext);
var LS: string;
begin LS := TextToLower('HELLO WORLD'); GSink := GSink xor UInt64(Length(LS)); end;
var LSuite: IBenchSuite;
begin
  GSink := 0;
  LSuite := TBenchSuite.Create('strings');
  LSuite.Add('Trim', @BenchTrim).Add('Split', @BenchSplit).Add('Join', @BenchJoin)
    .Add('Replace', @BenchReplace).Add('Contains', @BenchContains).Add('HasPrefix', @BenchHasPrefix)
    .Add('HasSuffix', @BenchHasSuffix).Add('EqualFold', @BenchEqualFold).Add('ToUpper', @BenchToUpper).Add('ToLower', @BenchToLower);
  WriteLn(LSuite.Run.PrintToConsole);
end.
