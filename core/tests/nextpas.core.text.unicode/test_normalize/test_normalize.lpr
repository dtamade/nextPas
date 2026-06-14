program test_normalize;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode;

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

function InvalidUtf8SurrogateBytes: string;
begin
  SetLength(Result, 3);
  Result[1] := AnsiChar($ED);
  Result[2] := AnsiChar($A0);
  Result[3] := AnsiChar($80);
end;

procedure TestCanonicalDecomposition;
begin
  CheckEqual(Utf8Of([$0065, $0301]), NFD(Utf8Of([$00E9])), 'e acute decomposes');
  CheckEqual(Utf8Of([$0041, $030A]), NFD(Utf8Of([$212B])), 'angstrom recursively decomposes');
  CheckEqual(Utf8Of([$1EAF]), NFC(NFD(Utf8Of([$1EAF]))), 'U+1EAF round-trips through NFC');
end;

procedure TestCanonicalComposition;
begin
  CheckEqual(Utf8Of([$00E9]), NFC(Utf8Of([$0065, $0301])), 'e acute composes');
  CheckEqual(Utf8Of([$00C5]), NFC(Utf8Of([$0041, $030A])), 'A ring composes to U+00C5');
end;

procedure TestCanonicalOrdering;
begin
  CheckEqual(Utf8Of([$0044, $0323, $0307]), NFD(Utf8Of([$0044, $0307, $0323])),
    'combining marks reorder by CCC');
  CheckEqual(Utf8Of([$1E0C, $0307]), NFC(Utf8Of([$0044, $0307, $0323])),
    'composition runs after canonical reordering');
end;

procedure TestCompatibilityForms;
begin
  CheckEqual(Utf8Of([$210C]), NFD(Utf8Of([$210C])), 'black-letter H stays in NFD');
  CheckEqual('H', NFKD(Utf8Of([$210C])), 'black-letter H compatibility decomposes');
  CheckEqual('H', NFKC(Utf8Of([$210C])), 'black-letter H compatibility composes to ASCII H');
end;

procedure TestHangulNormalization;
begin
  CheckEqual(Utf8Of([$1100, $1161, $11A8]), NFD(Utf8Of([$AC01])), 'Hangul syllable decomposes algorithmically');
  CheckEqual(Utf8Of([$AC01]), NFC(Utf8Of([$1100, $1161, $11A8])), 'Hangul Jamo compose algorithmically');
end;

procedure TestAsciiAndEmpty;
const
  LAscii = 'ASCII only 123';
begin
  CheckEqual('', NFD(''), 'empty NFD');
  CheckEqual('', NFC(''), 'empty NFC');
  CheckEqual('', NFKD(''), 'empty NFKD');
  CheckEqual('', NFKC(''), 'empty NFKC');
  CheckEqual(LAscii, NFD(LAscii), 'ASCII NFD fast path');
  CheckEqual(LAscii, NFC(LAscii), 'ASCII NFC fast path');
  CheckEqual(LAscii, NFKD(LAscii), 'ASCII NFKD fast path');
  CheckEqual(LAscii, NFKC(LAscii), 'ASCII NFKC fast path');
end;

procedure TestIdempotenceAndQuickChecks;
var
  LDecomposed: string;
begin
  LDecomposed := Utf8Of([$0061, $0306, $0301]);
  CheckEqual(LDecomposed, NFD(NFD(Utf8Of([$1EAF]))), 'NFD idempotent for U+1EAF');
  CheckEqual(Utf8Of([$1EAF]), NFC(NFC(Utf8Of([$1EAF]))), 'NFC idempotent for U+1EAF');
  Check(IsNormalizedNFD(LDecomposed), 'decomposed form is normalized NFD');
  Check(not IsNormalizedNFD(Utf8Of([$00E9])), 'precomposed e acute is not normalized NFD');
  Check(IsNormalizedNFC(Utf8Of([$00E9])), 'precomposed e acute is normalized NFC');
  Check(not IsNormalizedNFC(Utf8Of([$0065, $0301])), 'decomposed e acute is not normalized NFC');
end;

procedure TestBoundaryBehavior;
begin
  CheckEqual(Utf8Of([$10FFFF]), NFD(Utf8Of([$10FFFF])), 'max codepoint stays stable in NFD');
  CheckEqual(Utf8Of([$10FFFF]), NFC(Utf8Of([$10FFFF])), 'max codepoint stays stable in NFC');
  CheckEqual(Utf8Of([$FFFD, $FFFD, $FFFD]), NFD(InvalidUtf8SurrogateBytes),
    'surrogate-like UTF-8 bytes normalize through replacement semantics');
  CheckEqual(Utf8Of([$FFFD, $FFFD, $FFFD]), NFC(InvalidUtf8SurrogateBytes),
    'surrogate-like UTF-8 bytes stay replacement chars after NFC');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.unicode.normalize');
  T.Run('canonical decomposition', @TestCanonicalDecomposition);
  T.Run('canonical composition', @TestCanonicalComposition);
  T.Run('canonical ordering', @TestCanonicalOrdering);
  T.Run('compatibility forms', @TestCompatibilityForms);
  T.Run('Hangul normalization', @TestHangulNormalization);
  T.Run('ASCII and empty inputs', @TestAsciiAndEmpty);
  T.Run('idempotence and quick checks', @TestIdempotenceAndQuickChecks);
  T.Run('boundary behavior', @TestBoundaryBehavior);
  T.Summary;
end.
