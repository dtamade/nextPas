{
  nextpas.core.settings.inc
  Global compiler settings for the nextpas.core framework.
  Include this file at the top of every unit.
}

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{$IFDEF DEBUG}
  {$C+}
  {$R+}
  {$Q+}
  {$S+}
{$ENDIF}

{ Platform detection }
{$IF defined(LINUX)}
  {$DEFINE NEXTPAS_LINUX}
{$ELSEIF defined(DARWIN)}
  {$DEFINE NEXTPAS_MACOS}
{$ELSEIF defined(WINDOWS)}
  {$DEFINE NEXTPAS_WINDOWS}
{$ENDIF}

{ CPU detection }
{$IF defined(CPUX86_64)}
  {$DEFINE NEXTPAS_X86_64}
{$ELSEIF defined(CPUAARCH64)}
  {$DEFINE NEXTPAS_AARCH64}
{$ENDIF}
