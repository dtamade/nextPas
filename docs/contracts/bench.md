# nextpas.core.bench 代码契约

> 模块路径: `core/src/nextpas.core.bench.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

基准测试框架。提供统计分析、基线比较、矩阵测试和报告生成。

---

## 关键类型

```pascal
type
  TBenchResult = record ... end;
  TBenchStats = record ... end;
  TBenchComparison = record ... end;
  TBenchConfig = record ... end;
  TBenchBaseline = record ... end;
  TMatrixResult = record ... end;
```

---

## 线程安全

- 并行基准测试由 runner 管理
- 统计计算为纯函数

---

## 依赖关系

- 依赖: time, platform.time
- 被依赖: 性能回归检测

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
