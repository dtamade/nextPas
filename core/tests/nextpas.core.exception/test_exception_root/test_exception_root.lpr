program test_exception_root;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.mem.error;

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
  WriteLn('PASS: all exception root tests passed');
end.
