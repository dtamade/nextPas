unit nextpas.core.platform.base;

{$I nextpas.core.settings.inc}

interface

type
  TOSKind = (
    osLinux,
    osMacOS,
    osWindows,
    osAndroid,
    osUnix,
    osUnknown
  );

  TCPUArch = (
    cpuX86_64,
    cpuAArch64,
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
  {$ELSEIF defined(NEXTPAS_UNIX)}
  CURRENT_OS: TOSKind = osUnix;
  {$ELSE}
  CURRENT_OS: TOSKind = osUnknown;
  {$ENDIF}

  {$IF defined(NEXTPAS_X86_64)}
  CURRENT_CPU: TCPUArch = cpuX86_64;
  {$ELSEIF defined(NEXTPAS_AARCH64)}
  CURRENT_CPU: TCPUArch = cpuAArch64;
  {$ELSE}
  CURRENT_CPU: TCPUArch = cpuUnknown;
  {$ENDIF}

  CURRENT_ENDIAN: TEndianness = endLittle;

implementation

end.
