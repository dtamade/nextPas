# Progress Log: INI 修复与 XML/INI/CSV Benchmark

## Session: 2026-06-01

### Phase 1: Context + RED
- **Status:** complete
- Actions taken:
  - Loaded required workflow skills and nextPas memory constraints.
  - Checked session catchup, worktree status, and repo file layout.
  - Replaced stale planning files with this round's plan/findings/progress.
  - Read `src/nextpas.core.ini.pas` and `tests/nextpas.core.ini/test_ini/test_ini.lpr`.
  - Read XML/CSV facade files and existing benchmark examples.
  - Added duplicate parsed key regression test.
  - Verified the test failed before implementation with `expected "second", got "first"`.
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
  - `tests/nextpas.core.ini/test_ini/test_ini.lpr`

### Phase 2: INI Fix
- **Status:** complete
- Actions taken:
  - Updated `ParseLine` to reuse `FindKey` and update existing entries on duplicate parsed keys.
  - Replaced `LoadFromFile` repeated concatenation with a growable string buffer.
  - Replaced `ToString` repeated concatenation with precomputed length and direct writes.
  - Re-ran the specified INI test command; all 25 tests passed.
- Files created/modified:
  - `src/nextpas.core.ini.pas`
  - `tests/nextpas.core.ini/test_ini/test_ini.lpr`

### Phase 3: Benchmarks
- **Status:** complete
- Actions taken:
  - Added XML benchmark for 10KB config and 100KB data inputs, covering tokenizer-only and DOM+query.
  - Added Go `encoding/xml` compare benchmark for matching generated XML inputs.
  - Added INI benchmark for 50-key parse, 500-key parse, and `ReadString` lookup.
  - Added CSV benchmark for 1000x5 and 10000x5 parse inputs.
  - Smoke-compiled and smoke-ran all benchmark programs.
- Files created/modified:
  - `benchmarks/nextpas.core.xml/bench_xml/bench_xml.lpr`
  - `benchmarks/nextpas.core.xml/bench_xml/compare_go/main.go`
  - `benchmarks/nextpas.core.ini/bench_ini/bench_ini.lpr`
  - `benchmarks/nextpas.core.csv/bench_csv/bench_csv.lpr`

### Phase 4: Verification + Closeout
- **Status:** complete
- Actions taken:
  - Ran the final requested INI test command.
  - Ran the final requested XML/INI/CSV benchmark command sequence.
  - Ran Go XML comparison because Go is available.
  - Ran focused INI heaptrc check.
  - Checked git status; `build/` is ignored and pre-existing/new unrelated template/validation files remain untracked.

## Verification Evidence
| Check | Command | Result |
|-------|---------|--------|
| INI RED | `rm -rf build/lib && mkdir -p build/lib build/bin; fpc ... tests/nextpas.core.ini/test_ini/test_ini.lpr && ./build/bin/test_ini` | Failed as expected: duplicate parsed key returned `first` |
| INI GREEN | same command after implementation | `25 total, 25 passed, 0 failed` |
| Benchmark smoke compile/run | `fpc ... bench_xml.lpr`, `bench_ini.lpr`, `bench_csv.lpr`, plus binaries | All compiled and emitted benchmark rows |
| Go XML smoke | `cd benchmarks/nextpas.core.xml/bench_xml/compare_go && go run main.go` | Go available; emitted benchmark rows |
| Final command sequence | User-provided INI test + XML/INI/CSV benchmark + Go compare commands | exit 0 |
| INI heaptrc | `fpc -MObjFPC -Sh -O1 -gh ... test_ini.lpr && ./build/bin/test_ini` | `25 total, 25 passed, 0 failed`; `0 unfreed memory blocks` |

## Test Results
| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| Duplicate parsed INI key | Last parsed value wins; one key remains | Red before fix, green after fix | pass |

## Final Benchmark Results
| Benchmark | ns/op |
|-----------|-------|
| XML tokenize 10KB config | 601804.7 |
| XML tokenize 100KB data | 6093018.9 |
| XML DOM+query 10KB config | 835574.6 |
| XML DOM+query 100KB data | 8562913.7 |
| INI parse 1KB / 50 keys | 86261.4 |
| INI parse 10KB / 500 keys | 6869804.7 |
| INI ReadString key499 | 24874.3 |
| CSV parse 10KB / 1000x5 | 622393.9 |
| CSV parse 100KB / 10000x5 | 6528267.7 |
| Go xml tokenize 10KB config | 783636.1 |
| Go xml tokenize 100KB data | 8347527.4 |
| Go xml unmarshal 10KB config | 1553418.8 |
| Go xml unmarshal 100KB data | 13645205.2 |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
