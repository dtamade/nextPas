# nextpas.core.js 变更日志

## [0.8.0] - 2026-08-31 — 11 单元 pure.base 单源 + Close 幂等 + V8/Chakra 独立门禁

- 新增 `nextpas.core.js.pure.base.pas` 168 行共享基座（`JsPureValidateHostName/JsPureFindHost/JsPureDoEval` 零分配 `TStringView`，零 FFI/零 dl），`js.js888/v8/chakra` 各 104 行复用消 300 行克隆；`TryEvalFile` 统一 `TryReadFileText` 64MiB 限流 + `FORMAT_BULK_PARSE_MAX_BYTES` owner
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

