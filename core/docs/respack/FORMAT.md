# respack 线格式 v1

本文是 respack 二进制格式的**权威定义**。实现（reader/writer）与工具必须以本文为准；
改格式先改本文并升版本。

- 版本：`1`
- 字节序：固定 little-endian；大端平台由 reader 显式换序（`platform.endian` inquiry 判定）
- 所有 offset 均为相对 blob 起点的绝对偏移
- 所有保留字段必须写 0，reader 必须拒绝非 0 保留值（防误扩展）

## 总布局

```
偏移 0x00      ┌──────────────────────────┐
               │ header (32 B)            │
偏移 0x20      ├──────────────────────────┤
               │ index (entryCount × 40B) │  按 path 字节序升序
               ├──────────────────────────┤
               │ string table             │  全部路径 UTF-8 拼接，无 NUL
               ├──────────────────────────┤  （16 字节对齐处开始）
               │ data blobs               │  每条目内容，各起始于 16 字节对齐边界
blobTotal      └──────────────────────────┘
```

顺序固定：header → index → string table → data。reader 可按此顺序做递进式越界校验。

## Header（32 字节）

| 偏移 | 大小 | 字段 | 类型 | 含义 |
|------|------|------|------|------|
| 0x00 | 4 | `magic` | bytes | `'N' 'P' 'R' 'S'` |
| 0x04 | 4 | `version` | u32 LE | 必须 = 1 |
| 0x08 | 4 | `flags` | u32 LE | bit0 = 全部条目 hash 有效；其余必须为 0 |
| 0x0C | 4 | `entryCount` | u32 LE | 条目数 |
| 0x10 | 8 | `indexOffset` | u64 LE | index 起始偏移（v1 恒为 32） |
| 0x18 | 8 | `blobTotal` | u64 LE | 整个 pack 总字节数 |

## Index Entry（40 字节 × entryCount）

| 偏移 | 大小 | 字段 | 类型 | 含义 |
|------|------|------|------|------|
| +0x00 | 4 | `pathOffset` | u32 LE | 路径在 string table 内的偏移 |
| +0x04 | 2 | `pathLen` | u16 LE | 路径 UTF-8 字节长度（无 NUL） |
| +0x06 | 2 | `flags` | u16 LE | bit0 = 本条目 hash 有效；其余必须为 0 |
| +0x08 | 8 | `dataOffset` | u64 LE | 内容起始绝对偏移 |
| +0x10 | 8 | `size` | u64 LE | 内容字节数 |
| +0x18 | 8 | `modTime` | i64 LE | Unix 秒；0 = 未知 |
| +0x20 | 4 | `hash` | u32 LE | FNV-1a 32（内容字节流；仅 bit0 置位时有效） |
| +0x24 | 4 | `reserved` | u32 LE | 必须 = 0 |

index 数组按 `path` 的**字节序升序**排列（UTF-8 字节直接比较，不做语言敏感排序），
支持二分查找。数组逻辑终点：`indexOffset + entryCount × 40`。

## String Table

- 内容：全部路径的 UTF-8 编码按 index 顺序拼接，无分隔符、无 NUL、无对齐要求
- 边界完全由 `(pathOffset, pathLen)` 描述
- v1 不做路径去重共享（每条目独占一段）；未来如需可加 flag 引入字典段

## Data Section

- 从 string table 结束后的下一个 **16 字节对齐**边界开始
- 每个条目内容起始于 16 字节对齐边界；条目间由 writer 填零填充
- 条目内容连续存放，不允许空洞交叉引用
- 对齐目的：切片可直接用于 SIMD 扫描/未来 mmap 映射，不因头部错位降速

空文件（size=0）合法：仍分配对齐槽位（dataOffset 指向对齐边界），简化 reader 断言。

## 路径规范（canonical path grammar）

写入与查找一律使用规范形式；writer 负责规范化，reader 校验后接受：

- UTF-8；分隔符恒为 `'/'`
- 不允许前导 `/`、尾随 `/`、空段（`//`）、`.`、`..` 段
- 大小写敏感；唯一性以精确字节相等判定
- 目录不产生条目——由文件路径隐含（`a/b.js` 隐含目录 `a` 与根）
- 最大路径长度受 `pathLen` u16 限制（65535 字节），实际建议 ≤ 1024

示例：`assets/app.js`、`index.html`、`vendor/vue/dist/vue.esm.js`。

## Reader 校验清单（按序执行，任一失败即拒绝整包）

1. 缓冲长度 ≥ 32；magic 匹配
2. `version = 1`；header `flags` 未知位全 0
3. `indexOffset ≥ 32` 且 `indexOffset + entryCount×40 ≤ blobTotal`
4. 缓冲实际长度 ≥ `blobTotal`（允许多余尾部字节，供追加场景）
5. 每个 entry：`reserved = 0`、entry flags 未知位 0、
   `pathLen > 0`、`pathOffset + pathLen ≤ stringTableSize`、
   `dataOffset % 16 = 0`、`dataOffset + size ≤ blobTotal`
6. index 有序且无重复路径（校验即免费得到二分前提）
7. 路径逐段符合 canonical grammar（严格模式可开；宽松模式仅去前导 `/` 后重校验）

校验全部通过后才对外暴露任何查找结果；不存在"半信任"状态。

## Writer 构造流程

1. 收集条目列表 `(path, contentSource, modTime, wantHash)`
2. 规范化并校验路径；重复路径报 `EResPackDuplicatePath`
3. 按 path 字节序排序
4. 布局计算：string table → 对齐 → 依次分配 data 槽位（各 16 对齐）
5. 写 header/index/string table/data；需要时补零填充
6. 回填 `blobTotal`；flags 汇总条目 hash 有效性

输入来源与 writer 解耦：纯内存条目即可构造；目录扫描是 `dirsource` 的职责。

## 完整小例

两文件 pack：`assets/app.js`（25 B）、`index.html`（389 B），均带 hash，
modTime 已知。字节序比较 `'a' < 'i'`，故 app.js 在前。

| 区域 | 偏移 | 大小 | 说明 |
|------|------|------|------|
| header | 0x000 | 32 | entryCount=2, blobTotal=0x235 (565) |
| index | 0x020 | 80 | 2 × 40 B，app.js 先 |
| string table | 0x070 | 24 | `"assets/app.js"`(13) + `"index.html"`(11) |
| padding | 0x088 | 8 | 补到 16 对齐 |
| data: app.js | 0x090 | 25 | 结束于 0x0A9 |
| padding | 0x0A9 | 7 | 补到 16 对齐 |
| data: index.html | 0x0B0 | 389 | 结束于 0x235 = blobTotal ✓ |

## 版本化与扩展策略

- 加字段：优先用 `reserved` 与 flag 位；reader 拒绝未知置位保证不会静默误解新格式
- 改布局/语义：`version` 递增；reader 只接受自己认识的版本集合 `{1}`
- 新压缩编解码：将来在 entry flags 中引入 codec 位段 + 头部字典段，属 v2 议题，
  v1 一律原样存储
