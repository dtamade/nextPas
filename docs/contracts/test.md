# nextpas.core.test 代码契约

> **权威文档已迁移**
> 请以模块契约为准：**[`core/docs/test/CONTRACT.md`](../../core/docs/test/CONTRACT.md)**
> 路线图：[`core/docs/test/quality-scale-roadmap.md`](../../core/docs/test/quality-scale-roadmap.md)
> 审计 findings：[`core/docs/test/findings.md`](../../core/docs/test/findings.md)

本文件（`docs/contracts/test.md`）仅为仓库级入口指针，**不再维护 API 正文**（F-15）。

## 快速门禁

```bash
make -C core/tests/nextpas.core.test contracts
# 或: make focused FOCUS=core/tests/nextpas.core.test/lane_gate
```

## Double 比较语义（F-16，与实现一致）

- `CheckEqual(Double, Double [, Epsilon])` → **委托 `CheckNear`**（默认绝对误差 `1e-10`）
- 需要精确比较时：自行用 `CheckTrue(A = B)` 或未来 `CheckEqualExact`（未提供）
- `CheckNear` / `CheckApprox` / `CheckNearRel`：容差比较

## 错误语义（摘要）

| 场景 | 行为 |
|------|------|
| 断言失败 | raise `EAssertionFailed` |
| 测试跳过 | raise `ETestSkipped` |
| SoftFail | 不 raise；汇总后标记失败 |

## 泄漏探测（F-05）

默认 **不** 调用 `GetFPCHeapStatus`。可选 `SetHeapProbe` + `NoteHeapBaseline` 注入宿主探针（见 CONTRACT）。
