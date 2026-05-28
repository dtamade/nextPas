{ Linux riscv64 syscall numbers - ported from FPC rtl/linux/riscv64/sysnr.inc }
{ Includes generic (aarch64-compatible) table plus RISC-V specific syscalls }

{$I nextpas.core.platform.linux.base.syscall.generic.inc}

const
  syscall_nr_riscv_hwprobe      = 258;
  syscall_nr_riscv_flush_icache = 259;
