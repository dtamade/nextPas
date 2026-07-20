# Platform Runtime Truth Matrix

| Host / seam | Evidence | Current truth |
| --- | --- | --- |
| Linux readiness poller | focused-runtime | Runtime-covered through focused platform/io and consumer gates. |
| Windows readiness poller | wine-runtime-smoke + **ci-matrix** (23 **platform** gates) | Durable on `windows-latest` for platform matrix modules (+which +dl +args). Wine 24 secondary. Job `total` may be **24** when `mem.host_runtime` is listed (not a platform facade gate). |
| Windows IOCP lifecycle | source-contract, forced-compile, wine-runtime-smoke, GHA `poller.windows_runtime_smoke` | Real port lifecycle exists in matrix; broader IOCP completion beyond smoke is not real Windows runtime ready as a whole-host claim. |
| Windows IOCP AsyncRead/AsyncWrite file completion | source-contract, forced-compile, wine-runtime-smoke, GHA poller smoke | File completion is covered under documented ci-matrix poller gate; remaining AcceptEx/ConnectEx depth is not real Windows runtime ready beyond current smoke gaps. |
| Windows IOCP socket completion | focused-runtime + ci-matrix (socket wine + windows_real gates) | `AsyncSend`/`AsyncRecv` and `AsyncAccept`/`AsyncConnect` verified on Wine and real Windows GHA/VM. |
| Windows documented facade matrix | **ci-matrix** (23 platform) | Suite dirs through +info +which +dl +args + iocp + 3 real gates. args PASS on GHA 29728715160; promote lands with this batch. |
| Android files/mmap | forced-compile/source-contract | Android files stat/lstat/fstat, directory enumeration through getdents64, and mmap size paths compile through host-owned declarations; no Android device runtime proof exists. |
| Resource limits | Linux focused-runtime, Android forced-compile/source-contract | Linux rlimit get/set is focused-runtime covered; Android is compile/source proof only, not device runtime proof. |
| Platform memory secure-zero | Linux focused-runtime, POSIX forced-compile/source-contract, Windows permanent-fallback (source-contract + wine smoke) | Linux/FreeBSD: `explicit_bzero`. Darwin: FillChar+barrier (memset_s deferred after GHA Abort residual). Windows: permanent FillChar+ReadWriteBarrier (`pszbWindowsPermanentFallback`). |
| Platform signal Windows | forced-compile + source-contract | `NEXTPAS_FORCE_HOST_WINDOWS` compile gate + windows signal contract. Console Ctrl handler is not wine-matrix runtime evidence. |
| Darwin/macOS platform fail-closed matrix | **focused-runtime** (script step only) | 9 platform gates (+ optional mem.host → total=10). Promoted platform set run 29696318492; re-green pass=10 on 29719632518. **Whole job** red does not demote this row (e.g. async accept4). |
| Darwin/FreeBSD best-effort CI | best-effort inventory only | Skipped/failed rows are non-evidence. |
| Android/other forced host surfaces | forced-compile | Compile truth only. |

Update this file only when the evidence category changes.
