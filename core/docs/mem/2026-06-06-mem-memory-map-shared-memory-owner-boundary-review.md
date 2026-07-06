# Mem Memory-Map / Shared-Memory Owner Boundary Review

## Status

- `Needs Review`

## Active lane goal

Decide the owner boundary for `memory_map` and `shared-memory` semantics before
the next mem boundary cleanup slice starts. This note restores the active `mem`
lane goal after the accepted `22efa6ae` landing-candidate batch.

## Current truth

- `22efa6ae` (`fix(mem): harden l0 boundary helper surface`) is accepted for
  landing-candidate handling only.
- `mem` remains active. Do not report the lane as complete, and do not report
  the L0 boundary as cleaned.
- `core/src/nextpas.core.os.env.pas` is an allowed cross-module touched file in
  the accepted slice because it is the minimal blocker fix for
  `memory_map` Windows compile truth.
- `nextpas.core.mem.memory_map` no longer depends on `fs.util` or `text.conv`
  for local helpers, but raw mapping and shared-memory ownership still cross the
  `mem` and `platform` boundary.

## Review question

Which owner boundary is correct for mapping and shared-memory behavior?

1. Move host mapping and shared-memory semantics behind a platform-owned facade.
2. Reclassify part of the current `memory_map` surface so `mem` stops claiming
   it as L0-clean allocation core behavior.

## Comparison frame

### Option A: Platform-owned facade

- Keep anonymous mapping-backed allocator support in `mem`.
- Move file/shared-memory host calls and OS-shape semantics behind
  `nextpas.core.platform.*` ownership.
- Prefer this route if mapping semantics are treated as host capability first
  and allocator backend second.

### Option B: Reclassify capability outside L0 mem

- Keep only honest allocation primitives in `mem`.
- Move file/shared-memory mapping surface out of the L0 `mem` core if it cannot
  satisfy the owner-boundary rule without stretching `platform` in the wrong
  direction.
- Prefer this route if the shared-memory API is fundamentally broader than an
  allocator-support concern.

## Review scope

- `core/src/nextpas.core.mem.memory_map.pas`
- `core/src/nextpas.core.mem.allocator.memory_map_allocator.pas`
- `core/src/nextpas.core.platform.mmap.pas`
- `core/src/nextpas.core.os.env.pas`
- `core/tests/nextpas.core.mem/test_memory_map_compile_gate/`
- `core/tests/nextpas.core.mem/test_l0_dependency_boundaries/`

## Exit criteria

- Pick the owner boundary direction explicitly.
- Name the minimal file set for the next implementation slice.
- State whether the next slice is mem-only or controlled cross-module.
- Keep file/shared mapping expansion out of the allocator convergence batch
  until the owner-boundary decision is settled.

## Not this slice

- Do not raw-merge `codex/core-mem`.
- Do not reopen `compiler/**`.
- Do not claim `mem` goal complete.
- Do not claim the L0 boundary is clean.
