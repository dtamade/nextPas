# 职责边界审计（非按行数拆文件）

**日期**：2026-07-20
**原则**：只在有 **重复实现 + 清晰 owner + 低回归风险** 时下沉；禁止机械 `.inc` 切分。

## 已健康的边界

| 区域 | Owner | 说明 |
|------|-------|------|
| 门面工厂 | `collections.pas` | MakeXxx → 接口 |
| OA HashMap | `hashmap.pas` | 专家 / 部分包装 |
| Swiss table 内核 | `hashmap.swiss.pas` | `TSwissTable` |
| Swiss + IHashMap | `hashmap.swiss.adapter.pas` | 默认 map；已补 TCollection 抽象 |
| HashSet | `hashset.pas` | 薄包装 map（现 Swiss） |
| 连续数组算法大表面 | `arr` + `IArray` | Vec 继承复用；**方法式 API 有意保留** |
| 自由函数算法 | `algorithms.pas` | 对 `array of T` 的 FindIf 等，与容器方法并存 |

## 复制粘贴 / 平行实现（观察，非立刻重构）

| 项 | 位置 | 建议 |
|----|------|------|
| Map 的 Serialize/Append/DoZero | OA `THashMap` vs Swiss adapter | 语义已对齐；可抽私有 helper，**收益中等**，非阻塞 |
| 容器内 FindIf/CountIf/Sort 家族 | `arr` / `vec` / `vecdeque` | 大多绑定存储布局；**不宜**硬塞进 `algorithms.pas` 除非可零成本委托 |
| Ring 与连续路径的 bulk 读写 | `vecdeque` 专用 | 必须留在 deque；不是共享 owner 候选 |
| Tree/BTree/RB 有序容器 | 多单元 | 身份已收敛过；避免再并 |

## 本轮不实施代码下沉的原因

- 方法式容器 API 是已冻结的产品决策（见历史 findings）。
- 把 FindIf 等抽到自由函数会损害调用点，且仍要为 ring/contig 写两套。
- Map 的 TCollection 钩子刚补齐；再抽 helper 可后续 micro-batch，不阻塞正确性。

## 已落地（Phase D）

1. **LruCache / MultiMap / MultiSet** 内部 map 已切 **Swiss**（`TSwissHashMap`）；公共接口未变。
2. Swiss adapter 补 **GetKeys**（对齐 OA `THashMap`）。
3. **LinkedHashMap** 双表（值表 + 节点表）已切 Swiss；插入序仍由双向链表拥有。LinkedHashSet 经包装自动受益。

## 值得以后做的真职责项（排队）

1. **Swiss adapter 与 OA HashMap** 的 Serialize/Append 公共 helper（仅当再出现第三份拷贝时）。
2. **消费者驱动**：TLS 若要求工厂式 API，再提供桥接，不在此强推。
3. **ConcurrentHashMap** 分段表已用 `TSwissTable`；保持现状除非有压力证据。

## 结论

默认哈希族（MakeMap/MakeSet/HashSet/Multi*/Lru/LinkedHash*）已收敛到 Swiss 内核。
OA `THashMap` 保留给专家与 TLS 等直构路径。
机械文件拆分已取消并回退 vecdeque。
