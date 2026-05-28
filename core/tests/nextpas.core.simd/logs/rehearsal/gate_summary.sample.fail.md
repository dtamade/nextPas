| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Debug; wiring=1; coverage=0; perf=0 | logs/build.txt; logs/test.txt; logs/wiring_sync.txt |
| 2026-02-10 00:00:01 | build-check | PASS | 6200 | NORMAL | build/check/parity passed | logs/build.txt |
| 2026-02-10 00:00:02 | wiring-sync | PASS | 180 | NORMAL | legacy=116 grouped=116 missing=0 extra=0 markers_missing=0 strict_extra=1 | logs/wiring_sync.txt; logs/wiring_sync.json |
| 2026-02-10 00:00:03 | cpuinfo-x86 | FAIL | 1333 | FAILED | rc=1; cpuinfo x86 suite failed; cmd=gate_step_cpuinfo_x86 /mock/tests | tests/nextpas.core.simd.cpuinfo.x86/logs/test.txt |
| 2026-02-10 00:00:04 | gate | FAIL | 9800 | FAILED | failed-step=cpuinfo-x86 | - |
