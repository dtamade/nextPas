# nextpas.core.git — 扩展契约（extensions）

**模块路径**：`core/src/nextpas.core.git.native.{archive,submodule,mailmap,trailer,attributes,bundle,grep,bisect}.pas` + `nextpas.core.git.native.extensions.pas` 门面
**层级**：L2（L0-L1: base, bytes, text, fs）
**Owner**：git lane
**不变量域**：扩展能力（archive / submodule / mailmap / trailer / attributes / bundle / grep / bisect）

## 1. 范围与阈值
- 源聚合：8 单元 + 1 门面 shard（`native.extensions`），单 shard <800 行；`attributes` 委托 `wildmatch` 单源，零重复通配。

## 2. 不变量
- Archive：树扁平化→USTAR `tar`（`$4000` 递归 + 排序 + `0644/0755` 与符号链接 `2`，mtime 0，末尾 1024 零块；不含 `pax_global_header`，不下显式目录条目，忽略 umask，解包等价；`HEAD/ref` 经 `rev-parse` 16 层剥离）。
- Submodule/Mailmap/Trailer/Attributes：`.gitmodules` INI 解析、`.mailmap` 身份映射、尾注 `Key: Value` 尾块、`.gitattributes` last-match-wins（`*/?/**/[]` 通配委托 `wildmatch`）。
- Bundle v2：`# v2 git bundle` 头 + `-<oid> <title>` 前提 + `<oid> <ref>` 列表 + 空行 + `PACK` 流（经 `pack-objects --revs --delta-base-offset` 生成，SHA-1 尾 20B 校验，`GitBundleVerify` 深校验经 `GitBuildPackIndex`，`Unbundle` 落盘 `pack-<hash>.pack/.idx` 并写 `refs/*` 与 `refs/bundle/HEAD`），与 `git bundle create/verify/list-heads/fetch` 黄金互通，支持 `HEAD~/^/../` 前提语法。
- Grep：树内 `HEAD/ref/tree` 起点扁平化 `$4000` 递归 + NUL 二进制跳过 + `Pos` 固定串 + `-i` 折叠，经 `path:lineNo` 排序，对齐 `git grep -n -F`。
- Bisect：`good..bad` 经 `GitTopoOrderCommits` 排除祖先 + 回调二分，`log N` 步定位，对齐 `git bisect` 线性史。

## 3. 性能契约
- `archive` 512 块单遍 `bytes.ops` 零重复分配；`bundle/grep` 复用 `wildmatch/bytes.ops` 单源；`bisect` 计数 `O(log N)`。

## 4. 稳定性
- `bundle Write/Unbundle` 经 `WriteAtomic` + 校验，异常 `try..finally` 不留半包；`archive` 零块收尾 `try..finally`。

## 5. 与总约关系
- 本域权威：归档/束/搜索/二分语义以本文件为准；跨域仍以总 CONTRACT 为准。
