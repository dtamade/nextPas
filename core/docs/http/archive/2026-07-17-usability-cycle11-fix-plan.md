# Usability Fix Plan: nextpas.core.http cycle-11 Wave F

**Status**: landed
**Assessment**: `2026-07-17-usability-assessment-cycle11.md`
**Research**: `2026-07-17-usability-cycle11-research.md`

## Milestones

| M | Item | Depends | Gate |
|---|------|---------|------|
| M0 | assessment + research + this plan | — | docs present |
| M1 | HTTP-date Retry-After + tests | M0 | test_http_client |
| M2 | WithTLSContext + tests | M0 | client + base |
| M3 | JsonDocument write helpers + tests | M0 | test_http_client |
| M4 | CONTRACT / API_COVERAGE / GOAL_TREE / README | M1–M3 | hygiene |
| M5 | focused verification | M1–M4 | client + contract + base |
| M6 | path-limited land main | M5 | landing-check |

## DoD

1. IMF-fix `Retry-After` drives capped delay; past → 0; invalid → backoff.
2. Delta-seconds path unchanged (cap 60s).
3. `WithTLSContext` on options + fluent client + forwarder.
4. `HttpPost/Put/PatchJsonDocument` ensure+decode; string helpers unchanged.
5. Docs inventory cycle-11; base ProxyUrl auth comment fixed.
6. Path-limited land evidence.

## Non-goals

full PSL, Response metadata, Op-everywhere, H3, Digest/SOCKS,
server Default RW=0 change.
