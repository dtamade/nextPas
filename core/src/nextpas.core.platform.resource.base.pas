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

end.
