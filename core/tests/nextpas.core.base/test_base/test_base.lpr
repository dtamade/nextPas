program test_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.testing;

type
  IBaseSupportsProbe = interface
    ['{6C65DA2D-5B1A-4777-8E73-02C905783F77}']
    function Value: Integer;
  end;

  IBaseSupportsOther = interface
    ['{8748F136-F298-4C32-94C2-15B89BE06A12}']
  end;

  TBaseSupportsProbe = class(TInterfacedObject, IBaseSupportsProbe)
  public
    function Value: Integer;
  end;

  TIntNullable = specialize TNullable<Integer>;
  TIntOption = specialize TOption<Integer>;
  TIntResult = specialize TResult<Integer, string>;

var
  T: TTestRunner;

function TBaseSupportsProbe.Value: Integer;
begin
  Result := 42;
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
  Check(CompareMem(@LA[0], @LB[0], 2), 'CompareMem should stay true for equal buffers');
  LB[1] := 3;
  Check(not CompareMem(@LA[0], @LB[0], 2), 'CompareMem should stay false for different buffers');
end;

procedure TestByteSpanNilAndBoundsContracts;
var
  LSpan: TByteSpan;
  LEmpty: TByteSpan;
  LOverflowSpan: TByteSpan;
begin
  LSpan := TByteSpan.Create(nil, 0);
  Check(LSpan.IsEmpty, 'TByteSpan.Create(nil, 0) should stay empty');
  Check(LSpan.Data = nil, 'empty span should keep nil data');

  LEmpty := TByteSpan.Empty.Slice(0, 0);
  Check(LEmpty.IsEmpty, 'empty span Slice(0, 0) should stay empty');

  ExpectInvalidArgumentNil(
    procedure
    begin
      TByteSpan.Create(nil, 1);
    end,
    'TByteSpan.Create(nil, >0) should raise EArgumentNil'
  );

  LOverflowSpan.Data := PByte(PtrUInt(1));
  LOverflowSpan.Len := High(SizeUInt);
  ExpectOutOfRange(
    procedure
    begin
      LOverflowSpan.Slice(High(SizeUInt), 1);
    end,
    'TByteSpan.Slice should reject offset + length overflow'
  );
end;

procedure TestHashBytesNilContracts;
begin
  CheckEqual(Int64(HashString('')), Int64(HashBytes(nil, 0)),
    'HashBytes(nil, 0) should stay the empty hash');

  ExpectInvalidArgumentNil(
    procedure
    begin
      HashBytes(nil, 1);
    end,
    'HashBytes(nil, >0) should raise EArgumentNil'
  );
end;

procedure TestSupportsClearsOutInterfaceOnFailure;
var
  LObj: TBaseSupportsProbe;
  LInstance: IInterface;
  LProbe: IBaseSupportsProbe;
  LOther: IBaseSupportsOther;
begin
  LObj := TBaseSupportsProbe.Create;
  try
    LProbe := LObj as IBaseSupportsProbe;
    Check(not Supports(TObject(nil), IBaseSupportsProbe, LProbe),
      'Supports(nil object) should return false');
    Check(LProbe = nil, 'Supports(nil object) should clear the out interface');

    LProbe := LObj as IBaseSupportsProbe;
    LOther := nil;
    Check(not Supports(LObj, IBaseSupportsOther, LOther),
      'Supports(object, unsupported interface) should return false');
    Check(LOther = nil,
      'Supports(object, unsupported interface) should clear the out interface');

    Check(Supports(LObj, IBaseSupportsProbe, LProbe),
      'Supports(object, supported interface) should return true');
    Check(LProbe <> nil,
      'Supports(object, supported interface) should assign the out interface');
    Check(LProbe.Value = 42,
      'Supports(object, supported interface) should return the requested interface');

    LInstance := LObj as IInterface;
    LProbe := LObj as IBaseSupportsProbe;
    Check(not Supports(IInterface(nil), IBaseSupportsProbe, LProbe),
      'Supports(nil interface) should return false');
    Check(LProbe = nil, 'Supports(nil interface) should clear the out interface');

    LProbe := LObj as IBaseSupportsProbe;
    LOther := nil;
    Check(not Supports(LInstance, IBaseSupportsOther, LOther),
      'Supports(interface, unsupported interface) should return false');
    Check(LOther = nil,
      'Supports(interface, unsupported interface) should clear the out interface');

    Check(Supports(LInstance, IBaseSupportsProbe, LProbe),
      'Supports(interface, supported interface) should return true');
    Check(LProbe <> nil,
      'Supports(interface, supported interface) should assign the out interface');
    Check(LProbe.Value = 42,
      'Supports(interface, supported interface) should return the requested interface');
  finally
    LProbe := nil;
    LOther := nil;
    LInstance := nil;
    LObj := nil;
  end;
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
  T.Run('copymem handles zero-size and nil', @TestCopyMemHandlesZeroSizeAndNil);
  T.Run('comparemem semantics stay stable', @TestCompareMemSemanticsStayStable);
  T.Run('bytespan nil and bounds contracts', @TestByteSpanNilAndBoundsContracts);
  T.Run('hashbytes nil contracts', @TestHashBytesNilContracts);
  T.Run('supports clears out interface on failure', @TestSupportsClearsOutInterfaceOnFailure);
  T.Run('nullable surface', @TestNullableSurface);
  T.Run('option surface', @TestOptionSurface);
  T.Run('result surface', @TestResultSurface);
  T.Summary;
end.
