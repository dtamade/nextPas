program test_text;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text,
  nextpas.core.text.utils;

var
  T: TTestRunner;

function LoadSourceText(const ARelativePath: string): string;
var
  LLines: TStringList;
begin
  Check(FileExists(ARelativePath), 'source file exists: ' + ARelativePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(ARelativePath);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
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
begin
  CheckEqual('   hi', TextPadLeft('hi', 5), 'pad spaces');
  CheckEqual('000hi', TextPadLeft('hi', 5, '0'), 'pad zeros');
  CheckEqual('hello', TextPadLeft('hello', 3), 'no pad needed');
end;

procedure TestPadRight;
begin
  CheckEqual('hi   ', TextPadRight('hi', 5), 'pad spaces');
  CheckEqual('hi000', TextPadRight('hi', 5, '0'), 'pad zeros');
  CheckEqual('hello', TextPadRight('hello', 3), 'no pad needed');
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
begin
  CheckEqual('hello', nextpas.core.text.utils.Trim('  hello  '), 'utils trim');
  CheckEqual('000hi', nextpas.core.text.utils.PadLeft('hi', 5, '0'), 'utils pad left');
  CheckEqual('hi000', nextpas.core.text.utils.PadRight('hi', 5, '0'), 'utils pad right');
  CheckEqual('abab', nextpas.core.text.utils.RepeatString('ab', 2), 'utils repeat');
  Check(nextpas.core.text.utils.IsEmpty(''), 'utils empty');
  Check(nextpas.core.text.utils.IsBlank(#9' '#10), 'utils blank');
end;

procedure TestFacadeExtendedSurface;
var
  LBuilder: TStringBuilder;
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
  LBuilder.Init(8);
  try
    LBuilder.AppendStr('he');
    LBuilder.AppendView(TStringView.FromStr('llo'));
    CheckEqual('hello', LBuilder.ToString, 'builder visible through facade');
  finally
    LBuilder.Done;
  end;

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
  CheckContains(LSource, 'TStringBuilder = nextpas.core.text.builder.TStringBuilder;',
    'facade builder type routed to builder');
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

begin
  T := TTestRunner.Create('nextpas.core.text');
  T.Run('Trim', @TestTrim);
  T.Run('TrimLeft', @TestTrimLeft);
  T.Run('TrimRight', @TestTrimRight);
  T.Run('StartsWith', @TestStartsWith);
  T.Run('EndsWith', @TestEndsWith);
  T.Run('Contains', @TestContains);
  T.Run('Split', @TestSplit);
  T.Run('Join', @TestJoin);
  T.Run('Replace', @TestReplace);
  T.Run('ReplaceAll', @TestReplaceAll);
  T.Run('ToUpper', @TestToUpper);
  T.Run('ToLower', @TestToLower);
  T.Run('PadLeft', @TestPadLeft);
  T.Run('PadRight', @TestPadRight);
  T.Run('Repeat', @TestRepeat);
  T.Run('IndexOf', @TestIndexOf);
  T.Run('LastIndexOf', @TestLastIndexOf);
  T.Run('IsEmpty', @TestIsEmpty);
  T.Run('IsBlank', @TestIsBlank);
  T.Run('UTF8Length', @TestUTF8Length);
  T.Run('UTF8CodePointAt', @TestUTF8CodePointAt);
  T.Run('UTF8 malformed consumes one byte', @TestUTF8MalformedConsumesOneByte);
  T.Run('Utils surface', @TestUtilsSurface);
  T.Run('Facade extended surface', @TestFacadeExtendedSurface);
  T.Run('Facade owner routing', @TestFacadeOwnerRouting);
  T.Run('Utils ownership contracts', @TestUtilsOwnershipContracts);
  T.Run('Strings consume utils helpers', @TestStringsConsumeUtilsHelpers);
  T.Run('Performance contracts', @TestTextPerformanceContracts);
  T.Summary;
end.
