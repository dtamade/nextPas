program test_lockfree_lru;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.lru,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

type
  TIntLru = specialize TConcurrentLruCache<Int64, Int64>;

procedure TestLruBasic;
var
  LLru: TIntLru;
  LValue: Int64;
begin
  LLru := TIntLru.Create(10, 4);
  try
    Check(LLru.IsEmpty, 'Cache should be empty');
    Check(not LLru.IsClosed, 'Cache should not be closed');
    CheckEqual(PtrUInt(0), LLru.Count);
    CheckEqual(PtrUInt(10), LLru.Capacity);

    Check(LLru.Put(1, 10) = lrAdded, 'Should add element');
    Check(not LLru.IsEmpty, 'Cache should not be empty');
    CheckEqual(PtrUInt(1), LLru.Count);

    Check(LLru.Get(1, LValue), 'Should get element');
    CheckEqual(Int64(10), LValue);

    Check(not LLru.Get(2, LValue), 'Should not get non-existent element');
  finally
    LLru.Free;
  end;
end;

procedure TestLruMultipleElements;
var
  LLru: TIntLru;
  LValue: Int64;
  I: Integer;
begin
  LLru := TIntLru.Create(10, 4);
  try
    for I := 1 to 5 do
      Check(LLru.Put(I, I * 10) = lrAdded, 'Should add element');

    CheckEqual(PtrUInt(5), LLru.Count);

    for I := 1 to 5 do
    begin
      Check(LLru.Get(I, LValue), 'Should get element');
      CheckEqual(Int64(I * 10), LValue);
    end;
  finally
    LLru.Free;
  end;
end;

procedure TestLruUpdate;
var
  LLru: TIntLru;
  LValue: Int64;
begin
  LLru := TIntLru.Create(10, 4);
  try
    LLru.Put(1, 10);
    Check(LLru.Get(1, LValue), 'Should get element');
    CheckEqual(Int64(10), LValue);

    Check(LLru.Put(1, 20) = lrUpdated, 'Should update element');
    Check(LLru.Get(1, LValue), 'Should get updated element');
    CheckEqual(Int64(20), LValue);

    CheckEqual(PtrUInt(1), LLru.Count);
  finally
    LLru.Free;
  end;
end;

procedure TestLruRemove;
var
  LLru: TIntLru;
  LValue: Int64;
begin
  LLru := TIntLru.Create(10, 4);
  try
    LLru.Put(1, 10);
    CheckEqual(PtrUInt(1), LLru.Count);

    Check(LLru.Remove(1), 'Should remove element');
    Check(not LLru.Get(1, LValue), 'Should not get removed element');
    CheckEqual(PtrUInt(0), LLru.Count);

    Check(not LLru.Remove(2), 'Should not remove non-existent element');
  finally
    LLru.Free;
  end;
end;

procedure TestLruClear;
var
  LLru: TIntLru;
begin
  LLru := TIntLru.Create(10, 4);
  try
    LLru.Put(1, 10);
    LLru.Put(2, 20);
    LLru.Put(3, 30);
    CheckEqual(PtrUInt(3), LLru.Count);

    LLru.Clear;
    Check(LLru.IsEmpty, 'Cache should be empty');
    CheckEqual(PtrUInt(0), LLru.Count);
  finally
    LLru.Free;
  end;
end;

procedure TestLruClose;
var
  LLru: TIntLru;
  LValue: Int64;
begin
  LLru := TIntLru.Create(10, 4);
  try
    LLru.Put(1, 10);
    LLru.Close;
    Check(LLru.IsClosed, 'Cache should be closed');

    Check(LLru.Get(1, LValue), 'Should still get from closed cache');
    Check(LLru.Put(2, 20) = lrClosed, 'Should not put after close');
  finally
    LLru.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_lru ===');
  WriteLn;

  TestLruBasic;
  WriteLn('  + Basic get/put');

  TestLruMultipleElements;
  WriteLn('  + Multiple elements');

  TestLruUpdate;
  WriteLn('  + Update existing');

  TestLruRemove;
  WriteLn('  + Remove');

  TestLruClear;
  WriteLn('  + Clear');

  TestLruClose;
  WriteLn('  + Close semantics');

  WriteLn;
  WriteLn('All LRU cache tests passed!');
end.
