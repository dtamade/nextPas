program test_lockfree_arccache;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.arccache,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.test;

procedure TestARCCacheBasic;
var
  LCache: TARCCacheImpl;
  LVal: UInt64;
begin
  LCache := TARCCacheImpl.Create(16);
  try
    { Put and get }
    CheckEqual(Ord(arcOk), Ord(LCache.Put(1, 100)));
    CheckEqual(Ord(arcOk), Ord(LCache.Put(2, 200)));
    CheckEqual(Ord(arcOk), Ord(LCache.Put(3, 300)));

    CheckEqual(Ord(arcOk), Ord(LCache.Get(1, LVal)));
    CheckEqual(UInt64(100), LVal);

    CheckEqual(Ord(arcOk), Ord(LCache.Get(2, LVal)));
    CheckEqual(UInt64(200), LVal);

    CheckEqual(Ord(arcOk), Ord(LCache.Get(3, LVal)));
    CheckEqual(UInt64(300), LVal);

    CheckEqual(3, LCache.GetSize);
    CheckEqual(16, LCache.GetCapacity);
  finally
    LCache.Free;
  end;
end;

procedure TestARCCacheNotFound;
var
  LCache: TARCCacheImpl;
  LVal: UInt64;
begin
  LCache := TARCCacheImpl.Create(8);
  try
    CheckEqual(Ord(arcNotFound), Ord(LCache.Get(99, LVal)));
  finally
    LCache.Free;
  end;
end;

procedure TestARCCacheEviction;
var
  LCache: TARCCacheImpl;
  LVal: UInt64;
  LI: Integer;
begin
  LCache := TARCCacheImpl.Create(4);
  try
    { Fill cache beyond capacity }
    for LI := 1 to 10 do
      LCache.Put(LI, LI * 100);

    { Recent items should be in cache }
    Check(LCache.GetSize <= 4, 'Size should not exceed capacity');
  finally
    LCache.Free;
  end;
end;

procedure TestARCCacheClose;
var
  LCache: TARCCacheImpl;
begin
  LCache := TARCCacheImpl.Create(8);
  try
    LCache.Put(1, 100);
    LCache.Close;
    Check(LCache.IsClosed, 'Should be closed');
    CheckEqual(Ord(arcClosed), Ord(LCache.Put(2, 200)));
  finally
    LCache.Free;
  end;
end;

procedure TestARCCacheRejectsUnrepresentableCapacity;
var
  LCache: TARCCacheImpl;
  LRaised: Boolean;
begin
  LCache := nil;
  LRaised := False;
  try
    try
      LCache := TARCCacheImpl.Create(High(UInt32));
    except
      on E: EArgumentError do
        LRaised := True;
    end;
  finally
    LCache.Free;
  end;
  Check(LRaised, 'Capacity above High(Integer) must be rejected');
end;

begin
  WriteLn('=== test_lockfree_arccache ===');
  WriteLn;

  TestARCCacheBasic;
  WriteLn('  + Basic put/get');

  TestARCCacheNotFound;
  WriteLn('  + Not found');

  TestARCCacheEviction;
  WriteLn('  + Eviction');

  TestARCCacheClose;
  WriteLn('  + Close semantics');

  TestARCCacheRejectsUnrepresentableCapacity;
  WriteLn('  + Capacity overflow guard');

  WriteLn;
  WriteLn('All ARC Cache tests passed!');
end.
