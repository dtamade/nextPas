# Platform Runtime Truth Matrix

| Host / seam | Evidence | Current truth |
| --- | --- | --- |
| Linux readiness poller | focused-runtime | Runtime-covered through focused platform/io and consumer gates. |
| Windows readiness poller | wine-runtime-smoke + **ci-matrix** (GHA documented 17-gate set) | Durable on `windows-latest` for matrix modules; not full-host Windows parity. |
| Windows IOCP lifecycle | source-contract, forced-compile, wine-runtime-smoke, GHA `poller.windows_runtime_smoke` | Real port lifecycle exists in matrix; broader IOCP completion beyond smoke is not real Windows runtime ready as a whole-host claim. |
| Windows IOCP AsyncRead/AsyncWrite file completion | source-contract, forced-compile, wine-runtime-smoke, GHA poller smoke | File completion is covered under documented ci-matrix poller gate; remaining AcceptEx/ConnectEx depth is not real Windows runtime ready beyond current smoke gaps. |
| Windows IOCP socket completion | focused-runtime + ci-matrix (socket wine + windows_real gates) | `AsyncSend`/`AsyncRecv` and `AsyncAccept`/`AsyncConnect` verified on Wine and real Windows GHA/VM. |
| Windows documented facade matrix | **ci-matrix** | 14 wine-suite dirs + 3 real gates via `platform-windows-ci-matrix.sh` on GHA `test-windows-runtime`. |
| Android files/mmap | forced-compile/source-contract | Android files stat/lstat/fstat, directory enumeration through getdents64, and mmap size paths compile through host-owned declarations; no Android device runtime proof exists. |
| Resource limits | Linux focused-runtime, Android forced-compile/source-contract | Linux rlimit get/set is focused-runtime covered; Android is compile/source proof only, not device runtime proof. |
| Platform memory secure-zero | Linux focused-runtime, POSIX forced-compile/source-contract, Windows source-contract | Linux/POSIX host path uses shared POSIX `explicit_bzero`; forced POSIX compile proves branch coherence. Windows remains fallback/deferred with no native runtime proof. |
| Darwin/FreeBSD best-effort CI | ci-runtime-matrix for passed rows | Skipped rows are non-evidence. |
| Android/other forced host surfaces | forced-compile | Compile truth only. |

Update this file only when the evidence category changes.
