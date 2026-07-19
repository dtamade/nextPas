program test_tui_modifier;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.modifier,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestEmpty;
begin
  Check(ModifierIsEmpty(MODIFIER_NONE), 'none is empty');
  Check(ModifierIsEmpty([]), 'empty set is empty');
  Check(not ModifierIsEmpty([mbBold]), 'bold not empty');
end;

procedure TestEquality;
begin
  Check(ModifierEquals([mbBold, mbItalic], [mbBold, mbItalic]), 'equal sets');
  Check(ModifierEquals([mbItalic, mbBold], [mbBold, mbItalic]), 'order independent');
  Check(not ModifierEquals([mbBold], [mbItalic]), 'unequal sets');
end;

procedure TestSetOps;
var
  LM: TModifier;
begin
  LM := [mbBold] + [mbItalic];
  Check(ModifierEquals(LM, [mbBold, mbItalic]), 'union');
  LM := [mbBold, mbItalic] - [mbItalic];
  Check(ModifierEquals(LM, [mbBold]), 'difference');
  LM := [mbBold, mbItalic] * [mbItalic, mbDim];
  Check(ModifierEquals(LM, [mbItalic]), 'intersection');
end;

procedure TestSize;
begin
  CheckEqual(Int64(2), Int64(SizeOf(TModifier)), 'TModifier 2 bytes (packset 2)');
end;

procedure TestAllBits;
var
  LM: TModifier;
begin
  LM := [mbBold, mbDim, mbItalic, mbUnderlined, mbSlowBlink,
         mbRapidBlink, mbReversed, mbHidden, mbCrossedOut];
  Check(mbBold in LM, 'bold in');
  Check(mbCrossedOut in LM, 'crossedout in');
  Check(not ModifierIsEmpty(LM), 'all bits not empty');
end;


procedure TestIncludeExclude;
var
  LM: TModifier;
begin
  LM := [];
  Include(LM, mbBold);
  Check(mbBold in LM, 'include bold');
  Exclude(LM, mbBold);
  Check(not (mbBold in LM), 'exclude bold');
end;

procedure TestUnionIntersection;
var
  A, B, C: TModifier;
begin
  A := [mbBold, mbItalic];
  B := [mbItalic, mbUnderlined];
  C := A + B;
  Check(mbBold in C, 'union bold');
  Check(mbUnderlined in C, 'union underline');
  C := A * B;
  Check(mbItalic in C, 'intersect italic');
  Check(not (mbBold in C), 'intersect no bold');
end;

procedure TestDifference;
var
  A, B, C: TModifier;
begin
  A := [mbBold, mbDim, mbItalic];
  B := [mbDim];
  C := A - B;
  Check(mbBold in C, 'diff keeps bold');
  Check(not (mbDim in C), 'diff drops dim');
end;

procedure TestSingleFlags;
begin
  Check(mbBold in [mbBold], 'bold alone');
  Check(mbDim in [mbDim], 'dim alone');
  Check(mbItalic in [mbItalic], 'italic alone');
  Check(mbUnderlined in [mbUnderlined], 'underline alone');
  Check(mbReversed in [mbReversed], 'reversed alone');
end;

procedure TestEmptyEquality;
begin
  Check(ModifierEquals([], []), 'empty equals empty');
  Check(ModifierIsEmpty([]), 'empty is empty');
  Check(not ModifierEquals([mbBold], []), 'bold != empty');
end;

procedure TestSymmetryEquals;
var
  A, B: TModifier;
begin
  A := [mbBold, mbItalic];
  B := [mbItalic, mbBold];
  Check(ModifierEquals(A, B), 'set equality commutative');
end;

procedure TestHiddenCrossedOut;
var
  LM: TModifier;
begin
  LM := [mbHidden, mbCrossedOut];
  Check(mbHidden in LM, 'hidden');
  Check(mbCrossedOut in LM, 'crossed');
end;


begin
  T := TTestSuite.Create('nextpas.core.tui.modifier');
  T.Test('empty', @TestEmpty);
  T.Test('equality', @TestEquality);
  T.Test('set operations', @TestSetOps);
  T.Test('size 2 bytes', @TestSize);
  T.Test('all bits', @TestAllBits);
    T.Test('include exclude', @TestIncludeExclude);
  T.Test('union intersection', @TestUnionIntersection);
  T.Test('difference', @TestDifference);
  T.Test('single flags', @TestSingleFlags);
  T.Test('empty equality', @TestEmptyEquality);
  T.Test('symmetry equals', @TestSymmetryEquals);
  T.Test('hidden crossed out', @TestHiddenCrossedOut);
if not T.Run then Halt(1);
end.
