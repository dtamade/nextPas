# nextpas.core.math.scalar 代码契约

> 模块路径: `core/src/nextpas.core.math.scalar.pas`
> 创建日期: 2026-07-03
> 维护者: AI

---

## 概述

提供标量数学运算函数，包括基本算术、三角函数、对数函数等。

---

## 接口签名

### 类型定义

无自定义类型，使用 FPC 内置类型。

### 函数/过程

```pascal
{ 基本算术 }
function Max(AA, AB: Double): Double;
function Min(AA, AB: Double): Double;
function Abs(AValue: Double): Double;
function Sqr(AValue: Double): Double;
function Sqrt(AValue: Double): Double;

{ 取整 }
function Ceil(AValue: Double): Int64;
function Floor(AValue: Double): Int64;
function Round(AValue: Double): Int64;
function Trunc(AValue: Double): Int64;

{ 三角函数 }
function Sin(AValue: Double): Double;
function Cos(AValue: Double): Double;
function Tan(AValue: Double): Double;
function ArcTan(AValue: Double): Double;
function ArcTan2(AY, AX: Double): Double;

{ 对数函数 }
function Ln(AValue: Double): Double;
function Log2(AValue: Double): Double;
function Log10(AValue: Double): Double;
function Power(ABase, AExponent: Double): Double;
function Exp(AValue: Double): Double;
```

---

## 前置条件

1. Sqrt: AValue >= 0
2. Ln: AValue > 0
3. Log2: AValue > 0
4. Log10: AValue > 0
5. Power: ABase > 0 (当 AExponent 非整数时)

---

## 后置条件

1. Max: 返回 AA 和 AB 中较大值
2. Min: 返回 AA 和 AB 中较小值
3. Abs: 返回非负值
4. Sqr: 返回 AValue * AValue
5. Sqrt: 返回非负值，结果的平方等于 AValue

---

## 错误语义

| 场景 | 行为 |
|------|------|
| Sqrt(负数) | 返回 NaN |
| Ln(0) | 返回 -Infinity |
| Ln(负数) | 返回 NaN |
| Power(0, 负数) | 返回 Infinity |

---

## 线程安全

- 纯函数，无线程安全问题
- 可安全并发调用

---

## 内存管理

- 无动态内存分配
- 无资源管理

---

## 测试覆盖

### 单元测试

```pascal
procedure TestMax_TwoPositive;
procedure TestMax_PositiveNegative;
procedure TestMax_TwoNegative;
procedure TestMin_TwoPositive;
procedure TestAbs_Positive;
procedure TestAbs_Negative;
procedure TestAbs_Zero;
procedure TestSqrt_PerfectSquare;
procedure TestSqrt_NonPerfectSquare;
procedure TestSqrt_Zero;
procedure TestCeil_Positive;
procedure TestCeil_Negative;
procedure TestFloor_Positive;
procedure TestFloor_Negative;
```

### 边界测试

```pascal
procedure TestSqrt_NegativeInput;
procedure TestLn_Zero;
procedure TestLn_Negative;
procedure TestPower_ZeroNegativeExponent;
```

---

## 依赖关系

- 依赖: 无（纯数学运算）
- 被依赖: nextpas.core.math, units/linux-x86_64/Math.pas

---

## 基准对照

| 函数 | FPC RTL | Go math | Rust f64 |
|------|---------|---------|----------|
| Sqrt | ~5ns | ~4ns | ~3ns |
| Sin | ~15ns | ~12ns | ~10ns |
| Ln | ~20ns | ~18ns | ~15ns |

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-03 | 初始版本 | 契约建立 |

