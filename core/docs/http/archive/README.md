# HTTP docs archive

**Not a live backlog.** Forward work lives only in [`../ROADMAP.md`](../ROADMAP.md).

This directory keeps historical assessments, research, fix-plans, and one-shot
investigations that were used while closing non-H3 stage-complete and usability
waves A–F. Do not extend these files as if they were the roadmap.

## Live docs (parent directory)

| File | Role |
|------|------|
| [`../ROADMAP.md`](../ROADMAP.md) | Ordered next work |
| [`../GOAL_TREE.md`](../GOAL_TREE.md) | North star / stage truth |
| [`../CONTRACT.md`](../CONTRACT.md) | Public behavior contract |
| [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | Stable architecture facts |
| [`../API_COVERAGE.md`](../API_COVERAGE.md) | Public API evidence matrix |
| [`../BENCHMARKS.md`](../BENCHMARKS.md) | Benchmark truth |
| [`../README.md`](../README.md) | Module entry / API map |

## What landed (index only)

| Era | Outcome | Sample archive files |
|-----|---------|----------------------|
| Phase 1 base / server foundation | Early module foundation | `2026-05-31-*`, `2026-06-01-*`, `2026-06-03-*` |
| Deferred / investigation dumps | Superseded by stage-complete + ROADMAP | `deferred-items-investigation.md`, `investigation-report.md`, `implementation-plan.md`, `inbox.md` |
| Usability residual → cycle-3 | hekArgument, factories, ensure-string | `2026-07-17-usability-residual-*`, `*-cycle3-*` |
| Wave A (cycle-4/5) | OS dial timeout, mid-read cancel, WS budgets, live e2e | `*-cycle4-*`, `*-cycle5-*` |
| Wave B (cycle-7) | WS cancel token, H2 live dial, CreateOp | `*-cycle7-*` |
| Wave C (cycle-8) | GetJson ensure+decode, 429 Retry-After delta | `*-cycle8-*` |
| Wave D (cycle-9) | HTTPS CONNECT via HTTP proxy | `*-cycle9-*` |
| Wave E (cycle-10) | H1 direct HTTPS, proxy Basic | `*-cycle10-*` |
| Wave F (cycle-11) | HTTP-date Retry-After, WithTLSContext, *JsonDocument | `*-cycle11-*` |

`cycle-6` was process-only (land cycle-5); kept for audit trail.

## Rule

If an archive note disagrees with `ROADMAP.md` / `CONTRACT.md` / live source,
**live docs and source win**.
