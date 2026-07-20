# Platform Runtime Truth Matrix

| Host / seam | Evidence | Current truth |
| --- | --- | --- |
| Linux readiness poller | focused-runtime | Runtime-covered through focused platform/io and consumer gates. |
| Windows readiness poller | wine-runtime-smoke + **ci-matrix** (GHA documented 19-gate set) | Durable on `windows-latest` for matrix modules; not full-host Windows parity. Wine matrix 21 modules (+error +fmt +info +which +dl +pipe +args). |
| Windows IOCP lifecycle | source-contract, forced-compile, wine-runtime-smoke, GHA `poller.windows_runtime_smoke` | Real port lifecycle exists in matrix; broader IOCP completion beyond smoke is not real Windows runtime ready as a whole-host claim. |
| Windows IOCP AsyncRead/AsyncWrite file completion | source-contract, forced-compile, wine-runtime-smoke, GHA poller smoke | File completion is covered under documented ci-matrix poller gate; remaining AcceptEx/ConnectEx depth is not real Windows runtime ready beyond current smoke gaps. |
| Windows IOCP socket completion | focused-runtime + ci-matrix (socket wine + windows_real gates) | `AsyncSend`/`AsyncRecv` and `AsyncAccept`/`AsyncConnect` verified on Wine and real Windows GHA/VM. |
| Windows documented facade matrix | **ci-matrix** (19) | 16 wine-suite dirs (+error +fmt) + 3 real gates; GHA pass=19 (run 29686191527 @ `e9f203e45`). |
| Android files/mmap | forced-compile/source-contract | Android files stat/lstat/fstat, directory enumeration through getdents64, and mmap size paths compile through host-owned declarations; no Android device runtime proof exists. |
| Resource limits | Linux focused-runtime, Android forced-compile/source-contract | Linux rlimit get/set is focused-runtime covered; Android is compile/source proof only, not device runtime proof. |
| Platform memory secure-zero | Linux focused-runtime, POSIX forced-compile/source-contract, Windows permanent-fallback (source-contract + wine smoke) | Linux/FreeBSD: `explicit_bzero`. Darwin: FillChar+barrier (memset_s deferred after GHA Abort residual). Windows: permanent FillChar+ReadWriteBarrier (`pszbWindowsPermanentFallback`). |
| Platform signal Windows | forced-compile + source-contract | `NEXTPAS_FORCE_HOST_WINDOWS` compile gate + windows signal contract. Console Ctrl handler is not wine-matrix runtime evidence. |
| Darwin/macOS documented 9-gate set | **focused-runtime** (GHA `test-macos` via `platform-macos-ci-matrix.sh`, fail-closed) | Documented set: time/sync/thread/files/path/env/error/socket/**memory** on `macos-14` aarch64. Promoted run 29696318492 @ `d160cbc46`. Not full-host macOS parity. Best-effort whole suite remains non-evidence. |
| Darwin/FreeBSD best-effort CI | best-effort inventory only | Skipped/failed rows are non-evidence. |
| Android/other forced host surfaces | forced-compile | Compile truth only. |

Update this file only when the evidence category changes.
