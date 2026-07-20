{**
 * TreeSet with custom comparer (reverse order) via MakeTreeSet.
 *}
program treeset_compare;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.collections,
  nextpas.core.collections.tree_set.intf;

procedure Fail(const AMessage: string);
begin
  WriteLn('collections-treeset-compare-status=fail');
  WriteLn('error=', AMessage);
  Halt(1);
end;

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

function ReverseIntCompare(const A, B: Integer; aData: Pointer): SizeInt;
begin
  if A > B then
    Result := -1
  else if A < B then
    Result := 1
  else
    Result := 0;
end;

var
  Asc: specialize ITreeSet<Integer>;
  Desc: specialize ITreeSet<Integer>;
  LVal: Integer;
begin
  WriteLn('collections-treeset-compare=ready');

  Asc := specialize MakeTreeSet<Integer>;
  Asc.Add(2);
  Asc.Add(1);
  Asc.Add(3);
  Require(Asc.Min(LVal) and (LVal = 1), 'asc min');
  WriteLn('asc-min=', LVal);
  Require(Asc.Max(LVal) and (LVal = 3), 'asc max');
  WriteLn('asc-max=', LVal);

  Desc := specialize MakeTreeSet<Integer>(@ReverseIntCompare);
  Desc.Add(2);
  Desc.Add(1);
  Desc.Add(3);
  Require(Desc.Min(LVal) and (LVal = 3), 'desc min is largest under reverse');
  WriteLn('desc-min=', LVal);
  Require(Desc.Max(LVal) and (LVal = 1), 'desc max is smallest under reverse');
  WriteLn('desc-max=', LVal);

  WriteLn('collections-treeset-compare-status=ok');
end.
