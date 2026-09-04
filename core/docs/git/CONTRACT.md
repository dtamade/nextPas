# nextpas.core.git 代码契约

**模块路径**：`core/src/nextpas.core.git*.pas`（89 个源文件，含 6 个 native 门面 + 10 个 bindings 域分片 + `libgit2.types` 词汇 helper + `scripts/git-contract-check.sh` C5 自动门禁；双编译器 stub：源码 `uses SysUtils` 等经 `units/<target>/` 名称桥接，无 `{$IFDEF}` 分叉，stub 仅过渡、随 `nextpas.core` 自有类型落地自然废弃）
**层级**：L2（依赖 L0-L1: base, text, bytes, io；native 子家族另用同层单向 fs/compress/hash/zlib/checksum owner，经 core/docs/core-module-registry.md 显式豁免；89 源/40+ 能力聚合已按不变量域拆 6 shard（`design-conventions.md §2` 单单元 >800 必拆），各 shard 行阈与 umbrella 索引由 `scripts/git-contract-check.sh` C5 硬门禁维持阈值——非人工巡检，属演进监控点；1→89 源演进经 C5 固化）
**拆分生效**：2026-09-02（按业务不变量域独立契约，umbrella 仅索引与跨域不变量；分域不变量、门面阈值与 SLO 归各 shard 权威；总索引阈值由 C5 硬门禁维持，属演进监控点）
**Owner**：Claude（AI 负责）
**最后更新**：2026-09-02
**版本**: 2.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| git.base | TGitStatusEntry, TGitStatusFilter 基础类型 |
| git.intf | IGitManager, IGitRepository, IGitCommit 等接口定义 |
| git.libgit2 | libgit2 集成门面 |
| git.libgit2.ffi | libgit2 C FFI 缝隙（极简占位 <30 行，四件套仅含 external 约束下零 re-export 聚合、零 libc 探针；词汇单源 libgit2.base/types + ffi.*直引、bytes.ops 单源 inline 零拷贝；运行时仍经 binding/platform.dl 候选表 dlopen/dlsym，零 IFDEF） |
| git.libgit2.binding | libgit2 函数指针绑定（dlopen/dlsym 运行时加载） |
| git.libgit2.backend | libgit2 后端实现 |
| git.libgit2.bindings | libgit2 门面（<150 行，re-export 10 域分片，零重复） |
| git.libgit2.bindings.types | 标量别名域（C 类型，<250 行） |
| git.libgit2.bindings.structs | 记录/句柄/回调域（PACKRECORDS C，<800 行） |
| git.libgit2.bindings.consts | 常量域（GIT_*，<700 行） |
| git.libgit2.bindings.c | C 标准库 external 域（memcpy/strtod 等，external 'c'） |
| git.libgit2.bindings.oid | oid/indexer/odb 基础域（inline Move 零拷贝，复用 bytes.ops） |
| git.libgit2.bindings.odb | odb 流域 |
| git.libgit2.bindings.refs | refs/refdb 域 |
| git.libgit2.bindings.commit | commit/tree/blob 域 |
| git.libgit2.bindings.repo | repository 域 |
| git.libgit2.bindings.diff | tree/diff/patch 域 |
| git.libgit2.bindings.extra | filter/attr/checkout/config/remote/revwalk 等剩余域 |
| git.libgit2.base | libgit2 基础类型/句柄/oid 单源（20-byte 以 native.base.TGitOid 为权威，git_oid variant id/Bytes 零拷贝，33-byte TGitOid33 已移除 Phase7，SHA256 泛型候选经 bytes.ops Len 参化，复用 bytes.ops） |
| git.libgit2.types | 词汇 helper（标量/句柄/OID/枚举，纯 re-export，bytes.ops 单源 inline 零拷贝；原 ffi.types 零 external 已迁出，ffi 仅 external 极简 <30 行） |
| git.libgit2.ffi.types | **已删除**（文件已物理删除，零 tombstone 零 re-export 零 external 探针；词汇单源 base←types via nextpas.core.git.libgit2.types，ffi 仅 external 极简；新代码直用 libgit2.types；零死文件噪音、hygiene 零产物假象已消除） |
| git.libgit2.manager | libgit2 管理器实现（TGitManagerImpl/TGitRepositoryImpl 完整 IGit* 适配，经 backend/binding + dlopen/dlsym） |
| git.native.base | 纯 Pas 对象层：TGitOid / TGitObjectKind / EGitError |
| git.native.zlib | zlib 流边界处理（复用 compress.Deflate*，嵌入式 reader） |
| git.native.loose | loose 对象读写（objects/xx/yyyy 布局，SHA-1 寻址） |
| git.native.pack | .idx v2 解析、pack 对象读取、OFS/REF delta 应用 |
| git.native.refs | HEAD / loose refs / packed-refs / gitdir 发现 |
| git.native.objmodel | commit/tree/tag 文本格式解析 |
| git.native.repo | TNativeRepository：loose + packs 聚合只读访问 |
| git.native.write | 写路径：blob 写入、tree 规范排序/序列化、commit/tag 构造 |
| git.native.index | .git/index 读写（DIRC v2/v3/v4，TREE 扩展解析/再生成/构建器，SHA-1 校验） |
| git.native.cachetree | TREE 扩展纯格式单元：记录解析（名字 NUL 前缀、计数哨兵 -1）与两遍精确尺寸序列化 |
| git.native.status | worktree status 聚合（HEAD↔index 暂存态 / index↔worktree 工作树态 / untracked 扫描 + rename/copy 检测：oid 100 快路径 + hashsig 行哈希 0..100、阈值 50 配对、porcelain 分组序） |
| git.native.ignore | .gitignore 引擎：模式编译（负规则/锚定/仅目录/字符类/**）、分组栈（深目录优先、文件内后者胜）、纯逻辑无 IO |
| git.native.revwalk | 提交遍历（committer-date 降序游标 + topo 序一次性规划，first-parent / hide + boundary / since-until 日期裁剪，每提交恰一次读取解析，commit-graph 透明加速） |
| git.native.commitgraph | commit-graph v1 读写+缓存（CGPH 头 + OIDF/OIDL/CDAT/EDGE + 尾 SHA-1，fanout 二分，octopus 溢出，`Build/Write/WriteAll/Verify/Invalidate` 3 块无 GDA2 最小闭合，`Write*` 经 `WriteAtomic` 原子落盘 + 内存/文件双重校验 + `Invalidate`，`TryLoad` 经 `Stat.mtime+size` 缓存 `IMappedFile` 零堆复制 `MmapOpen`（`Cap=16` 8→16 半减多仓 thrash，`PByte` 零拷贝 via `io.mapped`，`bytes.ops` 单源，OS page-reclaimable，`inline` O(1) Seq touch + O(Cap) victim 扫描 trivial 16×UInt64 <30ns 无线性搬移/接口拷贝抖动，`GGraphCacheLock` (L1 `sync.mutex`) 纯锁模型已退役外部同步，`collections.lrucache` 候选已闭合 — 16-cap 手工保留 `DirHash` FNV-1a via `bytes.ops` + `IMappedFile` 零拷贝 vs `TLruCache` 开销，波动门禁见 CONTRACT.history.md §3），`WriteAll` 聚合全量起止，`git commit-graph write/verify` 黄金） |
| git.native.reflog | reflog 读取（`logs/<ref>` 文本解析，`old new sig TAB msg`，签名复用 `GitParseSignature`，空文件与缺失回空数组） |
| git.native.stash | stash 栈（`logs/refs/stash` reflog 列表反序 + `GitStashPush/Apply/Pop/Drop/Clear` 原生栈操作：push 为 index/working 树落盘→index/stash 提交→reflog append→refs/stash→检出回 HEAD；apply 为 `checkout` 目标树；pop=apply+drop；drop/clear 精确重写 reflog 与 refs，对齐 `git stash push/pop/apply/drop/clear`） |
| git.native.worktree | worktree 列表与增删（`worktrees/<id>/commondir+gitdir+HEAD` 布局，`Add` 创建分支/检出、`AddDetached` 游离、`Remove` 清理，对齐 `git worktree add/list/remove --porcelain`） |
| git.native.config | config 读写（INI 风格 `[section]`/`[section "sub"]`，引号转义 `\" \\ \n \t \b`，大小写折叠，`--get/--get-all` 语义，对齐 `git config --list`） |
| git.native.pktline | pkt-line 帧编解码（`0000` flush / `0001` delim / `XXXXpayload`，4-hex 长度含头，hex 校验、65535 上限、空载 `0004` 禁止，`Scan`/`Join` 流式拼装） |
| git.native.remote | 远端清单（基于 `config` 的 `[remote "<name>"]` 分组，`url`/`pushurl`/`fetch` 多值，对齐 `git remote -v` / `git remote get-url`） |
| git.native.advertise | 公告解析（`pkt-line` 之上，`oid SP ref [NUL caps] LF`，首行能力表，`flush` 终止，`delim` 兼容） |
| git.native.negotiate | 协商编解码（`want/have/done` pkt-line 生成与 `ACK/NAK` 解析，复用 pkt-line，首 want 能力表） |
| git.native.sideband | 复用分流（`chr(1/2/3)+payload` side-band-64k 解复用，`Data` 二进制保 NUL、`Progress/Error` 文本，`flush` 终止） |
| git.native.indexer | 索引重建（`pack`→`idx v2` 构建，OFS/REF delta 解析、CRC-32、fanout 排序、pack/index SHA-1，对齐 `git index-pack`） |
| git.native.fetch | 抓取客户端（`git upload-pack --stateless-rpc` 无状态抓取，want/have/done 协商 + sideband 解复用，对齐 `git fetch-pack`） |
| git.native.clone | 克隆（`upload-pack --advertise-refs` 公告 + `fetch` 整库抓取 + `pack→idx` 落盘 + `refs/HEAD/config` 骨架，对齐 `git clone --bare`；`GitClone` 另写 `refs/remotes/origin/*` + `HEAD` 树检出 + v2 index，对齐 `git clone` 黄金；检出委托 `checkout`） |
| git.native.checkout | 检出（任意 tree/commit/ref → worktree 物化，类型翻转/孤儿裁剪/可执行位/symlink/gitlink，v2 index 落盘，对齐 `git checkout`/`read-tree -u`） |
| git.native.push | 推送（`receive-pack --stateless-rpc` 无状态推送，`old new ref NUL caps` + flush + `pack-objects --revs --delta-base-offset` 生成包，对齐 `git push`/`send-pack`；支持创建/快进/删除/多 ref 原子，`report-status` 解析 `unpack ok`/`ok`/`ng`， stale-old 拒绝） |
| git.native.reset | 重置（`--hard` 单分支硬重置，复用 `checkout` 的工作树物化 + 孤儿裁剪 + v2 index，剥离 tag 至提交，更新当前分支或游离 HEAD；支持 `oid`/`ref`/`HEAD~N` 等 rev via `git rev-parse` 回退） |
| git.native.prune | 裁剪（`remote prune` 陈旧远端追踪分支裁剪，`refs/heads/* → refs/remotes/<name>/*` 映射，对比 `ls-remote` 公告与本地 `refs/remotes` 树，删除 stale 分支与空目录，处理 `HEAD` symref，对齐 `git remote prune`/`fetch --prune`） |
| git.native.clean | 清理（`git clean` untracked 清理，`-d` 目录、`-x` 忽略文件、`-n` 演练，复用 status 的 `info/exclude` + `core.excludesFile` + 逐级 `.gitignore` 与 index 已追踪集，对齐 `git clean -f/-d/-x/-n`） |
| git.native.revparse | 解析（`rev-parse` 修订语法，支持 `HEAD`/`refs/*`/`branch` dwim + 40-hex + `~<n>`/`^<n>` 父链 + `^{commit|tree|blob|tag|}` 剥离，对齐 `git rev-parse --verify`，`reset --hard` 首选原生解析） |
| git.native.notes | 笔记（`refs/notes/*` 提交：`target-hex → blob` 映射，flat 写 + 递归 fanout 透明读，`core.notesRef` 默认 `commits`，对齐 `git notes add/show/list/remove`） |
| git.native.branch | 分支（`refs/heads/*` 列表/当前/创建/删除/重命名，loose 递归+packed-refs 归并去重排序，`HEAD` symref 跟随，对齐 `git branch --list/create/delete/move`） |
| git.native.tag | 标签（`refs/tags/*` 列表/轻量/附注/删除/重命名，loose 递归+packed-refs `^` peeled 归并，附注经 `TagBuilder` + 对象剥离，对齐 `git tag --list/create/delete`） |
| git.native.log | 日志（`log` 列表/oneline/查找，`Head/branch/tag/~` 起点经 `rev-parse` 剥离，`revwalk` date 序聚合 + `commit` 解析，对齐 `git log --oneline`） |
| git.native.describe | 描述（`describe` 最近标签距离，BFS 最短路径 `Head→parents`，`tag` 剥离后 `tag-距离-gShort`，`--tags` 含轻量，对齐 `git describe`/`--tags`） |
| git.native.diff | 差异（`diff` 树对比/名称状态/统计，扁平化递归 + 字典排序 + 归并，Added/Modified/Deleted/TypeChanged，对齐 `git diff --name-status`，零重命名，peel 16 层） |
| git.native.blame | 归因（`blame` 行级归因，LCS 行 diff + head-vs-each 最老匹配，线性历史，对齐 `git blame --porcelain`，`ShortOid(7)`/author/time） |
| git.native.mergebase | 合并基（`merge-base` 最近公共祖先，A 祖先集 + B BFS 最短命中，多提交归并，对齐 `git merge-base`） |
| git.native.show | 展示（`show` 提交展示，`log` 聚合 + `parent→tree diff` + `name-status/stat`，根空树/首父，对齐 `git show --name-status`） |
| git.native.shortlog | 简志（`shortlog` 作者聚合，`Author Name+Email` 分组 + 计数降序 + 姓名升序，对齐 `git shortlog -s -n`） |
| git.native.catfile | 检视（`cat-file` 对象检视，`type/size/content` + `pretty` 树/提交/标签/Blob，对齐 `git cat-file -t/-s/-p`） |
| git.native.lsfiles | 清单（`ls-files` 索引清单，`cached` 路径列表 + `stage` 详表 `mode oid stage<TAB>path` + `detailed` 记录，对齐 `git ls-files --stage`） |
| git.native.cherrypick | 拣选（`cherry-pick` 首父差异的扁平应用，`HEAD` 树落盘 + 新树递归构建 + `commit+trailer` + `checkout` + 分支/游离 `HEAD` 更新，对齐 `git cherry-pick`） |
| git.native.revert | 还原（`revert` 逆向首父差异 `Target→Parent` 的扁平应用，`Revert "<subject>"` + `This reverts commit <oid>.` + 递归建树 + `checkout`，对齐 `git revert`） |
| git.native.archive | 归档（`archive` 树扁平化→USTAR `tar`，`$4000` 递归 + 排序 + `0644/0755` 与 `2` 符号链接，gitlink 跳过，`1024` 零块收尾，对齐 `git archive --format=tar`） |
| git.native.submodule | 子模块（`.gitmodules` INI 解析：`[submodule "name"] path/url/branch`，worktree 优先、HEAD 回退，对齐 `git config -f .gitmodules --list`） |
| git.native.mailmap | 身份映射（`.mailmap` 解析：`[proper] [<proper>] [commit] [<commit>]`，worktree 优先、HEAD 回退，大小写折叠，对齐 `git check-mailmap`） |
| git.native.trailer | 尾注（`trailer` 解析：`Key: Value` 尾块、`Has/Find/Format/Append`，大小写折叠，对齐 `git interpret-trailers`） |
| git.native.attributes | 属性（`.gitattributes` 模式→属性映射，`*`/`?`/`**` 通配，`set/-unset/value`，last-match-wins，对齐 `git check-attr`） |
| git.native.bundle | 束（`bundle` v2 创建/校验/列表/落盘，`pack-objects --revs --delta-base-offset` 生成 pack、`SHA-1` 尾校验、`-` 前提与标题、跨 `git bundle verify/list-heads/fetch` 黄金） |
| git.native.grep | 搜索（`grep` 树内全文检索，`HEAD`/`ref`/`tree` 起点、`-i` 大小写折叠、行号/路径/行文本、二进制跳过、`path:lineNo:line` 排序，对齐 `git grep -n`） |
| git.native.bisect | 二分（`bisect` 首坏提交定位，`good..bad` 候选经 `revwalk` topo 排除 + 二分回调，对齐 `git bisect` 线性史） |
| git.native.common | 共享对象助手（tree 查找/tag 剥离单源，GitFindBlobInTree/GitPeelToTree，零重复，EGitError 语义） |
| git.native.util | 通用工具单源（Trim/SplitLines/WorktreeDir/FindBlobInTree/PeelToTree，inline/零拷贝，去重 common） |
| git.native.wildmatch | **已移除**（owner 已收敛至 L1 `text.wildmatch` 单源，`*`/`?`/`**`/`[]` 含转义/字符类，零 SysUtils；`ignore`/`attributes` 直连 `text.wildmatch.WildSegment*` inline 零拷贝 via `bytes.ops` 单源，原 thin shim 已删除） |
| git.factory | TGitBackend + NewGitManager/NewNativeGitManager + RegisterLibGit2Creator 选择层（静态仅 native.manager，注册注入 libgit2，gbAuto 首版=gbLibGit2，详见 PURE-BACKEND.md §4） |
| git.native.manager | TNativeGitManager 纯实现（零 libgit2，闭合 Initialize/IsRepository/OpenRepository/InitRepository） |
| git.native.repository | TNativeRepositoryAdapter 适配（IGitRepository/IGitRepositoryExt 纯实现，未实现方法抛 EGitError('not implemented for native backend: <Method>')） |
| git.native.objects | 对象层门面分片（oid/zlib/loose/pack/refs/objmodel/write，唯一 inline 零拷贝网关，<400 行；native 为已折叠空 BC shim 零类型/常量/函数转发 `@deprecated`，唯一门面为 objects） |
| git.native.staging | 暂存区门面分片（index/cachetree/status/worktree/lsfiles/clean，委托 bytes.ops） |
| git.native.history.traversal | 历史·遍历分片（revwalk/commitgraph/reflog/revparse，4 单元 <210 行，inline 零拷贝 via bytes.ops） |
| git.native.history.query | 历史·查询分片（log/describe/diff/blame/mergebase/show，6 单元 <260 行） |
| git.native.history.ops | 历史·操作分片（shortlog/catfile/cherrypick/revert，4 单元 <180 行） |
| git.native.history | **已移除**（umbrella 空壳已删除，零聚合；历史能力经 `history.{traversal,query,ops}` 3 分片直引，各 <260 行，预拆前 14 单元/464 行已按域分片，新代码禁 `uses history`） |
| git.native.branches | 分支门面分片（branch/tag/stash/notes） |
| git.native.transport | 传输门面分片（config/pktline/remote/advertise/negotiate/sideband/indexer/fetch/clone/checkout/push/reset） |
| git.native.extensions | 扩展门面分片（archive/submodule/mailmap/trailer/attributes/bundle/grep/bisect） |
| git.native | 子家族薄网关（<30 行，已折叠空 BC shim 零类型/常量/函数转发 `@deprecated`，对象层唯一门面为 `objects`，零 I-Cache 复制，fan-in 收敛至 objects→owners；staging/history/branches/transport/extensions 需直引分片，旧 `uses git.native` 已弃用以消除类型/常量双重薄网关稀释，将移除） |
| git.pas | 门面 re-export（inline NewGitManager → factory.NewGitManager(gbAuto)，impl 零 libgit2，base←intf←factory←facade 隔离） |

### 1.1.1 native 子家族（2026-08-25 起）

- 定位：无外部依赖的 git **对象层 + 工作树状态 + 历史遍历 + 传输基座**（object
  storage + refs + parsing + index 读写（含 TREE cache-tree）+ status
  聚合（含 .gitignore + rename/copy 检测）+ revwalk + commit-graph 读写+缓存（`Build/Write/WriteAll/Verify/Invalidate` + `Stat` 缓存） + reflog + stash（含 push/pop/apply/drop/clear）+ notes + branch + tag + log + describe + diff + blame + mergebase + show + shortlog + catfile + lsfiles + cherrypick + revert + archive + submodule + mailmap + trailer + attributes + bundle + grep + bisect + worktree + config + pkt-line + remote + advertise + negotiate + sideband + indexer + clone + checkout + push + reset + prune + clean + revparse）。
  不实现网络协议；
  远期网络与更深相似度调优仍由 libgit2 后端承接。
- `EGitError`（git.native.base）是 native 子家族的统一错误类型；
  libgit2.backend 内的同名声明为历史遗留，后续统一时收敛到 base。
- pack 读取需要"流结束即停"的解压语义，来自 compress 模块的
  `DeflateReaderEmbedded`（TDeflateReader.CreateEmbedded）。
- 已知限制：index v1 不支持；idx CRC 表不校验；delta 链深度上限 64；
  index 的 split-index/sparse 扩展（小写强制扩展）遇到即拒绝而不是跳过；
  SHA-256 对象格式不支持（仅 SHA-1，20-byte `TGitOid` 权威）；
  shallow/grafts 不支持（revwalk 仍遍历全父链）；
  网络 `http(s)/ssh/git` 抓取/推送不支持（`CloneRepository` 仅本地目录与 `file://`，网络抛 `EGitError(transport)`；`Fetch` 返回 `False`）；
  `SetGlobalConfig` 写不支持（读支持全局两文件+`XDG`，写需 `libgit2` 或 CLI）；
  cache-tree 冲突失效为整树粒度（git 是按目录最小失效，消费语义等价——
  无效缓存本就必须重算）；checkout 对 linked worktree 的 `commondir` 透明（经 `EffectiveGitDir` 读对象、`AGitDir` 写 index）；
  status/clean 有 .gitignore 链（.git/info/exclude + `core.excludesFile` 全局排除 + worktree 逐级 .gitignore，`~/` 展开）、untracked 过滤与 rename 检测（阈值 50
  的 oid 快路径 + hashsig 行哈希配对，porcelain 分组序归并，conflict
  时跳过 rename；copy 需显式开启）与 submodule 目录存在性校验；clean 另支持 `-d`（含 tracked 后代的目录不删）、`-x`（连忽略文件一并删）与 `-n` 演练；
  revwalk 不支持 shallow/grafts，日期相同者顺序未定义（测试用显式日期；
  topo 序复刻 git 默认 REV_SORT_IN_GRAPH_ORDER 的 LIFO 就绪栈语义）；
  已支持 first-parent（仅首父）、hide/exclude（连带祖先）+ boundary（紧邻隐藏父）、
  since/until（committer-date 过滤，0 为无界，仅裁剪发射仍遍历父链）、
  commit-graph 透明加速（命中则免 inflate/parse，未命中或无文件回退对象层）；
  archive 为 `树扁平化→USTAR tar`（`$4000` 递归扁平→排序→512 块，`$E000` 跳过，`0644/0755` 固定 исполняемые位、`0777+typeflag '2'` 符号链接，mtime 置 0，末尾 1024 零块；不含 `pax_global_header`、不下显式目录条目、忽略 umask，解包等价；`HEAD`/`ref` 经 `rev-parse`+16 层剥离）；
  bundle 为 `v2 bundle`（`# v2 git bundle` 头 + `-<oid> <title>` 前提 + `<oid> <ref>` 列表 + 空行 + `PACK` 流，经 `pack-objects --revs --delta-base-offset` 生成 pack，`SHA-1` 尾 20B 校验，`GitBundleVerify` 深校验经 `GitBuildPackIndex`，`Unbundle` 落盘 `pack-<hash>.pack/.idx` 并写 `refs/*` 与 `refs/bundle/HEAD`，与 `git bundle create/verify/list-heads/fetch` 黄金互通，支持 `HEAD~`/`^`/`..` 前提语法）；
  grep 为 `树内 grep`（`HEAD`/`ref` 经 `rev-parse` 16 层剥离至 `tree`，扁平化 `$4000` 递归 + 二进制 NUL 跳过 + `Pos` 固定串 + `-i` 大小写折叠，经 `path:lineNo` 排序，对齐 `git grep -n -F`）；
  bisect 为 `二分首坏`（`good..bad` 经 `GitTopoOrderCommits` 排除祖先 + 回调二分，`log N` 步定位，对齐 `git bisect` 线性史）；
  commit-graph 读写为 `CGPH v1 构建+缓存`（`OIDF/OIDL/CDAT` 3 块 + 尾 SHA-1，`fanout` 累积 + `OIDL` 排序 + `CDAT` 36B/条 + `EDGE` 溢出 + `generation` 迭代收敛，`Write*` 经 `WriteAtomic` 原子落盘 + 内存/文件双重 `Verify` 校验 + `Invalidate`，`TryLoad` 经 `Stat.mtime+size` 缓存 `IMappedFile` 零堆复制 `MmapOpen`（`Cap=16` 8→16 半减多仓 thrash，`PByte` 零拷贝 via `io.mapped`，`bytes.ops` 单源，OS page-reclaimable，`inline` O(1) Seq touch + O(Cap) victim 扫描 trivial 16×UInt64 <30ns 无线性搬移/接口拷贝抖动，波动门禁见 CONTRACT.history.md §3），`WriteAll` 聚合 `refs/heads + HEAD + tags` 起止，经 `GitCollectCommits` 全量闭合，对齐 `git commit-graph write/verify` 黄金）。
- 参考实现对照表见 `native-reference-map.md`（~/projects/libgit2 只读借鉴，
  不进源码树、不搬代码）。

### 1.1.2 双轨绑定架构（2026-08-25 起）

libgit2 声明层是**两条互补轨道**，不是竞争关系：

| 轨道 | 单元 | 加载方式 | 覆盖面 | 验证 |
|---|---|---|---|---|
| 运行时加载系 | ffi + binding + backend | dlopen/dlsym（platform.dl），零链接依赖 | 手写子集，按需增长 | test_git 20 测全绿（真库跑 commit/diff/blame/revwalk/config） |
| 静态声明系 | bindings (+10 域分片 types/structs/consts/c/oid/odb/refs/commit/repo/diff/extra) | external 'c'（构建期 -lgit2 / soname 直链），门面 <150 行，每分片 <800 行 | 全量 876 函数 + 全部类型/宏（c2pas888 生成后按域分片） | test_bindings 5 测全绿（gcc 探针 sizeof/offsetof 黄金对照 + 运行时版本实证，uses 显式分片） |

- 默认消费路径是运行时加载系；静态声明系服务需要完整 ABI 面
  （如绑定生成器、ABI 审计、未来静态链接发行形态）的场景。
- 选择层默认仍走 libgit2（需显式 `uses nextpas.core.git.libgit2` 注册）：`nextpas.core.git.factory.NewGitManager(gbAuto)` 首版等价 `gbLibGit2`（已注册时），未注册时 fail-closed；`uses nextpas.core.git; NewGitManager;` 未注册时亦三零（门面 impl 零 libgit2，base←intf←factory←facade）；纯路径 `gbNative`/`NewNativeGitManager` 或直连 `native.manager` 无需注册（见 PURE-BACKEND.md §2-§3）。
- 词汇收敛（单源 `native.base.TGitOid` 20-byte 为权威，`bytes.ops` 单源 `SpanEqual/SpanCopy/IsZeroBytes/SpanFill`，`inline` 零拷贝 `Move`/`MemEqual`/`MemSet` 3×QWord，§7 `Oid/Same:inline` ≤80 ns/op, `Oid/IsValidHex|FromHex|ToHex` ≤150 ns/op not inline per red line 2）：
  运行时 `git_oid` 为 `libgit2.base.git_oid` variant 叠加（`id/Bytes/AsNative` 同偏移 0，`SizeOf=20=GitOidRawLen`，`PACKRECORDS C` 双编译器等价 stub 经 `settings.inc`，`Assert` 二进制保证，`GitOidToNative/NativeToGitOid` `inline` 零拷贝 overlay 无 `Move`，Pascal 别名 `TGitOid/TGitOid20` 同体）；
  静态 `TGitOid`（`bindings.structs`）已单源化为 20-byte `libgit2.base.git_oid` 别名（`SizeOf=20`，`PACKRECORDS C` 双编译器 stub，`Assert` 同源，`inline` 零拷贝 `SpanEqual` 3×QWord / `SpanCopy` 单 `Move` 无堆，`try..finally` 资源不丢），33-byte `TGitOid33` 及其 `GitOidCopy20To33/33To20/GitOid33Equals` 桥接已于 Phase7 (2026-09-02) 彻底移除（`grep -R TGitOid33` 零命中），SHA256 泛型候选改经 `bytes.ops` `Len` 参化 `TByteSpan`（`SpanEqual/Create(@Buf,32)`）非定长结构，不再占用单源；新模块一律经 20-byte 权威（`scripts/git-contract-check.sh` C5 `grep -R TGitOid` 越界即 warn，Phase 7 已清理静态 33-byte 双轨，`bindings.structs:685` 不再 `TGitOid33`）；
  Ops 单源收敛：`libgit2.base.GitOidEquals/IsZero/Copy` 与 `bindings.oid.BindingsGitOidEquals/Copy` 同经 `bytes.ops`（`SpanEqual`→`MemEqual`、`SpanCopy`→`Move`，`GIT_OID_RAWSZ` 单源，`inline` ≤80 ns/op），`helper Equals/IsZero/Assign` 亦同源，消除分散 `Move/CompareMem` 双轨；
  路线：Phase 6（2026-09）别名+Ops 收敛（本 CONTRACT 生效，`bindings-pitfalls.md` 同步），Phase 7（2026-09-02）已完成静态 33-byte `TGitOid33` 双轨彻底清理与历史 `PChar/cint` 词汇收敛（`grep -R TGitOid33` 零命中 + `scripts/git-contract-check.sh` C5 归一 gate），期间任何一侧增补仍以各自 gate 为准但须经单源 Ops；
  稳定性：`PACKRECORDS C`（FPC/nextPas 双编译器等价 stub 经 `settings.inc`） + `Assert(SizeOf=20)` 失败即停，句柄 `Pointer` 缝隙零成本，`try..finally` 资源不丢，`heaptrc` 双 pin 零泄漏门禁同 §6。
- 再生成与坑清单见 `bindings-pitfalls.md`。

### 1.1.3 按不变量域独立合约拆分（2026-09-02 起）

89 源/40+ 能力聚合已超越单 CONTRACT 可审计阈（`design-conventions.md §2` 800 行软阈），按业务不变量域独立契约拆分，本文件仅作总索引与跨域不变量权威；门禁由 `scripts/git-contract-check.sh` C5 硬门禁维持阈值（各 shard 单单元 ≤800 行，门面 shard 按域分档 <250-600 行，umbrella 仅索引，超阈即红），属演进监控点（1→89 源含 6 native 门面 + libgit2.types + C5 自动门禁固化）：

| 不变量域 | 权威 CONTRACT | 门面 shard | 行阈 | 能力 |
|---|---|---|---|---|
| 对象层 | `CONTRACT.objects.md` | `git.native.objects` | <400 行 | oid/zlib/loose/pack/refs/objmodel/repo/write，零拷贝 via `bytes.ops`/`checksum.adler32`/`compress` |
| 暂存区 | `CONTRACT.staging.md` | `git.native.staging` | <500 行 | index/cachetree/status/ignore/worktree/lsfiles/clean + wildmatch 薄委派至 `text.wildmatch` |
| 历史 | `CONTRACT.history.md` | `git.native.history.{traversal,query,ops}`（`history` umbrella 已移除） | 各 <260 行 / 总 <650 行 | revwalk/commitgraph/reflog/revparse/log/describe/diff/blame/mergebase/show/shortlog/catfile/cherrypick/revert 等，20+类型/40+inline，预拆前 14 单元/464 行已按 traversal/query/ops 域拆分 |
| 分支 | `CONTRACT.branches.md` | `git.native.branches` | <300 行 | branch/tag/stash/notes |
| 传输 | `CONTRACT.transport.md` | `git.native.transport` | <600 行 | config/pktline/remote/advertise/negotiate/sideband/indexer/fetch/clone/checkout/push/reset |
| 扩展 | `CONTRACT.extensions.md` | `git.native.extensions` | <400 行 | archive/submodule/mailmap/trailer/bundle/grep/bisect + attributes |

> **权威规则**：分域内不变量、阈值与门面规模以各 shard CONTRACT 为准；跨域不变量、选择层与总体 89 源清单以本 umbrella 为准。新增能力先反哺 owner（bytes/compress/checksum/wildmatch），分域仅薄编排。
> **演进监控点**：总索引 1→89 源（含 6 native 门面 + libgit2.types + 10 bindings 域分片）及各 shard 行阈（objects <400 / staging <500 / history 各 <260 & umbrella <80 & 总 <650 / branches <300 / transport <600 / extensions <400 / native <250 / bindings 门面 <150 & 分片 <800）均由 `scripts/git-contract-check.sh` C5 硬门禁自动维持，超阈即红，非人工巡检；阈值接近 800 软阈或 fan-in 显著时再评估拆分（见各 shard §6 与本 umbrella §8）。

### 1.2 核心接口

```pascal
IGitManager = interface
  function Initialize: Boolean;
  procedure Finalize;
  function OpenRepository(const APath: string): IGitRepository;
  function CloneRepository(const AURL, ALocalPath: string): IGitRepository;
  function InitRepository(const APath: string; ABare: Boolean = False): IGitRepository;
  function IsRepository(const APath: string): Boolean;
  function DiscoverRepository(const AStartPath: string): string;
  function GetGlobalConfig(const AKey: string): string;
  function SetGlobalConfig(const AKey, AValue: string): Boolean;
  function Version: string;
  procedure SetVerifySSL(AEnabled: Boolean);
  procedure SetCredentialAcquireHandler(AHandler: TCredentialAcquireEvent);
  procedure SetCertificateCheckHandler(AHandler: TCertificateCheckEvent);
  function Initialized: Boolean;
  function VerifySSL: Boolean;
end;

IGitRepository = interface
  function Status: TGitStatusEntryArray;
  function Head: IGitReference;
  function LookupCommit(const AId: string): IGitCommit;
  procedure Close;
end;

IGitCommit = interface
  function Id: string;
  function Message: string;
  function Author: string;
  function Timestamp: TInstant;
end;
```

选择层（`nextpas.core.git.factory`，静态仅 native.manager，注册注入 libgit2）：

```pascal
type
  TGitBackend = (gbNative, gbLibGit2, gbAuto);
  TLibGit2Creator = function: IGitManager;
procedure RegisterLibGit2Creator(ACreator: TLibGit2Creator);
function NewGitManager(ABackend: TGitBackend = gbAuto): IGitManager; inline;
function NewNativeGitManager: IGitManager; inline;
```

| 枚举 | 语义 | 首版行为 |
|------|------|----------|
| `gbNative` | 创建 `TNativeGitManager`，仅依赖 `native.*`，零 libgit2；`inline` 值类型枚举零拷贝分发，`bytes.ops` 单源，`try..finally` 资源不丢；未拉入 `libgit2` 时编译图/产物双零 | 纯路径（三零经门面/ factory/直连三重达成） |
| `gbLibGit2` | 创建 `TLibGit2Manager`，经 `platform.dl` 的 `dlopen/dlsym` 运行时加载 `libgit2`，需显式 `uses nextpas.core.git.libgit2` 注册（`RegisterLibGit2Creator`），未注册时 fail-closed 抛 `EGitError` | 需显式注册 |
| `gbAuto` | 策略别名，首版恒等于 `gbLibGit2`（已注册时），下版本切 `gbNative` 前发迁移公告；未注册时 fail-closed | 显式注册后兼容，未注册时三零（门面 impl 零 libgit2），详见 `PURE-BACKEND.md` §3 |

门面保留无参重载：`nextpas.core.git.NewGitManager` inline 转发 `factory.NewGitManager(gbAuto)`，impl 零 libgit2（`base←intf←factory←facade` 隔离，未注册时 `gbAuto` fail-closed 抛 `EGitError('not registered')`）；需 libgit2 轨道时显式 `uses nextpas.core.git.libgit2` 触发注册；纯消费显式 `gbNative`/`NewNativeGitManager` 或直连 `nextpas.core.git.native.manager.TNativeGitManager.Create`（三零）。

### 1.3 核心类型

```pascal
TGitStatusEntry = record
  Path: string;
  IndexStatus: TGitStatusKind;
  WorkdirStatus: TGitStatusKind;
end;
```

---

## 2. 不变量

- IGitRepository 拥有 libgit2 仓库句柄
- Close 后不可再使用
- Commit ID 为 40 字符十六进制字符串

---

## 3. 错误处理

- 仓库不存在抛 `EGitError`
- libgit2 错误抛 `EGitError`（含错误码）

---

## 4. 线程安全

- IGitManager 线程安全
- IGitRepository 非线程安全

---

## 5. 内存管理

- IGitRepository.Close 释放 libgit2 资源
- IGitManager 拥有 libgit2 全局状态

---

## 6. 测试覆盖

| 测试集 | 覆盖 | HEAPTRC 门禁（`haltonnotreleased` 双 pin 零泄漏） |
|--------|------|--------------------------|
| `test_git` | Status/Head/LookupCommit/Init/IsGitRepository（libgit2 真库，20 用例） | `HEAPTRC='haltonnotreleased,log=*.heaptrc'` 双 pin：`grep '^Heap dump by heaptrc unit'` 存在性 + `grep '^0 unfreed memory blocks : 0$'` 零泄漏 + `haltonnotreleased` exit 203 → `0 unfreed` |
| `test_git_bindings` | 静态声明系 ABI 黄金对照（5 用例，gcc 探针 sizeof/offsetof + 运行时版本实证） | 同上，双 pin 零泄漏（`common.mk HEAPTRC_GATE=1` 自动审） |
| `test_git_native` | native 子家族 118 用例（零 libgit2，覆盖 loose/pack/refs/objmodel/repo/write/index/cachetree/status/ignore/revwalk/commitgraph/reflog/stash/worktree/config/pktline/remote/advertise/negotiate/sideband/indexer/fetch/clone/checkout/push/reset/prune/clean/revparse/notes/branch/tag/log/describe/diff/blame/mergebase/show/shortlog/catfile/lsfiles/cherrypick/revert/archive/submodule/mailmap/trailer/attributes/bundle/grep/bisect/common/util/wildmatch，对齐 git 黄金） | 同上，118 用例零 libgit2 + 双 pin 零泄漏（`make -C core/tests/nextpas.core.git/test_git_native clean test` 经 `common.mk HEAPTRC_GATE=1` 审） |
| `test_git_pure_manager` | 纯门面 10 用例，零 `libgit2`（Init/StatusEmpty/StatusWithFile/HeadAndLookup/FactoryGbAutoCompat/Discover/Clone/CommitOnHead/AddWorktree/SetVerifySSL，经 `factory.NewGitManager(gbNative)` 运行时零 `libgit2` + 直连 `native.manager.TNativeGitManager.Create` 三零（`fpc -va Loading libgit2` 零命中，`inline` 值类型枚举零拷贝，`bytes.ops` 单源，`try..finally` 资源不丢），C4 门禁：`grep` 零命中 + `fpc -va Loading` 双重实检） | 同上，双 pin 零泄漏 + C4 双重闭环（`grep` + `fpc -va Loading`），`core/tests/common.mk:75-78` `haltonnotreleased+log` |

门禁：`scripts/git-contract-check.sh` C4 已闭环（`fpc -va Loading.*libgit2` 实检 + `grep` 零命中，双重）+ C5 硬门禁已闭环（88 源/6 native 门面/10 bindings 分片阈值自动维持，属演进监控点，超阈即红——非人工巡检）；`core/tests/common.mk HEAPTRC_GATE=1` → `HEAPTRC='haltonnotreleased,log=*.heaptrc'` 双 pin（`grep '^Heap dump by heaptrc unit'` 存在性防真空 + `grep '^0 unfreed memory blocks : 0$'` 零泄漏 + `haltonnotreleased` `exit 203`，FPC trunk `FlushFunc` 设备语义：`pipe/tty` 逐写刷新、`file` 缓冲丢失，故走环境变量双通道）自动化，全量 `20+5+118+10=153` 用例 `0 unfreed`；`make hygiene` + `git diff --check` 必要门禁；`build/verify_local.sh` 聚合 `git-contract-check`，以 `CONTRACT.md` 本节与 `PURE-BACKEND.md` §5 为准。

---

## 7. 基准

- **位置**：`core/benchmarks/nextpas.core.git/bench_git`（`TBenchSuite` via `nextpas.core.bench`，禁手搓计时，单次调用不内循环；对照见 `compare_go/` + `compare_rust/`）
- **构建**：`make -C core/benchmarks/nextpas.core.git/bench_git build` 经 `bench_common.mk` 落盘 `core/build/projects/nextpas.core.git/bench_git/bench_git`，`make hygiene` 零产物闭环（源码树无 `.o/.ppu/link*.res`）；对照构建 `make -C .../bench_git compare` 产 `compare_go/bench_git_go` + `compare_rust/bench_git_rs`（`-O3` 同机）
- **运行**：`make -C core/benchmarks/nextpas.core.git/bench_git run`（默认 `-O3 -Xs` 全量优化，无 heaptrc 计时保真；`SaveToJSON build/bench-git.json`）；同机 A/B 归一 `make -C .../bench_git bench-compare`（Pascal `ns/op` vs Go `testing.B ns/op` vs Rust `criterion ns/op`，`nextpas.core.bench.xlang` 解析统一 `TBenchResult`，同机同 `DATA_64K`）
- **覆盖**：`Oid/Same:inline`（`inline` + `Move` 零拷贝，复用 `bytes.ops.SpanEqual` 单源，20-byte `TByteSpan` 三 QWord 对比）/ `Oid/IsValidHex|FromHex|ToHex`（not inline per red line 2, 40× loop/alloc+table exceeds I-Cache, zero-copy via `encoding.hex` HexVal/HexDecode single source + `bytes.ops` SpanCopy single source）/ `Kind/FromMode`（`inline`）/ `Zlib/Compress1K|Decompress1K`（`native.zlib → compress.Deflate*` 透传，`PByte+Len` 零拷贝）/ `Adler32/PByte64K:zero-copy|Bytes64K`（`PByte` 零拷贝单源 `checksum.adler32.Adler32Update(PByte,Len)`，`ADLER32_MOD/NMAX` 单源，不自建 65521 循环）/ `Wild/*`（`wildmatch` 单源 `inline WildSegment* / WildSegmentsMatch` via `text.wildmatch` + `bytes.ops` 零拷贝，`**` 目录通配）/ `Delta/Apply|ApplyReuse`（`TByteSpan` 零拷贝 + `GReuseBuf` 复用单源 `GitApplyDeltaInto` via `bytes.ops`）/ `Status/RenameOidFastPath:inline|RenameHashSig:1K`（`oid 100 快路径 inline SpanEqual 零拷贝 via bytes.ops` + `hashsig 行哈希 CollectLineHashes+SortU32 127 cap+ScoreFromSigs merge O(CA+CB) via bytes.ops`，`CMax1MiB` guard 免大文件瞬时峰值）
- **阈值 SLO（绝对红线，ns/op / ops/sec，同机 `-O3 -Xs` 无 heaptrc 中位数，含 10-15% 抖动余量，`inline/零拷贝` 路径不回退，单源复用 `bytes.ops`/`checksum.adler32`/`compress`/`wildmatch`）**：`Oid/Same:inline` ≤ 80 ns/op（≥12.5 Mops/sec）；`Oid/IsValidHex|FromHex|ToHex` ≤ 150 ns/op（≥6.6 Mops/sec, not inline per red line 2 — 40× HexVal/alloc+table loop exceeds inline I-Cache benefit, bench阈与实现策略已对齐）；`Kind/FromMode:inline` ≤ 30 ns/op（≥33 Mops/sec）；`Zlib/Compress1K|Decompress1K` ≤ 15 µs/op（≥66 Kop/sec）；`Adler32/PByte64K:zero-copy|Bytes64K` ≤ 3 µs/op（≥333 Kop/sec, ~21 GB/s，零拷贝 `PByte+Len` 单源，`Bytes64K` 仅薄封装同阈）；`Wild/Segment:inline|Class|SegmentsMatch:**` ≤ 100 ns/op（≥10 Mops/sec）；`Delta/Apply|ApplyReuse:inline` ≤ 5 µs/op（≥200 Kop/sec）；`Status/RenameOidFastPath:inline` ≤ 80 ns/op（≥12.5 Mops/sec，`inline` SpanEqual 零拷贝 via bytes.ops，oid 同值 100 免 inflate/Score）；`Status/RenameHashSig:1K` ≤ 5 µs/op（≥200 Kop/sec，`CollectLineHashes inline 零拷贝 TByteSpan.Slice`+`SortU32` 单源 radix+introsort 127 cap+`ScoreFromSigs inline merge O(CA+CB)`，`CMax1MiB` guard 免大文件峰值，`bytes.ops` 单源）
- **门禁（可回归，双锚+噪声感知防漂移）**：基线锚为提交态 `core/benchmarks/nextpas.core.git/bench_git/baseline.json`（`TBaselineManager.SaveToFile/LoadFromFile`，`build/bench-git.json` 仅本地落盘，不为唯一真源），`COMPARE-GO-RUST` 同机 A/B 归一（Pascal vs Go `hash/adler32` vs Rust `adler` crate 同 `64K` 零拷贝 `PByte` 路径，`xlang` 解析差值归一）；判定为 `ratio>1.10` 且超出 `2×CV (StdDev/NsPerOp)`，不稳定样本 `CV>10%` 需 `ratio>1.15`，样本配置 `10@200ms + 3 warmup + adaptive warmup CV<5%`（原 `5@50ms` 易受噪声误判，已加倍）；再叠加绝对 SLO 红线，双重收敛（本地 JSON 漂移由提交态基线 + 绝对 SLO 双锚校正，单侧失真不掩回归），`make -C core/benchmarks/nextpas.core.git/bench_git run` 可复现。
- **稳定性**：`IMappedFile` 资源由接口引用计数拥有，`TPackFile` 析构释放；`bench` 初始化往返校验异常 `raise EGitError` 不泄漏（`TBytes` 受控，`try..finally` 不丢，`GReuseBuf` 复用不丢）
- **层级复核**：L2（依赖 L0: base, text, fs；native 子家族另用 compress/hash/io L1 owner）—— 与 §1 首部一致，`bench_git` 仅复用 owner 能力，不自建压缩/哈希实现；校验见 `bench_git/compare_go` 与 `compare_rust` 同机 A/B 报告（`bench-compare` 汇总 `SaveToJSON` + `xlang` 对比）

---

## 8. 演进监控（C5 硬门禁，阈值自动维持）

- **总索引**：1→89 源演进已固化（89 `nextpas.core.git*.pas`，含 6 native 门面 shard + libgit2.types + 10 bindings 域分片 + `native` 薄网关 `<250` 行 + `git.pas` 门面）；`scripts/git-contract-check.sh` C5 硬门禁自动维持，超阈即红，非人工巡检。
- **分片阈值（硬门禁，`wc -l` 行阈）**：`objects <400` / `staging <500` / `history.traversal|query|ops` 各 `<260` & `history` umbrella `<80` & 总 `<650` / `branches <300` / `transport <600` / `extensions <400` / `bindings` 门面 `<150` & 各分片 `<800`（含 `types/structs/consts/c/oid/odb/refs/commit/repo/diff/extra` 各 `<800`）；单源 `bytes.ops`/`checksum.adler32`/`compress`/`text.wildmatch` 零拷贝 `inline` 约束同步门禁。
- **触发与处置**：任一 shard 单单元 `>800` 或门面超域分档阈值即 C5 失败；接近阈值（>85%）即评估再拆分（按不变量域薄编排，复用 owner，不自建压缩/哈希/通配）；`commitgraph.pas` 约 1523 行已标记为历史域内聚例外并已超 1500 硬阈触发拆分评估（见 `CONTRACT.history.md §6`），不计入 800 阈但受 4 region 标记与独立门禁约束。
- **资源与性能同门禁**：`IMappedFile`/`TPackFile`/`TBytes` 零泄漏（`try..finally` + 接口计数，`HEAPTRC` 双 pin）、`inline` 零拷贝 `PByte+Len/TByteSpan`（`bytes.ops` 单源）与 SLO 双锚（§7）同 C5 聚合于 `build/verify_local.sh`。
