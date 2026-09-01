# respack / vfs — Go / Rust 对标矩阵

**状态日期**：2026-08-30（1.0 收官；S1 格式层/S2 契约/S3 后端/S4 工具链/S5 http.static 已收官，S6 装饰器勘误补齐）
**范围**：L2 `nextpas.core.{respack,vfs}`（已落地 1.0；FORMAT 已正确无需改）
**标杆**（均为一手来源，2026-08-25 抓取）：

| 来源 | 版本/分支 | 材料 |
|------|-----------|------|
| Go `io/fs` | golang/go master | `src/io/fs/fs.go` 全文 |
| Go `embed` | golang/go master | `src/embed/embed.go` 全文 |
| Go `testing/fstest` | golang/go master | `testfs.go`（TestFS 一致性测试） |
| Tauri EmbeddedAssets | tauri-apps/tauri dev | `crates/tauri-utils/src/assets.rs` 全文 |
| rust-embed | 8.12.0（docs.rs，2026-07-08） | derive 属性表 + trait 文档 |
| include_dir | Michael-F-Bryan/include_dir master | README |
| Electron asar | electron/asar master | README 格式规范节（JSON 头/integrity/去重） |

> 对标的是**能力 + 边界语义 + 测试强度**，不是符号名复制。

---

## 一、格式层（respack）对标

| 能力 | asar | rust-embed | include_dir | Tauri | Go embed | **nextpas 决策** |
|------|------|------------|-------------|-------|----------|------------------|
| 随机访问索引 | JSON 树头 + offset | 编译期 phf/map | 静态树结构 | phf::Map | 编译器生成静态数据 | 排序数组 + 二分（Done 设计） |
| 整包完整性 | — | — | — | — | — | 每条目 FNV-1a 32（ETag 级） |
| 强完整性（防篡改） | **SHA256 全量 + 4KB 分块哈希** | sha2 dev-dep | — | CSP 哈希注入 | — | **采纳弱化版**：可选 digest 区（每条目 SHA-256，算法由调用方注入），分块哈希推迟 |
| 内容去重 | **同内容单副本共享 offset** | — | — | — | — | **采纳**：writer 可选项，fnv 候选 + 字节级回验 |
| 压缩 | 无原生（transform 钩子） | include-flate | TODO 中 | **brotli 构建期压缩，读时解压分配** | — | 勘误 Done：`codecId` 槽位 + L3 `vfs.compressed` gzip 按需解压（`CreateDecompressingVfs` 经 `transform` 模板，`VFS_DECOMPRESS_MAX_BYTES→GZIP_MAX 32MiB` 单源防 bomb，STORE 零拷贝保持） |
| 元数据 | size/executable/integrity | metadata_only 模式 | metadata feature | — | ModTime | size/modTime/hash；"只列清单不读内容"由索引天然支持 |
| 路径键形态 | 树形 JSON | folder/prefix/include/exclude | 目录树 | AssetKey：强制根 `/`、unix 分隔、无尾斜杠、**目录不入表** | — | 规范路径语法对齐 Go ValidPath；前导 `/` 不采用（Go unrooted 风格）；include/exclude/prefix 归工具层 |
| 大文件流式写入 | 流式 | — | — | — | — | v1 内存构造 + 显式上限声明；超限策略 S4 基准后定 |

### 关键取舍记录

1. **强完整性的依赖倒置**（asar 启发）：SHA-256 属 L2 hash/crypto 域，而 respack 仅依赖
   L0。解法：digest 区存**不透明 32 字节摘要**，writer 经调用方注入的摘要函数生产，
   校验助手放在消费侧 hash 模块。格式零加密依赖。
2. **压缩不进 v1**（Tauri/rust-embed 反证两面）：Tauri brotli 读时要分配解压缓冲，
   牺牲零拷贝；include_dir 至今没做压缩也不影响可用性。前端资源 gzip/brotli 更适合在
   HTTP 层做内容编码（http.static 职责）。故只留 `codecId` 槽位。
3. **去重安全策略**（asar 同款问题）：以 fnv32 为候选键、复用前逐字节比对，杜绝哈希碰撞
   错误共享。

## 二、视图层（vfs）对标

| 能力 | Go io/fs | Rust 生态 | **nextpas 决策** |
|------|----------|-----------|------------------|
| 核心接口最小化 | `FS` 仅 `Open`；ReadDirFS/ReadFileFS 能力接口按需断言 | 各 crate 自定 trait | **偏离并记录理由**：IVfs 固定四操作（Exists/Stat/List/OpenRead），因三个后端全能高效实现，无需运行期能力探测；批量操作保持门面函数 |
| 路径语法 | ValidPath：UTF-8、unrooted、`/` 分隔、禁空段/`.`/`..`；`.` 特指根 | — | **全盘采纳**（含 `.` 根特例）；反斜杠任何平台都不是分隔符 |
| 结构化错误 | `PathError{Op,Path,Err}` + sentinel errors | — | **采纳**：EVfsError 增加 `Op`/`Path` 上下文字段 + 异常类分层 |
| 重定根视图 | `fs.Sub`（fstest 强制测试） | — | **采纳**：新增 `vfs.sub` 单元 `CreateSubVfs(Fs, Root)` |
| 实现一致性测试 | `fstest.TestFS`：从根遍历、子名合法性、Stat↔DirEntry 一致、Open 行为、期望文件存在、Sub 往返 | 无统一标准 | **采纳整套属性清单**为 `test_vfs_conformance` 门，跑满三后端 + Sub 视图 |
| 开发态工作流 | — | rust-embed debug 默认读磁盘（免重编译） | **同构方案已存在**：开发接 `os` 后端、发布接 `embedded`，consumer 零改动 |
| MIME 推断 | net/http 按扩展名 | rust-embed 独立 mime_guess crate | 保持消费侧（http.static）职责 |
| 零拷贝 | embed.FS 文件实现 Seeker+ReaderAt，指向静态数据 | Tauri Cow::Borrowed 切片 | 维持设计：切片直指 blob，接口持引用保活 |
| 多源聚合 | Go `io/fs` 无（单 FS） | — | **超越**：`mount` 异前缀最长匹配 + `overlay` 同根优先级 patch>dlc>base（游戏 Unreal Pak / Unity AssetBundle 热更模型，List去重合并，ETag优先透传，`O(n log n)`） |

## 三、Essential API 覆盖矩阵（符号级，2026-08-25 深化）

图例：`定稿`（设计已锁）/ `Partial` / `Deferred`（显式推迟有据）/ `N/A`

### Go `io/fs` 逐符号

| Go API | nextpas 对应物 | 状态 | 说明 |
|--------|----------------|------|------|
| `fs.FS.Open` | `IVfs.OpenRead`（+Exists/Stat/List 富化） | 定稿 | 只读域四操作合一 |
| `fs.ValidPath` | `vfs.base` 规范路径校验 | 定稿 | 全盘采纳含 `.` 根 |
| `fs.File{Stat,Read,Close}` | `IStream`（io.intf） | 定稿 | 句柄级 Stat 推迟：只读场景经 `IVfs.Stat` 已足 |
| `io.Seeker` / `io.ReaderAt` 能力文件 | `IStream.Seek`；`IReaderAt` 经 Supports 可选能力 | 定稿 | embedded/memtree/os 均可提供 ReaderAt，写入 SHOULD 不变量 |
| `fs.DirEntry` / `fs.FileInfo` | `TEntryInfo` / `TStatInfo` | 定稿 | record 替代接口（值语义） |
| `fs.ReadDirFile.ReadDir(n)` 流式 | `List` 整表返回 | Deferred | 流式目录迭代器待 >10k 条目场景立项；整表符合当前规模 |
| ReadDirFS / ReadFileFS / StatFS 能力接口 | 有意收敛为固定四操作 | 定稿偏离 | 三后端全能高效实现；理由见 vfs README 决策记录 |
| `fs.Sub` | `CreateSubVfs`（vfs.sub 单元） | 定稿 | fstest 强制测 Sub 往返，同构 |
| `fs.WalkDir` | **`VfsWalk(AFs; ARoot; ACallback)`**（本轮补齐） | 定稿 | 字典序确定性遍历；纯 IVfs 组合无新依赖 |
| `fs.Glob` | — | Deferred | 匹配器在 fs.glob/path 域；出现真实需求时以 path seam 接入，不提前建依赖 |
| 包级 `fs.ReadFile/Stat/ReadDir` 辅助 | 门面 `VfsReadAllBytes/Text` + **`VfsStat/VfsList`**（本轮补齐） | 定稿 | 与 Go"包函数优化路径"同构 |
| sentinel errors（ErrNotExist 等） | 异常类分层 EVfsNotFound 等 | 定稿 | 异常 vs 返回值为仓库既定风格 |
| `fs.PathError{Op,Path}` | `EVfsError.Op/Path` | 定稿 | |

### Go `embed` / `testing/fstest` 逐符号

| Go API | nextpas 对应物 | 状态 | 说明 |
|--------|---------------|------|------|
| `//go:embed` 指令 | S4 pack CLI + `.inc` 生成器 | Deferred→S4 | Pascal 无宏；构建工具承担 |
| `embed.FS` | `IVfs`（embedded 后端） | 定稿 | |
| `embed.FS.ReadDir/ReadFile` 方法 | 门面 `VfsList/VfsReadAllBytes` | 定稿 | 包函数而非类型方法，等价能力 |
| `fstest.TestFS` 属性电池 | `test_vfs_conformance` P1–P8 × 后端矩阵 | 定稿 | 强度对齐：根打开/子名合法/Stat↔List 一致/Sub 往返 |
| `fstest.MapFS` | `vfs.memtree`（Builder+Freeze） | 定稿 | 测试替身定位完全一致 |

### Rust 侧逐项

| rust-embed / include_dir / Tauri | nextpas 对应物 | 状态 | 说明 |
|----------------------------------|----------------|------|------|
| `#[folder/prefix/include/exclude]` | S4 工具选项同名能力 | Deferred→S4 | 工具层过滤映射 |
| debug 构建读磁盘 | os/embedded 双态工厂切换 | 定稿 | consumer 零改动，conformance 强制双态同结果 |
| `metadata_only` | index-only 枚举天然支持 | 定稿 | reader 不触内容即可 Count/枚举 |
| web 框架 handlers（axum/actix…） | http.static `ServeVfs(IVfs)`（S5 已落地） | Done (S5) | ETag 取条目 fnv32、条件请求/Range/MIME 与 fs 版同语义；端到端示例与三后端基准见 README「嵌入载体」节 |
| include_dir `extract()` | 工具 extract-to-dir 选项 | Deferred→S4 | 调试/迁移用途 |
| Tauri phf 完美哈希 O(1) | 排序数组二分 O(log n) | 定稿偏离 | 10k 条目 ≤14 次缓存友好比较；FORMAT 预留 flag bit2 hash-index 区，超大规模再启用 |
| Tauri brotli / include-flate | `vfs.compressed` gzip 按需解压（`CreateDecompressingVfs` 经 `transform` 模板） | Done (gzip via vfs.compressed) | 勘误：原 Deferred 已由 S6 L3 装饰器补齐 gzip 实现（`daAuto` 4K HeaderPred 免全量读 + 单次 `VfsReadAllBytes` 复用零二次 IO + 32MiB 防 bomb），STORE 零拷贝保持；HTTP 编码另选承载面 |

> **勘误与基准固化（2026-08-30 P0-4 1.0）**：压缩行原 `Deferred` 勘误为 `Done (gzip via vfs.compressed)`——S6 以 L3 装饰器 `vfs.transform` 通用模板 + `vfs.compressed` 薄门面补齐 gzip 按需解压（`GZIP_MAX 32MiB` 单源、`daAuto` 4K HeaderPred、`VFS_DECOMPRESS_MAX_BYTES` 薄别名），`bench_transform` 4 场景阈值已固化（`Stat/large-non-gzip/header-peek` 1MiB 非 gzip 免解压 ~972 ns、`Stat/gz/decompress` 64KiB ~51 µs、`Open/large-non-gzip/passthrough` 单次复用 ~2.26 ms、`Open/gz/decompress` ~107 µs；见 `core/docs/vfs/README.md` 基准节与 `core/docs/vfs/CONTRACT.md` §6 S6 行 + `test_vfs_compressed` 7/7 含 1MiB 头部预判功能契约）。

## 四、安全与威胁模型（企业级增补）

| 威胁 | 缓解 | 出处 |
|------|------|------|
| 路径穿越（zip-slip 类） | canonical grammar 拒绝 `..`/绝对路径/反斜杠；reader 校验存储形态 | FORMAT 路径规范；与 zip 单元纪律同源 |
| 符号链接逃逸 | 格式无 symlink/device 条目类型——按构造不存在 | FORMAT entry 布局 |
| 资源耗尽（恶意超大包） | Open 仅建索引视图零内容拷贝；entryCount/blobTotal 上限校验；writer 显式 512MB raise | CONTRACT INV-R10 |
| 数据被篡改/供应链投毒 | digest 区（注入算法，推荐 SHA-256）；发布审计流程消费 | FORMAT digest 区；asar integrity 同类 |
| 数据被当代码执行 | blob 恒为数据段；嵌入载体 typed const 无执行语义 | `.inc` 载体设计 |
| 哈希碰撞错误共享 | 去重必须字节级回验 | CONTRACT INV-R6 |

## 五、性能对照（同机吞吐，FPC/Go/Rust 量化基线，2026-08-30）

| 场景 | nextpas | FPC RTL | Go embed | Rust include_dir | 结论 |
|------|---------|---------|----------|------------------|------|
| ServeVfs 4KiB 满树直调 (`bench_servevfs` 65条目) | embedded 7.0µs | `TFileStream` 8.5µs | `embed.FS` 7.2µs | `include_dir` 7.1µs | **≤FPC (1.21×快) 且 0.97×Go/Rust**，零拷贝窗口 (`ContentPtr` inline + `bytes.ops.Move`) |
| 启动首资产可用 1MiB 包 (200×5KiB) | const 51µs | `TMemoryStream` 60µs | 55µs | 52µs | **≤FPC 且 1.3×内** |
| Writer 512MiB 吞吐/峰值 | 1.15× 内峰值 | 1.02×FPC | 0.98×Go | 0.97×Rust | **不低于FPC，接近Go/Rust** |

> 同机 `benchmarks/nextpas.core.respack/RESULTS.md` 快照 + `compare_go`/`compare_rust` 复现套件；`bench_servevfs`/`bench_embed_startup` 以 `AddBaseline` (`fpc-rtl`/`go-embed`/`rust-include_dir`) + `TBenchSuite` 校准计时输出，不只内部阈值，满足设计规范 §12 “不低于FPC、接近Go/Rust” 量化门限。

## 五、评分卡（自评，设计期）

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| 质量 Quality | 9.2 | 对齐 Go 语义基线（路径/错误/测试三件套）；压缩与分块哈希有明确槽位而非拍脑袋砍掉 |
| 规模 Scale (Essential) | 9.5 | 覆盖 asar 去重/Tauri 压缩位/rust-embed 工具链属性的对等物或显式推迟记录 |
| 测试强度 | 9.0 | fstest 级属性电池 × 多后端矩阵，超过单一生态常见水平 |

目标线：实现落地后质量 ≥ 9.0 维持；conformance 门为硬出口条件。

## 六、来源清单

- https://raw.githubusercontent.com/golang/go/master/src/io/fs/fs.go
- https://raw.githubusercontent.com/golang/go/master/src/embed/embed.go
- https://raw.githubusercontent.com/golang/go/master/src/testing/fstest/testfs.go
- https://raw.githubusercontent.com/tauri-apps/tauri/dev/crates/tauri-utils/src/assets.rs
- https://docs.rs/rust-embed/8.12.0/rust_embed/ （含 derive.RustEmbed 属性页）
- https://raw.githubusercontent.com/Michael-F-Bryan/include_dir/master/README.md
- https://raw.githubusercontent.com/electron/asar/master/README.md （Format/Deduplication 节）

GitHub API 限流期间以 raw/docs.rs 为准；版本以上述抓取日快照为准。
