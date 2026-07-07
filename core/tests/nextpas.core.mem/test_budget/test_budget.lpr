program test_budget;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.budget;

var
  T: TTestSuite;

{ --- TMemoryBudget tests --- }

var
  GSoftCallCount: Integer;
  GHardCallCount: Integer;

procedure TestBudgetInitiallyZero;
var
  LBudget: TMemoryBudget;
begin
  LBudget := TMemoryBudget.Create(1024, 2048);
  try
    Check(LBudget.UsedBytes = 0, 'initially used=0');
    Check(not LBudget.IsOverSoftLimit, 'not over soft limit');
    Check(not LBudget.IsOverHardLimit, 'not over hard limit');
  finally
    LBudget.Free;
  end;
end;

procedure TestBudgetRecordAllocFree;
var
  LBudget: TMemoryBudget;
begin
  LBudget := TMemoryBudget.Create(1000, 2000);
  try
    LBudget.RecordAlloc(500);
    Check(LBudget.UsedBytes = 500, 'used=500 after alloc');
    Check(not LBudget.IsOverSoftLimit, 'not over soft');

    LBudget.RecordAlloc(600);
    Check(LBudget.UsedBytes = 1100, 'used=1100');
    Check(LBudget.IsOverSoftLimit, 'over soft limit');
    Check(not LBudget.IsOverHardLimit, 'not over hard');

    LBudget.RecordFree(200);
    Check(LBudget.UsedBytes = 900, 'used=900 after free');
    Check(not LBudget.IsOverSoftLimit, 'not over soft after free');
  finally
    LBudget.Free;
  end;
end;

procedure SoftLimitHandler(AUsedBytes: UInt64; ALimitBytes: UInt64);
begin
  Inc(GSoftCallCount);
end;

procedure HardLimitHandler(AUsedBytes: UInt64; ALimitBytes: UInt64);
begin
  Inc(GHardCallCount);
end;

procedure TestBudgetSoftLimitCallback;
var
  LBudget: TMemoryBudget;
begin
  LBudget := TMemoryBudget.Create(100, 0);
  try
    LBudget.OnSoftLimit := @SoftLimitHandler;
    GSoftCallCount := 0;

    LBudget.RecordAlloc(50);
    Check(GSoftCallCount = 0, 'soft callback not fired yet');

    LBudget.RecordAlloc(60);
    Check(GSoftCallCount = 1, 'soft callback fired once');

    // 再次超过不应重复触发
    LBudget.RecordAlloc(10);
    Check(GSoftCallCount = 1, 'soft callback not fired again');
  finally
    LBudget.Free;
  end;
end;

procedure TestBudgetReset;
var
  LBudget: TMemoryBudget;
begin
  LBudget := TMemoryBudget.Create(100, 200);
  try
    LBudget.RecordAlloc(150);
    Check(LBudget.IsOverSoftLimit, 'over soft');
    LBudget.Reset;
    Check(LBudget.UsedBytes = 0, 'used=0 after reset');
    Check(not LBudget.IsOverSoftLimit, 'not over soft after reset');
  finally
    LBudget.Free;
  end;
end;

{ --- TBudgetAllocator tests --- }

procedure TestBudgetAllocatorPassthrough;
var
  LBudget: TMemoryBudget;
  LAllocator: TBudgetAllocator;
  LPtr: Pointer;
begin
  LBudget := TMemoryBudget.Create(0, 0); // 无限制
  LAllocator := TBudgetAllocator.Create(GetRtlAllocator, LBudget);
  try
    LPtr := LAllocator.GetMem(1024);
    Check(LPtr <> nil, 'alloc succeeds with no limit');
    LAllocator.FreeMem(LPtr);
  finally
    LAllocator.Free;
    LBudget.Free;
  end;
end;

procedure TestBudgetAllocatorHardLimit;
var
  LBudget: TMemoryBudget;
  LAllocator: TBudgetAllocator;
  LPtr: Pointer;
begin
  LBudget := TMemoryBudget.Create(0, 100); // 硬限制 100B
  LAllocator := TBudgetAllocator.Create(GetRtlAllocator, LBudget);
  try
    // 先记录一些使用量
    LBudget.RecordAlloc(90);
    // 尝试分配超过硬限制
    LPtr := LAllocator.GetMem(20);
    Check(LPtr = nil, 'alloc fails over hard limit');
    // 在限制内分配
    LPtr := LAllocator.GetMem(5);
    Check(LPtr <> nil, 'alloc succeeds within limit');
    if LPtr <> nil then
      LAllocator.FreeMem(LPtr);
  finally
    LAllocator.Free;
    LBudget.Free;
  end;
end;

procedure TestBudgetAllocatorTraits;
var
  LBudget: TMemoryBudget;
  LAllocator: TBudgetAllocator;
  LTraits: TAllocatorTraits;
begin
  LBudget := TMemoryBudget.Create;
  LAllocator := TBudgetAllocator.Create(GetRtlAllocator, LBudget);
  try
    LTraits := LAllocator.Traits;
    Check(LTraits.SupportsRealloc, 'RTL supports realloc');
  finally
    LAllocator.Free;
    LBudget.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.budget');

  T.Test('budget initially zero', @TestBudgetInitiallyZero);
  T.Test('budget record alloc/free', @TestBudgetRecordAllocFree);
  T.Test('budget soft limit callback', @TestBudgetSoftLimitCallback);
  T.Test('budget reset', @TestBudgetReset);
  T.Test('allocator passthrough', @TestBudgetAllocatorPassthrough);
  T.Test('allocator hard limit', @TestBudgetAllocatorHardLimit);
  T.Test('allocator traits', @TestBudgetAllocatorTraits);

  T.Run;
end.
