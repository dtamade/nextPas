unit nextpas.core.platform.resource;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.resource.base;

type
  TPlatformResourceLimitKind = nextpas.core.platform.resource.base.TPlatformResourceLimitKind;
  TPlatformResourceLimit = nextpas.core.platform.resource.base.TPlatformResourceLimit;

function platform_resource_get_limit(
  AKind: TPlatformResourceLimitKind;
  out ALimit: TPlatformResourceLimit): Int32;
function platform_resource_set_limit(
  AKind: TPlatformResourceLimitKind;
  const ALimit: TPlatformResourceLimit): Int32;

implementation

{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID)}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi
  {$ENDIF}
  {$IFDEF NEXTPAS_ANDROID}
  , nextpas.core.platform.android.base
  {$ENDIF}
  ;

type
  TPlatformHostRLimit =
  {$IFDEF NEXTPAS_LINUX}
    TRLimit
  {$ENDIF}
  {$IFDEF NEXTPAS_ANDROID}
    TPlatformAndroidRLimit
  {$ENDIF}
  ;
{$ENDIF}

function ResourceLimitKindValid(AKind: TPlatformResourceLimitKind): Boolean;
begin
  Result := (Ord(AKind) >= Ord(Low(TPlatformResourceLimitKind))) and
    (Ord(AKind) <= Ord(High(TPlatformResourceLimitKind)));
end;

function ResourceLimitValuesValid(const ALimit: TPlatformResourceLimit): Boolean;
begin
  Result := (ALimit.Maximum = PLATFORM_RESOURCE_LIMIT_INFINITY) or
    (ALimit.Current <= ALimit.Maximum);
end;

{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID)}
function TryMapResourceLimitKind(
  AKind: TPlatformResourceLimitKind;
  out AResource: Int32): Boolean;
begin
  Result := True;
  case Ord(AKind) of
    Ord(prlkCpuTime):      AResource := RLIMIT_CPU;
    Ord(prlkFileSize):     AResource := RLIMIT_FSIZE;
    Ord(prlkDataSize):     AResource := RLIMIT_DATA;
    Ord(prlkStackSize):    AResource := RLIMIT_STACK;
    Ord(prlkCoreFileSize): AResource := RLIMIT_CORE;
    Ord(prlkOpenFiles):    AResource := RLIMIT_NOFILE;
    Ord(prlkAddressSpace): AResource := RLIMIT_AS;
    Ord(prlkLockedMemory): AResource := RLIMIT_MEMLOCK;
    Ord(prlkProcessCount): AResource := RLIMIT_NPROC;
  else
    AResource := -1;
    Result := False;
  end;
end;

procedure FillPlatformResourceLimit(
  const AHostLimit: TPlatformHostRLimit;
  out ALimit: TPlatformResourceLimit);
begin
  ALimit.Current := UInt64(AHostLimit.rlim_cur);
  ALimit.Maximum := UInt64(AHostLimit.rlim_max);
end;

procedure FillHostResourceLimit(
  const ALimit: TPlatformResourceLimit;
  out AHostLimit: TPlatformHostRLimit);
begin
  AHostLimit.rlim_cur :=
  {$IFDEF NEXTPAS_LINUX}
    rlim_t(ALimit.Current)
  {$ENDIF}
  {$IFDEF NEXTPAS_ANDROID}
    nextpas.core.platform.android.base.rlim_t(ALimit.Current)
  {$ENDIF}
  ;
  AHostLimit.rlim_max :=
  {$IFDEF NEXTPAS_LINUX}
    rlim_t(ALimit.Maximum)
  {$ENDIF}
  {$IFDEF NEXTPAS_ANDROID}
    nextpas.core.platform.android.base.rlim_t(ALimit.Maximum)
  {$ENDIF}
  ;
end;

function platform_resource_get_limit(
  AKind: TPlatformResourceLimitKind;
  out ALimit: TPlatformResourceLimit): Int32;
var
  LResource: Int32;
  LHostLimit: TPlatformHostRLimit;
begin
  FillChar(ALimit, SizeOf(ALimit), 0);
  if not TryMapResourceLimitKind(AKind, LResource) then
    Exit(PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT);

  FillChar(LHostLimit, SizeOf(LHostLimit), 0);
{$IFDEF NEXTPAS_LINUX}
  if prlimit64(0, LResource, nil, @LHostLimit) <> 0 then
    Exit(platform_get_errno);
{$ELSEIF defined(NEXTPAS_ANDROID)}
  if getrlimit(LResource, @LHostLimit) <> 0 then
    Exit(platform_get_errno);
{$ENDIF}

  FillPlatformResourceLimit(LHostLimit, ALimit);
  Result := 0;
end;

function platform_resource_set_limit(
  AKind: TPlatformResourceLimitKind;
  const ALimit: TPlatformResourceLimit): Int32;
var
  LResource: Int32;
  LHostLimit: TPlatformHostRLimit;
begin
  if not TryMapResourceLimitKind(AKind, LResource) then
    Exit(PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT);
  if not ResourceLimitValuesValid(ALimit) then
    Exit(PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT);

  FillHostResourceLimit(ALimit, LHostLimit);
{$IFDEF NEXTPAS_LINUX}
  if prlimit64(0, LResource, @LHostLimit, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
{$ELSEIF defined(NEXTPAS_ANDROID)}
  if setrlimit(LResource, @LHostLimit) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
{$ENDIF}
end;
{$ELSE}
function platform_resource_get_limit(
  AKind: TPlatformResourceLimitKind;
  out ALimit: TPlatformResourceLimit): Int32;
begin
  FillChar(ALimit, SizeOf(ALimit), 0);
  if not ResourceLimitKindValid(AKind) then
    Exit(PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT);
  Result := PLATFORM_RESOURCE_ERROR_UNSUPPORTED;
end;

function platform_resource_set_limit(
  AKind: TPlatformResourceLimitKind;
  const ALimit: TPlatformResourceLimit): Int32;
begin
  if not ResourceLimitKindValid(AKind) then
    Exit(PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT);
  if not ResourceLimitValuesValid(ALimit) then
    Exit(PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT);
  Result := PLATFORM_RESOURCE_ERROR_UNSUPPORTED;
end;
{$ENDIF}

end.
