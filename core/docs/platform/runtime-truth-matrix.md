# Platform Runtime Truth Matrix

| Host / seam | Evidence | Current truth |
| --- | --- | --- |
| Linux readiness poller | focused-runtime | Runtime-covered through focused platform/io and consumer gates. |
| Windows readiness poller | wine-runtime-smoke + **ci-matrix** (GHA documented 18-gate set) | Durable on `windows-latest` for matrix modules; not full-host Windows parity. Wine matrix 16 modules (+error +fmt). 19-gate Windows script candidate (+fmt) pending GHA. |
| Windows IOCP lifecycle | source-contract, forced-compile, wine-runtime-smoke, GHA `poller.windows_runtime_smoke` | Real port lifecycle exists in matrix; broader IOCP completion beyond smoke is not real Windows runtime ready as a whole-host claim. |
| Windows IOCP AsyncRead/AsyncWrite file completion | source-contract, forced-compile, wine-runtime-smoke, GHA poller smoke | File completion is covered under documented ci-matrix poller gate; remaining AcceptEx/ConnectEx depth is not real Windows runtime ready beyond current smoke gaps. |
| Windows IOCP socket completion | focused-runtime + ci-matrix (socket wine + windows_real gates) | `AsyncSend`/`AsyncRecv` and `AsyncAccept`/`AsyncConnect` verified on Wine and real Windows GHA/VM. |
| Windows documented facade matrix | **ci-matrix** (18 promoted) | Promoted: 15 wine-suite dirs (+error) + 3 real. Script lists 16 suite dirs (+fmt) + 3 real = 19-gate candidate; promote only after GHA green. |
| Android files/mmap | forced-compile/source-contract | Android files stat/lstat/fstat, directory enumeration through getdents64, and mmap size paths compile through host-owned declarations; no Android device runtime proof exists. |
| Resource limits | Linux focused-runtime, Android forced-compile/source-contract | Linux rlimit get/set is focused-runtime covered; Android is compile/source proof only, not device runtime proof. |
| Platform memory secure-zero | Linux focused-runtime, POSIX forced-compile/source-contract, Windows permanent-fallback (source-contract + wine smoke) | Linux/POSIX host path uses shared POSIX `explicit_bzero` / Darwin `memset_s`; forced POSIX compile proves branch coherence. Windows closed as permanent FillChar+ReadWriteBarrier (`pszbWindowsPermanentFallback`); no stable RtlSecureZeroMemory/SecureZeroMemory DLL export across Wine+real Windows SDK. |
| Platform signal Windows | forced-compile + source-contract | `NEXTPAS_FORCE_HOST_WINDOWS` compile gate + windows signal contract. Console Ctrl handler is not wine-matrix runtime evidence. |
| Darwin/macOS documented 8-gate set | **focused-runtime** (GHA `test-macos` via `platform-macos-ci-matrix.sh`, fail-closed) | Documented set only: time/sync/thread/files/path/env/error/socket on `macos-14` aarch64. Not full-host macOS parity. Best-effort whole suite remains non-evidence. |
| Darwin/FreeBSD best-effort CI | best-effort inventory only | Skipped/failed rows are non-evidence. |
| Android/other forced host surfaces | forced-compile | Compile truth only. |

Update this file only when the evidence category changes.
