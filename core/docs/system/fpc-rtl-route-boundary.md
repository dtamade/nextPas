# FPC RTL Route Boundary

`nextpas.core.system` is the root kernel boundary for the FPC-routed stage0
path. It is not a broad FPC compatibility library and must not become a clone of
`System`, `SysUtils`, `TypInfo`, `Classes` or platform RTL units.

The S0 source contract tracks direct `uses` of these broad FPC units:

- `SysUtils`
- `Classes`
- `TypInfo`
- `DateUtils`
- `BaseUnix`
- `Unix`
- `Windows`

Current truth is a debt baseline, not debt zero. Entries in
`fpc_broad_rtl_allowlist.txt` are retained only as named migration debt.
New direct uses outside the allowlist fail.

Policy:

- `nextpas.core.system.*` is the only place that may intentionally route FPC RTL
  kernel semantics for system contracts.
- Compiler production code must converge on `nextpas.core.system` or more
  specific `nextpas.core` owners instead of directly depending on broad FPC RTL.
- Platform, mem, text, fs, process, time, collections and TLS ownership must not
  be moved into system to satisfy this gate.
- Each future migration removes allowlist entries through a named consumer
  slice with focused verification.
