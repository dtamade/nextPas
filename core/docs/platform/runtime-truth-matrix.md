# Platform Runtime Truth Matrix

| Host / seam | Evidence | Current truth |
| --- | --- | --- |
| Linux readiness poller | focused-runtime | Runtime-covered through focused platform/io and consumer gates. |
| Windows readiness poller | source-contract, forced-compile | Not runtime ready. |
| Windows IOCP lifecycle | source-contract, forced-compile, wine-runtime-smoke | Real port lifecycle exists; Wine smoke is optional and is not real Windows runtime ready. |
| Windows IOCP AsyncRead/AsyncWrite file completion | source-contract, forced-compile, wine-runtime-smoke | Runtime smoke covers file operations through IOCP/poller only when explicitly run under Wine; not real Windows runtime ready. |
| Windows IOCP socket completion | source-contract | `AsyncAccept/Connect/Send/Recv/Close` unsupported. |
| Darwin/FreeBSD best-effort CI | ci-runtime-matrix for passed rows | Skipped rows are non-evidence. |
| Android/other forced host surfaces | forced-compile | Compile truth only. |

Update this file only when the evidence category changes.
