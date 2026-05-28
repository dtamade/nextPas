unit nextpas.core.platform.base;

{$I nextpas.core.settings.inc}

interface

type
  TOSKind = (
    osLinux,
    osMacOS,
    osWindows,
    osAndroid,
    osFreeBSD,
    osUnix,
    osUnknown
  );

  TCPUArch = (
    cpuX86_64,
    cpuAArch64,
    cpuARM32,
    cpuRISCV64,
    cpuUnknown
  );

  TEndianness = (
    endLittle,
    endBig
  );

const
  {$IF defined(NEXTPAS_LINUX)}
  CURRENT_OS: TOSKind = osLinux;
  {$ELSEIF defined(NEXTPAS_MACOS)}
  CURRENT_OS: TOSKind = osMacOS;
  {$ELSEIF defined(NEXTPAS_WINDOWS)}
  CURRENT_OS: TOSKind = osWindows;
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  CURRENT_OS: TOSKind = osAndroid;
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  CURRENT_OS: TOSKind = osFreeBSD;
  {$ELSEIF defined(NEXTPAS_UNIX)}
  CURRENT_OS: TOSKind = osUnix;
  {$ELSE}
  CURRENT_OS: TOSKind = osUnknown;
  {$ENDIF}

  {$IF defined(NEXTPAS_X86_64)}
  CURRENT_CPU: TCPUArch = cpuX86_64;
  {$ELSEIF defined(NEXTPAS_AARCH64)}
  CURRENT_CPU: TCPUArch = cpuAArch64;
  {$ELSEIF defined(NEXTPAS_ARM)}
  CURRENT_CPU: TCPUArch = cpuARM32;
  {$ELSEIF defined(NEXTPAS_RISCV64)}
  CURRENT_CPU: TCPUArch = cpuRISCV64;
  {$ELSE}
  CURRENT_CPU: TCPUArch = cpuUnknown;
  {$ENDIF}

  CURRENT_ENDIAN: TEndianness = endLittle;

{$IFDEF NEXTPAS_WINDOWS}
  PLATFORM_PATH_DELIM = '\';
  PLATFORM_PATH_SEP = ';';
  PLATFORM_LINE_ENDING = #13#10;
{$ELSE}
  PLATFORM_PATH_DELIM = '/';
  PLATFORM_PATH_SEP = ':';
  PLATFORM_LINE_ENDING = #10;
{$ENDIF}
  PLATFORM_EXT_SEP = '.';

implementation

end.
