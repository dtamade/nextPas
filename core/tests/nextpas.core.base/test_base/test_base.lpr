program test_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.exception,
  nextpas.core.testing;

type
  IBaseSupportsProbe = interface
    ['{6F55B868-E7AE-4FCE-9A42-29D0C3C8AA01}']
    function Value: Integer;
  end;

  IBaseSupportsOther = interface
    ['{8E87160A-20F8-4F25-9EB1-5757D7D68C4B}']
  end;

  IBaseTrackedPayload = interface
    ['{0CC59069-A490-43E8-98F0-F386CB23E422}']
    function Id: Integer;
  end;

  TBaseSupportsProbe = class(TInterfacedObject, IBaseSupportsProbe)
  public
    function Value: Integer;
  end;

  TBaseSupportsOther = class(TInterfacedObject, IBaseSupportsOther)
  end;

  PObjectSlot = ^TObject;

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

var
  T: TTestRunner;
  GTrackedPayloadAlive: Integer = 0;
  GLifecycleProbeDestroyed: Integer = 0;
  GLifecycleProbeSawNilBeforeDestroy: Boolean = False;

function TBaseSupportsProbe.Value: Integer;
begin
  Result := 42;
end;

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
  CheckEqual(Int64(AExpected), Int64(GTrackedPayloadAlive), AMessage);
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

procedure ExpectOutOfRange(const AProc: TProc; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EOutOfRange do
      ;
  end;
end;

procedure ExpectOverflow(const AProc: TProc; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EOverflow do
      ;
  end;
end;

procedure ExpectOutOfRangeMessage(const AProc: TProc;
  const AExpectedMessage: string; const AMessage: string);
begin
  try
    AProc();
    Fail(AMessage);
  except
    on E: EOutOfRange do
      CheckEqual(AExpectedMessage, E.Message, AMessage);
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
var
  LErr: ENextPasError;
begin
  Check(EWow = EInvariantViolation, 'EWow should be a compatibility alias of EInvariantViolation');
  LErr := EInvariantViolation.Create('invariant violated');
  try
    CheckEqual(Ord(ecInternal), Ord(LErr.Category),
      'EInvariantViolation should classify invariant failures as internal');
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
    CheckEqual(Ord(ecInternal), Ord(LErr.Category),
      'EInvalidResult should classify result invariant failures as internal');
  finally
    LErr.Free;
  end;

  LErr := EInvalidResult.CreateFmt('invalid result %d', [5]);
  try
    CheckEqual('invalid result 5', LErr.Message,
      'EInvalidResult.CreateFmt should format the message');
    CheckEqual(Ord(ecInternal), Ord(LErr.Category),
      'EInvalidResult.CreateFmt should classify result invariant failures as internal');
  finally
    LErr.Free;
  end;
end;

procedure ExpectInternalInvariantViolation(const AProc: TProc; const AMessage: string);
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
      CheckEqual(Ord(ecInternal), Ord(E.Category),
        AMessage + ': invariant failure should use ecInternal');
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
    CheckEqual(Ord(ecInvalidArgument), Ord(LErr.Category),
      'EArgumentNil should classify nil arguments as invalid argument');
  finally
    LErr.Free;
  end;

  LErr := EOutOfRange.CreateFmt('index %d', [7]);
  try
    CheckEqual('index 7', LErr.Message, 'EOutOfRange.CreateFmt should format the message');
    CheckEqual(Ord(ecInvalidArgument), Ord(LErr.Category),
      'EOutOfRange.CreateFmt should classify range failures as invalid argument');
  finally
    LErr.Free;
  end;

  LErr := EInvalidArgument.CreateFmt('bad %d', [8]);
  try
    CheckEqual('bad 8', LErr.Message, 'EInvalidArgument.CreateFmt should format the message');
    CheckEqual(Ord(ecInvalidArgument), Ord(LErr.Category),
      'EInvalidArgument.CreateFmt should classify invalid arguments as invalid argument');
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
    CheckEqual(Ord(ecInvalidOperation), Ord(LErr.Category),
      'EEmptyCollection should classify empty collection operations as invalid operation');
  finally
    LErr.Free;
  end;

  LErr := EInvalidState.Create('invalid state');
  try
    CheckEqual(Ord(ecInvalidOperation), Ord(LErr.Category),
      'EInvalidState should classify state failures as invalid operation');
  finally
    LErr.Free;
  end;

  LErr := EInvalidOperation.CreateFmt('bad op %d', [9]);
  try
    CheckEqual('bad op 9', LErr.Message,
      'EInvalidOperation.CreateFmt should format the message');
    CheckEqual(Ord(ecInvalidOperation), Ord(LErr.Category),
      'EInvalidOperation.CreateFmt should classify operation failures as invalid operation');
  finally
    LErr.Free;
  end;

  LErr := ENotSupported.Create('unsupported operation');
  try
    CheckEqual(Ord(ecNotSupported), Ord(LErr.Category),
      'ENotSupported should classify unsupported operations as not supported');
  finally
    LErr.Free;
  end;

  LErr := ENotCompatible.Create('collection is not compatible');
  try
    CheckEqual(Ord(ecInvalidArgument), Ord(LErr.Category),
      'ENotCompatible should classify incompatible inputs as invalid argument');
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
  Check(not CompareMem(nil, nil, 1),
    'CompareMem(nil, nil, >0) should stay false');
  Check(not CompareMem(nil, @LB[0], 1),
    'CompareMem(nil, non-nil, >0) should stay false');
  Check(not CompareMem(@LA[0], nil, 1),
    'CompareMem(non-nil, nil, >0) should stay false');
  Check(CompareMem(@LA[0], @LB[0], 2), 'CompareMem should stay true for equal buffers');
  LB[1] := 3;
  Check(not CompareMem(@LA[0], @LB[0], 2), 'CompareMem should stay false for different buffers');
end;

procedure TestSizeUIntGuardsRejectOverflow;
var
  LSum: SizeUInt;
  LOne: SizeUInt;
  LNearMax: SizeUInt;
  LHalfMaxPlusOne: SizeUInt;
  LErr: ENextPasError;
begin
  LOne := 1;
  LNearMax := MAX_SIZE_UINT - LOne;
  LHalfMaxPlusOne := MAX_SIZE_UINT div 2;
  Inc(LHalfMaxPlusOne);

  LErr := EOverflow.Create('size overflow');
  try
    CheckEqual(Ord(ecInvalidArgument), Ord(LErr.Category),
      'EOverflow should classify size overflow as invalid argument');
  finally
    LErr.Free;
  end;

  LErr := EOverflow.CreateFmt('size overflow %d', [5]);
  try
    CheckEqual('size overflow 5', LErr.Message,
      'EOverflow.CreateFmt should format the message');
    CheckEqual(Ord(ecInvalidArgument), Ord(LErr.Category),
      'EOverflow.CreateFmt should classify size overflow as invalid argument');
  finally
    LErr.Free;
  end;

  LSum := 0;
  Check(TryAddSizeUInt(10, 20, LSum), 'TryAddSizeUInt should accept in-range sums');
  CheckEqual(Int64(30), Int64(LSum), 'TryAddSizeUInt should return the exact sum');

  Check(TryAddSizeUInt(MAX_SIZE_UINT, 0, LSum),
    'TryAddSizeUInt should accept max plus zero');
  Check(LSum = MAX_SIZE_UINT,
    'TryAddSizeUInt should return MAX_SIZE_UINT for max plus zero');

  Check(TryAddSizeUInt(LNearMax, LOne, LSum),
    'TryAddSizeUInt should accept sums up to MAX_SIZE_UINT');
  Check(LSum = MAX_SIZE_UINT,
    'TryAddSizeUInt should return MAX_SIZE_UINT for max boundary sum');

  LSum := 123;
  Check(not TryAddSizeUInt(MAX_SIZE_UINT, LOne, LSum),
    'TryAddSizeUInt should reject overflow');
  CheckEqual(Int64(123), Int64(LSum),
    'TryAddSizeUInt should leave the output unchanged on overflow');

  LSum := 456;
  Check(not TryAddSizeUInt(LOne, MAX_SIZE_UINT, LSum),
    'TryAddSizeUInt should reject overflow regardless of operand order');
  CheckEqual(Int64(456), Int64(LSum),
    'TryAddSizeUInt should leave the output unchanged on reversed overflow');

  CheckEqual(Int64(30), Int64(CheckedAddSizeUInt(10, 20)),
    'CheckedAddSizeUInt should return in-range sums');
  Check(CheckedAddSizeUInt(LNearMax, LOne) = MAX_SIZE_UINT,
    'CheckedAddSizeUInt should return MAX_SIZE_UINT for max boundary sum');
  ExpectOverflow(
    procedure
    begin
      try
        CheckedAddSizeUInt(MAX_SIZE_UINT, LOne);
      except
        on E: EOverflow do
        begin
          CheckEqual(Ord(ecInvalidArgument), Ord(E.Category),
            'CheckedAddSizeUInt overflow should classify as invalid argument');
          raise;
        end;
      end;
    end,
    'CheckedAddSizeUInt should reject overflow'
  );

  LSum := 0;
  Check(TryMulSizeUInt(10, 20, LSum),
    'TryMulSizeUInt should accept in-range products');
  CheckEqual(Int64(200), Int64(LSum),
    'TryMulSizeUInt should return the exact product');

  Check(TryMulSizeUInt(MAX_SIZE_UINT, 1, LSum),
    'TryMulSizeUInt should accept max times one');
  Check(LSum = MAX_SIZE_UINT,
    'TryMulSizeUInt should return MAX_SIZE_UINT for max times one');

  Check(TryMulSizeUInt(0, MAX_SIZE_UINT, LSum),
    'TryMulSizeUInt should accept zero times max');
  CheckEqual(Int64(0), Int64(LSum),
    'TryMulSizeUInt should return zero for zero times max');

  LSum := 789;
  Check(not TryMulSizeUInt(LHalfMaxPlusOne, 2, LSum),
    'TryMulSizeUInt should reject multiplication overflow');
  CheckEqual(Int64(789), Int64(LSum),
    'TryMulSizeUInt should leave the output unchanged on multiplication overflow');

  CheckEqual(Int64(200), Int64(CheckedMulSizeUInt(10, 20)),
    'CheckedMulSizeUInt should return in-range products');
  ExpectOverflow(
    procedure
    begin
      try
        CheckedMulSizeUInt(LHalfMaxPlusOne, 2);
      except
        on E: EOverflow do
        begin
          CheckEqual(Ord(ecInvalidArgument), Ord(E.Category),
            'CheckedMulSizeUInt overflow should classify as invalid argument');
          raise;
        end;
      end;
    end,
    'CheckedMulSizeUInt should raise EOverflow before wrapping'
  );

  CheckSizeRange(0, 0, 0);
  CheckSizeRange(0, 3, 3);
  CheckSizeRange(1, 2, 3);
  CheckSizeRange(3, 0, 3);
  ExpectOutOfRange(
    procedure
    begin
      CheckSizeRange(4, 0, 3);
    end,
    'CheckSizeRange should reject offsets past the size'
  );
  ExpectOutOfRange(
    procedure
    begin
      CheckSizeRange(2, 2, 3);
    end,
    'CheckSizeRange should reject length past the remaining size'
  );
  ExpectOutOfRange(
    procedure
    begin
      CheckSizeRange(LNearMax, 2, MAX_SIZE_UINT);
    end,
    'CheckSizeRange should reject overflow without wrapping offset + length'
  );
end;

procedure TestSupportsClearsOutParamOnFailure;
var
  LObj: TBaseSupportsProbe;
  LKeepAlive: IInterface;
  LInstance: IInterface;
  LProbe: IBaseSupportsProbe;
  LOther: IBaseSupportsOther;
begin
  LObj := TBaseSupportsProbe.Create;
  LKeepAlive := LObj as IInterface;
  try
    Check(LKeepAlive <> nil, 'supports probe object should stay alive during the test');

    LProbe := LObj as IBaseSupportsProbe;
    Check(not Supports(TObject(nil), IBaseSupportsProbe, LProbe),
      'Supports(nil object) should return false');
    Check(LProbe = nil,
      'Supports(nil object) should clear the out interface');

    LProbe := LObj as IBaseSupportsProbe;
    LOther := TBaseSupportsOther.Create as IBaseSupportsOther;
    Check(not Supports(LObj, IBaseSupportsOther, LOther),
      'Supports(object, unsupported interface) should return false');
    Check(LOther = nil,
      'Supports(object, unsupported interface) should clear the out interface');

    Check(Supports(LObj, IBaseSupportsProbe, LProbe),
      'Supports(object, supported interface) should return true');
    Check(LProbe <> nil,
      'Supports(object, supported interface) should assign the out interface');
    CheckEqual(Int64(42), Int64(LProbe.Value),
      'Supports(object, supported interface) should return the requested interface');

    LInstance := LObj as IInterface;
    LProbe := LObj as IBaseSupportsProbe;
    Check(not Supports(IInterface(nil), IBaseSupportsProbe, LProbe),
      'Supports(nil interface) should return false');
    Check(LProbe = nil,
      'Supports(nil interface) should clear the out interface');

    LOther := TBaseSupportsOther.Create as IBaseSupportsOther;
    Check(not Supports(LInstance, IBaseSupportsOther, LOther),
      'Supports(interface, unsupported interface) should return false');
    Check(LOther = nil,
      'Supports(interface, unsupported interface) should clear the out interface');

    Check(Supports(LInstance, IBaseSupportsProbe, LProbe),
      'Supports(interface, supported interface) should return true');
    Check((LProbe <> nil) and (LProbe.Value = 42),
      'Supports(interface, supported interface) should assign the out interface');
  finally
    LOther := nil;
    LProbe := nil;
    LInstance := nil;
    LKeepAlive := nil;
  end;
end;

procedure TestFreeAndNilObjectLifecycle;
var
  LObj: TObject;
begin
  GLifecycleProbeDestroyed := 0;
  GLifecycleProbeSawNilBeforeDestroy := False;

  LObj := nil;
  FreeAndNil(LObj);
  Check(LObj = nil, 'FreeAndNil(nil) should keep the variable nil');
  CheckEqual(Int64(0), Int64(GLifecycleProbeDestroyed), 'FreeAndNil(nil) should not destroy an object');

  LObj := TBaseLifecycleProbe.Create(@LObj);
  FreeAndNil(LObj);
  Check(LObj = nil, 'FreeAndNil should nil the variable');
  Check(GLifecycleProbeSawNilBeforeDestroy, 'FreeAndNil should nil the variable before destructor runs');
  CheckEqual(Int64(1), Int64(GLifecycleProbeDestroyed), 'FreeAndNil should destroy exactly once');

  FreeAndNil(LObj);
  CheckEqual(Int64(1), Int64(GLifecycleProbeDestroyed), 'FreeAndNil should be repeat-safe after nil');
end;

procedure TestSafeFreeObjectLifecycle;
var
  LObj: TObject;
begin
  GLifecycleProbeDestroyed := 0;
  GLifecycleProbeSawNilBeforeDestroy := False;

  LObj := nil;
  SafeFree(LObj);
  Check(LObj = nil, 'SafeFree(nil) should keep the variable nil');
  CheckEqual(Int64(0), Int64(GLifecycleProbeDestroyed), 'SafeFree(nil) should not destroy an object');

  LObj := TBaseLifecycleProbe.Create(@LObj);
  SafeFree(LObj);
  Check(LObj = nil, 'SafeFree should nil the variable');
  Check(GLifecycleProbeSawNilBeforeDestroy, 'SafeFree should nil the variable before destructor runs');
  CheckEqual(Int64(1), Int64(GLifecycleProbeDestroyed), 'SafeFree should destroy exactly once');

  SafeFree(LObj);
  CheckEqual(Int64(1), Int64(GLifecycleProbeDestroyed), 'SafeFree should be repeat-safe after nil');
end;

procedure TestByteSpanRejectsNilNonEmpty;
begin
  ExpectInvalidArgumentNil(
    procedure
    begin
      TByteSpan.Create(nil, 1);
    end,
    'TByteSpan.Create(nil, >0) should raise EArgumentNil'
  );
end;

procedure TestByteSpanSliceRejectsOverflow;
var
  LData: array[0..1] of Byte;
  LSpan: TByteSpan;
begin
  LSpan := TByteSpan.Create(@LData[0], Length(LData));
  ExpectOutOfRange(
    procedure
    begin
      LSpan.Slice(MAX_SIZE_UINT, 2);
    end,
    'TByteSpan.Slice should reject offset + length overflow'
  );
end;

procedure TestByteSpanEmptyGetByteRejectsWithoutUnderflowedRange;
var
  LSpan: TByteSpan;
begin
  LSpan := TByteSpan.Empty;
  ExpectOutOfRangeMessage(
    procedure
    begin
      LSpan.GetByte(0);
    end,
    'TByteSpan: index 0 out of range for empty span',
    'TByteSpan.GetByte on empty span should not report an underflowed range'
  );
end;

procedure TestByteSpanRejectsInvalidPublicRecordState;
var
  LSpan: TByteSpan;
begin
  LSpan.Data := nil;
  LSpan.Len := 1;

  ExpectInvalidArgumentNil(
    procedure
    begin
      LSpan.Slice(0, 1);
    end,
    'TByteSpan.Slice should reject nil data when Len > 0'
  );

  ExpectInvalidArgumentNil(
    procedure
    begin
      LSpan.GetByte(0);
    end,
    'TByteSpan.GetByte should reject nil data when Len > 0'
  );
end;

procedure TestByteSpanFromBytesAndEmptySliceBoundaries;
var
  LBytes: TBytes;
  LSpan: TByteSpan;
  LEmpty: TByteSpan;
begin
  SetLength(LBytes, 3);
  LBytes[0] := $11;
  LBytes[1] := $22;
  LBytes[2] := $33;

  LSpan := TByteSpan.FromBytes(LBytes);
  Check(not LSpan.IsEmpty, 'FromBytes(non-empty) should create a non-empty view');
  Check(LSpan.Data = @LBytes[0], 'FromBytes(non-empty) should point at the first byte');
  CheckEqual(Int64(3), Int64(LSpan.Len), 'FromBytes(non-empty) should preserve length');
  CheckEqual(Int64($11), Int64(LSpan.GetByte(0)), 'FromBytes view should read first byte');
  CheckEqual(Int64($33), Int64(LSpan.GetByte(2)), 'FromBytes view should read last byte');

  ExpectOutOfRange(
    procedure
    begin
      LSpan.GetByte(3);
    end,
    'TByteSpan.GetByte(Len) should reject the one-past index'
  );

  LEmpty := LSpan.Slice(LSpan.Len, 0);
  Check(LEmpty.IsEmpty, 'Slice(Len, 0) should be empty');
  Check(LEmpty.Data = nil, 'Slice(Len, 0) should return canonical empty span');

  SetLength(LBytes, 0);
  LEmpty := TByteSpan.FromBytes(LBytes);
  Check(LEmpty.IsEmpty, 'FromBytes(empty) should create an empty view');
  Check(LEmpty.Data = nil, 'FromBytes(empty) should return canonical empty span');
end;

procedure TestHashBytesRejectsNilNonEmpty;
begin
  ExpectInvalidArgumentNil(
    procedure
    begin
      HashBytes(nil, 1);
    end,
    'HashBytes(nil, >0) should raise EArgumentNil'
  );
end;

procedure TestHashBytesKeepsFnvWraparound;
var
  LData: array[0..3] of Byte;
begin
  LData[0] := $FF;
  LData[1] := $EE;
  LData[2] := $DD;
  LData[3] := $CC;

  Check(HashBytes(@LData[0], Length(LData)) = THashCode($79E26891),
    'HashBytes should keep FNV-1a 32-bit wraparound semantics');
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

procedure TestNullableInterfacePayloadLifecycle;

  procedure Exercise;
  var
    LNullable: TTrackedNullable;
    LUnwrapped: IBaseTrackedPayload;
  begin
    LNullable := TTrackedNullable.Some(NewTrackedPayload(101));
    CheckTrackedPayloadAlive(1, 'Nullable.Some should retain interface payload');
    CheckEqual(Int64(101), Int64(LNullable.Value.Id), 'Nullable.Some should unwrap interface payload');

    LNullable := TTrackedNullable.Some(NewTrackedPayload(102));
    CheckTrackedPayloadAlive(1, 'Nullable.Some overwrite should release previous payload');
    CheckEqual(Int64(102), Int64(LNullable.Value.Id), 'Nullable overwrite should keep the new payload');

    LUnwrapped := LNullable.Value;
    LNullable := TTrackedNullable.None;
    CheckTrackedPayloadAlive(1, 'Nullable.None overwrite should keep separately unwrapped interface alive');
    CheckEqual(Int64(102), Int64(LUnwrapped.Id), 'unwrapped Nullable payload should remain usable');

    LUnwrapped := nil;
    CheckTrackedPayloadAlive(1, 'Nullable.None carrier assignment may release hidden managed temporaries at scope exit');

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

procedure TestOptionInterfacePayloadLifecycle;

  procedure Exercise;
  var
    LOption: TTrackedOption;
    LUnwrapped: IBaseTrackedPayload;
  begin
    LOption := TTrackedOption.Some(NewTrackedPayload(1));
    CheckTrackedPayloadAlive(1, 'Option.Some should retain interface payload');
    CheckEqual(Int64(1), Int64(LOption.Unwrap.Id), 'Option.Some should unwrap interface payload');

    LOption := TTrackedOption.Some(NewTrackedPayload(2));
    CheckTrackedPayloadAlive(1, 'Option.Some overwrite should release previous payload');
    CheckEqual(Int64(2), Int64(LOption.Unwrap.Id), 'Option overwrite should keep the new payload');

    LUnwrapped := LOption.Unwrap;
    LOption := TTrackedOption.None;
    CheckTrackedPayloadAlive(1, 'Option.None overwrite should keep separately unwrapped interface alive');
    CheckEqual(Int64(2), Int64(LUnwrapped.Id), 'unwrapped Option payload should remain usable');

    LUnwrapped := nil;
    CheckTrackedPayloadAlive(1, 'Option.None carrier assignment may release hidden managed temporaries at scope exit');

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

procedure TestResultInterfacePayloadLifecycle;

  procedure Exercise;
  var
    LResult: TTrackedResult;
    LUnwrapped: IBaseTrackedPayload;
  begin
    LResult := TTrackedResult.Ok(NewTrackedPayload(10));
    CheckTrackedPayloadAlive(1, 'Result.Ok should retain interface payload');
    CheckEqual(Int64(10), Int64(LResult.Unwrap.Id), 'Result.Ok should unwrap interface payload');

    LResult := TTrackedResult.Err(NewTrackedPayload(20));
    CheckTrackedPayloadAlive(1, 'Result.Err overwrite should release previous ok payload');
    CheckEqual(Int64(20), Int64(LResult.UnwrapErr.Id), 'Result.Err should unwrap error payload');

    LUnwrapped := LResult.UnwrapErr;
    LResult := TTrackedResult.Ok(NewTrackedPayload(30));
    CheckTrackedPayloadAlive(2, 'Result.Ok overwrite should keep separately unwrapped error payload alive');
    CheckEqual(Int64(20), Int64(LUnwrapped.Id), 'unwrapped Result error payload should remain usable');
    CheckEqual(Int64(30), Int64(LResult.Unwrap.Id), 'Result.Ok overwrite should keep the new ok payload');

    LUnwrapped := nil;
    CheckTrackedPayloadAlive(1, 'clearing unwrapped Result error payload should release that reference');

    LResult := TTrackedResult.Err(NewTrackedPayload(40));
    CheckTrackedPayloadAlive(1, 'Result.Err overwrite should release previous ok payload');
    CheckEqual(Int64(40), Int64(LResult.UnwrapErr.Id), 'Result.Err overwrite should keep the new error payload');
  end;

begin
  CheckTrackedPayloadAlive(0, 'Result lifecycle starts without tracked payloads');
  Exercise;
  CheckTrackedPayloadAlive(0, 'Result local scope should release managed interface payloads');
end;

begin
  T := TTestRunner.Create('nextpas.core.base');
  T.Run('framework identity', @TestFrameworkIdentity);
  T.Run('invariant compatibility alias', @TestInvariantCompatibilityAlias);
  T.Run('base result exceptions use internal category', @TestBaseResultExceptionsUseInternalCategory);
  T.Run('base validation exceptions use invalid-argument category', @TestBaseValidationExceptionsUseInvalidArgumentCategory);
  T.Run('base operation exceptions use specific categories', @TestBaseOperationExceptionsUseSpecificCategories);
  T.Run('base EOutOfMemoryError long name is canonical', @TestBaseOutOfMemoryLongNameIsCanonical);
  T.Run('contract helpers use framework exceptions', @TestContractHelpersUseFrameworkExceptions);
  T.Run('zeromem handles zero-size and nil', @TestZeroMemHandlesZeroSizeAndNil);
  T.Run('copymem handles zero-size and nil', @TestCopyMemHandlesZeroSizeAndNil);
  T.Run('comparemem semantics stay stable', @TestCompareMemSemanticsStayStable);
  T.Run('SizeUInt guards reject overflow', @TestSizeUIntGuardsRejectOverflow);
  T.Run('supports clears out param on failure', @TestSupportsClearsOutParamOnFailure);
  T.Run('FreeAndNil object lifecycle', @TestFreeAndNilObjectLifecycle);
  T.Run('SafeFree object lifecycle', @TestSafeFreeObjectLifecycle);
  T.Run('bytespan rejects nil non-empty', @TestByteSpanRejectsNilNonEmpty);
  T.Run('bytespan slice rejects overflow', @TestByteSpanSliceRejectsOverflow);
  T.Run('bytespan empty getbyte rejects without underflowed range', @TestByteSpanEmptyGetByteRejectsWithoutUnderflowedRange);
  T.Run('bytespan rejects invalid public record state', @TestByteSpanRejectsInvalidPublicRecordState);
  T.Run('bytespan FromBytes and empty slice boundaries', @TestByteSpanFromBytesAndEmptySliceBoundaries);
  T.Run('hashbytes rejects nil non-empty', @TestHashBytesRejectsNilNonEmpty);
  T.Run('hashbytes keeps fnv wraparound', @TestHashBytesKeepsFnvWraparound);
  T.Run('nullable surface', @TestNullableSurface);
  T.Run('nullable interface payload lifecycle', @TestNullableInterfacePayloadLifecycle);
  T.Run('option surface', @TestOptionSurface);
  T.Run('option interface payload lifecycle', @TestOptionInterfacePayloadLifecycle);
  T.Run('result surface', @TestResultSurface);
  T.Run('result interface payload lifecycle', @TestResultInterfacePayloadLifecycle);
  T.Summary;
end.
