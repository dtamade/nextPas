program test_platform_memory_secure_zero_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.memory;

var
  LBuffer: array[0..31] of Byte;

begin
  if platform_secure_zero_memory_backend <> pszbFallbackFillCharBarrier then
    Halt(1);
  if platform_secure_zero_memory_is_native then
    Halt(1);

  platform_secure_zero_memory(@LBuffer[0], SizeOf(LBuffer));
  platform_secure_zero_memory(nil, 0);
end.
