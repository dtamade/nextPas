# nextpas.core.git

`nextpas.core.git` 是 `nextpas.core` 的 L2 Git 集成模块。提供双轨后端（`libgit2` 运行时加载 + `native` 纯 Pascal）与 `factory` 唯一汇聚点，为 `IGitManager / IGitRepository / IGitCommit` 提供统一门面，已覆盖对象层 / refs / index / status / revwalk / 传输基座等 88 个源文件。

- 层级：L2，依赖 L0-L1（`base`/`text`/`bytes`/`fs`/`io`）；`native` 子家族另用同层单向 `compress`/`hash`/`zlib`/`checksum` owner 能力（mmap、Deflate、SHA-1、Adler-32 等，`core/docs/core-module-registry.md` 显式豁免 `L0-L1 plus same-layer one-way compress/hash/zlib/checksum`），不自建重复实现。
- 门面：`nextpas.core.git`（纯 re-export + `inline NewGitManager → factory.NewGitManager(gbAuto)`，impl 零 libgit2，`base←intf←factory←facade` 隔离）。
- 选择层：`nextpas.core.git.factory`（`TGitBackend = (gbNative, gbLibGit2, gbAuto)` + `RegisterLibGit2Creator` 注册注入 + `NewNativeGitManager` 纯别名，首版 `gbAuto = gbLibGit2` 需显式注册）。
- 纯路径：`nextpas.core.git`（未显式 uses libgit2）/`factory(gbNative)`/`NewNativeGitManager`/`native.manager` → `native.*` 零 `libgit2`（`scripts/git-contract-check.sh` C4 三重闭环：`grep` + `fpc -va Loading libgit2` + `nm -D` 产物零命中；`core/tests/common.mk:75-78` `haltonnotreleased+log` 双 pin 因 FPC trunk `FlushFunc` 设备语义；三零证据 `fpc -va`/`nm` 双零，门面/ factory 纯路径/直连三重三零，`inline` 值类型枚举零拷贝分发，`bytes.ops` 单源，`try..finally` 资源不丢）。
- 文档真源：契约见 [CONTRACT.md](CONTRACT.md)（总索引，88 源/40+ 能力按不变量域 6 shard 拆分）+ 6 shard 独立契约；纯后端隔离见 [PURE-BACKEND.md](PURE-BACKEND.md).

## 文档地图

| 文档 | 职责 |
|------|------|
| [README.md](README.md) | 本文件：统一门面与高级感入口 |
| [CONTRACT.md](CONTRACT.md) | 代码契约总索引（88 源/40+ 能力总览，跨域不变量与 800 行阈拆分索引） |
| [CONTRACT.objects.md](CONTRACT.objects.md) | 对象层契约（oid/zlib/loose/pack/refs/objmodel/repo/write） |
| [CONTRACT.staging.md](CONTRACT.staging.md) | 暂存区契约（index/cachetree/status/ignore/worktree/lsfiles/clean + wildmatch） |
| [CONTRACT.history.md](CONTRACT.history.md) | 历史契约（revwalk/commitgraph/reflog/revparse/log/diff/blame/mergebase/show） |
| [CONTRACT.branches.md](CONTRACT.branches.md) | 分支契约（branch/tag/stash/notes） |
| [CONTRACT.transport.md](CONTRACT.transport.md) | 传输契约（config/pktline/remote/advertise/negotiate/sideband/indexer/fetch/clone/checkout/push/reset） |
| [CONTRACT.extensions.md](CONTRACT.extensions.md) | 扩展契约（archive/submodule/mailmap/trailer/bundle/grep/bisect） |
| [PURE-BACKEND.md](PURE-BACKEND.md) | 纯 Pascal 后端隔离契约（依赖图、选择矩阵、`gbAuto` 迁移、`uses` 隔离与门禁） |
| [native-reference-map.md](native-reference-map.md) | `native.*` ↔ `~/projects/libgit2` 只读对照（格式/算法/边界清单，不进源码树） |
| [bindings-pitfalls.md](bindings-pitfalls.md) | `libgit2.bindings` 再生成管线与 C 绑定坑清单（c2pas888 / shim / 黄金对照） |

> 外部入口：`docs/contracts/git.md` 与 `core/docs/git/CONTRACT.md` 互为镜像时，以本目录为准。

## 源文件布局

```
core/src/nextpas.core.git.pas                 ← 聚合门面（re-export base/intf + inline NewGitManager(gbAuto)，impl 零 libgit2，base←intf←factory←facade）
core/src/nextpas.core.git.base.pas            ← TGitStatusEntry / TGitStatusFilter 基础类型
core/src/nextpas.core.git.intf.pas            ← IGitManager / IGitRepository / IGitCommit 接口
core/src/nextpas.core.git.factory.pas         ← TGitBackend + NewGitManager/NewNativeGitManager + RegisterLibGit2Creator（静态仅 native.manager，注册注入 libgit2）
core/src/nextpas.core.git.libgit2.base.pas     ← libgit2 基础类型/句柄/oid 单源（native.base TGitOid 20-byte 权威，git_oid id/Bytes 零拷贝，TGitOid33 legacy）
core/src/nextpas.core.git.libgit2.ffi.pas     ← libgit2 C FFI 聚合门面（<200 行，re-export 5 域分片，零 IFDEF，宿主库名经 binding/platform.dl 运行时候选）
core/src/nextpas.core.git.libgit2.ffi.types.pas   ← FFI 标量/句柄/OID/枚举域（csize_t/git_oid/branch/object/reference，<200 行）
core/src/nextpas.core.git.libgit2.ffi.structs.pas ← FFI 记录域（buf/strarray/time/sig/error/config/indexer/diff/blame，<200 行）
core/src/nextpas.core.git.libgit2.ffi.callbacks.pas← FFI 回调域（全部回调 typedef，<100 行）
core/src/nextpas.core.git.libgit2.ffi.options.pas ← FFI 选项域（remote/fetch/checkout/clone/push/worktree/diff 选项，<200 行）
core/src/nextpas.core.git.libgit2.ffi.consts.pas  ← FFI 常量域（全部 GIT_*，<200 行）
core/src/nextpas.core.git.libgit2.binding.pas ← libgit2 运行时绑定（dlopen/dlsym）
core/src/nextpas.core.git.libgit2.backend.pas ← libgit2 后端实现
core/src/nextpas.core.git.libgit2.manager.pas ← libgit2 管理器（TGitManagerImpl，经 backend/binding）
core/src/nextpas.core.git.libgit2.pas        ← libgit2 集成门面
core/src/nextpas.core.git.libgit2.bindings.pas← libgit2 门面（<150 行，re-export shards，零重复）
core/src/nextpas.core.git.libgit2.bindings.types.pas  ← 标量别名域（C 类型，<250 行）
core/src/nextpas.core.git.libgit2.bindings.structs.pas← 记录/句柄/回调域（<800 行，PACKRECORDS C）
core/src/nextpas.core.git.libgit2.bindings.consts.pas ← 常量域（GIT_*，<700 行）
core/src/nextpas.core.git.libgit2.bindings.c.pas     ← C 标准库 external 域（memcpy/strtod 等， shim external）
core/src/nextpas.core.git.libgit2.bindings.oid.pas   ← oid/oidarray/indexer 域（inline Move 零拷贝，复用 bytes.ops）
core/src/nextpas.core.git.libgit2.bindings.odb.pas   ← odb 流域
core/src/nextpas.core.git.libgit2.bindings.refs.pas  ← refs/refdb 域
core/src/nextpas.core.git.libgit2.bindings.commit.pas← commit/tree/blob/object 域
core/src/nextpas.core.git.libgit2.bindings.repo.pas  ← repository/annotated_commit 域
core/src/nextpas.core.git.libgit2.bindings.diff.pas  ← tree/diff/patch 域
core/src/nextpas.core.git.libgit2.bindings.extra.pas ← filter/attr/checkout/config/remote 等剩余域
core/src/nextpas.core.git.native.pas          ← native 子家族薄网关（<250 行，仅聚合 objects 核心对象层 + inline gateway 零拷贝 via bytes.ops，fan-in=1+base）
core/src/nextpas.core.git.native.objects.pas  ← 对象层门面分片（oid/zlib/loose/pack/refs/objmodel/write，inline 零拷贝）
core/src/nextpas.core.git.native.staging.pas  ← 暂存区门面分片（index/cachetree/status/worktree/lsfiles/clean，委托 bytes.ops）
core/src/nextpas.core.git.native.history.pas  ← 历史门面分片（revwalk/commitgraph/reflog/revparse/log/describe/diff/blame/mergebase/show/shortlog/catfile/cherrypick/revert，20+类型/40+inline，<600阈值内单 shard 单次交付，超阈按不变量域再分片）
core/src/nextpas.core.git.native.branches.pas ← 分支门面分片（branch/tag/stash/notes）
core/src/nextpas.core.git.native.transport.pas ← 传输门面分片（config/pktline/remote/advertise/negotiate/sideband/indexer/fetch/clone/checkout/push/reset）
core/src/nextpas.core.git.native.extensions.pas← 扩展门面分片（archive/submodule/mailmap/trailer/bundle/grep/bisect）
core/src/nextpas.core.git.native.base.pas     ← TGitOid / EGitError 等对象层基座
core/src/nextpas.core.git.native.{zlib,loose,pack,refs,objmodel,repo,write,index,cachetree,
  status,ignore,revwalk,commitgraph,reflog,stash,notes,branch,tag,log,describe,diff,blame,
  mergebase,show,shortlog,catfile,lsfiles,cherrypick,revert,archive,submodule,mailmap,
  trailer,attributes,bundle,grep,bisect,worktree,config,pktline,remote,advertise,negotiate,
  sideband,indexer,fetch,clone,checkout,push,reset,prune,clean,revparse,common,util,wildmatch,manager,repository}.pas
```

四件套范式：`base ← intf ← 实现 ← 门面`；依赖只向下，禁止同层循环。

## 核心不变量（见 CONTRACT.md §2-§5）

- **Ownership 单一所有者**：`TPackFile.FMapped: IMappedFile` 独占 `PByte+Size` 零拷贝视图，析构释放；`WriteAtomic` 临时句柄 `try..finally`。
- **Exactly-once 单次交付**：`revwalk`/`zlib`/`status-rename` 均恰一次 `ReadObject+Parse / inflate / 归并`，零重复开销。
- **单源复用**：`ignore/attributes` 委托 `wildmatch`（`GitWildSegment*`/`GitSegmentsMatch`，inline）；`Adler-32` 委托 `nextpas.core.checksum.adler32`（`ADLER32_INIT/MOD/NMAX` 单源，`PByte+Len` 零拷贝）；`Span/Bytes` 委托 `nextpas.core.bytes.ops`；`zlib` 委托 `nextpas.core.compress`（`CreateDeflateReaderEmbedded`）。禁止手写重复循环。
- **性能 inline/零拷贝**：`GitOidIsValidHex/GitOidSame/GitKindFromMode/GitZlibAdler32(PByte)` 等 `inline`；`GitZlibDecompressPtr/Adler32Update(PByte,Len)` 为 `Pointer+Len` 零拷贝，复用 `bytes.ops` 零分配路径。
- **稳定性**：`EIOError → EGitError` 映射保留 `EGitError` 原样 `raise`；`TPackFile/LoadPacks/Index` 异常 `try..finally` 重抛且不泄漏；`HEAPTRC=haltonnotreleased,log=*.heaptrc` 双 pin 零泄漏（`FPC trunk FlushFunc` 设备语义：`pipe/tty` 逐写刷新，`file` 缓冲丢失，`common.mk:75-78` 双通道）。

## 快速开始

```pascal
uses
  nextpas.core.git,            // 纯门面：未显式 uses libgit2 时 gbAuto/gbLibGit2 fail-closed，gbNative 三零
  nextpas.core.git.factory;    // 显式选择

var
  Mgr: IGitManager;
  Repo: IGitRepository;
begin
  Mgr := NewGitManager; // 等价 factory.NewGitManager(gbAuto)；未注册 libgit2 时抛 EGitError(not registered)
  // 需 libgit2 轨道时显式 uses nextpas.core.git.libgit2 触发 RegisterLibGit2Creator
  Mgr.Initialize;
  if Mgr.IsRepository('/path/to/repo') then
    Repo := Mgr.OpenRepository('/path/to/repo');

  // 纯路径（零 libgit2, 门面/ factory/直连三重三零）
  Mgr := factory.NewGitManager(gbNative); // 或 factory.NewNativeGitManager / native.manager.TNativeGitManager.Create
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

覆盖见 [CONTRACT.md §6](CONTRACT.md#6-测试覆盖)：`test_git`（libgit2 真库 20+）、`test_git_bindings`（ABI 黄金）、`test_git_native`（118 用例，零 libgit2，覆盖 archive/bundle/grep/bisect/worktree 等 40+ 能力）、`test_git_pure_manager`（10 用例，C4 三重闭环：`grep` + `fpc -va Loading libgit2` + `nm -D`，三零证据）。
