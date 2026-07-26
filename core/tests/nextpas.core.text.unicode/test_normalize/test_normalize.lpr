program test_normalize;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.test,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

{$I ../test_helpers.inc}

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

{ === BMP Long Decompositions === }

procedure TestBmpLongDecompositions;
begin
  // U+FDFA: Arabic Sallallahu Alayhi Wasallam → 18 codepoints (compatibility decomposition)
  // NFD 不展开兼容性分解，需要用 NFKD
  CheckEqual(Utf8Of([$0635, $0644, $0649, $0020, $0627, $0644, $0644, $0647,
    $0020, $0639, $0644, $064A, $0647, $0020, $0648, $0633, $0644, $0645]),
    NFKD(Utf8Of([$FDFA])), 'U+FDFA NFKD = 18 Arabic codepoints');
  // NFD 保持兼容性字符不变
  CheckEqual(Utf8Of([$FDFA]), NFD(Utf8Of([$FDFA])), 'U+FDFA NFD stable (compat)');
  Check(not IsNormalizedNFKD(Utf8Of([$FDFA])), 'U+FDFA not NFKD');

  // U+FDFB: Arabic Jallajalalouhou → 8 codepoints (compatibility decomposition)
  CheckEqual(Utf8Of([$062C, $0644, $0020, $062C, $0644, $0627, $0644, $0647]),
    NFKD(Utf8Of([$FDFB])), 'U+FDFB NFKD = 8 Arabic codepoints');

  // U+2057: Quadruple Prime → 4 × U+2032 (compatibility decomposition)
  CheckEqual(Utf8Of([$2032, $2032, $2032, $2032]),
    NFKD(Utf8Of([$2057])), 'U+2057 NFKD = 4 primes');
  CheckEqual(Utf8Of([$2057]), NFD(Utf8Of([$2057])), 'U+2057 NFD stable (compat)');

  // U+2A0C: Quadruple Integral Operator → 4 × U+222B (compatibility decomposition)
  CheckEqual(Utf8Of([$222B, $222B, $222B, $222B]),
    NFKD(Utf8Of([$2A0C])), 'U+2A0C NFKD = 4 integrals');
  CheckEqual(Utf8Of([$2A0C]), NFD(Utf8Of([$2A0C])), 'U+2A0C NFD stable (compat)');
end;

{ === Hangul Normalization Edge Cases === }

procedure TestHangulNormalizationEdgeCases;
begin
  // LV-only syllable (no T): U+AC00 = L=1100, V=1161
  CheckEqual(Utf8Of([$1100, $1161]), NFD(Utf8Of([$AC00])),
    'U+AC00 (LV-only) NFD = L+V');
  CheckEqual(Utf8Of([$AC00]), NFC(Utf8Of([$1100, $1161])),
    'L+V NFC = LV syllable U+AC00');

  // Last LVT syllable: U+D7A3 = L=1112, V=1175, T=11C2
  CheckEqual(Utf8Of([$1112, $1175, $11C2]), NFD(Utf8Of([$D7A3])),
    'U+D7A3 (last LVT) NFD = L+V+T');
  CheckEqual(Utf8Of([$D7A3]), NFC(Utf8Of([$1112, $1175, $11C2])),
    'L+V+T NFC = last LVT syllable');

  // Jamo are starters, stable under NFD
  CheckEqual(Utf8Of([$1100]), NFD(Utf8Of([$1100])),
    'Leading Jamo U+1100 NFD stable');
  CheckEqual(Utf8Of([$1161]), NFD(Utf8Of([$1161])),
    'Vowel Jamo U+1161 NFD stable');
  CheckEqual(Utf8Of([$11A8]), NFD(Utf8Of([$11A8])),
    'Trailing Jamo U+11A8 NFD stable');

  // Jamo are already normalized
  Check(IsNormalizedNFD(Utf8Of([$1100])), 'Leading Jamo is NFD');
  Check(IsNormalizedNFC(Utf8Of([$1100])), 'Leading Jamo is NFC');

  // Composition of LV from two Jamo
  CheckEqual(Utf8Of([$AC00]), NFC(Utf8Of([$1100, $1161])),
    'L+V composes to first LV syllable');
  CheckEqual(Utf8Of([$AC01]), NFC(Utf8Of([$1100, $1161, $11A8])),
    'L+V+T composes to first LVT syllable');

  // L alone does not compose with T
  CheckEqual(Utf8Of([$1100, $11A8]), NFC(Utf8Of([$1100, $11A8])),
    'L+T does not compose (no V)');
end;

{ === Deprecated Decompositions === }

procedure TestDeprecatedDecompositions;
begin
  // U+0340: Combining Grave Tone Mark → U+0300 (canonical decomp = combining grave)
  CheckEqual(Utf8Of([$0300]), NFD(Utf8Of([$0340])),
    'U+0340 deprecated grave tone NFD = U+0300');

  // U+0341: Combining Acute Tone Mark → U+0301 (canonical decomp = combining acute)
  CheckEqual(Utf8Of([$0301]), NFD(Utf8Of([$0341])),
    'U+0341 deprecated acute tone NFD = U+0301');

  // U+0343: Combining Greek Koronis → U+0313 (canonical deprob = combining comma above)
  CheckEqual(Utf8Of([$0313]), NFD(Utf8Of([$0343])),
    'U+0343 Greek koronis NFD = U+0313');

  // U+0344: Combining Greek Dialytika Tonos → U+0308 + U+0301
  CheckEqual(Utf8Of([$0308, $0301]), NFD(Utf8Of([$0344])),
    'U+0344 dialytika tonos NFD = diaeresis + acute');

  // U+0387: Greek Ano Teleia → U+00B7 (middle dot)
  CheckEqual(Utf8Of([$00B7]), NFD(Utf8Of([$0387])),
    'U+0387 ano teleia NFD = middle dot U+00B7');

  // These deprecated characters should NOT appear in NFC output
  // (they are composition exclusions)
  Check(not IsNormalizedNFC(Utf8Of([$0340])), 'U+0340 not NFC');
  Check(not IsNormalizedNFC(Utf8Of([$0341])), 'U+0341 not NFC');
  Check(not IsNormalizedNFC(Utf8Of([$0344])), 'U+0344 not NFC');
  Check(not IsNormalizedNFC(Utf8Of([$0387])), 'U+0387 not NFC');
end;

{ === Composition Exclusions === }

procedure TestCompositionExclusions;
begin
  // U+0340-U+0344 are composition exclusions (deprecated chars)
  Check(IsCompositionExcluded($0340), 'U+0340 is composition exclusion');
  Check(IsCompositionExcluded($0341), 'U+0341 is composition exclusion');
  Check(IsCompositionExcluded($0343), 'U+0343 is composition exclusion');
  Check(IsCompositionExcluded($0344), 'U+0344 is composition exclusion');

  // U+0958-U+095F (Devanagari) have canonical decomposition to base+nukta
  // They are NOT singletons/non-starter decompositions, so not excluded by our check
  // In NFC, the decomposition components are processed normally
  Check(not IsCompositionExcluded($0958), 'U+0958 not excluded (base+nukta decomp)');
  Check(not IsCompositionExcluded($095F), 'U+095F not excluded (base+nukta decomp)');

  // U+FDFA and U+FDFB are composition exclusions (compat decomposable)
  Check(IsCompositionExcluded($FDFA), 'U+FDFA is composition exclusion');
  Check(IsCompositionExcluded($FDFB), 'U+FDFB is composition exclusion');

  // Hangul Jamo are excluded from composition
  Check(IsCompositionExcluded($1100), 'Leading Jamo excluded');
  Check(IsCompositionExcluded($1161), 'Vowel Jamo excluded');
  Check(IsCompositionExcluded($11A8), 'Trailing Jamo excluded');

  // Hangul syllables themselves are excluded
  Check(IsCompositionExcluded($AC00), 'Hangul syllable U+AC00 excluded');
  Check(IsCompositionExcluded($D7A3), 'Hangul syllable U+D7A3 excluded');

  // Regular characters are NOT excluded
  Check(not IsCompositionExcluded(Ord('A')), 'A is not excluded');
  Check(not IsCompositionExcluded($00E9), 'e acute is not excluded');
  Check(not IsCompositionExcluded($00C5), 'A ring is not excluded');
end;

{ === GetDecompositionMapping via Data Module === }

procedure TestGetDecompositionMapping;
var
  LDst: array[0..17] of TUnicodeCodepoint;
  LLen: Byte;
  LIsCompat: Boolean;
begin
  // No decomposition for ASCII
  CheckEqual(Byte(0), Byte(nextpas.core.text.unicode.GetDecompositionMapping(Ord('A'), LDst, LLen, LIsCompat)),
    'A has no decomposition');
  CheckEqual(Byte(0), LLen, 'A decomp len = 0');

  // Canonical decomposition: e acute → e + combining acute
  Check(nextpas.core.text.unicode.GetDecompositionMapping($00E9, LDst, LLen, LIsCompat),
    'e acute has decomposition');
  CheckEqual(Byte(2), LLen, 'e acute decomp len = 2');
  Check(not LIsCompat, 'e acute is canonical decomp');
  CheckEqual(TUnicodeCodepoint($0065), LDst[0], 'e acute decomp[0] = e');
  CheckEqual(TUnicodeCodepoint($0301), LDst[1], 'e acute decomp[1] = combining acute');

  // Long decomposition: U+FDFA → 18 codepoints
  Check(nextpas.core.text.unicode.GetDecompositionMapping($FDFA, LDst, LLen, LIsCompat),
    'U+FDFA has decomposition');
  CheckEqual(Byte(18), LLen, 'U+FDFA decomp len = 18');
  CheckEqual(TUnicodeCodepoint($0635), LDst[0], 'U+FDFA decomp[0] = sad');
  CheckEqual(TUnicodeCodepoint($0645), LDst[17], 'U+FDFA decomp[17] = mim');

  // Compatibility: U+210C (black-letter H) → H
  Check(nextpas.core.text.unicode.GetDecompositionMapping($210C, LDst, LLen, LIsCompat),
    'black-letter H has decomposition');
  Check(LIsCompat, 'black-letter H is compat decomp');
  CheckEqual(Byte(1), LLen, 'black-letter H decomp len = 1');
  CheckEqual(TUnicodeCodepoint($0048), LDst[0], 'black-letter H decomp[0] = H');
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
  T.Test('BMP long decompositions', @TestBmpLongDecompositions);
  T.Test('Hangul normalization edge cases', @TestHangulNormalizationEdgeCases);
  T.Test('deprecated decompositions', @TestDeprecatedDecompositions);
  T.Test('composition exclusions', @TestCompositionExclusions);
  T.Test('GetDecompositionMapping API', @TestGetDecompositionMapping);
  T.Test('stress normalization', @TestStressNormalization);
  if not T.Run then Halt(1);
end.
