# simd.cpuinfo platform debt (F-005)

> Status: **governed allowlist** (not migrated to `platform` owner)  
> Last updated: 2026-07-26

## Why this exists

CPU feature / topology detection must touch host OS surfaces. The module lives under
`nextpas.core.simd.cpuinfo*` while the registry marks **explicit CPUInfo debt**.

## Allowlist (path → permitted platform units)

Enforced by `core/tests/nextpas.core.simd/check_math_simd_source_contracts.py`.

| Path | Allowed `nextpas.core.platform.*` |
|------|-----------------------------------|
| `simd.cpuinfo.pas` | `files`, `files.base` |
| `simd.cpuinfo.lazy.pas` | `files`, `files.base` |
| `simd.cpuinfo.arm.pas` | `files`, `files.base` |
| `simd.cpuinfo.riscv.pas` | `files`, `files.base` |
| `simd.cpuinfo.loongarch.pas` | `files`, `files.base` |
| `simd.cpuinfo.unix.pas` | `linux.base`, `posix.ffi` |
| `simd.cpuinfo.windows.pas` | `windows.base`, `windows.ffi` |
| `simd.cpuinfo.darwin.pas` | `darwin.ffi` |
| `simd.cpuinfo.diagnostic.pas` | `time` |

Any new platform import is a **failing** source-contract until this table is updated
with a design note.

## Follow-on (not this package)

Move detection ownership to `platform.cpuinfo` and leave simd with a pure
capability snapshot consumer — requires platform lane coordination.
