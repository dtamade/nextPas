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
