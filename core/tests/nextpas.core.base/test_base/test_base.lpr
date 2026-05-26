program test_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base;

begin
  WriteLn('=== nextpas.core.base tests ===');

  Assert(NEXTPAS_CORE_VERSION = '0.1.0', 'Version mismatch');
  Assert(NEXTPAS_CORE_VERSION_MAJOR = 0);
  Assert(NEXTPAS_CORE_VERSION_MINOR = 1);
  Assert(NEXTPAS_CORE_VERSION_PATCH = 0);
  Assert(NEXTPAS_CORE_NAME = 'nextpas.core');

  WriteLn('PASS: all base tests passed');
end.
