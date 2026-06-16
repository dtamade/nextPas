program probe_static_avx2_usable;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}
{$R-}{$Q-}

uses
  nextpas.core.simd.cpuinfo;

begin
  if not HasAVX2 then
  begin
    WriteLn('[STATIC-AVX2-MISALIGNMENT] SKIP: host does not expose usable AVX2');
    Halt(77);
  end;

  WriteLn('[STATIC-AVX2-MISALIGNMENT] host exposes usable AVX2');
end.
