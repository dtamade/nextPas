# nextpas.core.git

`nextpas.core.git` 是 `nextpas.core` 的 L2 Git 集成模块。提供双轨后端（`libgit2` 运行时加载 + `native` 纯 Pascal）与 `factory` 唯一汇聚点，为 `IGitManager / IGitRepository / IGitCommit` 提供统一门面，已覆盖对象层 / refs / index / status / revwalk / 传输基座等 68 个源文件。

- 层级：L2，依赖 L0（`base` / `text` / `fs`）；`native` 子家族另用 L1 `compress` / `hash` / `io` owner 能力（mmap、Deflate、SHA-1 等），不自建重复实现。
- 门面：`nextpas.core.git`（纯 re-export + `inline NewGitManager → factory.NewGitManager(gbAuto)`，存量零改动）。
- 选择层：`nextpas.core.git.factory`（`TGitBackend = (gbNative, gbLibGit2, gbAuto)`，首版 `gbAuto = gbLibGit2`）。
- 纯路径：`native.manager` → `native.*` 零 `libgit2`（`scripts/git-contract-check.sh` C4 双重闭环：`grep` + `fpc -va Loading libgit2`）。
- 文档真源：契约见 [CONTRACT.md](CONTRACT.md)；纯后端隔离见 [PURE-BACKEND.md](PURE-BACKEND.md)。

## 文档地图

| 文档 | 职责 |
|------|------|
| [README.md](README.md) | 本文件：统一门面与高级感入口 |
| [CONTRACT.md](CONTRACT.md) | 代码契约（68 源文件清单、接口/不变量/线程安全/内存/测试门禁） |
| [PURE-BACKEND.md](PURE-BACKEND.md) | 纯 Pascal 后端隔离契约（依赖图、选择矩阵、`gbAuto` 迁移、`uses` 隔离与门禁） |
| [native-reference-map.md](native-reference-map.md) | `native.*` ↔ `~/projects/libgit2` 只读对照（格式/算法/边界清单，不进源码树） |
| [bindings-pitfalls.md](bindings-pitfalls.md) | `libgit2.bindings` 再生成管线与 C 绑定坑清单（c2pas888 / shim / 黄金对照） |

> 外部入口：`docs/contracts/git.md` 与 `core/docs/git/CONTRACT.md` 互为镜像时，以本目录为准。

## 源文件布局

```
core/src/nextpas.core.git.pas                 ← 聚合门面（re-export base/intf + inline NewGitManager）
core/src/nextpas.core.git.base.pas            ← TGitStatusEntry / TGitStatusFilter 基础类型
core/src/nextpas.core.git.intf.pas            ← IGitManager / IGitRepository / IGitCommit 接口
core/src/nextpas.core.git.factory.pas         ← TGitBackend + NewGitManager（唯一跨轨汇聚点）
core/src/nextpas.core.git.libgit2.ffi.pas     ← libgit2 C FFI 类型层（回调 typedef 等）
core/src/nextpas.core.git.libgit2.binding.pas ← libgit2 运行时绑定（dlopen/dlsym）
core/src/nextpas.core.git.libgit2.backend.pas ← libgit2 后端实现
core/src/nextpas.core.git.libgit2.pas        ← libgit2 集成门面
core/src/nextpas.core.git.libgit2.bindings.pas← libgit2 全量静态声明（c2pas888 生成，external）
core/src/nextpas.core.git.native.pas          ← native 子家族门面 re-export
core/src/nextpas.core.git.native.base.pas     ← TGitOid / EGitError 等对象层基座
core/src/nextpas.core.git.native.{zlib,loose,pack,refs,objmodel,repo,write,index,cachetree,
  status,ignore,revwalk,commitgraph,reflog,stash,notes,branch,tag,log,describe,diff,blame,
  mergebase,show,shortlog,catfile,lsfiles,cherrypick,revert,archive,submodule,mailmap,
  trailer,attributes,bundle,grep,bisect,worktree,config,pktline,remote,advertise,negotiate,
  sideband,indexer,fetch,clone,checkout,push,reset,prune,clean,revparse,common,util}.pas
```

四件套范式：`base ← intf ← 实现 ← 门面`；依赖只向下，禁止同层循环。

## 核心不变量（见 CONTRACT.md §2-§5）

- **Ownership 单一所有者**：`TPackFile.FMapped: IMappedFile` 独占 `PByte+Size` 零拷贝视图，析构释放；`WriteAtomic` 临时句柄 `try..finally`。
- **Exactly-once 单次交付**：`revwalk`/`zlib`/`status-rename` 均恰一次 `ReadObject+Parse / inflate / 归并`，零重复开销。
- **单源复用**：`ignore/attributes` 委托 `wildmatch`（`GitWildSegment*`/`GitSegmentsMatch`，inline）；`Adler-32` 委托 `nextpas.core.checksum.adler32`（`ADLER32_INIT/MOD/NMAX` 单源，`PByte+Len` 零拷贝）；`Span/Bytes` 委托 `nextpas.core.bytes.ops`；`zlib` 委托 `nextpas.core.compress`（`CreateDeflateReaderEmbedded`）。禁止手写重复循环。
- **性能 inline/零拷贝**：`GitOidIsValidHex/GitOidSame/GitKindFromMode/GitZlibAdler32(PByte)` 等 `inline`；`GitZlibDecompressPtr/Adler32Update(PByte,Len)` 为 `Pointer+Len` 零拷贝，复用 `bytes.ops` 零分配路径。
- **稳定性**：`EIOError → EGitError` 映射保留 `EGitError` 原样 `raise`；`TPackFile/LoadPacks/Index` 异常 `try..finally` 重抛且不泄漏；`HEAPTRC=haltonnotreleased` 双 pin 零泄漏。

## 快速开始

```pascal
uses
  nextpas.core.git,            // 存量：默认 gbAuto (= gbLibGit2 首版)
  nextpas.core.git.factory;    // 显式选择

var
  Mgr: IGitManager;
  Repo: IGitRepository;
begin
  Mgr := NewGitManager; // 等价 factory.NewGitManager(gbAuto)
  Mgr.Initialize;
  if Mgr.IsRepository('/path/to/repo') then
    Repo := Mgr.OpenRepository('/path/to/repo');

  // 纯路径（零 libgit2）
  Mgr := factory.NewGitManager(gbNative);
end;
```

## 测试与门禁

```bash
make -C core/tests/nextpas.core.git/test_git_native clean test
make -C core/tests/nextpas.core.git/test_git clean test
make -C core/tests/nextpas.core.git/test_git_pure_manager clean test
scripts/git-contract-check.sh   # C1-C6 契约完备性（含 C4 纯后端零 libgit2）
make hygiene                     # 产物卫生（禁止 .o/.ppu 等散落源码树）
```

覆盖见 [CONTRACT.md §6](CONTRACT.md#6-测试覆盖)：`test_git`（libgit2 真库 20+）、`test_git_bindings`（ABI 黄金）、`test_git_native`（≈114，零 libgit2）、`test_git_pure_manager`（C4 闭环，`grep + fpc -va`）。
