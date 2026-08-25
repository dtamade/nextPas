# nextpas.core.vfs

L2 只读虚拟文件树模块。把"一棵文件树"抽象成统一接口：真实磁盘（`nextpas.core.fs`）、
respack 嵌入包、纯内存树都是它的后端。consumer 只认 `IVfs`，不关心内容来自二进制
内嵌数据还是文件系统。

**状态：设计阶段（S0）。本模块尚未实现；本目录即权威设计文档。**
实现进度见 [`docs/plans/2026-08-25-respack-vfs-modules-plan.md`](../../../docs/plans/2026-08-25-respack-vfs-modules-plan.md)。
对标依据见 [`core/docs/respack/PARITY-go-rust.md`](../respack/PARITY-go-rust.md)。

## 动机与对标

Tauri 把前端资源编译期嵌进可执行文件，运行时经内存映射直接服务请求——没有解压落盘。
本模块 + `nextpas.core.respack` 提供 nextPas 生态的等价物：

```
构建期:  frontend/dist/* ──respack writer──▶ blob ──.inc 生成器──▶ typed const 编入程序
运行期:  blob ──vfs.embedded──▶ IVfs ──▶ http.static / config / TUI 资产
```

语义基线取自 **Go `io/fs`**（业界事实标准）：路径语法、结构化错误、重定根视图、
实现一致性测试四件全部对齐；偏离处（接口最小化策略）在决策记录中说明理由。

## 模块定位与分层

- **拥有**：只读文件树的接口契约、错误语义、路径语义；后端实现与 Sub 视图。
- **不拥有**：流词汇表（归 `nextpas.core.io`）、真实 FS 操作（归 `nextpas.core.fs`）、
  pack 字节格式（归 `nextpas.core.respack`）、MIME 推断（归 http.static，
  对标 rust-embed 与 mime_guess 分离）。

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

// 重定根视图（Go fs.Sub 对等物）
var Web := CreateSubVfs(Fs, 'wwwroot');

// 全树确定性遍历（Go fs.WalkDir 对等物）
VfsWalk(Fs, '',
  procedure(const APath: string; const AInfo: TEntryInfo; var AStop: Boolean)
  begin
    Log(APath);
  end);

// 后端装配视角
FsEmbedded := CreateEmbeddedVfs(ResPackOpen(@Blob[0], Length(Blob)));  // 嵌入包
FsDisk     := CreateOsVfs('/srv/app');                                 // 真实目录
FsMem      := CreateMemTreeVfs(Tree);                                  // 测试替身
```

## 架构

```
nextpas.core.vfs.pas            ← 门面：re-export + 便利函数（ReadAll/Walk/Stat/List）inline 转发
nextpas.core.vfs.base.pas       ← TEntryInfo/TStatInfo record、规范路径工具、常量
nextpas.core.vfs.intf.pas       ← IVfs 接口契约
nextpas.core.vfs.errors.pas     ← EVfsError(含 Op/Path) 及子类
nextpas.core.vfs.memtree.pas    ← 内存不可变树（embedded 底座 + 测试替身）+ Builder
nextpas.core.vfs.embedded.pas   ← respack blob → IVfs，零拷贝切片
nextpas.core.vfs.os.pas         ← nextpas.core.fs → IVfs 适配（类型转换在此收口）
nextpas.core.vfs.sub.pas        ← CreateSubVfs：任意 IVfs 的重定根包装
nextpas.core.vfs.mount.pas      ← （推迟）挂载表/overlay
```

依赖方向：`base/errors ← intf ← memtree/embedded/os/sub ← 门面`；
`embedded` 额外依赖 `respack.reader`；`os` 额外依赖 `nextpas.core.fs`。

### 依赖白名单

| 单元 | 允许依赖 | 说明 |
|------|----------|------|
| `base` | L0 | 自有 `TEntryInfo/TStatInfo`，**不复用 `fs.base` 类型** |
| `intf` | `base` + `io.intf`（IStream） | 流词汇唯一来源是 io |
| `memtree`/`embedded`/`sub` | `intf/base`（`embedded` 另加 `respack.reader`） | |
| `os` | `intf/base` + `nextpas.core.fs` + `nextpas.core.path` | **唯一的 L2→L2 seam**，registry 记录 |

## 核心契约

```pascal
IVfs = interface
  ['{...}']
  function Exists(const APath: string): Boolean;
  function Stat(const APath: string): TStatInfo;
  function List(const ADirPath: string): TEntryArray;
  function OpenRead(const APath: string): IStream;
  { 后端大小写敏感性内省：供上层折叠/匹配策略决策（memtree=True，os 按平台） }
  function CaseSensitive: Boolean;
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

### 错误语义（对齐 Go PathError）

所有异常携带**操作与路径上下文**（Go `PathError{Op,Path,Err}` 对等物），边界一次捕获
即可拿到完整定位信息：

```pascal
EVfsError = class(Exception)
public
  property Op: string;     // 'stat' / 'open' / 'list' / 'read'
  property Path: string;   // 出错时的虚拟路径
end;
// 子类：EVfsNotFound（≈ErrNotExist）、EVfsIsADirectory、EVfsNotADirectory、
//       EVfsInvalidPath（≈ErrInvalid）、EVfsClosed（≈ErrClosed）
```
| 场景 | 行为 |
|------|------|
| `Stat`/`OpenRead` 路径不存在 | raise `EVfsNotFound`，`Op='stat'/'open'` |
| `List` 目标不是目录 | raise `EVfsNotADirectory`，`Op='list'` |
| 对目录调用 `OpenRead` | raise `EVfsIsADirectory`，`Op='open'` |
| 对文件调用 `List` | raise `EVfsNotADirectory`，`Op='list'` |
| `Exists` 任何失败 | 返回 False，不 raise |
| 路径无法通过 ValidPath 校验 | 统一 raise `EVfsInvalidPath`，不做猜测性修正 |

### 路径语义（全盘采纳 Go `io/fs.ValidPath`）

- UTF-8 编码；分隔符恒为 `'/'`；unrooted：无前导 `/`、无尾随 `/`
- 任一路径段不得为空串、`.`、`..`
- 特例：整串 `.` 表示根目录（`List('.')` 列根、`Stat('.')` 返回根目录信息）
- 反斜杠 `\` 在任何平台上都只是普通字符，永远不是分隔符
- 大小写敏感性由后端声明：embedded/memtree 恒敏感；os 后端跟随平台
- `os` 后端在边界做虚拟路径 ↔ 平台路径双向转换（经 `nextpas.core.path`）

### 并发与不可变契约

- `IVfs` 实例发布后视为**不可变快照**；并发只读安全，无需外部锁
- 构造期可变性收敛在 `TVfsTreeBuilder`（memtree 侧），Freeze 后产出不可变树
- embedded 后端的不可变性来自 pack 本身只读

## 零拷贝与生命周期（embedded 后端）

- `OpenRead` 返回的 `IStream` 直接读 blob 切片区间，不做内容复制
  （对标 Go embed.FS 文件直指静态数据、Tauri `Cow::Borrowed` 切片）
- 接口对象内部持有后备存储引用保活：
  - 来源为堆缓冲/TBytes → 引用计数自然保活
  - 来源为 const 数据/静态段 → 无引用计数，**文档化规则：调用方保证 blob 生命期覆盖
    IVfs 及其派生的全部 IStream**；构造函数提供 `AOwnsBlob: Boolean` 覆盖堆场景
- conformance 门含地址断言：读取缓冲指针必须落在 `[blob, blob+blobTotal)` 区间内，
  锁死零拷贝不被回归破坏

## 后端矩阵

| 后端 | 单元 | 内容来源 | hash | 典型用途 |
|------|------|----------|------|----------|
| memtree | `vfs.memtree` | 进程内构造 | 可选 | 单测替身、运行时动态资产 |
| embedded | `vfs.embedded` | respack blob（const 数组/堆/mmap） | 来自 pack | 打包进程序的前端资源 |
| os | `vfs.os` | 真实目录（经 `core.fs`） | 不提供（0） | 开发模式、磁盘部署 |

同一 consumer 在开发态接 `os`、发布态接 `embedded`，行为一致——这正是引入抽象的理由。

### 开发态工作流（对标 rust-embed debug 行为）

rust-embed 在 debug 构建默认直接读磁盘（免"改一行重编全部资源"）；我们的同构方案：
开发期工厂返回 `CreateOsVfs('frontend/dist')`，发布期工厂返回 embedded 实例。
切换是装配层一个工厂函数的事，consumer 代码零改动。该双态切换本身列入 conformance
测试（同一用例集跑两后端必须同结果）。

## 一致性测试（fstest.TestFS 对等物）

新增 `test_vfs_conformance` 门：属性电池以 **Go `testing/fstest` 的 TestFS 清单**为蓝本，
跑满 `{memtree, embedded, os}` × `{整树, Sub 视图}` 矩阵：

| # | 属性（来源 fstest.go） |
|---|------------------------|
| P1 | 根可打开可列（`List('.')`），且从根遍历枚举结果 == 期望文件集（checkDir 递归走全树） |
| P2 | 每个列出的子名合法：非空、非 `.`/`..`、不含 `/` 与 `\` |
| P3 | `Stat(path)` 与父目录 List 条目一致（size/IsDir/modTime 三方一致） |
| P4 | 期望存在的文件 Open 可读且逐字节相等；不存在的路径行为符合错误表 |
| P5 | 非法路径（`''`、`'/x'`、`'a//b'`、`'a/../b'`、`'a/./b'`、`'a/'`）统一 `EVfsInvalidPath` |
| P6 | 目录上 OpenRead、文件上 List 报对应错误类 |
| P7 | `Sub('dir')` 视图内以新根重复 P1–P6（fstest 强制测 fs.Sub 往返） |
| P8 | embedded 后端附加：读取缓冲地址落在 blob 区间内（零拷贝断言） |

## 设计决策记录

| 决策 | 理由 |
|------|------|
| v1 只读契约 | 匹配资源嵌入主场景；写入走 fs；避免空实现污染接口 |
| IVfs 四读操作 + CaseSensitive 内省，而非 Go 式最小核+能力接口 | **有意偏离并记录**：三个后端全能高效实现 Exists/Stat/List/OpenRead 四个读操作，CaseSensitive 是后端固有属性的内省（供大小写折叠策略决策），无需运行期能力探测；批量操作保持门面函数。若出现只能部分实现的第 4 后端再引入能力拆分 |
| 自有 `TEntryInfo` 不复用 `fs.base` | 守住 "L2 仅依赖 L0-L1"；嵌入域字段需求远小于 fs；转换成本收口在 os 后端一个单元 |
| `IStream` 复用 io 词汇 | 流词汇 owner 是 io，不自造第二套 |
| 错误带 Op/Path 上下文 | Go PathError 是企业级错误定位的事实标准 |
| 路径语法采纳 Go ValidPath 含 `.` 根 | 业界事实标准；respack/vfs 两模块共享同一节定义 |
| Sub 视图独立单元而非核心方法 | Go 将 fs.Sub 作为自由函数；包装器不改核心契约即可测试（fstest 同样强制测它） |
| mount/overlay 推迟 | 无已落地的双源消费场景；接口留位不留桩 |

## 测试计划

```bash
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_memtree
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_embedded
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_os
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_conformance   # 属性电池 × 后端矩阵
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_facade        # 便利函数 + 双态切换
make focused FOCUS=core/tests/nextpas.core.vfs/test_vfs_source_contracts
```

- 各后端单元门覆盖自身实现细节；conformance 门锁跨后端语义一致
- `test_vfs_source_contracts`：源码契约检查，锁定依赖白名单（`vfs.*` 中除 `os` 外禁止
  出现对 `fs`/`respack` 的 uses；全模块禁止 OS 单元），照 system 模块 source-contract 先例
- 全部 gate 要求 heaptrc 零泄漏

## Consumer 展望（跨模块 slice，另行立项）

- `http.static` 增加 IVfs 内容源后端（S5）：ETag 直接取 `ContentHash`，
  If-Modified-Since 取 `ModTime`；属跨模块改动，按 AGENTS.md 单独说明理由与验证
- config/TUI 资产加载后续跟进

## FPC RTL 隔离与反哺

项目规范：`nextpas.core.*` 不直接依赖 FPC RTL；缺口通过反哺 nextpas.core 解决。

### 本模块 uses 白名单（source-contract 锁定）

| 允许 | 禁止 |
|------|------|
| `nextpas.core.settings.inc` | `SysUtils`、`Classes` |
| `nextpas.core.base` / `io.intf` | `Windows`、`BaseUnix`、`Unix` 及一切 OS 单元 |
| `nextpas.core.exception` / `errors`（异常根桥接） | 任何其他 FPC RTL 单元 |
| `os` 后端另加 `fs`/`path`；`embedded` 另加 `respack.reader` | |

- `EVfsError` 继承 `nextpas.core.exception.Exception`——异常词汇的桥接点收敛在
  exception 根模块（FPC 下桥接、nextPas 下原生实现）；仓库对 FPC RTL 直引的整体豁免面
  见 fs CONTRACT INV-7（仅 system 根门面等治理特例），本模块不在豁免面内，
  本模块只认 exception 根
- 流词汇只用 `nextpas.core.io.intf.IStream`，绝不引 FPC `Classes.TStream`
- source-contract 测试逐单元断言 uses 清单，违例即红。**复用既有门禁机制**
  `core/tests/fpc_rtl_uses_scan.inc`（test_fs 已在用），不自造扫描器

### 反哺触发点（当前已知）

| 缺口 | 反哺去向 | 状态 |
|------|----------|------|
| 大 pack 低驻留读取需要文件映射 | platform/mem（文件映射 owner） | v1 不做 mmap；有需求时反哺立项，不在本模块私调 OS API |
| 目录监视（开发态热刷新资产） | fs.watch（已有 owner） | 直接消费，不重复实现 |
| 原生 Exception 基类 | nextpas.core.exception 已承接 | 无新增缺口 |

## 可抽取存量盘点（2026-08-25 实查）

- compiler/tools 中不存在虚拟 FS、内存树或打包读取的存量代码可抽取——本模块是绿地
- "项目代码抽进 core"纪律对本设计的要求：S4 打包工具与 `.inc` 生成器的全部格式逻辑
  必须落在 `respack.writer`（core 侧），CLI 只是薄壳——工具逻辑进 core、壳留项目侧，
  正向示范该规则

## 关联文档

- [CONTRACT.md](CONTRACT.md) — 代码契约：不变量、错误表、线程安全、性能契约
- [`core/docs/respack/README.md`](../respack/README.md) — 格式层模块
- [`core/docs/respack/FORMAT.md`](../respack/FORMAT.md) — 线格式权威定义
- [`core/docs/respack/PARITY-go-rust.md`](../respack/PARITY-go-rust.md) — Go/Rust 对标矩阵与来源清单
- [`docs/plans/2026-08-25-respack-vfs-modules-plan.md`](../../../docs/plans/2026-08-25-respack-vfs-modules-plan.md) — 实施计划
