# Findings: whole-repo nextPas/core convention audit

## Scope

- 当前目标是审计整仓是否遵守 `docs/design-conventions.md`。
- 本轮以 `src/` 与 `tests/` 为主，结合 `docs/l1-goal-tree.md`、`docs/platform-goal-tree.md`、`docs/ARCHITECTURE.txt` 做静态合规审计。

## Baseline truths

- 当前共享工作树是脏的，审计阶段只读，不应把现有无关改动误判为本轮输出。
- `src/*.pas` 的单元名与文件名整体保持一致；未发现 `src/*.pas` 的非 `nextpas.core.*` 单元声明。
- `src/generated/` 虽然违背“源码平铺在单一 `src/`”的字面规则，但已在 [docs/ARCHITECTURE.txt](/home/dtamade/projects/nextPas/core/docs/ARCHITECTURE.txt:85) 明确登记为 SIMD 生成产物目录，属于文档化例外，不应按普通违规处理。

## Confirmed compliance

- 命名基线基本干净：
  - `src/*.pas` 单元名全小写 dotted namespace，且与文件名匹配。
  - `src/` 中未发现额外的非 `nextpas.core.*` 源单元。
- `platform.*` 本轮静态抽查未发现直接 `uses Linux|UnixType|BaseUnix|PThreads|Windows` 的 owner-boundary 违规；平台层多数仍通过 `platform.<host>.base/ffi` 组织。

## Confirmed violations

### 1. L0 `mem` 模块系统性越层

按 `docs/design-conventions.md` 的层级定义，`mem` 属于 L0，应只依赖 RTL 或同层；但当前有多处直接依赖 L1/L2：

- [nextpas.core.mem.blockpool.sharded.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.mem.blockpool.sharded.pas:18) 直接 `uses nextpas.core.sync`。
- [nextpas.core.mem.manager.rtl.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.mem.manager.rtl.pas:27) 直接 `uses nextpas.core.sync` / `nextpas.core.sync.mutex`。
- [nextpas.core.mem.pool.slab.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.mem.pool.slab.pas:10) 直接 `uses nextpas.core.platform.time`。
- [nextpas.core.mem.memory_map.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.mem.memory_map.pas:33) 直接 `uses nextpas.core.text.conv` 与 `nextpas.core.fs.util`。
- [nextpas.core.mem.memory_map.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.mem.memory_map.pas:39) 还直接 `uses Windows / BaseUnix / Unix`，绕开了 `platform` owner boundary。

这不是个别点，而是 `mem` 并发池、内存映射、manager/installers 多条子线同时越层。

### 2. L0 `simd` 模块系统性依赖 L1 文本层

`simd` 在目标树中也是 L0，但 CPU 信息相关子模块直接依赖 L1 文本工具：

- [nextpas.core.simd.cpuinfo.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.simd.cpuinfo.pas:9) 直接 `uses nextpas.core.text.conv`。
- [nextpas.core.simd.cpuinfo.base.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.simd.cpuinfo.base.pas:157) 在 implementation 直接 `uses nextpas.core.text.conv`。
- [nextpas.core.simd.cpuinfo.lazy.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.simd.cpuinfo.lazy.pas:134) 直接依赖 `nextpas.core.text.conv`、`nextpas.core.text.strings`，并额外依赖 `nextpas.core.os.env`。

这说明 `simd` 的 CPU info 子层并未维持严格的 L0 边界。

### 3. 测试组织大面积不符合规范目录形态

`docs/design-conventions.md` 明确要求测试项目使用 `tests/nextpas.core.<module>/test_xxx/test_xxx.lpr` 形态，[规则见 499-526 行](/home/dtamade/projects/nextPas/core/docs/design-conventions.md:499)。

当前存在系统性偏差：

- `tests/nextpas.core.tls/` 顶层直接存在 `291` 个 `program ...` 的 `.pas` 测试入口，而不是独立 `test_xxx/test_xxx.lpr` 项目。
- `tests/nextpas.core.simd/` 顶层直接存在 `75` 个 `program ...` 的 `.pas` 测试入口。
- 根级还存在 [tests/bench_bytes_simd.pas](/home/dtamade/projects/nextPas/core/tests/bench_bytes_simd.pas:1)，它既放在 `tests/` 根下，又是 benchmark 语义，和“benchmark 应在 `benchmarks/` 下”冲突。

具体例子：

- [tests/nextpas.core.tls/unit/test_certificate_pinning.pas](/home/dtamade/projects/nextPas/core/tests/nextpas.core.tls/unit/test_certificate_pinning.pas:1) 使用 `program TestCertificatePinning;`，既不是 `.lpr`，也不是小写程序名。
- [tests/nextpas.core.simd/test_parallel_gemm.pas](/home/dtamade/projects/nextPas/core/tests/nextpas.core.simd/test_parallel_gemm.pas:1) 文件名为 `test_parallel_gemm.pas`，但程序名是 `test_parallel`，与规范期望的项目名一致性不符。

### 4. 公开模块 `nextpas.core.contracts` 缺少直属测试目录

- [src/nextpas.core.contracts.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.contracts.pas:1) 是公开单元，但当前没有对应 `tests/nextpas.core.contracts/` 目录，也未检出直接引用它的测试入口。
- 这与“公开接口完成必须有单测”的项目纪律不一致，至少应视为覆盖缺口。

## Accepted or likely accepted deviations

- `src/generated/*.inc`
  - 与规范字面要求冲突，但已在架构文档中明确登记为 `simdgen` 生成产物目录，当前更适合视为“文档化例外”，而不是立即整改的违规。
- `nextpas.core.os.env`、`nextpas.core.path`、`nextpas.core.time.base`
  - 这些兼容/辅助模块不在设计规范的简化模块表中，但在源码与文档中被实际消费；更像“需要进入正式模块注册表”的历史兼容层，而不是立刻判死刑的坏命名。

## Spec drift discovered during audit

- `docs/design-conventions.md` 与 `docs/l1-goal-tree.md` 对部分模块层级存在漂移：
  - `args` / `process` 在设计规范里被列入 L2，但在目标树里被列在 L3。
  - `log` 在设计规范里属于 L3，但目标树里列在 L2。
- 如果后续要自动化层级审计，必须先统一这份模块注册口径，否则同一个依赖会因“以哪份文档为准”得到不同结论。

## Parallel Batch: crypto/rsa.ct scratch zeroization

- `CTNatAlloc(out ...)` 在 `rsa.ct` 是一个真实的安全坑：同一个 `TCTNat` 变量被反复复用时，旧 heap buffer 会先被释放，再分配新数组，zeroization 根本来不及执行。
- 旧实现只在 `TryRSACTSignWithCRT` 成功路径尾部清理少量 scratch；一旦中途 `Exit`，包含私钥派生中间态的 heap scratch 会直接绕过清理。
- `CTMontMul` / `CTMontModExp` 自身也维护动态 scratch；如果不在内部收口清理，调用方 `finally` 只能覆盖最后一层变量，无法覆盖中间重分配。
- `pkcs8` 的 double-free 修复虽然已在源码里存在，但此前缺少一个“已成功 parse，再走 early-exit” 的 focused regression proof。
