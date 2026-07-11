program test_allocator_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ Test allocator using TAllocatorBase }

type
  TSimpleAllocator = class(TAllocatorBase)
  private
    FAllocCount: Integer;
    FFreeCount: Integer;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    property AllocCount: Integer read FAllocCount;
    property FreeCount: Integer read FFreeCount;
  end;

function TSimpleAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := System.GetMem(ASize);
  if Result <> nil then
    Inc(FAllocCount);
end;

procedure TSimpleAllocator.DoFreeMem(APtr: Pointer);
begin
  System.FreeMem(APtr);
  Inc(FFreeCount);
end;

{ Test procedures }

procedure TestGetMemZero;
var
  LAlloc: TSimpleAllocator;
begin
  LAlloc := TSimpleAllocator.Create;
  try
    Check(LAlloc.GetMem(0) = nil, 'GetMem(0) should return nil');
    Check(LAlloc.AllocCount = 0, 'should not call DoGetMem');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZero;
var
  LAlloc: TSimpleAllocator;
begin
  LAlloc := TSimpleAllocator.Create;
  try
    Check(LAlloc.AllocMem(0) = nil, 'AllocMem(0) should return nil');
    Check(LAlloc.AllocCount = 0, 'should not call DoAllocMem');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeMemNil;
var
  LAlloc: TSimpleAllocator;
begin
  LAlloc := TSimpleAllocator.Create;
  try
    LAlloc.FreeMem(nil);
    Check(LAlloc.FreeCount = 0, 'FreeMem(nil) should not call DoFreeMem');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocMemNil;
var
  LAlloc: TSimpleAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSimpleAllocator.Create;
  try
    LPtr := LAlloc.ReallocMem(nil, 64);
    Check(LPtr <> nil, 'ReallocMem(nil, 64) should allocate');
    Check(LAlloc.AllocCount = 1, 'should call DoGetMem');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocMemToZero;
var
  LAlloc: TSimpleAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSimpleAllocator.Create;
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'GetMem should succeed');
    Check(LAlloc.AllocCount = 1, 'should call DoGetMem');

    LAlloc.ReallocMem(LPtr, 0);
    Check(LAlloc.FreeCount = 1, 'should call DoFreeMem');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TSimpleAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TSimpleAllocator.Create;
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ZeroInitialized = False, 'should not be zero initialized');
    Check(LTraits.ThreadSafe = False, 'should not be thread safe');
    Check(LTraits.SupportsRealloc = True, 'should support realloc');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetMemNonZero;
var
  LAlloc: TSimpleAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSimpleAllocator.Create;
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'GetMem(64) should succeed');
    Check(LAlloc.AllocCount = 1, 'should call DoGetMem');
    LAlloc.FreeMem(LPtr);
    Check(LAlloc.FreeCount = 1, 'should call DoFreeMem');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemNonZero;
var
  LAlloc: TSimpleAllocator;
  LPtr: PByte;
  LI: Integer;
begin
  LAlloc := TSimpleAllocator.Create;
  try
    LPtr := PByte(LAlloc.AllocMem(64));
    Check(LPtr <> nil, 'AllocMem(64) should succeed');
    Check(LAlloc.AllocCount = 1, 'should call DoGetMem');
    for LI := 0 to 63 do
      Check(LPtr[LI] = 0, 'byte ' + IntToStr(LI) + ' should be zero');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_allocator_base');
  T.Test('GetMemZero', @TestGetMemZero);
  T.Test('AllocMemZero', @TestAllocMemZero);
  T.Test('FreeMemNil', @TestFreeMemNil);
  T.Test('ReallocMemNil', @TestReallocMemNil);
  T.Test('ReallocMemToZero', @TestReallocMemToZero);
  T.Test('Traits', @TestTraits);
  T.Test('GetMemNonZero', @TestGetMemNonZero);
  T.Test('AllocMemNonZero', @TestAllocMemNonZero);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
