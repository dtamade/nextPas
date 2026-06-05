# nextpas.core.simd Public ABI Wrapper

> 本页描述的是 `nextpas.core.simd` 对外暴露的 **public ABI wrapper**。
>
> 它不是当前 `TSimdDispatchTable` 的直接公开版本。`TSimdDispatchTable` 仍然只是仓库内 dispatch contract。
>
> 如果你想看“到底承诺什么”，请继续看 `docs/simd/publicabi.stability.md`。

## 目标

这个 wrapper 解决的是两个问题：

- 给外部调用方一个 **POD-only**、可验证的稳定边界
- 避免热点路径出现“public wrapper 每次再去查内部 `TSimdDispatchTable`”的重复开销

因此它的原则是：

- 公开入口仍然在 `nextpas.core.simd`
- metadata 走 POD struct + 独立字符串查询
- data-plane 走 **已发布 snapshot + 稳定 `cdecl` 入口**

## 现在提供了什么

当前可用的 public ABI wrapper 入口：

- `GetSimdAbiVersionMajor`
- `GetSimdAbiVersionMinor`
- `GetSimdAbiSignature`
- `TryGetSimdBackendPodInfo`
- `GetSimdBackendNamePtr`
- `GetSimdBackendDescriptionPtr`
- `GetSimdPublicApi`
- `GetSimdPublicApiV2`

对应 POD 类型：

- `TFafafaSimdBackendPodInfo`
- `TFafafaSimdPublicApi`
- `TFafafaSimdPublicApiV2`

当前 ABI 版本：`1.3`（Major=`1`，Minor=`3`）。
当前 v2 table 版本：`2.0`。

## 后端元数据

`TFafafaSimdBackendPodInfo` 只保留 POD 字段：

- `StructSize`
- `BackendId`
- `CapabilityBits`
- `Flags`
- `Priority`

这里的 `Flags` 反映 4 层 backend 状态：

- `supported_on_cpu`
- `registered`
- `dispatchable`
- `active`

以及一层成熟度标志：

- `experimental`

字符串名称/描述不放进 struct，而是通过：

- `GetSimdBackendNamePtr`
- `GetSimdBackendDescriptionPtr`

单独查询。

## Public API Table

`GetSimdPublicApi` 返回的是一张**缓存的、已绑定的 public API table 指针**，不是当前内部 `TSimdDispatchTable`。

这意味着：

- 它返回的是 public-ABI 视图，不是内部 dispatch table 本体
- 后端切换后，内部会发布一张新的已绑定 snapshot
- 调用方可以缓存这张表并复用稳定 ABI 入口；如果需要最新 metadata，应在 backend 切换后重新取表
- 单次 `GetSimdPublicApi` 返回的 table 自身应当是自洽的 published snapshot

当前已绑定这些高 ROI façade：

- `MemEqual`
- `MemFindByte`
- `MemDiffRange`
- `SumBytes`
- `CountByte`
- `BitsetPopCount`
- `Utf8Validate`
- `AsciiIEqual`
- `BytesIndexOf`
- `MemCopy`
- `MemSet`
- `ToLowerAscii`
- `ToUpperAscii`
- `MemReverse`
- `MinMaxBytes`

这些函数指针使用 `cdecl`，适合外部 C ABI 调用。

## Public API Table V2

`GetSimdPublicApiV2` 在 v1 的 data-plane 函数集合上额外补充了两类 snapshot metadata：

- `SnapshotGeneration`
- `SnapshotFlags`

当前稳定语义是：

- `FAF_SIMD_PUBLIC_API_V2_FLAG_SNAPSHOT_BOUND` 表示这张表来自一次已发布的 snapshot
- `FAF_SIMD_PUBLIC_API_V2_FLAG_COMPAT_V1` 表示它与当前 v1 兼容视图对齐
- `FAF_SIMD_PUBLIC_API_V2_FLAG_DIRECT_DATA_PLANE` 仅在实现真的把函数指针直接绑定到 data-plane 时才应置位；调用方不要假设当前所有平台都一定带这个标志

对新调用方，推荐优先缓存 `GetSimdPublicApiV2` 的结果，而不是继续新接入 v1。
Pascal 侧最小可运行示例见 `examples/example_simd_public_api_v2.pas`。

其中带原地写入语义的入口，例如 `MemCopy`、`MemSet`、`ToLowerAscii`、`ToUpperAscii`、`MemReverse`，要求调用方提供**可写 buffer**；不要把只读或共享字符串存储直接当作原地修改目标。

## 性能语义

这张表的核心语义是：

- 初始化/切换后端时，dispatch hook 会先发布最新 target dispatch
- 调用方拿到表后可以缓存
- table 里的函数指针始终是稳定的 `cdecl` ABI 入口
- `GetSimdPublicApi` 和这些入口会在需要时 lazy refresh 到最新 published binding

也就是说，**不会在每次外部调用时重复查内部 dispatch table**。

即使初始化尚未完成等极少数兜底路径，也只会回到当前 published `dataplane`。
`public ABI wrapper` 不直接回读 `GetDispatchTable`，也不维护第二条 publication truth。

### Snapshot Boundary

这里要把边界说死：

- `GetSimdPublicApi` 的单次返回值承诺是**单份 published snapshot**
- 这个 snapshot 里的 `ActiveBackendId / ActiveFlags` 是冻结的 metadata
- `function pointers` 是稳定的 `cdecl` ABI 入口，不应被当成 backend 指纹
- 但它**不承诺**和另一个独立时刻调用的 `GetCurrentBackend` / `GetCurrentBackendInfo` 自动组成跨调用原子配对

也就是说，如果有并发 control-plane 写入正在发生：

- `SetCurrentBackend(...)`
- `ResetCurrentBackendSelection`
- `RegisterBackend(...)`
- `SetVectorAsmEnabled(...)`

那么两次独立 getter 观察到的是两个不同 published snapshot，并不自动构成 bug。

稳定态合同是：

- 控制面 API 已经返回
- 且没有新的并发 control-plane mutation

这时下面这些观察点应该重新收敛：

- `GetSimdPublicApi^.ActiveBackendId`
- `GetSimdPublicApi^.ActiveFlags`
- `GetCurrentBackend`
- `GetCurrentBackendInfo`
- `TryGetSimdBackendPodInfo(current_backend, ...)`

另外要注意一条实现边界：

- 旧的 cached table 仍然可以安全调用
- 但 control-plane 发生变化后，旧 table 里的函数指针会跟随最新 published data-plane
- 如果你需要**最新 metadata**，请重新调用 `GetSimdPublicApi`
- 如果你需要比较 backend 是否变化，不要比较函数指针地址，比较 `ActiveBackendId / ActiveFlags`

### 热点路径建议

推荐模式只有一个：

```pascal
var
  LApi: PFafafaSimdPublicApi;
begin
  LApi := GetSimdPublicApi;
  while ... do
    LApi^.MemEqual(...);
end;
```

不要把下面这种写法当成热点路径标准范式：

```pascal
while ... do
  GetSimdPublicApi^.MemEqual(...);
```

它是可用的，但不是推荐的 hot-loop 风格。

如果你想看当前仓库里对这件事的直接 benchmark，可以跑：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh perf-smoke
```

或：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh test --bench-only
```

其中会输出这些 public ABI 热点对照行：

- `HotMemEqPubCache`
- `HotMemEqPubGet`
- `HotMemEqDispGet`
- `HotSumPubCache`
- `HotSumPubGet`
- `HotSumDispGet`

它们用 32-byte 小负载对比：

- façade 调用
- 缓存后的 public API table 直调
- 循环内重复 `GetSimdPublicApi`
- 循环内重复 `GetDispatchTable`

benchmark 本身现在会把每个热点回调扩成 inner loop，并对 `PubCache / PubGet / DispGet`
做轮转采样，尽量减小固定顺序带来的热身偏置。

目的不是追求某个固定倍数，而是持续观察 public ABI 热点路径的几种调用形态。

当前 `perf-smoke` 也已经把这件事纳入自动检查：

- `PubGet` 必须明显快于 `DispGet`
- `PubCache` / `PubGet` 仍会输出并保留为观察项，但当前不再作为 hard fail
  因为 `GetSimdPublicApi` 是极薄的 inline getter，编译器可能把重复 getter 优化到与
  table cache 等价，甚至在个别样本里略快

也就是说，public ABI 热点路径现在不只是靠人工看 benchmark。

## 使用建议

### Pascal 侧

```pascal
var
  LApi: PFafafaSimdPublicApi;
  LHi, LLo: UInt64;
begin
  LApi := GetSimdPublicApi;
  GetSimdAbiSignature(LHi, LLo);

  if Assigned(LApi) and Assigned(LApi^.MemEqual) then
    if LApi^.MemEqual(@Buf1[0], @Buf2[0], Length(Buf1)) then
      WriteLn('equal');
end;
```

### C ABI smoke

仓库内已有最小 external smoke：

```bash
bash tests/nextpas.core.simd.publicabi/BuildOrTest.sh test
```

它会完成：

- 构建 shared library
- 校验导出符号（`readelf --wide --dyn-syms`）
- 通过 `dlopen + dlsym` 获取 public API table
- 对高 ROI façade 做最小 parity smoke

如果你只想先验证导出符号，不跑 C harness：

```bash
bash tests/nextpas.core.simd.publicabi/BuildOrTest.sh validate-exports
```

Windows 侧已有对等入口：

```bat
tests\nextpas.core.simd.publicabi\BuildOrTest.bat validate-exports
tests\nextpas.core.simd.publicabi\BuildOrTest.bat test
```

Windows smoke 通过 `publicabi_smoke.ps1` 完成：

- 校验 `fafafa_simd_*` 导出符号
- 调用 ABI version / signature / backend query
- 获取 public API table
- 执行最小 data-plane parity smoke
- batch runner 优先使用 `pwsh`，回退到 `powershell`；若两者都不存在则非零退出，避免 `publicabi-smoke` 被静默跳过
- shell / batch runner 都支持 `SIMD_OUTPUT_ROOT`；如果通过主 `simd` gate 链路调用，它会自动落到隔离根下的 `publicabi/` 子目录

### Machine-readable contract guard

除了 external smoke，仓库内现在还有一条 **machine-readable public ABI signature/layout checker**：

```bash
python3 tests/nextpas.core.simd/check_public_abi_signature.py --summary-line
```

它会守住这些基线：

- `TSimdBackend` / `TSimdCapability` 的枚举顺序
- `TFafafaSimdBackendPodInfo` / `TFafafaSimdPublicApi` 的声明与字段顺序
- public ABI getter / export alias 声明
- ABI flag / version / signature 常量
- `tests/nextpas.core.simd.publicabi/publicabi_smoke.h` 的 consumer-side struct/function typedef

也就是说，当前 public ABI 不再只靠 smoke 才能发现漂移。

主模块日常门禁里也已经带上这条验证：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh gate
```

其中会自动执行：

- `publicabi-signature`
- `publicabi-smoke`

## 当前边界

当前 **没有**做的事情：

- 不公开 `TSimdDispatchTable`
- 不公开 `TVec*` 按值 ABI
- 不把 Pascal managed string 带进 public ABI struct

如果未来要继续扩展，优先顺序应是：

1. 扩更多 pointer+len façade
2. 扩大 machine-readable contract 覆盖面（例如更多外部 consumer）
3. 再评估是否值得引入 vector ABI
