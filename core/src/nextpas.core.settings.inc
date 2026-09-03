{
  nextpas.core.settings.inc
  Global compiler settings for the nextpas.core framework.
  Include this file at the top of every unit.
}

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
{$GOTO ON}
{$WARN 6058 off} // inline 例程无法内联的提示性 Note，非缺陷（统一豁免，供调试用 profiling 而非编译噪声）
{$WARN 3123 off} // 含 open-array / assembler 的 inline 例程无法内联的提示性 Note，非缺陷（统一豁免）

{-- PACKRECORDS C dual compiler stub --}
{ FPC: PACKRECORDS C is C ABI packing. nextPas: same syntax supported natively (0.3+); variant record overlay (id/Bytes/AsNative at offset 0) is standard Pascal, binary guarantee via Assert(SizeOf=20) in git.libgit2.base. No IFDEF in modules, stub closed via settings.inc include chain. }

{$IFOPT O+}
  {$DEFINE NEXTPAS_CORE_INLINE}
{$ENDIF}

{$DEFINE NEXTPAS_CORE_ANONYMOUS_REFERENCES}
{$DEFINE NEXTPAS_CORE_CONTRACTS}

{ Temporary compatibility for copied modules not migrated yet. }
{$IFDEF NEXTPAS_CORE_INLINE}
  {$DEFINE NEXTPAS_CORE_INLINE}
{$ENDIF}
{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  {$DEFINE NEXTPAS_CORE_ANONYMOUS_REFERENCES}
{$ENDIF}
{$IFDEF NEXTPAS_CORE_CONTRACTS}
  {$DEFINE NEXTPAS_CORE_CONTRACTS}
{$ENDIF}

{$IFDEF DEBUG}
  {$C+}
  {$R+}
  {$Q+}
  {$S+}
{$ENDIF}

{-- Arena leak check --}
{.$DEFINE NEXTPAS_ARENA_LEAK_CHECK}  // 默认关闭，手动开启

{ Platform detection }
{$IF defined(NEXTPAS_FORCE_HOST_WINDOWS)}
  {$DEFINE NEXTPAS_WINDOWS}
{$ELSEIF defined(NEXTPAS_FORCE_HOST_ANDROID)}
  {$DEFINE NEXTPAS_ANDROID}
  {$DEFINE NEXTPAS_UNIX}
  {$DEFINE NEXTPAS_POSIX_CLOCK}
{$ELSEIF defined(NEXTPAS_FORCE_HOST_DARWIN)}
  {$DEFINE NEXTPAS_MACOS}
  {$DEFINE NEXTPAS_UNIX}
{$ELSEIF defined(NEXTPAS_FORCE_HOST_LINUX)}
  {$DEFINE NEXTPAS_LINUX}
  {$DEFINE NEXTPAS_UNIX}
  {$DEFINE NEXTPAS_POSIX_CLOCK}
{$ELSEIF defined(NEXTPAS_FORCE_HOST_FREEBSD)}
  {$DEFINE NEXTPAS_FREEBSD}
  {$DEFINE NEXTPAS_UNIX}
  {$DEFINE NEXTPAS_POSIX_CLOCK}
{$ELSEIF defined(NEXTPAS_FORCE_HOST_UNIX)}
  {$DEFINE NEXTPAS_UNIX}
  {$DEFINE NEXTPAS_POSIX_CLOCK}
{$ELSEIF defined(WINDOWS)}
  {$DEFINE NEXTPAS_WINDOWS}
{$ELSEIF defined(ANDROID)}
  {$DEFINE NEXTPAS_ANDROID}
  {$DEFINE NEXTPAS_UNIX}
  {$DEFINE NEXTPAS_POSIX_CLOCK}
{$ELSEIF defined(DARWIN)}
  {$DEFINE NEXTPAS_MACOS}
  {$DEFINE NEXTPAS_UNIX}
{$ELSEIF defined(LINUX)}
  {$DEFINE NEXTPAS_LINUX}
  {$DEFINE NEXTPAS_UNIX}
  {$DEFINE NEXTPAS_POSIX_CLOCK}
{$ELSEIF defined(FREEBSD)}
  {$DEFINE NEXTPAS_FREEBSD}
  {$DEFINE NEXTPAS_UNIX}
  {$DEFINE NEXTPAS_POSIX_CLOCK}
{$ELSEIF defined(UNIX)}
  {$DEFINE NEXTPAS_UNIX}
  {$DEFINE NEXTPAS_POSIX_CLOCK}
{$ENDIF}

{ CPU detection }
{$IF defined(CPUX86_64)}
  {$DEFINE NEXTPAS_X86_64}
{$ELSEIF defined(CPUAARCH64)}
  {$DEFINE NEXTPAS_AARCH64}
{$ELSEIF defined(CPURISCV64)}
  {$DEFINE NEXTPAS_RISCV64}
{$ELSEIF defined(CPU386)}
  {$DEFINE NEXTPAS_I386}
{$ELSEIF defined(CPUARM)}
  {$DEFINE NEXTPAS_ARM}
{$ENDIF}

{ Endian detection - cross-compile stable via NEXTPAS_BIG_ENDIAN; allow target override }
{$IF defined(NEXTPAS_FORCE_BIG_ENDIAN) or defined(NEXTPAS_FORCE_HOST_BIG_ENDIAN)}
  {$DEFINE NEXTPAS_BIG_ENDIAN}
{$ELSEIF defined(FPC_BIG_ENDIAN)}
  {$DEFINE NEXTPAS_BIG_ENDIAN}
{$ENDIF}

{-- bytes.ops single source unified sentinel --}
{ All String/Bytes zero-copy (BytesToString/StringToBytes/SpanClone etc.) single source is nextpas.core.bytes.ops (BYTES_OPS_SINGLE_SOURCE).
  Per-unit DB_*_BYTES_SINGLE_SOURCE aliases retired (factory/pool/migrate 7 units); central gate via this inc (owner=bytes.ops, L0).
  Units reuse bytes.ops via inline thin forward + single Move zero-copy; drift via BYTES_OPS_SINGLE_SOURCE sentinel (compile-time). }
{$DEFINE NEXTPAS_BYTES_OPS_SINGLE_SOURCE_UNIFIED}
