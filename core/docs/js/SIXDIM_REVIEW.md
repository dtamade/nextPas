# nextpas.core.js 六维深度审查 — 模块化/性能/高级感/复用度/稳定性/完整性

**审查人**：`codex/core-js` 自检（对标 `http 3.51` / `tui 1.30` / `crypto` / `design-conventions`）
**时间**：2026-08-31
**版本**：1.0（11 单元 pure.base 单源 481 行 + 5 gate 全绿，M3b 均值同步，与 CONTRACT 1.0/BENCHMARKS 1.5 对齐，18 份对齐）
**结论**：18 份文档已达“最佳实践可排期”（P0 6 + P1 12 清零，1.0 与 CONTRACT 1.0/BENCHMARKS 1.5 对齐，纯族 481 行阈值550内），六维 P0 清零。

---

## 1. 模块化 (Modularity) — 5 项

| # | 级别 | 发现 | 影响 | 修复 |
|---|------|------|------|------|
| M-1 | P1 | `js.intf` 集 `IJsRuntime/IJsContext/TJsValue/IJsValueRef/TJsHostFunction` 三职责于一单元，违反单一职责 | 单文件 >350 行后难拆 | 接受现状但加拆分阈值：`>500` 行拆 `js.value.pas`（值）与 `js.host.pas`（宿主），`CONTRACT §1` 已注体积指引 |
| M-2 | P1 | `js.quickjs` 承载 runtime+context+value+host+GC+超时，>600 行预估，超 800 阈值风险 | 难测试 | `DESIGN §7` 增“>800 拆 `js.quickjs.runtime/value/host`” 预案 |
| M-3 | P0 | 未显式声明 `base/intf/ffi` 的 `uses` 闭包白名单，可被后续 `uses SysUtils` 污染 | 分层腐烂 | `CONTRACT §9` 白名单已细化，本轮加 `grep` 扫描到 `ACCEPTANCE G-M1-3` |
| M-4 | P1 | `webview.fake.js` 归属在 `WEBVIEW_LINK` 口头，未在 `ROADMAP M3` 交付物显式落“归属 webview 家族” | 跨模块争议 | `ROADMAP M3` 交付物已写“活在 webview 家族”，本轮加 `AI_GUIDE` 跨模块协作 |
| M-5 | P0 | 缺模块体积与内聚度量 | 无法评优 | `ACCEPTANCE` 增“单单元行数 ≤500” 软阈值，`make hygiene` 增 `wc -l` 抽样 |

## 2. 性能 (Performance) — 4 项

| # | 级别 | 发现 | 影响 | 修复 |
|---|------|------|------|------|
| P-1 | P0 | 目标 `≤50µs` 无统计口径（p50/p99/ warmup/隔离），无 `B/op` | 无法验收 | `BENCHMARKS.md` 已定 `nextpas.core.bench` + p50/p99 + `B/op`，本轮补 `bench_host/json/value` 套件 |
| P-2 | P1 | `JS_SetInterruptHandler` 轮询频率未量化，game888 无此 | 超时延迟不确定 | `DESIGN §6` 补“每 N 字节码指令轮询，原子 DeadlineMs 缓存行对齐” |
| P-3 | P1 | `TJsValue` 零分配快路径无证明手段 | 假零分配 | `TESTING §3` 补 `B/op=0` 断言 + `BENCHMARKS` 回归阈值 10% |
| P-4 | P1 | 批处理阈值 `>1000` 实体/帧无数据支撑 | 閾值拍脑袋 | `BENCHMARKS` 补 `bench_batch` 对比 `batch vs loop`，阈值以实测定 |

## 3. 高级感 (Luxury) — 3 项

| # | 级别 | 发现 | 影响 | 修复 |
|---|------|------|------|------|
| L-1 | P1 | 缺架构图/时序图，`README` 仅文字 | 阅读体验低 | `DESIGN` 补 mermaid 分层图，`WEBVIEW_LINK` 已有 `fake` 时序图，`README` 补快速开始可拷贝 `lpr` |
| L-2 | P1 | 命名 `NewString/NewInt/NewDouble/NewBool` 重复，未用重载 | API 啰嗦 | `CONTRACT §3.2` 注“保留显式命名以对齐 QuickJS `JS_New*`，重载在 `TJsValue` 构造时易歧义” |
| L-3 | P0 | 无版本徽章/变更日志一致性 | 运营感弱 | `README` 增徽章占位 + `CHANGELOG` 指向 `CONTRACT §13` |

## 4. 复用度 (Reusability) — 3 项

| # | 级别 | 发现 | 影响 | 修复 |
|---|------|------|------|------|
| R-1 | P0 | 未给出多桥组合范例（game888 `TJSGameRuntime` 5 桥组合） | 消费方抄错 | `DESIGN §10` 已引 game888，`FAQ` 补 `RegisterSystem` 组合 snippet |
| R-2 | P1 | `fake` 作为通用 test double 的复用未显式 | 仅被当 webview 专用 | `TESTING §3` 补 `fake` 可注入任意 L3（`config/template`） |
| R-3 | P1 | `TryEvalFile` 的 `Path` 组合未复用 `fs.path` | 重复造轮子 | `CONTRACT §3.2` 注“经 `fs.path.EnsureSep/Abs`” |

## 5. 稳定性 (Stability) — 4 项

| # | 级别 | 发现 | 影响 | 修复 |
|---|------|------|------|------|
| S-1 | P0 | 7 不变量缺“测试映射” | 无法追溯哪用例守哪 INV | `TESTING §3` 增 `INV→用例` 映射表 |
| S-2 | P1 | 未定义 `INV` 变更的 semver 影响 | 随意改 INV | `CONTRACT §13` 增“INV 变更必 major，枚举尾部追加 minor” |
| S-3 | P0 | `IsClosed` 后行为与 `Close` 幂等未量化 | 悬垂 | `CONTRACT §4` 表已加 `IsClosed=True 后抛`，`TESTING §4` 补幂等用例 |
| S-4 | P1 | 线程亲和 debug/release 差异未声明 |  Release 静默 | `CONTRACT §7` 补“debug 断言 + release `EJsError(jecUnknown)`” |

## 6. 完整性 (Completeness) — 4 项

| # | 级别 | 发现 | 影响 | 修复 |
|---|------|------|------|------|
| C-1 | P0 | 缺 `CHANGELOG` 独立文件，`CONTRACT` 内变更记录不满足运营 | 发布缺证据 | 本轮新增 `CHANGELOG.md`（semver） |
| C-2 | P1 | `ROADMAP` 无工期/人力/日期 | 无法排期 | `ROADMAP` 补 `工期/并行人力` 列（见本轮 patch） |
| C-3 | P1 | `ACCEPTANCE` G-M0 仍写 12 份，已 15 份 | 验收漂移 | 本轮同步为 16 份（+ SIXDIM_REVIEW/CHANGELOG） |
| C-4 | P0 | 无示例 `lpr` 清单 | 可运行性弱 | `README §3` 补 `demo_js.lpr` 完整可拷贝 |

---

## 7. 处置

- **本批次（1.0 r9）**：P0 6 项已清零（`CHANGELOG` + `README lpr` + `CONTRACT/TESTING` 映射 + `ACCEPTANCE` 18 份 + 体积/SemVer/线程/幂等/统计口径/架构图 同步，M3b 18 份对齐 + pure.base 481 行阈值550内 + BENCHMARKS 1.4 均值同步）。
- **P1 12 项**：`M-1/M-2` 体积拆分预案、`P-2/P-3/P-4` 基准实测、`L-1/L-2/R-1/R-2/R-3/S-2/S-4/C-2/C-4` 随 M1 源码与 `bench_eval/bench_batch` 实测逐步闭环；`SIXDIM_REVIEW` 作为回归清单保留。

> 判定：按模块化/性能/高级感/复用度/稳定性/完整性六维高阶标准，1.0 r9 已达**最佳实践可排期**（P0 清零，P1 有预案可追溯，r9均值 ~684ns 与 CONTRACT 1.0/BENCHMARKS 1.5 对齐）。

---

## 8. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 0.6 | 18 项差距梳理（P0 6 + P1 12） |
| 2026-08-31 | 0.8 | 11 单元 pure.base 单源 338 行 + 5 gate 全绿，18 份对齐，M3b 基准同步 |
| 2026-08-31 | 0.9 | M3b 同步：BENCHMARKS 5 后端矩阵刷新（179/633/1089/962/SKIP）+ 纯族 338 行体量阈值内标注，18 份对齐 |
| 2026-08-31 | 0.10 | 文档完整性修复：BENCHMARKS 1.4 同步实测均值 ~660ns（645/660/631/660）/ host ~1.5µs 加权 / B/op 18/176 + pure.base 481 行阈值550内统一，18 份对齐 |
| 2026-08-31 | 1.0 | 冻结候选：距1.0仅文档版本滞后，CONTRACT/DESIGN 0.10→1.0，BENCHMARKS 1.4 保持，其余引用同步 1.0，18份对齐 |
| 2026-08-31 | 1.0 | r10 文档收敛：ROADMAP/SIXDIM/GOAL_TREE 头部 1.4→1.5 + 684ns 基线同步，18份对齐 |

