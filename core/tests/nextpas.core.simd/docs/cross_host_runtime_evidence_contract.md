# SIMD Cross-Host Runtime Evidence Contract

This source-contract defines how SIMD reports allocator runtime evidence across
hosts. SIMD consumes only the platform.memory public aligned allocation seam
through `SimdAlloc`, `SimdRealloc`, and `SimdFree`.

The fallback header internals are private platform.memory details. SIMD tests
and source must not inspect header layout, magic values, raw host allocation
handles, or platform native allocator FFI.

| Evidence layer | Acceptable SIMD evidence | Truth level |
| --- | --- | --- |
| Linux host runtime | `alignment-allocator-contract` and `test` executed on the Linux runner | The executing Linux runner only |
| Wine smoke | Batch/log compatibility smoke through Wine | Wine smoke is not native Windows runtime evidence |
| Windows native runtime | Artifact from a platform/native runner artifact that executed on Windows | Windows runtime truth for that artifact only |
| POSIX native runtime | Artifact from a platform/native runner artifact that executed on the POSIX host | POSIX runtime truth for that artifact only |
| forced compile | Cross-compile or forced host compile gate | Compile/API truth, not runtime truth |

Until a fresh platform/native runner artifact exists for a host family,
native-ready truth remains provisional for that host. SIMD may record that its
public consumer path is wired to platform.memory, but it must not promote
Windows or POSIX native allocator runtime truth from fallback behavior,
cross-compilation, Wine smoke, or source inspection.

Native backend claims come from platform.memory public backend truth and the
runner artifact that executed the runtime gate. SIMD must not implement host
allocator FFI to manufacture this evidence.
