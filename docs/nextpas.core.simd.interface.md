# nextpas.core.simd 接口分层与命名约定

这份文档专门收口 `simd` 模块的接口设计结论。目标只有一个：把公开层次、canonical 入口、兼容别名说死，避免继续把不同语义的 “available / active / best backend” 混在一起。

## 结论

当前 `simd` 的接口问题，核心不是能力缺失，而是历史别名过多、层次容易误读。这个 round 的最终口径是：

- `nextpas.core.simd` 是总 façade，负责向量/数学入口，并提供少量高频 runtime convenience wrapper
- `nextpas.core.simd.api` 只负责 mem/text/stat data-plane façade
- `nextpas.core.simd.runtime` 是 backend control-plane 与 runtime state 的 canonical 入口
- `nextpas.core.simd.cpuinfo` 是 CPU/OS capability 视图的 canonical 入口
- `nextpas.core.simd.dataplane` 是内部 publication seam，负责发布热点调用面会消费的 binding snapshot
- `public ABI wrapper` 是面向外部调用方的 POD-only 稳定包装面，但不是 `TSimdDispatchTable` 的公开版
- `nextpas.core.simd.direct` 是仓库内 direct dataplane companion，不是新的 control-plane 入口
- 所有 legacy alias 继续保留兼容，但新代码、示例、文档默认只使用 canonical 名称

## 分层职责

### `nextpas.core.simd`

- 面向业务调用方的一站式入口
- canonical 暴露向量/数学 façade
- 额外重导出少量 runtime / cpuinfo convenience wrapper，便于常见调用方不分层导入

### `nextpas.core.simd.api`

- 只放 data-plane façade
- 典型入口：`MemEqual`、`MemFindByte`、`Utf8Validate`、`AsciiIEqual`、`BytesIndexOf`
- 不承担 backend 选择、CPU 能力判断、注册状态查询

### `nextpas.core.simd.runtime`

- canonical control-plane
- canonical runtime state view
- canonical dispatchable / registered / active backend 语义
- `TSimdRuntimeSnapshot` 类型也归这个单元所有；如果调用方要显式声明 snapshot 变量，应该直接 `uses nextpas.core.simd.runtime`
- backend 列表容器 `TSimdBackendArray` 属于 `nextpas.core.simd.base`，`runtime` / `cpuinfo` 只是返回它

### `nextpas.core.simd.cpuinfo`

- canonical CPU/OS capability view
- 只回答“这台机器/当前 OS 能不能用”
- 不回答“当前二进制是否已注册”或“当前是否可派发”

### `nextpas.core.simd.dispatch`

- 更低层的 dispatch contract 与维护入口
- 仍然稳定，但不再是普通调用方默认 control-plane API
- 主要面向维护、测试、底层 wiring
- 是 control-plane truth source，不负责热点调用面的已绑定发布

### `nextpas.core.simd.dataplane`

- 内部 publication seam，不属于普通调用方公开 API
- 负责按当前 published dispatch 构造 data-plane binding snapshot
- 这份 snapshot 会被 `simd.pas` façade fast-path、本地 dispatch mirror、public ABI wrapper、`nextpas.core.simd.direct` 共同消费
- 不负责 backend 选择，不替代 `dispatch` / `runtime`

### `public ABI wrapper`

- 物理位置是 `src/nextpas.core.simd.public_abi.intf.inc` / `impl.inc`
- 逻辑上挂在 `nextpas.core.simd` 主入口旁边，承载 external stable wrapper
- 只暴露 POD-only metadata 和 `cdecl` public API table
- 不是 `TSimdDispatchTable` 的外部 ABI 承诺面

### `nextpas.core.simd.direct`

- 仓库内的 direct dataplane companion
- 读取当前已发布的 dispatch snapshot
- 适合热点路径、测试和 wiring 使用
- 不负责 backend 选择，不替代 `runtime` / `dispatch`

## 实现层口径

这一层不面向普通调用方，但必须统一口径：

- `nextpas.core.simd.*` backend unit：`backend adapter / backend assembly layer`
- `nextpas.core.simd.intrinsics.*`：`raw ISA leaf / low-level semantic leaf`
- `dispatch + dataplane`：`control/publication seam`

职责切分：

- backend adapter 负责 `TVec*` / `TMask*` façade 语义、dispatch 注册、backend 能力接线、必要的多寄存器拼装与 façade helper
- `dispatch` 负责 control-plane truth 与 in-repo dispatch contract
- `dataplane` 负责已绑定热点路径 publication
- raw ISA leaf 只负责原始寄存器或原始 intrinsic 风格接口，例如 `TM128/TM256/TM512`
- raw ISA leaf 不负责 dispatch table 注册
- raw ISA leaf 不负责 façade 级 `TVec*` 公开语义
- raw ISA leaf 不负责 backend selection / runtime control-plane

当前 SSE2 的专门判断：

- `src/nextpas.core.simd.sse2.pas` 是当前 backend adapter truth source
- `src/nextpas.core.simd.intrinsics.x86.sse2.pas` 是当前活跃的 SSE2 raw leaf，也是已落地的 128-bit 委托前沿
- 历史 `src/nextpas.core.simd.intrinsics.sse2.pas` wrapper 已 retire，不再是 live 单元

对应真相表：

- `docs/SIMD_BACKEND_TRUTH.md`
- `docs/SIMD_INTRINSICS_DISPOSITION.md`
- `docs/SIMD_SSE2_MIGRATION_MAP.md`

如果你这次讨论的是“为什么不能把 backend adapter 整层拿掉、直接做 façade -> intrinsics 两层直通”，统一以 `docs/SIMD_LAYERING_IMPLEMENTATION.md` 为准。

## 四层 backend 语义

| 语义 | 定义 | canonical 入口 |
|------|------|----------------|
| `supported_on_cpu` | 当前 CPU/OS 能力允许 | `cpuinfo.GetSupportedBackendList` / `cpuinfo.GetBestSupportedBackend` |
| `registered` | 当前二进制已经注册 | `runtime.GetRegisteredBackendList` / `runtime.IsBackendRegisteredInBinary` |
| `dispatchable` | CPU 支持 + 已注册 + `BackendInfo.Available=True` | `runtime.GetDispatchableBackendList` / `runtime.GetBestDispatchableBackend` |
| `active` | 当前真正生效的 backend | `runtime.GetCurrentRuntimeSnapshot` / `runtime.GetCurrentBackend` |

规则：

- 不再把一个含糊的 `available` 当通用总称
- `cpuinfo` 的 “available” 历史别名仍表示 `supported_on_cpu`
- façade / runtime 的 `GetAvailableBackendList` 历史别名表示 `dispatchable`

## Canonical 名称

### CPU capability

- `GetCPUInfo`
- `IsBackendSupportedOnCPU`
- `GetSupportedBackendList`
- `GetBestSupportedBackend`

### Runtime state

- `GetCurrentRuntimeSnapshot`
- `GetCurrentBackend`
- `GetCurrentBackendInfo`
- `GetRegisteredBackendList`
- `IsBackendRegisteredInBinary`
- `GetDispatchableBackendList`
- `GetBestDispatchableBackend`

### Runtime control-plane

- `TrySetCurrentBackend`
- `SetCurrentBackend`
- `ResetCurrentBackendSelection`

## Compatibility aliases

这些接口现在保留，但只按 compatibility alias 理解：

- active 文档、示例和新代码默认只使用 canonical 名称
- compatibility alias 只应该出现在兼容说明、迁移映射和契约回归测试里
- 如果你在新文档里需要写 legacy 名称，必须同时给出唯一 canonical 对应项，不能把它写成并列推荐入口

### `cpuinfo` aliases

- `GetSupportedBackends` -> `GetSupportedBackendList`
- `GetAvailableBackends` -> `GetSupportedBackendList`
- `GetBestBackendOnCPU` -> `GetBestSupportedBackend`
- `GetBestBackend` -> `GetBestSupportedBackend`

### `runtime` / façade aliases

- `GetCPUInfo`：`nextpas.core.simd` 直接重导出的 canonical convenience wrapper
- `GetCurrentSimdRuntimeSnapshot` -> `GetCurrentRuntimeSnapshot`
- `GetAvailableBackendList` -> `GetDispatchableBackendList`
- `GetCPUInformation` -> `GetCPUInfo`
- `TryForceBackend` -> `TrySetCurrentBackend`
- `ForceBackend` -> `SetCurrentBackend`
- `ResetBackendSelection` -> `ResetCurrentBackendSelection`

### `dispatch` low-level names

- `IsBackendAvailableOnCPU`（low-level compatibility alias；新代码改用 `cpuinfo.IsBackendSupportedOnCPU`）
- `GetActiveBackend`
- `TrySetActiveBackend`
- `SetActiveBackend`
- `ResetToAutomaticBackend`

这些名字不是废弃实现，但已经降级为低层入口；新代码不再默认推荐直接面向它们写 control-plane。

## 推荐用法

### 查询 CPU 能力

```pascal
uses nextpas.core.simd.cpuinfo;

LBackends := GetSupportedBackendList;
LBest := GetBestSupportedBackend;
```

### 查询当前 runtime 状态

```pascal
uses nextpas.core.simd.runtime;

LSnapshot := GetCurrentRuntimeSnapshot;
LDispatchable := GetDispatchableBackendList;
```

### 强制切换 backend

```pascal
uses nextpas.core.simd.runtime;

if TrySetCurrentBackend(sbScalar) then
  DoSomething;
ResetCurrentBackendSelection;
```

## 本轮接口审查的封边标准

本轮之后，接口层按下面标准理解：

- 文档、示例、smoke 默认只展示 canonical 名称
- legacy alias 只在兼容说明和契约测试里出现
- `runtime` 与 `cpuinfo` 的语义边界明确分离
- `dispatch` 保留为低层 contract，不再承担默认公开 control-plane 教程入口

下一轮如果继续审查，应只看实现质量、线程安全细节、fallback/adapter wiring 等实现问题，而不是重新争论公开接口叫什么。
