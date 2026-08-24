# respack / vfs — Go / Rust 对标矩阵

**状态日期**：2026-08-25
**范围**：L2 `nextpas.core.{respack,vfs}`（设计阶段）
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
| 压缩 | 无原生（transform 钩子） | include-flate | TODO 中 | **brotli 构建期压缩，读时解压分配** | — | 条目预留 `codecId` 槽位，v1 仅定义 0=store；编解码随 compress 模块 seam 后续立项 |
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

## 三、评分卡（自评，设计期）

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| 质量 Quality | 9.2 | 对齐 Go 语义基线（路径/错误/测试三件套）；压缩与分块哈希有明确槽位而非拍脑袋砍掉 |
| 规模 Scale (Essential) | 9.5 | 覆盖 asar 去重/Tauri 压缩位/rust-embed 工具链属性的对等物或显式推迟记录 |
| 测试强度 | 9.0 | fstest 级属性电池 × 多后端矩阵，超过单一生态常见水平 |

目标线：实现落地后质量 ≥ 9.0 维持；conformance 门为硬出口条件。

## 四、来源清单

- https://raw.githubusercontent.com/golang/go/master/src/io/fs/fs.go
- https://raw.githubusercontent.com/golang/go/master/src/embed/embed.go
- https://raw.githubusercontent.com/golang/go/master/src/testing/fstest/testfs.go
- https://raw.githubusercontent.com/tauri-apps/tauri/dev/crates/tauri-utils/src/assets.rs
- https://docs.rs/rust-embed/8.12.0/rust_embed/ （含 derive.RustEmbed 属性页）
- https://raw.githubusercontent.com/Michael-F-Bryan/include_dir/master/README.md
- https://raw.githubusercontent.com/electron/asar/master/README.md （Format/Deduplication 节）

GitHub API 限流期间以 raw/docs.rs 为准；版本以上述抓取日快照为准。
