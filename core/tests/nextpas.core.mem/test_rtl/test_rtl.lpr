program test_rtl;
{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.rtl;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestGetMem;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(256);
  Check(LPtr <> nil, 'GetMem(256) returned nil');
  LAlloc.FreeMem(LPtr);
end;

procedure TestAllocMem;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
  LI: SizeUInt;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.AllocMem(256);
  Check(LPtr <> nil, 'AllocMem(256) returned nil');
  { AllocMem should zero-initialize }
  for LI := 0 to 255 do
    Check(PByte(LPtr)[LI] = 0, 'AllocMem not zero-initialized');
  LAlloc.FreeMem(LPtr);
end;

procedure TestReallocMem;
var
  LAlloc: IAllocator;
  LPtr, LNew: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(128);
  Check(LPtr <> nil, 'GetMem(128) returned nil');
  PByte(LPtr)^ := $AB;
  LNew := LAlloc.ReallocMem(LPtr, 512);
  Check(LNew <> nil, 'ReallocMem returned nil');
  Check(PByte(LNew)^ = $AB, 'ReallocMem lost data');
  LAlloc.FreeMem(LNew);
end;

procedure TestTraits;
var
  LAlloc: IAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := GetRtlAllocator;
  LTraits := LAlloc.Traits;
  Check(LTraits.ZeroInitialized, 'RtlAllocator should be ZeroInitialized');
  Check(LTraits.ThreadSafe, 'RtlAllocator should be ThreadSafe');
end;

procedure TestResolveAllocator;
var
  LResolved: IAllocator;
  LRtl: IAllocator;
begin
  LResolved := ResolveAllocator(nil);
  Check(LResolved <> nil, 'ResolveAllocator(nil) returned nil');
  { S5: nil defaults to process Growing heap, not RTL. }
  Check(LResolved = GetGrowingIAllocator, 'ResolveAllocator(nil) → Growing root');
  LRtl := GetRtlAllocator;
  LResolved := ResolveAllocator(LRtl);
  Check(LResolved = LRtl, 'ResolveAllocator preserves explicit RTL');
end;

procedure TestTryGetRtlAllocator;
var
  LAlloc: IAllocator;
  LOk: Boolean;
begin
  LOk := TryGetRtlAllocator(LAlloc);
  Check(LOk, 'TryGetRtlAllocator returned False');
  Check(LAlloc <> nil, 'TryGetRtlAllocator returned nil allocator');
end;

procedure TestMultipleAllocations;
var
  LAlloc: IAllocator;
  LPtrs: array[0..31] of Pointer;
  LI: Integer;
begin
  LAlloc := GetRtlAllocator;
  for LI := 0 to 31 do
  begin
    LPtrs[LI] := LAlloc.GetMem(64 + SizeUInt(LI) * 8);
    Check(LPtrs[LI] <> nil, 'Allocation #' + IntToStr(LI) + ' failed');
  end;
  for LI := 0 to 31 do
    LAlloc.FreeMem(LPtrs[LI]);
end;

begin
  T := TTestSuite.Create('test_rtl');
  T.Test('GetMem', @TestGetMem);
  T.Test('AllocMem', @TestAllocMem);
  T.Test('ReallocMem', @TestReallocMem);
  T.Test('Traits', @TestTraits);
  T.Test('ResolveAllocator', @TestResolveAllocator);
  T.Test('TryGetRtlAllocator', @TestTryGetRtlAllocator);
  T.Test('MultipleAllocations', @TestMultipleAllocations);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
