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
| `core/docs/respack/README.md` | 格式模块定位、单元结构、依赖白名单、嵌入载体、完整性双档 |
| `core/docs/respack/FORMAT.md` | 线格式 v1 权威定义：字节布局、校验清单、路径语法、扩展策略 |
| `core/docs/respack/PARITY-go-rust.md` | Go/Rust 一手来源对标矩阵（asar/Tauri/rust-embed/include_dir/Go embed） |
| `core/docs/vfs/README.md` | 树视图模块契约：IVfs、错误语义、后端矩阵、零拷贝与生命期规则 |

实现与文档冲突时，以设计文档为准并先修文档。

## 对标驱动的关键设计决策（已定稿，证据见 PARITY 文档）

0. **语义基线取自 Go io/fs**：ValidPath 路径语法（含 `.` 根特例）、PathError 式
   Op/Path 错误上下文、fs.Sub 重定根视图、fstest 级一致性属性电池——四件全盘采纳；
   接口最小化策略有意偏离并记录理由。
1. **respack 仅依赖 L0**（base/errors）：纯格式层；FNV-1a 内联不依赖 checksum；
   digest 区存**不透明 32 字节摘要、算法由调用方注入**（SHA-256 属 hash 域，
   依赖倒置）；目录扫描收口在 `dirsource` 单元（唯一 L2→L2 seam）。
2. **vfs v1 只读**；自有 `TEntryInfo/TStatInfo` 不复用 `fs.base`；流词汇复用
   `io.intf.IStream`。
3. **vfs→fs seam 收口在 `vfs.os` 单元**；其余 vfs 单元禁止 uses fs/respack
   （source-contract 测试锁定）。新增 `vfs.sub` 重定根单元（Go fs.Sub 对等物）。
4. **完整性双档**：条目 fnv32（ETag 级）+ 可选 SHA-256 digest 区（审计级，
   asar integrity 的依赖倒置版）；分块哈希推迟。
5. **内容去重**为 writer 可选项：fnv32 候选 + 字节级回验（asar 同策略）。
6. **压缩不进 v1**：只留条目 `codecId` 登记表槽位（Tauri brotli 读时分配破坏零拷贝；
   HTTP 内容编码归 http.static）。
7. **嵌入载体**三轨：`.pack` 文件 / 生成 `.inc` typed const（S4）/ `{$R}`（按需）。
8. mount/overlay 推迟至有真实双源场景；接口留位不留桩。

## 仓库约束：FPC RTL 隔离与反哺（2026-08-25 增补）

规则：`nextpas.core.*` 不准直接依赖引用 FPC RTL，一切经 nextpas.core 解决；不满足的
能力通过反哺 nextpas.core 实现。落到本设计：

1. **uses 白名单**：respack/vfs 全部单元只允许 settings.inc + base/errors/exception
   （+io.intf/fs/path/respack.reader 按依赖白名单表）；禁 `SysUtils`/`Classes`/
   OS 单元直引。异常一律继承 `nextpas.core.exception.Exception`（全框架唯一
   SysUtils.Exception 触点在该根模块内桥接）。source-contract 测试逐单元断言。
2. **反哺清单**：mmap 大包读取 → platform/mem 立项（v1 不做）；目录监视 → 消费既有
   fs.watch；其余当前无缺口。
3. **存量抽取盘点**（实查结论）：compiler/tools 无虚拟 FS/打包存量可抽；
   bench `*.inc` 是代码拆分先例非数据嵌入；compiler 的 ResourceToolProfileId 属目标
   工具链档案与资产嵌入无关。S4 工具的格式逻辑必须全部落 core 侧（respack.writer），
   CLI 只留薄壳——正向示范"项目代码抽出来进 core"。

## 阶段切片

### S0 — 设计文档（本切片）

- [x] 三份设计文档 + 本计划落盘
- Lane: `codex/core-respack-vfs`（worktree `.worktrees/core-respack-vfs`）
- 出口条件：文档评审通过，landing 进 main

### S1 — respack 格式层

Lane 建议：沿用 `codex/core-respack-vfs` 或拆 `codex/core-respack`。

任务：
1. `nextpas.core.respack.base.pas` — header/entry record（40B，含 codecId）、常量、
   错误类型、内联 FNV-1a、路径规范校验（Go ValidPath 语义）
2. `nextpas.core.respack.writer.pas` — 排序/去重（fnv 候选+字节回验）/对齐/blob 组装/
   可选 digest 区（摘要函数注入）
3. `nextpas.core.respack.reader.pas` — FORMAT.md 八步校验清单 + 二分查找 + codecId
   登记表拒绝
4. `nextpas.core.respack.dirsource.pas` — fs 目录枚举适配
5. 门面 `nextpas.core.respack.pas`

验证门：
```bash
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_writer
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_reader
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_roundtrip
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_dirsource
```
出口条件：FORMAT.md 校验清单每条规则至少一个拒绝用例；golden 字节快照（含 digest 区
与去重共享槽位形态）；digest 与注入函数一致性用例；source-contract 含 uses 白名单
断言（禁 SysUtils/Classes/OS 单元直引）；heaptrc 零泄漏；
registry 增加 `respack` 行（L2，source-contract → focused-runtime）。

### S2 — vfs 契约与内存树

可与 S1 并行（仅共享路径语法定义文本，无代码依赖）。

任务：
1. `nextpas.core.vfs.base.pas` / `errors.pas`（EVfsError 含 Op/Path）/ `intf.pas`
2. `nextpas.core.vfs.memtree.pas` — Builder + Freeze 不可变树

验证门：
```bash
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_memtree
```
出口条件：错误语义表全覆盖（含 Op/Path 断言）；`.` 根特例；并发读 smoke；heaptrc 零泄漏。

### S3 — vfs 后端与门面

依赖 S1+S2。任务：
1. `nextpas.core.vfs.embedded.pas` — 零拷贝切片 + `AOwnsBlob` 生命期语义
2. `nextpas.core.vfs.os.pas` — fs/path 适配与类型转换
3. `nextpas.core.vfs.sub.pas` — CreateSubVfs 重定根视图（Go fs.Sub 对等物）
4. 门面便利函数 `VfsReadAllBytes/VfsReadAllText`
5. source-contract 测试锁定依赖白名单

验证门：
```bash
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_embedded
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_os
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_conformance   # fstest 属性电池 × 后端矩阵
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_facade
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_source_contracts
```
出口条件：conformance P1–P8 全过（三后端 × 整树/Sub 视图）；零拷贝地址断言生效；
source-contract 含 uses 白名单断言（含禁 SysUtils/Classes/OS 单元直引）；
registry 增加 `vfs` 行。

### S4 — 嵌入工具链

任务：
1. `.inc` 生成器（把 blob 转成 typed const Pascal 单元），放工具侧
2. 工具过滤/映射选项（对标 rust-embed derive 属性与 asar unpack-dir）：
   include/exclude glob、路径 prefix 映射、去重开关、digest 开关（算法选择）
3. 示例：最小 app 打包前端资源并用 os/embedded 双后端跑通（开发态/发布态切换演示）
4. 大小基准：const 数组 vs .pack 读入的编译时间/启动时间对比数据；writer 内存上限
   （512MB 声明）实测

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
| path 规范化与 `nextpas.core.path` 的关系 | vfs 内部语法自持（Go ValidPath）；os 边界转换用 path seam；若第三处出现同需求再讨论下沉 L1 |
| writer 内存上限 512MB | v1 显式声明不假装支持超大输入；S4 基准后决定是否立项流式两遍构造 |
| 分块哈希（asar blocks 对等物） | 推迟；有部分校验真实需求时随 digest 区扩展，不动布局 |

## 当前状态

- S0 完成：设计文档定稿（含 2026-08-25 Go/Rust 一手来源对标修订，见
  `core/docs/respack/PARITY-go-rust.md`），随本提交进入评审/landing 流程。
- 对标后主要变更：Go ValidPath/PathError/fs.Sub/fstest 电池四件采纳；
  digest 区 + 去重 + codecId 槽位入格式；压缩显式推迟并留槽。
- 下一步：S1/S2 可并行开工。
