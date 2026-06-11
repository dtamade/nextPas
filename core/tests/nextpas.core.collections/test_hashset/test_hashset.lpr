program test_hashset;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections.hashset.intf,
  nextpas.core.collections.hashset;

type
  IIntSet = specialize IHashSet<Integer>;
  TIntSet = specialize THashSet<Integer>;
  IStrSet = specialize IHashSet<string>;
  TStrSet = specialize THashSet<string>;

var
  T: TTestRunner;

function FoldAscii(const S: string): string;
var
  I: SizeInt;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Result[I] := Chr(Ord(Result[I]) + Ord('a') - Ord('A'));
end;

function HashCaseInsensitive(const S: string): UInt32;
var
  I: SizeInt;
  C: Char;
begin
  Result := 2166136261;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if (C >= 'A') and (C <= 'Z') then
      C := Chr(Ord(C) + Ord('a') - Ord('A'));
    Result := (Result xor Ord(C)) * 16777619;
  end;
end;

function EqualsCaseInsensitive(const L, R: string): Boolean;
begin
  Result := FoldAscii(L) = FoldAscii(R);
end;

procedure TestAddContains;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  Check(LS.Add(1), 'add 1');
  Check(LS.Add(2), 'add 2');
  Check(LS.Add(3), 'add 3');
  Check(LS.Contains(1), 'contains 1');
  Check(LS.Contains(2), 'contains 2');
  Check(LS.Contains(3), 'contains 3');
  Check(not LS.Contains(99), 'not contains 99');
  CheckEqual(Int64(3), Int64(LS.Count), 'count');
end;

procedure TestAddDuplicate;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  Check(LS.Add(42), 'first add');
  Check(not LS.Add(42), 'duplicate add');
  CheckEqual(Int64(1), Int64(LS.Count), 'count stays 1');
end;

procedure TestRemove;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  LS.Add(10);
  LS.Add(20);
  LS.Add(30);
  Check(LS.Remove(20), 'remove existing');
  Check(not LS.Contains(20), 'removed gone');
  Check(not LS.Remove(99), 'remove missing');
  CheckEqual(Int64(2), Int64(LS.Count), 'count after remove');
end;

procedure TestClear;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  LS.Add(1);
  LS.Add(2);
  LS.Clear;
  Check(LS.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LS.Count), 'count 0');
end;

procedure TestStringSet;
var
  LS: IStrSet;
begin
  LS := TStrSet.Create;
  Check(LS.Add('hello'), 'add hello');
  Check(LS.Add('world'), 'add world');
  Check(not LS.Add('hello'), 'dup hello');
  Check(LS.Contains('hello'), 'contains hello');
  Check(not LS.Contains('missing'), 'not contains missing');
  CheckEqual(Int64(2), Int64(LS.Count), 'count');
end;

procedure TestGrow;
var
  LS: IIntSet;
  LI: Integer;
begin
  LS := TIntSet.Create;
  for LI := 0 to 99 do
    LS.Add(LI);
  CheckEqual(Int64(100), Int64(LS.Count), 'count 100');
  for LI := 0 to 99 do
    Check(LS.Contains(LI), 'contains ' + IntToStr(LI));
end;

procedure TestReserve;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  LS.Reserve(64);
  Check(LS.Capacity >= 64, 'capacity >= 64');
  Check(LS.IsEmpty, 'still empty');
end;

procedure TestAutoFree;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  LS.Add(1);
  LS := nil;
  Check(True);
end;

procedure TestSerializeNilPositiveCountRaises;
var
  LS: TIntSet;
  LRaised: Boolean;
begin
  LS := TIntSet.Create;
  try
    LS.Add(10);
    LRaised := False;
    try
      LS.SerializeToArrayBuffer(nil, 1);
    except
      on E: EArgumentNil do
        LRaised := True;
    end;
    Check(LRaised, 'serialize nil destination raises');
  finally
    LS.Free;
  end;
end;

procedure TestSerializeCountPastEndRaises;
var
  LS: TIntSet;
  LOut: Integer;
  LRaised: Boolean;
begin
  LS := TIntSet.Create;
  try
    LS.Add(10);
    LRaised := False;
    try
      LS.SerializeToArrayBuffer(@LOut, 2);
    except
      on E: EOutOfRange do
        LRaised := True;
    end;
    Check(LRaised, 'serialize count past end raises');
  finally
    LS.Free;
  end;
end;

procedure CheckCaseInsensitiveSet(const AName: string; const ASet: TStrSet; const AKey: string; AExpectedCount: SizeUInt);
begin
  Check(ASet.Contains(AKey), AName + ' should contain ' + AKey + ' using custom equality');
  Check(not ASet.Add(FoldAscii(AKey)), AName + ' should reject duplicate under custom equality');
  CheckEqual(Int64(AExpectedCount), Int64(ASet.Count), AName + ' count after duplicate');
end;

procedure TestSetAlgebraPreservesCustomEquality;
var
  LLeft: TStrSet;
  LRight: TStrSet;
  LUnion: TStrSet;
  LIntersection: TStrSet;
  LDifference: TStrSet;
  LSymmetric: TStrSet;
begin
  LLeft := TStrSet.Create(0, @HashCaseInsensitive, @EqualsCaseInsensitive);
  LRight := TStrSet.Create(0, @HashCaseInsensitive, @EqualsCaseInsensitive);
  try
    LLeft.Add('Alpha');
    LLeft.Add('Beta');
    LRight.Add('alpha');
    LRight.Add('Gamma');

    LUnion := LLeft.Union(LRight);
    try
      CheckCaseInsensitiveSet('union', LUnion, 'ALPHA', 3);
    finally
      LUnion.Free;
    end;

    LIntersection := LLeft.Intersection(LRight);
    try
      CheckCaseInsensitiveSet('intersection', LIntersection, 'ALPHA', 1);
    finally
      LIntersection.Free;
    end;

    LDifference := LLeft.Difference(LRight);
    try
      CheckCaseInsensitiveSet('difference', LDifference, 'BETA', 1);
    finally
      LDifference.Free;
    end;

    LSymmetric := LLeft.SymmetricDifference(LRight);
    try
      CheckCaseInsensitiveSet('symmetric difference', LSymmetric, 'BETA', 2);
      CheckCaseInsensitiveSet('symmetric difference', LSymmetric, 'GAMMA', 2);
    finally
      LSymmetric.Free;
    end;
  finally
    LRight.Free;
    LLeft.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.hashset');
  T.Run('Add/Contains', @TestAddContains);
  T.Run('Add duplicate', @TestAddDuplicate);
  T.Run('Remove', @TestRemove);
  T.Run('Clear', @TestClear);
  T.Run('String set', @TestStringSet);
  T.Run('Grow (100 elements)', @TestGrow);
  T.Run('Reserve', @TestReserve);
  T.Run('Auto free (interface)', @TestAutoFree);
  T.Run('SerializeToArrayBuffer nil positive count raises', @TestSerializeNilPositiveCountRaises);
  T.Run('SerializeToArrayBuffer count past end raises', @TestSerializeCountPastEndRaises);
  T.Run('set algebra preserves custom equality', @TestSetAlgebraPreservesCustomEquality);
  T.Summary;
end.
