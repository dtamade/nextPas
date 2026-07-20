# 消费侧对照检查（模块 bench）

对照 [consumer-guide.md](consumer-guide.md)。**默认只记录**；模块 `.lpr` 大改归各模块 lane。

抽检日期：2026-07-20 · 抽检人：bench lane  
C3 落地：2026-07-20（Quiet + 50ms/5 samples + SaveToJSON）  
B32：text/json/async 对齐当前模块 API，checklist 8 模块均可编跑  
B33：C2 entry 命名统一 `Domain/Op` 或 `Op/size`（首个 `/` 供 GetGroups）  
B34：+2 文档抽检（yaml/log）；scorecard-tracks 纳入 binsearch/lookup

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
| `nextpas.core.hash/bench_hash` | ✅ | ✅ | ✅ | ✅ | ✅ | `SHA256/1MB`；Quiet+50ms/5；`build/bench-hash.json` |
| `nextpas.core.collections/bench_vec` | ✅ | ✅ | ✅ | ✅ | ✅ | `Vec/Push/N=…`；Quiet+50ms/5；`build/bench-vec.json` |
| `nextpas.core.json/bench_json` | ✅ | ✅ | ✅ | ✅ | ✅ | `Parse/small`；JsonParse 门面；`build/bench-json.json` |
| `nextpas.core.fs/bench_fs` | ✅ | ✅ | ✅ | ✅ | ✅ | `SeqWrite/64KB`、`Meta/FileExists`；`build/bench-fs.json` |
| `nextpas.core.encoding/bench_encoding` | ✅ | ✅ | ✅ | ✅ | ✅ | `Base64/Encode`、`Hex/Decode`；`build/bench-encoding.json` |
| `nextpas.core.async/bench_async` | ✅ | ✅ | ✅ | ✅ | ✅ | `Timer/Schedule` 等；Close；`build/bench-async.json` |
| `nextpas.core.toml/bench_toml_parse` | ✅ | ✅ | ✅ | ✅ | ✅ | `parse/small` 等（无括号噪音）；`build/bench-toml-parse.json` |
| `nextpas.core.text/bench_text` | ✅ | ✅ | ✅ | ✅ | ✅ | `text/IndexOf` 等；JsonEscape；`build/bench-text.json` |
| `nextpas.core.yaml/bench_yaml` | ✅ | ✅ | ⚠️ | ✅ | ✅ | `Parse/small\|medium\|large`；仅控制台；**无** Quiet/短时/JSON（B34 只记录） |
| `nextpas.core.log/bench_log` | ✅ | ✅ | ⚠️ | ✅ | ✅ | `Disabled/null` 等；仅控制台；**无** Quiet/短时/JSON（B34 只记录） |

**图例**：✅ 符合 · ⚠️ 部分符合 / 可改进 · ❌ 不符合

## 汇总（2026-07-20 · C3 + B32 + B33 + B34）

| 模式 | 观察 |
|------|------|
| 抽检面 | **10** 模块 |
| C1 | 均已 `TBenchSuite` |
| C2 | 前 8 全 ✅；yaml/log 命名已有 `/` |
| C3 | 前 8 已落地 Quiet+50ms/5；**yaml/log 仍 ⚠️**（可复制下方模板，归模块 lane） |
| C4–C5 | 控制台为主；前 8 有 `build/bench-*.json` |
| scorecard | `scorecard-tracks.txt` **11** track（含 binsearch、lookup） |

## 建议（其余模块 / yaml·log）

1. yaml/log 可复制下方片段补 C3 + SaveToJSON。  
2. 正式基线可本地去掉短时参数（恢复默认 1s / 30 samples）。

**可复制片段**（CI 友好）：

```pascal
LResults := TBenchSuite.Create('MyMod')
  .SetQuiet(True)
  .SetMinDuration(TDuration.FromMilliseconds(50))
  .SetMinSamples(5)
  .Add('MyMod/HotPath', @BenchHot)
  .Run;
WriteLn(LResults.PrintToConsole);
ForceDirectories('build');
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

# 列出全部 scorecard track（含 binsearch/lookup）
bash core/docs/bench/scripts/run-scorecard-subset.sh --list
```

## 如何更新本表

抽检新模块后追加行；重跑框架 gate：`make bench-module-test`。
