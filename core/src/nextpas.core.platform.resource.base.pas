unit nextpas.core.platform.resource.base;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 系统资源限制类型枚举 *}
  TPlatformResourceLimitKind = (
    prlkCpuTime,
    prlkFileSize,
    prlkDataSize,
    prlkStackSize,
    prlkCoreFileSize,
    prlkOpenFiles,
    prlkAddressSpace,
    prlkLockedMemory,
    prlkProcessCount
  );

  {** @desc 系统资源限制值 *}
  TPlatformResourceLimit = record
    Current: UInt64;
    Maximum: UInt64;
    {** @desc 检查当前限制是否为无限制
        @return True 如果当前限制为无限制 *}
    function IsCurrentUnlimited: Boolean; inline;
    {** @desc 检查最大限制是否为无限制
        @return True 如果最大限制为无限制 *}
    function IsMaximumUnlimited: Boolean; inline;
    {** @desc 检查是否完全无限制（当前和最大均为无限制）
        @return True 如果完全无限制 *}
    function IsUnlimited: Boolean; inline;
    {** @desc 检查是否有限制（当前或最大不为无限制）
        @return True 如果有限制 *}
    function IsLimited: Boolean; inline;
  end;

const
  {** @desc 无限制（RLIM_INFINITY） *}
  PLATFORM_RESOURCE_LIMIT_INFINITY = High(UInt64);

  {** @desc 不支持的操作错误码 *}
  {$IFDEF NEXTPAS_WINDOWS}
  PLATFORM_RESOURCE_ERROR_UNSUPPORTED = Int32(50);
  PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT = Int32(87);
  {$ELSEIF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  PLATFORM_RESOURCE_ERROR_UNSUPPORTED = Int32(45);
  PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT = Int32(22);
  {$ELSE}
  PLATFORM_RESOURCE_ERROR_UNSUPPORTED = Int32(95);
  PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT = Int32(22);
  {$ENDIF}

implementation

function TPlatformResourceLimit.IsCurrentUnlimited: Boolean;
begin
  Result := Current = PLATFORM_RESOURCE_LIMIT_INFINITY;
end;

function TPlatformResourceLimit.IsMaximumUnlimited: Boolean;
begin
  Result := Maximum = PLATFORM_RESOURCE_LIMIT_INFINITY;
end;

function TPlatformResourceLimit.IsUnlimited: Boolean;
begin
  Result := (Current = PLATFORM_RESOURCE_LIMIT_INFINITY) and
            (Maximum = PLATFORM_RESOURCE_LIMIT_INFINITY);
end;

function TPlatformResourceLimit.IsLimited: Boolean;
begin
  Result := (Current <> PLATFORM_RESOURCE_LIMIT_INFINITY) or
            (Maximum <> PLATFORM_RESOURCE_LIMIT_INFINITY);
end;

end.
