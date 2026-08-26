# http.static 接入 IVfs（S5 跨模块 slice 立项，2026-08-26）

## 理由（为什么必须做）

respack/vfs 的目标场景是"Tauri 式前端资源嵌入"：构建期把 dist 打包编入程序，
运行时零拷贝服务 HTTP 请求。当前 `nextpas.core.http.static` 只能服务真实磁盘
（ServeFile/ServeDir），嵌入包内容没有现成服务路径——consumer 必须自己把 IVfs
读出来塞进响应，等于每个项目重写一遍静态文件语义（ETag/条件请求/Range/MIME）。
静态文件语义应当一次实现在 owner 模块里，内容源抽象为参数。

这是 respack-vfs 计划（2026-08-25）预定的 S5 切片；S4 已落地并 landing main。

## 影响面

| 路径 | 变更 |
|------|------|
| `core/src/nextpas.core.http.static.pas` | 新增 `ServeVfs(AFs): THttpHandlerFunc` 与内部 ServeVfsContentEx；既有函数不动 |
| `core/src/nextpas.core.http.static.pas` uses | interface 增 `nextpas.core.vfs.intf`；implementation 增 `vfs.base/vfs.errors`。方向 L3→L2 合法 |
| `core/tests/nextpas.core.http/test_http_static/` | 新增 memtree 后端与 os 后端两组用例（复用现有真 server + SendRawRequest 模式） |

不改动：http.intf/router/server、vfs 任何单元、respack。

## 设计要点

- URL→vfs 路径：剥前导 '/' + UrlDecode；越界形态（'..'、根特例滥用）由 vfs
  ValidPath 拒绝 → 统一映射 404（与 fs 版"不存在即 404"对齐）；目录 → 404
  （v1 不做自动 index，与 ServeDir 行为一致）
- ETag：条目 ContentHash（fnv32）非 0 时用 `"fnv-<8hex>"`（计划既定决策；
  fnv 定位 ETag 级完整性，见 respack CONTRACT）；缺失时退回 size+mtime 强 ETag
- If-Modified-Since：仅当 ModTime > 0 才参与（嵌入包 mtime 可能为 0，此时
  条件协商只走 If-None-Match，避免 "mtime=0 ≤ 任意 IMS" 的错误 304）
- Range：单区间，经 IStream 定位读（INV-V12 保证 positioned 读正确）；
  多区间维持 fs 版行为 → 416
- MIME/Cache-Control/nosniff/Date 头与 ServeFile 完全同源（复用同一批 helper）

## 风险

| 风险 | 缓解 |
|------|------|
| L3→L2 新依赖被 http 源契约门禁拦截 | 先核对门禁白名单机制；若逐单元锁定则同步更新断言并说明 |
| fnv32 弱碰撞导致错误 304 | 文档明示 ETag 级定位；强一致场景由 digest 区+应用层校验承担 |
| IStream 生命期 | handler 内 try..finally Close；embedded 后端零拷贝切片无堆分配热路径 |

## 额外验证

- `make focused FOCUS=core/tests/nextpas.core.http/test_http_static`（新增用例全绿）
- vfs 五门回归（消费方不受影响）
- respack 五门回归（上游格式层不受影响）
- `git diff --check` + `make hygiene`

## 出口条件

双后端（memtree/os）行为一致：200/404/304/206/416 五态语义与 fs 版对齐；
两模块 gate 全绿后按 landing 纪律 path-limited 进 main。

## 完成记录（2026-08-26）

状态：已实现，验证全绿。

实现相对本计划的补充决策：

- `ServeVfs` 同时经 `nextpas.core.http` 门面 inline forwarding 输出
  （与 ServeFile/ServeDir 同模式；门面 interface uses 增
  `nextpas.core.vfs.intf`）。test_http_contract 36/36 绿确认门禁放行。
- 区间拷贝 helper `CopyFileRange(IFile)` 泛化为 `CopyRange(IStream)`：
  fs 的 IFile 本就是 IStream 子接口，vfs 定位读零新增代码路径；fs 行为不变。
- IStream 生命期走接口引用计数出域释放（与 fs 版一致），未加显式
  try..finally Close；embedded/memtree 流均为 TInterfacedObject 零堆热路径。

验证证据：

| Gate | 结果 |
|------|------|
| test_http_static | 39 passed / 0 failed（新增 ServeVfs 用例 11 项）+ heaptrc OK |
| test_http_contract | 36 passed / 0 failed |
| test_http_smoke | 6 passed / 0 failed + heaptrc OK |
| vfs 五门 memtree/embedded/conformance/facade/source-contract | 14/6/7/6/5 全绿 |
| git diff --check + make hygiene | pass |
