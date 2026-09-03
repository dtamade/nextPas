{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_ttl_cache;

uses
  nextpas.core.thread.init,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.platform.thread,
  nextpas.core.lockfree.ttl_cache;

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
  LCache: TTTLCache;
  LVal: AnsiString;
begin
  WriteLn('--- Empty ---');
  LCache := TTTLCache.Create(100, 60000);
  try
    Check(LCache.Count = 0, 'empty count = 0');
    Check(LCache.IsEmpty, 'empty is empty');
    Check(LCache.Get('key', LVal) = ttlNotFound, 'empty get = not found');
    Check(not LCache.Contains('key'), 'empty not contains');
    Check(LCache.Remove('key') = ttlNotFound, 'empty remove = not found');
  finally
    LCache.Free;
  end;
end;

procedure Test_PutGet;
var
  LCache: TTTLCache;
  LVal: AnsiString;
begin
  WriteLn('--- PutGet ---');
  LCache := TTTLCache.Create(100, 60000);
  try
    Check(LCache.Put('hello', 'world') = ttlOk, 'put hello');
    Check(LCache.Count = 1, 'count = 1');
    Check(LCache.Get('hello', LVal) = ttlOk, 'get hello');
    Check(LVal = 'world', 'value = world');
    Check(LCache.Contains('hello'), 'contains hello');
  finally
    LCache.Free;
  end;
end;

procedure Test_Update;
var
  LCache: TTTLCache;
  LVal: AnsiString;
begin
  WriteLn('--- Update ---');
  LCache := TTTLCache.Create(100, 60000);
  try
    LCache.Put('key', 'v1');
    LCache.Put('key', 'v2');
    Check(LCache.Count = 1, 'count still 1');
    Check(LCache.Get('key', LVal) = ttlOk, 'get key');
    Check(LVal = 'v2', 'value updated to v2');
  finally
    LCache.Free;
  end;
end;

procedure Test_Remove;
var
  LCache: TTTLCache;
begin
  WriteLn('--- Remove ---');
  LCache := TTTLCache.Create(100, 60000);
  try
    LCache.Put('a', '1');
    LCache.Put('b', '2');
    Check(LCache.Remove('a') = ttlOk, 'remove a');
    Check(LCache.Count = 1, 'count = 1');
    Check(not LCache.Contains('a'), 'not contains a');
    Check(LCache.Contains('b'), 'contains b');
  finally
    LCache.Free;
  end;
end;

procedure Test_Eviction;
var
  LCache: TTTLCache;
  LVal: AnsiString;
begin
  WriteLn('--- Eviction ---');
  LCache := TTTLCache.Create(3, 60000);
  try
    LCache.Put('a', '1');
    LCache.Put('b', '2');
    LCache.Put('c', '3');
    Check(LCache.Count = 3, 'count = 3');
    LCache.Put('d', '4');
    Check(LCache.Count = 3, 'count still 3 after eviction');
    Check(LCache.Get('d', LVal) = ttlOk, 'd exists');
  finally
    LCache.Free;
  end;
end;

procedure Test_CustomTTL;
var
  LCache: TTTLCache;
  LVal: AnsiString;
begin
  WriteLn('--- CustomTTL ---');
  LCache := TTTLCache.Create(100, 60000);
  try
    LCache.PutWithTTL('key', 'value', 1000);
    Check(LCache.Get('key', LVal) = ttlOk, 'get with custom ttl');
    Check(LVal = 'value', 'value matches');
  finally
    LCache.Free;
  end;
end;

procedure Test_ExpiredEntryCleanup;
var
  LCache: TTTLCache;
  LVal: AnsiString;
begin
  WriteLn('--- ExpiredEntryCleanup ---');
  LCache := TTTLCache.Create(4, 60000);
  try
    Check(LCache.PutWithTTL('short', 'value', 1) = ttlOk, 'put short ttl');
    platform_thread_sleep_ms(5);
    Check(LCache.Get('short', LVal) = ttlExpired, 'expired get removes entry');
    Check(LCache.Count = 0, 'expired entry decrements count');
  finally
    LCache.Free;
  end;
end;

procedure Test_DeadlineAndDefaultTTLContracts;
var
  LSource: string;
begin
  WriteLn('--- DeadlineAndDefaultTTLContracts ---');
  LSource := ReadFileText('../../../src/nextpas.core.lockfree.ttl_cache.pas');
    Check(Pos('atomic_load_64(FDefaultTTL, mo_acquire)', LSource) > 0,
      'default TTL is read atomically');
    Check(Pos('ATTLMs > High(Int64) - ANow', LSource) > 0,
      'expiration deadline addition is saturated');
end;

procedure Test_MultipleKeys;
var
  LCache: TTTLCache;
  LVal: AnsiString;
  I: Int32;
begin
  WriteLn('--- MultipleKeys ---');
  LCache := TTTLCache.Create(1000, 60000);
  try
    for I := 1 to 100 do
      LCache.Put('key' + IntToStr(I), 'val' + IntToStr(I));
    Check(LCache.Count = 100, 'count = 100');
    for I := 1 to 100 do
    begin
      Check(LCache.Get('key' + IntToStr(I), LVal) = ttlOk, 'find key' + IntToStr(I));
      Check(LVal = 'val' + IntToStr(I), 'value matches');
    end;
  finally
    LCache.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  Test_Empty;
  Test_PutGet;
  Test_Update;
  Test_Remove;
  Test_Eviction;
  Test_CustomTTL;
  Test_ExpiredEntryCleanup;
  Test_DeadlineAndDefaultTTLContracts;
  Test_MultipleKeys;

  WriteLn;
  WriteLn('=== TTLCache: ', GPassed, ' passed, ', GFailed, ' failed ===');
  if GFailed > 0 then
    Halt(1);
end.
