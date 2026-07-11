program bench_unicode_enhance;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.text.unicode;
var GSink: UInt64;
procedure BenchGetScriptAscii(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(Ord(GetScript(Ord('A')))); end;
procedure BenchGetScriptCjk(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(Ord(GetScript($4E2D))); end;
procedure BenchGetBlockAscii(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(Ord(GetBlock(Ord('A')))); end;
procedure BenchGetBlockCjk(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(Ord(GetBlock($4E2D))); end;
procedure BenchSegmentGraphemeClusters(const ACtx: IBenchContext);
const DATA = 'Hello World 你好世界';
var LResults: TSegmentResultArray;
begin LResults := SegmentGraphemeClusters(DATA); GSink := GSink xor UInt64(Length(LResults)); end;
procedure BenchSegmentWords(const ACtx: IBenchContext);
const DATA = 'Hello World 你好世界';
var LResults: TSegmentResultArray;
begin LResults := SegmentWords(DATA); GSink := GSink xor UInt64(Length(LResults)); end;
procedure BenchSegmentLines(const ACtx: IBenchContext);
const DATA = 'Line1' + #10 + 'Line2' + #10 + 'Line3';
var LResults: TSegmentResultArray;
begin LResults := SegmentLines(DATA); GSink := GSink xor UInt64(Length(LResults)); end;
procedure BenchSegmentSentences(const ACtx: IBenchContext);
const DATA = 'Hello. World! How are you?';
var LResults: TSegmentResultArray;
begin LResults := SegmentSentences(DATA); GSink := GSink xor UInt64(Length(LResults)); end;
procedure BenchCollatorCompare(const ACtx: IBenchContext);
var LCollator: IUnicodeCollator;
begin LCollator := UnicodeCollator; GSink := GSink xor UInt64(LCollator.Compare('Hello', 'World')); end;
procedure BenchCollatorEquals(const ACtx: IBenchContext);
var LCollator: IUnicodeCollator;
begin LCollator := UnicodeCollator; GSink := GSink xor Byte(LCollator.Equals('Hello', 'Hello')); end;
procedure BenchCollatorStartsWith(const ACtx: IBenchContext);
var LCollator: IUnicodeCollator;
begin LCollator := UnicodeCollator; GSink := GSink xor Byte(LCollator.StartsWith('Hello World', 'Hello')); end;
procedure BenchCollatorContains(const ACtx: IBenchContext);
var LCollator: IUnicodeCollator;
begin LCollator := UnicodeCollator; GSink := GSink xor Byte(LCollator.Contains('Hello World', 'World')); end;
var LSuite: IBenchSuite;
begin
  GSink := 0;
  LSuite := TBenchSuite.Create('unicode-enhance');
  LSuite.Add('GetScript/ASCII', @BenchGetScriptAscii).Add('GetScript/CJK', @BenchGetScriptCjk)
    .Add('GetBlock/ASCII', @BenchGetBlockAscii).Add('GetBlock/CJK', @BenchGetBlockCjk)
    .Add('SegmentGraphemeClusters', @BenchSegmentGraphemeClusters)
    .Add('SegmentWords', @BenchSegmentWords)
    .Add('SegmentLines', @BenchSegmentLines)
    .Add('SegmentSentences', @BenchSegmentSentences)
    .Add('Collator/Compare', @BenchCollatorCompare)
    .Add('Collator/Equals', @BenchCollatorEquals)
    .Add('Collator/StartsWith', @BenchCollatorStartsWith)
    .Add('Collator/Contains', @BenchCollatorContains);
  WriteLn(LSuite.Run.PrintToConsole);
end.