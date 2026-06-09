program test_exception_root;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.mem.error;

type
  TTrackedInnerError = class(SysUtils.Exception)
  private
    FFreedFlag: PBoolean;
  public
    constructor Create(const AMessage: string; const AFreedFlag: PBoolean);
    destructor Destroy; override;
  end;

procedure Check(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise SysUtils.Exception.Create(AMessage);
end;

constructor TTrackedInnerError.Create(const AMessage: string;
  const AFreedFlag: PBoolean);
begin
  inherited Create(AMessage);
  FFreedFlag := AFreedFlag;
  if FFreedFlag <> nil then
    FFreedFlag^ := False;
end;

destructor TTrackedInnerError.Destroy;
begin
  if FFreedFlag <> nil then
    FFreedFlag^ := True;
  inherited;
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

procedure TestAllocResultOutOfMemoryCatchesAsPublicOutOfMemory;
var
  LAlloc: TAllocResult;
  LCaught: Boolean;
begin
  LCaught := False;
  LAlloc := TAllocResult.Err(aeOutOfMemory);
  try
    LAlloc.ExpectPtr('allocation contract');
  except
    on E: nextpas.core.errors.EOutOfMemoryError do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;
  Check(LCaught, 'TAllocResult out-of-memory must catch as public OOM root');
end;

procedure TestAllocOutOfMemoryUsesCanonicalCatchBeforeAllocRoot;
var
  LAlloc: TAllocResult;
  LSeen: string;
begin
  LSeen := '';
  LAlloc := TAllocResult.Err(aeOutOfMemory);
  try
    LAlloc.ExpectPtr('allocation contract');
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

procedure CheckFormattedCategory(const AError: nextpas.core.exception.ENextPasError;
  const AExpectedMessage: string; const AExpectedCategory: nextpas.core.exception.TErrorCategory;
  const AContext: string);
begin
  try
    Check(AError.Message = AExpectedMessage, AContext + ' must format the message');
    Check(AError.Category = AExpectedCategory, AContext + ' must keep default category');
    Check(AError.Inner = nil, AContext + ' must not attach an inner exception');
  finally
    AError.Free;
  end;
end;

procedure TestTypedCreateFmtKeepsDefaultCategory;
begin
  CheckFormattedCategory(
    nextpas.core.exception.EArgumentError.CreateFmt('argument %d', [1]),
    'argument 1', nextpas.core.exception.ecInvalidArgument, 'EArgumentError.CreateFmt');
  CheckFormattedCategory(
    nextpas.core.exception.ETimeoutError.CreateFmt('timeout %d', [2]),
    'timeout 2', nextpas.core.exception.ecTimeout, 'ETimeoutError.CreateFmt');
  CheckFormattedCategory(
    nextpas.core.exception.EIOError.CreateFmt('io %d', [3]),
    'io 3', nextpas.core.exception.ecIO, 'EIOError.CreateFmt');
  CheckFormattedCategory(
    nextpas.core.exception.EParseError.CreateFmt('parse %d', [4]),
    'parse 4', nextpas.core.exception.ecParse, 'EParseError.CreateFmt');
end;

procedure TestWrapperMessageDoesNotLeakInnerMessage;
var
  LInner: SysUtils.Exception;
  LOuter: nextpas.core.exception.ENextPasError;
begin
  LInner := SysUtils.Exception.Create('inner secret token');
  LOuter := nextpas.core.exception.ENextPasError.Create('outer public message',
    nextpas.core.exception.ecInternal, LInner);
  try
    Check(LOuter.Message = 'outer public message',
      'outer message must not concatenate inner exception message');
    Check(LOuter.Inner = LInner, 'outer wrapper must retain inner exception reference');
  finally
    LOuter.Free;
  end;
end;

procedure TestCreateFmtWrapperKeepsOuterMessageOnly;
var
  LInner: SysUtils.Exception;
  LOuter: nextpas.core.exception.ENextPasError;
begin
  LInner := SysUtils.Exception.Create('inner secret token');
  LOuter := nextpas.core.exception.ENextPasError.CreateFmt('outer %d',
    nextpas.core.exception.ecNetwork, [9], LInner);
  try
    Check(LOuter.Message = 'outer 9',
      'ENextPasError.CreateFmt wrapper must format only the outer message');
    Check(LOuter.Category = nextpas.core.exception.ecNetwork,
      'ENextPasError.CreateFmt wrapper must keep explicit category');
    Check(LOuter.Inner = LInner,
      'ENextPasError.CreateFmt wrapper must retain inner exception reference');
    Check(Pos('inner secret token', LOuter.Message) = 0,
      'ENextPasError.CreateFmt wrapper must not leak inner exception message');
  finally
    LOuter.Free;
  end;
end;

procedure TestCreateFmtFormatFailureReleasesOwnedInner;
var
  LDestroyed: Boolean;
begin
  LDestroyed := False;
  try
    nextpas.core.exception.ENextPasError.CreateFmt('%d',
      nextpas.core.exception.ecInternal, ['not an integer'],
      TTrackedInnerError.Create('inner secret token', @LDestroyed));
  except
    on E: SysUtils.Exception do
      begin
        Check(LDestroyed,
          'ENextPasError.CreateFmt must release owned inner when Format raises');
        Exit;
      end;
  end;
  Check(False, 'ENextPasError.CreateFmt must propagate Format errors');
end;

procedure TestInnerOwnershipAndMessageLeakageContract;
var
  LInnerFreed: Boolean;
  LNonOwnedFreed: Boolean;
  LInner: TTrackedInnerError;
  LWrapped: nextpas.core.exception.ENextPasError;
begin
  LInnerFreed := False;
  LInner := TTrackedInnerError.Create('secret-token-123', @LInnerFreed);
  LWrapped := nextpas.core.exception.ENextPasError.Create(
    'outer failure', nextpas.core.exception.ecInternal, LInner, True);
  try
    Check(LWrapped.Inner = LInner, 'owned wrapper must expose the inner exception');
    Check(LWrapped.OwnsInner, 'owned wrapper must expose owns-inner truth');
    Check(LWrapped.Message = 'outer failure',
      'outer message must not concatenate the inner message');
    Check(Pos('secret-token-123', LWrapped.Message) = 0,
      'outer message must not leak sensitive inner details');
  finally
    LWrapped.Free;
  end;
  Check(LInnerFreed, 'owned inner exception must be released with the wrapper');

  LNonOwnedFreed := False;
  LInner := TTrackedInnerError.Create('non-owned-secret', @LNonOwnedFreed);
  try
    LWrapped := nextpas.core.exception.ENextPasError.Create(
      'outer only', nextpas.core.exception.ecInternal, LInner, False);
    try
      Check(LWrapped.Inner = LInner,
        'non-owned wrapper must expose the inner exception');
      Check(not LWrapped.OwnsInner,
        'non-owned wrapper must expose owns-inner false');
      Check(Pos('non-owned-secret', LWrapped.Message) = 0,
        'non-owned wrapper message must not leak inner details');
    finally
      LWrapped.Free;
    end;
    Check(not LNonOwnedFreed,
      'non-owned inner exception must survive wrapper destruction');
  finally
    LInner.Free;
  end;
  Check(LNonOwnedFreed, 'test must release the non-owned inner exception');
end;

begin
  WriteLn('=== nextpas.core.exception root tests ===');
  TestBaseExceptionsCatchAsUnifiedRoot;
  TestTimeoutHasOnePublicRuntimeType;
  TestLegacyECoreCatchesCanonicalAliases;
  TestOutOfMemoryCompatibilityCatchesAsPublicRoot;
  TestAllocErrorCatchesAsUnifiedRoot;
  TestAllocResultOutOfMemoryCatchesAsPublicOutOfMemory;
  TestAllocOutOfMemoryUsesCanonicalCatchBeforeAllocRoot;
  TestMemOutOfMemoryKeepsConstructorCompatibility;
  TestOutOfMemoryCreateFmtKeepsResourceExhaustedCategory;
  TestTypedCreateFmtKeepsDefaultCategory;
  TestWrapperMessageDoesNotLeakInnerMessage;
  TestCreateFmtWrapperKeepsOuterMessageOnly;
  TestCreateFmtFormatFailureReleasesOwnedInner;
  TestInnerOwnershipAndMessageLeakageContract;
  WriteLn('PASS: all exception root tests passed');
end.
