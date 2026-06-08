# Mem Secure-Zero Platform Owner Review

Status: `Needs Review`

## Decision under review

`nextpas.core.mem.secure` still owns raw host secure-zero behavior directly:

- Windows path uses `Windows`, `GetModuleHandle`, `GetProcAddress`,
  `RtlSecureZeroMemory`, and `InterlockedExchange`.
- Non-Windows path uses `BaseUnix` plus local architecture barriers.

This keeps host API ownership inside the L0 mem lane. The proposed seam is a
platform-owned facade:

```pascal
procedure platform_secure_zero_memory(Buffer: Pointer; Size: SizeUInt);
```

`mem.secure` would keep its public compatibility wrappers and delegate the raw
backend to `nextpas.core.platform.memory`.

## Source contract

This package adds a minimal RED compile gate:

```sh
make -C core/tests/nextpas.core.platform.memory/test_platform_memory_secure_zero_compile_gate test
```

Expected current result: compile failure because
`platform_secure_zero_memory` is not exported by `nextpas.core.platform.memory`.

## L0 dependency impact

- Current mem L0 debt count remains `6`.
- A later implementation slice should remove the `mem.secure.pas|Windows` and
  `mem.secure.pas|BaseUnix` allowlist entries only after `mem.secure` delegates
  to the platform-owned facade.
- This package does not modify `mem.secure` and does not change allocator,
  mapping, or shared-memory policy.

## Next slice if approved

1. Implement the minimal platform facade in `nextpas.core.platform.memory`.
2. Add focused platform runtime coverage for nil, zero-size, and writable buffer
   zeroing behavior.
3. Switch `mem.secure` to delegate through the platform facade.
4. Tighten the mem L0 allowlist for the secure-zero host units.
5. Run platform.memory, mem secure/consumer gates, mem L0 boundary, heaptrc,
   `git diff --check`, and `make hygiene`.
