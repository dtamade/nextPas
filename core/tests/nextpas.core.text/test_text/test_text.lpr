program test_text;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.fs,
  nextpas.core.text,
  nextpas.core.text.utf8,
  nextpas.core.text.utils;

var
  T: TTestSuite;

function LoadSourceText(const ARelativePath: string): string;
begin
  Check(FileExists(ARelativePath), 'source file exists: ' + ARelativePath);
  Result := ReadFileText(ARelativePath);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure TestTrim;
begin
  CheckEqual('hello', TextTrim('  hello  '), 'both sides');
  CheckEqual('hello', TextTrim('hello'), 'no whitespace');
  CheckEqual('', TextTrim('   '), 'all whitespace');
  CheckEqual('', TextTrim(''), 'empty');
end;

procedure TestTrimLeft;
begin
  CheckEqual('hello  ', TextTrimLeft('  hello  '), 'left only');
  CheckEqual('', TextTrimLeft(''), 'empty');
end;

procedure TestTrimRight;
begin
  CheckEqual('  hello', TextTrimRight('  hello  '), 'right only');
  CheckEqual('', TextTrimRight(''), 'empty');
end;

procedure TestStartsWith;
begin
  Check(TextStartsWith('hello world', 'hello'), 'prefix match');
  Check(not TextStartsWith('hello world', 'world'), 'no prefix');
  Check(TextStartsWith('hello', ''), 'empty prefix');
  Check(not TextStartsWith('', 'x'), 'empty value');
end;

procedure TestEndsWith;
begin
  Check(TextEndsWith('hello world', 'world'), 'suffix match');
  Check(not TextEndsWith('hello world', 'hello'), 'no suffix');
  Check(TextEndsWith('hello', ''), 'empty suffix');
end;

procedure TestContains;
begin
  Check(TextContains('hello world', 'lo wo'), 'substring');
  Check(not TextContains('hello', 'xyz'), 'not found');
  Check(TextContains('hello', ''), 'empty substr');
end;

procedure TestSplit;
var
  LParts: TStringArray;
begin
  LParts := TextSplit('a,b,c', ',');
  CheckEqual(Int64(3), Int64(Length(LParts)), 'count');
  CheckEqual('a', LParts[0], 'part 0');
  CheckEqual('b', LParts[1], 'part 1');
  CheckEqual('c', LParts[2], 'part 2');

  LParts := TextSplit('hello', ',');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'no delimiter');
  CheckEqual('hello', LParts[0], 'whole string');

  LParts := TextSplit('a::b::c', '::');
  CheckEqual(Int64(3), Int64(Length(LParts)), 'multi-char delim');
  CheckEqual('b', LParts[1], 'multi-char part');

  LParts := TextSplit(',a,', ',');
  CheckEqual(Int64(3), Int64(Length(LParts)), 'leading/trailing delim');
  CheckEqual('', LParts[0], 'empty first');
  CheckEqual('', LParts[2], 'empty last');

  LParts := TextSplit('a,,c', ',');
  CheckEqual(Int64(3), Int64(Length(LParts)), 'empty field count');
  CheckEqual('', LParts[1], 'empty middle field');

  LParts := TextSplit('abc', '');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'empty delimiter count');
  CheckEqual('abc', LParts[0], 'empty delimiter value');
end;

procedure TestJoin;
var
  LParts: TStringArray;
begin
  SetLength(LParts, 3);
  LParts[0] := 'a';
  LParts[1] := 'b';
  LParts[2] := 'c';
  CheckEqual('a,b,c', TextJoin(LParts, ','), 'basic join');
  CheckEqual('a--b--c', TextJoin(LParts, '--'), 'multi-char sep');

  SetLength(LParts, 0);
  CheckEqual('', TextJoin(LParts, ','), 'empty array');
end;

procedure TestReplace;
begin
  CheckEqual('hXllo', TextReplace('hello', 'e', 'X'), 'first only');
  CheckEqual('hello', TextReplace('hello', 'z', 'X'), 'not found');
  CheckEqual('hello', TextReplace('hello', '', 'X'), 'empty old');
end;

procedure TestReplaceAll;
begin
  CheckEqual('hXllo', TextReplaceAll('hello', 'e', 'X'), 'single match');
  CheckEqual('XbXbX', TextReplaceAll('ababa', 'a', 'X'), 'multiple');
  CheckEqual('hello', TextReplaceAll('hello', 'z', 'X'), 'not found');
  CheckEqual('hllo', TextReplaceAll('hello', 'e', ''), 'replace with empty');
end;

procedure TestToUpper;
begin
  CheckEqual('HELLO', TextToUpper('hello'), 'lower to upper');
  CheckEqual('HELLO123', TextToUpper('Hello123'), 'mixed');
  CheckEqual('STRASSE', TextToUpper('Stra' + #$C3#$9F + 'e'), 'unicode sharp s upper');
  CheckEqual('', TextToUpper(''), 'empty');
end;

procedure TestToLower;
begin
  CheckEqual('hello', TextToLower('HELLO'), 'upper to lower');
  CheckEqual('hello123', TextToLower('Hello123'), 'mixed');
  CheckEqual(#$CF#$89, TextToLower(#$CE#$A9), 'unicode omega lower');
  CheckEqual('', TextToLower(''), 'empty');
end;

procedure TestPadLeft;
var
  LVar: string;
begin
  CheckEqual('   hi', TextPadLeft('hi', 5), 'pad spaces');
  CheckEqual('000hi', TextPadLeft('hi', 5, '0'), 'pad zeros');
  CheckEqual('hello', TextPadLeft('hello', 3), 'no pad needed');
  // FPC inline+literal Move 缺陷回退锁：字面量与变量路径必须一致
  CheckEqual('   hi', nextpas.core.text.utils.PadLeft('hi', 5), 'utils pad literal');
  LVar := 'hi';
  CheckEqual('   hi', nextpas.core.text.utils.PadLeft(LVar, 5), 'utils pad var');
  CheckEqual('   hi', TextPadLeft(LVar, 5), 'facade pad var');
end;

procedure TestPadRight;
var
  LVar: string;
begin
  CheckEqual('hi   ', TextPadRight('hi', 5), 'pad spaces');
  CheckEqual('hi000', TextPadRight('hi', 5, '0'), 'pad zeros');
  CheckEqual('hello', TextPadRight('hello', 3), 'no pad needed');
  // 同上：PadRight 字面量路径回退锁
  CheckEqual('hi   ', nextpas.core.text.utils.PadRight('hi', 5), 'utils pad literal');
  LVar := 'hi';
  CheckEqual('hi   ', nextpas.core.text.utils.PadRight(LVar, 5), 'utils pad var');
end;

procedure TestRepeat;
begin
  CheckEqual('abcabcabc', TextRepeat('abc', 3), 'repeat 3');
  CheckEqual('', TextRepeat('abc', 0), 'repeat 0');
  CheckEqual('x', TextRepeat('x', 1), 'repeat 1');
end;

procedure TestIndexOf;
begin
  CheckEqual(Int64(0), Int64(TextIndexOf('hello', 'h')), 'first char');
  CheckEqual(Int64(4), Int64(TextIndexOf('hello', 'o')), 'last char');
  CheckEqual(Int64(-1), Int64(TextIndexOf('hello', 'z')), 'not found');
  CheckEqual(Int64(2), Int64(TextIndexOf('hello', 'llo')), 'substring');
  CheckEqual(Int64(0), Int64(TextIndexOf('hello', '')), 'empty substring');
  CheckEqual(Int64(1), Int64(TextIndexOf('a b c', ' ', 0)), 'from 0 first space');
  CheckEqual(Int64(3), Int64(TextIndexOf('a b c', ' ', 2)), 'from after first space');
  CheckEqual(Int64(-1), Int64(TextIndexOf('a b c', ' ', 4)), 'from last char no space');
  CheckEqual(Int64(-1), Int64(TextIndexOf('hello', 'h', 1)), 'skip first char');
end;

procedure TestLastIndexOf;
begin
  CheckEqual(Int64(3), Int64(TextLastIndexOf('abcabc', 'abc')), 'last occurrence');
  CheckEqual(Int64(0), Int64(TextLastIndexOf('abcdef', 'abc')), 'only occurrence');
  CheckEqual(Int64(-1), Int64(TextLastIndexOf('hello', 'xyz')), 'not found');
end;

procedure TestIsEmpty;
begin
  Check(TextIsEmpty(''), 'empty');
  Check(not TextIsEmpty(' '), 'space not empty');
  Check(not TextIsEmpty('x'), 'char not empty');
end;

procedure TestIsBlank;
begin
  Check(TextIsBlank(''), 'empty is blank');
  Check(TextIsBlank('   '), 'spaces are blank');
  Check(TextIsBlank(#9#10#13), 'whitespace is blank');
  Check(not TextIsBlank(' x '), 'has content');
end;

procedure TestUTF8Length;
begin
  CheckEqual(Int64(5), Int64(TextUTF8Length('hello')), 'ASCII');
  CheckEqual(Int64(2), Int64(TextUTF8Length(#$C3#$A9#$C3#$A8)), '2-byte chars');
  CheckEqual(Int64(1), Int64(TextUTF8Length(#$E4#$B8#$AD)), '3-byte CJK');
  CheckEqual(Int64(1), Int64(TextUTF8Length(#$F0#$9F#$98#$80)), '4-byte emoji');
  CheckEqual(Int64(0), Int64(TextUTF8Length('')), 'empty');
end;

procedure TestUTF8CodePointAt;
begin
  CheckEqual(Int64(Ord('h')), Int64(TextUTF8CodePointAt('hello', 0)), 'ASCII index 0');
  CheckEqual(Int64(Ord('o')), Int64(TextUTF8CodePointAt('hello', 4)), 'ASCII index 4');
  CheckEqual(Int64($4E2D), Int64(TextUTF8CodePointAt(#$E4#$B8#$AD, 0)), 'CJK U+4E2D');
  CheckEqual(Int64($1F600), Int64(TextUTF8CodePointAt(#$F0#$9F#$98#$80, 0)), 'emoji U+1F600');
end;

procedure TestUTF8MalformedConsumesOneByte;
var
  LValue: string;
begin
  LValue := #$80 + 'ABC';
  CheckEqual(Int64(4), Int64(TextUTF8Length(LValue)), 'invalid continuation byte counts as one replacement codepoint');
  CheckEqual(Int64($FFFD), Int64(TextUTF8CodePointAt(LValue, 0)), 'invalid byte returns replacement codepoint');
  CheckEqual(Int64(Ord('A')), Int64(TextUTF8CodePointAt(LValue, 1)), 'valid byte after invalid stays addressable');

  LValue := #$E2#$82 + 'Z';
  CheckEqual(Int64(3), Int64(TextUTF8Length(LValue)), 'truncated sequence consumes one byte at a time');
  CheckEqual(Int64($FFFD), Int64(TextUTF8CodePointAt(LValue, 0)), 'truncated lead returns replacement');
  CheckEqual(Int64($FFFD), Int64(TextUTF8CodePointAt(LValue, 1)), 'trailing continuation returns replacement');
  CheckEqual(Int64(Ord('Z')), Int64(TextUTF8CodePointAt(LValue, 2)), 'ASCII after truncated sequence stays addressable');
end;

procedure TestUtilsSurface;
var
  LParts: TStringArray;
begin
  CheckEqual('hello', nextpas.core.text.utils.Trim('  hello  '), 'utils trim');
  CheckEqual('000hi', nextpas.core.text.utils.PadLeft('hi', 5, '0'), 'utils pad left');
  CheckEqual('hi000', nextpas.core.text.utils.PadRight('hi', 5, '0'), 'utils pad right');
  CheckEqual('abab', nextpas.core.text.utils.RepeatString('ab', 2), 'utils repeat');
  Check(nextpas.core.text.utils.IsEmpty(''), 'utils empty');
  Check(nextpas.core.text.utils.IsBlank(#9' '#10), 'utils blank');

  { PosEx:StrUtils 语义,1-based 起查 }
  CheckEqual(7, nextpas.core.text.utils.PosEx('world', 'hello world'), 'posex found');
  CheckEqual(1, nextpas.core.text.utils.PosEx('hello', 'hello world'), 'posex at 1');
  CheckEqual(0, nextpas.core.text.utils.PosEx('x', 'abc'), 'posex absent');
  CheckEqual(2, nextpas.core.text.utils.PosEx('b', 'abc', 2), 'posex from');
  CheckEqual(0, nextpas.core.text.utils.PosEx('b', 'abc', 3), 'posex from past end');
  CheckEqual(0, nextpas.core.text.utils.PosEx('b', 'abc', 0), 'posex from below 1');
  CheckEqual(0, nextpas.core.text.utils.PosEx('abc', 'ab'), 'posex longer needle');
  CheckEqual(2, nextpas.core.text.utils.PosEx('', 'abc', 2), 'posex empty needle hits from');
  CheckEqual(0, nextpas.core.text.utils.PosEx('', 'abc', 5), 'posex empty needle past end');

  { SplitString:SysUtils 语义,连续分隔符不产生空段 }
  LParts := nextpas.core.text.utils.SplitString('a,b,c', ',');
  CheckEqual(Int64(3), Int64(Length(LParts)), 'split three');
  CheckEqual('a', LParts[0], 'split 0');
  CheckEqual('b', LParts[1], 'split 1');
  CheckEqual('c', LParts[2], 'split 2');
  LParts := nextpas.core.text.utils.SplitString('a,,b', ',');
  CheckEqual(Int64(2), Int64(Length(LParts)), 'split no empty between');
  CheckEqual('a', LParts[0], 'split no empty 0');
  CheckEqual('b', LParts[1], 'split no empty 1');
  LParts := nextpas.core.text.utils.SplitString(',a,', ',');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'split no edge empties');
  CheckEqual('a', LParts[0], 'split no edge 0');
  LParts := nextpas.core.text.utils.SplitString('', ',');
  CheckEqual(Int64(0), Int64(Length(LParts)), 'split empty src');
  LParts := nextpas.core.text.utils.SplitString('abc', ',');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'split no delimiter');
  LParts := nextpas.core.text.utils.SplitString('a-b_c', '-_');
  CheckEqual(Int64(3), Int64(Length(LParts)), 'split multi delimiter');
  CheckEqual('a', LParts[0], 'split multi 0');
  CheckEqual('b', LParts[1], 'split multi 1');
  CheckEqual('c', LParts[2], 'split multi 2');
  LParts := nextpas.core.text.utils.SplitString(',,,', ',');
  CheckEqual(Int64(0), Int64(Length(LParts)), 'split all delimiters');
  LParts := nextpas.core.text.utils.SplitString('a'#10'b'#10'c', #10);
  CheckEqual(Int64(3), Int64(Length(LParts)), 'split newline');
  CheckEqual('b', LParts[1], 'split newline mid');
end;

procedure TestCopyStrToBuf;
var
  Buf: array[0..7] of AnsiChar;
begin
  FillChar(Buf, SizeOf(Buf), $7F);
  CheckEqual(3, CopyStrToBuf('abc', Buf, SizeOf(Buf)), 'copy len');
  CheckEqual('abc', StrPas(@Buf[0]), 'copy content');
  CheckEqual(0, Ord(Buf[3]), 'copy nul term');

  FillChar(Buf, SizeOf(Buf), $7F);
  CheckEqual(8, CopyStrToBuf('toolongx', Buf, SizeOf(Buf)), 'truncate returns src len');
  CheckEqual('toolong', StrPas(@Buf[0]), 'truncated content');
  CheckEqual(0, Ord(Buf[7]), 'last byte nul');

  CheckEqual(0, CopyStrToBuf('', Buf, SizeOf(Buf)), 'empty src');
  CheckEqual('', StrPas(@Buf[0]), 'empty content');
  CheckEqual(1, CopyStrToBuf('x', Buf, 1), 'buf len 1 keeps nul only');
end;

procedure TestCStrToStr;
var
  LBig: array[0..511] of AnsiChar;
  I: Integer;
begin
  LBig[0] := #0;
  CheckEqual('', CStrToStr(@LBig[0]), 'empty');

  LBig[0] := 'a'; LBig[1] := #0;
  CheckEqual('a', CStrToStr(@LBig[0]), 'short');

  for I := 0 to 510 do
    LBig[I] := 'x';
  LBig[511] := #0;
  CheckEqual(511, Length(CStrToStr(@LBig[0])), 'beyond 255 intact');
end;

procedure TestFacadeExtendedSurface;
var
  LBuilder: IStringBuilder;
  LView: TStringView;
  LErr: TUnescapeError;
  LGrapheme: TGraphemeResult;
  LEscapedBuf: array[0..31] of AnsiChar;
  LUnescapedBuf: array[0..31] of AnsiChar;
  LEscapedLen: SizeUInt;
  LUnescapedLen: SizeUInt;
  LEscaped: string;
  LUnescaped: string;
  LComposed: string;
  LDecomposed: string;
begin
  LBuilder := MakeStringBuilder(8);
  LBuilder.AppendStr('he');
  LBuilder.AppendView(TStringView.FromStr('llo'));
  CheckEqual('hello', LBuilder.ToString, 'builder visible through facade');

  LView := TStringView.FromStr('  hello  ').Trim;
  CheckEqual('hello', LView.ToString, 'view visible through facade');

  LComposed := #$C3#$85;
  LDecomposed := 'A' + #$CC#$8A;
  Check(TextEqualCanonical(LComposed, LDecomposed), 'canonical compare visible through facade');
  Check(TextEqualCaseFold('Hello', 'HELLO'), 'casefold compare visible through facade');

  LEscapedLen := JsonEscapeToBuffer(PAnsiChar('a"'#10'b'), 4, @LEscapedBuf[0]);
  SetString(LEscaped, PAnsiChar(@LEscapedBuf[0]), LEscapedLen);
  CheckEqual('a' + '\' + '"' + '\' + 'nb', LEscaped,
    'json escape visible through facade');

  LUnescapedLen := JsonUnescapeToBuffer(PAnsiChar('a\n'), 3, @LUnescapedBuf[0], LErr);
  CheckEqual(Int64(Ord(ueNone)), Int64(Ord(LErr)), 'json unescape error visible through facade');
  SetString(LUnescaped, PAnsiChar(@LUnescapedBuf[0]), LUnescapedLen);
  CheckEqual('a'#10, LUnescaped, 'json unescape visible through facade');

  LGrapheme := GraphemeNext(PByte(PAnsiChar(#$F0#$9F#$98#$80)), 4);
  CheckEqual(Int64(4), Int64(LGrapheme.ByteLen), 'grapheme iterator visible through facade');
  CheckEqual(Int64(2), Int64(LGrapheme.Width), 'grapheme width visible through facade');

  CheckEqual(Int64(2), Int64(CodepointWidth($4E2D)), 'codepoint width visible through facade');
  CheckEqual(Int64(4), Int64(StringDisplayWidth('a' + #$E4#$B8#$AD + 'b')),
    'string display width visible through facade');

  CheckEqual('HELLO', UTF8ToUpper('Hello'), 'unicode upper visible through facade');
  CheckEqual('hello', UTF8ToLower('Hello'), 'unicode lower visible through facade');
  CheckEqual('hello', UTF8CaseFold('Hello'), 'unicode casefold visible through facade');
  CheckEqual(LDecomposed, NFD(LComposed), 'unicode NFD visible through facade');
  CheckEqual(LComposed, NFC(LDecomposed), 'unicode normalization visible through facade');
  Check(IsNormalizedNFC(LComposed), 'unicode normalization predicate visible through facade');
end;

procedure TestFacadeOwnerRouting;
var
  LSource: string;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.text.pas');
  CheckContains(LSource, 'Result := nextpas.core.text.utils.Trim(AValue);',
    'facade trim routed to utils');
  CheckContains(LSource, 'Result := nextpas.core.text.utils.TrimLeft(AValue);',
    'facade trim left routed to utils');
  CheckContains(LSource, 'Result := nextpas.core.text.utils.TrimRight(AValue);',
    'facade trim right routed to utils');
  CheckContains(LSource, 'Result := nextpas.core.text.compare.TextStartsWith(AValue, APrefix);',
    'facade startswith routed to compare');
  CheckContains(LSource, 'Result := nextpas.core.text.compare.TextEndsWith(AValue, ASuffix);',
    'facade endswith routed to compare');
  CheckContains(LSource, 'Result := nextpas.core.text.compare.TextContains(AValue, ASubStr);',
    'facade contains routed to compare');
  CheckContains(LSource, 'Result := nextpas.core.text.strings.StringsSplit(AValue, ADelimiter);',
    'facade split routed to strings');
  CheckContains(LSource, 'Result := nextpas.core.text.strings.StringsJoin(AParts, ASeparator);',
    'facade join routed to strings');
  CheckContains(LSource, 'Result := nextpas.core.text.utils.StringReplace(AValue, AOld, ANew, False);',
    'facade replace routed to utils');
  CheckContains(LSource, 'Result := nextpas.core.text.utils.StringReplace(AValue, AOld, ANew, True);',
    'facade replace all routed to utils');
  CheckContains(LSource, 'Result := nextpas.core.text.unicode.UTF8ToUpper(AValue);',
    'facade upper routed to unicode');
  CheckContains(LSource, 'Result := nextpas.core.text.unicode.UTF8ToLower(AValue);',
    'facade lower routed to unicode');
  CheckContains(LSource, 'Result := nextpas.core.text.utils.PadLeft(AValue, AWidth, APadChar);',
    'facade pad left routed to utils');
  CheckContains(LSource, 'Result := nextpas.core.text.utils.PadRight(AValue, AWidth, APadChar);',
    'facade pad right routed to utils');
  CheckContains(LSource, 'Result := nextpas.core.text.utils.RepeatString(AValue, ACount);',
    'facade repeat routed to utils');
  CheckContains(LSource, 'Result := Integer(nextpas.core.text.view.IndexOfStr(AValue, ASubStr));',
    'facade index routed to view');
  CheckContains(LSource, 'Result := Integer(nextpas.core.text.view.LastIndexOfStr(AValue, ASubStr));',
    'facade last index routed to view');
  CheckContains(LSource, 'Result := nextpas.core.text.utils.IsEmpty(AValue);',
    'facade empty routed to utils');
  CheckContains(LSource, 'Result := nextpas.core.text.utils.IsBlank(AValue);',
    'facade blank routed to utils');
  CheckContains(LSource, 'Result := Integer(nextpas.core.text.utf8.UTF8Length(AValue));',
    'facade utf8 length routed to utf8');
  CheckContains(LSource, 'Result := nextpas.core.text.utf8.UTF8CodePointAt(AValue, AIndex);',
    'facade utf8 codepoint routed to utf8');
  CheckContains(LSource, 'Result := nextpas.core.text.format.TextFormat(AFmt, AArgs);',
    'facade TextFormat routed to text.format');
  CheckContains(LSource, 'IStringBuilder = nextpas.core.text.builder.IStringBuilder;',
    'facade builder interface routed to builder');
  CheckContains(LSource, 'function MakeStringBuilder',
    'facade builder factory declared');
  CheckContains(LSource, 'Result := nextpas.core.text.builder.MakeStringBuilder(AInitialCap);',
    'facade builder factory routed to builder');
  CheckContains(LSource, 'TStringView = nextpas.core.text.view.TStringView;',
    'facade view type routed to view');
  CheckContains(LSource, 'Result := nextpas.core.text.compare.TextEqualCanonical(AValue, AOther);',
    'facade canonical compare routed to compare');
  CheckContains(LSource, 'Result := nextpas.core.text.compare.TextEqualCaseFold(AValue, AOther);',
    'facade casefold compare routed to compare');
  CheckContains(LSource, 'Result := nextpas.core.text.escape.JsonEscapeToBuffer(ASrc, ALen, ADst);',
    'facade json escape routed to escape');
  CheckContains(LSource, 'Result := nextpas.core.text.escape.JsonUnescapeToBuffer(ASrc, ALen, ADst, AError);',
    'facade json unescape routed to escape');
  CheckContains(LSource, 'Result := nextpas.core.text.grapheme.GraphemeNext(AData, ALen);',
    'facade grapheme routed to grapheme');
  CheckContains(LSource, 'Result := nextpas.core.text.width.CodepointWidth(ACodePoint);',
    'facade codepoint width routed to width');
  CheckContains(LSource, 'Result := nextpas.core.text.width.StringDisplayWidth(AData, ALen);',
    'facade display width routed to width');
  CheckContains(LSource, 'Result := nextpas.core.text.unicode.UTF8ToUpper(AValue);',
    'facade unicode upper routed to unicode');
  CheckContains(LSource, 'Result := nextpas.core.text.unicode.UTF8ToLower(AValue);',
    'facade unicode lower routed to unicode');
  CheckContains(LSource, 'Result := nextpas.core.text.unicode.UTF8CaseFold(AValue);',
    'facade unicode casefold routed to unicode');
  CheckContains(LSource, 'Result := nextpas.core.text.unicode.NFD(AValue);',
    'facade NFD routed to unicode');
  CheckContains(LSource, 'Result := nextpas.core.text.unicode.NFC(AValue);',
    'facade NFC routed to unicode');
  CheckContains(LSource, 'Result := nextpas.core.text.unicode.IsNormalizedNFC(AValue);',
    'facade IsNormalizedNFC routed to unicode');
end;

procedure TestUtilsOwnershipContracts;
var
  LConvSource: string;
  LUtilsSource: string;
begin
  LConvSource := LoadSourceText('../../../src/nextpas.core.text.conv.pas');
  LUtilsSource := LoadSourceText('../../../src/nextpas.core.text.utils.pas');

  CheckContains(LUtilsSource, 'function LowerCase(const S: string): string;',
    'utils publishes lower case owner');
  CheckContains(LUtilsSource,
    '@note ASCII-only. For Unicode-aware conversion use UTF8ToUpper/UTF8ToLower from text.unicode.',
    'utils ascii-only note');
  CheckContains(LConvSource, 'Result := nextpas.core.text.utils.Trim(AStr);',
    'conv trim forwards to utils');
  CheckContains(LConvSource, 'Result := nextpas.core.text.utils.TrimLeft(AStr);',
    'conv trim left forwards to utils');
  CheckContains(LConvSource, 'Result := nextpas.core.text.utils.TrimRight(AStr);',
    'conv trim right forwards to utils');
  CheckContains(LConvSource, 'Result := nextpas.core.text.utils.UpperCase(AStr);',
    'conv upper forwards to utils');
  CheckContains(LConvSource, 'Result := nextpas.core.text.utils.LowerCase(AStr);',
    'conv lower forwards to utils');
  CheckContains(LConvSource,
    'Result := nextpas.core.text.format.TextFormat(AFmt, AArgs);',
    'conv format compatibility delegates to text.format');
  CheckContains(LConvSource,
    '@note ASCII-only. For Unicode-aware conversion use UTF8ToUpper/UTF8ToLower from text.unicode.',
    'conv ascii-only note');
  CheckContains(LConvSource, 'Result := nextpas.core.text.utils.StringReplace(AStr, AOld, ANew, AAll);',
    'conv replace forwards to utils');
end;

procedure TestStringsConsumeUtilsHelpers;
var
  LSource: string;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.text.strings.pas');
  CheckContains(LSource, 'nextpas.core.text.utils',
    'strings uses utils unit');
  CheckContains(LSource, 'Result[i] := nextpas.core.text.utils.Trim(AArr[i]);',
    'strings trimall uses utils owner');
  CheckContains(LSource, 'Result[i] := nextpas.core.text.utils.UpperCase(AArr[i]);',
    'strings toupper uses utils owner');
  CheckContains(LSource, 'Result[i] := nextpas.core.text.utils.LowerCase(AArr[i]);',
    'strings tolower uses utils owner');
end;

procedure TestTextPerformanceContracts;
var
  LConvSource: string;
  LUtilsSource: string;
  LCompareSource: string;
begin
  LConvSource := LoadSourceText('../../../src/nextpas.core.text.conv.pas');
  LUtilsSource := LoadSourceText('../../../src/nextpas.core.text.utils.pas');
  LCompareSource := LoadSourceText('../../../src/nextpas.core.text.compare.pas');

  CheckContains(LConvSource, 'LStart', 'conv uses start index for trimming');
  Check(Pos('Delete(LTrimmed, 1, 1)', LConvSource) = 0,
    'conv must not delete leading whitespace one char at a time');
  Check(Pos('Delete(LTrimmed, Length(LTrimmed), 1)', LConvSource) = 0,
    'conv must not delete trailing whitespace one char at a time');

  CheckContains(LUtilsSource, 'TStringBuilder', 'utils replace uses string builder');
  Check(Pos('Result := Result + Copy(S, Start, P - Start) + NewPattern;', LUtilsSource) = 0,
    'utils replace must not rebuild result with repeated concatenation');

  CheckContains(LCompareSource, 'LFoldedSub', 'compare caches folded pattern');
  Check(Pos('if ToLower(Byte(AStr[I + J - 1])) <> ToLower(Byte(ASub[J])) then',
    LCompareSource) = 0, 'compare must not fold pattern byte for every subject comparison');
end;

procedure TestUTF8EncodeToStr;
begin
  CheckEqual('h', UTF8EncodeToStr(Ord('h')), 'ascii');
  CheckEqual(#$C3#$A9, UTF8EncodeToStr($E9), '2-byte e-acute');
  CheckEqual(#$E4#$B8#$AD, UTF8EncodeToStr($4E2D), '3-byte CJK');
  CheckEqual(#$F0#$9F#$98#$80, UTF8EncodeToStr($1F600), '4-byte emoji');
  CheckEqual('', UTF8EncodeToStr($D800), 'surrogate rejected');
  CheckEqual('', UTF8EncodeToStr($200000), 'out of range rejected');
end;

procedure TestUTF8TrimLastChar;
begin
  CheckEqual('a', UTF8TrimLastChar('ab'), 'ascii trim');
  CheckEqual('a', UTF8TrimLastChar('a' + #$E4#$B8#$AD), 'cjk trim');
  CheckEqual('a' + #$E4#$B8#$AD, UTF8TrimLastChar('a' + #$E4#$B8#$AD + #$F0#$9F#$98#$80), 'emoji trim');
  CheckEqual('', UTF8TrimLastChar(''), 'empty');
end;

procedure TestUTF8BytesRoundTrip;
var
  LB: TBytes;
begin
  { ASCII 往返 }
  LB := UTF8ToBytes('hello');
  CheckEqual(Int64(5), Int64(Length(LB)), 'ascii byte length');
  CheckEqual(Ord('h'), Integer(LB[0]), 'ascii first byte');
  CheckEqual('hello', BytesToUTF8(LB), 'ascii round trip');

  { 多字节 UTF-8 往返（e-acute / CJK / emoji） }
  LB := UTF8ToBytes(#$C3#$A9#$E4#$B8#$AD#$F0#$9F#$98#$80);
  CheckEqual(Int64(2 + 3 + 4), Int64(Length(LB)), 'multibyte total bytes');
  CheckEqual(Int64($C3), Int64(LB[0]), 'e-acute lead byte');
  CheckEqual(Int64($E4), Int64(LB[2]), 'cjk lead byte');
  CheckEqual(Int64($B8), Int64(LB[3]), 'cjk middle byte');
  CheckEqual(#$C3#$A9#$E4#$B8#$AD#$F0#$9F#$98#$80, BytesToUTF8(LB), 'multibyte round trip');

  { 空串/空数组 }
  LB := UTF8ToBytes('');
  CheckEqual(Int64(0), Int64(Length(LB)), 'empty string to empty bytes');
  CheckEqual('', BytesToUTF8(nil), 'empty bytes to empty string');

  { 含 NUL 的二进制往返（无损） }
  LB := UTF8ToBytes('a' + #0 + 'b');
  CheckEqual(Int64(3), Int64(Length(LB)), 'nul byte length preserved');
  CheckEqual(Ord('a'), Integer(LB[0]), 'nul first byte');
  CheckEqual(0, Integer(LB[1]), 'nul byte preserved');
  CheckEqual('a' + #0 + 'b', BytesToUTF8(LB), 'nul round trip');

  { 门面同语义 }
  CheckEqual('hello', BytesToUTF8(nextpas.core.text.UTF8ToBytes('hello')), 'facade round trip');
end;
begin
  T := TTestSuite.Create('nextpas.core.text');
  T.Test('Trim', @TestTrim);
  T.Test('TrimLeft', @TestTrimLeft);
  T.Test('TrimRight', @TestTrimRight);
  T.Test('StartsWith', @TestStartsWith);
  T.Test('EndsWith', @TestEndsWith);
  T.Test('Contains', @TestContains);
  T.Test('Split', @TestSplit);
  T.Test('Join', @TestJoin);
  T.Test('Replace', @TestReplace);
  T.Test('ReplaceAll', @TestReplaceAll);
  T.Test('ToUpper', @TestToUpper);
  T.Test('ToLower', @TestToLower);
  T.Test('PadLeft', @TestPadLeft);
  T.Test('PadRight', @TestPadRight);
  T.Test('Repeat', @TestRepeat);
  T.Test('IndexOf', @TestIndexOf);
  T.Test('LastIndexOf', @TestLastIndexOf);
  T.Test('IsEmpty', @TestIsEmpty);
  T.Test('IsBlank', @TestIsBlank);

  T.Test('UTF8Length', @TestUTF8Length);
  T.Test('UTF8CodePointAt', @TestUTF8CodePointAt);
  T.Test('UTF8EncodeToStr', @TestUTF8EncodeToStr);
  T.Test('UTF8TrimLastChar', @TestUTF8TrimLastChar);
  T.Test('UTF8BytesRoundTrip', @TestUTF8BytesRoundTrip);
  T.Test('UTF8 malformed consumes one byte', @TestUTF8MalformedConsumesOneByte);
  T.Test('Utils surface', @TestUtilsSurface);
  T.Test('CopyStrToBuf', @TestCopyStrToBuf);
  T.Test('CStrToStr', @TestCStrToStr);
  T.Test('Facade extended surface', @TestFacadeExtendedSurface);
  T.Test('Facade owner routing', @TestFacadeOwnerRouting);
  T.Test('Utils ownership contracts', @TestUtilsOwnershipContracts);
  T.Test('Strings consume utils helpers', @TestStringsConsumeUtilsHelpers);
  T.Test('Performance contracts', @TestTextPerformanceContracts);
  if not T.Run then Halt(1);
end.
