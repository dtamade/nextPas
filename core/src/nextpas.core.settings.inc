{
  nextpas.core.settings.inc
  Global compiler settings for the nextpas.core framework.
  Include this file at the top of every unit.
}

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{$IFOPT O+}
  {$DEFINE FAFAFA_CORE_INLINE}
{$ENDIF}

{$DEFINE FAFAFA_CORE_ANONYMOUS_REFERENCES}
{$DEFINE FAFAFA_CORE_CONTRACTS}

{$IFDEF DEBUG}
  {$C+}
  {$R+}
  {$Q+}
  {$S+}
{$ENDIF}

{ Platform detection }
{$IF defined(WINDOWS)}
  {$DEFINE NEXTPAS_WINDOWS}
{$ELSEIF defined(ANDROID)}
  {$DEFINE NEXTPAS_ANDROID}
  {$DEFINE NEXTPAS_UNIX}
{$ELSEIF defined(DARWIN)}
  {$DEFINE NEXTPAS_MACOS}
  {$DEFINE NEXTPAS_UNIX}
{$ELSEIF defined(LINUX)}
  {$DEFINE NEXTPAS_LINUX}
  {$DEFINE NEXTPAS_UNIX}
{$ELSEIF defined(FREEBSD)}
  {$DEFINE NEXTPAS_FREEBSD}
  {$DEFINE NEXTPAS_UNIX}
{$ELSEIF defined(UNIX)}
  {$DEFINE NEXTPAS_UNIX}
{$ENDIF}

{ CPU detection }
{$IF defined(CPUX86_64)}
  {$DEFINE NEXTPAS_X86_64}
{$ELSEIF defined(CPUAARCH64)}
  {$DEFINE NEXTPAS_AARCH64}
{$ENDIF}
