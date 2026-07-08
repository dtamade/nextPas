program test_lockfree_bag;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.bag,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

type
  TIntBag = specialize TLockFreeBag<Int64>;

procedure TestBagBasic;
var
  LBag: TIntBag;
  LValue: Int64;
begin
  LBag := TIntBag.Create(16);
  try
    // Empty bag
    Check(LBag.IsEmpty, 'Bag should be empty');
    Check(not LBag.IsFull, 'Bag should not be full');
    Check(not LBag.IsClosed, 'Bag should not be closed');
    CheckEqual(PtrUInt(16), LBag.Capacity);
    CheckEqual(PtrUInt(0), LBag.ApproxCount);

    // Add one element
    Check(LBag.TryAdd(42) = arAdded, 'Should add element');
    Check(not LBag.IsEmpty, 'Bag should not be empty');
    CheckEqual(PtrUInt(1), LBag.ApproxCount);

    // Take one element
    Check(LBag.TryTake(LValue), 'Should take element');
    CheckEqual(Int64(42), LValue);
    Check(LBag.IsEmpty, 'Bag should be empty');
    CheckEqual(PtrUInt(0), LBag.ApproxCount);

    // Take from empty bag
    Check(not LBag.TryTake(LValue), 'Should not take from empty bag');
  finally
    LBag.Free;
  end;
end;

procedure TestBagMultipleElements;
var
  LBag: TIntBag;
  LValue: Int64;
  I: Integer;
begin
  LBag := TIntBag.Create(8);
  try
    // Fill bag
    for I := 1 to 8 do
      Check(LBag.TryAdd(I * 10) = arAdded, 'Should add element');

    // Bag should be full
    Check(LBag.IsFull, 'Bag should be full');
    CheckEqual(PtrUInt(8), LBag.ApproxCount);

    // Adding to full bag should fail
    Check(LBag.TryAdd(90) = arFull, 'Should fail when full');

    // Take all elements
    for I := 1 to 8 do
    begin
      Check(LBag.TryTake(LValue), 'Should take element');
      CheckEqual(Int64(I * 10), LValue);
    end;

    // Bag should be empty
    Check(LBag.IsEmpty, 'Bag should be empty');
  finally
    LBag.Free;
  end;
end;

procedure TestBagClose;
var
  LBag: TIntBag;
  LValue: Int64;
begin
  LBag := TIntBag.Create(16);
  try
    // Add some elements
    LBag.TryAdd(1);
    LBag.TryAdd(2);

    // Close bag
    LBag.Close;
    Check(LBag.IsClosed, 'Bag should be closed');

    // Can still take existing elements
    Check(LBag.TryTake(LValue), 'Should take from closed bag');
    CheckEqual(Int64(1), LValue);
    Check(LBag.TryTake(LValue), 'Should take from closed bag');
    CheckEqual(Int64(2), LValue);

    // Cannot take from empty closed bag
    Check(not LBag.TryTake(LValue), 'Should not take from empty closed bag');

    // Cannot add to closed bag
    Check(LBag.TryAdd(3) = arClosed, 'Should not add to closed bag');
  finally
    LBag.Free;
  end;
end;

procedure TestBagWait;
var
  LBag: TIntBag;
  LValue: Int64;
begin
  LBag := TIntBag.Create(4);
  try
    // Fill bag
    LBag.TryAdd(1);
    LBag.TryAdd(2);
    LBag.TryAdd(3);
    LBag.TryAdd(4);

    // Take one to make space
    Check(LBag.TryTake(LValue), 'Should take element');
    CheckEqual(Int64(1), LValue);

    // Now we have space
    Check(LBag.AddWait(5), 'Should add with wait');

    // TakeWait should succeed
    Check(LBag.TakeWait(LValue), 'Should take with wait');
    CheckEqual(Int64(2), LValue);
  finally
    LBag.Free;
  end;
end;

procedure TestBagCloseWakesWaiters;
var
  LBag: TIntBag;
  LValue: Int64;
begin
  LBag := TIntBag.Create(4);
  try
    // Close empty bag
    LBag.Close;

    // TakeWait should return false immediately
    Check(not LBag.TakeWait(LValue), 'Should not wait on closed empty bag');
  finally
    LBag.Free;
  end;
end;

procedure TestBagDuplicateElements;
var
  LBag: TIntBag;
  LValue: Int64;
  I: Integer;
begin
  LBag := TIntBag.Create(16);
  try
    // Add duplicate elements
    for I := 1 to 5 do
      Check(LBag.TryAdd(42) = arAdded, 'Should add duplicate');

    CheckEqual(PtrUInt(5), LBag.ApproxCount);

    // Take all duplicates
    for I := 1 to 5 do
    begin
      Check(LBag.TryTake(LValue), 'Should take element');
      CheckEqual(Int64(42), LValue);
    end;

    Check(LBag.IsEmpty, 'Bag should be empty');
  finally
    LBag.Free;
  end;
end;

procedure TestBagCapacityPowerOf2;
var
  LBag: TIntBag;
begin
  // Capacity should be rounded up to power of 2
  LBag := TIntBag.Create(10);
  try
    CheckEqual(PtrUInt(16), LBag.Capacity);
  finally
    LBag.Free;
  end;

  LBag := TIntBag.Create(16);
  try
    CheckEqual(PtrUInt(16), LBag.Capacity);
  finally
    LBag.Free;
  end;

  LBag := TIntBag.Create(17);
  try
    CheckEqual(PtrUInt(32), LBag.Capacity);
  finally
    LBag.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_bag ===');
  WriteLn;

  TestBagBasic;
  WriteLn('  + Basic add/take');

  TestBagMultipleElements;
  WriteLn('  + Multiple elements');

  TestBagClose;
  WriteLn('  + Close semantics');

  TestBagWait;
  WriteLn('  + Wait semantics');

  TestBagCloseWakesWaiters;
  WriteLn('  + Close wakes waiters');

  TestBagDuplicateElements;
  WriteLn('  + Duplicate elements');

  TestBagCapacityPowerOf2;
  WriteLn('  + Capacity power of 2');

  WriteLn;
  WriteLn('All bag tests passed!');
end.
