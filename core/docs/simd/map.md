# nextpas.core.simd 阅读地图

如果你只想在 1 分钟内知道这个模块该从哪里读起，看这页就够了。

## 0 层：先看真相表

如果你这次要判断“谁是默认主线”“哪个 intrinsics 只是 experimental”“SSE2 到底该迁什么”，先看这三张表：

- `docs/SIMD_BACKEND_TRUTH.md`
- `docs/SIMD_INTRINSICS_DISPOSITION.md`
- `docs/SIMD_SSE2_MIGRATION_MAP.md`

如果你这次要回答“为什么这里不是两层”“后续实施时哪些职责必须留在 adapter”，再看：

- `docs/SIMD_LAYERING_IMPLEMENTATION.md`

如果你这次要回答“整个模块最优雅的设计是什么”“`dataplane` 到底算什么”，同样先看：

- `docs/SIMD_LAYERING_IMPLEMENTATION.md`

如果你这次要回答“整个 simd 模块该怎么整体重构，不能只盯 `SSE2`”，再看：

- `docs/plans/2026-05-10-simd-plan-status-index.md`
- `docs/plans/2026-05-10-simd-execution-index.md`
- `docs/plans/2026-05-10-simd-wave2-seam-hardening-plan.md`
- `docs/plans/2026-05-09-simd-global-architecture-refactor-plan.md`
- `docs/plans/2026-05-09-simd-family-matrix.md`

如果你已经接受 whole-module 总纲，准备按 family 逐波次推进，再按类别看：

- `docs/plans/2026-05-09-simd-avx2-active-leaf-sample.md`
- `docs/plans/2026-05-09-simd-x86-incremental-qualification-plan.md`
- `docs/plans/2026-05-09-simd-neon-qualification-plan.md`
- `docs/plans/2026-05-09-simd-riscvv-qualification-plan.md`

## 第一层：对外入口

从这里开始，先理解模块对外承诺什么：

- `docs/simd/README.md`
- `src/nextpas.core.simd.pas`
- `src/nextpas.core.simd.api.pas`

## 第二层：控制真相

如果你关心“为什么会选中这个 backend”，看这里：

- `src/nextpas.core.simd.dispatch.pas`
- `src/nextpas.core.simd.cpuinfo.pas`
- `src/nextpas.core.simd.backend.priority.pas`

配套 include：

- `src/nextpas.core.simd.dispatch.hooks.intf.inc`
- `src/nextpas.core.simd.dispatch.hooks.impl.inc`
- `src/nextpas.core.simd.cpuinfo.backends.impl.inc`

## 第三层：发布缝与热点绑定

如果你关心“这个选择结果是怎么发布给 façade / public ABI / direct 的”，看这里：

- `src/nextpas.core.simd.dataplane.pas`
- `src/nextpas.core.simd.direct.pas`
- `src/nextpas.core.simd.public_abi.intf.inc`
- `src/nextpas.core.simd.public_abi.impl.inc`

## 第四层：后端入口

想知道某个后端“注册了什么能力”，多数情况下优先看 `*.register.inc`；`SSE2` 例外，直接看 `src/nextpas.core.simd.sse2.pas`：

- `src/nextpas.core.simd.sse2.pas`
- `src/nextpas.core.simd.avx2.register.inc`
- `src/nextpas.core.simd.avx512.register.inc`
- `src/nextpas.core.simd.neon.register.inc`
- `src/nextpas.core.simd.riscvv.register.inc`

## 第五层：后端快路径

想看 mem/text/search/bitset 之类的快路径，优先看 `*.facade.inc`：

- `src/nextpas.core.simd.avx2.facade.inc`
- `src/nextpas.core.simd.avx512.facade.inc`
- `src/nextpas.core.simd.avx512.fallback.inc`
  - 当前是空 include 边界；旧 AVX512 fallback pass-through wrappers 已移除，别再把这里当成活跃 fallback 实现层
- `src/nextpas.core.simd.neon.facade_asm.inc`
- `src/nextpas.core.simd.neon.facade_scalar.inc`
- `src/nextpas.core.simd.neon.facade_platform.inc`
  - 当前是空 include 边界；旧 platform facade wrappers 已移除，别再把这里当成活跃 helper 实现层
- `src/nextpas.core.simd.neon.dot.inc`
  - 当前是空 include 边界；旧 wide dot wrappers 已移除，别再把这里当成活跃 helper 实现层
- `src/nextpas.core.simd.riscvv.facade.inc`

## 第六层：按向量族读实现

想看具体向量族实现时，再去读 family include：

- `avx512.f32x16_*`
- `avx512.f64x8_*`
- `avx512.i32x16_*`
- `avx512.i64x8_*`
- `avx512.*_family.inc`
- `avx2.f32x8_*`
- `avx2.f64x4_*`
- `avx2.i32x8_family.inc`
- `neon.scalar.*.inc`

## 一条经验

如果你是第一次定位问题，优先顺序通常是：

1. `simd.pas`
2. `dispatch.pas`
3. `dataplane.pas`
4. `cpuinfo.pas`
5. 对应 backend 的注册入口（多数是 `register.inc`，`SSE2` 直接看 `sse2.pas`）
6. 对应 backend 的 `facade.inc`
7. 最后才看具体 family 实现

这样最不容易在大量汇编和 fallback 代码里迷路。

## 一条红线

不要默认“主文件就是唯一真实位置”。

这个模块现在的常态是：

- 主文件负责组织
- include 负责承载大块实现

如果你没先看 include，通常很容易误判影响面。
