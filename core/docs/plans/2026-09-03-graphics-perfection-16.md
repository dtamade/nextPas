# Graphics 匠心打磨 16 — 完整性与高级感收口

**目标**：在 15 基础上（b3b792800）补齐完整性与高级感，守 888 与 0.2.1，零回归

## 任务 DAG

| id | title | dependencies | 验收 |
|---|---|---|---|
| svg-import | svg 导入闭环（M/L/H/V/C/S/Q/T/Z，16384 cap，EVectorError） |  | `nextpas.core.graphics.svg` SvgPathFromData/Try 8指令，bench_vector 不回归 |
| demo-poster | demo_vector_poster 512×256 海报固化（md5 27b73e0d9a765c491bee8c85b367cef2） | svg-import | `demo_vector_poster` 构建+运行 md5 匹配 |
| contract-docs | CONTRACT/ARCH/README 0.2.1 完整性对齐（6格式+bench+888守卫文档化） | demo-poster | `source-contract` 锁定，无 .pure 泄漏 |
| simd-inline | simd.inline InlineVec 直联（零 dispatch 原子表，21.1ns vs 28.2ns 0.75x） |  | `bench_inline_vs_dispatch` 0.75x ≤0.9x |
| gate-verify | 门禁回归（HYGIENE/DIFF/G/I/C/V/DEMO 全绿） | svg-import, simd-inline, contract-docs | 四门禁全绿 |

> 约束：L1 零 bytes/font，四件套 base←intf←实现←门面，owner 边界严格

## 执行层级
- L1 并行：`svg-import, simd-inline`
- L2 串行：`demo-poster` 依 `svg-import`，`contract-docs` 依 `demo-poster`，`gate-verify` 依其余三项
