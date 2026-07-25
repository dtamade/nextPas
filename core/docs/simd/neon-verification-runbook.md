# NEON verification runbook (F-010)

## Preferred (AArch64 host)

```bash
make -C core/tests/nextpas.core.simd neon-optin-focused
```

Record: host, FPC flags, pass count.

## Optional QEMU (when configured)

```bash
# requires qemu-aarch64 user-mode + cross FPC unit set for target
make -C core/tests/nextpas.core.simd neon-optin-focused
# or project-specific qemu wrapper if present under scripts/
```

## Lane default

Linux x86_64 focused gate does **not** prove NEON asm leaves. Last recorded
neon-optin count lives in README/MAINTENANCE when re-run.
