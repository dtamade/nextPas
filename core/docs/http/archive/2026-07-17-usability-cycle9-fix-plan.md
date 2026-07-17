# Usability Fix Plan: nextpas.core.http cycle-9 Wave D

**Status**: landed main `61ee03f93` (client 236; contract 31; base 31; landing-check pass; pushed)
**Assessment**: `2026-07-17-usability-assessment-cycle9.md`
**Research**: `2026-07-17-usability-cycle9-research.md`

## Milestones

| M | Item | Depends | Gate |
|---|------|---------|------|
| M0 | assessment + research + this plan | — | docs present |
| M1 | H1 CONNECT + TLS wrap + registry TLSContext | M0 | compile |
| M2 | CONNECT success/denied e2e tests | M1 | test_http_client |
| M3 | CONTRACT / API_COVERAGE / README / GOAL_TREE | M1–M2 | hygiene |
| M4 | focused verification | M1–M3 | client + contract + base |
| M5 | path-limited land main | M4 | landing-check |

## DoD

1. `https://` target with `ProxyUrl=http://host:port` uses CONNECT then TLS then origin-form.
2. `http://` target with same proxy keeps absolute-form (no CONNECT).
3. Non-2xx CONNECT → `EHttpError` Kind `hekConnect`.
4. Direct `https://` without proxy remains unsupported on H1.
5. Docs inventory: CONNECT Closed; proxy auth still Deferred.
6. Path-limited land evidence.

## Non-goals

Proxy auth, H1 direct https, full PSL, Response metadata, Op-everywhere, H3,
server Default RW=0 change.
