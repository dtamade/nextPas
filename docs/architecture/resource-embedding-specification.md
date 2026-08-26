# nextPas resource embedding 规范

用这份规范冻结"一棵资产文件树怎样从 source tree 进入程序、并在运行时被
消费"的仓库级稳定边界。它覆盖前端资源（Tauri 式 dist 嵌入）与同类只读
数据包场景；GUI 渲染资产（shader/icon/font 的预处理与 `RenderAssetBundle`）
归 `render-asset-pipeline-specification.md`，两者在"构建期打包、运行期零拷贝"
的理念上同源，但管线、格式与消费方不同。

模块级权威设计文档在 `core/docs/respack/`（FORMAT.md 为线格式 v1 唯一定义）
与 `core/docs/vfs/`；本文与其冲突时，先修模块文档再同步本文。

## 分层边界（已落地，S1–S5）

| 层 | 单元 | 职责 | 禁区 |
|----|------|------|------|
| 格式层 | `nextpas.core.respack.*` | pack 二进制格式 v1：字节布局、fnv32 条目校验、可选 digest 区（算法调用方注入）、内容去重 | 仅依赖 L0；不做树视图、不碰文件系统 |
| 视图层 | `nextpas.core.vfs.*` | 只读虚拟文件树 `IVfs`（Exists/Stat/List/OpenRead/CaseSensitive）；memtree/embedded/os/sub 五后端 | consumer 只认 `IVfs`；vfs→fs seam 收口在 vfs.os |
| HTTP 出口 | `nextpas.core.http.static.ServeVfs(IVfs)` | ETag（ContentHash fnv32 优先，缺则 size+mtime）、条件请求、单区间 Range、MIME、目录/非法路径统一 404 | 不做自动 index、多区间 416、不 ReadAll |
| 工具链 | `core/tools/respack/rp_pack` + `respack.embed` | build/inc/extract/list 四命令；`.inc` 发射器确定性（golden 门禁） | CLI 薄壳，格式逻辑全部在 core 侧 |

## 冻结的载体决策

- 三轨嵌入载体：**typed const `.inc`**（编译期编入）/ **`.pack` 文件随程序分发**
  / `{$R}` 资源链接（按需，未实现）。经验阈值：资产 **< 4MB 走 .inc**
  （fpc 编译时间 ≈1.1 s/MB 线性），更大走 .pack（启动一次性读入毫秒级，
  编译时间恒定）。实测与复现入口见 `core/docs/respack/README.md`「嵌入载体」。
- 完整性双档：条目 fnv32（ETag 级定位）+ 可选 digest 区（审计级，SHA-256 等
  属 hash 域，依赖倒置由调用方注入）。分块哈希推迟。
- 压缩不进 v1：读时分配破坏零拷贝，HTTP 内容编码归 http.static；仅留条目
  `codecId` 槽位。mount/overlay 推迟至真实双源场景。

## 运行时语义要点

- 路径语法取 Go io/fs ValidPath（段非空非`.`非`..`、unrooted、整串`.`表根）；
  错误为 Go PathError 对等物（EVfsError.Op/Path 族）。
- embedded 后端流是 blob 内偏移窗口切片，零拷贝直达（INV-V12 定位读保证）；
  blob 生命期由接口持引用保活（const 段场景 AOwnsBlob=False）。
- ServeVfs 对 ModTime=0 条目跳过 Last-Modified/If-Modified-Since 协商
  （杜绝 t=0 假 304），If-None-Match 经 fnv ETag 保持可用。

## 性能事实（2026-08-26 实测，复现入口在括号内）

- ServeVfs handler 直调每响应开销：embedded ≈7.0 µs/op vs os 真盘 ≈16.6 µs/op
  （≈2.3×）；206 区间读与全量同价；404 miss 无惩罚（`bench_servevfs`）。
- 启动"首资产可用"：const 载体 Open+Find ≈51 µs vs .pack 载体整读+Open+Find
  ≈3.3 ms（`bench_embed_startup`）。
- writer 内存峰值 ≈2×输入 +~14MB（512MB 输入实测；`bench_writer_memory`）。

## 验证与示范入口

- 测试门：respack 五门 + vfs 五门（含 fstest 级 conformance 与逐单元 uses
  白名单 source-contract）+ `test_http_static`（ServeVfs 双后端 39 检查）+
  `test_http_examples`（端到端 demo 自检入册）。
- 示例：`core/examples/nextpas.core.vfs/demo_asset_embed/`（开发态/发布态切换）、
  `core/examples/nextpas.core.http/http_static_vfs_demo/`（嵌入→HTTP 全链路）。
- 计划与决策记录：`docs/plans/2026-08-25-respack-vfs-modules-plan.md`（S1–S5
  收官）、`docs/plans/2026-08-26-http-static-vfs-s5-plan.md`。
