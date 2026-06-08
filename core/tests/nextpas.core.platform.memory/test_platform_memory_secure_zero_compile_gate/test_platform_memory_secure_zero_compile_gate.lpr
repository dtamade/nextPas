program test_platform_memory_secure_zero_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.memory;

var
  LBuffer: array[0..31] of Byte;

begin
  platform_secure_zero_memory(@LBuffer[0], SizeOf(LBuffer));
  platform_secure_zero_memory(nil, 0);
end.
