program test_lockfree_fenwick;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.fenwick,
  nextpas.core.atomic,
  nextpas.core.test;

procedure TestFenwickBasic;
var
  LTree: TConcurrentFenwickTree;
  LSum: Int64;
begin
  LTree := TConcurrentFenwickTree.Create(10);
  try
    CheckEqual(Ord(fwOk), Ord(LTree.Update(1, 5)));
    CheckEqual(Ord(fwOk), Ord(LTree.Update(2, 3)));
    CheckEqual(Ord(fwOk), Ord(LTree.Update(3, 7)));

    CheckEqual(Ord(fwOk), Ord(LTree.PrefixSum(1, LSum)));
    CheckEqual(Int64(5), LSum);

    CheckEqual(Ord(fwOk), Ord(LTree.PrefixSum(2, LSum)));
    CheckEqual(Int64(8), LSum);

    CheckEqual(Ord(fwOk), Ord(LTree.PrefixSum(3, LSum)));
    CheckEqual(Int64(15), LSum);
  finally
    LTree.Free;
  end;
end;

procedure TestFenwickRangeSum;
var
  LTree: TConcurrentFenwickTree;
  LSum: Int64;
begin
  LTree := TConcurrentFenwickTree.Create(10);
  try
    LTree.Update(1, 1);
    LTree.Update(2, 2);
    LTree.Update(3, 3);
    LTree.Update(4, 4);
    LTree.Update(5, 5);

    CheckEqual(Ord(fwOk), Ord(LTree.RangeSum(2, 4, LSum)));
    CheckEqual(Int64(9), LSum);

    CheckEqual(Ord(fwOk), Ord(LTree.RangeSum(1, 5, LSum)));
    CheckEqual(Int64(15), LSum);

    CheckEqual(Ord(fwOk), Ord(LTree.RangeSum(3, 3, LSum)));
    CheckEqual(Int64(3), LSum);
  finally
    LTree.Free;
  end;
end;

procedure TestFenwickOutOfBounds;
var
  LTree: TConcurrentFenwickTree;
  LSum: Int64;
begin
  LTree := TConcurrentFenwickTree.Create(5);
  try
    CheckEqual(Ord(fwOutOfBounds), Ord(LTree.Update(0, 1)));
    CheckEqual(Ord(fwOutOfBounds), Ord(LTree.Update(6, 1)));
    CheckEqual(Ord(fwOutOfBounds), Ord(LTree.PrefixSum(-1, LSum)));
    CheckEqual(Ord(fwOutOfBounds), Ord(LTree.PrefixSum(6, LSum)));
  finally
    LTree.Free;
  end;
end;

procedure TestFenwickClose;
var
  LTree: TConcurrentFenwickTree;
begin
  LTree := TConcurrentFenwickTree.Create(5);
  try
    LTree.Update(1, 10);
    LTree.Close;
    Check(LTree.IsClosed, 'Should be closed');
    CheckEqual(Ord(fwClosed), Ord(LTree.Update(2, 20)));
  finally
    LTree.Free;
  end;
end;

procedure TestFenwickGetSize;
var
  LTree: TConcurrentFenwickTree;
begin
  LTree := TConcurrentFenwickTree.Create(100);
  try
    CheckEqual(100, LTree.GetSize);
  finally
    LTree.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_fenwick ===');
  WriteLn;

  TestFenwickBasic;
  WriteLn('  + Basic operations');

  TestFenwickRangeSum;
  WriteLn('  + Range sum');

  TestFenwickOutOfBounds;
  WriteLn('  + Out of bounds');

  TestFenwickClose;
  WriteLn('  + Close semantics');

  TestFenwickGetSize;
  WriteLn('  + Get size');

  WriteLn;
  WriteLn('All fenwick tree tests passed!');
end.
