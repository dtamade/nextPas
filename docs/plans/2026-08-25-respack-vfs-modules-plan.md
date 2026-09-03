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
| `core/docs/respack/CONTRACT.md` | 代码契约：不变量 INV-R1..R10、错误表、性能契约（0.9 草案） |
| `core/docs/respack/PARITY-go-rust.md` | Go/Rust 一手来源对标矩阵（asar/Tauri/rust-embed/include_dir/Go embed） |
| `core/docs/vfs/README.md` | 树视图模块契约：IVfs、错误语义、后端矩阵、零拷贝与生命期规则 |
| `core/docs/vfs/CONTRACT.md` | 代码契约：不变量 INV-V1..V10、错误表、conformance 目标（0.9 草案） |

实现与文档冲突时，以设计文档为准并先修文档。

## 对标驱动的关键设计决策（已定稿，证据见 PARITY 文档）

0. **语义基线取自 Go io/fs**：ValidPath 路径语法（含 `.` 根特例）、PathError 式
   Op/Path 错误上下文、fs.Sub 重定根视图、fstest 级一致性属性电池、WalkDir 对等物
   `VfsWalk` 与包级辅助函数、MapFS 对等物 memtree——全盘采纳；接口最小化策略与
   phf O(1) 索引为有意偏离并记录理由（后者留 flag bit2 扩展槽）。
1. **respack 仅依赖 L0-L1**（base/errors + embed.limits L1 策略）：纯格式层阈值策略已抽离 `nextpas.core.embed.limits` 独立 L1，`respack.limits` 为兼容转发；FNV-1a 内联不依赖 checksum；digest 区存**不透明 32 字节摘要、算法由调用方注入**（SHA-256 属 hash 域，依赖倒置）；目录扫描收口在 `dirsource` 单元（唯一 L2→L2 seam）。
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

### S3 — vfs 后端与门面（已完成，2026-08-25）

依赖 S1+S2。任务：
- [x] `nextpas.core.vfs.embedded.pas` — 零拷贝切片 + `AOwnsBlob` 生命期语义
- [x] `nextpas.core.vfs.os.pas` — fs/path 适配与类型转换
- [x] `nextpas.core.vfs.sub.pas` — CreateSubVfs 重定根视图（Go fs.Sub 对等物）
- [x] 门面便利函数：`VfsReadAllBytes/VfsReadAllText` + `VfsWalk`（Go WalkDir 对等物）+
  `VfsStat/VfsList` 包级辅助
- [x] source-contract 测试锁定依赖白名单

验证门：
```bash
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_embedded
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_os            # 折叠进 conformance，见下
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_conformance   # fstest 属性电池 × 后端矩阵
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_facade
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_source_contract
```

出口条件（已满足）：conformance P1–P8 全过（三后端 × 整树/Sub 视图）+ INV-V12
positioned 读断言；零拷贝地址断言生效（P8）；source-contract uses 白名单断言全绿；
registry vfs 行更新为已落地形态。

实现期决策记录：
- **test_vfs_os 独立门折叠进 conformance**：os 后端全部行为断言在属性电池里以真实
  目录夹具覆盖，独立门只会复制同一套夹具（README 测试计划节同步记录）
- **新增 test_vfs_facade 门**：锁定"开发态/发布态工厂切换"承诺——同一纯门面 API
  consumer 在三后端产出一致树签名；并覆盖 VfsWalk 早停与便利包装
- **golden 快照**（writer gate）：固定输入集构建产物与提交的
  `golden_respack_v1.inc` 逐字节比对，INV-R5 从"声称"变门禁；由 rp-check/gen_golden 生成
- **perf smoke**（roundtrip gate）：10k 条目 build + 全量 Find 总耗时硬上限
  （1000ms 宽松预算防 O(n²) 回归，非基准测试），stopwatch 计时 + 全量有序性抽查

### S4 — 嵌入工具链（已完成，2026-08-26）

任务：
- [x] `.inc` 生成器（typed const snippet 与完整单元两种形态）——格式逻辑落 core 侧
  `nextpas.core.respack.embed`（glob 过滤/prefix 映射/inc 发射器），CLI 只留参数
  解析薄壳：`core/tools/respack/rp_pack.lpr`
- [x] 工具选项面（对标 rust-embed derive 属性与 asar unpack-dir）：
  include/exclude glob、StripPrefix/AddPrefix 映射、`--dedup`、`--digest sha256`
  （算法注入，CLI 组装 hash 域闭包）、extract-to-dir（收口 dirsource seam 单元）
- [x] 示例：`core/examples/nextpas.core.vfs/demo_asset_embed/`——同一 consumer 在
  os/embedded 双后端跑通开发态/发布态切换
- [x] 基准数字记入 `core/docs/respack/README.md`「嵌入载体」节：
  编译耗时 typed const ≈1.1s/MB 线性 vs `.pack` 恒定 ≈0.3s；启动首资产 1MB 包
  const ≈51µs vs 文件读入 ≈3.3ms；writer 512MB 上限构建成功、峰值 RSS ≈2×输入

出口条件已满足：示例 host fpc 构建运行通过；基准可复现（脚本 + 两基准程序）。

实现期决策与修复记录：
- **dirsource 内容锚点生命期缺陷修复（根因修复，非本切片引入）**：枚举返回后内容
  缓冲即释放，调用方 Data 全体悬垂，S3 gate 靠分配器运气通过。改为 bundle record
  （Entries + Contents 锚点同值返回）；补 mtime/size 携带回归测试
- **walk 回调不携带 Size/ModTime**：dirsource seam 内显式 Stat 补齐（上游 fs.dir
  BuildWalkInfo 缺口已记录，待 fs lane 评估是否下沉）
- **embed 不经 Include 回调过滤**：全枚举 + 单趟过滤映射，规避跨帧闭包捕获的不确定性
- **源契约门禁扩展**：respack 单元清单纳入 embed；seam 断言新增"仅允许 fs.glob"变体

### S5 — http.static 接入 IVfs（跨模块 slice，已完成 2026-08-26）

按 AGENTS.md 跨模块纪律单独立项说明：理由、影响面（`http.static` 内容源抽象）、
风险、额外验证（http focused gate + vfs gate）。ETag 取 `ContentHash`，
If-Modified-Since 取 `ModTime`。详见 `docs/plans/2026-08-26-http-static-vfs-s5-plan.md`。

### S6 — L3装饰器 transform/compressed（G6闭环，2026-08-30）

动机：ADR 0003 约定 vfs 内核保持 STORE 零拷贝，压缩/加密由 L3 装饰器承载；S6 将 `S6-B/C` 落地为可验证门禁，消除"12门宣称10门实存"漂移（transform/compressed两门缺失）。

任务（plan §2 G6规格）：
1. `nextpas.core.vfs.transform.pas` — L3通用字节变换装饰器：`TVfsTransformFunc/TVfsShouldTransformFunc` 注入，Stat 单源 Size/ContentHash 校正，OpenRead 单次 VfsReadAllBytes 复用 Pointer 判等零二次IO，ETag禁用，Op/Path 完整（'wrap'/'stat'/'open' + 'transform failed' 包装），CaseSensitive/List透传
2. `nextpas.core.vfs.compressed.pas` — L3解压薄门面：经 transform 承载 gzip，策略仅留 `VFS_DECOMPRESS_MAX_BYTES→GZIP_MAX_DECOMPRESS_BYTES` 单源32MiB防bomb + `daAuto/daGzip`语义 + `IsGzipPred`2字节 + `COMPRESSED_HEADER_PEEK`4096头预判HeaderPred（Stat免全量读），模板复用度消除120+行样板
3. 门面 `nextpas.core.vfs.pas` 重导出 `CreateTransformingVfs/CreateDecompressingVfs` + `TVfsTransformFunc` 类型
4. 测试：`test_vfs_transform`（6用例：upper/谓词/透传/错误包装/ETag/CaseSensitive）+ `test_vfs_compressed`（7用例：daAuto/daGzip/空包/大文件头窥/ETag/透传/错误）+ `source-contract` 白名单扩展（transform/compressed seam）
5. 基准：`core/benchmarks/nextpas.core.vfs/bench_transform` 4场景阈值（Stat large非gzip header-peek / Stat gz / Open large非gzip passthrough / Open gz）

约束复用（最小改动）：
- 四件套与L0-L3分层守恒：base←intf←实现←门面，仅向下依赖；L3装饰器单向依赖L2，无L2→L2闭环
- 单源不新增重复：ValidPath 单源 `base.pathvalid`，GZIP_MAX 单源 `compress.base`，VFS侧仅薄别名/薄门面
- 性能：HeaderPred 4K + 单次读取复用（零二次IO）证据见 CONTRACT §6 + bench
- 稳定性：回绕Int64下标/悬垂防御拷贝/两段式Freeze/池资源SpinLock16槽闭环（见 vfs.base/memtree/embedded/util/CONTRACT §5）
- 高级感：Op/Path 完整 + 门面重导出（vfs.pas）

验证门：
```bash
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_writer
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_reader
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_roundtrip
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_dirsource
make focused FOCUS=core/tests/nextpas.core.respack/test_respack_embed
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_memtree
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_embedded
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_conformance
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_facade
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_transform
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_compressed
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_source_contract
make -C core/benchmarks/nextpas.core.vfs/bench_transform clean bench
```
出口条件：12门全绿（respack5+vfs5+新增2，source-contract共享1）+ bench_transform 4场景阈值绿 + heaptrc 0 leak + `git diff --check` 0 + `make hygiene` 0；G6 PENDING闭环。

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
  `core/docs/respack/PARITY-go-rust.md`），已 landing。
- S1 完成：respack 格式层（base/writer/reader/dirsource/门面）+ 4 gate 全绿，
  已 landing main（b59258fe5）。
- S2 完成：vfs 契约 + memtree + 门面便利函数，test_vfs_memtree 全绿，已 landing。
- S3 完成（2026-08-25）：三后端 embedded/os/sub + conformance/embedded/facade/
  source-contract 四个新门；writer golden 快照与 roundtrip perf smoke 补齐；
  9 个 gate 全绿、heaptrc 零泄漏。实现期发现的 FPC trunk 陷阱沉淀在
  `core/docs/respack/README.md`「实现期发现的 FPC trunk 注意事项」。
- S4 完成（2026-08-26）：嵌入工具链（embed 单元 + rp_pack CLI + demo 示例 + 基准）；
  新增 test_respack_embed 门（12 检查），源契约门禁扩展至 embed 单元；
  修复 dirsource 内容锚点生命期缺陷与 mtime/size 缺失（含回归测试）；
  10 个 gate 全绿、heaptrc 零泄漏。
- S5 完成（2026-08-26）：http.static 接入 IVfs，立项与完成记录见
  `docs/plans/2026-08-26-http-static-vfs-s5-plan.md`；test_http_static 39 门 +
  vfs 五门 + http contract/smoke 全绿；端到端示例 http_static_vfs_demo 与
  bench_servevfs 基准（embedded ≈7.0 µs/op vs os ≈16.3 µs/op，≈2.3×）落库。
- S6 完成（2026-08-30）：L3装饰器 transform通用模板 + compressed薄门面落地；新增 `test_vfs_transform` 6用例 + `test_vfs_compressed` 7用例 + `bench_transform` 4场景阈值，12门全绿（respack5+vfs5+2）+ heaptrc0 + GZIP_MAX/HeaderPred/单次复用单源证据闭环；G6 PENDING闭环，完美基线不回退。
  **本计划全部切片收官（S0-S6）。**
