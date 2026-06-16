program test_text_compare;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.base,
  nextpas.core.text.compare;

var
  T: TTestRunner;

procedure AppendUtf8(var ADst: string; const ACp: TUnicodeCodepoint);
var
  LBuf: array[0..3] of Byte;
  LLen: Byte;
  LOldLen: SizeInt;
  I: Byte;
begin
  LLen := UTF8Encode(ACp, @LBuf[0]);
  Check(LLen > 0, 'test codepoint must be UTF-8 encodable');

  LOldLen := Length(ADst);
  SetLength(ADst, LOldLen + LLen);
  for I := 0 to LLen - 1 do
    ADst[LOldLen + I + 1] := AnsiChar(LBuf[I]);
end;

function Utf8Of(const ACps: array of TUnicodeCodepoint): string;
var
  I: SizeInt;
begin
  Result := '';
  for I := 0 to High(ACps) do
    AppendUtf8(Result, ACps[I]);
end;

function GermanStreetLower: string;
begin
  Result := 'Stra' + Utf8Of([$00DF]) + 'e';
end;

procedure TestTextCompareAscii;
begin
  CheckEqual(Int64(0), Int64(TextCompare('', '')), 'empty equal');
  CheckEqual(Int64(-1), Int64(TextCompare('', 'a')), 'empty shorter');
  CheckEqual(Int64(1), Int64(TextCompare('a', '')), 'non-empty longer');
  CheckEqual(Int64(0), Int64(TextCompare('alpha', 'alpha')), 'same string');
  CheckEqual(Int64(-1), Int64(TextCompare('abc', 'abd')), 'lexicographic less');
  CheckEqual(Int64(1), Int64(TextCompare('abd', 'abc')), 'lexicographic greater');
  CheckEqual(Int64(-1), Int64(TextCompare('abc', 'abcd')), 'shared prefix shorter');
  CheckEqual(Int64(1), Int64(TextCompare('abcd', 'abc')), 'shared prefix longer');
end;

procedure TestTextCompareCaseInsensitive;
begin
  CheckEqual(Int64(0), Int64(TextCompareI('', '')), 'empty equal ignore case');
  CheckEqual(Int64(0), Int64(TextCompareI('Alpha', 'aLPHA')), 'letters ignore case');
  CheckEqual(Int64(0), Int64(TextCompareI('a-b_1', 'A-B_1')), 'punctuation unchanged');
  CheckEqual(Int64(-1), Int64(TextCompareI('abc', 'AbD')), 'less ignore case');
  CheckEqual(Int64(1), Int64(TextCompareI('AbD', 'abc')), 'greater ignore case');
  CheckEqual(Int64(-1), Int64(TextCompareI('abc', 'ABCD')), 'shared prefix shorter ignore case');
  CheckEqual(Int64(1), Int64(TextCompareI('ABCD', 'abc')), 'shared prefix longer ignore case');
end;

procedure TestTextEqual;
begin
  Check(TextEqual('', ''), 'empty equal');
  Check(TextEqual('same', 'same'), 'same value');
  Check(not TextEqual('same', 'Same'), 'case sensitive mismatch');
  Check(not TextEqual('same', 'same '), 'length mismatch');
end;

procedure TestTextEqualIgnoreCase;
begin
  Check(TextEqualI('', ''), 'empty equal ignore case');
  Check(TextEqualI('Header', 'header'), 'letters ignore case');
  Check(TextEqualI('a-b', 'A-B'), 'punctuation ignore case');
  Check(not TextEqualI('Header', 'headers'), 'length mismatch ignore case');
  Check(not TextEqualI('Header', 'hedger'), 'content mismatch ignore case');
end;

procedure TestTextEqualCanonical;
begin
  Check(TextEqualCanonical('', ''), 'empty canonical equality');
  Check(TextEqualCanonical(Utf8Of([$00C5]), Utf8Of([$0041, $030A])), 'A ring canonical equality');
  Check(TextEqualCanonical(Utf8Of([$212B]), Utf8Of([$00C5])), 'angstrom sign canonical equality');
  Check(not TextEqualCanonical(Utf8Of([$00C5]), Utf8Of([$0041, $0301])), 'different combining marks are not canonical equal');
end;

procedure TestTextEqualCaseFoldUnicode;
begin
  Check(TextEqualCaseFold('', ''), 'empty case fold equality');
  Check(TextEqualCaseFold(GermanStreetLower, 'STRASSE'), 'sharp s case fold equality');
  Check(TextEqualCaseFold(Utf8Of([$0130]), 'i' + Utf8Of([$0307])), 'capital I with dot case fold equality');
  Check(not TextEqualCaseFold(Utf8Of([$03A9]), Utf8Of([$03C3])), 'omega and sigma stay different');
end;

procedure TestTextCompareUnicodeCaseFold;
begin
  CheckEqual(Int64(0), Int64(TextCompareI(Utf8Of([$0130]), 'i')), 'capital I with dot compare ignore case');
  Check(TextEqualI(Utf8Of([$03A9]), Utf8Of([$03C9])), 'omega equal ignore case');
  CheckEqual(Int64(-1), Int64(TextCompareI(Utf8Of([$00E4]), Utf8Of([$00F6]))), 'unicode compare remains lexicographic after fold');
end;

procedure TestTextStartsWithAscii;
begin
  Check(TextStartsWith('prefix-body', 'prefix'), 'prefix match');
  Check(TextStartsWith('exact', 'exact'), 'exact match');
  Check(TextStartsWith('value', ''), 'empty prefix');
  Check(not TextStartsWith('', 'x'), 'empty value');
  Check(not TextStartsWith('short', 'shorter'), 'prefix longer than value');
  Check(not TextStartsWith('prefix-body', 'Prefix'), 'case sensitive mismatch');
end;

procedure TestTextStartsWithIgnoreCase;
begin
  Check(TextStartsWithI('Prefix-Body', 'prefix'), 'prefix ignore case');
  Check(TextStartsWithI('exact', 'EXACT'), 'exact ignore case');
  Check(TextStartsWithI('value', ''), 'empty prefix ignore case');
  Check(not TextStartsWithI('', 'x'), 'empty value ignore case');
  Check(not TextStartsWithI('short', 'shorter'), 'prefix longer ignore case');
  Check(not TextStartsWithI('prefix-body', 'suffix'), 'content mismatch ignore case');
end;

procedure TestTextEndsWithAscii;
begin
  Check(TextEndsWith('body-suffix', 'suffix'), 'suffix match');
  Check(TextEndsWith('exact', 'exact'), 'exact suffix match');
  Check(TextEndsWith('value', ''), 'empty suffix');
  Check(not TextEndsWith('', 'x'), 'empty value for suffix');
  Check(not TextEndsWith('short', 'longer'), 'suffix longer than value');
  Check(not TextEndsWith('body-suffix', 'Suffix'), 'case sensitive suffix mismatch');
end;

procedure TestTextEndsWithIgnoreCase;
begin
  Check(TextEndsWithI('body-Suffix', 'suffix'), 'suffix ignore case');
  Check(TextEndsWithI('exact', 'EXACT'), 'exact suffix ignore case');
  Check(TextEndsWithI('value', ''), 'empty suffix ignore case');
  Check(not TextEndsWithI('', 'x'), 'empty value suffix ignore case');
  Check(not TextEndsWithI('short', 'longer'), 'suffix longer ignore case');
  Check(not TextEndsWithI('body-suffix', 'prefix'), 'content mismatch suffix ignore case');
end;

procedure TestTextContainsAscii;
begin
  Check(TextContains('alpha beta gamma', 'beta'), 'middle substring');
  Check(TextContains('alpha beta gamma', 'alpha'), 'prefix substring');
  Check(TextContains('alpha beta gamma', 'gamma'), 'suffix substring');
  Check(TextContains('value', ''), 'empty substring');
  Check(TextContains('value', 'value'), 'exact substring');
  Check(not TextContains('value', 'VALUE'), 'case sensitive contains mismatch');
  Check(not TextContains('short', 'longer'), 'substring longer than value');
end;

procedure TestTextContainsIgnoreCase;
begin
  Check(TextContainsI('Alpha Beta Gamma', 'beta'), 'middle substring ignore case');
  Check(TextContainsI('Alpha Beta Gamma', 'ALPHA'), 'prefix substring ignore case');
  Check(TextContainsI('Alpha Beta Gamma', 'gAmMa'), 'suffix substring ignore case');
  Check(TextContainsI('value', ''), 'empty substring ignore case');
  Check(TextContainsI('value', 'VALUE'), 'exact substring ignore case');
  Check(not TextContainsI('value', 'values'), 'substring longer ignore case');
  Check(not TextContainsI('value', 'delta'), 'missing substring ignore case');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.compare');
  T.Run('TextCompare ASCII', @TestTextCompareAscii);
  T.Run('TextCompareI ASCII', @TestTextCompareCaseInsensitive);
  T.Run('TextEqual', @TestTextEqual);
  T.Run('TextEqualI', @TestTextEqualIgnoreCase);
  T.Run('TextEqualCanonical', @TestTextEqualCanonical);
  T.Run('TextEqualCaseFold', @TestTextEqualCaseFoldUnicode);
  T.Run('TextCompareI Unicode', @TestTextCompareUnicodeCaseFold);
  T.Run('TextStartsWith', @TestTextStartsWithAscii);
  T.Run('TextStartsWithI', @TestTextStartsWithIgnoreCase);
  T.Run('TextEndsWith', @TestTextEndsWithAscii);
  T.Run('TextEndsWithI', @TestTextEndsWithIgnoreCase);
  T.Run('TextContains', @TestTextContainsAscii);
  T.Run('TextContainsI', @TestTextContainsIgnoreCase);
  T.Summary;
end.
