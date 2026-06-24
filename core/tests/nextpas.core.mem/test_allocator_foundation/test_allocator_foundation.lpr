program test_allocator_foundation;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.rtl;

var
  T: TTestRunner;
  GGetMemCalls: Integer = 0;
  GAllocMemCalls: Integer = 0;
  GReallocMemCalls: Integer = 0;
  GFreeMemCalls: Integer = 0;

procedure ResetCallbackCounters;
begin
  GGetMemCalls := 0;
  GAllocMemCalls := 0;
  GReallocMemCalls := 0;
  GFreeMemCalls := 0;
end;

function FoundationGetMem(ASize: SizeUInt): Pointer;
begin
  Inc(GGetMemCalls);
  Result := System.GetMem(ASize);
end;

function FoundationAllocMem(ASize: SizeUInt): Pointer;
begin
  Inc(GAllocMemCalls);
  Result := System.AllocMem(ASize);
end;

function FoundationReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  Inc(GReallocMemCalls);
  Result := System.ReallocMem(ADst, ASize);
end;

procedure FoundationFreeMem(ADst: Pointer);
begin
  Inc(GFreeMemCalls);
  System.FreeMem(ADst);
end;

procedure TestFoundationRtlAllocatorMatchesCanonicalSingleton;
var
  LFoundationAllocator: IAllocator;
  LCanonicalAllocator: nextpas.core.mem.allocator.base.IAllocator;
begin
  LFoundationAllocator := GetRtlAllocator;
  LCanonicalAllocator := nextpas.core.mem.allocator.rtl.GetRtlAllocator;

  Check(LFoundationAllocator <> nil, 'foundation facade should expose RTL allocator');
  Check(LFoundationAllocator = LCanonicalAllocator,
    'foundation RTL allocator should resolve to the canonical singleton');
end;

procedure TestFoundationCallbackAllocatorRoutesCallbacks;
var
  LAllocator: IAllocator;
  LPtr: Pointer;
begin
  ResetCallbackCounters;
  LAllocator := CreateCallbackAllocator(
    @FoundationGetMem,
    @FoundationAllocMem,
    @FoundationReallocMem,
    @FoundationFreeMem);

  LPtr := LAllocator.GetMem(24);
  Check(LPtr <> nil, 'GetMem should allocate through the callback facade');
  CheckEqual(Int64(1), Int64(GGetMemCalls), 'GetMem should call the GetMem callback');

  PByte(LPtr)^ := $7A;
  LPtr := LAllocator.ReallocMem(LPtr, 48);
  Check(LPtr <> nil, 'ReallocMem should return a pointer');
  CheckEqual(Int64(1), Int64(GReallocMemCalls), 'ReallocMem should call the ReallocMem callback');
  CheckEqual(Int64($7A), Int64(PByte(LPtr)^), 'ReallocMem should preserve the existing prefix');

  LAllocator.FreeMem(LPtr);
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'FreeMem should call the FreeMem callback');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.allocator.foundation');
  T.Run('RTL allocator matches canonical singleton', @TestFoundationRtlAllocatorMatchesCanonicalSingleton);
  T.Run('callback allocator routes callbacks', @TestFoundationCallbackAllocatorRoutesCallbacks);
  T.Summary;
end.
