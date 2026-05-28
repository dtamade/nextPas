# nextpas.core.simd.cpuinfo 模块文档

## 概述

`nextpas.core.simd.cpuinfo` 模块提供跨平台的 CPU 特性检测功能，支持 x86/x64、ARM、RISC-V 与最小 LoongArch 资格检测。

## 主要功能

### CPU 信息检测
- **厂商识别**: Intel, AMD, ARM, Qualcomm, Samsung, Apple 等
- **型号检测**: 完整的 CPU 型号字符串
- **架构识别**: x86, x64, ARM32, ARM64

### SIMD 特性检测

#### x86/x64 平台
- **SSE 系列**: SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2
- **AVX 系列**: AVX, AVX2, FMA
- **AVX-512**: AVX512F, AVX512DQ, AVX512BW (实验性)

#### ARM 平台
- **NEON**: ARM Advanced SIMD
- **浮点**: 硬件浮点支持
- **SVE**: Scalable Vector Extension
- **SVE2**: Scalable Vector Extension 2
- **加密**: 硬件加密指令

#### LoongArch 平台
- **LASX**: 当前只建模到 `HasLASX`
- **定位**: 这条能力目前只服务 `intrinsics.lasx` 的 experimental runtime qualification，不代表已经接纳 stable backend 路线

### 后端管理
- **自动选择**: 根据 CPU 特性自动选择最佳 SIMD 后端
- **支持性检查**: 检查特定后端是否受当前 CPU/OS 支持
- **优先级排序**: 按性能优先级排列 CPU/OS 支持的后端

### RISC-V 处理器信息
- `GetRISCVProcessorInfo` 默认返回 `rv64i/rv32i` 基线，并尽力从 `/proc/cpuinfo` 与 Linux 设备树 `riscv,isa` 回填 `Architecture/XLEN/ISA`；当 `/proc/cpuinfo` 存在多个 ISA 键时按“含 RV 基线 + 键优先级 + 信息量”选择最佳候选；当缺失 ISA 字符串但存在可解析 `misa` 数值位图时可合成基线 ISA（如 `rv64imafdcv`）；Linux 下还会合并 `auxv(AT_HWCAP/AT_HWCAP2)` 作为 ISA 合成的兜底/补充证据

## 通用能力与架构映射

通用能力 (TGenericFeature) 到各 ISA 的基线映射：

- gfSimd128：x86(SSE2+) / ARM(NEON/AdvSIMD) / RISC-V(V)
- gfSimd256：x86(AVX2) / ARM(SVE) / RISC-V(V) / LoongArch(LASX qualification)
- gfSimd512：x86(AVX-512F)
- gfAES：x86(AES-NI) / ARM(Crypto)
- gfSHA：x86(SHA ext) / ARM(Crypto)
- gfFMA：x86(FMA3)

注意（x86 OS 门槛）：

- AVX 可用：需 OSXSAVE = 1 且 XCR0[1:0] = 11b（XMM & YMM 上下文）
- AVX-512 可用：还需 XCR0[7:5] = 111b（ZMM 上下文）

本库已在 x86 实现中纳入上述门槛，`HasFeature/HasX86` 返回“可用”视图。

## API 参考

先记住一条规则：`cpuinfo` 只回答 `supported_on_cpu` 这一层能力视图，不回答 `registered / dispatchable / active`。如果你需要 runtime 视图，请改看 `nextpas.core.simd.runtime`。

### 主要函数

```pascal
// 获取 CPU 信息（线程安全）
function GetCPUInfo: TCPUInfo;

// 检查后端是否受当前 CPU/OS 支持
function IsBackendSupportedOnCPU(aBackend: TSimdBackend): Boolean;

// 获取 CPU/OS 语义下支持的后端列表（按优先级排序，推荐名称）
function GetSupportedBackendList: TSimdBackendArray;

// 兼容别名（等价于 GetSupportedBackendList；新代码/文档不用）
function GetSupportedBackends: TSimdBackendArray;

// 向后兼容别名（等价于 GetSupportedBackendList；新代码/文档不用）
function GetAvailableBackends: TSimdBackendArray;

// 获取 CPU/OS 语义下支持的最佳后端（推荐名称，不受运行时 active backend 影响）
function GetBestSupportedBackend: TSimdBackend;

// 原始名称（等价于 GetBestSupportedBackend；新代码/文档不用）
function GetBestBackendOnCPU: TSimdBackend;

// 向后兼容别名（等价于 GetBestBackendOnCPU；新代码/文档不用）
function GetBestBackend: TSimdBackend;

// 重置 CPU 信息（用于测试）
procedure ResetCPUInfo;

// LoongArch LASX 快速资格检查
function HasLASX: Boolean;
```

### 数据结构

```pascal
// CPU 信息结构
TCPUInfo = record
  Arch: TCPUArch;                     // CPU 架构 (caUnknown, caX86, caARM, caRISCV, caLoongArch)
  Vendor: string;                     // CPU 厂商
  Model: string;                      // CPU 型号
  LogicalCores: Integer;              // 逻辑核心数
  PhysicalCores: Integer;             // 物理核心数
  Cache: TCacheInfo;                  // 缓存信息
  OSXSAVE: Boolean;                   // OS 是否启用 XSAVE (AVX 状态保存)
  XCR0: UInt64;                       // 扩展控制寄存器 0 (用于检测 AVX/AVX-512 OS 支持)
  GenericRaw: TGenericFeatureSet;     // CPU 报告的通用特性 (原始值)
  GenericUsable: TGenericFeatureSet;  // 实际可用的通用特性 (考虑 OS 门槛)
  X86: TX86Features;                  // x86 特性 (条件编译: SIMD_X86_AVAILABLE)
  ARM: TARMFeatures;                  // ARM 特性 (条件编译: SIMD_ARM_AVAILABLE)
  RISCV: TRISCVFeatures;              // RISC-V 特性 (条件编译: SIMD_RISCV_AVAILABLE)
  LoongArch: TLoongArchFeatures;      // LoongArch 特性 (条件编译: SIMD_LOONGARCH_AVAILABLE)
end;

// CPU 架构枚举
TCPUArch = (caUnknown, caX86, caARM, caRISCV, caLoongArch);

// 通用特性枚举 (跨架构抽象)
TGenericFeature = (
  gfSimd128,   // 128-bit SIMD 可用
  gfSimd256,   // 256-bit SIMD 可用
  gfSimd512,   // 512-bit SIMD 可用
  gfAES,       // AES 指令
  gfSHA,       // SHA 指令
  gfFMA        // 融合乘加
);
TGenericFeatureSet = set of TGenericFeature;

// 缓存信息结构
TCacheInfo = record
  L1DataKB: Integer;    // L1 数据缓存大小 (KB)
  L1InstrKB: Integer;   // L1 指令缓存大小 (KB)
  L2KB: Integer;        // L2 缓存大小 (KB)
  L3KB: Integer;        // L3 缓存大小 (KB)
  LineSize: Integer;    // 缓存行大小 (字节)
end;

// x86 特性
TX86Features = record
  HasMMX: Boolean;
  HasSSE: Boolean;
  HasSSE2: Boolean;
  HasSSE3: Boolean;
  HasSSSE3: Boolean;
  HasSSE41: Boolean;
  HasSSE42: Boolean;
  HasPOPCNT: Boolean;

  HasAVX: Boolean;
  HasAVX2: Boolean;
  HasAVX512F: Boolean;
  HasAVX512DQ: Boolean;
  HasAVX512BW: Boolean;
  HasAVX512VL: Boolean;
  HasAVX512VBMI: Boolean;

  HasFMA: Boolean;
  HasFMA4: Boolean;

  HasBMI1: Boolean;
  HasBMI2: Boolean;

  HasAES: Boolean;
  HasPCLMULQDQ: Boolean;
  HasSHA: Boolean;

  HasRDRAND: Boolean;
  HasRDSEED: Boolean;
  HasF16C: Boolean;
end;

// ARM 特性
TARMFeatures = record
  HasNEON: Boolean;
  HasFP: Boolean;
  HasAdvSIMD: Boolean;
  HasSVE: Boolean;
  HasSVE2: Boolean;
  HasCrypto: Boolean;
end;

// RISC-V 特性
TRISCVFeatures = record
  HasRV32I: Boolean;    // 32-bit 基础整数指令集
  HasRV64I: Boolean;    // 64-bit 基础整数指令集
  HasM: Boolean;        // 整数乘除扩展
  HasA: Boolean;        // 原子操作扩展
  HasF: Boolean;        // 单精度浮点扩展
  HasD: Boolean;        // 双精度浮点扩展
  HasC: Boolean;        // 压缩指令扩展
  HasV: Boolean;        // 向量扩展
end;

// LoongArch 特性
TLoongArchFeatures = record
  HasLASX: Boolean;     // 256-bit LASX 扩展
  LinuxHWCAP: QWord;    // Linux auxv HWCAP 原始值
  LinuxHWCAP2: QWord;   // Linux auxv HWCAP2 原始值
end;

// SIMD 后端枚举
TSimdBackend = (
  sbScalar,     // 标量实现（总是可用）
  sbSSE2,       // SSE2 实现
  sbSSE3,       // SSE3 实现 - 水平运算指令 (HADDPS, MOVDDUP 等)
  sbSSSE3,      // SSSE3 实现 - 补充 SSE3 (PSHUFB, PALIGNR 等)
  sbSSE41,      // SSE4.1 实现 - 扩展整数/浮点指令 (ROUNDPS, PBLENDVB 等)
  sbSSE42,      // SSE4.2 实现 - 字符串处理/CRC32 (PCMPESTRI, CRC32 等)
  sbAVX2,       // AVX2 实现
  sbAVX512,     // AVX-512 实现
  sbNEON,       // ARM NEON 实现
  sbRISCVV      // RISC-V V 扩展实现 (实验性)
);
```

## 使用示例

### 基本用法

```pascal
uses
  nextpas.core.simd.base,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.cpuinfo;

var
  cpuInfo: TCPUInfo;
  bestBackend: TSimdBackend;
begin
  // 获取 CPU 信息
  cpuInfo := GetCPUInfo;
  WriteLn('CPU: ', cpuInfo.Vendor, ' ', cpuInfo.Model);

  // 获取 CPU/OS 语义下支持的最佳后端
  bestBackend := GetBestSupportedBackend;
  WriteLn('Best CPU-supported SIMD backend enum: ', Ord(bestBackend));

  // 检查特定特性
  if HasAVX2 then
    WriteLn('AVX2 is supported');

  if HasNEON then
    WriteLn('NEON is supported');
end;
```

### CPU 最佳后端 vs 当前 active 后端

`GetBestSupportedBackend` / `GetBestBackendOnCPU` 只反映“当前 CPU/OS 能用的最优后端”，不会因为 runtime control-plane 被强制切换而变化。

active 文档、示例和新代码默认应只使用 `GetCPUInfo`、`GetSupportedBackendList`、`GetBestSupportedBackend` 这组 canonical 名称。

```pascal
uses
  nextpas.core.simd.base,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.runtime;

var
  LBestOnCPU: TSimdBackend;
begin
  LBestOnCPU := GetBestSupportedBackend;

  if TrySetCurrentBackend(sbScalar) then
  try
    // 这里仍然是 CPU 能力上的最优后端，不会变成 sbScalar
    Assert(GetBestSupportedBackend = LBestOnCPU);
  finally
    ResetCurrentBackendSelection;
  end;
end;
```

### CPU capability 分支

```pascal
uses
  nextpas.core.simd.base,
  nextpas.core.simd.cpuinfo;

var
  backends: TSimdBackendArray;
  backend: TSimdBackend;
  i: Integer;
begin
  // 获取 CPU/OS 语义下所有支持的后端
  backends := GetSupportedBackendList;
  
  WriteLn('CPU-supported SIMD backends:');
  for i := 0 to Length(backends) - 1 do
  begin
    backend := backends[i];
    WriteLn('  backend enum = ', Ord(backend));
  end;
  
  // 注意：GetAvailableBackends 只是向后兼容别名；
  // 这里的语义始终是“CPU/OS 支持”，不是“当前二进制可派发”。
  // 若要查询“当前二进制真正可派发”的后端，请使用
  // nextpas.core.simd / nextpas.core.simd.runtime 提供的 dispatchable 视图。
  // 若要查询“当前二进制是否已注册某个 backend”，请使用
  // nextpas.core.simd.GetRegisteredBackendList / IsBackendRegisteredInBinary。

  // 基于 CPU capability 决定“是否值得走某条优化分支”
  if IsBackendSupportedOnCPU(sbAVX2) then
  begin
    WriteLn('CPU/OS allows AVX2-specific optimization path');
    // 这里只说明“CPU/OS 支持”，不代表 runtime 当前 active backend 已经是 AVX2
  end
  else if IsBackendSupportedOnCPU(sbSSE2) then
  begin
    WriteLn('CPU/OS allows SSE2-specific optimization path');
  end
  else
  begin
    WriteLn('Only scalar-safe path is guaranteed');
  end;
end;
```

如果你要查询**当前 runtime 真正已经选中的 backend**，或者要切换 control-plane，请改用 `nextpas.core.simd.runtime` 的 `GetCurrentRuntimeSnapshot` / `GetCurrentBackend` / `TrySetCurrentBackend`。

## 线程安全

所有公共函数都是线程安全的：

- `GetCPUInfo` 使用延迟初始化和双重检查锁定
- 初始化只执行一次，后续调用直接返回缓存结果
- 在 Windows 上使用 `TRTLCriticalSection`
- 在其他平台使用改进的自旋锁

## 性能特性

- **初始化**: 首次调用 `GetCPUInfo` 时执行检测（约 1-5ms）
- **后续调用**: 直接返回缓存结果（< 1μs）
- **内存占用**: 约 1KB 的静态数据
- **编译优化**: 只编译目标平台的代码

## 平台支持

### Windows
- **x86**: Windows 7+ (32位/64位)
- **ARM**: Windows 10+ ARM64

### Linux
- **x86**: 任何支持 CPUID 的发行版
- **ARM / RISC-V**: 优先通过 `/proc/cpuinfo` 检测 ISA 特性；Linux 下额外合并 `auxv(AT_HWCAP/AT_HWCAP2)` 作为兜底证据；RISC-V 还会合并设备树 `riscv,isa`（优先扫描 `cpus/cpu*`，并保留固定路径回退）作为次级证据源
- **ARM / RISC-V 缓存信息**: 优先通过 `/sys/devices/system/cpu/cpu*/cache/index*/{type,level,size,coherency_line_size}` 聚合探测（每级取最大值），避免固定占位值（`size` 兼容 `K/KB/KiB/M/MiB/G/GiB`）
- **ARM 特性解析**: 优先解析 `Features/flags/cpu feature(s)/extensions/cpu extension(s)/isa feature(s)/isa extension(s)/isa_ext/isaext` 键值并按 token 精确匹配（避免 `fp` 等子串误判）；`asimd*` 统一映射到 NEON/AdvSIMD，Crypto 采用确定性 token 族匹配：`aes/aesce/aesd/aesmc/aesimc/aes<digits>`、`pmull/pmull<digits>`、`sha/sha1/sha2/sha3/sha256/sha512`、`sm3/sm4`
- **ARM HWCAP 兜底**: 当 `/proc/cpuinfo` 缺失/裁剪时，使用 `AT_HWCAP/AT_HWCAP2` 位图回填 `FP/NEON/AdvSIMD/SVE/Crypto`
- **ARM Vendor/Model 解析**: `/proc/cpuinfo` 采用 key 优先级策略，避免将 `processor: 0/1/...` 误判为型号；信息不足时回退设备树 `model/compatible`
- **RISC-V ISA 解析**: 支持 `rv64imafdc...`、`rv64i2p1_m2p0_...`、`zve*`/`zvl*`、`zv*` 等 token 形式，兼容 `key: value` / `key=value` / `riscv,isa` / `riscv,isa extensions` / `march` / `riscv march` / `riscv,march` / `isa_ext` / `isa_extensions` / `extensions` / `riscv extensions` / `riscv isa extensions` / `riscv_isa_ext` 键值；多候选场景按“含 RV 基线 + 键优先级 + 信息量”择优；并支持解析 `misa`/`csr misa` 数值位图（十进制/十六进制，含 `0x`/`$`/`_` 分隔）回填 `RV32I/RV64I + M/A/F/D/C/V`，在无 ISA 字符串时可合成基线 ISA；为避免误判，泛化 vendor `x*` token 不直接推断 `V`，且 `rv*` 仅接受带 `rv32/rv64` 基线的 compact ISA，不把 `rva23u64` 等 profile 文本当作扩展位。
- **RISC-V HWCAP 兜底**: 当 ISA 字符串证据不足时，使用 `AT_HWCAP` 位图回填 `I/M/A/F/D/C/V` 基础能力；同时保留原始 `LinuxHWCAP/LinuxHWCAP2` 位图证据用于诊断与后续映射（`HWCAP2` 目前仍不直接推断扩展能力）
- **RISC-V Vendor/Model 解析**: `/proc/cpuinfo` 采用 key 优先级策略并忽略 `processor: 0/1/...` 这类 hart 索引误判；当信息不足时回退设备树 `model/compatible`

### macOS
- **x86**: macOS 10.9+
- **ARM**: macOS 11+ (Apple Silicon)

## 编译选项

在 `nextpas.core.settings.inc` 中配置：

```pascal
// 启用 x86 支持
{$DEFINE SIMD_X86_AVAILABLE}
{$DEFINE SIMD_BACKEND_SSE2}
{$DEFINE SIMD_BACKEND_AVX2}

// 启用 ARM 支持
{$DEFINE SIMD_ARM_AVAILABLE}
{$DEFINE SIMD_BACKEND_NEON}
```

## 错误处理

- 所有函数都有完善的异常处理
- 检测失败时返回安全的默认值
- 不会抛出异常到用户代码
- 提供详细的调试信息

## 测试

运行单元测试：

```bash
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --suite=TTestCase_PlatformSpecific

# 校验 cpuinfo runner 日志布局（target + legacy 双路径）
FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh log-layout-check

# 非 x86 CPUInfo 独立 QEMU 证据链（arm/v7 + arm64 + riscv64）
FAFAFA_BUILD_MODE=Release \
SIMD_QEMU_PLATFORMS="linux/arm/v7 linux/arm64 linux/riscv64" \
bash tests/nextpas.core.simd/BuildOrTest.sh qemu-cpuinfo-nonx86-evidence

# 非 x86 CPUInfo 全量 suite QEMU 专项（arm/v7 + arm64 + riscv64）
FAFAFA_BUILD_MODE=Release \
SIMD_QEMU_PLATFORMS="linux/arm/v7 linux/arm64 linux/riscv64" \
bash tests/nextpas.core.simd/BuildOrTest.sh qemu-cpuinfo-nonx86-full-evidence

# 非 x86 CPUInfo 全量 suite QEMU repeat 稳定性压测（每架构重复 N 轮）
FAFAFA_BUILD_MODE=Release \
SIMD_QEMU_CPUINFO_REPEAT_ROUNDS=2 \
SIMD_QEMU_PLATFORMS="linux/arm/v7 linux/arm64 linux/riscv64" \
bash tests/nextpas.core.simd/BuildOrTest.sh qemu-cpuinfo-nonx86-full-repeat

# 可控 retry 诊断演练（默认关闭；仅用于脚本链路自检）
# 说明：首轮在指定平台注入一次失败，触发 run_with_retry，并打印 [DIAG] target/legacy 日志 tail
FAFAFA_BUILD_MODE=Release \
SIMD_QEMU_RETRIES=2 \
SIMD_QEMU_CPUINFO_FAIL_ONCE=1 \
SIMD_QEMU_CPUINFO_FAIL_ONCE_PLATFORM="linux/riscv64" \
SIMD_QEMU_PLATFORMS="linux/riscv64" \
bash tests/nextpas.core.simd/BuildOrTest.sh qemu-cpuinfo-nonx86-evidence

# 一键重放（包含 [INJECT]/[DIAG]/summary PASS 断言）
FAFAFA_BUILD_MODE=Release \
SIMD_QEMU_RETRY_REHEARSAL_PLATFORMS="linux/riscv64" \
bash tests/nextpas.core.simd/rehearse_qemu_cpuinfo_retry_diagnostics.sh qemu-cpuinfo-nonx86-evidence

# CPUInfo Lazy 专项 repeat（本机架构，默认 5 轮）
FAFAFA_BUILD_MODE=Release \
SIMD_CPUINFO_LAZY_REPEAT_ROUNDS=3 \
bash tests/nextpas.core.simd/BuildOrTest.sh cpuinfo-lazy-repeat

# gate 中同时开启 full-evidence + full-repeat（Release）
FAFAFA_BUILD_MODE=Release \
SIMD_QEMU_CPUINFO_REPEAT_ROUNDS=1 \
SIMD_GATE_CPUINFO_LAZY_REPEAT=3 \
SIMD_GATE_QEMU_NONX86_EVIDENCE=0 \
SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 \
SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 \
SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 \
bash tests/nextpas.core.simd/BuildOrTest.sh gate

# gate-strict（默认即启用 cpuinfo non-x86 full-evidence/full-repeat + arch-matrix）
# 默认还会设置 SIMD_QEMU_CPUINFO_REPEAT_ROUNDS=1，降低严格门禁总时长
FAFAFA_BUILD_MODE=Release \
bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict

# freeze-status 强约束：同时要求 nonx86-evidence + full-evidence + full-repeat（Release）
FAFAFA_BUILD_MODE=Release \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=1 \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 \
bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status-linux

# freeze-status 强约束（含 lazy repeat）：要求 latest gate 中 cpuinfo-lazy-repeat 也为 PASS
FAFAFA_BUILD_MODE=Release \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=1 \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 \
SIMD_FREEZE_REQUIRE_CPUINFO_LAZY_REPEAT=1 \
bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status-linux

# 或直接调用底层 QEMU 脚本
FAFAFA_BUILD_MODE=Release \
SIMD_QEMU_PLATFORMS="linux/arm/v7 linux/arm64 linux/riscv64" \
bash tests/nextpas.core.simd/docker/run_multiarch_qemu.sh cpuinfo-nonx86-full-evidence

# 说明：该场景在每个架构容器内执行
# 1) BuildOrTest.sh check
# 2) BuildOrTest.sh test --list-suites
# 3) 若 list 中存在 TTestCase_LazyCPUInfo，则额外执行该 suite（当前 non-x86 默认三平台均可执行）
# 4) BuildOrTest.sh test --suite=TTestCase_PlatformSpecific
# 5) full-evidence 场景执行 BuildOrTest.sh test（全量 suite）
# 6) suite-repeat 场景：每轮固定执行 PlatformSpecific；
#    若 --list-suites 含 TTestCase_LazyCPUInfo，则同轮追加执行 LazyCPUInfo
#
# 默认平台说明：
# - 对 non-x86 相关场景（含 cpuinfo-nonx86-*），若未设置 SIMD_QEMU_PLATFORMS，
#   默认覆盖 linux/arm/v7 linux/arm64 linux/riscv64。
# - 可用 SIMD_QEMU_PLATFORMS_NONX86 覆盖该默认值（不影响 arch-matrix-evidence 的固定全矩阵要求）。
# - freeze-status 在上述强约束模式下会额外校验最新 qemu summary 中
#   `linux/arm/v7 + linux/arm64 + linux/riscv64` 三平台均为 PASS（nonx86-evidence/full-evidence/full-repeat）。
# - cpuinfo QEMU 场景重试失败时会自动输出 target/legacy 构建日志 tail；
#   可通过 SIMD_QEMU_CPUINFO_RETRY_LOG_TAIL_LINES 调整 tail 行数（默认 60）。
# - 如需演练重试诊断链路，可设置：
#   SIMD_QEMU_CPUINFO_FAIL_ONCE=1（启用一次性注入），
#   SIMD_QEMU_CPUINFO_FAIL_ONCE_PLATFORM=<platform>（可选平台过滤），
#   SIMD_QEMU_CPUINFO_FAIL_ONCE_SCENARIO=<scenario>（可选场景过滤），
#   SIMD_QEMU_CPUINFO_FAIL_ONCE_EXIT_CODE=<1..255>（注入退出码，默认 85）。
```

测试覆盖：
- ✅ 基础功能测试
- ✅ 线程安全测试
- ✅ 性能测试
- ✅ 平台特定测试
- ✅ 错误处理测试

## 已知限制

1. **CPUID 实现**: 当前使用回退实现，需要真实的 CPUID 指令
2. **AVX-512**: 实验性支持，默认禁用
3. **non-x86 特性检测**: 优先依赖 `/proc/cpuinfo`；若被裁剪会回退 `auxv/HWCAP`，但在极简运行时（两者都不可用）仍会退化为保守值

## 版本历史

- **v1.0**: 初始版本，基础 CPU 检测
- **v1.1**: 添加线程安全支持
- **v1.2**: 重构为模块化架构
- **v1.3**: 完善错误处理和测试覆盖

## 贡献指南

1. 遵循项目编码规范
2. 添加相应的单元测试
3. 更新文档
4. 确保跨平台兼容性
