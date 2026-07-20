# 消费侧对照检查（模块 bench）

对照 [consumer-guide.md](consumer-guide.md)。**默认只记录**；模块 `.lpr` 大改归各模块 lane。

抽检日期：2026-07-20 · 抽检人：bench lane  
C3：Quiet + 50ms/5 samples + SaveToJSON  
B32–B35：API / C2 / 扩面 / yaml·log  
B36：regex + text.number C3 + 轻量 C2 → checklist **12/12 全绿**

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
| `nextpas.core.hash/bench_hash` | ✅ | ✅ | ✅ | ✅ | ✅ | `SHA256/1MB`；`build/bench-hash.json` |
| `nextpas.core.collections/bench_vec` | ✅ | ✅ | ✅ | ✅ | ✅ | `Vec/Push/N=…`；`build/bench-vec.json` |
| `nextpas.core.json/bench_json` | ✅ | ✅ | ✅ | ✅ | ✅ | `Parse/small`；`build/bench-json.json` |
| `nextpas.core.fs/bench_fs` | ✅ | ✅ | ✅ | ✅ | ✅ | `SeqWrite/64KB`、`Meta/FileExists`；`build/bench-fs.json` |
| `nextpas.core.encoding/bench_encoding` | ✅ | ✅ | ✅ | ✅ | ✅ | `Base64/Encode`；`build/bench-encoding.json` |
| `nextpas.core.async/bench_async` | ✅ | ✅ | ✅ | ✅ | ✅ | `Timer/Schedule`；`build/bench-async.json` |
| `nextpas.core.toml/bench_toml_parse` | ✅ | ✅ | ✅ | ✅ | ✅ | `parse/small`；`build/bench-toml-parse.json` |
| `nextpas.core.text/bench_text` | ✅ | ✅ | ✅ | ✅ | ✅ | `text/IndexOf`；`build/bench-text.json` |
| `nextpas.core.yaml/bench_yaml` | ✅ | ✅ | ✅ | ✅ | ✅ | `Parse/small`；`build/bench-yaml.json` |
| `nextpas.core.log/bench_log` | ✅ | ✅ | ✅ | ✅ | ✅ | `Disabled/null`；`build/bench-log.json` |
| `nextpas.core.regex/bench_regex` | ✅ | ✅ | ✅ | ✅ | ✅ | `regex/IsMatch/*` 等；Quiet+50ms/5；`build/bench-regex.json`（B36） |
| `nextpas.core.text.number/bench_number` | ✅ | ✅ | ✅ | ✅ | ✅ | `number/IntToBuffer/*` 等；Quiet+50ms/5；`build/bench-number.json`（B36） |

**图例**：✅ 符合 · ⚠️ 部分符合 / 可改进 · ❌ 不符合

## 汇总（2026-07-20 · B36）

| 模式 | 观察 |
|------|------|
| 抽检面 | **12** 模块 |
| C1–C5 | **12/12 全 ✅** |
| C3 | Quiet + 50ms MinDuration + 5 MinSamples + `build/bench-*.json` |
| scorecard | 11 track（含 binsearch、lookup） |

## 可复制片段（CI 友好）

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
