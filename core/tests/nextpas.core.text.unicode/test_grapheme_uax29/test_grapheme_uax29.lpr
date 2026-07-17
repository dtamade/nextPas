program test_grapheme_uax29;
{**
 * UAX #29 Grapheme Cluster Boundary tests (Unicode 16.0).
 *
 * Tests all GB rules:
 *   GB1:  sot ÷
 *   GB3:  CR × LF
 *   GB4:  (Control|CR|LF) ÷
 *   GB5:  ÷ (Control|CR|LF)
 *   GB6:  L × (L|V|LV|LVT)
 *   GB7:  (V|LV) × (V|T)
 *   GB8:  (LVT|T) × T
 *   GB9:  × (Extend|ZWJ)
 *   GB9a: × SpacingMark
 *   GB9b: Prepend ×
 *   GB11: Extended_Pictographic Extend* ZWJ × Extended_Pictographic
 *   GB12-13: Regional Indicator pairs
 *   GB999: ÷
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

{ ─── Helper: count grapheme clusters ─────────────────────────────── }

function CountGraphemes(const AText: string): SizeInt;
var
  LResults: TSegmentResultArray;
begin
  LResults := SegmentGraphemeClusters(AText);
  Result := Length(LResults);
end;

{ ─── GB3: CR × LF ───────────────────────────────────────────────── }

procedure TestGB3_CRLF;
begin
  // CR+LF should be a single grapheme cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$0D#$0A)), 'GB3: CR+LF = 1 cluster');
  // CR alone
  CheckEqual(Int64(1), Int64(CountGraphemes(#$0D)), 'GB3: CR alone = 1 cluster');
  // LF alone
  CheckEqual(Int64(1), Int64(CountGraphemes(#$0A)), 'GB3: LF alone = 1 cluster');
  // CR+CR is two clusters
  CheckEqual(Int64(2), Int64(CountGraphemes(#$0D#$0D)), 'GB3: CR+CR = 2 clusters');
  // LF+CR is two clusters
  CheckEqual(Int64(2), Int64(CountGraphemes(#$0A#$0D)), 'GB3: LF+CR = 2 clusters');
end;

{ ─── GB4/5: Control characters ───────────────────────────────────── }

procedure TestGB4_5_Control;
begin
  // Tab (U+0009) is Control
  CheckEqual(Int64(1), Int64(CountGraphemes(#$09)), 'GB4: Tab = 1 cluster');
  // Two tabs are separate clusters
  CheckEqual(Int64(2), Int64(CountGraphemes(#$09#$09)), 'GB4: Tab+Tab = 2 clusters');
  // BEL (U+0007) is Control
  CheckEqual(Int64(1), Int64(CountGraphemes(#$07)), 'GB4: BEL = 1 cluster');
  // Text around control: each control char is isolated
  CheckEqual(Int64(4), Int64(CountGraphemes('a'#$00#$01'b')), 'GB5: Control breaks text');
end;

{ ─── GB6: Hangul L jamo ──────────────────────────────────────────── }

procedure TestGB6_HangulL;
var
  LResults: TSegmentResultArray;
begin
  // L × L: 두 consonants should be one cluster
  // U+1100 (L) + U+1100 (L) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$E1#$84#$80#$E1#$84#$80)), 'GB6: L×L = 1 cluster');

  // L × V: consonant + vowel = 1 cluster
  // U+1100 (L) + U+1161 (V) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$E1#$84#$80#$E1#$85#$A1)), 'GB6: L×V = 1 cluster');

  // L × LV = 1 cluster
  // U+1100 (L) + U+AC00 (LV) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$E1#$84#$80#$EA#$B0#$80)), 'GB6: L×LV = 1 cluster');

  // L × LVT = 1 cluster
  // U+1100 (L) + U+AC01 (LVT) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$E1#$84#$80#$EA#$B0#$81)), 'GB6: L×LVT = 1 cluster');
end;

{ ─── GB7: Hangul V jamo ──────────────────────────────────────────── }

procedure TestGB7_HangulV;
begin
  // V × V = 1 cluster
  // U+1161 (V) + U+1161 (V) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$E1#$85#$A1#$E1#$85#$A1)), 'GB7: V×V = 1 cluster');

  // V × T = 1 cluster
  // U+1161 (V) + U+11A8 (T) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$E1#$85#$A1#$E1#$86#$A8)), 'GB7: V×T = 1 cluster');

  // LV × V = 1 cluster
  // U+AC00 (LV) + U+1161 (V) = 1 cluster (extends the syllable)
  CheckEqual(Int64(1), Int64(CountGraphemes(#$EA#$B0#$80#$E1#$85#$A1)), 'GB7: LV×V = 1 cluster');

  // LV × T = 1 cluster
  // U+AC00 (LV) + U+11A8 (T) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$EA#$B0#$80#$E1#$86#$A8)), 'GB7: LV×T = 1 cluster');
end;

{ ─── GB8: Hangul T jamo ──────────────────────────────────────────── }

procedure TestGB8_HangulT;
begin
  // LVT × T = 1 cluster
  // U+AC01 (LVT) + U+11A8 (T) = 1 cluster (extends the trailing)
  CheckEqual(Int64(1), Int64(CountGraphemes(#$EA#$B0#$81#$E1#$86#$A8)), 'GB8: LVT×T = 1 cluster');

  // T × T = 1 cluster
  // U+11A8 (T) + U+11A8 (T) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$E1#$86#$A8#$E1#$86#$A8)), 'GB8: T×T = 1 cluster');
end;

{ ─── GB9: Extend and ZWJ ────────────────────────────────────────── }

procedure TestGB9_Extend;
var
  LResults: TSegmentResultArray;
begin
  // Base + combining mark (Extend) = 1 cluster
  // U+0061 (a) + U+0301 (combining acute) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes('a'#$CC#$81)), 'GB9: a+combining acute = 1 cluster');

  // Base + multiple combining marks = 1 cluster
  // U+0061 (a) + U+0301 (acute) + U+0308 (diaeresis) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes('a'#$CC#$81#$CC#$88)), 'GB9: a+2 combining marks = 1 cluster');

  // Base + Extend + Extend = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes('e'#$CC#$81#$CC#$88)), 'GB9: e+2 combining marks = 1 cluster');
end;

procedure TestGB9_ZWJ;
begin
  // ZWJ between emoji = 1 cluster (if Extended_Pictographic on both sides)
  // U+1F468 (👨) + U+200D (ZWJ) + U+1F469 (👩) = 1 cluster
  // This tests GB11, but ZWJ itself is tested via GB9
  CheckEqual(Int64(1), Int64(CountGraphemes(#$F0#$9F#$91#$A8#$E2#$80#$8D#$F0#$9F#$91#$A9)),
    'GB9+11: emoji ZWJ emoji = 1 cluster');
end;

{ ─── GB9a: SpacingMark ───────────────────────────────────────────── }

procedure TestGB9a_SpacingMark;
begin
  // U+0915 (क Devanagari Ka) + U+093E (ा Aa vowel sign, SpacingMark) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$E0#$A4#$95#$E0#$A4#$BE)),
    'GB9a: Devanagari Ka+Aa = 1 cluster');

  // U+0915 (क) + U+093F (ि I vowel sign, SpacingMark) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$E0#$A4#$95#$E0#$A4#$BF)),
    'GB9a: Devanagari Ka+I = 1 cluster');
end;

{ ─── GB11: Emoji ZWJ sequences ───────────────────────────────────── }

procedure TestGB11_EmojiZWJ;
begin
  // 👨‍👩‍👧‍👦 = 👨 ZWJ 👩 ZWJ 👧 ZWJ 👦 (family emoji)
  // Should be 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(
    #$F0#$9F#$91#$A8 + // 👨
    #$E2#$80#$8D +      // ZWJ
    #$F0#$9F#$91#$A9 + // 👩
    #$E2#$80#$8D +      // ZWJ
    #$F0#$9F#$91#$A7 + // 👧
    #$E2#$80#$8D +      // ZWJ
    #$F0#$9F#$91#$A6)), // 👦
    'GB11: family emoji = 1 cluster');

  // 👩‍🔬 = 👩 ZWJ 🔬 (woman scientist)
  CheckEqual(Int64(1), Int64(CountGraphemes(
    #$F0#$9F#$91#$A9 + // 👩
    #$E2#$80#$8D +      // ZWJ
    #$F0#$9F#$94#$AC)), // 🔬
    'GB11: woman scientist = 1 cluster');

  // 🏳️‍🌈 = 🏳 ZWJ 🌈 (rainbow flag)
  // Note: 🏳 has variation selector U+FE0F (Extend) between
  CheckEqual(Int64(1), Int64(CountGraphemes(
    #$F0#$9F#$8F#$B3 + // 🏳
    #$EF#$B8#$8F +      // U+FE0F (Extend)
    #$E2#$80#$8D +      // ZWJ
    #$F0#$9F#$8C#$88)), // 🌈
    'GB11: rainbow flag = 1 cluster');
end;

{ ─── GB12-13: Regional Indicator ─────────────────────────────────── }

procedure TestGB12_13_RegionalIndicator;
begin
  // 🇺🇸 = U+1F1FA U+1F1F8 (US flag) = 1 cluster (RI pair)
  CheckEqual(Int64(1), Int64(CountGraphemes(
    #$F0#$9F#$87#$BA + // U+1F1FA
    #$F0#$9F#$87#$B8)), // U+1F1F8
    'GB12: US flag = 1 cluster');

  // 🇯🇵 = U+1F1EF U+1F1F5 (Japan flag) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(
    #$F0#$9F#$87#$AF + // U+1F1EF
    #$F0#$9F#$87#$B5)), // U+1F1F5
    'GB12: Japan flag = 1 cluster');

  // Two flags = 2 clusters (4 RI = 2 pairs)
  CheckEqual(Int64(2), Int64(CountGraphemes(
    #$F0#$9F#$87#$BA + // U+1F1FA
    #$F0#$9F#$87#$B8 + // U+1F1F8
    #$F0#$9F#$87#$AF + // U+1F1EF
    #$F0#$9F#$87#$B5)), // U+1F1F5
    'GB13: two flags = 2 clusters');

  // Single RI alone = 1 cluster (odd count)
  CheckEqual(Int64(1), Int64(CountGraphemes(
    #$F0#$9F#$87#$BA)), // U+1F1FA alone
    'GB12: single RI = 1 cluster');
end;

{ ─── Mixed complex scenarios ─────────────────────────────────────── }

procedure TestMixed_Scenarios;
begin
  // ASCII text: each character is a cluster
  CheckEqual(Int64(5), Int64(CountGraphemes('Hello')), 'Mixed: ASCII = 5 clusters');

  // CJK: each character is a cluster
  CheckEqual(Int64(3), Int64(CountGraphemes('你好世')), 'Mixed: CJK = 3 clusters');

  // Mixed ASCII + combining marks
  CheckEqual(Int64(4), Int64(CountGraphemes('cafe'#$CC#$81)), 'Mixed: cafe+acute = 4 clusters');

  // Hangul syllable (pre-composed) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(#$ED#$95#$9C)), 'Mixed: Hangul 한 = 1 cluster');

  // Hangul decomposed (L+V+T) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(
    #$E1#$84#$92 + // ㅎ (L)
    #$E1#$85#$A1 + // ㅏ (V)
    #$E1#$86#$AB)), // ㄴ (T)
    'Mixed: Hangul decomposed = 1 cluster');

  // Emoji with skin tone modifier = 1 cluster
  // U+1F44B (👋) + U+1F3FD (🏽 medium skin tone, Extend)
  CheckEqual(Int64(1), Int64(CountGraphemes(
    #$F0#$9F#$91#$8B + // 👋
    #$F0#$9F#$8F#$BD)), // 🏽
    'Mixed: emoji+skin tone = 1 cluster');

  // Keycap sequence: # + U+FE0F (Extend) + U+20E3 (Extend) = 1 cluster
  CheckEqual(Int64(1), Int64(CountGraphemes(
    '#' +           // U+0023
    #$EF#$B8#$8F +  // U+FE0F (Extend)
    #$E2#$83#$A3)),  // U+20E3 (Enclosing Mark → Extend in GCB)
    'Mixed: keycap # = 1 cluster');
end;

{ ─── GCB property lookup ─────────────────────────────────────────── }

procedure TestGCB_PropertyLookup;
begin
  // CR
  CheckEqual(Int64(Ord(gbpCR)), Int64(Ord(GetGraphemeBreakProperty($000D))), 'GCB: CR=$000D');
  // LF
  CheckEqual(Int64(Ord(gbpLF)), Int64(Ord(GetGraphemeBreakProperty($000A))), 'GCB: LF=$000A');
  // Control
  CheckEqual(Int64(Ord(gbpControl)), Int64(Ord(GetGraphemeBreakProperty($0000))), 'GCB: NUL=$0000');
  CheckEqual(Int64(Ord(gbpControl)), Int64(Ord(GetGraphemeBreakProperty($001F))), 'GCB: US=$001F');
  // Extend (combining acute)
  CheckEqual(Int64(Ord(gbpExtend)), Int64(Ord(GetGraphemeBreakProperty($0301))), 'GCB: combining acute=$0301');
  // ZWJ
  CheckEqual(Int64(Ord(gbpZWJ)), Int64(Ord(GetGraphemeBreakProperty($200D))), 'GCB: ZWJ=$200D');
  // Regional Indicator
  CheckEqual(Int64(Ord(gbpRegionalIndicator)), Int64(Ord(GetGraphemeBreakProperty($1F1E6))), 'GCB: RI=$1F1E6');
  // Hangul L
  CheckEqual(Int64(Ord(gbpL)), Int64(Ord(GetGraphemeBreakProperty($1100))), 'GCB: L=$1100');
  // Hangul V
  CheckEqual(Int64(Ord(gbpV)), Int64(Ord(GetGraphemeBreakProperty($1161))), 'GCB: V=$1161');
  // Hangul T
  CheckEqual(Int64(Ord(gbpT)), Int64(Ord(GetGraphemeBreakProperty($11A8))), 'GCB: T=$11A8');
  // Hangul LV
  CheckEqual(Int64(Ord(gbpLV)), Int64(Ord(GetGraphemeBreakProperty($AC00))), 'GCB: LV=$AC00');
  // Hangul LVT
  CheckEqual(Int64(Ord(gbpLVT)), Int64(Ord(GetGraphemeBreakProperty($AC01))), 'GCB: LVT=$AC01');
  // Extended_Pictographic (emoji)
  CheckEqual(Int64(Ord(gbpExtendedPictographic)), Int64(Ord(GetGraphemeBreakProperty($1F600))), 'GCB: EP=$1F600');
  // SpacingMark (Devanagari vowel sign Aa)
  CheckEqual(Int64(Ord(gbpSpacingMark)), Int64(Ord(GetGraphemeBreakProperty($093E))), 'GCB: SM=$093E');
  // Other (ASCII letter)
  CheckEqual(Int64(Ord(gbpOther)), Int64(Ord(GetGraphemeBreakProperty(Ord('A')))), 'GCB: A=Other');
end;

{ ─── Edge cases ──────────────────────────────────────────────────── }

procedure TestEdgeCases;
begin
  // Empty string
  CheckEqual(Int64(0), Int64(CountGraphemes('')), 'Edge: empty = 0 clusters');

  // Single ASCII character
  CheckEqual(Int64(1), Int64(CountGraphemes('A')), 'Edge: single A = 1 cluster');

  // Single CJK character
  CheckEqual(Int64(1), Int64(CountGraphemes(#$E4#$B8#$AD)), 'Edge: single 中 = 1 cluster');

  // Single emoji
  CheckEqual(Int64(1), Int64(CountGraphemes(#$F0#$9F#$98#$80)), 'Edge: single 😀 = 1 cluster');

  // Multiple newlines
  CheckEqual(Int64(3), Int64(CountGraphemes(#$0A#$0A#$0A)), 'Edge: 3 newlines = 3 clusters');

  // CR+LF in context
  CheckEqual(Int64(5), Int64(CountGraphemes('a'#$0D#$0A'b'#$0D#$0A'c')),
    'Edge: text with CRLF = 5 clusters');
end;

{ ─── Main ────────────────────────────────────────────────────────── }

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.grapheme.uax29');
  T.Test('GB3: CR+LF', @TestGB3_CRLF);
  T.Test('GB4/5: Control', @TestGB4_5_Control);
  T.Test('GB6: Hangul L', @TestGB6_HangulL);
  T.Test('GB7: Hangul V', @TestGB7_HangulV);
  T.Test('GB8: Hangul T', @TestGB8_HangulT);
  T.Test('GB9: Extend', @TestGB9_Extend);
  T.Test('GB9: ZWJ', @TestGB9_ZWJ);
  T.Test('GB9a: SpacingMark', @TestGB9a_SpacingMark);
  T.Test('GB11: Emoji ZWJ', @TestGB11_EmojiZWJ);
  T.Test('GB12-13: Regional Indicator', @TestGB12_13_RegionalIndicator);
  T.Test('Mixed scenarios', @TestMixed_Scenarios);
  T.Test('GCB property lookup', @TestGCB_PropertyLookup);
  T.Test('Edge cases', @TestEdgeCases);
  if not T.Run then Halt(1);
end.
