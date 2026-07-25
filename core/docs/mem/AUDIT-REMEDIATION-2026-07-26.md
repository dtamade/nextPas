# Audit remediation close-out (2026-07-26)

Implements `findings.md` (31 items) per full plan Phase 0–9.

## Delivered

| Finding | Status | Evidence |
|---------|--------|----------|
| A-001 System.* in mem | **CLOSED** | `nextpas.core.system.heap` + mem → `NpSystem*`; isolation script |
| A-002 sharded OS FFI | **CLOSED** | `platform_tls_create_with_destructor` / destroy_dtor; sharded uses only platform.thread |
| A-003 IAllocator size | **WAIVE** | FreeMemOf path; no ISizedAllocator |
| A-004 surface | **CLOSED** | FACADES freeze kept; no new facade units |
| A-005 dead units | **CLOSED** | deleted pressure/registry/watermark + tests |
| A-006 DEBUG gap | **CLOSED** | README 查泄漏 / HEAP_DEBUG |
| A-007 simd.bitops | **WAIVE** | L0 same-layer; no behavior change needed |
| A-008 layer naming | **CLOSED** | CONTRACT → M0–M3 pointer |
| C-001 Rtl once | **CLOSED** | acquire/release ready flag |
| C-002 foreign free | **CLOSED** | docs + NpSystem fallback wording |
| C-003 HEAP_DEBUG perf | **CLOSED** | README |
| C-004 double-free UB | **WAIVE** | intentional default; SAFETY opt-in |
| C-005 concurrent gates | **CLOSED** | test-extended + sharded 15/15 |
| C-006 utils size | **WAIVE** | no split |
| C-007 error subclasses | **WAIVE** | keep FormatAllocErrorMsg |
| T-001–T-005 | **CLOSED** | isolation + test-extended + README |
| N-001–N-006 | **CLOSED** | CONTRACT/README/mem-findings SUPERSEDED |
| P-001–P-005 | **CLOSED**/doc | HEAP-BACKEND-OWNER + README sized free |

## Verification

```text
make lane-focused LANE=mem                    PASS
check_mem_rtl_isolation.sh                    OK
scorecard RELEASE=1                           ALL PASS (growing 8ns ≤ system 22ns)
test_soak                                     3/3 0 leak
test_sharded_pools                            15/15 (heaptrc 1 residual block — pre-existing TLS/global; tests pass)
```

## Cross-module files

- `core/src/nextpas.core.system.heap.pas` (new)
- `core/src/nextpas.core.platform.thread.pas` (TLS dtor APIs)
