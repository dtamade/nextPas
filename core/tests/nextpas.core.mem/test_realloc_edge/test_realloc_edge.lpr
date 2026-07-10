program test_realloc_edge;
{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestReallocGrow;
var
  LAlloc: IAllocator;
  LPtr, LNew: Pointer;
  LI: Integer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(64);
  Check(LPtr <> nil, 'Initial alloc should succeed');
  for LI := 0 to 63 do
    PByte(LPtr)[LI] := Byte(LI);

  LNew := LAlloc.ReallocMem(LPtr, 256);
  Check(LNew <> nil, 'Realloc grow should succeed');
  { Verify data preserved }
  for LI := 0 to 63 do
    Check(PByte(LNew)[LI] = Byte(LI), 'Data lost after grow at index ' + IntToStr(LI));
  LAlloc.FreeMem(LNew);
end;

procedure TestReallocShrink;
var
  LAlloc: IAllocator;
  LPtr, LNew: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(512);
  Check(LPtr <> nil, 'Initial alloc should succeed');
  FillChar(LPtr^, 512, $AB);

  LNew := LAlloc.ReallocMem(LPtr, 64);
  Check(LNew <> nil, 'Realloc shrink should succeed');
  Check(PByte(LNew)^ = $AB, 'Data should survive shrink');
  LAlloc.FreeMem(LNew);
end;

procedure TestReallocNil;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.ReallocMem(nil, 128);
  Check(LPtr <> nil, 'ReallocMem(nil, 128) should act as GetMem');
  LAlloc.FreeMem(LPtr);
end;

procedure TestReallocZeroSize;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(128);
  Check(LPtr <> nil, 'Initial alloc should succeed');
  LPtr := LAlloc.ReallocMem(LPtr, 0);
  Check(LPtr = nil, 'ReallocMem(ptr, 0) should free and return nil');
end;

procedure TestReallocSameSize;
var
  LAlloc: IAllocator;
  LPtr, LNew: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(128);
  Check(LPtr <> nil, 'Initial alloc should succeed');
  PByte(LPtr)^ := $42;
  LNew := LAlloc.ReallocMem(LPtr, 128);
  Check(LNew <> nil, 'Realloc same size should succeed');
  Check(PByte(LNew)^ = $42, 'Data should survive same-size realloc');
  LAlloc.FreeMem(LNew);
end;

procedure TestReallocMultipleGrow;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
  LSize: SizeUInt;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(16);
  Check(LPtr <> nil, 'Initial alloc should succeed');
  PByte(LPtr)^ := $FF;

  for LSize := 32 to 4096 do
  begin
    LPtr := LAlloc.ReallocMem(LPtr, LSize);
    Check(LPtr <> nil, 'Realloc to ' + IntToStr(LSize) + ' should succeed');
    Check(PByte(LPtr)^ = $FF, 'Data should survive realloc to ' + IntToStr(LSize));
  end;
  LAlloc.FreeMem(LPtr);
end;

procedure TestReallocZeroNil;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.ReallocMem(nil, 0);
  Check(LPtr = nil, 'ReallocMem(nil, 0) should return nil');
end;

begin
  T := TTestSuite.Create('test_realloc_edge');
  T.Test('ReallocGrow', @TestReallocGrow);
  T.Test('ReallocShrink', @TestReallocShrink);
  T.Test('ReallocNil', @TestReallocNil);
  T.Test('ReallocZeroSize', @TestReallocZeroSize);
  T.Test('ReallocSameSize', @TestReallocSameSize);
  T.Test('ReallocMultipleGrow', @TestReallocMultipleGrow);
  T.Test('ReallocZeroNil', @TestReallocZeroNil);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
