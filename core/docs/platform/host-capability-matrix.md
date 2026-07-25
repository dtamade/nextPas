# Platform host capability matrix (honest summary)

Companion to [runtime-truth-matrix.md](runtime-truth-matrix.md) and [goal-tree.md](goal-tree.md).  
**Not** a promise of full-host parity. Expand only with evidence.

| API family | Linux x86_64 | Windows x86_64 | macOS | FreeBSD | Android |
|------------|--------------|----------------|-------|---------|---------|
| time / sync / thread | focused-runtime | ci-matrix | focused-runtime (9-gate set) | best-effort | forced-compile fragments |
| files / path / env | focused-runtime | ci-matrix | focused-runtime (in 9) | best-effort | compile fragments |
| socket | focused-runtime | ci-matrix + real gates | focused-runtime (in 9) | best-effort | limited |
| console is_terminal/size/ansi | focused-runtime | ci-matrix (28) + wine 25 | **implemented**; matrix **candidate** (not promoted) | implemented (source) | read/write only; set_raw may UNSUPPORTED |
| console raw/read/write/wait | focused-runtime | ci-matrix (std handles) | termios path (F-002) | termios path | partial |
| process / pipe | focused-runtime | ci-matrix | partial | best-effort | limited |
| watch | focused-runtime | ci-matrix (WIN_MAX=8, no bWatchSubtree) | kqueue path | best-effort | limited |
| pty | focused-runtime | ci-matrix (ConPTY smoke) | limited | limited | limited |
| signal | focused-runtime | forced-compile + contract (not wine matrix) | partial | partial | limited |
| resource limits | focused-runtime | partial / unsupported map | partial | partial | compile |
| memory secure-zero | focused-runtime (explicit_bzero) | permanent FillChar+barrier | FillChar+barrier | explicit_bzero path | partial |
| freetype / x11 | optional dlopen binding (not OS core) | N/A / optional | optional | optional | optional |

## Dual-IO (F-004 / F-012)

`platform_io_read` / `write` / `poll` / `close` symbols live only on `platform.process`.  
**No new production call sites.** Prefer `platform.files` and `platform_process_*_ex`.

## L0 heap (F-009)

platform uses System `GetMem`/`FreeMem` for poller/fs buffers so it cannot depend on `nextpas.core.mem` (mem depends on platform). Documented invariant, not a bug.
