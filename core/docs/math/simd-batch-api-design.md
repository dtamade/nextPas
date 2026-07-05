# SIMD Batch API 设计文档

## 概述

为 `nextpas.core.math` 模块提供 SIMD 优化的批量向量操作 API，适用于需要处理大量向量的场景（粒子系统、物理模拟、批量变换等）。

## 设计原则

1. **向后兼容**: 不影响现有单元素 API
2. **渐进增强**: 先提供标量实现，后续可替换为 SIMD
3. **类型安全**: 使用泛型或类型特定函数确保类型安全
4. **内存布局**: 支持 AOS (Array of Structures) 和 SOA (Structure of Arrays) 两种布局

## API 设计

### 1. 批量 Dot 产品

```pascal
{** * 计算两个向量数组的点积结果数组
 * @param ALeft 左操作数数组
 * @param ARight 右操作数数组
 * @param AResults 结果数组（调用方预分配）
 * @return 处理的元素数量
 *}
function BatchDot(const ALeft, ARight: array of TVec2f; 
                  var AResults: array of Single): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec3f; 
                  var AResults: array of Single): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec4f; 
                  var AResults: array of Single): SizeInt; overload;

{ Double 精度版本 }
function BatchDot(const ALeft, ARight: array of TVec2d; 
                  var AResults: array of Double): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec3d; 
                  var AResults: array of Double): SizeInt; overload;
function BatchDot(const ALeft, ARight: array of TVec4d; 
                  var AResults: array of Double): SizeInt; overload;
```

### 2. 批量 Normalize

```pascal
{** * 批量归一化向量数组
 * @param AVectors 输入/输出向量数组（原地修改）
 * @param AEpsilon 零向量阈值
 * @return 处理的元素数量
 *}
function BatchNormalize(var AVectors: array of TVec2f; 
                        const AEpsilon: Single = 1e-10): SizeInt; overload;
function BatchNormalize(var AVectors: array of TVec3f; 
                        const AEpsilon: Single = 1e-10): SizeInt; overload;
function BatchNormalize(var AVectors: array of TVec4f; 
                        const AEpsilon: Single = 1e-10): SizeInt; overload;

{ 带输出版本 }
function BatchNormalize(const ASource: array of TVec3f;
                        var ADest: array of TVec3f;
                        const AEpsilon: Single = 1e-10): SizeInt; overload;
```

### 3. 批量 Matrix Transform

```pascal
{** * 批量变换向量数组（矩阵 * 向量）
 * @param AMatrix 变换矩阵
 * @param ASource 源向量数组
 * @param ADest 目标向量数组
 * @return 处理的元素数量
 *}
function BatchTransform(const AMatrix: TMat3f;
                        const ASource: array of TVec2f;
                        var ADest: array of TVec2f): SizeInt; overload;

function BatchTransform(const AMatrix: TMat4f;
                        const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt; overload;

{ 齐次坐标版本（输入 Vec3，输出 Vec4）}
function BatchTransformH(const AMatrix: TMat4f;
                         const ASource: array of TVec3f;
                         var ADest: array of TVec4f): SizeInt; overload;
```

### 4. 批量 Lerp

```pascal
{** * 批量线性插值
 * @param AStart 起始向量数组
 * @param AEnd 结束向量数组
 * @param AT 插值参数数组 [0..1]
 * @param ADest 目标数组
 * @return 处理的元素数量
 *}
function BatchLerp(const AStart, AEnd: array of TVec3f;
                   const AT: array of Single;
                   var ADest: array of TVec3f): SizeInt; overload;

{ 固定 t 值版本 }
function BatchLerp(const AStart, AEnd: array of TVec3f;
                   const AT: Single;
                   var ADest: array of TVec3f): SizeInt; overload;
```

### 5. 批量 Clamp

```pascal
{** * 批量约束向量到指定范围
 * @param AVectors 输入向量数组
 * @param AMin 最小值向量
 * @param AMax 最大值向量
 * @param ADest 目标数组
 * @return 处理的元素数量
 *}
function BatchClamp(const AVectors: array of TVec3f;
                    const AMin, AMax: TVec3f;
                    var ADest: array of TVec3f): SizeInt; overload;

{ 原地版本 }
function BatchClamp(var AVectors: array of TVec3f;
                    const AMin, AMax: TVec3f): SizeInt; overload;
```

## 内存布局支持

### AOS (Array of Structures) - 默认

```pascal
var
  LVectors: array[0..999] of TVec3f;  // 连续内存，每个向量紧挨着
```

### SOA (Structure of Arrays) - SIMD 友好

```pascal
type
  TVec3fSOA = record
    X: array of Single;
    Y: array of Single;
    Z: array of Single;
  end;
```

**当前阶段**: 仅实现 AOS 布局，SOA 作为未来扩展。

## 实现策略

### 阶段 1: 标量实现 (M3.2)

- 使用简单循环实现所有批量函数
- 确保正确性和测试覆盖
- 建立性能基准

### 阶段 2: 编译器优化 (M3.3)

- 依赖 FPC 的自动向量化
- 添加 `{$optimization autoinline}` 等提示
- 验证生成的汇编代码

### 阶段 3: 手动 SIMD (M3.4, 可选)

- 使用 SSE/AVX intrinsics
- 针对热点函数进行优化
- 保持标量 fallback

## 测试计划

### 单元测试

1. **空数组测试**: 验证零长度输入的处理
2. **单元素测试**: 验证边界条件
3. **多元素测试**: 验证正确性
4. **性能基准**: 对比标量和批量实现

### 性能目标

| 操作 | 标量 (1000 向量) | 批量目标 | 提升 |
|------|-----------------|----------|------|
| Dot | ~15μs | ~5μs | 3x |
| Normalize | ~20μs | ~8μs | 2.5x |
| Transform | ~25μs | ~10μs | 2.5x |

## 文件结构

```
core/src/
  nextpas.core.math.vec.batch.pas    ← 批量操作实现
  nextpas.core.math.pas              ← 门面 re-export

core/tests/nextpas.core.math/
  test_vec_batch/                    ← 批量操作测试
```

## 依赖关系

- 依赖: `nextpas.core.math.vec`, `nextpas.core.math.scalar`
- 被依赖: `nextpas.core.math` (门面)

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| FPC 不自动向量化 | 性能不达标 | 手动 SIMD 作为备选 |
| 内存对齐问题 | SIMD 效率低 | 提供对齐分配接口 |
| 测试覆盖不足 | 正确性风险 | 100% 分支覆盖 |

## 里程碑

- [ ] M3.2: 标量实现 + 测试 (8h)
- [ ] M3.3: 编译器优化验证 (4h)
- [ ] M3.4: 手动 SIMD (可选, 8h)
