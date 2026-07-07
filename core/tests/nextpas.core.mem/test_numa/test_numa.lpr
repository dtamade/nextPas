program test_numa;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.crt,
  nextpas.core.mem.allocator.numa;

var
  T: TTestSuite;

procedure TestTopologyDetection;
var
  LTopo: TNumaTopology;
begin
  LTopo := DetectNumaTopology;
  Check(LTopo.NodeCount >= 1, 'node count >= 1');
  WriteLn('  NUMA nodes: ', LTopo.NodeCount);
end;

procedure TestCreate;
var
  LAlloc: TNumaAllocator;
begin
  LAlloc := TNumaAllocator.Create(TCrtAllocator.Create);
  try
    Check(LAlloc.Topology.NodeCount >= 1, 'topology detected');
  finally
    LAlloc.Free;
  end;
end;

procedure TestBasicAlloc;
var
  LAlloc: TNumaAllocator;
  LPtr: Pointer;
begin
  LAlloc := TNumaAllocator.Create(TCrtAllocator.Create);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'GetMem(64)');
    FillChar(LPtr^, 64, $AA);
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TNumaAllocator;
  LPtr: PByte;
  LI: Int32;
begin
  LAlloc := TNumaAllocator.Create(TCrtAllocator.Create);
  try
    LPtr := PByte(LAlloc.AllocMem(128));
    Check(LPtr <> nil, 'AllocMem(128)');
    for LI := 0 to 127 do
      Check(LPtr[LI] = 0, 'zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TNumaAllocator;
  LPtr, LNew: PByte;
  LI: Int32;
begin
  LAlloc := TNumaAllocator.Create(TCrtAllocator.Create);
  try
    LPtr := PByte(LAlloc.GetMem(64));
    for LI := 0 to 63 do
      LPtr[LI] := Byte(LI);
    LNew := PByte(LAlloc.ReallocMem(LPtr, 256));
    Check(LNew <> nil, 'ReallocMem(256)');
    for LI := 0 to 63 do
      Check(LNew[LI] = Byte(LI), 'data preserved');
    LAlloc.FreeMem(LNew);
  finally
    LAlloc.Free;
  end;
end;

procedure TestSetNodeAllocator;
var
  LAlloc: TNumaAllocator;
  LNodeAlloc: IAllocator;
begin
  LAlloc := TNumaAllocator.Create(TCrtAllocator.Create);
  try
    LNodeAlloc := TCrtAllocator.Create;
    LAlloc.SetNodeAllocator(0, LNodeAlloc);
    Check(LAlloc.GetNodeAllocator(0) = LNodeAlloc, 'node 0 allocator set');
    { Non-existent node falls back to default }
    Check(LAlloc.GetNodeAllocator(99) <> nil, 'fallback for node 99');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TNumaAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TNumaAllocator.Create(TCrtAllocator.Create);
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ZeroInitialized, 'ZeroInitialized = True');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LAlloc: TNumaAllocator;
  LPtrs: array[0..49] of Pointer;
  LI: Int32;
begin
  LAlloc := TNumaAllocator.Create(TCrtAllocator.Create);
  try
    for LI := 0 to 49 do
    begin
      LPtrs[LI] := LAlloc.GetMem(16 + SizeUInt(LI * 5));
      Check(LPtrs[LI] <> nil, 'alloc ' + IntToStr(LI));
    end;
    for LI := 0 to 49 do
      LAlloc.FreeMem(LPtrs[LI]);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_numa');

  T.Test('topology_detection', @TestTopologyDetection);
  T.Test('create', @TestCreate);
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('alloc_mem_zeroed', @TestAllocMemZeroed);
  T.Test('realloc', @TestRealloc);
  T.Test('set_node_allocator', @TestSetNodeAllocator);
  T.Test('traits', @TestTraits);
  T.Test('multiple_allocs', @TestMultipleAllocs);

  T.Run;
  T.Summary;
end.
