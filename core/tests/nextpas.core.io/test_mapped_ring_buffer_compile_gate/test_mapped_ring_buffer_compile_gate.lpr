program test_mapped_ring_buffer_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.io.mapped.ring_buffer;

begin
  // RED gate: target unit does not exist yet
  // This will fail to compile until migration begins
end.
