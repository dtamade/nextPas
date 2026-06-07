program test_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.testing;

type
  PObjectRef = ^TObject;
  PIntegerRef = ^Integer;
  PBooleanRef = ^Boolean;

  TIntNullable = specialize TNullable<Integer>;
  TIntOption = specialize TOption<Integer>;
  TIntResult = specialize TResult<Integer, string>;

  IBaseUtilsProbe = interface
    ['{64EA3D42-C730-4895-A82E-03EA1E0ED457}']
    function Value: Integer;
  end;

  IBaseUtilsOtherProbe = interface
    ['{68450AD5-4018-4D0E-B909-BDA617EA7B19}']
  end;

  TBaseUtilsProbe = class(TInterfacedObject, IBaseUtilsProbe)
  public
    function Value: Integer;
  end;

  TBaseUtilsOtherProbe = class(TInterfacedObject, IBaseUtilsOtherProbe)
  end;

  TDestructorProbe = class
  private
    FTarget: PObjectRef;
    FDestroyCount: PIntegerRef;
    FReferenceWasNil: PBooleanRef;
  public
    constructor Create(ATarget: PObjectRef; ADestroyCount: PIntegerRef; AReferenceWasNil: PBooleanRef);
    destructor Destroy; override;
  end;

var
  T: TTestRunner;

function TBaseUtilsProbe.Value: Integer;
begin
  Result := 42;
end;

constructor TDestructorProbe.Create(ATarget: PObjectRef; ADestroyCount: PIntegerRef; AReferenceWasNil: PBooleanRef);
begin
  inherited Create;
  FTarget := ATarget;
  FDestroyCount := ADestroyCount;
  FReferenceWasNil := AReferenceWasNil;
end;

destructor TDestructorProbe.Destroy;
begin
  Inc(FDestroyCount^);
  FReferenceWasNil^ := FTarget^ = nil;
  inherited Destroy;
end;

procedure ExpectInvalidArgumentNil(const AProc: TProc; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EArgumentNil do
      ;
  end;
end;

procedure ExpectInvalidState(const AProc: TProc; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EInvalidState do
      ;
  end;
end;

procedure ExpectInvariantViolation(const AProc: TProc; const AMessage: string);
var
  LCaughtInvariant: Boolean;
  LCaughtCompat: Boolean;
begin
  LCaughtInvariant := False;
  LCaughtCompat := False;
  try
    AProc();
    Fail(AMessage);
  except
    on E: EInvariantViolation do
    begin
      LCaughtInvariant := True;
      LCaughtCompat := E is EWow;
    end;
  end;
  Check(LCaughtInvariant, 'should catch EInvariantViolation');
  Check(LCaughtCompat, 'EInvariantViolation should remain catch-compatible as EWow');
end;

procedure TestFrameworkIdentity;
begin
  CheckEqual('0.1.0', NEXTPAS_CORE_VERSION, 'version string');
  CheckEqual(Int64(0), NEXTPAS_CORE_VERSION_MAJOR, 'version major');
  CheckEqual(Int64(1), NEXTPAS_CORE_VERSION_MINOR, 'version minor');
  CheckEqual(Int64(0), NEXTPAS_CORE_VERSION_PATCH, 'version patch');
  CheckEqual('nextpas.core', NEXTPAS_CORE_NAME, 'framework name');
end;

procedure TestInvariantCompatibilityAlias;
begin
  Check(EWow = EInvariantViolation, 'EWow should be a compatibility alias of EInvariantViolation');
  ExpectInvariantViolation(
    procedure
    begin
      raise EInvariantViolation.Create('invariant violated');
    end,
    'raising EInvariantViolation should be catchable'
  );
end;

procedure TestContractHelpersUseFrameworkExceptions;
begin
  ExpectInvariantViolation(
    procedure
    begin
      Ensure(False, 'postcondition violated');
    end,
    'Ensure(False) should raise EInvariantViolation'
  );

  ExpectInvalidState(
    procedure
    begin
      CheckState(False, 'state violated');
    end,
    'CheckState(False) should raise EInvalidState'
  );

  ExpectInvariantViolation(
    procedure
    begin
      Unreachable('should not happen');
    end,
    'Unreachable should raise EInvariantViolation'
  );
end;

procedure TestZeroMemHandlesZeroSizeAndNil;
var
  LValue: UInt32;
begin
  ZeroMem(nil, 0);

  LValue := $DEADBEEF;
  ZeroMem(@LValue, 0);
  CheckEqual(Int64($DEADBEEF), Int64(LValue), 'ZeroMem with size 0 should not mutate');

  ZeroMem(@LValue, SizeOf(LValue));
  CheckEqual(Int64(0), Int64(LValue), 'ZeroMem should clear bytes');

  ExpectInvalidArgumentNil(
    procedure
    begin
      ZeroMem(nil, 1);
    end,
    'ZeroMem(nil, >0) should raise EArgumentNil'
  );
end;

procedure TestFillMemHandlesValueZeroSizeAndNil;
var
  LBytes: array[0..3] of Byte;
begin
  LBytes[0] := 1;
  LBytes[1] := 2;
  LBytes[2] := 3;
  LBytes[3] := 4;

  FillMem(nil, 0, $AA);
  FillMem(@LBytes[0], 0, $AA);
  CheckEqual(Int64(1), Int64(LBytes[0]), 'FillMem with size 0 should not mutate');

  FillMem(@LBytes[0], SizeOf(LBytes), $AA);
  CheckEqual(Int64($AA), Int64(LBytes[0]), 'FillMem should fill first byte');
  CheckEqual(Int64($AA), Int64(LBytes[3]), 'FillMem should fill last byte');

  FillMem(@LBytes[1], 2, $11);
  CheckEqual(Int64($AA), Int64(LBytes[0]), 'FillMem range should preserve byte before range');
  CheckEqual(Int64($11), Int64(LBytes[1]), 'FillMem range should fill first ranged byte');
  CheckEqual(Int64($11), Int64(LBytes[2]), 'FillMem range should fill last ranged byte');
  CheckEqual(Int64($AA), Int64(LBytes[3]), 'FillMem range should preserve byte after range');

  ExpectInvalidArgumentNil(
    procedure
    begin
      FillMem(nil, 1, $AA);
    end,
    'FillMem(nil, >0) should raise EArgumentNil'
  );
end;

procedure TestCopyMemHandlesZeroSizeAndNil;
var
  LSrc: array[0..3] of Byte;
  LDst: array[0..3] of Byte;
begin
  LSrc[0] := 1;
  LSrc[1] := 2;
  LSrc[2] := 3;
  LSrc[3] := 4;
  LDst[0] := 9;
  LDst[1] := 9;
  LDst[2] := 9;
  LDst[3] := 9;

  CopyMem(nil, nil, 0);
  CopyMem(@LDst[0], @LSrc[0], 0);
  CheckEqual(Int64(9), Int64(LDst[0]), 'CopyMem with size 0 should not mutate');

  CopyMem(@LDst[0], @LSrc[0], Length(LSrc));
  CheckEqual(Int64(1), Int64(LDst[0]), 'CopyMem should copy first byte');
  CheckEqual(Int64(4), Int64(LDst[3]), 'CopyMem should copy last byte');

  ExpectInvalidArgumentNil(
    procedure
    begin
      CopyMem(nil, @LSrc[0], 1);
    end,
    'CopyMem(nil, src, >0) should raise EArgumentNil'
  );

  ExpectInvalidArgumentNil(
    procedure
    begin
      CopyMem(@LDst[0], nil, 1);
    end,
    'CopyMem(dst, nil, >0) should raise EArgumentNil'
  );
end;

procedure TestCompareMemSemanticsStayStable;
var
  LA: array[0..1] of Byte;
  LB: array[0..1] of Byte;
begin
  LA[0] := 1;
  LA[1] := 2;
  LB[0] := 1;
  LB[1] := 2;

  Check(CompareMem(nil, nil, 0), 'CompareMem(nil, nil, 0) should stay true');
  Check(CompareMem(nil, nil, 1), 'CompareMem(nil, nil, >0) should stay true');
  Check(not CompareMem(nil, @LA[0], 1), 'CompareMem(nil, buffer, >0) should stay false');
  Check(not CompareMem(@LA[0], nil, 1), 'CompareMem(buffer, nil, >0) should stay false');
  Check(CompareMem(@LA[0], @LB[0], 2), 'CompareMem should stay true for equal buffers');
  LB[1] := 3;
  Check(not CompareMem(@LA[0], @LB[0], 2), 'CompareMem should stay false for different buffers');
end;

procedure TestObjectLifecycleHelpersStayStable;
var
  LObject: TObject;
  LDestroyCount: Integer;
  LReferenceWasNil: Boolean;
begin
  LDestroyCount := 0;
  LReferenceWasNil := False;
  LObject := TDestructorProbe.Create(@LObject, @LDestroyCount, @LReferenceWasNil);
  FreeAndNil(LObject);
  Check(LObject = nil, 'base FreeAndNil should nil the object reference');
  CheckEqual(Int64(1), Int64(LDestroyCount), 'base FreeAndNil should destroy the object once');
  Check(LReferenceWasNil, 'base FreeAndNil should nil before destructor execution');

  LObject := TObject.Create;
  SafeFree(LObject);
  Check(LObject = nil, 'base SafeFree should nil the object reference');

  LObject := nil;
  FreeAndNil(LObject);
  Check(LObject = nil, 'base FreeAndNil should accept nil references');
  SafeFree(LObject);
  Check(LObject = nil, 'base SafeFree should accept nil references');
end;

procedure TestSupportsHelpersStayStable;
var
  LObject: TBaseUtilsProbe;
  LOwner: IInterface;
  LProbe: IBaseUtilsProbe;
  LOther: IBaseUtilsOtherProbe;
  LInterface: IInterface;
begin
  LObject := TBaseUtilsProbe.Create;
  LOwner := LObject as IInterface;
  try
    Check(LOwner <> nil, 'probe owner should hold the object alive during base Supports query');
    Check(Supports(LObject, IBaseUtilsProbe, LProbe),
      'base Supports(TObject) should query supported interfaces');
    CheckEqual(Int64(42), Int64(LProbe.Value),
      'base Supports(TObject) should return the queried interface');

    LOther := TBaseUtilsOtherProbe.Create as IBaseUtilsOtherProbe;
    Check(not Supports(LObject, IBaseUtilsOtherProbe, LOther),
      'base Supports(TObject) should return false for unsupported interfaces');
    Check(LOther = nil,
      'base Supports(TObject) should clear stale interfaces on unsupported queries');
  finally
    LProbe := nil;
    LOther := nil;
    LOwner := nil;
  end;

  LInterface := TBaseUtilsProbe.Create as IInterface;
  Check(Supports(LInterface, IBaseUtilsProbe, LProbe),
    'base Supports(IInterface) should query supported interfaces');
  CheckEqual(Int64(42), Int64(LProbe.Value),
    'base Supports(IInterface) should return the queried interface');

  LOther := TBaseUtilsOtherProbe.Create as IBaseUtilsOtherProbe;
  Check(not Supports(LInterface, IBaseUtilsOtherProbe, LOther),
    'base Supports(IInterface) should return false for unsupported interfaces');
  Check(LOther = nil,
    'base Supports(IInterface) should clear stale interfaces on unsupported queries');

  LProbe := nil;
  LOther := nil;
  LInterface := nil;
  Check(not Supports(TObject(nil), IBaseUtilsProbe, LProbe),
    'base Supports(TObject) should return false for nil object references');
  Check(not Supports(IInterface(nil), IBaseUtilsProbe, LProbe),
    'base Supports(IInterface) should return false for nil interface references');
end;

procedure TestNullableSurface;
var
  LSome: TIntNullable;
  LNone: TIntNullable;
begin
  LSome := TIntNullable.Some(42);
  Check(LSome.HasValue, 'Some should report HasValue');
  Check(not LSome.IsNone, 'Some should not report none');
  CheckEqual(Int64(42), Int64(LSome.Value), 'Some should unwrap value');
  CheckEqual(Int64(42), Int64(LSome.ValueOr(7)), 'ValueOr should preserve present value');

  LNone := TIntNullable.None;
  Check(not LNone.HasValue, 'None should not have value');
  Check(LNone.IsNone, 'None should report none');
  CheckEqual(Int64(7), Int64(LNone.ValueOr(7)), 'ValueOr should return fallback for none');

  ExpectInvalidState(
    procedure
    begin
      LNone.Value;
    end,
    'Nullable.Value on none should raise EInvalidState'
  );
end;

procedure TestOptionSurface;
var
  LSome: TIntOption;
  LNone: TIntOption;
begin
  LSome := TIntOption.Some(11);
  Check(LSome.IsSome, 'Option.Some should report some');
  Check(not LSome.IsNone, 'Option.Some should not report none');
  CheckEqual(Int64(11), Int64(LSome.Unwrap), 'Option.Some should unwrap value');
  CheckEqual(Int64(11), Int64(LSome.UnwrapOr(3)), 'UnwrapOr should preserve some');

  LNone := TIntOption.None;
  Check(not LNone.IsSome, 'Option.None should not report some');
  Check(LNone.IsNone, 'Option.None should report none');
  CheckEqual(Int64(3), Int64(LNone.UnwrapOr(3)), 'UnwrapOr should use fallback');

  ExpectInvalidState(
    procedure
    begin
      LNone.Unwrap;
    end,
    'Option.None Unwrap should raise EInvalidState'
  );
end;

procedure TestResultSurface;
var
  LOk: TIntResult;
  LErr: TIntResult;
begin
  LOk := TIntResult.Ok(5);
  Check(LOk.IsOk, 'Result.Ok should report ok');
  Check(not LOk.IsErr, 'Result.Ok should not report err');
  CheckEqual(Int64(5), Int64(LOk.Unwrap), 'Result.Ok should unwrap value');
  CheckEqual(Int64(5), Int64(LOk.UnwrapOr(9)), 'Result.Ok should preserve value');

  LErr := TIntResult.Err('boom');
  Check(not LErr.IsOk, 'Result.Err should not report ok');
  Check(LErr.IsErr, 'Result.Err should report err');
  CheckEqual('boom', LErr.UnwrapErr, 'Result.Err should unwrap error');
  CheckEqual(Int64(9), Int64(LErr.UnwrapOr(9)), 'Result.Err should use fallback');

  ExpectInvalidState(
    procedure
    begin
      LErr.Unwrap;
    end,
    'Result.Err Unwrap should raise EInvalidState'
  );
end;

begin
  T := TTestRunner.Create('nextpas.core.base');
  T.Run('framework identity', @TestFrameworkIdentity);
  T.Run('invariant compatibility alias', @TestInvariantCompatibilityAlias);
  T.Run('contract helpers use framework exceptions', @TestContractHelpersUseFrameworkExceptions);
  T.Run('zeromem handles zero-size and nil', @TestZeroMemHandlesZeroSizeAndNil);
  T.Run('fillmem handles value zero-size and nil', @TestFillMemHandlesValueZeroSizeAndNil);
  T.Run('copymem handles zero-size and nil', @TestCopyMemHandlesZeroSizeAndNil);
  T.Run('comparemem semantics stay stable', @TestCompareMemSemanticsStayStable);
  T.Run('object lifecycle helpers stay stable', @TestObjectLifecycleHelpersStayStable);
  T.Run('supports helpers stay stable', @TestSupportsHelpersStayStable);
  T.Run('nullable surface', @TestNullableSurface);
  T.Run('option surface', @TestOptionSurface);
  T.Run('result surface', @TestResultSurface);
  T.Summary;
end.
