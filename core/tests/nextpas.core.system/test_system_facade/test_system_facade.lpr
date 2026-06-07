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
  public
    constructor Create(ATarget: PObjectRef; ADestroyCount: PIntegerRef);
    destructor Destroy; override;
  end;

var
  T: TTestRunner;

function TSystemFacadeProbe.Value: Integer;
begin
  Result := 42;
end;

constructor TDestructorProbe.Create(ATarget: PObjectRef; ADestroyCount: PIntegerRef);
begin
  inherited Create;
  FTarget := ATarget;
  FDestroyCount := ADestroyCount;
end;

destructor TDestructorProbe.Destroy;
begin
  Inc(FDestroyCount^);
  Check(FTarget^ = nil, 'system FreeAndNil should nil the reference before destructor execution');
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
  Check(nextpas.core.system.CompareMem(nil, nil, 1),
    'system CompareMem should preserve base nil/nil true semantics');
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

procedure TestObjectLifecycleHelpersDelegateToBaseUtils;
var
  LObject: TObject;
  LDestroyCount: Integer;
begin
  LDestroyCount := 0;
  LObject := TDestructorProbe.Create(@LObject, @LDestroyCount);
  nextpas.core.system.FreeAndNil(LObject);
  Check(LObject = nil, 'system FreeAndNil should nil the object reference');
  CheckEqual(Int64(1), Int64(LDestroyCount), 'system FreeAndNil should destroy the object once');

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

begin
  T := TTestRunner.Create('nextpas.core.system facade');
  T.Run('base and system byte aliases coexist', @TestBaseAndSystemByteAliasesCoexist);
  T.Run('system memory guards delegate to base contract', @TestSystemMemoryGuardsDelegateToBaseContract);
  T.Run('copy and compare facade delegates to base utils', @TestCopyAndCompareFacadeDelegatesToBaseUtils);
  T.Run('object lifecycle helpers delegate to base utils', @TestObjectLifecycleHelpersDelegateToBaseUtils);
  T.Run('supports facade delegates object and interface queries', @TestSupportsFacadeDelegatesObjectAndInterfaceQueries);
  T.Run('system exception root is canonical', @TestSystemExceptionRootIsCanonical);
  T.Run('errors facade catches through system root', @TestErrorsFacadeStillCatchesThroughSystemRoot);
  T.Run('system exception aliases stay canonical', @TestSystemExceptionAliasesStayCanonical);
  T.Summary;
end.
