# game888 JS 设计借鉴审计

**审计对象**：`~/projects/game888` 的 QuickJS 实践（`game888.script.js_*` + `lib/quickjs` + `examples/js_*`）
**审计时间**：2026-08-30
**审计人**：`codex/core-js`
**结论**：择优 6 项反哺，4 项明确不借鉴，已落到 `DESIGN/CONTRACT/ROADMAP`。

---

## 1. game888 概览

| 项 | 实现 |
|----|------|
| 绑定 | `game888.script.js_bindings.pas` — `JSRuntime/JSContext/JSValue(16B)` + `cdecl external`，真 inline 用 `lib/quickjs/qjs_fpc_bridge.c`（`qjs_new_int64/qjs_free_value/qjs_dup_value`）桥接，`{$linklib quickjs}` 静链 `libquickjs.a` |
| 宿主 | `game888.script.js_script_host.pas` — `TJSScriptHost`（`FRuntime/FContext/FLastError/FSandboxed/FModuleSearchPath`），`ExecuteString/File/Module`、`EvalToInt/Float/String/Bool`、`SetGlobal*/GetGlobal*`、`RegisterFunction/CallFunction*`、`MarshalArgs(array of const)`、`InstallConsole(console.log)`、`SetModuleSearchPath`（`JS_SetModuleLoaderFunc` + `js_std_add_helpers`） |
| 桥 | `game888.script.jsecs_bridge.pas` — `TJSECSBridge` 全局 `GJSBridgeInstance`，注册 13 个 `ecs_*`（`ecs_create/destroy/is_alive/entity_count/add/has/set/get/query/list_entities/component_names/inspect/batch_get/batch_set`），`ecs_batch_get/set` 批量反射（`TReflectKind` + `Offset`）降 FFI 开销；`game888.script.js_light2d_bridge/p_pathfinding_bridge/particle_bridge` 各自 `GJS*Bridge` 单例 |
| 系统 | `game888.script.js_script_system.pas` — `TJSScriptSystem`（`JS_MAX_SYSTEMS 32` + `JS_HOTRELOAD_MAX_FILES 32`），`RegisterSystem/TickAll(dt→SetGlobalFloat('dt'))`、`Watch/Unwatch/Update(1.0s poll)/CheckAndReload(GetFileModTime+ExecuteString)` |
| 运行时 | `game888.script.js_game_runtime.pas` — `TJSGameRuntime` 组合 `TJSScriptHost+TJSECSBridge+TECSLight2DSystem+TJSLight2DBridge+TJSPathfindingBridge+TJSParticleBridge+TJSScriptSystem` |
| 示例 | `examples/js_space_game/main.js`（`onTick` + `ecs_get/set` + `spawn`）、`js_dungeon_demo/main.js`（`path_find/light_update/ecs_*`）| 

---

## 2. 择优借鉴（6 项，已反哺）

| # | 模式 | game888 证据 | 反哺到 nextpas.core.js | 处置 |
|---|------|--------------|------------------------|------|
| B1 | **16B JSValue 校验** | `{$IF SizeOf(JSValue)<>16} {$FATAL}` + `tag` 枚举 | `CONTRACT §3.1` `TJsValue` 16B 句柄已写，`DESIGN §2` 显式 16B | 保留，S1 `js.quickjs.ffi` 加同校验 |
| B2 | **inline 桥接 c 文件** | `qjs_fpc_bridge.c` 绕过 FPC 无法 direct 链接的 `static inline`（`JS_NewInt64/FreeValue/DupValue`） | `DESIGN §3` 已写 `*.ffi` 只含 `cdecl`，实现侧桥接；`ROADMAP M2` 区分静链 vs `platform.dl` 动探 | 借鉴思路：nextpas 选 **动探**（`platform.dl`），game888 选 **静链**（`{$linklib quickjs}`），二者对偶，文档已补权衡 |
| B3 | **批量反射降开销** | `ecs_batch_get/set`（一次 FFI 批量读写多实体单字段，`Offset+Kind` 预解析） | `DESIGN §11` 新增“批处理”段落；`CONTRACT Deferred-Perf` 新增 `BatchGet/BatchSet` 触发条件（热循环 `>1000` 实体/帧） | 择优：S1 不加 API，S2 热循环触发时加 `GetBatch/SetBatch` |
| B4 | **模块加载器** | `ModuleNormalize/ModuleLoader`（`JS_SetModuleLoaderFunc + js_std_add_helpers + JS_EVAL_TYPE_MODULE + COMPILE_ONLY + js_module_set_import_meta`） | `DESIGN §9` 取舍已写“不做 ES Module”，`ACCEPTANCE Deferred-Mod` 触发条件保持“首个 `import` 消费方”，并引 game888 为参考实现 | 择优：Deferred，不提前占位 |
| B5 | **console.log 桥** | `InstallConsole`（`JS_GetGlobalObject + JS_NewObject + JS_NewCFunction('log')`） | `TESTING §3` 的宿主示例已含 `echo`，`ROADMAP M3` 联动时补 `console` 为可选宿主函数 | 择优：S1 仅 `echo` 示例，`console` 随首个调试需求触发 |
| B6 | **多桥组合运行时** | `TJSGameRuntime` 组合 5 桥 + 1 系统，非单体 | `DESIGN §10` 消费者审计 + `WEBVIEW_LINK §4` 适配归属已写“桥组合在消费侧”，引 game888 为范例 | 保留：`js` 家族不内置 ECS/Light/Path，消费侧组合 |

---

## 3. 明确不借鉴（4 项，原因）

| # | 模式 | game888 做法 | 不借鉴原因 |
|---|------|--------------|------------|
| X1 | **全局单例桥** | `GJSBridgeInstance/GJSLight2DBridge/GJSPathBridge` 全局单例，一进程一桥 | nextpas 需多 `IJsRuntime/IJsContext` 并存（`webview.fake` + 规则脚本），单例会串扰；`js` 用 `IJsContext` 闭包捕获，无全局 |
| X2 | **全局模块搜路** | `GModuleSearchPath: string` 全局变量 | 同 X1，非重入；`js` 的 `TryEvalFile` 以显式 `AFileName` + 调用方 `Path` 组合，无全局 |
| X3 | **TextFile + IOResult 文件 IO** | `AssignFile/Reset/ReadLn/IOResult` 手写文件读 | 违 `design-conventions` 与 `fs/text` owner 边界；`js` 的 `TryEvalFile` 经 `fs` + `FORMAT_BULK_PARSE_MAX_BYTES` |
| X4 | **array of const 传参** | `MarshalArgs(array of const)` + `vtInteger/vtInt64/vtExtended` 分支 | 类型不安全、需 `JSArgs` 手动 `FreeValue` 循环；`js` 用 `array of TJsValue` 切片，零 `interface`、生命周期与 `IJsContext` 绑定 |

---

## 4. 静链 vs 动探 权衡（补充 DESIGN §3）

| 方案 | 代表 | 优点 | 缺点 | 适用 |
|------|------|------|------|------|
| 静链 | game888 `{$linklib quickjs}` + `libquickjs.a` | 部署单二进制、无运行时探测、inline 桥接直接 | 体积附带、版本锁死、跨平台需多 `.a` | 游戏客户端（game888） |
| 动探 | nextpas `platform.dl` + `libquickjs.so.1/0` | 版本探测、多后端可插拔、CI 零依赖（`fake` 兜底） | 需 `libquickjs.so`、首启探测开销 | 框架库（nextpas.core.js） |

结论：二者对偶，无优劣；`js` 选动探是因框架需 `fake` 兜底与多后端尾部追加，game888 选静链是因游戏需单二进制。

---

## 5. 落点

- `DESIGN.md` §3/§11 已补 B2/B3 权衡与批处理 Deferred
- `ROADMAP.md` M3 已引 B4/B5 为 Deferred 触发参考
- `CONTRACT.md` §9 已保留 `platform.dl` 唯一 loader 纪律（与 game888 静链对偶）
- 本文档为借鉴审计唯一事实源，后续 `pure/V8` 触发时复审

---

## 6. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首版：6 借鉴 + 4 不借鉴 + 静链/动探权衡 |

