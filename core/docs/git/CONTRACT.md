# nextpas.core.git 代码契约

**模块路径**：`core/src/nextpas.core.git*.pas`（66 个源文件）
**层级**：L2（依赖 L0: base, text, fs；native 子家族另用 compress/hash/io L1 owner）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**: 2.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| git.base | TGitStatusEntry, TGitStatusFilter 基础类型 |
| git.intf | IGitManager, IGitRepository, IGitCommit 等接口定义 |
| git.libgit2 | libgit2 集成门面 |
| git.libgit2.ffi | libgit2 C FFI 类型层（回调 typedef 等，dlsym 系词汇） |
| git.libgit2.binding | libgit2 函数指针绑定（dlopen/dlsym 运行时加载） |
| git.libgit2.backend | libgit2 后端实现 |
| git.libgit2.bindings | libgit2 全量自动声明单元（c2pas888 生成，静态 external 形态） |
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
| git.native.commitgraph | commit-graph v1 读写+缓存（CGPH 头 + OIDF/OIDL/CDAT/EDGE + 尾 SHA-1，fanout 二分，octopus 溢出，`Build/Write/WriteAll/Verify/Invalidate` 3 块无 GDA2 最小闭合，`Write*` 经 `WriteAtomic` 原子落盘 + 内存/文件双重校验 + `Invalidate`，`TryLoad` 经 `Stat.mtime+size` 缓存 `TBytes` 零重复 `ReadFile`，`WriteAll` 聚合全量起止，`git commit-graph write/verify` 黄金） |
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
| git.factory | TGitBackend + NewGitManager 选择层（唯一跨轨汇聚点，gbAuto 首版=gbLibGit2，详见 PURE-BACKEND.md §4） |
| git.native.manager | TNativeGitManager 纯实现（零 libgit2，闭合 Initialize/IsRepository/OpenRepository/InitRepository） |
| git.native.repository | TNativeRepositoryAdapter 适配（IGitRepository/IGitRepositoryExt 纯实现，未实现方法抛 EGitError('not implemented for native backend: <Method>')） |
| git.native | 子家族门面 re-export |
| git.pas | 门面 re-export（inline NewGitManager → factory.NewGitManager(gbAuto)，存量零改动） |

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
  commit-graph 读写为 `CGPH v1 构建+缓存`（`OIDF/OIDL/CDAT` 3 块 + 尾 SHA-1，`fanout` 累积 + `OIDL` 排序 + `CDAT` 36B/条 + `EDGE` 溢出 + `generation` 迭代收敛，`Write*` 经 `WriteAtomic` 原子落盘 + 内存/文件双重 `Verify` 校验 + `Invalidate`，`TryLoad` 经 `Stat.mtime+size` 缓存 `TBytes` 零重复 `ReadFile`，`WriteAll` 聚合 `refs/heads + HEAD + tags` 起止，经 `GitCollectCommits` 全量闭合，对齐 `git commit-graph write/verify` 黄金）。
- 参考实现对照表见 `native-reference-map.md`（~/projects/libgit2 只读借鉴，
  不进源码树、不搬代码）。

### 1.1.2 双轨绑定架构（2026-08-25 起）

libgit2 声明层是**两条互补轨道**，不是竞争关系：

| 轨道 | 单元 | 加载方式 | 覆盖面 | 验证 |
|---|---|---|---|---|
| 运行时加载系 | ffi + binding + backend | dlopen/dlsym（platform.dl），零链接依赖 | 手写子集，按需增长 | test_git 20 测全绿（真库跑 commit/diff/blame/revwalk/config） |
| 静态声明系 | bindings | external 'c'（构建期 -lgit2 / soname 直链） | 全量 876 函数 + 全部类型/宏（c2pas888 自动生成） | test_bindings 5 测全绿（gcc 探针 sizeof/offsetof 黄金对照 + 运行时版本实证） |

- 默认消费路径是运行时加载系；静态声明系服务需要完整 ABI 面
  （如绑定生成器、ABI 审计、未来静态链接发行形态）的场景。
- 选择层默认仍走 libgit2：`nextpas.core.git.factory.NewGitManager(gbAuto)` 首版等价 `gbLibGit2`，存量 `uses nextpas.core.git; NewGitManager;` 零改动；纯路径需显式 `gbNative` 或直连 `native.manager`（见 PURE-BACKEND.md §2-§3 迁移公告）。
- 两套符号词汇不同（运行时系 C 风格 `git_oid`，静态系 Pascal 风格
  `TGitOid`），**不做名字统一**；任何一侧的增补以各自 gate 为准。
- 再生成与坑清单见 `bindings-pitfalls.md`。

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
  function Path: string;
  function WorkDir: string;
  function IsBare: Boolean;
  function IsEmpty: Boolean;
  function Head: IGitReference;
  function CurrentBranch: string;
  function ListBranches(Kind: TGitBranchKind = gbLocal): TStringArray;
  function CommitByHash(const Hash: string): IGitCommit;
  function HeadCommit: IGitCommit;
  function Remote(const Name: string = 'origin'): IGitRemote;
  function Fetch(const RemoteName: string = 'origin'): Boolean;
  function CheckoutBranch(const Branch: string): Boolean;
  function CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;
  // 兼容旧接口：简单清单
  function Status: TStringArray;
  // 详细状态与过滤（含 StatusEntries: TGitStatusEntryArray）
  function StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
  function IsClean: Boolean;
  function HasUncommittedChanges: Boolean;
end;
// 扩展操作见 IGitRepositoryExt: ListRemotes / PullFastForward / Diff(+Ex) /
// DiffWorkingTree(+Ex) / RevWalk / Blame / ConfigEntries / ApplyPatch /
// CheckoutPaths / WorkdirPatchText（保持二进制兼容，独立接口）

IGitCommit = interface
  function Message: string;
  function ShortMessage: string;
  function AuthorString: string;
  function CommitterString: string;
  function Time: TDateTime;
  function ParentCount: Integer;
  function OIDString: string;
  function ParentOIDString(AIndex: Integer): string;
end;
```

选择层（`nextpas.core.git.factory`，唯一跨轨汇聚点）：

```pascal
type
  TGitBackend = (gbNative, gbLibGit2, gbAuto);
function NewGitManager(ABackend: TGitBackend = gbAuto): IGitManager;
```

| 枚举 | 语义 | 首版行为 |
|------|------|----------|
| `gbNative` | 创建 `TNativeGitManager`，仅依赖 `native.*`，零 libgit2；未实现方法抛 `EGitError('not implemented for native backend: <Method>')` | 纯路径 |
| `gbLibGit2` | 创建 `TLibGit2Manager`，经 `platform.dl` 的 `dlopen/dlsym` 运行时加载 `libgit2` | 兼容路径 |
| `gbAuto` | 策略别名，首版恒等于 `gbLibGit2`，下版本切 `gbNative` 前发迁移公告 | 默认兼容，详见 `PURE-BACKEND.md` §3 |

门面保留无参重载以兼容存量：`nextpas.core.git.NewGitManager` inline 转发 `factory.NewGitManager(gbAuto)`，语义与重构前一致；纯消费显式传 `gbNative` 或直连 `nextpas.core.git.native.manager.TNativeGitManager.Create`。

### 1.3 核心类型

```pascal
TGitStatusEntry = record
  Path: string;
  Flags: TGitStatusFlags;
end;
TGitStatusEntryArray = array of TGitStatusEntry;
```

---

## 2. 不变量

- IGitRepository 拥有 libgit2 仓库句柄（接口引用计数自动释放，无显式 Close；历史 `Close` 已移除，析构见 `TGitRepositoryImpl.Destroy` / `TNativeRepository.Destroy`）
- Commit ID 为 40 字符十六进制字符串（`OIDString` / `ParentOIDString`，非法抛 `EGitError`）
- **[INV-O1] Ownership 单一所有者**：`TNativeRepository` 独占 `objects/pack/*.pack` 的 `IMappedFile` 句柄（`TPackFile.FMapped: IMappedFile`，`PByte+Size` 零拷贝视图），析构时 `Free` 全部 packs；`IMappedFile` 引用计数归仓，禁止拷贝共享。`WriteAtomic`/`GitWriteIndex` 临时文件句柄由调用帧 `try..finally` 保证释放。`TBytes` 读取结果所有权移交调用方（调用方持有，零拷贝 `PByte+Len` 变体不拥有内存，需在 `TPackFile` 生命周期内使用）。
- **[INV-O2] Exactly-once 单次交付**：`revwalk` 每提交恰一次 `ReadObject+Parse`（发射零重复开销，`seen` 入队时标记）；`GitZlibDecompress*` 每 zlib 流恰一次 inflate（`AEndPos` 精确边界，无重读）；`status/rename` 每路径恰一次归并（porcelain 分组序，conflict 跳过 rename）。重复调用不产生重复副作用。
- **[INV-O3] 单源复用**：`ignore/attributes` 通配一律委托 `git.native.wildmatch`（`GitWildSegment*`/`GitSegmentsMatch`，inline 热路径）；`Adler-32` 一律委托 `nextpas.core.checksum.adler32`（`Adler32Update`/`Adler32OfBytes`，`ADLER32_INIT/MOD/NMAX` 单源，`PByte+Len` 零拷贝）；`Span/Bytes` 比较一律委托 `nextpas.core.bytes.ops`（`SpanEqual/SpanCompare` 等，`bytes.ops` 单源）；`zlib` 一律委托 `nextpas.core.compress`（`Deflate*`/`CreateDeflateReaderEmbedded`）。禁止手写重复循环。
- **[INV-O4] 新增行为不变式**：`DiscoverRepository(const AStartPath: string): string` 纯查询无副作用，`AStartPath=''` 或不可达返回 `''`（不抛），逐级上溯寻 `.git` 目录、命中 worktree 时解析 `.git` 文件 `gitdir: <path>` 返回 worktree 根，`PathClean` 规范绝对路径；`CloneRepository(const AURL,ALocalPath: string): IGitRepository` 成功返回非空句柄且落盘为有效仓（`HEAD`/`config`/`objects/pack`），失败不留半仓且抛 `EGitError`（native 抛 `not implemented`）；`CommitOnHead(const AMessage,AAuthorName,AAuthorEmail: string): string` 要求 `AMessage<>''` 否则 `EGitError(GIT_EINVALID)`，`index→write_tree→lookup_tree→signature→commit_create(HEAD)` 全链 `try/finally` 释放句柄，成功返回 40-hex OID；`AddWorktree(const AName,APath,ARef: string; ADetach: Boolean): IGitWorktree` 要求 `AName<>''且APath<>''` 否则 `EGitError(GIT_EINVALIDSPEC)`，同名抛 `EGitError`，创建 `worktrees/<id>/commondir+gitdir+HEAD`，`PruneWorktree` 仅清元数据不删工作区；`SetVerifySSL(AEnabled: Boolean)`/`VerifySSL` 为 Manager 粒度标志默认 `True`（`FVerifySSL`），仅影响后续网络操作（Clone/Fetch/Push 的 `http.sslVerify`），同 Manager 可见跨 Manager 不共享

---

## 3. 错误处理

- 仓库不存在抛 `EGitError`
- libgit2 错误抛 `EGitError`（含错误码）
- **[INV-E1] 异常不丢**：所有 `EIOError` → `EGitError` 映射保留 `EGitError` 原样 `raise`（`on E: EGitError do raise`），其余异常包装为 `EGitError` 且不吞栈；`TPackFile/LoadPacks/Index` 解析失败经 `try..finally/try..except` 释放已分配句柄/内存后重抛，确保 `EGitError` 不丢失且资源不泄漏。
- **[INV-E2] 新增行为错误契约**：`DiscoverRepository` 返回 `''` 不抛（空串与不可达均空）；`CloneRepository` 失败抛 `EGitError` 含 `git_clone` 错误码（native 抛 `EGitError('not implemented for native backend: CloneRepository')`）；`CommitOnHead` 空消息 `EGitError(GIT_EINVALID,'message required')`，`index/tree/signature/commit_create` 任一步 `rc<>GIT_OK` 抛 `EGitError(rc,'<step> failed')` 且 `try/finally` 释放 `git_index/git_tree/git_signature/git_commit`；`AddWorktree/LookupWorktree` 参数缺失 `EGitError(GIT_EINVALIDSPEC)`，底层 `git_worktree_*` 非 `GIT_OK` 抛 `EGitError(rc,'<op> failed')`，`ListWorktrees` 失败抛 `EGitError` 且 `git_strarray_free` 保证释放；`SetVerifySSL/SetCredential*` 未接线时传入非空处理器抛 `EGitError(GIT_EUSER/'not supported')` 而非静默忽略；`GitOidIsValidHex` 失败抛 `EGitError` 不返回哨兵，`inline` 零拷贝路径亦不掩盖错误

---

## 4. 线程安全

- `IGitManager` 线程安全：`Initialize/Finalize/IsRepository/DiscoverRepository/CloneRepository/GetGlobalConfig/SetGlobalConfig/SetVerifySSL/VerifySSL/Version` 均可在任意线程并发调用；`Finalize` 延迟释放（`FActiveHandles>0` 时置 `FFinalizeRequested`，`ReleaseHandle` 归零后自动 `Finalize`），`CloneRepository` 内部串行化 `git_clone` 且异常不破坏 Manager 状态
- `IGitRepository` / `IGitRepositoryExt` / `IGitWorktreeExt` 非线程安全：`Status/Head/CommitByHash/Diff/RevWalk/Blame/ConfigEntries/ApplyPatch/CheckoutPaths/WorkdirPatchText/AddWorktree/CommitOnHead/PruneWorktree` 均需外部互斥，mmap `PByte` 零拷贝视图调用方同步
- `SetVerifySSL` / `VerifySSL` 原子可见：`FVerifySSL` 为 Manager 私有字段，`SetVerifySSL` 写入后 `VerifySSL` 立即可见（libgit2 额外同步 `git_config_set_string(http.sslVerify)`），跨线程以最后写入为准，不保证跨 Manager 一致性
- `DiscoverRepository` 纯读无锁：仅读文件系统与 `.git` 文件，不改 Manager 状态，可与 `CloneRepository` 并发但结果取决于文件系统时序
- `CommitOnHead` / `AddWorktree` 非线程安全且不可重入：依赖 `git_index` / `git_worktree` 句柄，调用期间禁止同仓并发
- 文档与门禁约束：`CONTRACT.md` 本节与 `scripts/git-contract-check.sh` C5 共同作为线程安全契约门禁，新增 Manager/Repository 方法必须在此节声明线程模型

---

## 5. 内存管理

- IGitRepository 由接口引用计数释放 libgit2 资源（无显式 Close，异常路径亦经 `EGitError` 保障释放；`TGitRepositoryImpl.Destroy` 释放 `FRepo` 并 `ReleaseHandle`，`TNativeRepository.Destroy` 释放 `FPacks`）
- IGitManager.Initialize/Finalize 拥有 libgit2 全局状态（`Initialized`/`VerifySSL` 查询；`TGitManagerImpl` 以 `FActiveHandles` 计数延迟 Finalize，杜绝句柄泄漏）
- **[INV-M1] 资源释放**：`TPackFile.Create` 失败时已分配 `IMappedFile` 随实例析构释放；`TNativeRepository.LoadPacks` 批内异常回滚已建 packs（`try..except Free`）；`Deflate/Gzip` 流的 `inflateEnd/deflateEnd` 在 `try..finally`/`destructor` 中释放；`WriteAtomic` 先写临时文件后原子 rename，异常不留残余。
- **[INV-M2] Heaptrc 零泄漏**：`test_git_native`（≈114）/`test_git`/`test_git_bindings` 全门以 `-gh` 编译，`HEAPTRC=haltonnotreleased,log` 双 pin（dump 存在 + `0 unfreed memory blocks`）为硬门禁；`make focused FOCUS=core/tests/nextpas.core.git/test_git_native` 必须通过。
- **[INV-M3] 性能 inline/零拷贝**：`GitOidIsValidHex/GitOidSame/GitKindFromMode/GitZlibAdler32(PByte)` 等热路径 `inline`；`GitZlibDecompressPtr`/`Adler32Update(AData: PByte; ALen: SizeUInt)` 为 `Pointer+Len` 零拷贝（`TByteSpan` 视图），`SpanEqual/BytesEqual` 复用 `bytes.ops` 的 `MemEqual/CompareBytesOrdered` 零分配路径；证据见 `bytes.ops` 单源与 `bench`。
- **[INV-M4] 新增行为内存契约**：`CloneRepository` 成功句柄由 `TGitRepositoryImpl` 接管（`FRepo.Free`+`ReleaseHandle`），失败无句柄泄漏；`AddWorktree` 返回 `TGitWorktreeImpl` 持有 `git_worktree`（`git_worktree_add` 句柄故意不 `git_worktree_free` 规避 libgit2 1.9 double-free，随仓释放，见 libgit2.pas 注释）；`CommitOnHead` 全量 `try/finally` 配对释放 `git_index/git_tree/git_commit/git_signature/git_reference`，异常路径亦释放且 `EGitError` 不丢；`ListWorktrees/PullFastForward` 等 `git_strarray/git_diff/git_revwalk` 均 `try/finally` 释放，`StatusEntries` 的 `New(Dispose)` 列表异常时逐项 `Dispose`

---

## 6. 测试覆盖

| 测试集 | 覆盖 |
|--------|------|
| `test_git` | Status/Head/CommitByHash+HeadCommit/Init/IsRepository/Discover/RevWalk/Diff/Blame/Config 等（libgit2 真库，20+ 用例，对齐 IGitCommit.OIDString/AuthorString/Time: TDateTime） |
| `test_git_bindings` | 静态声明系 ABI 黄金对照（5 用例，gcc 探针 sizeof/offsetof + 运行时版本实证） |
| `test_git_native` | native 子家族对象层/refs/status/revwalk 等（零 libgit2） |
| `test_git_pure_manager` | 纯门面 5 用例，零 libgit2（Init/StatusEmpty/StatusWithFile/HeadAndLookup/FactoryGbAutoCompat，经 `factory.NewGitManager(gbNative)`，C4 门禁：grep 零命中 + `fpc -va Loading libgit2` 双重闭环） |

门禁：`scripts/git-contract-check.sh` C4 已闭环（`fpc -va Loading.*libgit2` 实检 + `grep` 零命中）；`build/verify_local.sh` 后续聚合 `git-contract-check`，以 `CONTRACT.md` 本节与 `PURE-BACKEND.md` §5 为准。
