program test_platform_linux_riscv64_compile;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time,
  nextpas.core.platform.memory,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread,
  nextpas.core.platform.io,
  nextpas.core.platform.process,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.platform.path,
  nextpas.core.platform.env,
  nextpas.core.platform.mmap,
  nextpas.core.platform.random,
  nextpas.core.platform.socket;

begin
  { Smoke test: all 13 platform modules compile for Linux riscv64 }
end.
