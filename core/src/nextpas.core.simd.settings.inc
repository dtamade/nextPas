{
  nextpas.core.simd.settings.inc
  SIMD module local settings. Include after nextpas.core.settings.inc.
}

{$IFDEF CPUX86_64}
  {$ASMMODE INTEL}
{$ENDIF}
{$IFDEF CPUI386}
  {$ASMMODE INTEL}
{$ENDIF}
