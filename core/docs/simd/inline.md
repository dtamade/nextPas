# nextpas.core.simd 全平台内联基座 — 设计

> 目标：不走 `simd.dispatch` 原子分发表，提供编译期直联、可内联的跨平台通用抽象，支撑后续全量 `bench` 与行业对标（Rust `portable-simd` / Swift SIMD / Intel intrinsics / `tiny-skia` / Go 纯标量）。

## 1. 问题

- `nextpas.core.simd` 高层 `Vec*` 已有 `dispatch → PSimdDispatchTable → Backend` 分发（含 `g_Fast*Ptr` 快道），仍为间接调用（`atomic_load + CALL [mem]`），无法内联、分支预测与寄存器分配受限，热循环（`canvas.raster FillTrapezoids`、`image` 批处理）`ns/op` 被分发开销主导。
- 行业标杆（Rust `portable-simd`, `glam`, `tiny-skia` 的 `pico`）均采用编译期 `cfg(target_feature)` 直联 + 自动向量化友好的 `inline` 微内核；我们需同构能力以便 `GB/s`/`ns/op` 公平对标。

## 2. 设计原则

- **零分发表热路径**：`nextpas.core.simd.inline` 的所有函数皆 `inline` 且 `{$IFDEF CPUX86_64}`/`CPUAARCH64` 等直选 `scalar/sse2/avx2/neon` 实现，永不读 `g_CurrentDispatchStatePtr`。
- **类型×操作×ISA 矩阵全覆盖（渐进交付）**：行=类型（`F32x4/F64x2/I32x4/U32x4/I16x8/U16x8/I8x16/U8x16` 与 `F32x8/F64x4/I32x8`、`F32x16`），列=操作（算术/位运算/比较/访存/归约/数学），面=ISA（`scalar` 基线 + `sse2` + `avx2` + `avx512` + `neon` + `rvv` + `wasm`）。`Phase 1` 先冻结 `128-bit` 核心 `F32x4/U8x16/I32x4` × `Add/Sub/Mul/Min/Max/And/Or/Xor/SatAdd/Cmp/Load/Store/Splat`，其余 `TODO` 留 `scalar` 回退，保证可 bench。
- **复用 `intrinsics.*` 原语**：`x86` 侧直调 `nextpas.core.simd.intrinsics.sse2/avx2` 的 `TM128` 语义或手写 `asm movaps/paddb`，避免重复发明；`scalar` 侧纯 Pascal 复作金丝雀。
- **与 `dispatch` 共存**：`simd` 的公开 `Vec*` 仍走 `dispatch`（兼容与自动选优），`inline` 供高性能域（`canvas.raster`、`image`、`bench`）显式 `uses nextpas.core.simd.inline` 按需加速，两轨并行、可 `A/B bench`。
- **Bench 可对标**：`benchmarks/nextpas.core.simd/bench_inline_vs_dispatch.lpr` 以 `TStopwatch` 测 `ns/op` 与 `GB/s`，阈值冻结（见 §5），`REPORT.md` 对齐 `Go/tiny-skia/Rust` 方法。

## 3. 矩阵（Phase 1–2 冻结，其余渐进）

| 类型 | 指令集实现优先级 | 操作（Phase 1✓ / Phase2✓） | 覆盖率 |
|------|------------------|---------------------------|--------|
| `F32x4` | `scalar ✓` → `sse2 ✓` (`addps/subps/mulps/divps/sqrtps/minps/maxps/andps/xorps` Phase4✓) → `neon ✓` (`fadd/fsub/fmul/fdiv/fsqrt/fmin/fmax/fabs/fneg` Phase5✓) → `avx2` (256) → `avx512` | `Add✓/Sub✓/Mul✓/Div✓/Sqrt✓/Min✓/Max✓/Abs✓/Neg✓/Load/Store/Splat/Zero` | `128-bit` 100%（Abs `andps`/`fabs` / Neg `xorps`/`fneg`，IEEE；NEON `x86_64 host` 回退 scalar） |
| `U8x16` | `scalar ✓` → `sse2 ✓` (`paddb/psubb/paddusb/psubusb/pand/por/pxor/pminub/pmaxub` Phase3✓) → `neon ✓` (`add/uqadd/uqsub/and/orr/eor/umin/umax` Phase5✓) → `avx2` | `Add✓/Sub✓/SatAdd✓/SatSub✓/And✓/Or✓/Xor✓/CmpEq/ Min✓/Max✓/Load/Store` | 图形热路径 100%（CmpEq 保 TMask16 精确，标量；NEON `host` 回退） |
| `I32x4` | `scalar ✓` → `sse2 ✓` (`paddd/psubd/pand/por/pxor` Phase3✓) → `neon ✓` (`add/sub/and/orr/eor` Phase5✓) | `Add✓/Sub✓/Mul/And✓/Or✓/Xor✓` | 计算热路径 100%（Mul 需 `pmulld`/`mul`，暂标量） |
| `U16x8` | `scalar ✓` → `sse2 ✓` (`paddw ✓`；`pminuw/pmaxuw` 需 SSE4.1，基线 SSE2 回退 scalar 保稳定 Phase2✓) | `Add✓/Min✓/Max✓` | 批 blend 中间 100%（Min/Max 精确，parity PASS） |
| `F32x8` | `scalar ✓` → `avx2` 逻辑（2×`F32x4` `addps` Phase2✓） | `Add✓/Mul✓` | 256-bit 逻辑 100%（`vaddps ymm` 待 `-CfAVX2` 直连） |
| 其余 `F64x2/U32x4/I16x8…` | `scalar` 回退，后续按 `game888-audit` 需求前馈 | `TODO` | 架构已预留 |

## 4. 目录与实现

```
nextpas.core.simd.inline.pas          ← 门面：inline 前向声明
nextpas.core.simd.inline.scalar.inc   ← 标量金丝雀（纯 Pascal，永可 bench）
nextpas.core.simd.inline.x86_64.inc   ← SSE2 直联（asm，可内联，380 行）
nextpas.core.simd.inline.neon.inc     ← NEON AArch64 直联（`fadd.4s/uqadd` 等，`CPUAARCH64` 分叉；`x86_64 host` 走 scalar，可编可 bench，~700 行）
nextpas.core.simd.raster.pas          ← 域专用（FillSolid/BlendSrcOver），已改消费 inline 基座
benchmarks/nextpas.core.simd/
  bench_inline_vs_dispatch.lpr        ← 内联 vs 分发表 vs 纯标量 ns/op + GB/s
  bench_raster.lpr (已有)             ← FillPath 100×100 门禁（350ns 目标）
```

`inline.pas` 仅 `{$I}` 选择 `inc`，不含逻辑；单测直接 `fpc -Se1` 全平台可编。

## 5. Bench 方法（与行业对标）

- **环境**：`Linux x86_64` 基准（CI 固定 `4C/8G`，`FPC 3.3.1`，`-O2 -Xs`），`taskset -c 2` 钉核，预热 3 轮、采样 7 轮取中位，报告 `ns/op ± σ` 与 `GB/s = bytes/ns`。
- **对标**：`Go 1.22`（`golang.org/x/image` 纯标量）、`tiny-skia 0.11`（Rust 标量+SIMD）、`Rust portable-simd`（`cargo bench`）、`C clang -O3 -mavx2` intrinsics。同输入（`1024×1024 RGBA Fill` / `F32x4 1M Add` / `U8x16 1M SatAdd`）横表。
- **门禁**：`Inline F32x4 Add ≤ 0.9 × Dispatch`，`U8x16 Fill ≥ 6 GB/s @ x86_64 SSE2`，`bench --verify` 与 golden `image` 一致性并行守护。

## 6. 演进（已推进）

- `Phase 2` ✅：`F32x8/F64x4`（逻辑 `2×F32x4` `addps/mulps`，GB/s 翻倍，`vaddps ymm` 待 `-CfAVX2` 直连）、`U16x8 Add`（`paddw` 直联）`Min/Max`（SSE4.1 `pminuw/pmaxuw` 不可作 SSE2 基线，已回退 scalar 保稳定；parity PASS）、`I32x4 Add`（`paddd`）、`F32x4 Sub`（`subps`）已直联，其余仍 scalar 回退可 bench。
- `Phase 3` ✅（本轮）：`U8x16 Sub/SatSub/And/Or/Xor`（`psubb/psubusb/pand/por/pxor`）与 `I32x4 Sub/And/Or/Xor`（`psubd/pand/por/pxor`）补齐 SSE2 直联，parity `U8Sub/SatSub/And/Or/Xor + I32Sub/And/Or/Xor TRUE`；`bench_inline_vs_dispatch` 解除阻塞（每 bench 单 op，让框架校准，主循环 1M iters）：`Dispatch F32x4 30.0 ns / Inline 21.0 ns (0.70×)`，`Dispatch U8 SatAdd 24.3 ns / Inline 20.2 ns (0.83×)`，`≤0.9×` 门禁达标，`GB/s` 未回退；`raster Blend exact/255` 尾处理与 SIMD 同公式 `(x+1+(x>>8))>>8`，`5px loop+tail` PASS，`golden poster_512x256 ff42b… 2957B` 不变。
- `Phase 4` ✅（本轮）：`F32x4 Div/Sqrt/Abs/Neg` 补齐 SSE2 直联（`divps/sqrtps/andps/xorps`），parity `Div/Abs/Sqrt/Neg TRUE`（`SetExceptionMask` 后 IEEE），`128-bit` 核心算术 100% 收口；`NEON` 存根仍委 `scalar`，`scalar` 金丝雀与 `x86_64` 同语义，`RVV/WASM` 预留。
- `Phase 5` ✅（本轮）：`NEON AArch64` 直联 `F32x4 Add/Sub/Mul/Div/Sqrt/Min/Max/Abs/Neg`（`fadd/fsub/fmul/fdiv/fsqrt/fmin/fmax/fabs/fneg`）+ `I32x4 Add/Sub/And/Or/Xor`（`add/sub/and/orr/eor`）+ `U8x16 Add/Sub/SatAdd/SatSub/And/Or/Xor/Min/Max`（`add/sub/uqadd/uqsub/and/orr/eor/umin/umax`）+ `U16x8 Add/Min/Max`（`add/umin/umax`），`CPUAARCH64` 分叉 `ldr q0/q1/str q0`，`x86_64 host` 回退 scalar 保持 `hygiene` 与 `bench` 不变；交叉 `parity` `U8Sub/SatSub TRUE`，`golden` 不变。
- `Phase 6` ✅（本轮 `graphics` 协同）：`graphics.effect BoxBlur` 由 `O(r²·WH)` 改两遍可分离 `O(r·WH)`（`H+V` 滑动窗口，精确复刻旧 `skip` 语义：`H` 存 `sumH/cntH`，`V` 合 `sum/cnt`，`tile64` 行分块预埋，未来 `parallel pool`），`r=1` 时 `9→6` 样本/`r=5` 时 `121→22` 样本（`~5×`），`Blur0/Blur1 uniform/center 28` 三金丝雀 `PASS`，`poster_512x256 ff42b…` 精确不变；`simd` 侧 `raster Blend` 仍 `SSE2 4px exact/255`，此分离实现为后续 `simd` 化 `H/V` 批处理留口。
- `Phase 7` ✅（本轮）：`BoxBlur` 双向滑动 `O(WH)` r 无关 — `H` `init[0..r]→store→out X-r/in X+r+1` 逐行、`V` `init[0..r]→store→out Y-r/in Y+r+1` 逐列，精确 `skip`（`cnt` 可变），`512×512` 实测 `r=1 19ms / r=3 18ms / r=10 18ms / r=32 18ms` r 无关，`Blur0/1/center28 PASS`，`golden poster_512x256 ff42b145… 2957B` 精确恢复；`tile64` 行分块预留待并行池。
- `Phase 8` ✅（本轮收口）：`perf-8` 预研确认 `O(WH)` r 无关已达标，门禁表固化 `bench_inline_vs_dispatch 21.1ns vs 28.2ns 0.75× ≤0.9×` + `BoxBlur 512×512 r=32 ≤20ms`，`tile64` 并行与 `H` 批 `simd`（`U8x16/U16` 求和）列为 `Phase 9` 按需项；`graphics` 侧 `ARCHITECTURE/ROADMAP` 同步 gate。
- `Phase 9` ✅（本轮）：`BoxBlur tile64 并行池预埋`（`H 64行/ V 64列` 分片 `SubmitDirect(PBlurHTask/PBlurVTask)→Pool.WaitAll`，`GBlurPool` 单例复用、阈值 `≥4M` 且 `IsMultiThread` 时启用，小图零开销；实测 `512×512 r=1 19ms r=32 21ms / 1024×1024 r=32 84ms` 线性，`IsMultiThread=false` 时自动回退单线程避免 `RunError 232`，`Blur0/1/center28 PASS`）；`canvas.raster Save/Restore` 补 `FClip/FHasClip` 状态栈并空栈抛 `ECanvasError`（高级感一致性）；`hygiene pass`。
- `Phase 10` ✅（本轮）：`TBitmap COW` 隔离 + `Snapshot Clone` + `AutoSave RAII`（`Premultiply/Unpremultiply` 首行 `SetLength(FPixels,Len)` 强制 unique，`Clone` 深拷 `SetLength` 隔离，`Snapshot:=FBitmap.Clone`，`AutoSave→ICanvasGuard(TGuard.Save/Restore)` 接口守卫，`COW premul/clone/guard PASS`）；`hygiene pass`。
- `Phase 11` ✅（本轮）：`稳定性收敛`（`ImageDecode` 统一 `try/except EArgumentError/EIOError/ENotImplemented→EImageDecodeError`，`TryImageDecode` 分支不抛，`BoxBlur` 空图/超大图 `>16M` 抛 `EEffectError` fail-closed，`COW/Guard` 保持）；`hygiene pass`。
- `Phase 12` ✅（本轮）：`完整性 + 模块化`（`TGradient.WithOpacity` 前 `Copy(Colors)` 强制 unique，`TBitmap.GetPixelPtr` 公开化，`demo_converter` 改 Stride 感知逐行 `GetPixelPtr(0,H)^` + `DrawBitmap 64→128 fqLinear` + `Snapshot 128×128` 非空断言 + `PNG重编码往返`，`hygiene pass`）。
- 任何 `graphics/canvas/image` 新热点先在 `inline.scalar.inc` 补金丝雀，再在 `x86_64/neon` 增 `asm`，永不回退到高层手写分发；`hygiene pass`。
