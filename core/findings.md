# Findings & Decisions

## Requirements
- Review `src/nextpas.core.log.pas` and `src/nextpas.core.log.intf.pas`.
- Focus on the ring buffer, `TLogEvent` finalization, `TFileHandler`, `TJsonHandler`, `TConsoleHandler`, context cloning APIs, `NextEventSlot`, `InterlockedIncrement`, default logger initialization, and missing `slog`-style APIs.
- Report each finding with severity, approximate location, failure mode, and a specific test case.

## Research Findings
- Memory quick pass confirms `nextPas` review work should stay correctness-first and call out leak risks explicitly.
- The shipped `test_log`, `test_log_audit`, and `test_log_intf` suites all pass under heaptrc, so the main problems are in uncovered concurrent and shared-state paths rather than obvious single-thread leaks.
- A threaded probe logged only 13 handled records out of 32 attempted events and emitted unexpected `[REENTRANT]` fallbacks, confirming that the global pool plus global depth guard breaks concurrent logging.
- A file-handler probe using `With_` on a base file logger produced a 631-byte main log file with `AMaxBytes=100` and no rotated `.1` file, confirming that child loggers reset rotation state per derived handler.
- A write-failure probe against `/dev/full` raised `EInOutError: Disk Full` on every call, confirming that mid-stream file errors are not converted into a broken-state fallback.
- An open-failure recovery probe showed that once `EnsureOpen` marks the handler broken, later environmental recovery does not restore logging.
- `TLogEvent` managed fields are finalized on slot reuse and unit finalization; the existing heaptrc runs did not show leaks from `Attrs` in single-threaded use.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Review by pipeline: event creation -> handler fanout -> helper APIs | Makes it easier to connect surface bugs to root causes |
| Use shipped tests plus focused probes if needed | Confirms whether suspected issues are real or only theoretical |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Existing planning notes were still for regex review | Replaced them with log-review scope before continuing |

## Resources
- `task_plan.md`
- `src/nextpas.core.log.pas`
- `src/nextpas.core.log.intf.pas`
- `tests/nextpas.core.log/test_log/test_log.lpr`
- `tests/nextpas.core.log/test_log_audit/test_log_audit.lpr`
- `tests/nextpas.core.log.intf/test_log_intf/test_log_intf.lpr`
- `/tmp/log_thread_probe.pas`
- `/tmp/log_file_failure_probe.pas`
- `/tmp/log_file_recovery_probe.pas`
- `/tmp/log_file_withattrs_probe.pas`

## Visual/Browser Findings
- None; local source review only.
