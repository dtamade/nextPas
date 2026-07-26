program test_allocator_foundation;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.system.heap,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.rtl;

var
  T: TTestSuite;
  LRunPassed: Boolean;
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
  Result := NpSystemGetMem(ASize);
end;

function FoundationAllocMem(ASize: SizeUInt): Pointer;
begin
  Inc(GAllocMemCalls);
  Result := NpSystemAllocMem(ASize);
end;

function FoundationReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  Inc(GReallocMemCalls);
  Result := NpSystemReallocMem(ADst, ASize);
end;

procedure FoundationFreeMem(ADst: Pointer);
begin
  Inc(GFreeMemCalls);
  NpSystemFreeMem(ADst);
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
  Check(GGetMemCalls = 1, 'GetMem should call the GetMem callback');

  PByte(LPtr)^ := $7A;
  LPtr := LAllocator.ReallocMem(LPtr, 48);
  Check(LPtr <> nil, 'ReallocMem should return a pointer');
  Check(GReallocMemCalls = 1, 'ReallocMem should call the ReallocMem callback');
  Check(PByte(LPtr)^ = $7A, 'ReallocMem should preserve the existing prefix');

  LAllocator.FreeMem(LPtr);
  Check(GFreeMemCalls = 1, 'FreeMem should call the FreeMem callback');
end;

{ D-2a: TryGetRtlAllocator should return the same singleton as GetRtlAllocator }
procedure TestTryGetRtlAllocator;
var
  LTry: IAllocator;
  LGet: IAllocator;
  LOk: Boolean;
begin
  LOk := TryGetRtlAllocator(LTry);
  LGet := GetRtlAllocator;
  Check(LOk, 'TryGetRtlAllocator should return True');
  Check(LTry <> nil, 'TryGetRtlAllocator should return non-nil allocator');
  Check(LTry = LGet, 'TryGetRtlAllocator should match GetRtlAllocator singleton');
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.allocator.foundation');
  T.Test('RTL allocator matches canonical singleton', @TestFoundationRtlAllocatorMatchesCanonicalSingleton);
  T.Test('callback allocator routes callbacks', @TestFoundationCallbackAllocatorRoutesCallbacks);
  T.Test('TryGetRtlAllocator returns singleton', @TestTryGetRtlAllocator);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
