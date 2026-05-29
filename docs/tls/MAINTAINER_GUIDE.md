# Maintainer Guide

## Quick Reference

```bash
# Build all modules
python3 scripts/compile_all_modules.py

# Core contracts (< 5s, run every iteration)
python3 scripts/run_contracts.py --tier core

# Release contracts (< 60s, run before push)
python3 scripts/run_contracts.py --tier release

# Full local gate (< 4min)
bash scripts/run_minimal_ci_gate.sh --fast-local

# FreePascal TLS 1.3 gate
bash scripts/run_freepascal_tls13_completeness_gate.sh --fast-local

# Code style
python3 scripts/check_code_style.py src
```

## Release Process

1. Update version constants in `src/fafafa.ssl.base.pas`
2. Update `fafafa_ssl.lpk` package version
3. Update `README.md` version badge
4. Update `docs/RELEASE_NOTES.md` and `docs/BACKEND_CAPABILITY_MATRIX.md`
5. Run full verification:
   ```bash
   python3 scripts/compile_all_modules.py --rebuild
   python3 scripts/run_contracts.py --tier release
   bash scripts/run_minimal_ci_gate.sh --fast-local
   ```
6. Commit, push, create GitHub Release with tag

## Contract System

Contracts are shell scripts in `tests/scripts/` that verify documentation
and code stay aligned. They are organized in tiers:

- **Core** (13): Public API entrypoints, config boundaries, platform guidance
- **Release** (3): Version truth, release workflow, static audit
- **Full** (not yet populated): Remaining 388 scripts exist but are not yet tiered into the manifest. Run individually as needed.

Manifest: `tests/contracts.manifest.json`
Runner: `scripts/run_contracts.py`

### Adding a New Contract

1. Write the script in `tests/scripts/`
2. Add it to `tests/contracts.manifest.json` with tier, category, and what it protects
3. Run `python3 scripts/run_contracts.py --lint` to validate

### Contract Principles

- Contracts protect **security boundaries** and **public API correctness**
- Avoid fragile wording checks with no risk explanation
- Contracts that protect release/API/security truth via precise text matching are acceptable

## Architecture Overview

```
src/fafafa.ssl.pas              → Main facade (re-exports all public types)
src/fafafa.ssl.base.pas         → Core types, interfaces, enums
src/fafafa.ssl.context.builder  → Fluent builder (recommended entry)
src/fafafa.ssl.tls.pas          → Connector/Acceptor/Stream facade
src/fafafa.ssl.factory.pas      → Multi-backend factory
src/fafafa.ssl.{backend}.*      → Backend implementations
```

### Recommended User Entry Point

```pascal
uses fafafa.ssl, fafafa.ssl.context.builder;
```

Users create contexts via `TSSLContextBuilder`, connect via `TSSLConnector`.

### Backend Priority (auto-selection order)

1. WinSSL (200) — Windows only
2. MbedTLS (175) — cross-platform
3. WolfSSL (150) — cross-platform
4. OpenSSL (100) — cross-platform
5. FreePascal (50) — experimental, TLS 1.3 only

## Key Design Decisions

- `TSSLContextConfig` is the recommended config surface (not legacy `TSSLConfig`)
- `TSSLConfig` remains for v1.x compatibility but is not taught as primary
- FreePascal backend is experimental; early-data uses fail-closed replay store
- All security-sensitive operations use constant-time comparisons
- Key material is always zeroed before deallocation
