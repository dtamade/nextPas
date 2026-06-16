program test_exception_root;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.mem.error;

type
  TNextPasErrorClass = class of nextpas.core.exception.ENextPasError;

  TTrackedInnerException = class(SysUtils.Exception)
  public
    destructor Destroy; override;
  end;

var
  GTrackedInnerDestroyCount: Integer;

destructor TTrackedInnerException.Destroy;
begin
  Inc(GTrackedInnerDestroyCount);
  inherited;
end;

procedure Check(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise SysUtils.Exception.Create(AMessage);
end;

procedure TestBaseExceptionsCatchAsUnifiedRoot;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise nextpas.core.base.EArgumentNil.Create('argument is nil');
  except
    on E: nextpas.core.exception.ENextPasError do
      LCaught := True;
  end;
  Check(LCaught, 'ECore-derived exceptions must catch as ENextPasError');
end;

procedure TestTimeoutHasOnePublicRuntimeType;
var
  LBaseTimeout: SysUtils.Exception;
  LErrorsTimeout: SysUtils.Exception;
begin
  LBaseTimeout := nextpas.core.base.ETimeoutError.Create('base timeout');
  try
    LErrorsTimeout := nextpas.core.errors.ETimeoutError.Create('errors timeout');
    try
      Check(LBaseTimeout.ClassType = LErrorsTimeout.ClassType,
        'base/errors ETimeoutError must have the same runtime class');
      Check(LBaseTimeout is nextpas.core.exception.ETimeoutError,
        'base ETimeoutError must use the canonical timeout type');
      Check(LErrorsTimeout is nextpas.core.exception.ETimeoutError,
        'errors ETimeoutError must use the canonical timeout type');
    finally
      LErrorsTimeout.Free;
    end;
  finally
    LBaseTimeout.Free;
  end;
end;

procedure TestLegacyECoreCatchesCanonicalAliases;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise nextpas.core.base.ETimeoutError.Create('base timeout');
  except
    on E: nextpas.core.base.ECore do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;
  Check(LCaught, 'legacy ECore catch must catch base ETimeoutError alias');

  LCaught := False;
  try
    raise nextpas.core.errors.ETimeoutError.Create('errors timeout');
  except
    on E: nextpas.core.base.ECore do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;
  Check(LCaught, 'legacy ECore catch must catch errors ETimeoutError alias');

  LCaught := False;
  try
    raise nextpas.core.base.EOutOfMemory.Create('base oom');
  except
    on E: nextpas.core.base.ECore do
      LCaught := E is nextpas.core.errors.EOutOfMemoryError;
  end;
  Check(LCaught, 'legacy ECore catch must catch base EOutOfMemory alias');

  LCaught := False;
  try
    raise nextpas.core.errors.EOutOfMemoryError.Create('errors oom');
  except
    on E: nextpas.core.base.ECore do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;
  Check(LCaught, 'legacy ECore catch must catch errors EOutOfMemoryError');
end;

procedure TestOutOfMemoryCompatibilityCatchesAsPublicRoot;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise nextpas.core.base.EOutOfMemory.Create('allocation failed');
  except
    on E: nextpas.core.errors.EOutOfMemoryError do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;
  Check(LCaught, 'EOutOfMemory must catch as EOutOfMemoryError and ENextPasError');
end;

procedure TestAllocErrorCatchesAsUnifiedRoot;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise nextpas.core.mem.error.EAllocError.Create(aeInvalidLayout, 'invalid layout');
  except
    on E: nextpas.core.exception.ENextPasError do
      LCaught := True;
  end;
  Check(LCaught, 'EAllocError must catch as ENextPasError');
end;

procedure TestMemOutOfMemoryCatchesAsPublicOutOfMemory;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise nextpas.core.mem.error.EOutOfMemory.Create(aeOutOfMemory, 'allocation contract');
  except
    on E: nextpas.core.errors.EOutOfMemoryError do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;
  Check(LCaught, 'mem EOutOfMemory must catch as public OOM root');
end;

procedure TestMemOutOfMemoryUsesCanonicalCatchBeforeAllocRoot;
var
  LSeen: string;
begin
  LSeen := '';
  try
    raise nextpas.core.mem.error.EOutOfMemory.Create(aeOutOfMemory, 'allocation contract');
  except
    on E: nextpas.core.mem.error.EAllocError do
      LSeen := 'alloc';
    on E: nextpas.core.errors.EOutOfMemoryError do
      LSeen := 'oom';
  end;
  Check(LSeen = 'oom',
    'allocation OOM must use the canonical OOM catch contract, not EAllocError');
end;

procedure TestMemOutOfMemoryKeepsConstructorCompatibility;
var
  LErr: nextpas.core.mem.error.EOutOfMemory;
begin
  LErr := nextpas.core.mem.error.EOutOfMemory.Create(aeOutOfMemory, 'allocation contract');
  try
    Check(LErr.Error = aeOutOfMemory,
      'mem EOutOfMemory must preserve the TAllocError detail code');
    Check(LErr is nextpas.core.errors.EOutOfMemoryError,
      'mem EOutOfMemory must catch as the public OOM root');
    Check(LErr.Category = nextpas.core.exception.ecResourceExhausted,
      'mem EOutOfMemory must keep resource-exhausted category');
  finally
    LErr.Free;
  end;
end;

procedure TestOutOfMemoryCreateFmtKeepsResourceExhaustedCategory;
var
  LCanonical: nextpas.core.exception.EOutOfMemoryError;
  LCompat: nextpas.core.exception.EOutOfMemory;
begin
  LCanonical := nextpas.core.exception.EOutOfMemoryError.CreateFmt(
    'canonical oom %d', [42]);
  try
    Check(LCanonical.Message = 'canonical oom 42',
      'EOutOfMemoryError.CreateFmt must format the message');
    Check(LCanonical.Category = nextpas.core.exception.ecResourceExhausted,
      'EOutOfMemoryError.CreateFmt must keep resource-exhausted category');
  finally
    LCanonical.Free;
  end;

  LCompat := nextpas.core.exception.EOutOfMemory.CreateFmt(
    'compat oom %d', [7]);
  try
    Check(LCompat.Message = 'compat oom 7',
      'EOutOfMemory.CreateFmt must format the message');
    Check(LCompat.Category = nextpas.core.exception.ecResourceExhausted,
      'EOutOfMemory.CreateFmt must keep resource-exhausted category');
  finally
    LCompat.Free;
  end;
end;

procedure TestRootCreateFmtKeepsExplicitCategory;
var
  LErr: nextpas.core.exception.ENextPasError;
begin
  LErr := nextpas.core.exception.ENextPasError.CreateFmt(
    'plain code %d', [12]);
  try
    Check(LErr.Message = 'plain code 12',
      'ENextPasError.CreateFmt must keep inherited message-only format constructor');
    Check(LErr.Category = nextpas.core.exception.ecNone,
      'ENextPasError.CreateFmt without explicit category must keep ecNone');
  finally
    LErr.Free;
  end;

  LErr := nextpas.core.exception.ENextPasError.CreateFmt(
    'network code %d', nextpas.core.exception.ecNetwork, [54]);
  try
    Check(LErr.Message = 'network code 54',
      'ENextPasError.CreateFmt must format explicit-category messages');
    Check(LErr.Category = nextpas.core.exception.ecNetwork,
      'ENextPasError.CreateFmt must keep explicit category');
  finally
    LErr.Free;
  end;
end;

procedure TestRootCreateFmtKeepsInnerOwnershipContract;
var
  LInner: TTrackedInnerException;
  LErr: nextpas.core.exception.ENextPasError;
begin
  GTrackedInnerDestroyCount := 0;
  LInner := TTrackedInnerException.Create('password=secret-token');
  LErr := nextpas.core.exception.ENextPasError.CreateFmt(
    'outer failure %d', nextpas.core.exception.ecNetwork, [99], LInner, True);
  try
    Check(LErr.Message = 'outer failure 99',
      'ENextPasError.CreateFmt with inner must format the outer message');
    Check(Pos('secret-token', LErr.Message) = 0,
      'ENextPasError.CreateFmt must not append inner sensitive data to outer message');
    Check(LErr.Category = nextpas.core.exception.ecNetwork,
      'ENextPasError.CreateFmt with inner must keep explicit category');
    Check(LErr.Inner = LInner,
      'ENextPasError.CreateFmt with inner must keep the inner exception pointer');
  finally
    LErr.Free;
  end;
  Check(GTrackedInnerDestroyCount = 1,
    'owned inner exception must be freed when ENextPasError is freed');

  GTrackedInnerDestroyCount := 0;
  LInner := TTrackedInnerException.Create('token=caller-owned');
  LErr := nextpas.core.exception.ENextPasError.CreateFmt(
    'outer non-owning %d', nextpas.core.exception.ecIO, [7], LInner, False);
  try
    Check(LErr.Message = 'outer non-owning 7',
      'non-owning ENextPasError.CreateFmt must format the outer message');
    Check(LErr.Category = nextpas.core.exception.ecIO,
      'non-owning ENextPasError.CreateFmt must keep explicit category');
    Check(LErr.Inner = LInner,
      'non-owning ENextPasError.CreateFmt must keep the inner exception pointer');
  finally
    LErr.Free;
  end;
  Check(GTrackedInnerDestroyCount = 0,
    'non-owned inner exception must not be freed by ENextPasError');
  LInner.Free;
  Check(GTrackedInnerDestroyCount = 1,
    'caller must still be able to free a non-owned inner exception');
end;

procedure TestRootCreateFmtFormatFailureFreesOwnedInner;
var
  LInner: TTrackedInnerException;
  LCaught: Boolean;
begin
  GTrackedInnerDestroyCount := 0;
  LInner := TTrackedInnerException.Create('password=format-failure-secret');
  LCaught := False;
  try
    nextpas.core.exception.ENextPasError.CreateFmt(
      'bad format %d %d', nextpas.core.exception.ecInternal, [1], LInner, True);
  except
    on E: SysUtils.EConvertError do
      LCaught := True;
  end;
  Check(LCaught,
    'ENextPasError.CreateFmt should surface the format failure');
  Check(GTrackedInnerDestroyCount = 1,
    'owned inner exception must be freed when ENextPasError.CreateFmt fails before construction');

  GTrackedInnerDestroyCount := 0;
  LInner := TTrackedInnerException.Create('token=caller-owned-format-failure');
  LCaught := False;
  try
    nextpas.core.exception.ENextPasError.CreateFmt(
      'bad format %d %d', nextpas.core.exception.ecInternal, [1], LInner, False);
  except
    on E: SysUtils.EConvertError do
      LCaught := True;
  end;
  Check(LCaught,
    'non-owned ENextPasError.CreateFmt should surface the format failure');
  Check(GTrackedInnerDestroyCount = 0,
    'non-owned inner exception must remain caller-owned when ENextPasError.CreateFmt fails');
  LInner.Free;
  Check(GTrackedInnerDestroyCount = 1,
    'caller must still be able to free non-owned inner after ENextPasError.CreateFmt failure');
end;

procedure CheckCategoryText(const ACategory: nextpas.core.exception.TErrorCategory;
  const AExpected: string);
begin
  Check(nextpas.core.exception.ErrorCategoryToString(ACategory) = AExpected,
    'ErrorCategoryToString must return ' + AExpected);
end;

procedure TestErrorCategoryToStringUsesStableTokens;
var
  LInner: TTrackedInnerException;
  LErr: nextpas.core.exception.ENextPasError;
  LToken: string;
begin
  CheckCategoryText(nextpas.core.exception.ecNone, 'none');
  CheckCategoryText(nextpas.core.exception.ecInvalidArgument, 'invalid_argument');
  CheckCategoryText(nextpas.core.exception.ecNullReference, 'null_reference');
  CheckCategoryText(nextpas.core.exception.ecInvalidOperation, 'invalid_operation');
  CheckCategoryText(nextpas.core.exception.ecNotImplemented, 'not_implemented');
  CheckCategoryText(nextpas.core.exception.ecNotSupported, 'not_supported');
  CheckCategoryText(nextpas.core.exception.ecTimeout, 'timeout');
  CheckCategoryText(nextpas.core.exception.ecCancelled, 'cancelled');
  CheckCategoryText(nextpas.core.exception.ecInterrupted, 'interrupted');
  CheckCategoryText(nextpas.core.exception.ecWouldBlock, 'would_block');
  CheckCategoryText(nextpas.core.exception.ecPermission, 'permission');
  CheckCategoryText(nextpas.core.exception.ecNotFound, 'not_found');
  CheckCategoryText(nextpas.core.exception.ecAlreadyExists, 'already_exists');
  CheckCategoryText(nextpas.core.exception.ecResourceExhausted, 'resource_exhausted');
  CheckCategoryText(nextpas.core.exception.ecIO, 'io');
  CheckCategoryText(nextpas.core.exception.ecNetwork, 'network');
  CheckCategoryText(nextpas.core.exception.ecParse, 'parse');
  CheckCategoryText(nextpas.core.exception.ecInternal, 'internal');

  LInner := TTrackedInnerException.Create('password=secret-token');
  LErr := nextpas.core.exception.ENextPasError.Create(
    'outer secret token', nextpas.core.exception.ecNetwork, LInner, True);
  try
    LToken := nextpas.core.exception.ErrorCategoryToString(LErr.Category);
    Check(LToken = 'network',
      'ErrorCategoryToString must classify by category');
    Check(Pos('secret', LToken) = 0,
      'ErrorCategoryToString must not include sensitive inner message data');
    Check(Pos('outer', LToken) = 0,
      'ErrorCategoryToString must not include outer message data');
  finally
    LErr.Free;
  end;
end;

procedure TestUnknownExplicitCategoryFallsBackToInternal;
var
  LErr: nextpas.core.exception.ENextPasError;
  LUnknown: nextpas.core.exception.TErrorCategory;
  LUnknownOrdinal: Integer;
begin
  LUnknownOrdinal := Ord(High(nextpas.core.exception.TErrorCategory));
  Inc(LUnknownOrdinal);
  LUnknown := nextpas.core.exception.TErrorCategory(LUnknownOrdinal);

  LErr := nextpas.core.exception.ENextPasError.Create('unknown category', LUnknown);
  try
    Check(LErr.Category = nextpas.core.exception.ecInternal,
      'unknown explicit root category must normalize to ecInternal');
    Check(nextpas.core.exception.ErrorCategoryToString(LErr.Category) = 'internal',
      'unknown explicit root category must publish the internal token');
  finally
    LErr.Free;
  end;
end;

procedure TestSpecificInnerConstructorsKeepSubclassCategory;
var
  LInner: TTrackedInnerException;
  LErr: nextpas.core.exception.ENextPasError;
begin
  GTrackedInnerDestroyCount := 0;
  LInner := TTrackedInnerException.Create('password=timeout-secret');
  LErr := nextpas.core.exception.ETimeoutError.Create('outer timeout', LInner, False);
  try
    Check(LErr.Message = 'outer timeout',
      'specific inner constructor must keep the outer message');
    Check(Pos('timeout-secret', LErr.Message) = 0,
      'specific inner constructor must not append inner sensitive data');
    Check(LErr.Category = nextpas.core.exception.ecTimeout,
      'ETimeoutError inner constructor must keep timeout category');
    Check(LErr.Inner = LInner,
      'specific inner constructor must keep the inner exception pointer');
  finally
    LErr.Free;
  end;
  Check(GTrackedInnerDestroyCount = 0,
    'non-owned specific inner exception must not be freed by ENextPasError');
  LInner.Free;
  Check(GTrackedInnerDestroyCount = 1,
    'caller must still be able to free a non-owned specific inner exception');

  GTrackedInnerDestroyCount := 0;
  LInner := TTrackedInnerException.Create('token=io-secret');
  LErr := nextpas.core.exception.EIOError.Create('outer io', LInner, True);
  try
    Check(LErr.Message = 'outer io',
      'owned specific inner constructor must keep the outer message');
    Check(Pos('io-secret', LErr.Message) = 0,
      'owned specific inner constructor must not append inner sensitive data');
    Check(LErr.Category = nextpas.core.exception.ecIO,
      'EIOError inner constructor must keep IO category');
    Check(LErr.Inner = LInner,
      'owned specific inner constructor must keep the inner exception pointer');
  finally
    LErr.Free;
  end;
  Check(GTrackedInnerDestroyCount = 1,
    'owned specific inner exception must be freed when ENextPasError is freed');
end;

procedure TestSpecificLeavesRejectMismatchedExplicitCategory;
var
  LInner: TTrackedInnerException;
  LErr: nextpas.core.exception.ENextPasError;
begin
  LErr := nextpas.core.exception.ETimeoutError.Create(
    'timeout typed as io', nextpas.core.exception.ecIO);
  try
    Check(LErr.Category = nextpas.core.exception.ecTimeout,
      'ETimeoutError explicit-category constructor must keep timeout category');
  finally
    LErr.Free;
  end;

  LErr := nextpas.core.exception.EIOError.CreateFmt(
    'io typed as network %d', nextpas.core.exception.ecNetwork, [11]);
  try
    Check(LErr.Message = 'io typed as network 11',
      'EIOError explicit-category CreateFmt must still format the message');
    Check(LErr.Category = nextpas.core.exception.ecIO,
      'EIOError explicit-category CreateFmt must keep IO category');
  finally
    LErr.Free;
  end;

  GTrackedInnerDestroyCount := 0;
  LInner := TTrackedInnerException.Create('password=leaf-secret');
  LErr := nextpas.core.exception.EParseError.Create(
    'parse typed as internal', nextpas.core.exception.ecInternal, LInner, True);
  try
    Check(LErr.Message = 'parse typed as internal',
      'EParseError explicit-category inner constructor must keep outer message');
    Check(Pos('leaf-secret', LErr.Message) = 0,
      'EParseError explicit-category inner constructor must not append inner sensitive data');
    Check(LErr.Category = nextpas.core.exception.ecParse,
      'EParseError explicit-category inner constructor must keep parse category');
    Check(LErr.Inner = LInner,
      'EParseError explicit-category inner constructor must keep inner pointer');
  finally
    LErr.Free;
  end;
  Check(GTrackedInnerDestroyCount = 1,
    'owned explicit-category leaf inner exception must be freed');
end;

procedure CheckLeafDefaultCategory(const AName: string;
  const AClass: TNextPasErrorClass;
  const ACategory: nextpas.core.exception.TErrorCategory);
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise AClass.Create(AName + ' default category');
  except
    on E: nextpas.core.exception.ENextPasError do
    begin
      LCaught := True;
      Check(E.ClassType = AClass,
        AName + ' class reference must create the requested public leaf');
      Check(E.Category = ACategory,
        AName + ' public leaf must keep its default category');
    end;
  end;
  Check(LCaught,
    AName + ' public leaf must catch as ENextPasError');
end;

procedure TestAllLeafDefaultCategories;
begin
  CheckLeafDefaultCategory('EArgumentError',
    nextpas.core.exception.EArgumentError,
    nextpas.core.exception.ecInvalidArgument);
  CheckLeafDefaultCategory('ENullReferenceError',
    nextpas.core.exception.ENullReferenceError,
    nextpas.core.exception.ecNullReference);
  CheckLeafDefaultCategory('EInvalidOperationError',
    nextpas.core.exception.EInvalidOperationError,
    nextpas.core.exception.ecInvalidOperation);
  CheckLeafDefaultCategory('ENotImplementedError',
    nextpas.core.exception.ENotImplementedError,
    nextpas.core.exception.ecNotImplemented);
  CheckLeafDefaultCategory('ENotSupportedError',
    nextpas.core.exception.ENotSupportedError,
    nextpas.core.exception.ecNotSupported);
  CheckLeafDefaultCategory('ETimeoutError',
    nextpas.core.exception.ETimeoutError,
    nextpas.core.exception.ecTimeout);
  CheckLeafDefaultCategory('ECancelledError',
    nextpas.core.exception.ECancelledError,
    nextpas.core.exception.ecCancelled);
  CheckLeafDefaultCategory('EInterruptedError',
    nextpas.core.exception.EInterruptedError,
    nextpas.core.exception.ecInterrupted);
  CheckLeafDefaultCategory('EWouldBlockError',
    nextpas.core.exception.EWouldBlockError,
    nextpas.core.exception.ecWouldBlock);
  CheckLeafDefaultCategory('EPermissionError',
    nextpas.core.exception.EPermissionError,
    nextpas.core.exception.ecPermission);
  CheckLeafDefaultCategory('ENotFoundError',
    nextpas.core.exception.ENotFoundError,
    nextpas.core.exception.ecNotFound);
  CheckLeafDefaultCategory('EAlreadyExistsError',
    nextpas.core.exception.EAlreadyExistsError,
    nextpas.core.exception.ecAlreadyExists);
  CheckLeafDefaultCategory('EResourceExhaustedError',
    nextpas.core.exception.EResourceExhaustedError,
    nextpas.core.exception.ecResourceExhausted);
  CheckLeafDefaultCategory('EIOError',
    nextpas.core.exception.EIOError,
    nextpas.core.exception.ecIO);
  CheckLeafDefaultCategory('ENetworkError',
    nextpas.core.exception.ENetworkError,
    nextpas.core.exception.ecNetwork);
  CheckLeafDefaultCategory('EParseError',
    nextpas.core.exception.EParseError,
    nextpas.core.exception.ecParse);
  CheckLeafDefaultCategory('EIndexOutOfRangeError',
    nextpas.core.exception.EIndexOutOfRangeError,
    nextpas.core.exception.ecInvalidArgument);
  CheckLeafDefaultCategory('EOutOfMemoryError',
    nextpas.core.exception.EOutOfMemoryError,
    nextpas.core.exception.ecResourceExhausted);
  CheckLeafDefaultCategory('EOutOfMemory',
    nextpas.core.exception.EOutOfMemory,
    nextpas.core.exception.ecResourceExhausted);
end;

procedure CheckLeafInnerConstructorKeepsDefaultCategory(const AName: string;
  const AClass: TNextPasErrorClass;
  const ACategory: nextpas.core.exception.TErrorCategory);
var
  LInner: TTrackedInnerException;
  LSecret: string;
begin
  GTrackedInnerDestroyCount := 0;
  LSecret := AName + '-inner-secret-token';
  LInner := TTrackedInnerException.Create(LSecret);
  try
    raise AClass.Create(AName + ' outer message',
      nextpas.core.exception.ecInternal, LInner, True);
  except
    on E: nextpas.core.exception.ENextPasError do
    begin
      Check(E.ClassType = AClass,
        AName + ' inner constructor must create the requested public leaf');
      Check(E.Category = ACategory,
        AName + ' inner constructor must keep the leaf default category');
      Check(E.Inner = LInner,
        AName + ' inner constructor must keep the inner pointer');
      Check(Pos(LSecret, E.Message) = 0,
        AName + ' inner constructor must not leak inner sensitive data');
    end;
  end;
  Check(GTrackedInnerDestroyCount = 1,
    AName + ' owned inner exception must be freed after the leaf is handled');
end;

procedure TestAllLeafInnerConstructorsKeepDefaultCategory;
begin
  CheckLeafInnerConstructorKeepsDefaultCategory('EArgumentError',
    nextpas.core.exception.EArgumentError,
    nextpas.core.exception.ecInvalidArgument);
  CheckLeafInnerConstructorKeepsDefaultCategory('ENullReferenceError',
    nextpas.core.exception.ENullReferenceError,
    nextpas.core.exception.ecNullReference);
  CheckLeafInnerConstructorKeepsDefaultCategory('EInvalidOperationError',
    nextpas.core.exception.EInvalidOperationError,
    nextpas.core.exception.ecInvalidOperation);
  CheckLeafInnerConstructorKeepsDefaultCategory('ENotImplementedError',
    nextpas.core.exception.ENotImplementedError,
    nextpas.core.exception.ecNotImplemented);
  CheckLeafInnerConstructorKeepsDefaultCategory('ENotSupportedError',
    nextpas.core.exception.ENotSupportedError,
    nextpas.core.exception.ecNotSupported);
  CheckLeafInnerConstructorKeepsDefaultCategory('ETimeoutError',
    nextpas.core.exception.ETimeoutError,
    nextpas.core.exception.ecTimeout);
  CheckLeafInnerConstructorKeepsDefaultCategory('ECancelledError',
    nextpas.core.exception.ECancelledError,
    nextpas.core.exception.ecCancelled);
  CheckLeafInnerConstructorKeepsDefaultCategory('EInterruptedError',
    nextpas.core.exception.EInterruptedError,
    nextpas.core.exception.ecInterrupted);
  CheckLeafInnerConstructorKeepsDefaultCategory('EWouldBlockError',
    nextpas.core.exception.EWouldBlockError,
    nextpas.core.exception.ecWouldBlock);
  CheckLeafInnerConstructorKeepsDefaultCategory('EPermissionError',
    nextpas.core.exception.EPermissionError,
    nextpas.core.exception.ecPermission);
  CheckLeafInnerConstructorKeepsDefaultCategory('ENotFoundError',
    nextpas.core.exception.ENotFoundError,
    nextpas.core.exception.ecNotFound);
  CheckLeafInnerConstructorKeepsDefaultCategory('EAlreadyExistsError',
    nextpas.core.exception.EAlreadyExistsError,
    nextpas.core.exception.ecAlreadyExists);
  CheckLeafInnerConstructorKeepsDefaultCategory('EResourceExhaustedError',
    nextpas.core.exception.EResourceExhaustedError,
    nextpas.core.exception.ecResourceExhausted);
  CheckLeafInnerConstructorKeepsDefaultCategory('EIOError',
    nextpas.core.exception.EIOError,
    nextpas.core.exception.ecIO);
  CheckLeafInnerConstructorKeepsDefaultCategory('ENetworkError',
    nextpas.core.exception.ENetworkError,
    nextpas.core.exception.ecNetwork);
  CheckLeafInnerConstructorKeepsDefaultCategory('EParseError',
    nextpas.core.exception.EParseError,
    nextpas.core.exception.ecParse);
  CheckLeafInnerConstructorKeepsDefaultCategory('EIndexOutOfRangeError',
    nextpas.core.exception.EIndexOutOfRangeError,
    nextpas.core.exception.ecInvalidArgument);
  CheckLeafInnerConstructorKeepsDefaultCategory('EOutOfMemoryError',
    nextpas.core.exception.EOutOfMemoryError,
    nextpas.core.exception.ecResourceExhausted);
  CheckLeafInnerConstructorKeepsDefaultCategory('EOutOfMemory',
    nextpas.core.exception.EOutOfMemory,
    nextpas.core.exception.ecResourceExhausted);
end;

begin
  WriteLn('=== nextpas.core.exception root tests ===');
  TestBaseExceptionsCatchAsUnifiedRoot;
  TestTimeoutHasOnePublicRuntimeType;
  TestLegacyECoreCatchesCanonicalAliases;
  TestOutOfMemoryCompatibilityCatchesAsPublicRoot;
  TestAllocErrorCatchesAsUnifiedRoot;
  TestMemOutOfMemoryCatchesAsPublicOutOfMemory;
  TestMemOutOfMemoryUsesCanonicalCatchBeforeAllocRoot;
  TestMemOutOfMemoryKeepsConstructorCompatibility;
  TestOutOfMemoryCreateFmtKeepsResourceExhaustedCategory;
  TestRootCreateFmtKeepsExplicitCategory;
  TestRootCreateFmtKeepsInnerOwnershipContract;
  TestRootCreateFmtFormatFailureFreesOwnedInner;
  TestErrorCategoryToStringUsesStableTokens;
  TestUnknownExplicitCategoryFallsBackToInternal;
  TestSpecificInnerConstructorsKeepSubclassCategory;
  TestSpecificLeavesRejectMismatchedExplicitCategory;
  TestAllLeafDefaultCategories;
  TestAllLeafInnerConstructorsKeepDefaultCategory;
  WriteLn('PASS: all exception root tests passed');
end.
