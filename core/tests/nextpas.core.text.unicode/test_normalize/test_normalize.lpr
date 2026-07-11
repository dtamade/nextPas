program test_normalize;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

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

procedure TestNFKDAndNFKC;
begin
  // NFKD/NFKC 检查
  Check(IsNormalizedNFKD('ASCII'), 'ASCII is NFKD');
  Check(IsNormalizedNFKC('ASCII'), 'ASCII is NFKC');
  Check(not IsNormalizedNFKD(Utf8Of([$210C])), 'black-letter H is not NFKD');
  Check(IsNormalizedNFKD('H'), 'H is NFKD');
  Check(not IsNormalizedNFKC(Utf8Of([$210C])), 'black-letter H is not NFKC');
  Check(IsNormalizedNFKC('H'), 'H is NFKC');
  // Hangul
  Check(IsNormalizedNFKD(Utf8Of([$1100, $1161, $11A8])), 'Hangul decomposed is NFKD');
  Check(not IsNormalizedNFKD(Utf8Of([$AC01])), 'Hangul composed is not NFKD');

  // QuickCheck NFKD
  Check(QuickCheckNFKD(''), 'empty is NFKD');
  Check(QuickCheckNFKD('ASCII'), 'ASCII is NFKD');
  Check(not QuickCheckNFKD(Utf8Of([$210C])), 'black-letter H is not NFKD (QuickCheck)');
  Check(not QuickCheckNFKD(Utf8Of([$00E9])), 'precomposed e acute is not NFKD (QuickCheck)');
  Check(QuickCheckNFKD(Utf8Of([$0061, $0301])), 'decomposed e acute is NFKD (QuickCheck)');
end;

procedure TestQuickCheck;
var
  LDecomposed: string;
begin
  // QuickCheck NFD
  Check(QuickCheckNFD(''), 'empty is NFD');
  Check(QuickCheckNFD('ASCII'), 'ASCII is NFD');
  LDecomposed := Utf8Of([$0061, $0306, $0301]);
  Check(QuickCheckNFD(LDecomposed), 'decomposed a+breve+acute is NFD');
  Check(not QuickCheckNFD(Utf8Of([$00E9])), 'precomposed e acute is not NFD');

  // NFD allows compatibility characters (they don't decompose canonically)
  Check(QuickCheckNFD(Utf8Of([$210C])), 'black-letter H is NFD (compat allowed)');

  // QuickCheck NFC
  Check(QuickCheckNFC(''), 'empty is NFC');
  Check(QuickCheckNFC('ASCII'), 'ASCII is NFC');
  Check(QuickCheckNFC(Utf8Of([$00E9])), 'precomposed e acute is NFC');
  Check(not QuickCheckNFC(Utf8Of([$0065, $0301])), 'decomposed e acute is not NFC');

  // QuickCheck should agree with full check
  CheckEqual(QuickCheckNFD(LDecomposed), IsNormalizedNFD(LDecomposed), 'QuickCheck NFD agrees');
  CheckEqual(QuickCheckNFC(Utf8Of([$00E9])), IsNormalizedNFC(Utf8Of([$00E9])), 'QuickCheck NFC agrees');
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

procedure TestCanonicalCombiningClass;
begin
  // Starter characters have CCC = 0
  CheckEqual(Int64(GetCanonicalCombiningClass(Ord('A'))), Int64(0), 'A CCC = 0');
  CheckEqual(Int64(GetCanonicalCombiningClass(Ord('a'))), Int64(0), 'a CCC = 0');
  CheckEqual(Int64(GetCanonicalCombiningClass($4E2D)), Int64(0), '中 CCC = 0');

  // Combining marks have CCC > 0
  Check(GetCanonicalCombiningClass($0301) > 0, 'combining acute CCC > 0'); // U+0301
  Check(GetCanonicalCombiningClass($0308) > 0, 'combining diaeresis CCC > 0'); // U+0308

  // CCC values: combining acute (230) and combining diaeresis (230) both ABOVE
  CheckEqual(Int64(GetCanonicalCombiningClass($0301)), Int64(230), 'combining acute CCC = 230');
  CheckEqual(Int64(GetCanonicalCombiningClass($0308)), Int64(230), 'combining diaeresis CCC = 230');

  // Different CCC: combining cedilla (202) vs combining acute (230)
  Check(GetCanonicalCombiningClass($0327) <> GetCanonicalCombiningClass($0301),
    'cedilla and acute have different CCC');
end;

{ === SMP Normalization === }

procedure TestSmpNormalization;
begin
  // CJK Extension B (U+20000) - should be stable
  CheckEqual(Utf8Of([$20000]), NFD(Utf8Of([$20000])), 'CJK Ext B NFD stable');
  CheckEqual(Utf8Of([$20000]), NFC(Utf8Of([$20000])), 'CJK Ext B NFC stable');
  CheckEqual(Utf8Of([$20000]), NFKD(Utf8Of([$20000])), 'CJK Ext B NFKD stable');
  CheckEqual(Utf8Of([$20000]), NFKC(Utf8Of([$20000])), 'CJK Ext B NFKC stable');
  Check(IsNormalizedNFD(Utf8Of([$20000])), 'CJK Ext B is NFD');
  Check(IsNormalizedNFC(Utf8Of([$20000])), 'CJK Ext B is NFC');

  // Math Bold A (U+1D400) - has compatibility decomposition
  Check(not IsNormalizedNFKD(Utf8Of([$1D400])), 'Math Bold A not NFKD');
  Check(not IsNormalizedNFKC(Utf8Of([$1D400])), 'Math Bold A not NFKC');
  Check(not QuickCheckNFKD(Utf8Of([$1D400])), 'Math Bold A not NFKD QuickCheck');

  // Musical Symbol (U+1D11E) - no decomposition, should be stable
  Check(IsNormalizedNFKD(Utf8Of([$1D11E])), 'Musical is NFKD (no decomposition)');
  Check(IsNormalizedNFKC(Utf8Of([$1D11E])), 'Musical is NFKC (no decomposition)');

  // Deseret (U+10400) - no decomposition, should be stable
  Check(IsNormalizedNFD(Utf8Of([$10400])), 'Deseret AY is NFD');
  Check(IsNormalizedNFC(Utf8Of([$10400])), 'Deseret AY is NFC');
end;

{ === Stress Test === }

procedure TestStressNormalization;
var
  LLong: string;
  LI: SizeInt;
  LNFD: string;
  LNFC: string;
begin
  // 1000 个 precomposed e-acute → 应全部分解
  LLong := '';
  for LI := 1 to 1000 do
    LLong := LLong + Utf8Of([$00E9]);
  LNFD := NFD(LLong);
  Check(Length(LNFD) > Length(LLong), 'NFD expanded 1000 e-acute');
  Check(IsNormalizedNFD(LNFD), 'NFD of 1000 e-acute is normalized');
  LNFC := NFC(LLong);
  CheckEqual(LLong, LNFC, 'NFC of precomposed is identity');
  Check(IsNormalizedNFC(LNFC), 'NFC of 1000 e-acute is normalized');

  // 500 个 CJK 字符 — 无分解，应保持不变
  LLong := '';
  for LI := 1 to 500 do
    LLong := LLong + Utf8Of([$4E00 + (LI mod 100)]);
  Check(IsNormalizedNFD(LLong), '500 CJK is NFD');
  Check(IsNormalizedNFC(LLong), '500 CJK is NFC');
  Check(IsNormalizedNFKD(LLong), '500 CJK is NFKD');
  Check(IsNormalizedNFKC(LLong), '500 CJK is NFKC');

  // 混合 combining marks: a + 10 combining acute
  LLong := Utf8Of([Ord('a')]);
  for LI := 1 to 10 do
    LLong := LLong + Utf8Of([$0301]);
  LNFD := NFD(LLong);
  Check(IsNormalizedNFD(LNFD), 'a + 10 acute is NFD');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.normalize');
  T.Test('canonical decomposition', @TestCanonicalDecomposition);
  T.Test('canonical composition', @TestCanonicalComposition);
  T.Test('canonical ordering', @TestCanonicalOrdering);
  T.Test('compatibility forms', @TestCompatibilityForms);
  T.Test('Hangul normalization', @TestHangulNormalization);
  T.Test('ASCII and empty inputs', @TestAsciiAndEmpty);
  T.Test('idempotence and quick checks', @TestIdempotenceAndQuickChecks);
  T.Test('NFKD and NFKC checks', @TestNFKDAndNFKC);
  T.Test('QuickCheck functions', @TestQuickCheck);
  T.Test('boundary behavior', @TestBoundaryBehavior);
  T.Test('canonical combining class', @TestCanonicalCombiningClass);
  T.Test('SMP normalization', @TestSmpNormalization);
  T.Test('stress normalization', @TestStressNormalization);
  if not T.Run then Halt(1);
end.
