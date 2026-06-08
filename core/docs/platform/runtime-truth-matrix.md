# Platform Runtime Truth Matrix

| Host / seam | Evidence | Current truth |
| --- | --- | --- |
| Linux readiness poller | focused-runtime | Runtime-covered through focused platform/io and consumer gates. |
| Windows readiness poller | source-contract, forced-compile | Not runtime ready. |
| Windows IOCP lifecycle | source-contract, focused-runtime fragments | Real port lifecycle exists; consumer truth remains narrow. |
| Windows IOCP AsyncRead/AsyncWrite file completion | focused-runtime | Runtime smoke covers file operations through IOCP/poller. |
| Windows IOCP socket completion | source-contract | `AsyncAccept/Connect/Send/Recv/Close` unsupported. |
| Darwin/FreeBSD best-effort CI | ci-runtime-matrix for passed rows | Skipped rows are non-evidence. |
| Android/other forced host surfaces | forced-compile | Compile truth only. |

Update this file only when the evidence category changes.
