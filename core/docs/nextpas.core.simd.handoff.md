# nextpas.core.simd 最终交接总结

这份文档给下一位维护者一个简短但完整的现状说明：现在这个模块已经整理到什么程度、哪些边界比较稳、接下来最值得做什么。

如果你只想看“现在该做什么”，再看 `docs/nextpas.core.simd.checklist.md`。

如果你这次接手的是 backend / intrinsics / SSE2 分账，不要先翻历史计划，先看：

- `docs/SIMD_BACKEND_TRUTH.md`
- `docs/SIMD_INTRINSICS_DISPOSITION.md`
- `docs/SIMD_SSE2_MIGRATION_MAP.md`
- `docs/SIMD_LAYERING_IMPLEMENTATION.md`

如果你这次接手的是“按文档继续做结构实施”，要再单独记住一条：

- 当前推荐的全局形态不是只背“三层”，而是 `public surface + control/publication seam + companion surfaces + backend adapters + raw leaves`
- 其中 `dispatch + dataplane` 是共享中间缝；不要把 `dataplane` 继续当成隐藏 helper

## 当前状态

`nextpas.core.simd` 已经完成一轮较大规模的“低风险结构收口”。

重点不是改变语义，而是把原来集中在少数超大 Pascal 单元里的内容，按现有注释边界拆成主单元 + include 片段的结构，降低 review 成本和定位成本。

截至 `2026-05-21`，当前最重要的状态判断要单独记住：

- 代码侧已经是 green：
  - 最新 `gate` 为 PASS
  - 最新接口完整度检查为绿，`P0/P1/P2=0`
  - `linux_qemu_cpuinfo_nonx86_evidence` 已在 canonical gate 中 fresh PASS
- 发布级 closeout 现在也已经是 green：
  - cross-platform `freeze-status` 当前为 `ready=True / mainline-ready=True / cross-ready=True`
  - `cross_gate_required_steps` 已 PASS
  - `windows_preflight_latest` 已 PASS：`status=PASS code=OK`
  - `windows_evidence_verify` 已 PASS
  - `windows_sources_not_newer_than_evidence` 已 PASS
  - 当前 canonical fresh Windows evidence 批次为 `SIMD-20260521-153`，对应 GH run `26230362365`
- 当前 public API 覆盖也已经被 canonical gate 固化：
  - canonical `public-api-coverage` 现在默认按 `strict-thin` 运行
  - future `thin > 0` 会直接让 `gate` / `gate-strict` 变红
- 这不是新的接口/实现质量问题，也不再是 billing / freshness blocker：
  - 当前 `HEAD` 的更准确交接口径应是 `code-green / cross-ready`
  - 历史文档里“Windows 已归档/已闭环”的标记仍只能理解成旧批次归档事实；但这一次 current `HEAD` 也已经重新拿回 cross-ready
  - 默认不要再重开 closeout 讨论；下一步应回到 real implementation residual、family qualification 或 raw parity 线

当前已经完成的方向包括：

- 主入口层收口：`simd.pas` 的类型与框架包装已拆到 include。
- 派发层收口：`dispatch` 的 hook 管理、`cpuinfo` 的 backend 选择已拆出。
- 发布缝收口：`dataplane` 已经承担 façade fast-path / public ABI / direct 共用的 published binding 语义，不再只是局部缓存技巧。
- 后端注册区收口：主要 backend 的 register / initialization 区块已拆出。
- 后端辅助区收口：`AVX2`、`AVX-512`、`NEON` 的 facade / fallback / family 已经拆到较细粒度。
- 测试文件保持稳定：测试文件拆分尝试已回滚，不再继续沿那条路推进。
- 稳定边界已收紧：公开 façade 是稳定入口，`TSimdDispatchTable` 只按 in-repo dispatch contract 理解，不再误读成 public binary ABI。
- backend 状态语义已拉直：现在明确区分 `supported_on_cpu / registered / dispatchable / active` 四层视图。
- 性能收口已完成主判断：`VecI16x32Add`、`VecU8x64Max` 保留复用；`VecU32x16Mul` 仅观察；`VecU64x8Add`、`VecF32x4Add` 降级观察。
- dispatch contract 已补 machine-readable signature guard：`gate` 默认会校验 `TSimdBackendInfo` / `TSimdDispatchTable` 的声明签名没有漂移。
- public API 覆盖也已补 machine-readable thickness guard：`gate` / `gate-strict` 默认会把 `thin > 0` 当成 fail-close，而不再只是统计 `missing=0`

## 现在哪些地方比较稳

如果只是继续维护，不想冒险，这些区域可以认为已经进入“相对稳态”：

- `src/nextpas.core.simd.pas`
- `src/nextpas.core.simd.dispatch.pas`
- `src/nextpas.core.simd.dataplane.pas`
- `src/nextpas.core.simd.cpuinfo.pas`
- `src/nextpas.core.simd.public_abi.impl.inc`
- `src/nextpas.core.simd.direct.pas`
- `src/nextpas.core.simd.avx2.pas`
- `src/nextpas.core.simd.avx512.pas`
- `src/nextpas.core.simd.neon.pas`
- 对应的 `*.register.inc` / `*.facade.inc` / `*.family.inc`

这些文件不是不能继续改，而是已经完成了最有价值的结构性整理。继续改动时，更多应该是“按需修正”而不是“继续为拆分而拆分”。

## 哪些地方暂时不要再硬拆

### `src/nextpas.core.simd.sse2.pas`

这是当前最明确的稳定边界。

原因不是它不能维护，而是继续做细颗粒物理拆分时，风险已经明显高于收益：

- 它同时承担 128-bit 基线实现与大量 256/512 仿真路径。
- 它里面混合了 fallback、宽向量仿真、mask/select、舍入、数学函数等多个主题。
- Pascal 对声明区 / 实现区 / include 插入位置比较敏感，继续切细容易触发编译器级问题。

结论很简单：

- 可以继续读、继续修、继续补文档。
- 但不建议再做高频物理拆分，除非先单独做一版 `SSE2` 重构设计。

补一条当前已经冻结的归属判断：

- `src/nextpas.core.simd.sse2.pas` 是当前 SSE2 backend adapter truth source
- `src/nextpas.core.simd.intrinsics.x86.sse2.pas` 是当前活跃的 SSE2 raw leaf，但不是当前发布真相源
- 历史 `src/nextpas.core.simd.intrinsics.sse2.pas` wrapper 已 retire，不再属于 live tree

补一条当前已经冻结的结构判断：

- 这个仓库的正确目标不是“两层：façade -> intrinsics”
- 而是“三层：stable façade / control-plane -> thin backend adapter -> raw intrinsics leaf”
- 如果从整个模块视角再压一次，最优雅的说法是：
  - `public surface`
  - `control/publication seam`
  - `companion surfaces`
  - `backend adapters`
  - `raw leaves`
- 具体理由和实施纪律统一写在 `docs/SIMD_LAYERING_IMPLEMENTATION.md`

## 验证基线

结构性改动之后，最值得优先跑的是这三条：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DispatchAPI
bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_DirectDispatch
bash tests/nextpas.core.simd/BuildOrTest.sh gate
```

它们分别覆盖：

- dispatch table 映射是否仍完整
- direct dispatch 是否仍跟随主 dispatch
- gate / completeness / adapter / wiring / coverage 是否还稳定

如果是 release / closeout 收口，再补这两条：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict
bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status
```

`closeout-release` 已经是当前推荐的单一 release/closeout 入口。

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh closeout-release SIMD-YYYYMMDD-152
```

它固定把 `win-evidence-preflight -> impl-smoke-x86 -> closeout-host-local -> win-evidence-via-gh -> freeze-status` 串成一条 canonical 主线；只有在你明确要拆分诊断 Windows 手工路径或单独复验某一步时，才再退回下面这些低层 helper。
但当前 `HEAD` 还有一个明确前提条件：当前这条主线已经 fresh 收口到 `cross-ready=True`。只有当 future `freeze-status` 再次红在 `linux_sources_not_newer_than_gate` / `windows_sources_not_newer_than_evidence` 时，才先补 fresh evidence；只有当 future `win-evidence-preflight` 再次回到 `RECENT_BILLING_BLOCK` 时，才在 preflight 这一步停下，并按 `code-green / release-evidence-blocked` 交接。

如果需要 Windows 证据闭环，优先主入口：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-via-gh SIMD-YYYYMMDD-152
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status
```

如果走手工 Windows 实机路径，则顺序应为：`evidence-win-verify -> SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 + SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 + SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 + SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 + SIMD_GATE_CPUINFO_LAZY_REPEAT=3 gate -> win-closeout-finalize -> freeze-status`。

这里还有一个当前必须显式记住的前提：

- `evidence-win-verify` 只能在真实 Windows runner / Windows 实机上执行，且 `LAZBUILD` 必须解析到 native Windows `.exe/.bat/.cmd`
- 不要把 `LAZBUILD` 指到 `Z:\opt\...` 这类 Wine 可见但 `cmd.exe` 不能执行的 Linux ELF
- 本机 Wine 现在只算 batch smoke / 日志新鲜度探针，不算可 finalize 的 Windows evidence runner
- 若显式试 `SIMD_WIN_EVIDENCE_USE_BASH_GATE=1`，也只限 `cmd.exe` 真能解析 `bash` 的环境；当前本机 Wine 不属于这种环境，不要把它当成 host-side Unix bridge 逃生口

## 常见假失败

有些失败看起来像回归，其实只是运行方式问题。

### `Text file busy`

这通常是并发构建 / 运行同一个测试二进制导致的，不一定是代码问题。

处理方式：

- 顺序重跑同一命令
- 以顺序重跑结果为准

### `Function nesting > 31`

这通常表示 Pascal 文件的声明区 / 实现区 / include 边界被切坏了。

处理方式：

- 不要继续在坏状态上叠加拆分
- 先恢复到最近的稳定结构
- 再决定是否真的值得继续拆

## 后续最值得做的 3 件事

### 1. 保持文档同步

现在最有价值的工作，不是继续硬拆代码，而是让结构说明一直跟上代码现状。

优先维护：

- `docs/nextpas.core.simd.md`
- `src/nextpas.core.simd.README.md`
- `docs/nextpas.core.simd.maintenance.md`
- `docs/nextpas.core.simd.map.md`

### 2. 只做高 ROI 改动

如果未来要加功能或修 bug，建议只改真正需要动的层，且优先级按下面排：

- 第一优先级：稳定边界、evidence contract、runbook/真相源文档一致性
- 第二优先级：继续复用已证实 ROI 的 fast-path 模式（`VecI16x32Add`、`VecU8x64Max`）
- 第三优先级：`VecU32x16Mul` 仅低成本观察
- 降级观察：`VecU64x8Add`、`VecF32x4Add`

落到代码层时，仍然建议：

- 先看 `dispatch` / `cpuinfo`
- 如果问题落在 façade fast-path / public ABI / direct 绑定一致性，先看 `dataplane`
- 再看对应 backend 的 `register.inc`
- 最后看对应 family / facade include

不要一上来就大范围横跨多个 backend 重排。

### 3. 如需继续重构，先写设计

尤其是 `SSE2` 这种已经接近边界的文件。

如果真的还想继续做结构性重构，最好先写一页短设计，说明：

- 为什么还要拆
- 想拆哪一层
- 预计回报是什么
- 风险怎么控

没有这个前置设计时，继续硬拆通常得不偿失。

## 一句话交接

当前 `SIMD` 子系统已经完成了大部分高价值、低风险的结构收口；继续维护时，优先做 stable boundary / evidence / 文档真相源同步，以及少量高 ROI 改动，不建议再对 `SSE2` 做激进物理拆分，也不建议把低 ROI benchmark 项重新拉回主线。
