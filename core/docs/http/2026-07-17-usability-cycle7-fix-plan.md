# Usability Fix Plan: nextpas.core.http cycle-7 Wave B

**Status**: implementing  
**Assessment**: `2026-07-17-usability-assessment-cycle7.md` (97/100)  
**Research**: `2026-07-17-usability-cycle7-research.md`

## Milestones

| M | Item | Depends | Gate |
|---|------|---------|------|
| M0 | research + this plan | — | docs present |
| M1 | WS CancelToken + mid-frame cancel | M0 | test_http_websocket_client |
| M2 | H2 live dial e2e | M0 | test_http_h2_client |
| M3 | client CreateOp redirect hot-path | M0 | test_http_client |
| M4 | CONTRACT / API_COVERAGE / GOAL_TREE / README | M1–M3 | hygiene |
| M5 | focused verification suite | M1–M4 | all green heaptrc 0 |
| M6 | path-limited land main | M5 | landing-check |

## DoD

1. WS WithCancelToken + entry ThrowIfCanceled + stream SetCancelToken after dial; residual ~50ms honest.
2. H2 backlog-full live dial → hekTimeout|hekConnect.
3. client redirect resolve bare Create → CreateOp(…, 'redirect', …); hekStatus keeps Status overload.
4. Docs: no “cycle-5 uncommitted”; cycle-7 entry current.
5. No FPC RTL uses in http path.
6. Path-limited land evidence.

## Non-goals

CONNECT, Retry-After, full PSL, Response metadata, GetJson decode, Op-everywhere, H3,
server Default RW=0 change, shared cancel adapter extraction.
