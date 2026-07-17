# Usability Fix Plan: nextpas.core.http cycle-8 Wave C

**Status**: verified (client 234 / contract 31 / base 31; heaptrc 0); landing
**Assessment**: `2026-07-17-usability-assessment-cycle8.md`
**Research**: `2026-07-17-usability-cycle8-research.md`

## Milestones

| M | Item | Depends | Gate |
|---|------|---------|------|
| M0 | assessment + research + this plan | — | docs present |
| M1 | GetJson / ReadResponseJson + facade + tests | M0 | test_http_client |
| M2 | Retry-After + 429 in TRetryClient + tests | M0 | test_http_client |
| M3 | CONTRACT / API_COVERAGE / GOAL_TREE / README | M1–M2 | hygiene |
| M4 | focused verification | M1–M3 | green heaptrc 0 |
| M5 | path-limited land main | M4 | landing-check |

## DoD

1. `HttpGetJson` / `HttpReadResponseJson` / `IHttpClient.GetJson` return `IJsonDocument` on 2xx valid JSON.
2. Invalid JSON → `EHttpError` Kind `hekProtocol` Op `json`.
3. `WithRetry`: 429 and 5xx retriable; honor delta-seconds Retry-After (cap 60s); else exponential.
4. No default-client behavior change without WithRetry.
5. Docs inventory: cycle-8 entry; Deferred list without GetJson/Retry-After.
6. Path-limited land evidence.

## Non-goals

CONNECT, full PSL, Response metadata, Op-everywhere, H3,
HTTP-date Retry-After, server Default RW=0 change,
changing `HttpPostJson` return type from string.
