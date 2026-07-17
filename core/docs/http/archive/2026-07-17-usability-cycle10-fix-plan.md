# Usability Fix Plan: nextpas.core.http cycle-10 Wave E

**Status**: landed main `2820157d2` (client 240; contract 31; base 31; landing-check pass; pushed)
**Assessment**: `2026-07-17-usability-assessment-cycle10.md`
**Research**: `2026-07-17-usability-cycle10-research.md`

## Milestones

| M | Item | Depends | Gate |
|---|------|---------|------|
| M0 | assessment + research + this plan | — | docs present |
| M1 | H1 direct https (scheme + TLS wrap + pool key) + tests | M0 | test_http_client |
| M2 | Proxy Basic from UserInfo (CONNECT + absolute-form) + tests | M0 | test_http_client |
| M3 | CONTRACT / API_COVERAGE / README / GOAL_TREE | M1–M2 | hygiene |
| M4 | focused verification | M1–M3 | client + contract + base |
| M5 | path-limited land main | M4 | landing-check |

## DoD

1. `https://` without proxy: dial → TLS → origin-form; pool key `https|host`.
2. `https://` with `ProxyUrl=http://…` still CONNECT + TLS (Wave D preserved).
3. `ProxyUrl` with UserInfo injects `Proxy-Authorization: Basic …` on CONNECT
   and on absolute-form when request lacks that header.
4. Explicit request `Proxy-Authorization` is not overwritten on absolute-form.
5. Non-`http`/`https` schemes still rejected on default H1 client.
6. Docs inventory: direct HTTPS Closed; proxy Basic Closed; Digest/SOCKS Deferred.
7. Path-limited land evidence.

## Non-goals

full PSL, Response metadata, Op-everywhere, H3, Digest/NTLM, SOCKS,
percent-decode UserInfo, server Default RW=0 change.
