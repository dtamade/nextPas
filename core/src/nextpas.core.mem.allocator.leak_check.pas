unit nextpas.core.mem.allocator.leak_check;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.tracking;

type
  {** 带 allocator 参数的回调类型 }
  TAllocatorTestProc = procedure(AAllocator: IAllocator);

  {** 泄漏检查结果 }
  TLeakCheckResult = record
    HasLeaks: Boolean;
    AllocCount: SizeInt;
    AllocBytes: SizeUInt;
    Report: string;
  end;

{** 运行测试过程并检查泄漏。
    ATest 会收到一个 TTrackingAllocator 作为 IAllocator 参数，
    回调内应通过该参数进行分配以确保泄漏被检测到。
    如果 AInnerAllocator 为 nil，使用默认的 TRtlAllocator。
    返回泄漏检查结果。 }
function RunTestWithLeakCheck(ATest: TAllocatorTestProc;
  AInnerAllocator: IAllocator = nil): TLeakCheckResult;

implementation

uses
  nextpas.core.mem.allocator.rtl;

function RunTestWithLeakCheck(ATest: TAllocatorTestProc;
  AInnerAllocator: IAllocator): TLeakCheckResult;
var
  LInner: IAllocator;
  LTracker: TTrackingAllocator;
  LTrackerIntf: IAllocator;
begin
  if AInnerAllocator <> nil then
    LInner := AInnerAllocator
  else
    LInner := GetRtlAllocator;

  { 创建 tracker 并通过接口变量管理生命周期 }
  LTracker := TTrackingAllocator.Create(LInner);
  LTrackerIntf := LTracker as IAllocator;
  { LTrackerIntf 现在持有引用，不再通过 LTracker.Free 释放 }
  LTracker := nil;

  try
    ATest(LTrackerIntf);

    { 通过接口向下转型来查询状态 }
    LTracker := LTrackerIntf as TTrackingAllocator;
    Result.AllocCount := LTracker.ActiveAllocCount;
    Result.AllocBytes := LTracker.ActiveAllocBytes;
    Result.HasLeaks := LTracker.HasLeaks;
    Result.Report := LTracker.ReportLeaks;
  finally
    LTrackerIntf := nil;
  end;
end;

end.
