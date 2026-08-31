unit nextpas.core.platform.base;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 操作系统类型枚举 *}
  TOSKind = (
    osLinux,
    osMacOS,
    osWindows,
    osAndroid,
    osFreeBSD,
    osUnix,
    osUnknown
  );

  {** @desc CPU 架构枚举 *}
  TCPUArch = (
    cpuX86_64,
    cpuAArch64,
    cpuARM32,
    cpuRISCV64,
    cpuUnknown
  );

  {** @desc 字节序枚举 *}
  TEndianness = (
    endLittle,
    endBig
  );

const
  {** @desc 当前操作系统类型（编译时确定） *}
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

  {** @desc 当前 CPU 架构（编译时确定） *}
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

  {** @desc 当前字节序（编译时确定, target-aware via NEXTPAS_BIG_ENDIAN） *}
  {$IF DEFINED(NEXTPAS_BIG_ENDIAN)}
  CURRENT_ENDIAN = endBig;
  {$ELSE}
  CURRENT_ENDIAN = endLittle;
  {$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
  {** @desc 路径分隔符（Windows: \，Unix: /） *}
  PLATFORM_PATH_DELIM = '\';
  {** @desc 路径列表分隔符（Windows: ;，Unix: :） *}
  PLATFORM_PATH_SEP = ';';
  {** @desc 行尾符号（Windows: CRLF，Unix: LF） *}
  PLATFORM_LINE_ENDING = #13#10;
{$ELSE}
  PLATFORM_PATH_DELIM = '/';
  PLATFORM_PATH_SEP = ':';
  PLATFORM_LINE_ENDING = #10;
{$ENDIF}
  {** @desc 扩展名分隔符 *}
  PLATFORM_EXT_SEP = '.';

implementation

end.
