# Platform Runtime Truth Matrix

| Host / seam | Evidence | Current truth |
| --- | --- | --- |
| Linux readiness poller | focused-runtime | Runtime-covered through focused platform/io and consumer gates. |
| Windows readiness poller | source-contract, forced-compile | Not runtime ready. |
| Windows IOCP lifecycle | source-contract, forced-compile, wine-runtime-smoke | Real port lifecycle exists; Wine smoke is optional and is not real Windows runtime ready. |
| Windows IOCP AsyncRead/AsyncWrite file completion | source-contract, forced-compile, wine-runtime-smoke | Runtime smoke covers file operations through IOCP/poller only when explicitly run under Wine; not real Windows runtime ready. |
| Windows IOCP socket completion | focused-runtime | `AsyncSend`/`AsyncRecv` and `AsyncAccept`/`AsyncConnect` are verified on Wine and a real Windows VM. |
| Android files/mmap | forced-compile/source-contract | Android files stat/lstat/fstat, directory enumeration through getdents64, and mmap size paths compile through host-owned declarations; no Android device runtime proof exists. |
| Resource limits | Linux focused-runtime, Android forced-compile/source-contract | Linux rlimit get/set is focused-runtime covered; Android is compile/source proof only, not device runtime proof. |
| Platform memory secure-zero | Linux focused-runtime, POSIX forced-compile/source-contract, Windows source-contract | Linux/POSIX host path uses shared POSIX `explicit_bzero`; forced POSIX compile proves branch coherence. Windows remains fallback/deferred with no native runtime proof. |
| Darwin/FreeBSD best-effort CI | ci-runtime-matrix for passed rows | Skipped rows are non-evidence. |
| Android/other forced host surfaces | forced-compile | Compile truth only. |

Update this file only when the evidence category changes.
