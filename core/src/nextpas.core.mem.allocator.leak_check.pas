unit nextpas.core.mem.allocator.leak_check;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.tracking;

type
  TAllocatorTestProc = procedure(AAllocator: TAllocator);

  TLeakCheckResult = record
    HasLeaks: Boolean;
    AllocCount: SizeInt;
    AllocBytes: SizeUInt;
    Report: string;
  end;

function RunTestWithLeakCheck(ATest: TAllocatorTestProc;
  AInnerAllocator: TAllocator = nil): TLeakCheckResult;

implementation

uses
  nextpas.core.mem.allocator.rtl;

function RunTestWithLeakCheck(ATest: TAllocatorTestProc;
  AInnerAllocator: TAllocator): TLeakCheckResult;
var
  LInner: TAllocator;
  LTracker: TTrackingAllocator;
begin
  if AInnerAllocator <> nil then
    LInner := AInnerAllocator
  else
    LInner := GetRtlAllocator;

  LTracker := TTrackingAllocator.Create(LInner);
  try
    ATest(LTracker);
    Result.AllocCount := LTracker.ActiveAllocCount;
    Result.AllocBytes := LTracker.ActiveAllocBytes;
    Result.HasLeaks := LTracker.HasLeaks;
    Result.Report := LTracker.ReportLeaks;
  finally
    LTracker.Free;
  end;
end;

end.
