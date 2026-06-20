program demo_memtrack;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  SysUtils,
  nextpas.core.bench.memtrack;

var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
  LIterations: Int64;
begin
  WriteLn('=== nextpas.core.bench.memtrack Demo ===');
  WriteLn('');

  // Create a memory tracker
  LTracker := TMemoryTracker.Create(True);

  // Simulate benchmark iterations
  WriteLn('Simulating 1000 benchmark iterations...');
  for LIterations := 1 to 1000 do
  begin
    // Simulate 2 allocations and 1 free per iteration
    LTracker.RecordAlloc(64);   // Small allocation
    LTracker.RecordAlloc(1024); // Medium allocation
    LTracker.RecordFree(64);    // Free the small one
  end;

  // Get statistics
  LStats := LTracker.GetStats;

  // Display results
  WriteLn('');
  WriteLn('=== Memory Statistics ===');
  WriteLn('Total Allocations: ', LStats.AllocCount);
  WriteLn('Total Frees: ', LStats.FreeCount);
  WriteLn('Total Bytes Allocated: ', LStats.AllocBytes);
  WriteLn('Total Bytes Freed: ', LStats.FreeBytes);
  WriteLn('Peak Allocations: ', LStats.PeakAllocs);
  WriteLn('Peak Bytes: ', LStats.PeakBytes);
  WriteLn('Current Allocations: ', LStats.CurrentAllocs);
  WriteLn('Current Bytes: ', LStats.CurrentBytes);

  WriteLn('');
  WriteLn('=== Per-Operation Metrics ===');
  WriteLn('Bytes per iteration: ', LTracker.BytesPerOp(1000):0:2);
  WriteLn('Allocs per iteration: ', LTracker.AllocsPerOp(1000):0:2);

  // Simulate memory leak detection
  WriteLn('');
  WriteLn('=== Memory Leak Detection ===');
  if LStats.CurrentAllocs > 0 then
    WriteLn('WARNING: ', LStats.CurrentAllocs, ' allocations not freed (potential memory leak)')
  else
    WriteLn('OK: All allocations freed');

  // Reset and reuse
  WriteLn('');
  WriteLn('Resetting tracker...');
  LTracker.Reset;
  LStats := LTracker.GetStats;
  WriteLn('After reset:');
  WriteLn('  Allocations: ', LStats.AllocCount);
  WriteLn('  Bytes: ', LStats.AllocBytes);

  WriteLn('');
  WriteLn('=== Demo Complete ===');
end.
