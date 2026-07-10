unit nextpas.core.mem.allocator.leak_check;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.tracking;

type
  TAllocatorTestProc = procedure(AAllocator: IAllocator);

  TLeakCheckResult = record
    HasLeaks: Boolean;
    AllocCount: SizeInt;
    AllocBytes: SizeUInt;
    Report: string;
  end;

function RunTestWithLeakCheck(ATest: TAllocatorTestProc;
  AInnerAllocator: IAllocator = nil): TLeakCheckResult;

implementation

uses
  nextpas.core.mem.allocator.rtl;

function RunTestWithLeakCheck(ATest: TAllocatorTestProc;
  AInnerAllocator: IAllocator): TLeakCheckResult;
var
  LInner: IAllocator;
  LTracker: IAllocator;
  LTrackerObj: TTrackingAllocator;
begin
  if AInnerAllocator <> nil then
    LInner := AInnerAllocator
  else
    LInner := GetRtlAllocator;

  LTrackerObj := TTrackingAllocator.Create(LInner);
  LTracker := LTrackerObj;
  try
    ATest(LTracker);
    Result.AllocCount := LTrackerObj.ActiveAllocCount;
    Result.AllocBytes := LTrackerObj.ActiveAllocBytes;
    Result.HasLeaks := LTrackerObj.HasLeaks;
    Result.Report := LTrackerObj.ReportLeaks;
  finally
    LTracker := nil;
  end;
end;

end.
