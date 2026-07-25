# platform.process — behavior vs test map (F-017)

Minimal inventory. Gaps are honest; not a commitment to fill every row this program.

| Behavior | Primary test / evidence | Notes |
|----------|-------------------------|-------|
| spawn + wait | `test_platform_process` | Linux focused-runtime |
| stdin/stdout/stderr `*_ex` | `test_platform_process` | Prefer over deprecated length APIs |
| pipe helpers | process suite + `platform.pipe` | dual-IO not used in `process.pipe` |
| timeout wait | process suite | |
| kill / signal | process + signal suites | Windows Job Object path in process |
| NewProcessGroup / KillTree (Windows) | Windows ci-matrix process gate | Job Object |
| wine smoke | `test_platform_process_wine` | secondary |
| ExtraFd / credentials | **gap** | document when consumers need |
| dual-IO `platform_io_*` | owner-only; no expand | F5/D3.c permanent |

Expand rows only with consumer pain + focused gates.
