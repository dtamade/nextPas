program test_confusable;

{**
 * UTS#39 §4 confusable detection — unit suite.
 *
 * Covers the MA-table lookup (GetConfusablePrototype), the skeleton
 * transform (ConfusableSkeleton) and the pairwise confusability predicate
 * (AreConfusable) with hand-picked homograph anchors.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.unicode;

const
  MAXLEN = CONFUSABLE_MAX_PROTOTYPE; { 18 — longest prototype in the table }

var
  T: TTestSuite;

procedure TestUnknownEntry;
var
  LBuf: array[0..MAXLEN - 1] of TUnicodeCodepoint;
  LLen: Byte;
begin
  { CPs absent from the MA table must report False (own prototype). }
  Check(not GetConfusablePrototype($0041, LBuf, LLen), 'A unmapped');
  Check(not GetConfusablePrototype($007A, LBuf, LLen), 'z unmapped');
  Check(not GetConfusablePrototype($0033, LBuf, LLen), 'digit 3 unmapped');
  Check(not GetConfusablePrototype($0378, LBuf, LLen), 'unassigned unmapped');
end;

procedure TestBufferTooSmall;
var
  LSmall: array[0..1] of TUnicodeCodepoint;
  LLen: Byte;
begin
  { U+FDFA prototype is 18 cps; a 2-slot buffer must fail closed. }
  Check(not GetConfusablePrototype($FDFA, LSmall, LLen), 'FDFA too-small buf rejected');
  CheckEqual(Int64(0), Int64(LLen), 'len untouched on too-small');
end;

procedure TestBasicMappings;
var
  LBuf: array[0..MAXLEN - 1] of TUnicodeCodepoint;
  LLen: Byte;
begin
  { Cyrillic а (0430) → Latin a (0061) }
  Check(GetConfusablePrototype($0430, LBuf, LLen), 'cyrillic a found');
  CheckEqual(Int64(1), Int64(LLen), 'cyrillic a len');
  CheckEqual(Int64($0061), Int64(LBuf[0]), 'cyrillic a target');

  { Cyrillic р (0440) → Latin p (0070) }
  Check(GetConfusablePrototype($0440, LBuf, LLen), 'cyrillic p found');
  CheckEqual(Int64(1), Int64(LLen), 'cyrillic p len');
  CheckEqual(Int64($0070), Int64(LBuf[0]), 'cyrillic p target');

  { Greek omicron (03BF) → Latin o (006F) }
  Check(GetConfusablePrototype($03BF, LBuf, LLen), 'greek o found');
  CheckEqual(Int64(1), Int64(LLen), 'greek o len');
  CheckEqual(Int64($006F), Int64(LBuf[0]), 'greek o target');

  { dotless ı (0131) → Latin i (0069) }
  Check(GetConfusablePrototype($0131, LBuf, LLen), 'dotless i found');
  CheckEqual(Int64(1), Int64(LLen), 'dotless i len');
  CheckEqual(Int64($0069), Int64(LBuf[0]), 'dotless i target');
end;

procedure TestMultiPrototype;
var
  LBuf: array[0..MAXLEN - 1] of TUnicodeCodepoint;
  LLen: Byte;
begin
  { U+FDFA is the longest prototype in the table (18 cps). }
  Check(GetConfusablePrototype($FDFA, LBuf, LLen), 'FDFA found');
  CheckEqual(Int64(18), Int64(LLen), 'FDFA proto len');
end;

procedure TestHomographs;
begin
  { "paypal" vs Cyrillic-a lookalike "раypal" }
  Check(AreConfusable('paypal', 'раypal'), 'paypal vs раypal');
  Check(AreConfusable('раypal', 'paypal'), 'symmetric homograph');

  { 'test' vs Cyrillic е (0435→0065) }
  Check(AreConfusable('test', 'tеst'), 'test vs cyrillic е');

  { Non-confusable pairs must stay distinct. }
  Check(not AreConfusable('paypal', 'paypu'), 'different letters');
  Check(not AreConfusable('abc', 'abd'), 'abc vs abd');

  { ASCII case is NOT folded by the MA table (exact-codepoint morphing),
    so 'A' (U+0041, unmapped) and 'а' (U+0430→U+0061) are not confusable. }
  Check(not AreConfusable('A', 'а'), 'A vs cyrillic a');
  Check(AreConfusable('a', 'а'), 'a vs cyrillic a');
end;

procedure TestSkeleton;
begin
  { skeleton is deterministic and side-effect free. }
  CheckEqual(ConfusableSkeleton('paypal'), 'paypal', 'skeleton of ascii idempotent');
  CheckEqual(ConfusableSkeleton('раypal'), 'paypal', 'skeleton maps lookalikes');
  CheckEqual(ConfusableSkeleton(''), '', 'empty skeleton');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.confusable');
  T.Test('unknown entry absent', @TestUnknownEntry);
  T.Test('too-small buffer fails closed', @TestBufferTooSmall);
  T.Test('basic single-cp mappings', @TestBasicMappings);
  T.Test('multi-codepoint prototype U+FDFA', @TestMultiPrototype);
  T.Test('homograph detection', @TestHomographs);
  T.Test('skeleton transform', @TestSkeleton);
  if not T.Run then
    Halt(1);
end.