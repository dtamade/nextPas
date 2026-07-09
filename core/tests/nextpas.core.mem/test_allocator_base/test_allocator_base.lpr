program test_allocator_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.error;

type
  { Mock allocator implementing IAllocator directly.
    Verifies zero-size guards, nil guards, and method dispatch. }
  TMockAllocator = class(TInterfacedObject, IAllocator)
  private
    FGetMemCalls: SizeUInt;
    FAllocMemCalls: SizeUInt;
    FReallocMemCalls: SizeUInt;
    FFreeMemCalls: SizeUInt;
  public
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
    function Traits: TAllocatorTraits;

    property GetMemCalls: SizeUInt read FGetMemCalls;
    property AllocMemCalls: SizeUInt read FAllocMemCalls;
    property ReallocMemCalls: SizeUInt read FReallocMemCalls;
    property FreeMemCalls: SizeUInt read FFreeMemCalls;
  end;

var
  T: TTestSuite;

{ TMockAllocator }

function TMockAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  Inc(FGetMemCalls);
  Result := System.GetMem(ASize);
end;

function TMockAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  Inc(FAllocMemCalls);
  Result := System.AllocMem(ASize);
end;

function TMockAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then Exit(GetMem(ASize));
  Inc(FReallocMemCalls);
  Result := System.ReallocMem(APtr, ASize);
end;

procedure TMockAllocator.FreeMem(APtr: Pointer);
begin
  if APtr = nil then Exit;
  Inc(FFreeMemCalls);
  System.FreeMem(APtr);
end;

function TMockAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

{ Tests }

procedure TestGetMemZeroSize;
var
  LAlloc: TMockAllocator;
  LPtr: Pointer;
begin
  LAlloc := TMockAllocator.Create;
  try
    LPtr := LAlloc.GetMem(0);
    Check(LPtr = nil, 'GetMem(0) should return nil');
    Check(LAlloc.GetMemCalls = 0, 'GetMem should not be called for size 0');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroSize;
var
  LAlloc: TMockAllocator;
  LPtr: Pointer;
begin
  LAlloc := TMockAllocator.Create;
  try
    LPtr := LAlloc.AllocMem(0);
    Check(LPtr = nil, 'AllocMem(0) should return nil');
    Check(LAlloc.AllocMemCalls = 0, 'AllocMem should not be called for size 0');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocMemNilBecomesGetMem;
var
  LAlloc: TMockAllocator;
  LPtr: Pointer;
begin
  LAlloc := TMockAllocator.Create;
  try
    LPtr := LAlloc.ReallocMem(nil, 256);
    Check(LPtr <> nil, 'ReallocMem(nil, 256) should succeed');
    Check(LAlloc.GetMemCalls = 1, 'ReallocMem(nil) should call GetMem');
    Check(LAlloc.ReallocMemCalls = 0, 'ReallocMem(nil) should NOT increment ReallocMemCalls');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocMemZeroSizeFrees;
var
  LAlloc: TMockAllocator;
  LPtr: Pointer;
begin
  LAlloc := TMockAllocator.Create;
  try
    LPtr := LAlloc.GetMem(128);
    Check(LPtr <> nil, 'GetMem should succeed');
    LPtr := LAlloc.ReallocMem(LPtr, 0);
    Check(LPtr = nil, 'ReallocMem(ptr, 0) should return nil');
    Check(LAlloc.FreeMemCalls = 1, 'ReallocMem(ptr, 0) should free the pointer');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeMemNilIsNoOp;
var
  LAlloc: TMockAllocator;
begin
  LAlloc := TMockAllocator.Create;
  try
    LAlloc.FreeMem(nil);
    Check(LAlloc.FreeMemCalls = 0, 'FreeMem(nil) should not increment FreeMemCalls');
  finally
    LAlloc.Free;
  end;
end;

procedure TestDefaultTraits;
var
  LAlloc: TMockAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TMockAllocator.Create;
  try
    LTraits := LAlloc.Traits;
    Check(not LTraits.ZeroInitialized, 'Default ZeroInitialized should be False');
    Check(not LTraits.ThreadSafe, 'Default ThreadSafe should be False');
    Check(LTraits.SupportsRealloc, 'Default SupportsRealloc should be True');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetMemAllocates;
var
  LAlloc: TMockAllocator;
  LPtr: Pointer;
begin
  LAlloc := TMockAllocator.Create;
  try
    LPtr := LAlloc.GetMem(512);
    Check(LPtr <> nil, 'GetMem(512) should succeed');
    Check(LAlloc.GetMemCalls = 1, 'GetMemCalls should be 1');
    LAlloc.FreeMem(LPtr);
    Check(LAlloc.FreeMemCalls = 1, 'FreeMemCalls should be 1');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_allocator_base');
  T.Test('GetMemZeroSize', @TestGetMemZeroSize);
  T.Test('AllocMemZeroSize', @TestAllocMemZeroSize);
  T.Test('ReallocMemNilBecomesGetMem', @TestReallocMemNilBecomesGetMem);
  T.Test('ReallocMemZeroSizeFrees', @TestReallocMemZeroSizeFrees);
  T.Test('FreeMemNilIsNoOp', @TestFreeMemNilIsNoOp);
  T.Test('DefaultTraits', @TestDefaultTraits);
  T.Test('GetMemAllocates', @TestGetMemAllocates);
  T.Run;
  T.Summary;
end.
