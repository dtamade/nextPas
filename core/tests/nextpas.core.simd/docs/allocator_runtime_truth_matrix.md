# SIMD Allocator Runtime Truth Matrix

This matrix is a source-contract for SIMD allocator evidence.
SIMD consumes only nextpas.core.platform.memory public aligned allocation seam
through SimdAlloc, SimdRealloc, and SimdFree.
The fallback header internals are platform.memory private implementation details
and must not be inspected by SIMD tests or source.

| Truth layer | Evidence allowed in SIMD | Claim allowed |
| --- | --- | --- |
| Linux/POSIX host runtime | `alignment-allocator-contract` and `test` on the current Linux runner | Current runner behavior only |
| Windows native runtime | Artifact from a real Windows platform/native runner | Windows native runtime truth |
| POSIX native runtime | Artifact from the POSIX platform/native runner that executed the binary | That runner's POSIX native runtime truth |
| fallback-only runtime | Host/runtime where `platform_aligned_alloc_is_native` reports false | Fallback behavior through public seam only |
| forced compile | Cross-compile or forced host compile gate | Compile/API truth, not runtime truth |
| Wine | Wine smoke/logs | Wine is not native runtime evidence |

Windows/POSIX native runtime truth requires platform/native runner evidence.
SIMD must not implement platform FFI or infer native readiness from fallback
header layout. Native readiness claims come only from platform.memory public
backend truth plus a runner that actually executed the runtime test.

This file is referenced by allocator_runtime_truth_matrix.md contract checks.
