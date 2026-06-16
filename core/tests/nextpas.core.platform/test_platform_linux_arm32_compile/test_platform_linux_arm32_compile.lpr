program test_platform_linux_arm32_compile;

{*
 * Cross-compile gate for Linux arm32 (ARMv7 hard-float) target.
 *
 * DOCUMENTED GAP (2026-06-16):
 *   FPC arm cross-compiler (ppcrossarm) is not installed in this CI
 *   environment. This test verifies source-level compatibility only when
 *   the cross-compiler becomes available.
 *
 * To enable:
 *   1. Install arm cross-compiler: fpcupdeluxe --only=arm-linux
 *   2. Ensure units at: /opt/fpcupdeluxe/fpc/units/arm-linux/
 *   3. Run: make -C test_platform_linux_arm32_compile test
 *
 * QEMU runtime gate requires:
 *   apt install qemu-user libc6-dev-armhf-cross
 *}

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
  { Smoke test: all 13 platform modules compile for Linux arm32 }
end.
