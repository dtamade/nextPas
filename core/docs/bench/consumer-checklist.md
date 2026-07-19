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
| `nextpas.core.hash/bench_hash` | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | `SHA256/1MB` 等；无 Quiet/短时；仅控制台 |
| `nextpas.core.collections/bench_vec` | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | `Vec.Push` suite；多段 suite |
| `nextpas.core.json/bench_json` | ✅ | ✅ | ⚠️ | ✅ | ✅ | `Parse/small` 命名好；时长可能偏长 |
| `nextpas.core.fs/bench_fs` | ✅ | ✅ | ⚠️ | ✅ | ✅ | `SeqWrite/64KB` 等；仅控制台 |
| `nextpas.core.encoding/bench_encoding` | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | suite `Base64`；entry 需确认 `/` 层级 |
| `nextpas.core.async/bench_async` | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | `TimerSchedule` 等无 `/` |
| `nextpas.core.toml/bench_toml_parse` | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | suite `parse`；控制台输出 |
| `nextpas.core.text/bench_text` | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | `IndexOf`/`IntToStr` 等扁平名 |

**图例**：✅ 符合 · ⚠️ 部分符合 / 可改进 · ❌ 不符合

## 汇总（2026-07-20）

| 模式 | 观察 |
|------|------|
| C1 | 抽检模块均已 `TBenchSuite` |
| C2 | json/fs 较好；async/text/toml 偏扁平名 |
| C3 | **普遍未** `SetQuiet` / 显式短 `MinDuration` — CI 可预测性弱 |
| C4–C5 | 控制台输出为主；无源码树污染；少见 `SaveToJSON` |

## 建议（给各模块 lane）

1. `.SetQuiet(True)` + 显式 `SetMinDuration` / `SetMinSamples`。  
2. 可选 `SaveToJSON('build/bench-<mod>.json')`。  
3. entry 名统一 `Module/Op` 或 `Op/size`。  

**可复制片段**（CI 友好）：

```pascal
LResults := TBenchSuite.Create('MyMod')
  .SetQuiet(True)
  .SetMinDuration(TDuration.FromMilliseconds(50))
  .SetMinSamples(5)
  .Add('MyMod/HotPath', @BenchHot)
  .Run;
WriteLn(LResults.PrintToConsole);
LResults.SaveToJSON('build/bench-mymod.json');
```

## 仓库一键入口

```bash
# 框架全量测试
make bench-module-test
# 或
make -C core bench-module-test

# 子集 smoke（需 fpc + go）
make bench-scorecard-smoke
```

## 如何更新本表

抽检新模块后追加行；重跑框架 gate：`make bench-module-test`。
