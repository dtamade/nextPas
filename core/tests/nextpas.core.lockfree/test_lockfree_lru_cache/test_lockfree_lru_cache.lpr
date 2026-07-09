{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_lru_cache;

uses
  SysUtils,
  nextpas.core.lockfree.lru_cache;

var
  GPassed, GFailed: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure Test_Empty;
var
  LLRU: TConcurrentLRUCache;
  LVal: AnsiString;
begin
  WriteLn('--- Empty ---');
  LLRU := TConcurrentLRUCache.Create(100);
  try
    Check(LLRU.Count = 0, 'empty count = 0');
    Check(LLRU.Get('key', LVal) = lrNotFound, 'empty Get = not found');
    Check(not LLRU.Contains('key'), 'empty not contains');
    LLRU.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LLRU.Free;
    end;
  end;
end;

procedure Test_PutGet;
var
  LLRU: TConcurrentLRUCache;
  LVal: AnsiString;
begin
  WriteLn('--- Put/Get ---');
  LLRU := TConcurrentLRUCache.Create(100);
  try
    Check(LLRU.Put('k1', 'v1') = lrOk, 'Put(k1) = ok');
    Check(LLRU.Put('k2', 'v2') = lrOk, 'Put(k2) = ok');
    Check(LLRU.Count = 2, 'count = 2');
    Check(LLRU.Get('k1', LVal) = lrOk, 'Get(k1) = ok');
    Check(LVal = 'v1', 'k1 = v1');
    Check(LLRU.Get('k2', LVal) = lrOk, 'Get(k2) = ok');
    Check(LVal = 'v2', 'k2 = v2');
    Check(LLRU.Get('k3', LVal) = lrNotFound, 'Get(k3) = not found');
    LLRU.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LLRU.Free;
    end;
  end;
end;

procedure Test_Update;
var
  LLRU: TConcurrentLRUCache;
  LVal: AnsiString;
begin
  WriteLn('--- Update ---');
  LLRU := TConcurrentLRUCache.Create(100);
  try
    LLRU.Put('k1', 'v1');
    LLRU.Put('k1', 'v2');
    Check(LLRU.Count = 1, 'count = 1 after update');
    Check(LLRU.Get('k1', LVal) = lrOk, 'Get(k1) = ok');
    Check(LVal = 'v2', 'k1 = v2 (updated)');
    LLRU.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LLRU.Free;
    end;
  end;
end;

procedure Test_Eviction;
var
  LLRU: TConcurrentLRUCache;
  LVal: AnsiString;
  I: Int32;
begin
  WriteLn('--- Eviction ---');
  LLRU := TConcurrentLRUCache.Create(3);
  try
    LLRU.Put('a', '1');
    LLRU.Put('b', '2');
    LLRU.Put('c', '3');
    Check(LLRU.Count = 3, 'count = 3');
    { Add 4th item — should evict 'a' (LRU) }
    LLRU.Put('d', '4');
    Check(LLRU.Count = 3, 'count = 3 after eviction');
    Check(LLRU.Get('a', LVal) = lrNotFound, 'a evicted');
    Check(LLRU.Get('d', LVal) = lrOk, 'd exists');
    Check(LVal = '4', 'd = 4');
    LLRU.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LLRU.Free;
    end;
  end;
end;

procedure Test_LRUSorting;
var
  LLRU: TConcurrentLRUCache;
  LVal: AnsiString;
begin
  WriteLn('--- LRU Sorting ---');
  LLRU := TConcurrentLRUCache.Create(3);
  try
    LLRU.Put('a', '1');
    LLRU.Put('b', '2');
    LLRU.Put('c', '3');
    { Access 'a' — promotes it to MRU }
    LLRU.Get('a', LVal);
    { Now LRU order: b, c, a }
    LLRU.Put('d', '4');
    { Should evict 'b' (now LRU) }
    Check(LLRU.Get('b', LVal) = lrNotFound, 'b evicted');
    Check(LLRU.Get('a', LVal) = lrOk, 'a still exists');
    LLRU.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LLRU.Free;
    end;
  end;
end;

procedure Test_Remove;
var
  LLRU: TConcurrentLRUCache;
begin
  WriteLn('--- Remove ---');
  LLRU := TConcurrentLRUCache.Create(100);
  try
    LLRU.Put('k1', 'v1');
    LLRU.Put('k2', 'v2');
    Check(LLRU.Remove('k1') = lrOk, 'Remove(k1) = ok');
    Check(LLRU.Count = 1, 'count = 1');
    Check(not LLRU.Contains('k1'), 'not contains k1');
    Check(LLRU.Remove('k1') = lrNotFound, 'Remove(k1) again = not found');
    LLRU.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LLRU.Free;
    end;
  end;
end;

procedure Test_Clear;
var
  LLRU: TConcurrentLRUCache;
begin
  WriteLn('--- Clear ---');
  LLRU := TConcurrentLRUCache.Create(100);
  try
    LLRU.Put('k1', 'v1');
    LLRU.Put('k2', 'v2');
    LLRU.Clear;
    Check(LLRU.Count = 0, 'count = 0 after clear');
    Check(not LLRU.Contains('k1'), 'not contains k1 after clear');
    LLRU.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LLRU.Free;
    end;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;
  WriteLn('=== LRUCache Tests ===');
  Test_Empty;
  Test_PutGet;
  Test_Update;
  Test_Eviction;
  Test_LRUSorting;
  Test_Remove;
  Test_Clear;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.
