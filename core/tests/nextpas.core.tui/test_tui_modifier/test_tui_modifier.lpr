program test_tui_modifier;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.modifier,
  nextpas.core.testing;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.tui.modifier');
  T.Run('empty', @TestEmpty);
  T.Run('equality', @TestEquality);
  T.Run('set operations', @TestSetOps);
  T.Run('size 2 bytes', @TestSize);
  T.Run('all bits', @TestAllBits);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
