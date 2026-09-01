# nextpas.core.git — 暂存区契约（staging）

**模块路径**：`core/src/nextpas.core.git.native.{index,cachetree,status,ignore,worktree,lsfiles,clean,wildmatch,common,util}.pas` + `nextpas.core.git.native.staging.pas` 门面
**层级**：L2（L0-L1: base, bytes, text, fs；同层单向 wildmatch 复用，委托 `bytes.ops`）
**Owner**：git lane
**不变量域**：暂存区（index / cache-tree / status / ignore / worktree / lsfiles / clean）

## 1. 范围与阈值
- 源聚合：10 单元 + 1 门面 shard（`native.staging` 委托 `bytes.ops`），单 shard <800 行；`wildmatch` 单源 `inline GitWildSegment*/GitSegmentsMatch`，ignore/attributes 委托此引擎零重复。

## 2. 不变量
- Index: DIRC v2/v3/v4 + TREE 扩展，双遍精确尺寸序列化，SHA-1 全量校验；小写 split-index/sparse 扩展遇即拒绝（非跳过）。
- Cache-tree：记录解析（NUL 前缀、计数哨兵 -1）+ 两遍序列化，冲突失效整树粒度（与 git 最小目录失效语义等价——无效缓存必重算）。
- Status：HEAD↔index / index↔worktree / untracked 三态聚合 + rename/copy 检测（oid 100 快路径 + hashsig 0..100、阈值 50 配对、porcelain 分组序归并，conflict 跳过 rename；copy 需显式开启）+ .gitignore 链（`.git/info/exclude` + `core.excludesFile` + 逐级 `.gitignore`，`~/` 展开）+ submodule 目录校验；clean 另支持 `-d/-x/-n`。
- Wildmatch：`*/?/**/[]` 含转义/字符类零 `SysUtils`，`inline` 热路径。

## 3. 性能契约（复用 bytes.ops 单源）
- `Wild/Segment:inline|Class|SegmentsMatch:**` ≤100 ns/op（≥10 Mops/sec），单源 `wildmatch`，inline 零拷贝视图 `TByteSpan/PByte+Len`。
- Index 读写零重复 `ReadFile`（`Stat.mtime+size` 缓存 `TBytes`，见 commit-graph 复用模式）；`BytesConcatMany/SpanConcatMany` 单次分配防 O(n²) churn。

## 4. 稳定性
- `IMappedFile` 计数拥有，`TPack/Index` 异常 `try..finally` 重抛不泄漏；`Status` 扫描 `fs` 句柄按目录 `try..finally` 关闭。
- 与对象层同 `EGitError` 单源 `native.base`。

## 5. 与总约关系
- 本域权威：暂存区状态/忽略规则/索引格式以本文件为准；跨域仍以总 CONTRACT 为准。
- 缺能力先反哺 owner：路径/通配能力归 `bytes.ops`/`wildmatch`，暂存区仅编排。
