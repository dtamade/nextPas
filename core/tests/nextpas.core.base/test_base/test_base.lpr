program test_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.exception,
  nextpas.core.test;

type
  PObjectRef = ^TObject;
  PIntegerRef = ^Integer;
  PBooleanRef = ^Boolean;
  PObjectSlot = ^TObject;

  IBaseTrackedPayload = interface
    ['{B3A5F8E1-2D4C-4A6B-9E7F-1C8D3A5B7E92}']
    function Id: Integer;
  end;

  TBaseTrackedPayload = class(TInterfacedObject, IBaseTrackedPayload)
  private
    FId: Integer;
  public
    constructor Create(AId: Integer);
    destructor Destroy; override;
    function Id: Integer;
  end;

  TBaseLifecycleProbe = class
  private
    FSlot: PObjectSlot;
  public
    constructor Create(ASlot: PObjectSlot);
    destructor Destroy; override;
  end;

  TIntNullable = specialize TNullable<Integer>;
  TIntOption = specialize TOption<Integer>;
  TIntResult = specialize TResult<Integer, string>;
  TTrackedNullable = specialize TNullable<IBaseTrackedPayload>;
  TTrackedOption = specialize TOption<IBaseTrackedPayload>;
  TTrackedResult = specialize TResult<IBaseTrackedPayload, IBaseTrackedPayload>;

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
  GTrackedPayloadAlive: Integer = 0;
  GLifecycleProbeDestroyed: Integer = 0;
  GLifecycleProbeSawNilBeforeDestroy: Boolean = False;

constructor TBaseTrackedPayload.Create(AId: Integer);
begin
  inherited Create;
  FId := AId;
  Inc(GTrackedPayloadAlive);
end;

destructor TBaseTrackedPayload.Destroy;
begin
  Dec(GTrackedPayloadAlive);
  inherited Destroy;
end;

function TBaseTrackedPayload.Id: Integer;
begin
  Result := FId;
end;

constructor TBaseLifecycleProbe.Create(ASlot: PObjectSlot);
begin
  inherited Create;
  FSlot := ASlot;
end;

destructor TBaseLifecycleProbe.Destroy;
begin
  Inc(GLifecycleProbeDestroyed);
  GLifecycleProbeSawNilBeforeDestroy := (FSlot <> nil) and (FSlot^ = nil);
  inherited Destroy;
end;

function NewTrackedPayload(AId: Integer): IBaseTrackedPayload;
begin
  Result := TBaseTrackedPayload.Create(AId);
end;

procedure CheckTrackedPayloadAlive(AExpected: Integer; const AMessage: string);
begin
  CheckEqual(Int64(AExpected), Int64(GTrackedPayloadAlive));
end;

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

procedure ExpectInvalidArgumentNil(const AProc: TTestClosure; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EArgumentNil do
      ;
  end;
end;

procedure ExpectInvalidState(const AProc: TTestClosure; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EInvalidState do
      ;
  end;
end;

procedure ExpectOutOfRange(const AProc: TTestClosure; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EOutOfRange do
      ;
  end;
end;

procedure ExpectOverflow(const AProc: TTestClosure; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EOverflow do
      ;
  end;
end;

procedure ExpectOutOfRangeMessage(const AProc: TTestClosure;
  const AExpectedMessage: string; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EOutOfRange do
      CheckEqual(AExpectedMessage, E.Message);
  end;
end;

procedure ExpectInvariantViolation(const AProc: TTestClosure; const AMessage: string);
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
  CheckEqual('0.1.0', NEXTPAS_CORE_VERSION);
  CheckEqual(Int64(0), NEXTPAS_CORE_VERSION_MAJOR);
  CheckEqual(Int64(1), NEXTPAS_CORE_VERSION_MINOR);
  CheckEqual(Int64(0), NEXTPAS_CORE_VERSION_PATCH);
  CheckEqual('nextpas.core', NEXTPAS_CORE_NAME);
end;

procedure TestInvariantCompatibilityAlias;
var
  LErr: ENextPasError;
begin
  Check(EWow = EInvariantViolation, 'EWow should be a compatibility alias of EInvariantViolation');
  LErr := EInvariantViolation.Create('invariant violated');
  try
    CheckEqual(Ord(ecInternal), Ord(LErr.Category));
  finally
    LErr.Free;
  end;
  ExpectInvariantViolation(
    procedure
    begin
      raise EInvariantViolation.Create('invariant violated');
    end,
    'raising EInvariantViolation should be catchable'
  );
end;

procedure TestBaseResultExceptionsUseInternalCategory;
var
  LErr: ENextPasError;
begin
  LErr := EInvalidResult.Create('invalid result');
  try
    CheckEqual(Ord(ecInternal), Ord(LErr.Category));
  finally
    LErr.Free;
  end;

  LErr := EInvalidResult.CreateFmt('invalid result %d', [5]);
  try
    CheckEqual('invalid result 5', LErr.Message);
    CheckEqual(Ord(ecInternal), Ord(LErr.Category));
  finally
    LErr.Free;
  end;
end;

procedure ExpectInternalInvariantViolation(const AProc: TTestClosure; const AMessage: string);
var
  LCaughtInvariant: Boolean;
begin
  LCaughtInvariant := False;
  try
    AProc();
    Fail(AMessage);
  except
    on E: EInvariantViolation do
    begin
      LCaughtInvariant := True;
      CheckEqual(Ord(ecInternal), Ord(E.Category));
    end;
  end;
  Check(LCaughtInvariant, AMessage + ': should catch EInvariantViolation');
end;

procedure TestBaseValidationExceptionsUseInvalidArgumentCategory;
var
  LErr: ENextPasError;
begin
  LErr := EArgumentNil.Create('argument is nil');
  try
    CheckEqual(Ord(ecInvalidArgument), Ord(LErr.Category));
  finally
    LErr.Free;
  end;

  LErr := EOutOfRange.CreateFmt('index %d', [7]);
  try
    CheckEqual('index 7', LErr.Message);
    CheckEqual(Ord(ecInvalidArgument), Ord(LErr.Category));
  finally
    LErr.Free;
  end;

  LErr := EInvalidArgument.CreateFmt('bad %d', [8]);
  try
    CheckEqual('bad 8', LErr.Message);
    CheckEqual(Ord(ecInvalidArgument), Ord(LErr.Category));
  finally
    LErr.Free;
  end;
end;

procedure TestBaseOperationExceptionsUseSpecificCategories;
var
  LErr: ENextPasError;
begin
  LErr := EEmptyCollection.Create('collection is empty');
  try
    CheckEqual(Ord(ecInvalidOperation), Ord(LErr.Category));
  finally
    LErr.Free;
  end;

  LErr := EInvalidState.Create('invalid state');
  try
    CheckEqual(Ord(ecInvalidOperation), Ord(LErr.Category));
  finally
    LErr.Free;
  end;

  LErr := EInvalidOperation.CreateFmt('bad op %d', [9]);
  try
    CheckEqual('bad op 9', LErr.Message);
    CheckEqual(Ord(ecInvalidOperation), Ord(LErr.Category));
  finally
    LErr.Free;
  end;

  LErr := ENotSupported.Create('unsupported operation');
  try
    CheckEqual(Ord(ecNotSupported), Ord(LErr.Category));
  finally
    LErr.Free;
  end;

  LErr := ENotCompatible.Create('collection is not compatible');
  try
    CheckEqual(Ord(ecInvalidArgument), Ord(LErr.Category));
  finally
    LErr.Free;
  end;
end;

procedure TestBaseOutOfMemoryLongNameIsCanonical;
var
  LErr: nextpas.core.base.EOutOfMemoryError;
  LCaught: Boolean;
begin
  LErr := nextpas.core.base.EOutOfMemoryError.Create('allocation failed');
  try
    Check(LErr is nextpas.core.exception.EOutOfMemoryError,
      'base EOutOfMemoryError should be the canonical public OOM root');
    Check(LErr.Category = ecResourceExhausted,
      'base EOutOfMemoryError should keep resource-exhausted category');
  finally
    LErr.Free;
  end;

  LCaught := False;
  try
    raise nextpas.core.base.EOutOfMemory.Create('compat allocation failed');
  except
    on E: nextpas.core.base.EOutOfMemoryError do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;
  Check(LCaught, 'base EOutOfMemory compatibility name should catch as EOutOfMemoryError');
end;

procedure TestContractHelpersUseFrameworkExceptions;
begin
  ExpectInternalInvariantViolation(
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

  ExpectInternalInvariantViolation(
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
  CheckEqual(Int64($DEADBEEF), Int64(LValue));

  ZeroMem(@LValue, SizeOf(LValue));
  CheckEqual(Int64(0), Int64(LValue));

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
  CheckEqual(Int64(1), Int64(LBytes[0]));

  FillMem(@LBytes[0], SizeOf(LBytes), $AA);
  CheckEqual(Int64($AA), Int64(LBytes[0]));
  CheckEqual(Int64($AA), Int64(LBytes[3]));

  FillMem(@LBytes[1], 2, $11);
  CheckEqual(Int64($AA), Int64(LBytes[0]));
  CheckEqual(Int64($11), Int64(LBytes[1]));
  CheckEqual(Int64($11), Int64(LBytes[2]));
  CheckEqual(Int64($AA), Int64(LBytes[3]));

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
  CheckEqual(Int64(9), Int64(LDst[0]));

  CopyMem(@LDst[0], @LSrc[0], Length(LSrc));
  CheckEqual(Int64(1), Int64(LDst[0]));
  CheckEqual(Int64(4), Int64(LDst[3]));

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
  { CompareMem(nil, nil, >0) behavior is platform-dependent — skip assertion }
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
  CheckEqual(Int64(1), Int64(LDestroyCount));
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
    Check(LOwner <> nil, 'probe owner should hold the object alive');
    Check(Supports(LObject, IBaseUtilsProbe, LProbe),
      'base Supports(TObject) should query supported interfaces');
    CheckEqual(Int64(42), Int64(LProbe.Value));

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
  CheckEqual(Int64(42), Int64(LProbe.Value));

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
  CheckEqual(Int64(42), Int64(LSome.Value));
  CheckEqual(Int64(42), Int64(LSome.ValueOr(7)));

  LNone := TIntNullable.None;
  Check(not LNone.HasValue, 'None should not have value');
  Check(LNone.IsNone, 'None should report none');
  CheckEqual(Int64(7), Int64(LNone.ValueOr(7)));

  ExpectInvalidState(
    procedure
    begin
      LNone.Value;
    end,
    'Nullable.Value on none should raise EInvalidState'
  );
end;

procedure TestNullableInterfacePayloadLifecycle;

  procedure Exercise;
  var
    LNullable: TTrackedNullable;
    LUnwrapped: IBaseTrackedPayload;
  begin
    LNullable := TTrackedNullable.Some(NewTrackedPayload(101));
    CheckTrackedPayloadAlive(1, 'Nullable.Some should retain interface payload');
    CheckEqual(Int64(101), Int64(LNullable.Value.Id));

    LNullable := TTrackedNullable.Some(NewTrackedPayload(102));
    CheckTrackedPayloadAlive(1, 'Nullable.Some overwrite should release previous payload');
    CheckEqual(Int64(102), Int64(LNullable.Value.Id));

    LUnwrapped := LNullable.Value;
    LNullable := TTrackedNullable.None;
    CheckTrackedPayloadAlive(1, 'Nullable.None overwrite should keep separately unwrapped interface alive');
    CheckEqual(Int64(102), Int64(LUnwrapped.Id));

    LUnwrapped := nil;
    CheckTrackedPayloadAlive(1, 'Nullable.None carrier assignment may release hidden managed temporaries');

    LNullable := TTrackedNullable.Some(NewTrackedPayload(103));
    CheckTrackedPayloadAlive(1, 'Nullable local should hold payload before scope exit');
  end;

begin
  CheckTrackedPayloadAlive(0, 'Nullable lifecycle starts without tracked payloads');
  Exercise;
  CheckTrackedPayloadAlive(0, 'Nullable local scope should release managed interface payload');
end;

procedure TestOptionSurface;
var
  LSome: TIntOption;
  LNone: TIntOption;
begin
  LSome := TIntOption.Some(11);
  Check(LSome.IsSome, 'Option.Some should report some');
  Check(not LSome.IsNone, 'Option.Some should not report none');
  CheckEqual(Int64(11), Int64(LSome.Unwrap));
  CheckEqual(Int64(11), Int64(LSome.UnwrapOr(3)));

  LNone := TIntOption.None;
  Check(not LNone.IsSome, 'Option.None should not report some');
  Check(LNone.IsNone, 'Option.None should report none');
  CheckEqual(Int64(3), Int64(LNone.UnwrapOr(3)));

  ExpectInvalidState(
    procedure
    begin
      LNone.Unwrap;
    end,
    'Option.None Unwrap should raise EInvalidState'
  );
end;

procedure TestOptionInterfacePayloadLifecycle;

  procedure Exercise;
  var
    LOption: TTrackedOption;
    LUnwrapped: IBaseTrackedPayload;
  begin
    LOption := TTrackedOption.Some(NewTrackedPayload(1));
    CheckTrackedPayloadAlive(1, 'Option.Some should retain interface payload');
    CheckEqual(Int64(1), Int64(LOption.Unwrap.Id));

    LOption := TTrackedOption.Some(NewTrackedPayload(2));
    CheckTrackedPayloadAlive(1, 'Option.Some overwrite should release previous payload');
    CheckEqual(Int64(2), Int64(LOption.Unwrap.Id));

    LUnwrapped := LOption.Unwrap;
    LOption := TTrackedOption.None;
    CheckTrackedPayloadAlive(1, 'Option.None overwrite should keep separately unwrapped interface alive');
    CheckEqual(Int64(2), Int64(LUnwrapped.Id));

    LUnwrapped := nil;
    CheckTrackedPayloadAlive(1, 'Option.None carrier assignment may release hidden managed temporaries');

    LOption := TTrackedOption.Some(NewTrackedPayload(3));
    CheckTrackedPayloadAlive(1, 'Option local should hold payload before scope exit');
  end;

begin
  CheckTrackedPayloadAlive(0, 'Option lifecycle starts without tracked payloads');
  Exercise;
  CheckTrackedPayloadAlive(0, 'Option local scope should release managed interface payload');
end;

procedure TestResultSurface;
var
  LOk: TIntResult;
  LErr: TIntResult;
begin
  LOk := TIntResult.Ok(5);
  Check(LOk.IsOk, 'Result.Ok should report ok');
  Check(not LOk.IsErr, 'Result.Ok should not report err');
  CheckEqual(Int64(5), Int64(LOk.Unwrap));
  CheckEqual(Int64(5), Int64(LOk.UnwrapOr(9)));

  LErr := TIntResult.Err('boom');
  Check(not LErr.IsOk, 'Result.Err should not report ok');
  Check(LErr.IsErr, 'Result.Err should report err');
  CheckEqual('boom', LErr.UnwrapErr);
  CheckEqual(Int64(9), Int64(LErr.UnwrapOr(9)));

  ExpectInvalidState(
    procedure
    begin
      LErr.Unwrap;
    end,
    'Result.Err Unwrap should raise EInvalidState'
  );
end;

procedure TestResultInterfacePayloadLifecycle;

  procedure Exercise;
  var
    LResult: TTrackedResult;
    LUnwrapped: IBaseTrackedPayload;
  begin
    LResult := TTrackedResult.Ok(NewTrackedPayload(10));
    CheckTrackedPayloadAlive(1, 'Result.Ok should retain interface payload');
    CheckEqual(Int64(10), Int64(LResult.Unwrap.Id));

    LResult := TTrackedResult.Err(NewTrackedPayload(20));
    CheckTrackedPayloadAlive(1, 'Result.Err overwrite should release previous ok payload');
    CheckEqual(Int64(20), Int64(LResult.UnwrapErr.Id));

    LUnwrapped := LResult.UnwrapErr;
    LResult := TTrackedResult.Ok(NewTrackedPayload(30));
    CheckTrackedPayloadAlive(2, 'Result.Ok overwrite should keep separately unwrapped error payload alive');
    CheckEqual(Int64(20), Int64(LUnwrapped.Id));
    CheckEqual(Int64(30), Int64(LResult.Unwrap.Id));

    LUnwrapped := nil;
    CheckTrackedPayloadAlive(1, 'clearing unwrapped Result error payload should release that reference');

    LResult := TTrackedResult.Err(NewTrackedPayload(40));
    CheckTrackedPayloadAlive(1, 'Result.Err overwrite should release previous ok payload');
    CheckEqual(Int64(40), Int64(LResult.UnwrapErr.Id));
  end;

begin
  CheckTrackedPayloadAlive(0, 'Result lifecycle starts without tracked payloads');
  Exercise;
  CheckTrackedPayloadAlive(0, 'Result local scope should release managed interface payloads');
end;

var
  Suite: TTestSuite;
  Runner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  Suite := TTestSuite.Create('nextpas.core.base');
  Suite.Test('framework identity', @TestFrameworkIdentity);
  Suite.Test('invariant compatibility alias', @TestInvariantCompatibilityAlias);
  Suite.Test('base result exceptions use internal category', @TestBaseResultExceptionsUseInternalCategory);
  Suite.Test('base validation exceptions use invalid-argument category', @TestBaseValidationExceptionsUseInvalidArgumentCategory);
  Suite.Test('base operation exceptions use specific categories', @TestBaseOperationExceptionsUseSpecificCategories);
  Suite.Test('base EOutOfMemoryError long name is canonical', @TestBaseOutOfMemoryLongNameIsCanonical);
  Suite.Test('contract helpers use framework exceptions', @TestContractHelpersUseFrameworkExceptions);
  Suite.Test('zeromem handles zero-size and nil', @TestZeroMemHandlesZeroSizeAndNil);
  Suite.Test('fillmem handles value zero-size and nil', @TestFillMemHandlesValueZeroSizeAndNil);
  Suite.Test('copymem handles zero-size and nil', @TestCopyMemHandlesZeroSizeAndNil);
  Suite.Test('comparemem semantics stay stable', @TestCompareMemSemanticsStayStable);
  Suite.Test('object lifecycle helpers stay stable', @TestObjectLifecycleHelpersStayStable);
  Suite.Test('supports helpers stay stable', @TestSupportsHelpersStayStable);
  Suite.Test('nullable surface', @TestNullableSurface);
  Suite.Test('nullable interface payload lifecycle', @TestNullableInterfacePayloadLifecycle);
  Suite.Test('option surface', @TestOptionSurface);
  Suite.Test('option interface payload lifecycle', @TestOptionInterfacePayloadLifecycle);
  Suite.Test('result surface', @TestResultSurface);
  Suite.Test('result interface payload lifecycle', @TestResultInterfacePayloadLifecycle);

  Runner := TTestRunner.Create('base-tests');
  Runner.Add(Suite);
  Runner.RunAllWithResult(LResults);
  Runner.Summary;

  if not Runner.AllPassed then
    Halt(1);
end.
