# nextpas.core.vfs

L2 只读虚拟文件树模块。把"一棵文件树"抽象成统一接口：真实磁盘（`nextpas.core.fs`）、
respack 嵌入包、纯内存树都是它的后端。consumer 只认 `IVfs`，不关心内容来自二进制
内嵌数据还是文件系统。

**状态：设计阶段（S0）。本模块尚未实现；本目录即权威设计文档。**
实现进度见 [`docs/plans/2026-08-25-respack-vfs-modules-plan.md`](../../docs/plans/2026-08-25-respack-vfs-modules-plan.md)。

## 动机与对标

Tauri 把前端资源编译期嵌进可执行文件，运行时经内存映射直接服务请求——没有解压落盘。
本模块 + `nextpas.core.respack` 提供 nextPas 生态的等价物：

```
构建期:  frontend/dist/* ──respack writer──▶ blob ──.inc 生成器──▶ typed const 编入程序
运行期:  blob ──vfs.embedded──▶ IVfs ──▶ http.static / config / TUI 资产
```

## 模块定位与分层

- **拥有**：只读文件树的接口契约、错误语义、路径语义；三个后端实现。
- **不拥有**：流词汇表（归 `nextpas.core.io`）、真实 FS 操作（归 `nextpas.core.fs`）、
  pack 字节格式（归 `nextpas.core.respack`）。

**v1 契约刻意只读。** Tauri 资产同样只读；写入本来就该走 `core.fs`。把 Write/Delete/Rename
塞进 `IVfs` 只会让 embedded 后端全是"不支持"。可写 overlay 属于将来 `vfs.mount` 议题。

## 目标使用形态（未实现，设计签名）

```pascal
uses nextpas.core.vfs;

// consumer 视角 —— 不关心后端
var Fs := GetAppAssets;                 // 返回 IVfs（embedded 或 os）
if Fs.Exists('index.html') then
  Serve(Fs.OpenRead('index.html'));    // IStream，零拷贝视图

// 便利函数（门面层，基于 OpenRead 组合）
Bytes := VfsReadAllBytes(Fs, 'assets/app.js');

// 后端装配视角
FsEmbedded := CreateEmbeddedVfs(ResPackOpen(@Blob[0], Length(Blob)));  // 嵌入包
FsDisk     := CreateOsVfs('/srv/app');                                 // 真实目录
FsMem      := CreateMemTreeVfs(Tree);                                  // 测试替身
```

## 架构

```
nextpas.core.vfs.pas            ← 门面：re-export + 便利函数 inline 转发
nextpas.core.vfs.base.pas       ← TEntryInfo/TStatInfo record、规范路径工具、常量
nextpas.core.vfs.intf.pas       ← IVfs 接口契约
nextpas.core.vfs.errors.pas     ← EVfsNotFound/EVfsNotADirectory/EVfsError
nextpas.core.vfs.memtree.pas    ← 内存不可变树（embedded 底座 + 测试替身）+ Builder
nextpas.core.vfs.embedded.pas   ← respack blob → IVfs，零拷贝切片
nextpas.core.vfs.os.pas         ← nextpas.core.fs → IVfs 适配（类型转换在此收口）
nextpas.core.vfs.mount.pas      ← （推迟）挂载表/overlay
```

依赖方向：`base/errors ← intf ← memtree/embedded/os ← 门面`；
`embedded` 额外依赖 `respack.reader`；`os` 额外依赖 `nextpas.core.fs`。

### 依赖白名单

| 单元 | 允许依赖 | 说明 |
|------|----------|------|
| `base` | L0 | 自有 `TEntryInfo/TStatInfo`，**不复用 `fs.base` 类型** |
| `intf` | `base` + `io.intf`（IStream） | 流词汇唯一来源是 io |
| `memtree`/`embedded` | `intf/base`（+`respack.reader`） | |
| `os` | `intf/base` + `nextpas.core.fs` + `nextpas.core.path` | **唯一的 L2→L2 seam**，registry 记录 |

## 核心契约

```pascal
IVfs = interface
  ['{...}']
  function Exists(const APath: string): Boolean;
  function Stat(const APath: string): TStatInfo;
  function List(const ADirPath: string): TEntryArray;
  function OpenRead(const APath: string): IStream;
end;

TEntryInfo = record
  Name: string;      // 规范虚拟路径
  Size: Int64;
  ModTime: Int64;    // Unix 秒；0 = 未知
  IsDir: Boolean;
end;

TStatInfo = record
  Info: TEntryInfo;
  ContentHash: UInt32;   // FNV-1a 32；0 = 后端未提供（os 后端默认不提供）
end;
```

### 错误语义

直线代码风格："无值"用异常表达，探测用 `Exists`：

| 场景 | 行为 |
|------|------|
| `Stat`/`OpenRead` 路径不存在 | raise `EVfsNotFound` |
| `List` 目标不是目录 | raise `EVfsNotADirectory` |
| 对文件调用 `List`、对目录调用 `OpenRead` | raise `EVfsError` 子类 |
| `Exists` 任何失败 | 返回 False，不 raise |
| 路径不规范（`..`、前导 `/` 等） | 统一先规范化再解释；无法规范化即 `EVfsError` |

所有异常继承 `EVfsError`（挂在 `nextpas.core.exception` 根上），边界处一次捕获即可。

### 路径语义

- 树内一律使用 respack 同款规范路径（UTF-8、`'/'` 分隔、无前导 `/`、无 `.`/`..`）——
  两模块共享同一语法定义，定义文本以 `respack/FORMAT.md` 为准
- `os` 后端在边界做双向转换：虚拟路径 → 平台路径（经 `nextpas.core.path`），平台路径 → 虚拟路径
- 大小写敏感性由后端声明：embedded/memtree 恒敏感；os 后端跟随平台

### 并发与不可变契约

- `IVfs` 实例发布后视为**不可变快照**；并发只读安全，无需外部锁
- 构造期可变性收敛在 `TVfsTreeBuilder`（memtree 侧），Freeze 后产出不可变树
- embedded 后端的不可变性来自 pack 本身只读

## 零拷贝与生命周期（embedded 后端）

- `OpenRead` 返回的 `IStream` 直接读 blob 切片区间，不做内容复制
- 接口对象内部持有后备存储引用保活：
  - 来源为堆缓冲/TBytes → 引用计数自然保活
  - 来源为 const 数据/静态段 → 无引用计数，**文档化规则：调用方保证 blob 生命期覆盖
    IVfs 及其派生的全部 IStream**；构造函数提供 `AOwnsBlob: Boolean` 覆盖堆场景
- focused gate 含地址断言：读取缓冲指针必须落在 `[blob, blob+blobTotal)` 区间内，
  锁死零拷贝不被回归破坏

## 后端矩阵

| 后端 | 单元 | 内容来源 | hash | 典型用途 |
|------|------|----------|------|----------|
| memtree | `vfs.memtree` | 进程内构造 | 可选 | 单测替身、运行时动态资产 |
| embedded | `vfs.embedded` | respack blob（const 数组/堆/mmap） | 来自 pack | 打包进程序的前端资源 |
| os | `vfs.os` | 真实目录（经 `core.fs`） | 不提供（0） | 开发模式、磁盘部署 |

同一 consumer 在开发态接 `os`、发布态接 `embedded`，行为一致——这正是引入抽象的理由。

## 设计决策记录

| 决策 | 理由 |
|------|------|
| v1 只读契约 | 匹配资源嵌入主场景；写入走 fs；避免空实现污染接口 |
| 自有 `TEntryInfo` 不复用 `fs.base` | 守住 "L2 仅依赖 L0-L1"；嵌入域字段需求远小于 fs；转换成本收口在 os 后端一个单元 |
| `IStream` 复用 io 词汇 | 流词汇 owner 是 io，不自造第二套 |
| 目录条目从路径推导 | 与 respack 格式一致，List 为按需推导而非存储遍历 |
| mount/overlay 推迟 | 无已落地的双源消费场景；接口留位不留桩 |

## 测试计划

```bash
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_memtree
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_embedded   # 含零拷贝地址断言、生命期
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_os
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_facade     # 便利函数 + 三后端同测集
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_source_contracts
```

- **三后端一致性测试集**：同一组用例（存在性/错误语义/List 排序/大文件切片）跑三个后端，
  防后端漂移
- `test_vfs_source_contracts`：源码契约检查，锁定依赖白名单（`vfs.*` 中除 `os` 外禁止
  出现对 `fs`/`respack` 的 uses；全模块禁止 OS 单元），照 system 模块 source-contract 先例
- 全部 gate 要求 heaptrc 零泄漏

## Consumer 展望（跨模块 slice，另行立项）

- `http.static` 增加 IVfs 内容源后端（S5）：ETag 直接取 `ContentHash`，
  If-Modified-Since 取 `ModTime`；属跨模块改动，按 AGENTS.md 单独说明理由与验证
- config/TUI 资产加载后续跟进

## 关联文档

- [`core/docs/respack/README.md`](../respack/README.md) — 格式层模块
- [`core/docs/respack/FORMAT.md`](../respack/FORMAT.md) — 线格式权威定义（含路径语法）
- [`docs/plans/2026-08-25-respack-vfs-modules-plan.md`](../../docs/plans/2026-08-25-respack-vfs-modules-plan.md) — 实施计划
