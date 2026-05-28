# nextpas.core.simd 维护指南

这份文档面向维护 `nextpas.core.simd` 的开发者，重点说明现在的代码组织、推荐阅读顺序、哪些地方适合继续整理，以及哪些地方暂时不要再拆。

如果你只想快速定位入口，再看 `docs/nextpas.core.simd.map.md`。

如果你只想看“现在该做什么”，再看 `docs/nextpas.core.simd.checklist.md`。

如果你想快速了解当前收口已经做到哪里，以及后续最值得做什么，再看 `docs/nextpas.core.simd.handoff.md`。

如果你这次接手的是“当前到底还要不要继续改实现，还是已经只差 release 证据”，先记住一条最新事实：

- 截至 `2026-05-21`，当前应按 `code-green / cross-ready` 理解
- 也就是说，默认不要再重开 closeout blocker 讨论；除非 future `freeze-status` 再次拉红，否则优先沿 `docs/nextpas.core.simd.checklist.md` / `docs/nextpas.core.simd.closeout.md` 参考 future rerun 纪律，并把主要精力放回实现 residual / qualification
- 当前 `public-api-coverage` 也已经是默认硬护栏：canonical `public-api-coverage` 现在默认按 `strict-thin` 运行；future `thin > 0` 会直接让 `gate` / `gate-strict` 变红

如果你这次要判断 backend / intrinsics / SSE2 的真实归属，先看三张真相表：

- `docs/SIMD_BACKEND_TRUTH.md`
- `docs/SIMD_INTRINSICS_DISPOSITION.md`
- `docs/SIMD_SSE2_MIGRATION_MAP.md`

如果你这次要决定“为什么不是 façade 直接引用 intrinsics”“后续迁移应该按什么实施纪律推进”，再看：

- `docs/SIMD_LAYERING_IMPLEMENTATION.md`

## 先看什么

如果你第一次接手这个模块，建议按这个顺序读：

1. `src/nextpas.core.simd.README.md`
2. `docs/nextpas.core.simd.md`
3. `docs/nextpas.core.simd.architecture-impl.md`
4. `src/nextpas.core.simd.pas`
5. `src/nextpas.core.simd.dispatch.pas`
6. `src/nextpas.core.simd.dataplane.pas`
7. `src/nextpas.core.simd.cpuinfo.pas`
8. `src/nextpas.core.simd.direct.pas` / `public_abi` include
9. 具体后端（`avx2` / `avx512` / `neon` / `sse2`）

这个顺序有两个好处：

- 先理解对外 API 和运行时派发，再去看 ISA 细节。
- 先理解“主单元 + include 片段”的组织方式，再进入后端实现，不容易在大量汇编和 fallback 代码里迷路。

## 现在的代码组织

当前 `SIMD` 子系统已经从“少量超大 Pascal 单元”收口到“主单元 + include 片段”的结构。

### 主入口层

- `src/nextpas.core.simd.pas`
- `src/nextpas.core.simd.api.pas`
- `src/nextpas.core.simd.base.pas`

这里负责：

- 对外 API
- 类型别名与重导出
- 高层语义包装

其中 `src/nextpas.core.simd.pas` 已经把类型与框架包装拆到 include：

- `src/nextpas.core.simd.types.inc`
- `src/nextpas.core.simd.framework.intf.inc`
- `src/nextpas.core.simd.framework.impl.inc`

### 派发与能力检测层

- `src/nextpas.core.simd.dispatch.pas`
- `src/nextpas.core.simd.dataplane.pas`
- `src/nextpas.core.simd.cpuinfo.pas`
- `src/nextpas.core.simd.backend.priority.pas`

这里负责：

- 后端优先级
- CPU / OS 能力判断
- control-plane truth 与 dispatch table 选择
- dataplane published binding snapshot
- runtime hook / backend rebuild

补充一条当前容易踩坑的事实：

- `SSE* / AVX*` 多数 backend 已经有比较明确的 runtime-gated rebuild 语义。
- `NEON / RISCVV` 的 asm/fallback 主路径仍主要是编译期开关；当前实现是在 asm build + runtime disabled 时，把 backend 重建成 scalar-backed table，而不是在同一 build 里动态切到另一套 backend-local fallback 函数。

当前更值得关注的真相源：

- `src/nextpas.core.simd.dispatch.pas`：`TSimdDispatchTable` 与 base fallback 的事实真相源
- `src/nextpas.core.simd.dataplane.pas`：façade fast-path / public ABI / direct 共用的 published binding seam
- `src/nextpas.core.simd.cpuinfo.pas`：CPU/OS 支持视图与能力判断入口
- `src/nextpas.core.simd.STABLE`：公开 façade、in-repo dispatch contract 与 stable boundary 的真相源

### control/publication seam

如果你是从整个模块视角判断“最优雅的设计是什么”，这里是当前最该记住的一层：

- `dispatch` 负责 control-plane truth
- `dataplane` 负责 publication seam

这两者合起来，才是当前仓库把 backend 选择结果发布给热点调用面的中间缝。

后续不要再把 `dataplane` 当成：

- `direct` 的私有 helper
- `public ABI wrapper` 的缓存实现
- 或 façade hot-path 的偶然优化

它现在已经是明确的共享结构。

### 伴生出口层

除了主 façade / runtime / cpuinfo / dispatch 这条主线，还要明确两个真实存在的伴生出口：

- `public ABI wrapper`
- `direct dispatch companion`

对应位置：

- `src/nextpas.core.simd.public_abi.intf.inc`
- `src/nextpas.core.simd.public_abi.impl.inc`
- `src/nextpas.core.simd.direct.pas`

这里的维护判断要固定：

- `public ABI wrapper` 是外部稳定包装面，不是 `TSimdDispatchTable` 的公开版
- `direct` 只是读取已发布 dataplane 的 fast-path companion，不是新的 control-plane 真相源
- 这两个面都通过 `dataplane` 消费当前 published binding
- 这两个面都挂在第一层附近；不要把它们误判成 backend adapter，也不要把它们下沉到 raw leaf 讨论

## 当前接口封边结论

这一轮之后，`SIMD` 的接口分层应视为冻结：

- `src/nextpas.core.simd.pas`：data-plane façade 与兼容别名出口
- `src/nextpas.core.simd.runtime.pas`：canonical runtime / control-plane snapshot
- `src/nextpas.core.simd.dataplane.pas`：published binding seam
- `src/nextpas.core.simd.cpuinfo.pas`：CPU/OS capability-only 视图
- `src/nextpas.core.simd.dispatch.pas`：更低层的 dispatch contract、hook 与 backend wiring
- `src/nextpas.core.simd.public_abi.intf.inc` / `impl.inc`：external stable wrapper
- `src/nextpas.core.simd.direct.pas`：direct dataplane companion

同样冻结的一条实现口径是：

- `simd.*` = backend adapter / backend assembly layer
- `intrinsics.*` = raw ISA leaf / low层语义叶子

这里不要偷换成“两层直通”理解。对这个仓库来说，正确口径是：

- stable façade / control-plane
- control/publication seam
- thin backend adapter
- raw intrinsics leaf

为什么不是两层，以及哪些职责不能穿透 adapter，统一以 `docs/SIMD_LAYERING_IMPLEMENTATION.md` 为准。
再补一条实施纪律：default stable backend adapter 只允许新增依赖 `active leaf`，不允许直接把 `experimental isolated` 当成默认实现依赖。

不要再把 `intrinsics.*` 误读成默认主线 backend 实现层；尤其是 `SSE2`，当前发布真相源仍然是 `src/nextpas.core.simd.sse2.pas`。

后续默认不要再回到“命名是不是还要再改”“runtime/cpuinfo 要不要再换层”这种接口层反复重构。除非出现新的语义错误或兼容性问题，否则审查重点应放在：

- 实现正确性
- 并发一致性
- fallback / wiring 真相
- 非 x86 可移植性
- 证据链是否新鲜且可复验

## Runtime snapshot 发布模型

`src/nextpas.core.simd.runtime.pas` 当前采用的是“target 指针 + version + 锁内 published snapshot cache”的发布模型，这一层不要随意回退到 cacheless rebuild。

关键约束：

- `TSimdRuntimeSnapshot` 是 control-plane 视图，并按值返回给调用方
- snapshot 内部包含 `TSimdBackendInfo` 的 managed string，以及 backend 列表动态数组
- 因此当前实现故意把最新已发布 snapshot 缓存在 `g_SimdRuntimeState`，并用 `g_SimdRuntimeRebindLock` 串起 publish / read 一致性
- 失效信号使用 `g_SimdRuntimeTargetDispatchPtr + g_SimdRuntimeTargetVersion`
- `TargetVersion` 明确使用 `UInt32`，避免重新引入 `armv7` 等平台缺失 `atomic_*_64` 的可移植性问题

维护规则：

- 只是触发 runtime 重新绑定时，维持现在的 invalidation + rebuild + publish 语义
- 不要把这里“简化”为每次读取都 lockless 现算的 cacheless rebuild，除非你重新证明并发稳定性与 managed-field 生命周期安全
- 任何想动这一层发布模型的改动，至少要重新通过 `gate`、`gate-strict`，以及当前 gate 中的 `publicabi-concurrent-chain` 回归组合；没有真实硬件时，还要保住现有 QEMU non-x86 evidence

## Dataplane published snapshot 模型

`src/nextpas.core.simd.dataplane.pas` 当前不是普通 helper，而是热点调用面的 publication seam。

关键约束：

- `dataplane` 绑定的是当前 published dispatch 对应的一组热点函数指针
- `simd.pas` façade fast-path、`simd.pas` 本地 dispatch mirror、public ABI wrapper、`direct` 都共享这份发布结果
- 当前语义是“发布 snapshot，再消费”，不是每个调用面自己反复回读 `dispatch`

维护规则：

- 不要把这层重新打散回“多个调用面各自 getter + 各自缓存”的状态
- `simd.pas` 的本地 dispatch mirror 只能从 `PSimdDataPlane.Dispatch` 发布；它是只读热路径镜像，不是新的 truth source
- 如果你改了 `dataplane` 的字段、发布时机或失效逻辑，至少重新跑 `TTestCase_DataPlane`、`TTestCase_DirectDispatch` 和 `gate`
- 如果你同时动 `dispatch` 与 `dataplane`，要把它视为同一条 seam 的一致性改动，而不是两个无关文件

### 后端层

当前后端大致分三类：

- **稳定基线**：`scalar`、`sse2`
- **已完成较多结构收口**：`avx2`、`avx512`、`neon`
- **特殊平台 / 试验性**：`sse2.i386`、`riscvv`

要看默认主线 backend 的“文件级真相源”，以 `docs/SIMD_BACKEND_TRUTH.md` 为准。
要看 intrinsics 是否只是隔离叶子或兼容包袱，以 `docs/SIMD_INTRINSICS_DISPOSITION.md` 为准。
要看 SSE2 以后能迁什么、不能迁什么，以 `docs/SIMD_SSE2_MIGRATION_MAP.md` 为准。

已经拆出的典型片段包括：

- `*.register.inc`：多数 backend 的注册与 initialization（`SSE2` 当前保留在主单元）
- `*.facade.inc`：门面 / helper / fallback
- `*.family.inc`：按向量族或操作族拆分的实现片段


## Include 清单

下面这份清单不是“完整文件索引”，而是维护时最值得关注的 include 入口。

### 主入口与派发

- `src/nextpas.core.simd.types.inc`
- `src/nextpas.core.simd.framework.intf.inc`
- `src/nextpas.core.simd.framework.impl.inc`
- `src/nextpas.core.simd.public_abi.intf.inc`
- `src/nextpas.core.simd.public_abi.impl.inc`
- `src/nextpas.core.simd.dispatch.pas`
- `src/nextpas.core.simd.dataplane.pas`
- `src/nextpas.core.simd.direct.pas`
- `src/nextpas.core.simd.cpuinfo.pas`
- `tests/nextpas.core.simd/check_backend_adapter_sync.py`
- `tests/nextpas.core.simd/check_intrinsics_experimental_status.py`

### 后端注册

- `src/nextpas.core.simd.sse2.pas`（SSE2 的注册逻辑当前保留在主单元内，作为稳定边界的一部分）
- `src/nextpas.core.simd.sse2.i386.register.inc`
- `src/nextpas.core.simd.sse3.register.inc`
- `src/nextpas.core.simd.ssse3.register.inc`
- `src/nextpas.core.simd.sse41.register.inc`
- `src/nextpas.core.simd.sse42.register.inc`
- `src/nextpas.core.simd.avx2.register.inc`
- `src/nextpas.core.simd.avx512.register.inc`
- `src/nextpas.core.simd.neon.register.inc`
- `src/nextpas.core.simd.riscvv.register.inc`

### 后端辅助区块

- `src/nextpas.core.simd.avx2.facade.inc`
- `src/nextpas.core.simd.avx512.facade.inc`
- `src/nextpas.core.simd.avx512.fallback.inc`
  - 当前是故意保留的空 include 边界：旧 AVX512 fallback pass-through wrappers 已退场，`MemDiffRange/BytesIndexOf` 直接复用 cloned AVX2 slots
- `src/nextpas.core.simd.avx512.mask_sat.inc`
- `src/nextpas.core.simd.neon.facade_asm.inc`
- `src/nextpas.core.simd.neon.facade_scalar.inc`
- `src/nextpas.core.simd.neon.facade_platform.inc`
  - 当前是故意保留的空 include 边界：permanently-scalar NEON platform facade wrappers 已经退场，dispatch table 直接复用 canonical base scalar slots
- `src/nextpas.core.simd.neon.dot.inc`
  - 当前是故意保留的空 include 边界：wide dot wrappers 已退场，dispatch table 继续复用 canonical base scalar slots
- `src/nextpas.core.simd.neon.scalar_fallback.inc`

### 族级实现（代表性）

- `src/nextpas.core.simd.avx512.f32x16_*.inc`
- `src/nextpas.core.simd.avx512.f64x8_*.inc`
- `src/nextpas.core.simd.avx512.i32x16_*.inc`
- `src/nextpas.core.simd.avx512.i64x8_*.inc`
- `src/nextpas.core.simd.avx512.u32x16_family.inc`
- `src/nextpas.core.simd.avx512.u64x8_family.inc`
- `src/nextpas.core.simd.avx512.i16x32_family.inc`
- `src/nextpas.core.simd.avx512.i8x64_family.inc`
- `src/nextpas.core.simd.avx512.u8x64_family.inc`
- `src/nextpas.core.simd.avx2.f32x8_*.inc`
- `src/nextpas.core.simd.avx2.f64x4_*.inc`
- `src/nextpas.core.simd.avx2.i32x8_family.inc`
- `src/nextpas.core.simd.avx2.wide_emulation.inc`
- `src/nextpas.core.simd.neon.scalar.*.inc`

这份清单的用途不是“让你全部读完”，而是帮你在改动前快速定位影响面。


## 命名规则

当前 include 文件名基本遵循这几个模式：

- `*.register.inc`：多数 backend 的后端注册与 initialization（`SSE2` 当前保留在主单元）
- `*.facade.inc`：门面、helper、fallback 快路径
- `*.family.inc`：单个向量族或一组同类操作
- `*.intf.inc` / `*.impl.inc`：主单元拆出来的接口/实现配对
- `*.scalar.*.inc`：NEON 这类后端的标量回退细分片段

推荐继续遵守两个约定：

1. **先后端，后主题**
   - 例如 `avx512.f32x16_math.inc`
   - 而不是把主题放前面，避免排序和 grep 时失焦

2. **名字描述“边界”而不是“意图”**
   - `mask_sat.inc`、`wide_loadstore.inc`、`framework.impl.inc` 这种命名更容易定位真实内容
   - 避免 `misc.inc`、`helpers2.inc` 这种泛名

如果一段代码很难起一个清晰名字，通常也意味着它还不适合继续物理拆分。

## 目录速查

下面这份统计不是精确的代码规模报告，而是帮助维护者快速判断“哪里已经拆得很多，哪里最好别再动”。

| 主题 | include 数量 | 说明 |
|------|-------------|------|
| `dispatch` | 0 | 主逻辑仍集中在 `src/nextpas.core.simd.dispatch.pas` |
| `cpuinfo` | 0 | 后端判断主逻辑仍集中在 `src/nextpas.core.simd.cpuinfo.pas` |
| `sse2` | 14 | 已有一定拆分，但继续细拆风险明显升高 |
| `avx2` | 16 | family/facade 收口较充分 |
| `avx512` | 29 | family 拆分最充分 |
| `neon` | 20 | facade/fallback/family 已较充分拆分 |
| `riscvv` | 3 | 仍偏集中，但主入口已明确 |

用法很简单：

- 想加新功能时，先看这个 backend 是不是已经有合适的 include 边界。
- 想继续重构时，先问自己：这是在“补清晰边界”，还是在“把已经很碎的东西继续打碎”。

后者通常不值得。

## 维护者检查表

改动 `SIMD` 代码前，建议快速过一遍这个清单。

### 改动前

- 确认你改的是哪一层：主入口、dispatch/cpuinfo、后端 register、后端 family，还是 helper/facade。
- 先找对应的 `*.inc`，不要默认主文件就是唯一真实位置。
- 如果改动涉及 backend 选择、hook、能力检测，优先看 `dispatch` / `cpuinfo`，不要只改单个 backend。
- 如果改动涉及 `SSE2`，先判断是不是值得做；很多时候“保持稳态”比继续细拆更好。

### 改动后

日常改动至少跑这四条（快门禁 / 基础门禁）：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh check
bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DispatchAPI
bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DirectDispatch
bash tests/nextpas.core.simd/BuildOrTest.sh gate
```

说明：

- `check` 负责编译卫生、基础 runner parity，以及默认启用的轻量静态检查；其中 `wiring-sync` 现在默认执行，如需临时跳过要显式设 `SIMD_CHECK_WIRING_SYNC=0`。
- runner parity 当前只允许两条刻意保留的 Windows-only batch alias：`evidence-win` 与 `evidence-win-verify`。它们服务 native Windows evidence capture/verify 手册，不应再被当成待清理的 drift action。
- `check` 现在还包含 `simdgen --verify`、`public-operator-surface`、`dispatch-read-scope`、`dataplane-consumer-scope`、`direct-dispatch-scope`、`metadata-query-scope`、`implementation-matrix-sync`、`register-truthfulness --strict` 与 experimental isolation：`simdgen --verify` 只守住 `src/generated/nextpas.core.simd.*.inc` 等于 canonical type-order 生成器输出，不等于完整 public surface 证明；`public-operator-surface` 把 unsigned `VecU*Add/Sub/Mul/And/Or/Xor/Not` 和 `nextpas.core.simd` 默认 operator 声明/实现/委派绑在一起，并同时读取 generated facade 声明和主门面手写补充面；`dispatch-read-scope` 把 `GetDispatchTable` 的直接读取限制在 `dispatch` / `dataplane` / `runtime` 这三处内部单元；`dataplane-consumer-scope` 把 `GetCurrentSimdDataPlane` / `GetCurrentSimdDataPlaneDispatch` / `RebindSimdDataPlane` 的直接消费限制在 `dataplane` / `direct` / `public ABI` / façade companion surfaces，防止其他模块长出第二条 publication-consumer path；`direct-dispatch-scope` 把 `GetDirectDispatchTable` 的直接读取限制在 `api` / `arrays` / `ops` / `direct` 这几个 companion fast-path surface，防止其他模块再长出新的 direct fast-path 边界；`metadata-query-scope` 则把 `GetBackendInfo` / `TryGetRegisteredBackendDispatchTable` / backend text getters 的直接使用限制在 `dispatch` / `runtime` / `public ABI` / `backend adapter` 内部，防止 façade / companion surfaces 又长出第二条 metadata truth path；`implementation-matrix-sync` 会 fail-close active `docs/nextpas.core.simd.implementation-matrix.md` 与 key-slot / bounded-frontier ledger 的漂移，避免 working ledger 和当前实现护栏长期分叉。
- `gate` 负责日常改动使用的快门禁 / 基础门禁；它会串联主要模块回归，并默认包含 `contract-signature` 与 `publicabi-signature` 这类结构护栏，但不会默认打开所有重检查。
- `gate` 默认包含 `public-operator-surface`，防止生成/手写 `VecU*` façade 面继续扩展时漏掉 `uses nextpas.core.simd;` 下的 operator 编译边界。
- `gate` 现在还默认包含 `publicabi-concurrent-chain`，固定重跑历史上真实炸过的组合：`TTestCase_PublicAbi,TTestCase_SimdConcurrentPublicAbi,TTestCase_SimdConcurrentFramework`。
- 如果你明确改了 `TSimdBackendInfo` / `TSimdDispatchTable` 的声明形状，先单独跑：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh contract-signature
python3 tests/nextpas.core.simd/check_dispatch_contract_signature.py --dump-current
```

只有在这是**有意的 in-repo contract 变更**时，才更新 checker 里的 expected signature。

如果你明确改了 public ABI wrapper 的声明/常量/consumer mirror，再额外跑：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh publicabi-signature
python3 tests/nextpas.core.simd/check_public_abi_signature.py --dump-current
```

准备 closeout / release 时，再补这一条：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict
```

`gate-strict` 是发布门禁 / 完整门禁，会在 `gate` 的基础上额外打开性能烟测、repeat、non-x86 / evidence 等更重的检查。

`interface-completeness` checker 的默认 JSON/Markdown 产物现在都应落到 `tests/nextpas.core.simd/logs/`。只有在你明确要刷新 tracked doc 时，才显式传 `--md-file tests/nextpas.core.simd/docs/interface_implementation_completeness.md`。

`coverage` checker 现在也会把默认证据落到 `tests/nextpas.core.simd/logs/intrinsics_coverage.{txt,json}`；如果只是走 `gate` / `gate-strict`，直接复用这里的产物即可，不需要再从 stdout 手工摘结果。当前这条证据除了 `SSE/MMX/AVX2/AES/SHA` 直测映射外，也会固定检查 `intrinsics.x86.sse2` raw-leaf surface：要求代码级 `missing=0`，并把当前 `simd_*` witness floor 收成 `sse2_min_refs=2`。当前 fresh 状态下，这条 `SSE2` coverage guardrail 已经不再需要 side-effect helper allowlist。

### 出现异常时先怀疑什么

- `Text file busy`：通常是并发构建/运行冲突，不一定是代码回归。
- `backend_slot_counts` 异常下降：通常是 checker 没跟上 `{$I ...}` include，先看脚本是否递归展开本地 include。
- `Function nesting > 31`：通常是 Pascal 文件中把声明区/实现区切错了，不要继续叠加拆分。
- 链接错误或 VMT 缺失：优先检查单元引用和 initialization / RegisterTest / RegisterBackend 的入口有没有被破坏。

### 什么时候跑哪种门禁

- 日常改动、局部修正、文档同步：优先跑 `check` + 定向 suites + `gate`。
- closeout、发布前回归、需要更强证据链时：在上面的基础上再跑 `gate-strict`。
- 如果你只是确认脚本/文档口径没有漂移，先看 `BuildOrTest.sh` 的 `gate` / `gate-strict` usage 和 gate-summary profile 字段。

### 并发或预演时用隔离输出

如果你在同一台机器上并发跑多个 `SIMD` helper，或者只是想预演 closeout 而不污染默认 `bin2/lib2/logs`，优先设置 `SIMD_OUTPUT_ROOT`。

Run:
```bash
SIMD_OUTPUT_ROOT=/tmp/simd-run-123 bash tests/nextpas.core.simd/BuildOrTest.sh gate
```

或者：
```bash
SIMD_OUTPUT_ROOT=/tmp/simd-run-123 bash tests/nextpas.core.simd/BuildOrTest.sh evidence-linux
```

这会把主 runner 的 `bin2/lib2/logs` 改写到新根目录下；`cpuinfo`、`cpuinfo.x86` 与 `publicabi` 子 runner 在 shell 链路里也会自动落到 `cpuinfo/`、`cpuinfo.x86/`、`publicabi/` 子目录。`run_all_tests` 过滤链里尊重 `SIMD_OUTPUT_ROOT` 的 simd 模块则会落到 `run_all/<module>/`，避免覆盖顶层 gate 证据文件。
如果你想回收这次隔离 run 的全部产物，直接对同一个根执行 `SIMD_OUTPUT_ROOT=/tmp/simd-run-123 bash tests/nextpas.core.simd/BuildOrTest.sh clean`；主 runner 现在会同时删除顶层 `bin/lib`、这些子目录和 `run_all/`。

Windows batch runner 也已经接入同名环境变量，但这部分目前仍缺 Windows 实机验证。

### 什么时候该停手

如果你发现自己开始：

- 为了拆分而拆分
- 需要跨多个后端同时大改
- 需要改测试文件结构才能继续
- 在 `SSE2` 上持续碰编译器边界

那通常说明这一轮已经不适合继续做物理拆分了。改做文档、清单和设计说明，收益往往更高。

## 推荐继续整理的区域

如果后续还要继续做低风险整理，优先顺序建议如下：

1. 文档同步与阅读地图
2. `dispatch` / `cpuinfo` 的说明补充
3. 已经 include 化的后端片段做命名统一与目录清单整理
4. 小范围 helper 抽离

也就是说，接下来更适合做“结构可读性提升”，而不是继续大量物理拆分。

## 暂时不要再拆的区域

### `src/nextpas.core.simd.sse2.pas`

这是当前最接近风险边界的后端。

原因很简单：

- 它既承担 128-bit 基线实现，又承担很多 256/512 的仿真路径。
- 里面有大量 fallback、宽向量分解、mask/select、舍入与数学函数的交错实现。
- 继续细拆时，Pascal 对函数声明 / 实现布局的要求比较苛刻，稍不注意就容易触发编译问题。

结论：

- 可以继续读、继续审查。
- 可以补文档、补清单。
- 但不建议再做高频的物理拆分，除非先专门做一次针对 `sse2` 的重构设计。

## 读后端时怎么找入口

建议优先看这些片段：

- 注册入口：这个后端到底注册了哪些能力。多数 backend 看 `*.register.inc`，`SSE2` 直接看 `sse2.pas`
- `*.facade.inc`：这个后端的 mem/text/search/bitset 快路径在哪里
- `dispatch` / `cpuinfo`：这个后端什么时候会被选中

然后再去看 family 实现，比如：

- `f32x8`
- `f64x4`
- `i32x16`
- `u8x64`

不要一上来就整文件从头读到尾，那样最容易丢上下文。

## 回归时优先跑什么

改动结构但不改语义时，优先回归这些：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DispatchAPI
bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DirectDispatch
bash tests/nextpas.core.simd/BuildOrTest.sh gate
```

这三项足够覆盖：

- dispatch table 是否还完整
- direct dispatch 是否还跟随主 dispatch
- 关键 gate、coverage、adapter、wiring 是否保持稳定

## 一句话原则

继续维护这个模块时，优先做：

- 结构说明
- 命名统一
- 小块 helper 收口
- 明确稳定边界

尽量少做：

- 对 `SSE2` 这种基线大后端的继续硬拆
- 对测试大文件的物理拆分
- 没有专门设计前的大规模跨后端重排

---

## Known Technical Debt (2026-05-26 审计)

以下为已识别但暂不处理的架构级问题：

| 项目 | 描述 | 影响 |
|------|------|------|
| BuildOrTest.sh 膨胀 | 8858 行，含 closeout/rehearsal/gate 等非核心逻辑 | 维护成本高 |
| 辅助脚本过多 | 41 Python + 32 shell = ~15K 行 | 新人上手困难 |
| ArrayAdd 加速比低 | 1.3x（理论 4-8x），疑似内存带宽瓶颈 | 性能未充分发挥 |
| Dispatch 开销 | 19-23 ns/call，单向量操作占比高 | 批量操作不受影响 |
| LoongArch/SVE/SVE2 | 有 intrinsics 源码但无测试和后端集成 | 功能不完整 |
