# nextPas Core Framework Goal Tree

This goal tree tracks evidence, not optimism. Do not use plain "complete" for a
module unless the row also names the evidence tier that supports the claim.

## Position

nextPas Core is moving from module-by-module feature growth to architecture
governance hardening. The current control vocabulary is:

- `source-contract`: source/static guards lock a boundary or public claim.
- `forced-compile`: a host or facade path compiles under an explicit target gate.
- `focused-runtime`: focused runtime tests cover named behavior on a host.
- `CI matrix`: repeated CI proof across the named host/arch matrix.

## Layer map

| Layer | Module families | Required proof before stronger claims |
| --- | --- | --- |
| L0 | `base`, `errors`, `platform`, `mem`, `system`, `atomic`, `math`, `simd`, `log.intf` | source-contract for owner boundaries; focused runtime for public behavior; CI matrix for host truth |
| L1 | `bytes`, `text`, `encoding`, `collections`, `sync`, `thread`, `lockfree`, `async`, `io`, `time`, `id`, `testing`, `stopwatch` | source-contract for public facade/dependencies; focused runtime for each public API group |
| L2 | `fs`, `net`, `process`, `args`, `json`, `toml`, `yaml`, `compress`, `regex`, `hash`, `crypto`, `tls` | forced compile for host/backend seams; focused runtime for behavior; no backend readiness claim without runtime evidence |
| L3 | `log`, `config`, `http`, `websocket`, `tui`, `event`, `coroutine`, `template` | consumer contracts, focused runtime, leak proof for lifecycle paths |

## Current evidence

| Area | Current truth | Required next proof |
| --- | --- | --- |
| L0 owner boundary | source-contract gate being hardened for `base/errors/platform/mem/system/atomic/math/simd` | shrink explicit debt allowlists to zero where the module is meant to stay L0 |
| Platform | Linux has focused runtime; Windows/macOS/Android evidence is mixed source-contract and forced-compile | platform runtime truth matrix by host and feature |
| Mem | public allocator/pool paths have focused runtime; L0 dependency debt remains explicit | mem L0 debt zero lane |
| System | source-contract and focused runtime exist for root/facade slices; final facade is not closed | system final facade plan and consumer compile matrix |
| Math/SIMD | focused runtime exists for many APIs; SIMD public cutover and host matrix are not final | source-contract guards plus runtime matrix before performance claims |
| TLS/Crypto | public and backend docs/tests exist, but backend truth is mixed | TLS master spec with backend truth tiers |
| HTTP/TUI/Config | focused runtime exists for many slices | keep consumer contracts aligned with lower-layer owner boundaries |

## Governance gates

| Gate | Scope | Required before Ready |
| --- | --- | --- |
| module registry | layer, owner, facade, dependency policy, truth level | registry row updated for changed module family |
| dependency boundary audit | L0 upward dependency ban plus explicit debt | no unknown violations |
| host raw FFI audit | raw host unit use outside owner/allowlist | no unknown violations |
| focused runtime | changed public API/lifecycle path | test output and heaptrc evidence when runtime path is touched |
| hygiene | build artifact and source tree hygiene | `make hygiene` passes |

## Next priorities

1. TLS master spec and backend truth table.
2. System final facade and compatibility pressure matrix.
3. Mem L0 debt zero.
4. Platform runtime truth matrix.
5. Benchmarks only after source-contract and runtime truth are stable.
