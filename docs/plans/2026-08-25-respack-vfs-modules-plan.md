# respack + vfs 模块落地计划（2026-08-25）

**目标**：为 `nextpas.core.respack`（资源打包格式）与 `nextpas.core.vfs`（只读虚拟文件树）
提供从设计到落地的分阶段计划。设计文档已定稿于 `core/docs/respack/`、`core/docs/vfs/`，
本文只管执行顺序、验证门与落地纪律。

**动机**：对标 Tauri 的前端资源嵌入能力——构建期把 dist 目录打成单个 blob 编入程序/
动态库，运行时零拷贝随机读取，供 http.static 等直接服务。拆成格式层（respack）与
视图层（vfs）两个模块，格式层可独立被工具链复用。

## 权威设计文档

| 文档 | 内容 |
|------|------|
| `core/docs/respack/README.md` | 格式模块定位、单元结构、依赖白名单、嵌入载体 |
| `core/docs/respack/FORMAT.md` | 线格式 v1 权威定义：字节布局、校验清单、路径语法、扩展策略 |
| `core/docs/vfs/README.md` | 树视图模块契约：IVfs、错误语义、后端矩阵、零拷贝与生命期规则 |

实现与文档冲突时，以设计文档为准并先修文档。

## 关键设计决策（已定稿）

1. **respack 仅依赖 L0**（base/errors）：纯格式层；FNV-1a 内联不依赖 checksum；
   目录扫描收口在 `dirsource` 单元（唯一 L2→L2 seam，registry 记录）。
2. **vfs v1 只读**；自有 `TEntryInfo/TStatInfo` 不复用 `fs.base`，守住 "L2 仅依赖
   L0-L1"；流词汇复用 `io.intf.IStream`。
3. **vfs→fs seam 收口在 `vfs.os` 单元**；其余 vfs 单元禁止 uses fs/respack
   （source-contract 测试锁定）。
4. **嵌入载体**三轨：`.pack` 文件 / 生成 `.inc` typed const（S4）/ `{$R}`（按需）。
5. mount/overlay 推迟至有真实双源场景；接口留位不留桩。

## 阶段切片

### S0 — 设计文档（本切片）

- [x] 三份设计文档 + 本计划落盘
- Lane: `codex/core-respack-vfs`（worktree `.worktrees/core-respack-vfs`）
- 出口条件：文档评审通过，landing 进 main

### S1 — respack 格式层

Lane 建议：沿用 `codex/core-respack-vfs` 或拆 `codex/core-respack`。

任务：
1. `nextpas.core.respack.base.pas` — header/entry record、常量、错误类型、内联 FNV-1a
2. `nextpas.core.respack.writer.pas` — 排序/去重/对齐/blob 组装
3. `nextpas.core.respack.reader.pas` — 七步校验清单 + 二分查找
4. `nextpas.core.respack.dirsource.pas` — fs 目录枚举适配
5. 门面 `nextpas.core.respack.pas`

验证门：
```bash
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_writer
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_reader
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_roundtrip
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_dirsource
```
出口条件：FORMAT.md 每条校验规则至少一个拒绝用例；golden 字节快照；heaptrc 零泄漏；
registry 增加 `respack` 行（L2，source-contract → focused-runtime）。

### S2 — vfs 契约与内存树

可与 S1 并行（仅共享路径语法定义文本，无代码依赖）。

任务：
1. `nextpas.core.vfs.base.pas` / `errors.pas` / `intf.pas`
2. `nextpas.core.vfs.memtree.pas` — Builder + Freeze 不可变树

验证门：
```bash
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_memtree
```
出口条件：错误语义表全覆盖；并发读 smoke；heaptrc 零泄漏。

### S3 — vfs 后端与门面

依赖 S1+S2。任务：
1. `nextpas.core.vfs.embedded.pas` — 零拷贝切片 + `AOwnsBlob` 生命期语义
2. `nextpas.core.vfs.os.pas` — fs/path 适配与类型转换
3. 门面便利函数 `VfsReadAllBytes/VfsReadAllText`
4. source-contract 测试锁定依赖白名单

验证门：
```bash
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_embedded
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_os
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_facade
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_source_contracts
```
出口条件：三后端一致性测试集通过；零拷贝地址断言生效；registry 增加 `vfs` 行。

### S4 — 嵌入工具链

任务：
1. `.inc` 生成器（把 blob 转成 typed const Pascal 单元），放工具侧
2. 示例：最小 app 打包前端资源并用 os/embedded 双后端跑通
3. 大小基准：const 数组 vs .pack 读入的编译时间/启动时间对比数据

出口条件：示例程序在 host fpc 下构建运行；基准数字记入模块文档。

### S5 — http.static 接入 IVfs（跨模块 slice）

按 AGENTS.md 跨模块纪律单独立项说明：理由、影响面（`http.static` 内容源抽象）、
风险、额外验证（http focused gate + vfs gate）。ETag 取 `ContentHash`，
If-Modified-Since 取 `ModTime`。

## 落地纪律

- 全程 worktree 开发；每片 landing 前：worktree clean、focused gate 通过、
  `git diff --check`、`make hygiene` 通过
- 不 raw merge lane 进 main；landing 用 path-limited cherry-pick 或等价小提交
- registry 在每个模块首个可验证切片落地时补行，不在设计阶段抢注

## 风险与开放问题

| 项 | 状态 |
|----|------|
| FPC 大型 const 数组编译慢 | S4 基准量化；超阈值走 `.pack`+启动读入或 mmap |
| BE 平台字节序 | reader 显式换序，用例进 reader gate（host 为 LE，逻辑评审覆盖） |
| path 规范化与 `nextpas.core.path` 的关系 | vfs 内部语法自持；os 边界转换用 path seam；若第三处出现同需求再讨论下沉 L1 |

## 当前状态

- S0 完成：设计文档随本提交进入评审/landing 流程。
- 下一步：S1/S2 可并行开工。
