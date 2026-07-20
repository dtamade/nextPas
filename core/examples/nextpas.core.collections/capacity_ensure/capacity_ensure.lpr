{**
 * Ensure vs EnsureCapacity — do not use Ensure as "reserve".
 *
 * Ensure(n)     → grows logical Count (new elements initialized)
 * EnsureCapacity(n) → grows physical Capacity only
 *}
program capacity_ensure;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.collections,
  nextpas.core.collections.vec.intf;

procedure Fail(const AMessage: string);
begin
  WriteLn('collections-capacity-ensure-status=fail');
  WriteLn('error=', AMessage);
  Halt(1);
end;

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

var
  CapOnly: specialize IVec<Integer>;
  LengthGrow: specialize IVec<Integer>;
begin
  WriteLn('collections-capacity-ensure=ready');

  { --- EnsureCapacity: Count stays 0, Capacity grows --- }
  CapOnly := specialize MakeVec<Integer>;
  CapOnly.EnsureCapacity(64);
  Require(CapOnly.GetCount = 0, 'EnsureCapacity must not change Count');
  Require(CapOnly.Capacity >= 64, 'EnsureCapacity must raise Capacity');
  WriteLn('ensure-capacity-count=', CapOnly.GetCount);
  WriteLn('ensure-capacity-cap=', CapOnly.Capacity);

  CapOnly.Push(1);
  CapOnly.Push(2);
  Require(CapOnly.GetCount = 2, 'push after EnsureCapacity');
  Require(CapOnly.Capacity >= 64, 'capacity retained after push');
  WriteLn('after-push-count=', CapOnly.GetCount);

  { --- Ensure: Count becomes n (logical length; slots become indexable) --- }
  LengthGrow := specialize MakeVec<Integer>;
  LengthGrow.Ensure(8);
  Require(LengthGrow.GetCount = 8, 'Ensure grows Count to 8');
  Require(LengthGrow.Capacity >= 8, 'Ensure also provides capacity for Count');
  WriteLn('ensure-count=', LengthGrow.GetCount);
  WriteLn('ensure-cap=', LengthGrow.Capacity);

  LengthGrow.Put(3, 42);
  Require(LengthGrow.Get(3) = 42, 'indexable after Ensure');
  WriteLn('ensure-slot3=', LengthGrow.Get(3));

  { Ensure again with smaller n is a no-op for Count }
  LengthGrow.Ensure(4);
  Require(LengthGrow.GetCount = 8, 'Ensure smaller n does not shrink Count');
  Require(LengthGrow.Get(3) = 42, 'prior Put still visible after Ensure(4)');

  WriteLn('collections-capacity-ensure-status=ok');
end.
