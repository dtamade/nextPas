# Stale PPU Rebuild Hazard

## Problem

Free Pascal can reuse existing `.ppu` files when they look newer than the
corresponding source files. A compiler rebuild that only compiles the root
program can therefore leave the `nextpas` binary backed by stale units.

This can make compiler smoke results look valid while they are actually running
against an old binary.

## Symptom

A suspicious rebuild compiles only the main program, for example roughly:

```text
481 lines compiled
```

A real full compiler rebuild should recompile the compiler units and produce a
much larger compile count, for example `15000+ lines compiled` depending on the
current source tree.

## Required Practice

After changing compiler sources, rebuild through:

```bash
scripts/rebuild-compiler.sh
```

Do not treat a compiler verification run as fresh unless the rebuild step
actually invalidated stale units and rebuilt the compiler implementation.

## Why It Matters

Running smoke tests against a stale compiler binary can produce false pass
counts and can hide regressions introduced in the current source tree. Compiler
owners should treat low-line-count rebuild output as a verification failure, not
as a successful rebuild.
