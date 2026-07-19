# 消费侧对照检查（模块 bench）

对照 [consumer-guide.md](consumer-guide.md)。**默认只记录**；模块 `.lpr` 大改归各模块 lane。

抽检日期：2026-07-20 · 抽检人：bench lane

## 检查项

| ID | 项 | 说明 |
|----|-----|------|
| C1 | 使用 `TBenchSuite` | 非裸循环计时 |
| C2 | 命名 `Domain/Op` 或含 `/` 层级 | 利于 Filter/GetGroups |
| C3 | Quiet / 短时配置合理 | CI 友好 |
| C4 | 产物不落源码树 | JSON/HTML 进 build/ 或 ignored |
| C5 | 有可读输出 | PrintToConsole / ToJSON 等 |

## 抽检结果

| 模块 bench | C1 | C2 | C3 | C4 | C5 | 备注 |
|------------|----|----|----|----|----|------|
| `nextpas.core.hash/bench_hash` | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | `TBenchSuite` + `SHA256/1MB` 等；未显式 Quiet/短 MinDuration；仅 PrintToConsole |
| `nextpas.core.collections/bench_vec` | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | `Vec.Push` 等 suite 名；多段 suite；控制台输出 |
| `nextpas.core.json/bench_json` | ✅ | ✅ | ⚠️ | ✅ | ✅ | `Parse/small` 等命名好；链式 Add；默认时长可能偏长 |

**图例**：✅ 符合 · ⚠️ 部分符合 / 可改进 · ❌ 不符合

## 建议（给各模块 lane，非本 lane 改代码）

1. 统一 `.SetQuiet(True)` + 显式 `SetMinDuration`/`SetMinSamples`（CI 可预测）。  
2. 可选 `SaveToJSON('build/bench-<mod>.json')` 便于 CI 工件。  
3. suite 名与 entry 名都用 `Module/Op` 前缀，方便矩阵与分组导出。  

## 如何更新本表

抽检新模块后追加行；重跑框架 gate：

```bash
make -C core/tests/nextpas.core.bench clean test
```
