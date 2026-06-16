program test_system_facade;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.base,
  nextpas.core.system,
  nextpas.core.exception,
  nextpas.core.errors;

type
  PObjectRef = ^TObject;
  PIntegerRef = ^Integer;
  PBooleanRef = ^Boolean;

  ISystemFacadeProbe = interface
    ['{04BE096F-2108-4D91-A781-35939E37FC01}']
    function Value: Integer;
  end;

  TSystemFacadeProbe = class(TInterfacedObject, ISystemFacadeProbe)
  public
    function Value: Integer;
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

procedure TestSystemConstantsMirrorBaseCompileTruth;
begin
  CheckEqual('nextpas.core.system', nextpas.core.system.NEXTPAS_SYSTEM_NAME,
    'system name should identify the root facade');
  Check(nextpas.core.system.MAX_SIZE_INT = nextpas.core.base.MAX_SIZE_INT,
    'system MAX_SIZE_INT should mirror base');
  Check(nextpas.core.system.MAX_SIZE_UINT = nextpas.core.base.MAX_SIZE_UINT,
    'system MAX_SIZE_UINT should mirror base');
  Check(nextpas.core.system.MIN_SIZE_INT = nextpas.core.base.MIN_SIZE_INT,
    'system MIN_SIZE_INT should mirror base');
  Check(nextpas.core.system.SIZE_PTR = nextpas.core.base.SIZE_PTR,
    'system SIZE_PTR should mirror base');
  Check(nextpas.core.system.SIZE_8 = SizeOf(UInt8),
    'system SIZE_8 should stay tied to UInt8');
  Check(nextpas.core.system.SIZE_16 = SizeOf(UInt16),
    'system SIZE_16 should stay tied to UInt16');
  Check(nextpas.core.system.SIZE_32 = SizeOf(UInt32),
    'system SIZE_32 should stay tied to UInt32');
  Check(nextpas.core.system.SIZE_64 = SizeOf(UInt64),
    'system SIZE_64 should stay tied to UInt64');
end;

procedure TestSystemBaseCarrierAliasesMirrorBaseCompileTruth;
var
  LSystemBytes: nextpas.core.system.TBytes;
  LBaseBytes: nextpas.core.base.TBytes;
  LSystemSpan: nextpas.core.system.TByteSpan;
  LBaseSpan: nextpas.core.base.TByteSpan;
  LSystemHash: nextpas.core.system.THashCode;
  LBaseHash: nextpas.core.base.THashCode;
begin
  SetLength(LSystemBytes, 2);
  LSystemBytes[0] := 11;
  LSystemBytes[1] := 22;

  LBaseBytes := LSystemBytes;
  LSystemSpan := nextpas.core.system.TByteSpan.FromBytes(LSystemBytes);
  LBaseSpan := LSystemSpan;

  CheckEqual(Int64(2), Int64(Length(LBaseBytes)),
    'system TBytes should be assignable to base TBytes');
  CheckEqual(Int64(2), Int64(LBaseSpan.Len),
    'system TByteSpan should be assignable to base TByteSpan');
  CheckEqual(Int64(11), Int64(LBaseSpan[0]),
    'system TByteSpan should keep base byte access semantics');
  CheckEqual(Int64(22), Int64(LBaseSpan[1]),
    'system TByteSpan should keep base byte access semantics for later bytes');

  LSystemHash := nextpas.core.system.THashCode(12345);
  LBaseHash := LSystemHash;
  Check(LBaseHash = nextpas.core.base.THashCode(12345),
    'system THashCode should be assignable to base THashCode');
end;

procedure TestSystemAbiAliasesMirrorCompilerTruth;
var
  LSystemSizeInt: nextpas.core.system.SizeInt;
  LSystemSizeUInt: nextpas.core.system.SizeUInt;
  LSystemPtrInt: nextpas.core.system.PtrInt;
  LSystemPtrUInt: nextpas.core.system.PtrUInt;
  LSystemNativeInt: nextpas.core.system.NativeInt;
  LSystemNativeUInt: nextpas.core.system.NativeUInt;
  LCompilerSizeInt: System.SizeInt;
  LCompilerSizeUInt: System.SizeUInt;
  LCompilerPtrInt: System.PtrInt;
  LCompilerPtrUInt: System.PtrUInt;
  LCompilerNativeInt: System.NativeInt;
  LCompilerNativeUInt: System.NativeUInt;
begin
  LSystemSizeInt := -42;
  LSystemSizeUInt := 42;
  LSystemPtrInt := -21;
  LSystemPtrUInt := 21;
  LSystemNativeInt := -7;
  LSystemNativeUInt := 7;

  LCompilerSizeInt := LSystemSizeInt;
  LCompilerSizeUInt := LSystemSizeUInt;
  LCompilerPtrInt := LSystemPtrInt;
  LCompilerPtrUInt := LSystemPtrUInt;
  LCompilerNativeInt := LSystemNativeInt;
  LCompilerNativeUInt := LSystemNativeUInt;

  CheckEqual(Int64(-42), Int64(LCompilerSizeInt),
    'system SizeInt should mirror compiler/System SizeInt');
  CheckEqual(Int64(42), Int64(LCompilerSizeUInt),
    'system SizeUInt should mirror compiler/System SizeUInt');
  CheckEqual(Int64(-21), Int64(LCompilerPtrInt),
    'system PtrInt should mirror compiler/System PtrInt');
  CheckEqual(Int64(21), Int64(LCompilerPtrUInt),
    'system PtrUInt should mirror compiler/System PtrUInt');
  CheckEqual(Int64(-7), Int64(LCompilerNativeInt),
    'system NativeInt should mirror compiler/System NativeInt');
  CheckEqual(Int64(7), Int64(LCompilerNativeUInt),
    'system NativeUInt should mirror compiler/System NativeUInt');
end;

function TSystemFacadeProbe.Value: Integer;
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

procedure TestBaseAndSystemByteAliasesCoexist;
var
  LSystemBytes: nextpas.core.system.TBytes;
  LBaseBytes: nextpas.core.base.TBytes;
begin
  SetLength(LSystemBytes, 3);
  LSystemBytes[0] := 7;
  LSystemBytes[1] := 8;
  LSystemBytes[2] := 9;

  LBaseBytes := LSystemBytes;
  CheckEqual(Int64(3), Int64(Length(LBaseBytes)), 'system TBytes must be assignable to base TBytes');

  nextpas.core.system.ZeroMem(@LSystemBytes[0], Length(LSystemBytes));
  CheckEqual(Int64(0), Int64(LSystemBytes[0]), 'ZeroMem clears first byte');
  CheckEqual(Int64(0), Int64(LSystemBytes[1]), 'ZeroMem clears middle byte');
  CheckEqual(Int64(0), Int64(LSystemBytes[2]), 'ZeroMem clears last byte');
end;

procedure TestSystemMemoryGuardsDelegateToBaseContract;
var
  LCaught: Boolean;
begin
  nextpas.core.system.ZeroMem(nil, 0);

  LCaught := False;
  try
    nextpas.core.system.ZeroMem(nil, 1);
  except
    on E: nextpas.core.base.EArgumentNil do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;

  Check(LCaught, 'system ZeroMem must preserve base EArgumentNil guard');
end;

procedure TestCopyAndCompareFacadeDelegatesToBaseUtils;
var
  LSource: array[0..2] of Byte = (1, 2, 3);
  LTarget: array[0..2] of Byte = (0, 0, 0);
  LCaught: Boolean;
begin
  nextpas.core.system.CopyMem(@LTarget[0], nil, 0);
  CheckEqual(Int64(0), Int64(LTarget[0]), 'system CopyMem size 0 should not touch target');

  nextpas.core.system.CopyMem(@LTarget[0], @LSource[0], SizeOf(LSource));
  Check(nextpas.core.system.CompareMem(@LTarget[0], @LSource[0], SizeOf(LSource)),
    'system CopyMem/CompareMem should share base utils semantics');
  LTarget[2] := 4;
  Check(not nextpas.core.system.CompareMem(@LTarget[0], @LSource[0], SizeOf(LSource)),
    'system CompareMem should detect unequal buffers');
  Check(not nextpas.core.system.CompareMem(nil, nil, 1),
    'system CompareMem should preserve base nil/nil false semantics');
  Check(not nextpas.core.system.CompareMem(nil, @LSource[0], 1),
    'system CompareMem should preserve base one-side-nil false semantics');
  Check(not nextpas.core.system.CompareMem(@LSource[0], nil, 1),
    'system CompareMem should preserve base one-side-nil false semantics');

  LCaught := False;
  try
    nextpas.core.system.CopyMem(nil, @LSource[0], 1);
  except
    on E: nextpas.core.base.EArgumentNil do
      LCaught := True;
  end;
  Check(LCaught, 'system CopyMem should preserve nil destination guard');

  LCaught := False;
  try
    nextpas.core.system.CopyMem(@LTarget[0], nil, 1);
  except
    on E: nextpas.core.base.EArgumentNil do
      LCaught := True;
  end;
  Check(LCaught, 'system CopyMem should preserve nil source guard');
end;

procedure TestSystemMemoryFacadeDelegatesFullBaseUtilsContract;
var
  LSource: array[0..3] of Byte = (5, 6, 7, 8);
  LTarget: array[0..3] of Byte = (0, 0, 0, 0);
  LCaught: Boolean;
begin
  nextpas.core.system.ZeroMem(nil, 0);
  nextpas.core.system.CopyMem(nil, nil, 0);
  Check(nextpas.core.system.CompareMem(nil, nil, 0),
    'system CompareMem should preserve base zero-size true semantics');

  nextpas.core.system.CopyMem(@LTarget[0], @LSource[0], SizeOf(LSource));
  Check(nextpas.core.system.CompareMem(@LTarget[0], @LSource[0], SizeOf(LSource)),
    'system CopyMem should delegate copying to base utils');

  nextpas.core.system.ZeroMem(@LTarget[0], SizeOf(LTarget));
  CheckEqual(Int64(0), Int64(LTarget[0]), 'system ZeroMem should clear byte 0');
  CheckEqual(Int64(0), Int64(LTarget[3]), 'system ZeroMem should clear byte 3');

  LCaught := False;
  try
    nextpas.core.system.ZeroMem(nil, 1);
  except
    on E: nextpas.core.base.EArgumentNil do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;
  Check(LCaught, 'system ZeroMem should preserve base nil destination exception root');

  LCaught := False;
  try
    nextpas.core.system.CopyMem(nil, @LSource[0], 1);
  except
    on E: nextpas.core.base.EArgumentNil do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;
  Check(LCaught, 'system CopyMem should preserve base nil destination exception root');
end;

procedure TestSystemFillMemDelegatesToBaseUtils;
var
  LBytes: array[0..3] of Byte = (1, 2, 3, 4);
  LCaught: Boolean;
begin
  nextpas.core.system.FillMem(nil, 0, $AA);
  nextpas.core.system.FillMem(@LBytes[0], 0, $AA);
  CheckEqual(Int64(1), Int64(LBytes[0]), 'system FillMem size 0 should not mutate');

  nextpas.core.system.FillMem(@LBytes[0], SizeOf(LBytes), $AA);
  CheckEqual(Int64($AA), Int64(LBytes[0]), 'system FillMem should fill first byte');
  CheckEqual(Int64($AA), Int64(LBytes[3]), 'system FillMem should fill last byte');

  nextpas.core.system.FillMem(@LBytes[1], 2, $11);
  CheckEqual(Int64($AA), Int64(LBytes[0]), 'system FillMem should preserve byte before range');
  CheckEqual(Int64($11), Int64(LBytes[1]), 'system FillMem should fill range start');
  CheckEqual(Int64($11), Int64(LBytes[2]), 'system FillMem should fill range end');
  CheckEqual(Int64($AA), Int64(LBytes[3]), 'system FillMem should preserve byte after range');

  LCaught := False;
  try
    nextpas.core.system.FillMem(nil, 1, $AA);
  except
    on E: nextpas.core.base.EArgumentNil do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;
  Check(LCaught, 'system FillMem should preserve base nil destination exception root');
end;

procedure TestObjectLifecycleHelpersDelegateToBaseUtils;
var
  LObject: TObject;
  LDestroyCount: Integer;
  LReferenceWasNil: Boolean;
begin
  LDestroyCount := 0;
  LReferenceWasNil := False;
  LObject := TDestructorProbe.Create(@LObject, @LDestroyCount, @LReferenceWasNil);
  nextpas.core.system.FreeAndNil(LObject);
  Check(LObject = nil, 'system FreeAndNil should nil the object reference');
  CheckEqual(Int64(1), Int64(LDestroyCount), 'system FreeAndNil should destroy the object once');
  Check(LReferenceWasNil, 'system FreeAndNil should nil the reference before destructor execution');

  LObject := TObject.Create;
  nextpas.core.system.SafeFree(LObject);
  Check(LObject = nil, 'system SafeFree should nil the object reference');

  LObject := nil;
  nextpas.core.system.FreeAndNil(LObject);
  Check(LObject = nil, 'system FreeAndNil should accept nil references');
  nextpas.core.system.SafeFree(LObject);
  Check(LObject = nil, 'system SafeFree should accept nil references');
end;

procedure TestSupportsFacadeDelegatesObjectAndInterfaceQueries;
var
  LObject: TSystemFacadeProbe;
  LOwner: IInterface;
  LProbe: ISystemFacadeProbe;
  LInterface: IInterface;
begin
  LObject := TSystemFacadeProbe.Create;
  LOwner := LObject as IInterface;
  try
    Check(LOwner <> nil, 'probe owner should hold the object alive during object Supports query');
    Check(nextpas.core.system.Supports(LObject, ISystemFacadeProbe, LProbe),
      'system Supports(TObject) should query supported interfaces');
    CheckEqual(Int64(42), Int64(LProbe.Value),
      'system Supports(TObject) should return the queried interface');
  finally
    LProbe := nil;
    LOwner := nil;
  end;

  LInterface := TSystemFacadeProbe.Create as IInterface;
  Check(nextpas.core.system.Supports(LInterface, ISystemFacadeProbe, LProbe),
    'system Supports(IInterface) should query supported interfaces');
  CheckEqual(Int64(42), Int64(LProbe.Value),
    'system Supports(IInterface) should return the queried interface');

  LProbe := nil;
  LInterface := nil;
  Check(not nextpas.core.system.Supports(TObject(nil), ISystemFacadeProbe, LProbe),
    'system Supports(TObject) should return false for nil object references');
  Check(not nextpas.core.system.Supports(IInterface(nil), ISystemFacadeProbe, LProbe),
    'system Supports(IInterface) should return false for nil interface references');
end;

procedure TestSystemExceptionRootIsCanonical;
var
  LError: nextpas.core.system.ENextPasError;
begin
  LError := nextpas.core.system.ENextPasError.Create('system error');
  try
    Check(LError is nextpas.core.exception.ENextPasError,
      'system ENextPasError must be the canonical framework root');
    Check(LError.ClassType = nextpas.core.exception.ENextPasError,
      'system ENextPasError must not introduce a shadow subclass');
  finally
    LError.Free;
  end;
end;

procedure TestSystemBaseErrorAliasesMirrorBaseCompileTruth;
var
  LCore: nextpas.core.system.ECore;
  LInvariant: nextpas.core.system.EInvariantViolation;
  LArgumentNil: nextpas.core.system.EArgumentNil;
  LEmptyCollection: nextpas.core.system.EEmptyCollection;
  LInvalidArgument: nextpas.core.system.EInvalidArgument;
  LInvalidResult: nextpas.core.system.EInvalidResult;
  LInvalidState: nextpas.core.system.EInvalidState;
  LOutOfRange: nextpas.core.system.EOutOfRange;
  LNotSupported: nextpas.core.system.ENotSupported;
  LNotCompatible: nextpas.core.system.ENotCompatible;
  LInvalidOperation: nextpas.core.system.EInvalidOperation;
  LOverflow: nextpas.core.system.EOverflow;
begin
  LCore := nil;
  LInvariant := nil;
  LArgumentNil := nil;
  LEmptyCollection := nil;
  LInvalidArgument := nil;
  LInvalidResult := nil;
  LInvalidState := nil;
  LOutOfRange := nil;
  LNotSupported := nil;
  LNotCompatible := nil;
  LInvalidOperation := nil;
  LOverflow := nil;
  try
    LCore := nextpas.core.system.ECore.Create('core');
    LInvariant := nextpas.core.system.EInvariantViolation.Create('invariant');
    LArgumentNil := nextpas.core.system.EArgumentNil.Create('argument nil');
    LEmptyCollection := nextpas.core.system.EEmptyCollection.Create('empty');
    LInvalidArgument := nextpas.core.system.EInvalidArgument.Create('invalid argument');
    LInvalidResult := nextpas.core.system.EInvalidResult.Create('invalid result');
    LInvalidState := nextpas.core.system.EInvalidState.Create('invalid state');
    LOutOfRange := nextpas.core.system.EOutOfRange.Create('out of range');
    LNotSupported := nextpas.core.system.ENotSupported.Create('not supported');
    LNotCompatible := nextpas.core.system.ENotCompatible.Create('not compatible');
    LInvalidOperation := nextpas.core.system.EInvalidOperation.Create('invalid operation');
    LOverflow := nextpas.core.system.EOverflow.Create('overflow');

    Check(LCore.ClassType = nextpas.core.base.ECore,
      'system ECore should be canonical base owner alias');
    Check(LInvariant.ClassType = nextpas.core.base.EInvariantViolation,
      'system EInvariantViolation should be canonical base owner alias');
    Check(LArgumentNil.ClassType = nextpas.core.base.EArgumentNil,
      'system EArgumentNil should be canonical base owner alias');
    Check(LEmptyCollection.ClassType = nextpas.core.base.EEmptyCollection,
      'system EEmptyCollection should be canonical base owner alias');
    Check(LInvalidArgument.ClassType = nextpas.core.base.EInvalidArgument,
      'system EInvalidArgument should be canonical base owner alias');
    Check(LInvalidResult.ClassType = nextpas.core.base.EInvalidResult,
      'system EInvalidResult should be canonical base owner alias');
    Check(LInvalidState.ClassType = nextpas.core.base.EInvalidState,
      'system EInvalidState should be canonical base owner alias');
    Check(LOutOfRange.ClassType = nextpas.core.base.EOutOfRange,
      'system EOutOfRange should be canonical base owner alias');
    Check(LNotSupported.ClassType = nextpas.core.base.ENotSupported,
      'system ENotSupported should be canonical base owner alias');
    Check(LNotCompatible.ClassType = nextpas.core.base.ENotCompatible,
      'system ENotCompatible should be canonical base owner alias');
    Check(LInvalidOperation.ClassType = nextpas.core.base.EInvalidOperation,
      'system EInvalidOperation should be canonical base owner alias');
    Check(LOverflow.ClassType = nextpas.core.base.EOverflow,
      'system EOverflow should be canonical base owner alias');
  finally
    LOverflow.Free;
    LInvalidOperation.Free;
    LNotCompatible.Free;
    LNotSupported.Free;
    LOutOfRange.Free;
    LInvalidState.Free;
    LInvalidResult.Free;
    LInvalidArgument.Free;
    LEmptyCollection.Free;
    LArgumentNil.Free;
    LInvariant.Free;
    LCore.Free;
  end;
end;

procedure TestErrorsFacadeStillCatchesThroughSystemRoot;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise nextpas.core.errors.ETimeoutError.Create('timeout');
  except
    on E: nextpas.core.system.ENextPasError do
      LCaught := E.Category = nextpas.core.exception.ecTimeout;
  end;

  Check(LCaught, 'errors facade exceptions must catch through system root alias');
end;

procedure TestSystemExceptionAliasesStayCanonical;
var
  LConvertError: nextpas.core.system.EConvertError;
  LAssertionError: nextpas.core.system.EAssertionFailed;
begin
  LConvertError := nextpas.core.system.EConvertError.Create('conversion failed');
  try
    Check(LConvertError is nextpas.core.exception.EConvertError,
      'system EConvertError must stay the canonical exception alias');
  finally
    LConvertError.Free;
  end;

  LAssertionError := nextpas.core.system.EAssertionFailed.Create('assertion failed');
  try
    Check(LAssertionError is nextpas.core.exception.EAssertionFailed,
      'system EAssertionFailed must stay the canonical exception alias');
  finally
    LAssertionError.Free;
  end;
end;

procedure TestSystemErrorTaxonomyAliasesMirrorCanonicalOwners;
var
  LArgumentError: nextpas.core.system.EArgumentError;
  LNullError: nextpas.core.system.ENullReferenceError;
  LInvalidOperationError: nextpas.core.system.EInvalidOperationError;
  LNotImplementedError: nextpas.core.system.ENotImplementedError;
  LNotSupportedError: nextpas.core.system.ENotSupportedError;
  LTimeoutError: nextpas.core.system.ETimeoutError;
  LCancelledError: nextpas.core.system.ECancelledError;
  LPermissionError: nextpas.core.system.EPermissionError;
  LNotFoundError: nextpas.core.system.ENotFoundError;
  LAlreadyExistsError: nextpas.core.system.EAlreadyExistsError;
  LResourceError: nextpas.core.system.EResourceExhaustedError;
  LIOError: nextpas.core.system.EIOError;
  LNetworkError: nextpas.core.system.ENetworkError;
  LParseError: nextpas.core.system.EParseError;
  LIndexError: nextpas.core.system.EIndexOutOfRangeError;
  LOutOfMemoryError: nextpas.core.system.EOutOfMemoryError;
  LOutOfMemory: nextpas.core.system.EOutOfMemory;
begin
  Check(nextpas.core.system.ecNone = nextpas.core.errors.ecNone,
    'system ecNone should mirror errors owner');
  Check(nextpas.core.system.ecInvalidArgument = nextpas.core.errors.ecInvalidArgument,
    'system ecInvalidArgument should mirror errors owner');
  Check(nextpas.core.system.ecNullReference = nextpas.core.errors.ecNullReference,
    'system ecNullReference should mirror errors owner');
  Check(nextpas.core.system.ecInvalidOperation = nextpas.core.errors.ecInvalidOperation,
    'system ecInvalidOperation should mirror errors owner');
  Check(nextpas.core.system.ecNotImplemented = nextpas.core.errors.ecNotImplemented,
    'system ecNotImplemented should mirror errors owner');
  Check(nextpas.core.system.ecNotSupported = nextpas.core.errors.ecNotSupported,
    'system ecNotSupported should mirror errors owner');
  Check(nextpas.core.system.ecTimeout = nextpas.core.errors.ecTimeout,
    'system ecTimeout should mirror errors owner');
  Check(nextpas.core.system.ecCancelled = nextpas.core.errors.ecCancelled,
    'system ecCancelled should mirror errors owner');
  Check(nextpas.core.system.ecInterrupted = nextpas.core.errors.ecInterrupted,
    'system ecInterrupted should mirror errors owner');
  Check(nextpas.core.system.ecWouldBlock = nextpas.core.errors.ecWouldBlock,
    'system ecWouldBlock should mirror errors owner');
  Check(nextpas.core.system.ecPermission = nextpas.core.errors.ecPermission,
    'system ecPermission should mirror errors owner');
  Check(nextpas.core.system.ecNotFound = nextpas.core.errors.ecNotFound,
    'system ecNotFound should mirror errors owner');
  Check(nextpas.core.system.ecAlreadyExists = nextpas.core.errors.ecAlreadyExists,
    'system ecAlreadyExists should mirror errors owner');
  Check(nextpas.core.system.ecResourceExhausted = nextpas.core.errors.ecResourceExhausted,
    'system ecResourceExhausted should mirror errors owner');
  Check(nextpas.core.system.ecIO = nextpas.core.errors.ecIO,
    'system ecIO should mirror errors owner');
  Check(nextpas.core.system.ecNetwork = nextpas.core.errors.ecNetwork,
    'system ecNetwork should mirror errors owner');
  Check(nextpas.core.system.ecParse = nextpas.core.errors.ecParse,
    'system ecParse should mirror errors owner');
  Check(nextpas.core.system.ecInternal = nextpas.core.errors.ecInternal,
    'system ecInternal should mirror errors owner');

  LArgumentError := nil;
  LNullError := nil;
  LInvalidOperationError := nil;
  LNotImplementedError := nil;
  LNotSupportedError := nil;
  LTimeoutError := nil;
  LCancelledError := nil;
  LPermissionError := nil;
  LNotFoundError := nil;
  LAlreadyExistsError := nil;
  LResourceError := nil;
  LIOError := nil;
  LNetworkError := nil;
  LParseError := nil;
  LIndexError := nil;
  LOutOfMemoryError := nil;
  LOutOfMemory := nil;
  try
    LArgumentError := nextpas.core.system.EArgumentError.Create('argument');
    LNullError := nextpas.core.system.ENullReferenceError.Create('null');
    LInvalidOperationError := nextpas.core.system.EInvalidOperationError.Create('invalid operation');
    LNotImplementedError := nextpas.core.system.ENotImplementedError.Create('not implemented');
    LNotSupportedError := nextpas.core.system.ENotSupportedError.Create('not supported');
    LTimeoutError := nextpas.core.system.ETimeoutError.Create('timeout');
    LCancelledError := nextpas.core.system.ECancelledError.Create('cancelled');
    LPermissionError := nextpas.core.system.EPermissionError.Create('permission');
    LNotFoundError := nextpas.core.system.ENotFoundError.Create('not found');
    LAlreadyExistsError := nextpas.core.system.EAlreadyExistsError.Create('already exists');
    LResourceError := nextpas.core.system.EResourceExhaustedError.Create('resource');
    LIOError := nextpas.core.system.EIOError.Create('io');
    LNetworkError := nextpas.core.system.ENetworkError.Create('network');
    LParseError := nextpas.core.system.EParseError.Create('parse');
    LIndexError := nextpas.core.system.EIndexOutOfRangeError.Create('index');
    LOutOfMemoryError := nextpas.core.system.EOutOfMemoryError.Create('oom');
    LOutOfMemory := nextpas.core.system.EOutOfMemory.Create('oom short');

    Check(LArgumentError.ClassType = nextpas.core.errors.EArgumentError,
      'system EArgumentError should be canonical errors owner alias');
    Check(LArgumentError.Category = nextpas.core.errors.ecInvalidArgument,
      'system EArgumentError should preserve canonical category');
    Check(LNullError.ClassType = nextpas.core.errors.ENullReferenceError,
      'system ENullReferenceError should be canonical errors owner alias');
    Check(LNullError.Category = nextpas.core.errors.ecNullReference,
      'system ENullReferenceError should preserve canonical category');
    Check(LInvalidOperationError.ClassType = nextpas.core.errors.EInvalidOperationError,
      'system EInvalidOperationError should be canonical errors owner alias');
    Check(LInvalidOperationError.Category = nextpas.core.errors.ecInvalidOperation,
      'system EInvalidOperationError should preserve canonical category');
    Check(LNotImplementedError.ClassType = nextpas.core.errors.ENotImplementedError,
      'system ENotImplementedError should be canonical errors owner alias');
    Check(LNotSupportedError.ClassType = nextpas.core.errors.ENotSupportedError,
      'system ENotSupportedError should be canonical errors owner alias');
    Check(LTimeoutError.ClassType = nextpas.core.errors.ETimeoutError,
      'system ETimeoutError should be canonical errors owner alias');
    Check(LCancelledError.ClassType = nextpas.core.errors.ECancelledError,
      'system ECancelledError should be canonical errors owner alias');
    Check(LPermissionError.ClassType = nextpas.core.errors.EPermissionError,
      'system EPermissionError should be canonical errors owner alias');
    Check(LNotFoundError.ClassType = nextpas.core.errors.ENotFoundError,
      'system ENotFoundError should be canonical errors owner alias');
    Check(LAlreadyExistsError.ClassType = nextpas.core.errors.EAlreadyExistsError,
      'system EAlreadyExistsError should be canonical errors owner alias');
    Check(LResourceError.ClassType = nextpas.core.errors.EResourceExhaustedError,
      'system EResourceExhaustedError should be canonical errors owner alias');
    Check(LResourceError.Category = nextpas.core.errors.ecResourceExhausted,
      'system EResourceExhaustedError should preserve canonical category');
    Check(LIOError.ClassType = nextpas.core.errors.EIOError,
      'system EIOError should be canonical errors owner alias');
    Check(LNetworkError.ClassType = nextpas.core.errors.ENetworkError,
      'system ENetworkError should be canonical errors owner alias');
    Check(LParseError.ClassType = nextpas.core.errors.EParseError,
      'system EParseError should be canonical errors owner alias');
    Check(LIndexError.ClassType = nextpas.core.errors.EIndexOutOfRangeError,
      'system EIndexOutOfRangeError should be canonical errors owner alias');
    Check(LOutOfMemoryError.ClassType = nextpas.core.errors.EOutOfMemoryError,
      'system EOutOfMemoryError should be canonical errors owner alias');
    Check(LOutOfMemory.ClassType = nextpas.core.errors.EOutOfMemory,
      'system EOutOfMemory should be canonical errors owner alias');
  finally
    LOutOfMemory.Free;
    LOutOfMemoryError.Free;
    LIndexError.Free;
    LParseError.Free;
    LNetworkError.Free;
    LIOError.Free;
    LResourceError.Free;
    LAlreadyExistsError.Free;
    LNotFoundError.Free;
    LPermissionError.Free;
    LCancelledError.Free;
    LTimeoutError.Free;
    LNotSupportedError.Free;
    LNotImplementedError.Free;
    LInvalidOperationError.Free;
    LNullError.Free;
    LArgumentError.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.system facade');
  T.Run('system constants mirror base compile-truth', @TestSystemConstantsMirrorBaseCompileTruth);
  T.Run('system base carrier aliases mirror base compile-truth', @TestSystemBaseCarrierAliasesMirrorBaseCompileTruth);
  T.Run('system ABI aliases mirror compiler truth', @TestSystemAbiAliasesMirrorCompilerTruth);
  T.Run('base and system byte aliases coexist', @TestBaseAndSystemByteAliasesCoexist);
  T.Run('system memory guards delegate to base contract', @TestSystemMemoryGuardsDelegateToBaseContract);
  T.Run('copy and compare facade delegates to base utils', @TestCopyAndCompareFacadeDelegatesToBaseUtils);
  T.Run('system memory facade delegates full base utils contract', @TestSystemMemoryFacadeDelegatesFullBaseUtilsContract);
  T.Run('system FillMem delegates to base utils', @TestSystemFillMemDelegatesToBaseUtils);
  T.Run('object lifecycle helpers delegate to base utils', @TestObjectLifecycleHelpersDelegateToBaseUtils);
  T.Run('supports facade delegates object and interface queries', @TestSupportsFacadeDelegatesObjectAndInterfaceQueries);
  T.Run('system exception root is canonical', @TestSystemExceptionRootIsCanonical);
  T.Run('system base error aliases mirror base compile-truth', @TestSystemBaseErrorAliasesMirrorBaseCompileTruth);
  T.Run('errors facade catches through system root', @TestErrorsFacadeStillCatchesThroughSystemRoot);
  T.Run('system exception aliases stay canonical', @TestSystemExceptionAliasesStayCanonical);
  T.Run('system error taxonomy aliases mirror canonical owners', @TestSystemErrorTaxonomyAliasesMirrorCanonicalOwners);
  T.Summary;
end.
