program test_allocator_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base;

type
  { Mock allocator for testing TAllocator base class }
  TMockAllocator = class(TAllocator)
  private
    FGetMemCalls: SizeUInt;
    FAllocMemCalls: SizeUInt;
    FReallocMemCalls: SizeUInt;
    FFreeMemCalls: SizeUInt;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    property GetMemCalls: SizeUInt read FGetMemCalls;
    property AllocMemCalls: SizeUInt read FAllocMemCalls;
    property ReallocMemCalls: SizeUInt read FReallocMemCalls;
    property FreeMemCalls: SizeUInt read FFreeMemCalls;
  end;

var
  T: TTestSuite;

{ TMockAllocator }

function TMockAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Inc(FGetMemCalls);
  Result := System.GetMem(ASize);
end;

function TMockAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Inc(FAllocMemCalls);
  Result := System.AllocMem(ASize);
end;

function TMockAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  Inc(FReallocMemCalls);
  Result := System.ReallocMem(APtr, ASize);
end;

procedure TMockAllocator.DoFreeMem(APtr: Pointer);
begin
  Inc(FFreeMemCalls);
  System.FreeMem(APtr);
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
    Check(LAlloc.GetMemCalls = 0, 'DoGetMem should not be called for size 0');
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
    Check(LAlloc.AllocMemCalls = 0, 'DoAllocMem should not be called for size 0');
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
    Check(LAlloc.ReallocMemCalls = 0, 'ReallocMem(nil) should NOT call DoReallocMem');
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
    Check(LAlloc.FreeMemCalls = 0, 'FreeMem(nil) should not call DoFreeMem');
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

procedure TestGetMemCallsDoGetMem;
var
  LAlloc: TMockAllocator;
  LPtr: Pointer;
begin
  LAlloc := TMockAllocator.Create;
  try
    LPtr := LAlloc.GetMem(512);
    Check(LPtr <> nil, 'GetMem(512) should succeed');
    Check(LAlloc.GetMemCalls = 1, 'DoGetMem should be called once');
    LAlloc.FreeMem(LPtr);
    Check(LAlloc.FreeMemCalls = 1, 'DoFreeMem should be called once');
  finally
    LAlloc.Free;
  end;
end;

{$IFDEF DEBUG}
procedure TestDoubleFreeDetection;
var
  LAlloc: TMockAllocator;
  LPtr: Pointer;
  LCaught: Boolean;
begin
  LAlloc := TMockAllocator.Create;
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'GetMem should succeed');
    LAlloc.FreeMem(LPtr);
    LCaught := False;
    try
      LAlloc.FreeMem(LPtr);  // double free!
    except
      on E: EAllocError do
      begin
        LCaught := True;
        Check(E.Error = aeDoubleFree, 'Error code should be aeDoubleFree');
      end;
    end;
    Check(LCaught, 'Double free should raise EAllocError');
  finally
    LAlloc.Free;
  end;
end;
{$ENDIF}

begin
  T := TTestSuite.Create('test_allocator_base');
  T.Test('GetMemZeroSize', @TestGetMemZeroSize);
  T.Test('AllocMemZeroSize', @TestAllocMemZeroSize);
  T.Test('ReallocMemNilBecomesGetMem', @TestReallocMemNilBecomesGetMem);
  T.Test('ReallocMemZeroSizeFrees', @TestReallocMemZeroSizeFrees);
  T.Test('FreeMemNilIsNoOp', @TestFreeMemNilIsNoOp);
  T.Test('DefaultTraits', @TestDefaultTraits);
  T.Test('GetMemCallsDoGetMem', @TestGetMemCallsDoGetMem);
  {$IFDEF DEBUG}
  T.Test('DoubleFreeDetection', @TestDoubleFreeDetection);
  {$ENDIF}
  T.Run;
  T.Summary;
end.
