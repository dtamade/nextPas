# 消费侧对照检查（模块 bench）

对照 [consumer-guide.md](consumer-guide.md)。**默认只记录**；模块 `.lpr` 大改归各模块 lane。

抽检日期：2026-07-20 · 抽检人：bench lane  
C3 落地：2026-07-20（Quiet + 50ms/5 samples + SaveToJSON）  
B32–B34：API 对齐 / C2 命名 / +2 抽检 + scorecard binsearch·lookup  
B35：yaml/log C3 落地；regex + text.number 文档抽检

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
| `nextpas.core.toml/bench_toml_parse` | ✅ | ✅ | ✅ | ✅ | ✅ | `parse/small` 等；`build/bench-toml-parse.json` |
| `nextpas.core.text/bench_text` | ✅ | ✅ | ✅ | ✅ | ✅ | `text/IndexOf` 等；`build/bench-text.json` |
| `nextpas.core.yaml/bench_yaml` | ✅ | ✅ | ✅ | ✅ | ✅ | `Parse/small\|medium\|large`；Quiet+50ms/5；`build/bench-yaml.json`（B35） |
| `nextpas.core.log/bench_log` | ✅ | ✅ | ✅ | ✅ | ✅ | `Disabled/null` 等；Quiet+50ms/5；`build/bench-log.json`（B35） |
| `nextpas.core.regex/bench_regex` | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | 扁平/含正则字面量与空格；仅控制台；**无** Quiet/JSON（B35 只记录） |
| `nextpas.core.text.number/bench_number` | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | `IntToBuffer(42)` 等扁平名；仅控制台；**无** Quiet/JSON（B35 只记录） |

**图例**：✅ 符合 · ⚠️ 部分符合 / 可改进 · ❌ 不符合

## 汇总（2026-07-20 · B35）

| 模式 | 观察 |
|------|------|
| 抽检面 | **12** 模块 |
| C1 | 均已 `TBenchSuite` |
| C2 | 10/12 ✅；regex / text.number 仍偏扁平（后续可选） |
| C3 | **10/12 ✅**（yaml/log 已落地）；regex / number 仍 ⚠️ |
| C4–C5 | 10 模块有 `build/bench-*.json`；regex/number 仅控制台 |
| scorecard | 11 track（含 binsearch、lookup） |

## 建议（regex / text.number）

1. 可复制下方片段补 C3 + SaveToJSON。  
2. entry 改为 `regex/IsMatch`、`number/IntToBuffer/small` 等（C2）。  

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
make bench-module-test
make bench-scorecard-smoke
bash core/docs/bench/scripts/run-scorecard-subset.sh --list
```

## 如何更新本表

抽检新模块后追加行；重跑框架 gate：`make bench-module-test`。
