{**
 * np_query_database_test.pas
 *
 * TQueryDatabase 单元测试
 *
 * 测试覆盖：
 *   - 基本 Get 缓存命中/未命中
 *   - Invalidate 失效
 *   - InvalidatePrefix 前缀失效
 *   - Clear 清空
 *   - HitRate 统计
 *}

unit np_query_database_test;

{$mode objfpc}{$H+}

interface

uses
  np_query_database;

{ 运行所有测试，失败抛出异常 }
procedure RunQueryDatabaseTests;

implementation

uses
  SysUtils;

type
  TTestContext = class
  public
    ComputeCount: LongInt;
    function ComputeFunc(const AKey: string): TQueryValue;
  end;

function TTestContext.ComputeFunc(const AKey: string): TQueryValue;
begin
  Inc(ComputeCount);
  Result := TObject.Create;
end;

procedure Test_Get_Miss;
var
  DB: TQueryDatabase;
  Ctx: TTestContext;
  V: TQueryValue;
begin
  DB := TQueryDatabase.Create;
  Ctx := TTestContext.Create;
  try
    V := DB.Get('key1', @Ctx.ComputeFunc);
    Assert(V <> nil, 'Get should return value');
    Assert(Ctx.ComputeCount = 1, 'First Get should compute');
    Assert(DB.EntryCount = 1, 'Should have 1 entry');
    Assert(DB.MissCount = 1, 'Should have 1 miss');
  finally
    Ctx.Free;
    DB.Free;
  end;
end;

procedure Test_Get_Hit;
var
  DB: TQueryDatabase;
  Ctx: TTestContext;
  V1, V2: TQueryValue;
begin
  DB := TQueryDatabase.Create;
  Ctx := TTestContext.Create;
  try
    V1 := DB.Get('key1', @Ctx.ComputeFunc);
    V2 := DB.Get('key1', @Ctx.ComputeFunc);
    Assert(V1 = V2, 'Same key should return same value');
    Assert(Ctx.ComputeCount = 1, 'Second Get should not compute');
    Assert(DB.HitCount = 1, 'Should have 1 hit');
    Assert(DB.MissCount = 1, 'Should have 1 miss');
  finally
    Ctx.Free;
    DB.Free;
  end;
end;

procedure Test_Invalidate;
var
  DB: TQueryDatabase;
  Ctx: TTestContext;
  V1, V2: TQueryValue;
begin
  DB := TQueryDatabase.Create;
  Ctx := TTestContext.Create;
  try
    V1 := DB.Get('key1', @Ctx.ComputeFunc);
    DB.Invalidate('key1');
    { After invalidate, Get with nil func returns nil (dirty entry skipped) }
    V2 := DB.Get('key1', nil);
    Assert(V2 = nil, 'Invalidated key should return nil');
    { But with compute func, it recomputes }
    V2 := DB.Get('key1', @Ctx.ComputeFunc);
    Assert(V2 <> nil, 'Recompute should return new value');
    Assert(Ctx.ComputeCount = 2, 'Should recompute after invalidate');
  finally
    { Free values manually since DB no longer owns them }
    V1.Free;
    V2.Free;
    Ctx.Free;
    DB.Free;
  end;
end;

procedure Test_InvalidatePrefix;
var
  DB: TQueryDatabase;
  Ctx: TTestContext;
begin
  DB := TQueryDatabase.Create;
  Ctx := TTestContext.Create;
  try
    DB.Get('parse:file1.pas', @Ctx.ComputeFunc);
    DB.Get('parse:file2.pas', @Ctx.ComputeFunc);
    DB.Get('type:MyType', @Ctx.ComputeFunc);
    Assert(Ctx.ComputeCount = 3, 'Should have 3 computations');
    Assert(DB.EntryCount = 3, 'Should have 3 entries');

    DB.InvalidatePrefix('parse:');
    Assert(DB.EntryCount = 3, 'Entries remain (marked dirty)');

    { Re-get parse entries — should return nil without compute func }
    Assert(DB.Get('parse:file1.pas', nil) = nil, 'dirty entry returns nil');
    Assert(DB.Get('parse:file2.pas', nil) = nil, 'dirty entry returns nil');

    { Re-get with compute — should recompute }
    DB.Get('parse:file1.pas', @Ctx.ComputeFunc);
    DB.Get('parse:file2.pas', @Ctx.ComputeFunc);
    Assert(Ctx.ComputeCount = 5, 'parse entries should recompute');

    { type entry should still be cached }
    DB.Get('type:MyType', @Ctx.ComputeFunc);
    Assert(Ctx.ComputeCount = 5, 'type entry should not recompute');
  finally
    Ctx.Free;
    DB.Free;
  end;
end;

procedure Test_Clear;
var
  DB: TQueryDatabase;
  Ctx: TTestContext;
begin
  DB := TQueryDatabase.Create;
  Ctx := TTestContext.Create;
  try
    DB.Get('key1', @Ctx.ComputeFunc);
    DB.Get('key2', @Ctx.ComputeFunc);
    Assert(DB.EntryCount = 2, 'Should have 2 entries');

    DB.Clear;
    Assert(DB.EntryCount = 0, 'Should have 0 entries after Clear');
    Assert(DB.HitCount = 0, 'Hits should reset');
    Assert(DB.MissCount = 0, 'Misses should reset');

    { Re-get after clear }
    DB.Get('key1', @Ctx.ComputeFunc);
    Assert(Ctx.ComputeCount = 3, 'Should recompute after clear');
  finally
    Ctx.Free;
    DB.Free;
  end;
end;

procedure Test_HitRate;
var
  DB: TQueryDatabase;
  Ctx: TTestContext;
begin
  DB := TQueryDatabase.Create;
  Ctx := TTestContext.Create;
  try
    Assert(Abs(DB.HitRate) < 0.001, 'Empty DB should have 0 hit rate');

    DB.Get('a', @Ctx.ComputeFunc);  { miss }
    DB.Get('a', @Ctx.ComputeFunc);  { hit  }
    DB.Get('b', @Ctx.ComputeFunc);  { miss }
    DB.Get('b', @Ctx.ComputeFunc);  { hit  }
    DB.Get('b', @Ctx.ComputeFunc);  { hit  }

    Assert(Abs(DB.HitRate - 0.6) < 0.001, 'Hit rate should be 3/5 = 0.6');
  finally
    Ctx.Free;
    DB.Free;
  end;
end;

procedure RunQueryDatabaseTests;
begin
  Test_Get_Miss;
  Test_Get_Hit;
  Test_Invalidate;
  Test_InvalidatePrefix;
  Test_Clear;
  Test_HitRate;
end;

end.
