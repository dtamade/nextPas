program test_unicode_collate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.collate,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

procedure TestPrimaryWeightLookup;
begin
  // Latin letters — A and a have same primary weight (case-insensitive at primary level)
  Check(GetCollationPrimaryWeight(Ord('A')) > 0, 'A has non-zero weight');
  CheckEqual(
    Int64(GetCollationPrimaryWeight(Ord('A'))),
    Int64(GetCollationPrimaryWeight(Ord('a'))),
    'A and a have same primary weight'
  );

  // B > A
  Check(
    GetCollationPrimaryWeight(Ord('B')) > GetCollationPrimaryWeight(Ord('A')),
    'B > A'
  );

  // C > B
  Check(
    GetCollationPrimaryWeight(Ord('C')) > GetCollationPrimaryWeight(Ord('B')),
    'C > B'
  );

  // Accent variants have same primary weight as base letter
  CheckEqual(
    Int64(GetCollationPrimaryWeight($00E1)),  // á
    Int64(GetCollationPrimaryWeight(Ord('a'))),
    'á and a have same primary weight'
  );

  // Combining marks are ignorable (weight 0)
  CheckEqual(
    Int64(GetCollationPrimaryWeight($0301)),  // combining acute accent
    Int64(0),
    'combining acute is ignorable'
  );
end;

procedure TestDUCETOrdering;
var
  LCollator: IUnicodeCollator;
begin
  LCollator := UnicodeCollator;

  // Basic Latin ordering: A < B < C
  Check(LCollator.Compare('A', 'B') < 0, 'A < B');
  Check(LCollator.Compare('B', 'C') < 0, 'B < C');
  Check(LCollator.Compare('A', 'C') < 0, 'A < C');

  // Case-insensitive at primary level: a == A
  CheckEqual(LCollator.Compare('a', 'A'), 0, 'a == A (primary)');
  CheckEqual(LCollator.Compare('abc', 'ABC'), 0, 'abc == ABC (primary)');

  // Accent-insensitive at primary level: á == a
  CheckEqual(LCollator.Compare(#$C3#$A1, 'a'), 0, 'á == a (primary)');

  // Words: apple < banana < cherry
  Check(LCollator.Compare('apple', 'banana') < 0, 'apple < banana');
  Check(LCollator.Compare('banana', 'cherry') < 0, 'banana < cherry');

  // Numbers: 1 < 2 < 9
  Check(LCollator.Compare('1', '2') < 0, '1 < 2');
  Check(LCollator.Compare('2', '9') < 0, '2 < 9');
end;

procedure TestCJKOrdering;
var
  LCollator: IUnicodeCollator;
begin
  LCollator := UnicodeCollator;

  // CJK characters sort after Latin
  Check(LCollator.Compare('A', #$E4#$B8#$AD) < 0, 'A < 中');  // 中 = U+4E2D

  // CJK characters have consistent ordering
  // 一 (U+4E00) < 中 (U+4E2D) < 国 (U+56FD)
  Check(LCollator.Compare(#$E4#$B8#$80, #$E4#$B8#$AD) < 0, '一 < 中');
  Check(LCollator.Compare(#$E4#$B8#$AD, #$E5#$9B#$BD) < 0, '中 < 国');
end;

procedure TestSortKeyGeneration;
var
  LCollator: IUnicodeCollator;
  LKeyA, LKeyB, LKeyC: TCollationKey;
begin
  LCollator := UnicodeCollator;

  // Sort keys are deterministic
  LKeyA := LCollator.GetSortKey('A');
  LKeyB := LCollator.GetSortKey('A');
  Check(Length(LKeyA) > 0, 'Sort key for A is non-empty');
  CheckEqual(Length(LKeyA), Length(LKeyB), 'Same input produces same length');

  // Different inputs produce different keys
  LKeyC := LCollator.GetSortKey('B');
  Check(Length(LKeyC) > 0, 'Sort key for B is non-empty');

  // Empty string produces empty key
  LKeyA := LCollator.GetSortKey('');
  CheckEqual(Length(LKeyA), 0, 'Empty string produces empty sort key');
end;

procedure TestSortKeyOrdering;
var
  LCollator: IUnicodeCollator;
  LKey1, LKey2: TCollationKey;
  LMinLen, LI: SizeInt;
  LDiffer: Boolean;
begin
  LCollator := UnicodeCollator;

  // Sort key comparison matches string comparison
  LKey1 := LCollator.GetSortKey('apple');
  LKey2 := LCollator.GetSortKey('banana');

  // Compare keys byte by byte — should find first difference
  LDiffer := False;
  LMinLen := Length(LKey1);
  if Length(LKey2) < LMinLen then
    LMinLen := Length(LKey2);
  for LI := 0 to LMinLen - 1 do
  begin
    if LKey1[LI] <> LKey2[LI] then
    begin
      Check(LKey1[LI] < LKey2[LI], 'apple sort key < banana sort key');
      LDiffer := True;
      Break;
    end;
  end;
  Check(LDiffer, 'Sort keys differ');
end;

procedure TestCollatorMethods;
var
  LCollator: IUnicodeCollator;
begin
  LCollator := UnicodeCollator;

  // Equals
  Check(LCollator.Equals('hello', 'hello'), 'hello equals hello');
  Check(LCollator.Equals('Hello', 'HELLO'), 'Hello equals HELLO (primary)');
  Check(not LCollator.Equals('hello', 'world'), 'hello not equals world');

  // StartsWith
  Check(LCollator.StartsWith('hello world', 'hello'), 'starts with hello');
  Check(LCollator.StartsWith('HELLO WORLD', 'hello'), 'starts with hello (case)');
  Check(not LCollator.StartsWith('hello', 'world'), 'hello does not start with world');

  // EndsWith
  Check(LCollator.EndsWith('hello world', 'world'), 'ends with world');
  Check(LCollator.EndsWith('HELLO WORLD', 'world'), 'ends with world (case)');
  Check(not LCollator.EndsWith('hello', 'world'), 'hello does not end with world');

  // Contains
  Check(LCollator.Contains('hello world', 'lo wo'), 'contains lo wo');
  Check(LCollator.Contains('HELLO WORLD', 'lo wo'), 'contains LO WO (case)');
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
  // "a" + combining acute should equal "a"
  CheckEqual(
    LCollator.Compare('a', 'a' + #$CC#$81),  // a vs a + combining acute (U+0301)
    0,
    'a equals a + combining acute (primary)'
  );
end;

procedure TestScriptOrdering;
var
  LCollator: IUnicodeCollator;
begin
  LCollator := UnicodeCollator;

  // Latin vs Greek — different primary weights
  Check(
    GetCollationPrimaryWeight(Ord('A')) <> GetCollationPrimaryWeight($0391),
    'Latin A and Greek Alpha have different weights'
  );
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.collate');
  T.Test('PrimaryWeightLookup', @TestPrimaryWeightLookup);
  T.Test('DUCETOrdering', @TestDUCETOrdering);
  T.Test('CJKOrdering', @TestCJKOrdering);
  T.Test('SortKeyGeneration', @TestSortKeyGeneration);
  T.Test('SortKeyOrdering', @TestSortKeyOrdering);
  T.Test('CollatorMethods', @TestCollatorMethods);
  T.Test('EmptyAndEdgeCases', @TestEmptyAndEdgeCases);
  T.Test('IgnorableCharacters', @TestIgnorableCharacters);
  T.Test('ScriptOrdering', @TestScriptOrdering);
  if not T.Run then Halt(1);
end.
