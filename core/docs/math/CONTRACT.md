# nextpas.core.math 代码契约

**模块路径**：`core/src/nextpas.core.math*.pas`（16 个源文件）
**层级**：L1（依赖 L0: base）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| math.base | TPoint2f/3f, 常量 (PI/TWO_PI/DEG_TO_RAD/RAD_TO_DEG) |
| math.scalar | 标量工具 (IsAddOverflow/IsMulOverflow/Min/Max/Clamp/Abs/Lerp/Sign) |
| math.trig | 三角函数 (Sin/Cos/Tan/Asin/Acos/Atan/Atan2) |
| math.vec | TVec2f/2d/3f/3d/4f/4d (packed record, glam 实例方法风格) |
| math.mat | TMat3f/3d/4f/4d (行主序矩阵) |
| math.quat | TQuatf/Quatd (四元数) |
| math.transform | 3D 变换 (Ortho/Perspective/LookAt/Translate/Scale/RotateX/Y/Z/Camera2D) |
| math.easing | 22 种缓动函数 (Linear/Quad/Cubic/Quart/Expo/Elastic/Back/Bounce × In/Out/InOut) |
| math.random | TRandomGen (xoroshiro128+), TNoiseGen |
| math.vec.compat | 向后兼容函数式 API |
| math.impl.scalar | 标量 SIMD fallback |
| math.impl.simd | 平台 SIMD 实现 |
| math.pas | 门面 re-export |

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
TRandomGen = class
  constructor Create(ASeed: UInt64 = 0);
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
- **[INV-2]** `Normalize` 对零向量行为未定义；`TryNormalize` 对零向量返回零向量
- **[INV-3]** `TMat4f * TVec4f` 为列向量右乘（V 在 M 右侧）
- **[INV-4]** `TQuatf * TQuatf` 为 Hamilton 积
- **[INV-5]** `Slerp` 在两个反向四元数时取较短路径
- **[INV-6]** 缓动函数假设 T ∈ [0,1]，超出范围结果未定义
- **[INV-7]** `Perspective` 要求 AFar > ANear，AAspect > 0
- **[INV-8]** `TRandomGen` 不是密码学安全的（PRNG，非 CSPRNG）
- **[INV-9]** SIMD 实现与标量 fallback 数值结果必须一致

---

## 3. 错误处理

| 场景 | 策略 |
|------|------|
| Normalize 零向量 | 未定义行为（TryNormalize 安全返回零） |
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
- `TRandomGen` 为 class，Create/Destroy 管理
- 无全局缓存或静态状态

---

## 6. 测试覆盖

| 子系统 | 测试目录 | 测试数 |
|--------|----------|--------|
| Vec2f/3f/4f | test_vec2f, test_vec3f, test_vec4f 等 | ~80 |
| Vec2d/3d/4d | test_vec2d, test_vec3d, test_vec4d | ~40 |
| Mat3f/4f/4d | test_mat3f, test_mat4f, test_mat4d | ~30 |
| Quatf/Quatd | test_quatf, test_quatd | ~20 |
| Transform | test_transform | ~15 |
| Easing | test_easing | ~22 |
| Random | test_random | ~10 |
| Scalar/Trig | test_scalar, test_trig | ~20 |
| SIMD | test_simd | ~5 |
| L0 边界 | test_l0_dependency | 1 |
| **合计** | **16 个测试目录** | **~10422** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本：完整六项契约 | Claude |
