# nextpas.core.js 变更日志

## [1.0.2] - 2026-08-31 — r10 宿主单源+文档收敛（18份对齐）

- 复用度：新增 `JsPureCheckHostName/JsPureHostSetFunc/Method/Proc` 4 helper inline 单源（`Validate+nil+JsPureHostSet`），`fake/js888/v8/chakra/quickjs` 各 `SetHostFunction 3形态×5` 15 处克隆委托，纯族零 FFI/零 dl，`pure.base 481→516 行`阈值550内（+35 行，Close+Host 合计）
- 文档收敛：`ROADMAP/GOAL_TREE/SIXDIM_REVIEW/PARITY/WEBVIEW_LINK/DESIGN` 头部 `BENCHMARKS 1.4→1.5` + `r9 均值 684ns` 同步，`SIXDIM 结论 0.10→1.0 r9`，`CONTRACT 纯族 481+122×3` 刷新，`42×4+12+SKIP` 5 gate 全绿，`hygiene pass`

## [1.0.1] - 2026-08-31 — r9 快路径+Close单源+基准回落（18份对齐）

- 性能回落：`JsPureToJsonString` 快路径（先扫 `"` `\` `<32` 无转义则 `'"'+S+'"'` 零 builder，微测 `hello 95ns` vs 转义 `184ns`），`Eval/small 716→684ns -4.5%` 回归收敛，`Value/ops 154ns B/op0` 保持
- 模块化：新增 `JsPureClose(var Hosts,Heap,Global,AContextId)` inline 单源，`fake/js888/v8/chakra` 各 `Close 10行×4` 克隆委托，纯族零 FFI/零 dl，`pure.base 481 行`阈值550内（+17 行）
- 微测：`micro_pure 1M hello 95ns / escape 184ns`，`ToJson` 全量 `\b\f\n\r\t\"\\ \u0000-\u001F` 经 `TJsonWriter.Str` 覆盖
- 文档：`BENCHMARKS 1.4→1.5`（表均值同步 684/852/1.89µs/154ns，快路径说明），`CONTRACT/README` 纯族 `481+122×3` 刷新，`42×4+12+SKIP` 5 gate 全绿

## [1.0.0] - 2026-08-31 — r8 工厂单源+转义+1.0 冻结（18份对齐）

- 工厂单源：新增 `JsPureNewString/JsPureNewInt/JsPureNewDouble/JsPureNewBool` inline 单源（`pure.base` 内 `JsValueBindContext` 封装），`fake/js888/v8/chakra/quickjs` 各 `NewString/NewInt/NewDouble/NewBool` 16 处克隆改为 `JsPureNew*(*, FContextId)` 委托，`quickjs` 的 `NewJson/ToJson` 同步委托 `JsPureNewString/JsPureToJson`；零残留 `Bind(JsStringValue`（除 `pure.base` 定义），`pure.base 352→481 行`阈值550内
- 转义加固：`JsPureToJsonString` 的 `jskString` 分支由 `'"' + AsString + '"'` 改为 `TStringBuilder+TJsonWriter.Str` 经 `nextpas.core.text.escape/JsonEscapeToBuilder` 真转义（`\n \r \t \" \\ \u`），`quickjs` 的 `ToJson` 改委托 `JsPureToJson`，用例 `a"b`+LF+反斜杠 正确为 `"a\"b\nc\\\t\\"`，`B/op` 18/176 保持
- 依赖：`pure.base` 实现侧新增 `uses nextpas.core.text.builder/nextpas.core.json.writer`（L1 owner，零 FFI/零 dl），`hygiene` 0 违规
- 文档冻结：`CONTRACT/DESIGN/ROADMAP/BENCHMARKS/GOAL_TREE/PARITY/WEBVIEW_LINK/SIXDIM_REVIEW/README` 版本 `1.0rc/1.3→1.0/1.4`，`pure.base 352→481 行` 体量全量刷新，`18份对齐`，`bench_eval` 实测 `716ns/852ns/1.89µs/154ns`（0 alloc Value），`42×4+12+SKIP` 5 gate 全绿
- 基准：`BENCHMARKS 1.3→1.4`：均值同步 r8 实测（Eval/small 716ns / host 852ns / JSON 1.89µs / Value 154ns），`pure.base 481 行`阈值550内标注

## [1.0.0-rc.1] - 2026-08-31 — 冻结候选（距1.0仅文档版本滞后，18份对齐）

- `CONTRACT 0.10→1.0rc` / `DESIGN 0.10→1.0rc`：冻结候选，`11单元 pure.base 352行 + 5 gate 全绿 + M3b 均值 ~660ns` 零代码变更，`BENCHMARKS 1.3` 保持（Eval/small 645/660/631/660 / host ~1.5µs 加权 / B/op 18/176 / Value 零分配），其余引用同步 1.0rc，`18份对齐`，仅头部版本与变更记录变更，历史行不变
- 冻结说明：`S1 pure.base 单源 352行阈值550内 + 5 gate 全绿 + hygiene/source-contract pass` 已就绪，`1.0rc` 为冻结候选，待 `M4/M5` 真消费方联动验证后晋升 `1.0`

## [0.10.0] - 2026-08-31 — 文档完整性修复 + fake Global 幂等 + BENCHMARKS 均值同步

- `BENCHMARKS 1.2→1.3`：`Eval/small` 由 `179/633/1089/962` 旧表刷新为本次实测均值 `fake 645 / js888 660 / v8 631 / chakra 660`（~660ns，均值）/ `Eval/host ~1.5µs` 加权（host 18 B/op + JSON 176 B/op）/ `Value/ops` 零分配（B/op=0），`pure.base 338→352` 行阈值550内统一，`18`份对齐
- `CONTRACT 0.9→0.10` / `DESIGN 0.9→0.10` / `README 0.8→0.10` / `GOAL_TREE 0.8→0.10` 四份联动，`BENCHMARKS 1.3` 对齐，变更记录闭环
- `fake` 稳定性：`FGlobal/FHeap` 幂等（`Create` 时 `JsPureHeapNewObject` + `Global` 返 `FGlobal` + `Close` 清堆清宿主），对齐 `js888/v8/chakra` 真堆，`heaptrc 0`，`42`用例绿

## [0.9.0] - 2026-08-31 — 11 单元 pure.base 复用 + 文档0.9对齐

- `quickjs` 复用 `pure.base`：`FindHost/ValidateHostName` 内联委托 `JsPure*` 消15行克隆，`FHostFuncs` 改 `TJsPureHostArray`，零FFI/零dl/inline/heaptrc0 保留，`wc` `308→298`
- 文档 `0.8→0.9` 联动：`CONTRACT/DESIGN/PARITY/WEBVIEW/SIXDIM/ROADMAP` 四份版本链与`BENCHMARKS 1.2`对齐，`18`份闭环

## [0.8.0] - 2026-08-31 — 11 单元 pure.base 单源 + Close 幂等 + V8/Chakra 独立门禁

- 新增 `nextpas.core.js.pure.base.pas` 338 行共享基座（`JsPureValidateHostName/JsPureFindHost/JsPureDoEval` 零分配 `TStringView`，零 FFI/零 dl），`js.js888/v8/chakra` 各 104 行复用消 300 行克隆；`TryEvalFile` 统一 `TryReadFileText` 64MiB 限流 + `FORMAT_BULK_PARSE_MAX_BYTES` owner
- `Close` 幂等清零：`js888/v8/chakra` 对齐 `fake` 清空 `FHostFuncs` 宿主闭包，heaptrc 零泄漏；`CONTRACT` 补 `pure.base` 第11单元入表、依赖图 `pure.base←{js888,v8,chakra}`，版本 0.7→0.8
- 测试：`test_js_v8_runtime` / `test_js_chakra_runtime` 新增各 42 用例独立门禁（与 js888 同矩阵），`test_js_base` 12 + `fake/js888/v8/chakra` 42×4 + `quickjs` SKIP 5 gate 全绿，bench 5 后端全绿
- 文档：CONTRACT/DESIGN/README 0.8 同步，纯族依赖与体积指引更新

## 2026-08-30 — V8/Chakra 纯占位 + Symbol/BigInt + 对象完备化

- 新增 `nextpas.core.js.v8.pas` / `js.chakra.pas`（各 137 行，零 FFI/零 dl，恒可用，与 fake/js888 同约束），`TJsBackendKind` 扩展至 5 值（`jsbkQuickJs/jsbkFake/jsbkJs888/jsbkV8/jsbkChakra`，尾部追加纪律）、`TJsValueKind` 扩展至 12 值（新增 `jskSymbol/jskBigInt` + `JsSymbolValue/JsBigIntValue/IsSymbol/IsBigInt`）
- `IJsContext` 补齐 `HasProp/DeleteProp/GetKeys/NewError/NewFunction×3` 全后端实现（fake/js888/v8/chakra 返回 False/nil/JsErrorValue/JsFunctionValue 并绑定宿主三形态；QuickJS 同步 stub），门面 `CreateJsRuntime/JsBackendAvailable` 扩展纯族分支，`bench_eval` 五后端矩阵（fake/js888/v8/chakra/quickjs）同跑
- 测试：`test_js_base` 12 项（新增 symbol/bigint + backend ext + probe 8 名）、`test_js_fake` 41 项（新增 object complete：Has/Delete/GetKeys/NewError/NewFunction 三形态）、`test_js_js888` 40 项、`test_js_quickjs` SKIP；bench：fake 630ns / js888 639ns / v8 626ns / chakra 630ns（Eval/small）、Value/ops 51-56ns，heaptrc OK，hygiene pass，wc 基准阈值内
- 文档：CONTRACT/DESIGN/README/BENCHMARKS 同步纯族 10 单元与 5 后端矩阵



**格式**：Keep a Changelog + SemVer
**关联**：`CONTRACT §13`（稳定性）

---

## [0.7.0] - 2026-08-30 — 六维硬化 P0 清零

- `CONTRACT` 体积指引 500/800 双阈值、`Close` 幂等、线程 debug/release、SemVer、徽章（`SIXDIM M-1/M-2/S-2/S-3/S-4/L-3`）
- `TESTING` `INV→用例` 映射、`B/op=0` 零分配断言、`fake` 通用复用、`Close` 幂等（`SIXDIM S-1/P-3/R-2/S-3`）
- `DESIGN` 增 mermaid 分层图、中断轮询缓存行对齐、体积预案（`SIXDIM L-1/P-2/M-1/M-2`）
- `BENCHMARKS` 补 p50/p99/warmup/`B/op`、`bench_batch` 实测阈值（`SIXDIM P-1/P-4`）
- `ROADMAP` 补工期/人力列、`webview.fake.js` 归属明示（`SIXDIM C-2/M-4`）
- `ACCEPTANCE` 12→18 份同步、`wc -l` 体积门禁、`INV` 映射回归（`SIXDIM C-3/M-5`）
- `AI_GUIDE` 体积双阈值 + 跨模块协作（`SIXDIM M-1/M-4`）
- `README` 17→18 份、`CHANGELOG` 语义化闭环

## [0.6.0] - 2026-08-30 — 六维硬化

- 增 `SIXDIM_REVIEW.md`（18 项，P0 6 + P1 12）
- 增 `CHANGELOG.md` 本文件
- `DESIGN` 0.5→0.6：批处理阈值实测定、静链/动探权衡、中断轮询量化
- `README` 0.5→0.6：补 `demo_js.lpr` 可拷贝、15→16 份索引

## [0.5.0] - 2026-08-30 — 借鉴与运营

- 增 `GAME888_BORROW.md` / `FAQ.md` / `DECISIONS.md`（6 借鉴 + 4 不借鉴）
- `DESIGN` 反哺批处理/模块加载器

## [0.4.0] - 2026-08-30 — 冻结 12 份

- 增 `REVIEW/ROADMAP/ACCEPTANCE/AI_GUIDE/TESTING/SECURITY/BENCHMARKS`
- `CONTRACT/DESIGN/GOAL_TREE` 0.3→0.4

## [0.3.0] - 2026-08-30 — 生产级骨架

- 7 单元布局、双层值模型、三形态宿主、超时/内存限

## [0.1.0] - 2026-08-30 — 初稿

- 7 单元草图

