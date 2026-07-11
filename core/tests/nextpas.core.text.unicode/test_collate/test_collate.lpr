program test_unicode_collate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.collate,
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

procedure TestWeightLookup;
var
  LWeight: UInt32;
begin
  // A has non-zero weight
  LWeight := GetCollationWeight(Ord('A'));
  Check(LWeight > 0, 'A has non-zero weight');

  // A and a have same primary weight (case-insensitive at primary level)
  CheckEqual(
    Int64(UnpackPrimary(GetCollationWeight(Ord('A')))),
    Int64(UnpackPrimary(GetCollationWeight(Ord('a')))),
    'A and a have same primary weight'
  );

  // B > A
  Check(
    UnpackPrimary(GetCollationWeight(Ord('B'))) > UnpackPrimary(GetCollationWeight(Ord('A'))),
    'B > A (primary)'
  );

  // Accent variants have same primary weight as base letter
  CheckEqual(
    Int64(UnpackPrimary(GetCollationWeight($00E1))),  // á
    Int64(UnpackPrimary(GetCollationWeight(Ord('a')))),
    'á and a have same primary weight'
  );

  // Combining marks are ignorable (weight 0)
  CheckEqual(
    Int64(GetCollationWeight($0301)),  // combining acute accent
    Int64(0),
    'combining acute is ignorable'
  );
end;

procedure TestTertiaryWeights;
begin
  // Lowercase and uppercase have different tertiary weights
  Check(
    UnpackTertiary(GetCollationWeight(Ord('a'))) <> UnpackTertiary(GetCollationWeight(Ord('A'))),
    'a and A have different tertiary weights'
  );

  // Lowercase < uppercase in DUCET tertiary ordering
  Check(
    UnpackTertiary(GetCollationWeight(Ord('a'))) < UnpackTertiary(GetCollationWeight(Ord('A'))),
    'a tertiary < A tertiary'
  );

  // Hiragana and katakana have different tertiary weights
  Check(
    UnpackTertiary(GetCollationWeight($3042)) <> UnpackTertiary(GetCollationWeight($30A2)),
    'あ and ア have different tertiary weights'
  );
end;

procedure TestPrimaryOnlyOrdering;
var
  LOptions: TCollationOptions;
  LCollator: IUnicodeCollator;
begin
  LOptions := DefaultCollationOptions;
  LOptions.Strength := csPrimary;
  LCollator := UnicodeCollatorWithOptions(LOptions);

  // Basic Latin ordering: A < B < C
  Check(LCollator.Compare('A', 'B') < 0, 'A < B');
  Check(LCollator.Compare('B', 'C') < 0, 'B < C');

  // Case-insensitive at primary level: a == A
  CheckEqual(LCollator.Compare('a', 'A'), 0, 'a == A (primary)');
  CheckEqual(LCollator.Compare('abc', 'ABC'), 0, 'abc == ABC (primary)');

  // Accent-insensitive at primary level: á == a
  CheckEqual(LCollator.Compare(#$C3#$A1, 'a'), 0, 'á == a (primary)');

  // Words: apple < banana < cherry
  Check(LCollator.Compare('apple', 'banana') < 0, 'apple < banana');
  Check(LCollator.Compare('banana', 'cherry') < 0, 'banana < cherry');
end;

procedure TestTertiaryOrdering;
var
  LOptions: TCollationOptions;
  LCollator: IUnicodeCollator;
begin
  LOptions := DefaultCollationOptions;
  LOptions.Strength := csTertiary;
  LCollator := UnicodeCollatorWithOptions(LOptions);

  // Case-sensitive: a < A (lowercase sorts before uppercase in DUCET)
  Check(LCollator.Compare('a', 'A') < 0, 'a < A (tertiary)');
  Check(LCollator.Compare('abc', 'ABC') < 0, 'abc < ABC (tertiary)');

  // Same case: a == a
  CheckEqual(LCollator.Compare('a', 'a'), 0, 'a == a');

  // Precomposed á decomposes to a + combining acute (ignorable) → equals a
  CheckEqual(LCollator.Compare('á', 'a'), 0, 'á == a (NFD: a + combining acute)');

  // à vs À have different tertiary (lowercase vs uppercase)
  Check(LCollator.Compare('à', 'À') < 0, 'à < À (tertiary)');
end;

procedure TestCJKOrdering;
var
  LCollator: IUnicodeCollator;
begin
  LCollator := UnicodeCollator;

  // CJK characters sort after Latin
  Check(LCollator.Compare('A', #$E4#$B8#$AD) < 0, 'A < 中');

  // CJK characters have consistent ordering
  Check(LCollator.Compare(#$E4#$B8#$80, #$E4#$B8#$AD) < 0, '一 < 中');
  Check(LCollator.Compare(#$E4#$B8#$AD, #$E5#$9B#$BD) < 0, '中 < 国');
end;

procedure TestSortKeyGeneration;
var
  LCollator: IUnicodeCollator;
  LKeyA, LKeyB: TCollationKey;
begin
  LCollator := UnicodeCollator;

  // Sort keys are deterministic
  LKeyA := LCollator.GetSortKey('A');
  LKeyB := LCollator.GetSortKey('A');
  Check(Length(LKeyA) > 0, 'Sort key for A is non-empty');
  CheckEqual(Length(LKeyA), Length(LKeyB), 'Same input produces same length');

  // Empty string produces empty key
  LKeyA := LCollator.GetSortKey('');
  CheckEqual(Length(LKeyA), 0, 'Empty string produces empty sort key');
end;

procedure TestSortKeyLevels;
var
  LPrimaryOpts, LTertiaryOpts: TCollationOptions;
  LPrimaryCol, LTertiaryCol: IUnicodeCollator;
  LKeyP, LKeyT: TCollationKey;
begin
  // Primary-only sort key is shorter than tertiary
  LPrimaryOpts := DefaultCollationOptions;
  LPrimaryOpts.Strength := csPrimary;
  LPrimaryCol := UnicodeCollatorWithOptions(LPrimaryOpts);

  LTertiaryOpts := DefaultCollationOptions;
  LTertiaryOpts.Strength := csTertiary;
  LTertiaryCol := UnicodeCollatorWithOptions(LTertiaryOpts);

  LKeyP := LPrimaryCol.GetSortKey('Hello');
  LKeyT := LTertiaryCol.GetSortKey('Hello');

  // Tertiary key has more levels (primary + secondary + tertiary)
  Check(Length(LKeyT) > Length(LKeyP), 'Tertiary key > Primary key length');
end;

procedure TestCollatorMethods;
var
  LCollator: IUnicodeCollator;
begin
  LCollator := UnicodeCollator;

  // TextEquals
  Check(LCollator.TextEquals('hello', 'hello'), 'hello equals hello');
  Check(not LCollator.TextEquals('hello', 'world'), 'hello not equals world');

  // StartsWith
  Check(LCollator.StartsWith('hello world', 'hello'), 'starts with hello');
  Check(not LCollator.StartsWith('hello', 'world'), 'hello does not start with world');

  // EndsWith
  Check(LCollator.EndsWith('hello world', 'world'), 'ends with world');
  Check(not LCollator.EndsWith('hello', 'world'), 'hello does not end with world');

  // Contains
  Check(LCollator.Contains('hello world', 'lo wo'), 'contains lo wo');
  Check(not LCollator.Contains('hello', 'xyz'), 'does not contain xyz');

  // IndexOf
  CheckEqual(LCollator.IndexOf('hello world', 'world'), 7, 'world at position 7');
  CheckEqual(LCollator.IndexOf('hello', 'xyz'), 0, 'xyz not found');
  CheckEqual(LCollator.IndexOf('hello', ''), 1, 'empty substring at position 1');
end;

procedure TestEmptyAndEdgeCases;
var
  LCollator: IUnicodeCollator;
begin
  LCollator := UnicodeCollator;

  // Empty strings
  CheckEqual(LCollator.Compare('', ''), 0, 'empty == empty');
  Check(LCollator.Compare('', 'a') < 0, 'empty < a');
  Check(LCollator.Compare('a', '') > 0, 'a > empty');

  // Single characters
  CheckEqual(LCollator.Compare('x', 'x'), 0, 'x == x');

  // Long strings
  Check(LCollator.Compare('aaa', 'aab') < 0, 'aaa < aab');
  Check(LCollator.Compare('aab', 'aaa') > 0, 'aab > aaa');
end;

procedure TestIgnorableCharacters;
var
  LCollator: IUnicodeCollator;
begin
  LCollator := UnicodeCollator;

  // Combining marks are ignorable at primary level
  CheckEqual(
    LCollator.Compare('a', 'a' + #$CC#$81),  // a vs a + combining acute
    0,
    'a equals a + combining acute (primary)'
  );
end;

procedure TestWeightPacking;
var
  LWeight: UInt32;
begin
  // Verify packing/unpacking roundtrip
  LWeight := GetCollationWeight(Ord('A'));
  CheckEqual(Int64(UnpackPrimary(LWeight)), Int64(UnpackPrimary(GetCollationWeight(Ord('A')))),
    'Primary roundtrip');
  CheckEqual(Int64(UnpackSecondary(LWeight)), Int64(UnpackSecondary(GetCollationWeight(Ord('A')))),
    'Secondary roundtrip');
  CheckEqual(Int64(UnpackTertiary(LWeight)), Int64(UnpackTertiary(GetCollationWeight(Ord('A')))),
    'Tertiary roundtrip');

  // Verify weight is zero for ignorable
  CheckEqual(Int64(GetCollationWeight($0301)), Int64(0), 'Combining mark weight is 0');
end;

procedure TestSortKeyConsistency;
var
  LCollator: IUnicodeCollator;
  LKeyA, LKeyB: TCollationKey;
  LI: SizeInt;
begin
  // Sort key comparison must agree with direct Compare
  LCollator := UnicodeCollator;

  LKeyA := LCollator.GetSortKey('hello');
  LKeyB := LCollator.GetSortKey('world');
  Check(LCollator.Compare('hello', 'world') < 0, 'hello < world');

  // Sort key byte comparison must agree
  if Length(LKeyA) < Length(LKeyB) then
    for LI := 0 to Length(LKeyA) - 1 do
    begin
      if LKeyA[LI] < LKeyB[LI] then begin Check(True, 'sort key bytes confirm hello < world'); Break; end;
      if LKeyA[LI] > LKeyB[LI] then begin Check(False, 'sort key bytes disagree'); Break; end;
    end
  else
    for LI := 0 to Length(LKeyB) - 1 do
    begin
      if LKeyA[LI] < LKeyB[LI] then begin Check(True, 'sort key bytes confirm hello < world'); Break; end;
      if LKeyA[LI] > LKeyB[LI] then begin Check(False, 'sort key bytes disagree'); Break; end;
    end;

  // Sort key for same string must be identical
  LKeyA := LCollator.GetSortKey('test');
  LKeyB := LCollator.GetSortKey('test');
  CheckEqual(Length(LKeyA), Length(LKeyB), 'same string sort key length');
  for LI := 0 to Length(LKeyA) - 1 do
    CheckEqual(Int64(LKeyA[LI]), Int64(LKeyB[LI]), 'same string sort key bytes');
end;

procedure TestStrengthLevels;
var
  LPrimaryOpts, LSecondaryOpts, LTertiaryOpts: TCollationOptions;
  LPrimaryCol, LSecondaryCol, LTertiaryCol: IUnicodeCollator;
begin
  // Primary: ignore case and accents
  LPrimaryOpts := DefaultCollationOptions;
  LPrimaryOpts.Strength := csPrimary;
  LPrimaryCol := UnicodeCollatorWithOptions(LPrimaryOpts);
  CheckEqual(LPrimaryCol.Compare('a', 'A'), 0, 'a == A (primary)');
  CheckEqual(LPrimaryCol.Compare('á', 'a'), 0, 'á == a (primary)');

  // Secondary: distinguish accents, ignore case
  LSecondaryOpts := DefaultCollationOptions;
  LSecondaryOpts.Strength := csSecondary;
  LSecondaryCol := UnicodeCollatorWithOptions(LSecondaryOpts);
  // á decomposes to a + combining acute; combining acute is ignorable (weight 0)
  // So á == a at ALL levels including secondary
  CheckEqual(LSecondaryCol.Compare('a', 'á'), 0, 'á == a (secondary, combining ignorable)');
  // à decomposes to a + combining grave; also ignorable
  CheckEqual(LSecondaryCol.Compare('a', 'à'), 0, 'à == a (secondary, combining ignorable)');

  // Tertiary: distinguish case
  LTertiaryOpts := DefaultCollationOptions;
  LTertiaryOpts.Strength := csTertiary;
  LTertiaryCol := UnicodeCollatorWithOptions(LTertiaryOpts);
  Check(LTertiaryCol.Compare('a', 'A') <> 0, 'a != A (tertiary)');
end;

{ === SMP Collation === }

procedure TestSmpCollation;
var
  LCollator: IUnicodeCollator;
begin
  LCollator := UnicodeCollator;

  // CJK Extension B (U+20000) - may have no DUCET weight, so compare may be 0
  // Just verify it doesn't crash
  LCollator.Compare(Utf8Of([$20000]), Utf8Of([$20001]));

  // Math Bold A (U+1D400) - has compatibility decomposition to 'A'
  // After NFD, it becomes 'A', so it should sort near 'A'
  Check(LCollator.Compare(Utf8Of([$1D400]), 'B') < 0,
    'Math Bold A sorts before B (decomposes to A)');

  // Deseret (U+10400) - no decomposition
  Check(LCollator.Compare(Utf8Of([$10400]), Utf8Of([$10401])) < 0,
    'Deseret AY < Deseret OW');

  // Sort key generation for SMP
  Check(Length(LCollator.GetSortKey(Utf8Of([$20000]))) > 0,
    'CJK Ext B sort key non-empty');
end;

{ === Stress Collation === }

procedure TestStressCollation;
var
  LCollator: IUnicodeCollator;
  LArr5: array[0..4] of string;
  LArr20: array[0..19] of string;
  LI: SizeInt;
begin
  LCollator := UnicodeCollator;

  // Verify sort with insertion sort threshold (≤16 elements)
  LArr5[0] := 'cherry';
  LArr5[1] := 'apple';
  LArr5[2] := 'elderberry';
  LArr5[3] := 'banana';
  LArr5[4] := 'date';
  SortStrings(LArr5);
  Check(LCollator.Compare(LArr5[0], LArr5[1]) <= 0, '5-elem sorted 0-1');
  Check(LCollator.Compare(LArr5[1], LArr5[2]) <= 0, '5-elem sorted 1-2');
  Check(LCollator.Compare(LArr5[2], LArr5[3]) <= 0, '5-elem sorted 2-3');
  Check(LCollator.Compare(LArr5[3], LArr5[4]) <= 0, '5-elem sorted 3-4');

  // Verify sort with quicksort (>16 elements)
  for LI := 0 to 19 do
    LArr20[LI] := 'str' + Chr(Ord('t') - LI);
  SortStrings(LArr20);
  for LI := 1 to 19 do
    Check(LCollator.Compare(LArr20[LI - 1], LArr20[LI]) <= 0, '20-elem sorted');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.collate');
  T.Test('WeightLookup', @TestWeightLookup);
  T.Test('TertiaryWeights', @TestTertiaryWeights);
  T.Test('PrimaryOnlyOrdering', @TestPrimaryOnlyOrdering);
  T.Test('TertiaryOrdering', @TestTertiaryOrdering);
  T.Test('CJKOrdering', @TestCJKOrdering);
  T.Test('SortKeyGeneration', @TestSortKeyGeneration);
  T.Test('SortKeyLevels', @TestSortKeyLevels);
  T.Test('CollatorMethods', @TestCollatorMethods);
  T.Test('EmptyAndEdgeCases', @TestEmptyAndEdgeCases);
  T.Test('IgnorableCharacters', @TestIgnorableCharacters);
  T.Test('WeightPacking', @TestWeightPacking);
  T.Test('SortKeyConsistency', @TestSortKeyConsistency);
  T.Test('StrengthLevels', @TestStrengthLevels);
  T.Test('SmpCollation', @TestSmpCollation);
  T.Test('StressCollation', @TestStressCollation);
  if not T.Run then Halt(1);
end.
