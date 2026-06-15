program test_platform_linux_aarch64_compile;

{*
 * Cross-compile gate for Linux aarch64 target.
 *
 * DOCUMENTED GAP (2026-06-16):
 *   FPC aarch64 cross-compiler (ppcrossa64) is not installed in this CI
 *   environment. This test verifies source-level compatibility only when
 *   the cross-compiler becomes available.
 *
 * To enable:
 *   1. Install aarch64 cross-compiler: fpcupdeluxe --only=aarch64-linux
 *   2. Ensure units at: /opt/fpcupdeluxe/fpc/units/aarch64-linux/
 *   3. Run: make -C test_platform_linux_aarch64_compile test
 *
 * QEMU runtime gate requires:
 *   apt install qemu-user libc6-dev-arm64-cross
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
  { Smoke test: all 13 platform modules compile for Linux aarch64 }
end.
