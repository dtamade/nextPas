program test_numa_allocator;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.numa;

var
  T: TTestRunner;

procedure TestDefaultNumaProviderIsExplicitNoOp;
var
  LProvider: INumaAllocatorProvider;
  LCaps: TNumaAllocatorCapabilities;
  LAllocator: IAllocator;
begin
  LProvider := GetDefaultNumaAllocatorProvider;
  Check(LProvider <> nil, 'default NUMA provider should exist');

  LCaps := LProvider.Capabilities;
  CheckEqual(False, LCaps.Available, 'default NUMA provider should not claim availability');
  CheckEqual(False, LCaps.SupportsNodeBinding, 'default NUMA provider should not claim node binding');
  CheckEqual(False, LCaps.SupportsInterleave, 'default NUMA provider should not claim interleave');

  LAllocator := nil;
  CheckEqual(False, LProvider.TryCreateNodeAllocator(0, LAllocator), 'node allocator should not silently fall back');
  Check(LAllocator = nil, 'failed NUMA node allocator should leave nil allocator');

  LAllocator := nil;
  CheckEqual(False, LProvider.TryCreateInterleavedAllocator(LAllocator), 'interleaved allocator should not silently fall back');
  Check(LAllocator = nil, 'failed NUMA interleave allocator should leave nil allocator');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.numa_allocator');
  T.Run('default provider is explicit no-op', @TestDefaultNumaProviderIsExplicitNoOp);
  T.Summary;
end.
