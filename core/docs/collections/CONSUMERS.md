# Collections 消费者审计

**日期**：2026-07-20
**范围**：`core/src` 中引用 `nextpas.core.collections*` 的非 collections 单元。

## 外部消费者

| 模块 | 用法 | 备注 |
|------|------|------|
| `tls.session.cache` / `tls.session.cache.sharded` | 具体类 `THashMap<…>`（OA） | 专家路径；**不**走 `MakeMap`/`MakeHashMap`（Swiss） |
| `tls.ocsp.cache` | `hashmap` + intf | 同上族 |
| `tls.asn1` / `tls.*.certificate` | `vec` | 序列存储 |
| `tls.pkcs11.utils` | collections 相关 | 辅助 |
| `test.runner` | `collections.base` | 测试基础设施 |
| `bench` | swiss.str 等 | 基准 |

## 结论

1. **默认工厂路径（Swiss）** 与 **TLS 等专家直构 `THashMap`（OA）** 并存是当前事实，不是 bug。
2. 本 lane **不**跨模块把 TLS 迁到 Swiss；若未来统一，应 tls lane 评估语义/性能后改。
3. 契约已写明：`MakeMap`/`MakeHashMap` = Swiss；`THashMap` 仍可用。
4. Phase A 已修 Swiss adapter 对 `TCollection` 抽象方法的实现，避免默认路径 abstract error。

## 本模块内相关包装

| 组件 | 后端 |
|------|------|
| `THashSet` | Swiss map |
| `TMultiMap` / `TMultiSet` / `TLruCache` / 部分 concurrent | 仍依赖 `hashmap` 单元（OA 或 swiss table 视实现）— 变更需单独评估 |
