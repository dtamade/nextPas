# nextpas.core.math 代码契约

**模块路径**：`core/src/nextpas.core.math*.pas`（约 20 个源文件）
**层级**：L0（注册表权威；与 `base`/`simd`/`atomic` 同属 L0 治理集。batch/impl 可消费公开 `nextpas.core.simd` 门面）
**Owner**：math-simd lane
**最后更新**：2026-08-31
**版本**：1.5.2

---

## 0. FPC RTL 隔离（编译器无关）

**规则**：仅 `nextpas.core.system`（及其 system 子门面）允许直接 `uses` FPC RTL 单元。
`nextpas.core.math*` 生产源 **禁止** `uses Math|SysUtils|Classes|Windows|Unix|BaseUnix|Dos|TypInfo|Types`。

| 能力 | Owner | 禁止 |
|------|-------|------|
| 标量/超越函数 | `math.scalar` / `math.trig` | FPC `Math` |
| 错误类型 | `nextpas.core.errors` | FPC `SysUtils` 异常树直连 |
| FPU mask | `nextpas.core.math` 门面 `Get/SetExceptionMask` | FPC `Math` FPU API |
| OS/平台 | 不属 math；由 `platform` | OS 单元 |

**门禁**：`make -C core/tests/nextpas.core.math/test_rtl_isolation test`
（生产 **fail**；测试/示例/基准仍可 **WARN**，`--fail-tests` 可收紧）

**FPU mask 契约**：`Get/SetExceptionMask` 在 x86_64 上同时写 MXCSR 与 x87 CW，并清 sticky 状态；
FPC host 下同步 `softfloat_exception_mask`。仅写 MXCSR 不足以覆盖 SIMD batch 的 `fsin`/`fcos`/`fyl2x` scalar tail。

**测试树 residual（2026-08-31；详见 [`../math-simd/MAINTENANCE.md`](../math-simd/MAINTENANCE.md)）**：
- `core/tests/nextpas.core.math/**`：无 FPC `Math`/`SysUtils`/`Classes`/OS 单元。
- `core/tests/nextpas.core.simd/**`（含 concurrent/direct/cpuinfo.lazy）：无 FPC `Math`/`Classes`/`TThread`。
- **已关闭**：
  - dispatchapi `TSourceLines`（无 `Classes`/`TStringList`）
  - transcendental_f32 math `Power` + TextFormat `%f`
  - concurrent/direct/cpuinfo.lazy → `TWorkerThread`（`thread.base` 用 BeginThread + Destroy join）
- Gate：`production=0`；math/simd 测试树 RTL residual **0**（相对上述清单）。

`System.Sin/Sqrt/...` 等语言级 intrinsic 应集中在 `math.trig`/`math.scalar` 出口；consumer 与 simd 应调用 math owner，避免业务路径散落 `System.*`。

**System.* 允许清单（实现细节）**：

| 位置 | 允许 | 禁止 |
|------|------|------|
| `math.trig` / `math.scalar` | `System.Sin/Exp/Ln/Sqrt/...` 作为 RTL intrinsic 出口 | 业务单元直连 |
| `simd` 标量 convert / 叶 specials | 实现内部可暂用 `System.*` | 应用代码 `uses` simd 后假设 bit=libm |
| `simd.signal` / `nn` 等 | 应逐步收敛到 math owner 或本地 poly | 本包不批量改（依赖面大） |

### 0.1 应用入口 vs 内核入口

| 角色 | 入口 | 禁止 |
|------|------|------|
| 应用 / 游戏 / 业务 | `nextpas.core.math`（`Batch*`、`TVec*`） | 默认 `uses nextpas.core.simd` |
| 内核 / 热循环专家 | `nextpas.core.simd` 的 `Array*`/`Vec*` | 无 open-array 边界；调用方拥有长度 |

### 0.2 Batch open-array 长度策略（默认严格）

见 `API.md`「Batch open-array length policy」。实现：

- 标量 Batch：`math.batch.simd` 的 `ResolveEqualOrMin*`
- 向量 Batch：`math.vec.batch` / `math.vec.batch.simd` 同构 helper

`{$DEFINE NEXTPAS_MATH_BATCH_TRUNCATE_MIN}` 恢复旧 min 截断（两路共用同一 define）。

### 0.3 超越 near-parity（NEON sample）

NEON 超越叶（Sin/Exp/Cos/Log 等）对 `System.*` / scalar **near-parity**，非 bit 相等。
细节：`docs/simd/design-c5-transcendentals.md`。测试容差为契约证据，非 libm 认证 ULP。

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| math.base | TPoint2f/3f，六个 canonical `Double` 编译期常量 |
| math.scalar | 标量工具 (IsAddOverflow/IsMulOverflow/Min/Max/Clamp/Abs/Lerp/Sign) |
| math.trig | 三角函数 (Sin/Cos/Tan/Asin/Acos/Atan/Atan2)，以及 PI/TWO_PI/HALF_PI 编译期 alias |
| math.vec | TVec2f/2d/3f/3d/4f/4d (packed record, glam 实例方法风格) |
| math.mat | TMat3f/3d/4f/4d (行主序矩阵) |
| math.quat | TQuatf/Quatd (四元数) |
| math.transform | 3D 变换 (Ortho/Perspective/LookAt/Translate/Scale/RotateX/Y/Z/Camera2D) |
| math.easing | 22 种缓动函数 (Linear/Quad/Cubic/Quart/Expo/Elastic/Back/Bounce × In/Out/InOut) |
| math.random | TRandomGen (xoroshiro128+), TNoiseGen |
| math.batch | 公开 F32 标量数组批量 API（委托 batch.simd） |
| math.batch.simd | batch 的 SIMD 实现（只 uses 公开 simd 门面） |
| math.vec.batch | 向量数组批量 API |
| math.vec.batch.simd | vec.batch 的 SIMD 实现 |
| math.vec.compat | 向后兼容函数式 API（deprecated 别名） |
| math.impl.scalar | 内部标量 seam |
| math.impl.simd | 内部 SIMD seam（非公开 API） |
| math.pas | 门面 re-export |

常量所有权只有一份：`math.base` 以 `NAME = Double(literal);` 声明
`PI_VALUE`、`TWO_PI`、`HALF_PI`、`QUARTER_PI`、`DEG_TO_RAD` 和 `RAD_TO_DEG`。
`math.trig` 的三个公共常量与根门面的五个公共常量必须使用
`NAME = nextpas.core.math.base.NAME;` 编译期 alias，禁止复制数值字面量。

FPC 的 `NAME: Double = literal;` 是 typed constant，不能作为上述 alias 的右值；
`{$J+}`/`{$J-}` 只控制 typed constant 是否可写，不能改变该语法限制。显式
`Double(...)` 还保证 ordinary constant 的表达式类型不会被推断为更宽的实数类型。

### 1.2 向量类型（glam 风格实例方法）

```pascal
TVec3f = packed record
  X, Y, Z: Single;
  // 创建
  class function Create(AX, AY, AZ: Single): TVec3f; static;
  class function Zero: TVec3f; static;
  class function One: TVec3f; static;
  // 算术运算符
  class operator +(A, B: TVec3f): TVec3f;
  class operator -(A, B: TVec3f): TVec3f;
  class operator -(A: TVec3f): TVec3f;
  class operator *(A: TVec3f; S: Single): TVec3f;
  class operator *(S: Single; A: TVec3f): TVec3f;
  class operator /(A: TVec3f; S: Single): TVec3f;
  // 核心运算
  function Dot(B: TVec3f): Single;
  function Cross(B: TVec3f): TVec3f;
  function Length: Single;
  function LengthSqr: Single;
  function Normalize: TVec3f;
  function TryNormalize: TVec3f;   // 零向量返回零
  function Lerp(Target: TVec3f; T: Single): TVec3f;
  function Distance(B: TVec3f): Single;
  function DistanceSqr(B: TVec3f): Single;
  function Reflect(Normal: TVec3f): TVec3f;
  function ProjectOnto(Dir: TVec3f): TVec3f;
  function RejectFrom(Dir: TVec3f): TVec3f;
  // 分量操作
  function ComponentMul(B: TVec3f): TVec3f;
  function ComponentDiv(B: TVec3f): TVec3f;
  function Min(B: TVec3f): TVec3f;
  function Max(B: TVec3f): TVec3f;
  function Abs: TVec3f;
  function IsZero: Boolean;
  function Equals(B: TVec3f; Epsilon: Single): Boolean;
  // 联合访问
  case Integer of
    0: (X, Y, Z: Single);
    1: (Data: array[0..2] of Single);
end;
```

同构：TVec2f, TVec2d, TVec3d, TVec4f, TVec4d。所有类型 `packed record`，值语义。

### 1.3 矩阵类型

```pascal
TMat4f = packed record
  // 行主序 4×4
  class function Identity: TMat4f; static;
  class operator *(A, B: TMat4f): TMat4f;
  class operator *(V: TVec4f; M: TMat4f): TVec4f;
  function Determinant: Single;
  function Inverse: TMat4f;
  function Transpose: TMat4f;
  // 联合: Data[0..15] / Rows[0..3]
end;
```

同构：TMat3f, TMat3d, TMat4d。

### 1.4 四元数

```pascal
TQuatf = packed record
  X, Y, Z, W: Single;
  class function Identity: TQuatf; static;
  class function FromAxisAngle(Axis: TVec3f; Radians: Single): TQuatf; static;
  class function FromEuler(Yaw, Pitch, Roll: Single): TQuatf; static;
  class operator *(A, B: TQuatf): TQuatf;  // Hamilton 积
  function Normalize: TQuatf;
  function Conjugate: TQuatf;
  function ToMatrix: TMat4f;
  function RotatePoint(P: TVec3f): TVec3f;
  function Slerp(Target: TQuatf; T: Single): TQuatf;
  function Equals(B: TQuatf; Epsilon: Single): Boolean;
end;
```

### 1.5 3D 变换

| 函数 | 说明 |
|------|------|
| `Ortho(L,R,B,T,N,F)` | 正交投影矩阵 |
| `Perspective(FovY, Aspect, Near, Far)` | 透视投影矩阵 |
| `LookAt(Eye, Target, Up)` | 观察矩阵 |
| `Translate(X,Y,Z)` | 平移矩阵 |
| `Scale(X,Y,Z)` | 缩放矩阵 |
| `RotateX/Y/Z(Radians)` | 旋转矩阵 |
| `Camera2D(CX,CY,Zoom,W,H)` | 2D 相机矩阵 |

全部 Single/Double 重载。

### 1.6 缓动函数

签名：`function EaseXxx(const AT: Double): Double;` — T ∈ [0,1] → [0,1]。

22 种：Linear, InQuad, OutQuad, InOutQuad, InCubic, OutCubic, InOutCubic, InQuart, OutQuart, InOutQuart, InExpo, OutExpo, InOutExpo, InElastic, OutElastic, InOutElastic, InBack, OutBack, InOutBack, InBounce, OutBounce, InOutBounce。

### 1.7 随机数

```pascal
TRandomGen = record
  class function Init(const ASeed: UInt64 = 0): TRandomGen; static;
  procedure SetSeed(ASeed: UInt64);
  function NextInt: Integer;
  function NextIntRange(AMin, AMax: Integer): Integer;
  function NextFloat: Single;       // [0, 1)
  function NextFloatRange(AMin, AMax: Single): Single;
  function NextDouble: Double;      // [0, 1)
  function NextBool(AProbability: Single = 0.5): Boolean;
  function NextGaussian: Single;
  function NextVec3f: TVec3f;
  function NextVec4f: TVec4f;
end;
```

底层算法：xoroshiro128+。

### 1.8 标量工具

| 函数 | 说明 |
|------|------|
| `IsAddOverflow/IsMulOverflow` | SizeUInt/UInt32 溢出检测 |
| `Min/Max` | SizeUInt/SizeInt/UInt32/Int32 重载 |
| `Clamp(Value, Lo, Hi)` | 值域钳制 |
| `Abs` | 绝对值 |
| `Lerp(A, B, T)` | 线性插值 |
| `Sign` | 符号函数 (-1/0/1) |

---

## 2. 不变量

- **[INV-1]** 所有 vec/mat/quat 为 `packed record`，值语义，无堆分配
- **[INV-2]** `Normalize` 对零向量行为未定义（fail-fast：`EArgumentError`）；`TryNormalize` 对零向量返回零向量；`vec.batch.BatchNormalize` 对零向量元素按 `TryNormalize` 安全路径返回零（不抛、不产 NaN），与单点 `Normalize` 的 fail-fast 区分
- **[INV-3]** `TMat4f * TVec4f` 为列向量右乘（V 在 M 右侧）
- **[INV-4]** `TQuatf * TQuatf` 为 Hamilton 积
- **[INV-5]** `Slerp` 在两个反向四元数时取较短路径
- **[INV-6]** 缓动函数假设 T ∈ [0,1]，超出范围结果未定义
- **[INV-7]** `Perspective` 要求 AFar > ANear，AAspect > 0
- **[INV-8]** `TRandomGen` 不是密码学安全的（PRNG，非 CSPRNG）
- **[INV-9]** SIMD 实现与标量 fallback 数值结果必须一致
- **[INV-10]** `math.base` 是数学常量字面量的唯一 owner；`math.trig` 和根门面只提供编译期 `Double` alias

---

## 3. 错误处理

| 场景 | 策略 |
|------|------|
| Normalize 零向量 | 未定义行为（`Normalize` fail-fast `EArgumentError`；`TryNormalize` 安全返回零；`vec.batch.BatchNormalize` 按 `TryNormalize` 路径不产 NaN） |
| Matrix Inverse 奇异矩阵 | 结果可能为 Inf/NaN |
| Perspective AFar ≤ ANear | 结果未定义 |
| Random NextIntRange Min > Max | 结果未定义 |
| Scalar 溢出 | IsXxxOverflow 返回 True（不抛异常） |

---

## 4. 线程安全

| 类型 | 线程安全 | 说明 |
|------|----------|------|
| TVec/TMat/TQuat | ✅ | 值类型，栈上操作 |
| TRandomGen | ❌ | 有状态（种子），调用方同步 |
| TNoiseGen | ❌ | 有状态 |
| trig/transform/easing 纯函数 | ✅ | 无状态 |
| Scalar 工具函数 | ✅ | 纯函数 |

---

## 5. 内存管理

- 所有 record 类型为值语义，无堆分配
- `TRandomGen` 为 record，使用 `Init` 初始化，值语义且无需 `Free`
- 无全局缓存或静态状态

---

## 6. 测试覆盖

| 子系统 | 测试项目 | 说明 |
|--------|----------|------|
| API surface | `test_api_surface` | Python source-contract（legacy/FFI/impl 漂移） |
| Facade / symbol | `test_facade`, `test_symbol_scope` | 门面 re-export 与符号边界 |
| Scalar / Trig | `test_scalar`, `test_trig` | 标量与三角函数行为 |
| Vec / Mat / Quat | `test_vec`, `test_mat`, `test_quat` | 值类型行为 |
| Transform / Easing | `test_transform`, `test_easing` | 变换与缓动 |
| Random / Noise | `test_random`, `test_noise` | 确定性随机与噪声 |
| Batch | `test_batch_scalar`, `test_batch_simd`, `test_vec_batch` | 批量 API 与 SIMD seam |
| Impl / Compat | `test_impl_simd`, `test_vec_compat` | 内部 seam 与 deprecated 别名 |
| **合计** | **17 个 PROJECTS** | **2026-08-31: ~273 tests, 0 fail, heaptrc 0（同步 API.md 证据链刷新）** |

入口：`make -C core/tests/nextpas.core.math clean test`

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-17 | 1.2 | 层级纠正为 L0；补 batch 单元；测试表与当前 gate 对齐 | math-simd lane |
| 2026-07-10 | 1.1 | 固化 `math.base` canonical 常量及 trig/根门面编译期 alias 契约 | Codex |
| 2026-07-01 | 1.0 | 初始版本：完整六项契约 | Claude |
| 2026-08-31 | 1.5.2 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
