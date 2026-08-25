# respack 线格式 v1

本文是 respack 二进制格式的**权威定义**。实现（reader/writer）与工具必须以本文为准；
改格式先改本文并升版本。

对标依据见 [PARITY-go-rust.md](PARITY-go-rust.md)（asar / Tauri / rust-embed /
include_dir / Go embed 逐项决策记录）。

- 版本：`1`
- 字节序：固定 little-endian；大端平台由 reader 显式换序（`platform.endian` inquiry 判定）
- 所有 offset 均为相对 blob 起点的绝对偏移
- 所有保留字段必须写 0，reader 必须拒绝非 0 保留值（防误扩展）

## 总布局

```
偏移 0x00      ┌──────────────────────────┐
               │ header (40 B)            │
偏移 0x28      ├──────────────────────────┤
               │ index (entryCount × 40B) │  按 path 字节序升序
               ├──────────────────────────┤
               │ string table             │  全部路径 UTF-8 拼接，无 NUL
               ├──────────────────────────┤  （16 字节对齐处开始）
               │ data blobs               │  各起始于 16 字节对齐边界
               ├──────────────────────────┤
               │ digest 区（可选）         │  entryCount × 32B，flags.bit1 置位时存在
blobTotal      └──────────────────────────┘
```

顺序固定：header → index → string table → data → digest。reader 可按此顺序做递进式
越界校验。

## Header（40 字节）

| 偏移 | 大小 | 字段 | 类型 | 含义 |
|------|------|------|------|------|
| 0x00 | 4 | `magic` | bytes | `'N' 'P' 'R' 'S'` |
| 0x04 | 4 | `version` | u32 LE | 必须 = 1 |
| 0x08 | 4 | `flags` | u32 LE | bit0 = 全部条目 hash 有效；bit1 = digest 区存在；其余必须为 0 |
| 0x0C | 4 | `entryCount` | u32 LE | 条目数 |
| 0x10 | 8 | `indexOffset` | u64 LE | index 起始偏移（v1 恒为 40） |
| 0x18 | 8 | `digestOffset` | u64 LE | digest 区起始；无则 0 |
| 0x20 | 8 | `blobTotal` | u64 LE | 整个 pack 总字节数 |

## Index Entry（40 字节 × entryCount）

| 偏移 | 大小 | 字段 | 类型 | 含义 |
|------|------|------|------|------|
| +0x00 | 4 | `pathOffset` | u32 LE | 路径在 string table 内的偏移 |
| +0x04 | 2 | `pathLen` | u16 LE | 路径 UTF-8 字节长度（无 NUL） |
| +0x06 | 2 | `flags` | u16 LE | bit0 = 本条目 hash 有效；其余必须为 0 |
| +0x08 | 8 | `dataOffset` | u64 LE | 内容起始绝对偏移 |
| +0x10 | 8 | `size` | u64 LE | 内容字节数 |
| +0x18 | 8 | `modTime` | i64 LE | Unix 秒；0 = 未知 |
| +0x20 | 4 | `hash` | u32 LE | FNV-1a 32（原始内容字节流；仅 bit0 置位时有效） |
| +0x24 | 1 | `codecId` | u8 | 内容编解码：`0` = store（原样存储）；未知值 reader 必须拒绝 |
| +0x25 | 3 | `reserved` | bytes | 必须 = 0 |

index 数组按 `path` 的**字节序升序**排列（UTF-8 字节直接比较，不做语言敏感排序），
支持二分查找。数组逻辑终点：`indexOffset + entryCount × 40`。

### hash 有效性：header bit0 与 entry bit0 的关系

entry 级 flag 是**权威**判定（逐条目独立）；header bit0 只是"全部条目 hash 均有效"
的汇总提示，供 reader 跳过逐条判断的快速路径。二者必须一致（writer 保证）；
reader 校验规则：header bit0 = 0 时允许部分条目 bit0 = 1；header bit0 = 1 时
任何条目 bit0 = 0 即整包拒绝。

### codecId 登记表

| 值 | 编码 | 状态 |
|----|------|------|
| 0 | store | v1 已定义 |
| 1+ | 未分配 | reader 一律拒绝；分配须伴随本表更新与 compress 模块 seam 立项 |

压缩不进 v1 是有意决策：Tauri brotli 方案读时需分配解压缓冲、破坏零拷贝；
HTTP 场景的 gzip/brotli 属内容编码，归 http.static 职责。槽位保证未来可平滑引入
（如 zstd 字典模式）而不动布局。

## String Table

- 内容：全部路径的 UTF-8 编码按 index 顺序拼接，无分隔符、无 NUL、无对齐要求
- 边界完全由 `(pathOffset, pathLen)` 描述
- v1 不做路径去重共享（每条目独占一段）；未来如需可加 flag 引入字典段

## Data Section 与内容去重

- 从 string table 结束后的下一个 **16 字节对齐**边界开始
- 每个内容槽位起始于 16 字节对齐边界；槽位间由 writer 填零填充
- 空文件（size=0）合法：仍分配对齐槽位（dataOffset 指向对齐边界），简化 reader 断言
- **内容去重**（writer 可选开关，默认关）：开启后，写入前以 fnv32 为候选键查已写内容，
  候选命中必须**逐字节回验相等**才允许复用槽位——杜绝哈希碰撞错误共享（策略同 asar）。
  共享槽位的多个条目各自持有完整 index 记录；对齐只需满足一次

### 内存上限声明

writer v1 采用内存内构造：输入总量（内容字节 + 路径表）建议 ≤ 512 MB。
超限场景（超大 dist/依赖树）的流式两遍构造属后续 slice，由 S4 基准数据触发立项，
不在 v1 内假装支持。

## Digest 区（可选，企业完整性档）

header flags bit1 置位时存在：`entryCount × 32` 字节数组，与 index 同序，第 i 项是
第 i 个条目**原始内容**的摘要。

- **摘要算法不由格式固定**：区内存的是不透明 32 字节。生产经 writer 注入的摘要函数
  （典型 SHA-256），校验助手位于消费侧 hash/crypto 模块——respack 保持零加密依赖
  （依赖倒置，对标 asar 的 integrity 但解耦算法）
- 推荐算法 SHA-256；分块哈希（asar blockSize/blocks 对等物）推迟至有部分校验真实需求
- 用途：供应链完整性核验、发布物审计；ETag 场景继续用条目 fnv32（更廉价）

## 路径规范（canonical path grammar）

**全盘采纳 Go `io/fs.ValidPath` 语义**（两模块共享；vfs 层引用同一节）：

- UTF-8 编码；分隔符恒为 `'/'`
- unrooted：不允许前导 `/`、尾随 `/`
- 任一路径段不得为空串、`.`、`..`
- 特例：整串 `.` 表示根目录（仅用于列根/Stat 根；文件查找中非法）
- 反斜杠 `\` 在任何平台上都只是普通字符，永远不是分隔符
- 大小写敏感；唯一性以精确字节相等判定
- 目录不产生条目——由文件路径隐含（`a/b.js` 隐含目录 `a` 与根）
- 最大路径长度受 `pathLen` u16 限制（65535 字节），实际建议 ≤ 1024

示例：`assets/app.js`、`index.html`、`vendor/vue/dist/vue.esm.js`。

## Reader 校验清单（按序执行，任一失败即拒绝整包）

1. 缓冲长度 ≥ 40；magic 匹配
2. `version = 1`；header `flags` 未知位全 0；bit1 置位时 `digestOffset ≠ 0`
3. `indexOffset ≥ 40` 且 `indexOffset + entryCount×40 ≤ blobTotal`
4. 缓冲实际长度 ≥ `blobTotal`（允许多余尾部字节，供追加场景）
5. digest 存在时：`digestOffset ≥ dataEnd` 且 `digestOffset + entryCount×32 ≤ blobTotal`
6. 每个 entry：`reserved` 全零、`codecId` 在登记表内、entry flags 未知位 0、
   `pathLen > 0`、`pathOffset + pathLen ≤ stringTableSize`、
   `dataOffset % 16 = 0`、`dataOffset + size ≤ blobTotal`
7. index 有序且无重复路径（校验即免费得到二分前提）
8. 路径逐段符合 canonical grammar（严格模式；宽松模式仅去前导 `/` 后重校验）

校验全部通过后才对外暴露任何查找结果；不存在"半信任"状态。

## Writer 构造流程

1. 收集条目列表 `(path, contentSource, modTime, wantHash, wantDigest)`
2. 规范化并校验路径；重复路径报 `EResPackDuplicatePath`
3. 按 path 字节序排序
4. 布局计算：string table → 16 对齐 → 依次分配内容槽位（去重开启时先候选匹配）
5. 写 header/index/string table/data；需要时补零填充；可选写 digest 区
6. 回填 `blobTotal`/`digestOffset`；汇总 flags 位

输入来源与 writer 解耦：纯内存条目即可构造；目录扫描是 `dirsource` 的职责；
include/exclude/prefix 过滤归工具层（对标 rust-embed derive 属性与 asar unpack-dir）。

## 完整小例

两文件 pack：`assets/app.js`（25 B）、`index.html`（389 B），均带 fnv hash 与
SHA-256 digest，modTime 已知。字节序比较 `'a' < 'i'`，故 app.js 在前。

| 区域 | 偏移 | 大小 | 说明 |
|------|------|------|------|
| header | 0x000 | 40 | entryCount=2, flags=0b11, digestOffset=0x238, blobTotal=0x278 (632) |
| index | 0x028 | 80 | 2 × 40 B，app.js 先 |
| string table | 0x078 | 24 | `"assets/app.js"`(13) + `"index.html"`(11) |
| padding | 0x090 | 0 | 已 16 对齐 |
| data: app.js | 0x090 | 25 | 结束于 0x0A9 |
| padding | 0x0A9 | 7 | 补到 16 对齐 |
| data: index.html | 0x0B0 | 389 | 结束于 0x235 |
| padding | 0x235 | 3 | 补到 4 对齐（digest 区自然对齐即可） |
| digest 区 | 0x238 | 64 | 2 × 32 B SHA-256 |
| 结束 | 0x278 | — | = blobTotal ✓ |

## 版本化与扩展策略

- 加字段：优先用 `reserved`、flag 位与登记表机制；reader 拒绝未知置位保证不会静默
  误解新格式
- **预留位登记**：header flags **bit2 = hash-index 区**（未来 O(1) 路径查找索引，
  对标 Tauri phf 完美哈希的扩展槽）。v1 reader 见 bit2 置位即拒绝；启用须伴随本表
  更新与版本评审，不动既有布局
- 改布局/语义：`version` 递增；reader 只接受自己认识的版本集合 `{1}`
- 新压缩编解码：走 `codecId` 登记表 + compress 模块 seam，独立立项
