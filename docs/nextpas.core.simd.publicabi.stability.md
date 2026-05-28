# nextpas.core.simd Public ABI Stability

> 这页只回答一个问题：**public ABI wrapper 到底承诺什么，不承诺什么。**

## 当前承诺

当前 `nextpas.core.simd` 的 public ABI wrapper 承诺下面这些东西是稳定边界：

- `GetSimdAbiVersionMajor`
- `GetSimdAbiVersionMinor`
- `GetSimdAbiSignature`
- `TryGetSimdBackendPodInfo`
- `GetSimdBackendNamePtr`
- `GetSimdBackendDescriptionPtr`
- `GetSimdPublicApi`

以及对应的 POD 类型：

- `TFafafaSimdBackendPodInfo`
- `TFafafaSimdPublicApi`

当前 ABI 版本：`1.3`（Major=`1`，Minor=`3`）。

对外更具体地说，稳定的是：

- POD struct 的字段语义
- `cdecl` 调用约定
- `fafafa_simd_*` 导出符号名
- backend 状态四层语义
- 已进入 `TFafafaSimdPublicApi` 的那些 high-ROI façade 函数

当前 table 中已明确进入承诺面的 data-plane 函数包括：

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

## 当前不承诺

下面这些东西**不是** public ABI 承诺面：

- `TSimdDispatchTable`
- `TSimdBackendInfo`
- `TSimdBackendOps`
- backend.adapter / backend.iface 的内部组织
- Pascal managed string 的内存布局
- `TVec*` record 的按值 ABI

一句话：

**public ABI wrapper 是外部边界，内部 dispatch contract 不是。**

## backend 状态怎么理解

public ABI wrapper 继续沿用当前已经统一的四层语义：

- `supported_on_cpu`
- `registered`
- `dispatchable`
- `active`

这些语义在 `TFafafaSimdBackendPodInfo.Flags` 里表达。

调用方不应该把一个含糊的 “available” 当成总称。

## data-plane 语义

`GetSimdPublicApi` 返回的是一张**已绑定**的 public API table。

这里承诺的是：

- 调用方可以缓存这个 table
- table 中的函数指针是 `cdecl`
- 正常 data-plane 路径不会每次再去查内部 `TSimdDispatchTable`
- 函数指针是稳定 ABI 入口，而不是 backend 专属地址标签

也就是说，public wrapper 不是“再包一层重复分发”。

## refresh 语义

当前语义是：

- backend 变化后，dispatch hook 先发布新的 target dispatch
- 下一次 `GetSimdPublicApi` 或 public-ABI `cdecl` entrypoint 调用时，会 lazy refresh 到最新 binding
- `GetSimdPublicApi` 返回的是当前最新绑定 snapshot

调用方如果长时间缓存 table，应该把它理解成：

- **拿到的 metadata snapshot 在进程内可继续安全读取**
- **函数指针在进程内可继续安全调用**
- **control-plane 变化后，旧 table 的函数指针会跟随最新 published data-plane**
- **backend 切换后如需最新 metadata，应重新取表**

不要把当前实现理解成“拿一次就永远不会变，且地址恒定不变”。

## 兼容性规则

如果未来继续扩展 public ABI wrapper，遵循下面几条规则：

1. **只追加，不破坏现有字段语义**
   - 现有字段一旦公开，就不要改含义

2. **优先通过 `StructSize` 扩展**
   - 新字段优先往 record 尾部追加
   - 调用方先看 `StructSize`

3. **只扩 high-ROI façade**
   - 优先 `pointer + len` 风格接口
   - 不急着把 vector-by-value 推进 public ABI

4. **签名变化必须显式更新**
   - 如果 public ABI 结构真的变了，就必须同步更新文档、smoke、header 和 machine-readable signature baseline

## 验证方式

当前至少有 4 层验证：

1. 主模块 gate

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh gate
```

它会带上：

- `contract-signature`
- `publicabi-signature`
- `publicabi-smoke`

2. machine-readable public ABI signature/layout checker

```bash
python3 tests/nextpas.core.simd/check_public_abi_signature.py --summary-line
```

它会同时校验 Pascal public ABI 声明和 `publicabi_smoke.h` 的 consumer contract。

3. Linux external smoke

```bash
bash tests/nextpas.core.simd.publicabi/BuildOrTest.sh test
```

4. Windows external smoke 入口

```bat
tests\nextpas.core.simd.publicabi\BuildOrTest.bat test
```

该入口现在优先使用 `pwsh`，回退到 `powershell`；若 PowerShell runtime 缺失，会直接失败而不是静默 `SKIP`，以守住 native batch gate 的 external smoke 承诺。
当通过主 `simd` gate 在隔离根下运行时，`publicabi` external smoke 也会自动写入 `SIMD_OUTPUT_ROOT/publicabi/`，避免并发回归互相覆盖。

## 什么时候才考虑扩到 vector ABI

只有在下面三件事同时成立时，才值得把 vector ABI 拉进 public 边界：

- 有明确跨语言用户
- 有真实 workload 证明收益
- 有稳定的跨编译器/跨平台调用约定测试

在那之前，继续保持现在这条边界更稳。
