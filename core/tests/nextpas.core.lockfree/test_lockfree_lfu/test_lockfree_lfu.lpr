program test_lockfree_lfu;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.lfu,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

type
  TIntLFU = specialize TConcurrentLFUCache<Int64, Int64>;

procedure TestLfuBasic;
var
  LCache: TIntLFU;
  LValue: Int64;
begin
  LCache := TIntLFU.Create(100, 4);
  try
    CheckEqual(Ord(lfAdded), Ord(LCache.Put(1, 100)));
    CheckEqual(Ord(lfAdded), Ord(LCache.Put(2, 200)));
    CheckEqual(Ord(lfAdded), Ord(LCache.Put(3, 300)));

    Check(LCache.Get(1, LValue), 'Should find key 1');
    CheckEqual(Int64(100), LValue);

    Check(LCache.Get(2, LValue), 'Should find key 2');
    CheckEqual(Int64(200), LValue);

    Check(LCache.Get(3, LValue), 'Should find key 3');
    CheckEqual(Int64(300), LValue);

    Check(not LCache.Get(99, LValue), 'Should not find key 99');
  finally
    LCache.Free;
  end;
end;

procedure TestLfuUpdate;
var
  LCache: TIntLFU;
  LValue: Int64;
begin
  LCache := TIntLFU.Create(100, 4);
  try
    CheckEqual(Ord(lfAdded), Ord(LCache.Put(1, 100)));
    CheckEqual(Ord(lfUpdated), Ord(LCache.Put(1, 999)));

    Check(LCache.Get(1, LValue), 'Should find key 1');
    CheckEqual(Int64(999), LValue);
  finally
    LCache.Free;
  end;
end;

procedure TestLfuRemove;
var
  LCache: TIntLFU;
begin
  LCache := TIntLFU.Create(100, 4);
  try
    LCache.Put(1, 100);
    LCache.Put(2, 200);

    Check(LCache.Remove(1), 'Should remove key 1');
    Check(not LCache.Remove(1), 'Should not find key 1 again');
    Check(LCache.Contains(2), 'Key 2 should still exist');
    Check(not LCache.Contains(1), 'Key 1 should be gone');
  finally
    LCache.Free;
  end;
end;

procedure TestLfuContains;
var
  LCache: TIntLFU;
begin
  LCache := TIntLFU.Create(100, 4);
  try
    LCache.Put(1, 100);
    Check(LCache.Contains(1), 'Should contain key 1');
    Check(not LCache.Contains(99), 'Should not contain key 99');
  finally
    LCache.Free;
  end;
end;

procedure TestLfuCount;
var
  LCache: TIntLFU;
begin
  LCache := TIntLFU.Create(100, 4);
  try
    CheckEqual(PtrUInt(0), LCache.Count);
    LCache.Put(1, 100);
    CheckEqual(PtrUInt(1), LCache.Count);
    LCache.Put(2, 200);
    CheckEqual(PtrUInt(2), LCache.Count);
    LCache.Remove(1);
    CheckEqual(PtrUInt(1), LCache.Count);
  finally
    LCache.Free;
  end;
end;

procedure TestLfuHitRate;
var
  LCache: TIntLFU;
  LValue: Int64;
begin
  LCache := TIntLFU.Create(100, 4);
  try
    LCache.Put(1, 100);
    LCache.Get(1, LValue);  // hit
    LCache.Get(1, LValue);  // hit
    LCache.Get(99, LValue); // miss

    Check(LCache.GetHitRate > 0.6, 'Hit rate should be > 0.66');
    Check(LCache.GetHitRate < 0.7, 'Hit rate should be < 0.7');
  finally
    LCache.Free;
  end;
end;

procedure TestLfuClose;
var
  LCache: TIntLFU;
begin
  LCache := TIntLFU.Create(100, 4);
  try
    LCache.Put(1, 100);
    LCache.Close;
    Check(LCache.IsClosed, 'Should be closed');
    CheckEqual(Ord(lfClosed), Ord(LCache.Put(2, 200)));
  finally
    LCache.Free;
  end;
end;

procedure TestLfuEmpty;
var
  LCache: TIntLFU;
begin
  LCache := TIntLFU.Create(100, 4);
  try
    Check(LCache.IsEmpty, 'Should be empty');
    LCache.Put(1, 100);
    Check(not LCache.IsEmpty, 'Should not be empty');
  finally
    LCache.Free;
  end;
end;

procedure TestLfuClear;
var
  LCache: TIntLFU;
begin
  LCache := TIntLFU.Create(100, 4);
  try
    LCache.Put(1, 100);
    LCache.Put(2, 200);
    LCache.Clear;
    Check(LCache.IsEmpty, 'Should be empty after clear');
    Check(not LCache.Contains(1), 'Key 1 should be gone');
  finally
    LCache.Free;
  end;
end;

procedure TestLfuMultipleBuckets;
var
  LCache: TIntLFU;
  LI: Integer;
  LValue: Int64;
begin
  LCache := TIntLFU.Create(50, 8);
  try
    for LI := 1 to 50 do
      CheckEqual(Ord(lfAdded), Ord(LCache.Put(LI, LI * 100)));

    CheckEqual(PtrUInt(50), LCache.Count);

    for LI := 1 to 50 do
    begin
      Check(LCache.Get(LI, LValue), 'Should find key');
      CheckEqual(Int64(LI * 100), LValue);
    end;
  finally
    LCache.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_lfu ===');
  WriteLn;

  TestLfuBasic;
  WriteLn('  + Basic operations');

  TestLfuUpdate;
  WriteLn('  + Update');

  TestLfuRemove;
  WriteLn('  + Remove');

  TestLfuContains;
  WriteLn('  + Contains');

  TestLfuCount;
  WriteLn('  + Count');

  TestLfuHitRate;
  WriteLn('  + Hit rate');

  TestLfuClose;
  WriteLn('  + Close semantics');

  TestLfuEmpty;
  WriteLn('  + Empty');

  TestLfuClear;
  WriteLn('  + Clear');

  TestLfuMultipleBuckets;
  WriteLn('  + Multiple buckets');

  WriteLn;
  WriteLn('All LFU cache tests passed!');
end.
