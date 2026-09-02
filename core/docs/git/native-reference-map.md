# git.native 参考实现借鉴地图

**参考源码**：`~/projects/libgit2`（浅克隆，仅作只读参考）
**用途**：为 `nextpas.core.git.native.*` 的后续切片提供格式与算法对照。
**最后更新**：2026-08-29
**版本**: 2.0（与 `CONTRACT.md` 版本体系对齐）

## 借鉴纪律

- 只借鉴**格式规范、算法思路、边界条件清单**；不逐行搬运代码。
- libgit2 为 GPLv2（含链接例外），逐行翻译会污染 nextPas 的许可立场；
  一切实现以 git 官方格式文档 + 本仓库设计规范为准，libgit2 仅当"活的规格书"。
- 参考目录在 `~/projects` 下，永不进入本仓库源码树或构建路径。

## 已完成切片 ↔ 参考位置

| native 子模块 | libgit2 参考位置 | 备注 |
|---|---|---|
| native.pack（idx v2 解析） | `src/libgit2/pack.c`（`pack_index_find` 等） | 大偏移表/CRC 表布局对照 |
| native.pack（delta 应用） | `src/libgit2/delta.c`（`git_delta_apply`） | copy/insert 指令边界条件可逐条核对 |
| native.refs（packed-refs） | `src/libgit2/refs/packed_backend.c` | peeled 行、排序假设 |
| native.objmodel（commit/tree） | `src/libgit2/commit.c` / `tree.c` 的 parse_raw 系列 | 头部续行（gpgsig）处理 |
| native.write（tree 排序） | `tree.c`（`entry_sort_cmp`）+ `util/fs_path.c` | tie point 目录视作 `name+'/'` |
| native.write（mode 渲染） | `tree.c`（`write_tree`, `%o` 格式化） | 无前导零：目录是 `40000` 不是 `040000` |
| native.write（签名行） | `signature.c`（`git_signature__writebuf`） | `%u ±HHMM`，负偏移取绝对值加符号位 |
| native.write（blob 写入） | `object_api`/odb 写侧（`git_hash_object` 语义） | `"<kind> <size>\0"` 头 + SHA-1；空内容与含 NUL 二进制都要对 `git hash-object` 黄金对照 |
| objmodel/write（tag 解析+构造） | `src/libgit2/tag.c: parse_tag_buffer` / `mktag` fsck 语义 | object/type/tag 三头必需且顺序固定，tagger 可缺省；嵌套 tag（type tag）合法；消息体含内嵌 PGP 签名无需特殊头处理；对象末字节必须是 LF——builder 拒绝非规范消息 |
| native.index（DIRC 解析+序列化） | `read-cache.c: create_from_disk` / `expand_name_field` / `ce_write_entry` | v2/v3 定长头+padding 公式 `(fixed+len+8)&~7`（至少 1 个 NUL）；v4 前缀压缩用 pack OFS 同款偏移 varint 且无 padding、但保留 v3 扩展 flags 字——漏读会整段错位；namelen 字段 ≥4095 时钳制为 \$FFF（掩码会静默截断）；小写强制扩展（link/sdir）必须拒绝而非跳过；序列化不生成任何扩展区（git 会按需重建缓存） |
| native.status（worktree 聚合） | `status.c` / `diff-lib.c`（stat 快路径语义） | typechange 是模式类别翻转（regular↔symlink↔gitlink），exec 位变化只是 modify——用 Kind 枚举比较会把两者混同；干净文件靠 size+纳秒 mtime 匹配免哈希（对齐 git cached-stat）；冲突路径多阶段相邻、只报一次且必须推进 HEAD 游标否则误报 staged-deleted；untracked 扫描自递归 ReadDir 并剪 .git（fs 的 Walk 回调无法按目录剪枝） |
| native.revwalk（日期序遍历） | `revision.c`（默认 date-order 优先队列语义） | 排序键是 committer date；队列条目在入队时预取父列表——每提交恰一次 read+parse，发射零重复开销；seen 集合在入队时标记防重复入队；FPC 托管类型函数 Result 进入时不保证清空——累积型返回数组必须显式 `Result := nil`，否则跨调用串结果（黄金对照抓到的真 bug） |
| native.revwalk（topo 序） | `revision.c: sort_in_topological_order` + `prio-queue.c` | git 默认 topo 排序是 REV_SORT_IN_GRAPH_ORDER：就绪集是 **LIFO 栈**（prio_queue compare=NULL 时 get 取 `array[--nr]`），不是日期优先堆——merge 的父列表按序入栈导致**后列父提交先发射**（黄金对照推翻"最新就绪优先"假设）；只有初始 tips 按 limit_list 日期降序播种；入度=集合内子节点数，归零才入栈；实现为三阶段：可达集收集（每提交恰一次 parse）→ 子计数 → 栈发射 |
| native.revwalk（first-parent / hide / boundary / 日期裁剪） | `revision.c`（`--first-parent` / `add_pending_object --not` / `--boundary` / `since/before`） | first-parent 仅跟首父遍历；hide 经 `BuildHiddenSet` 广度遍历排除 Hides 及其全祖先，ShowBoundary 时收集被隐藏的紧邻父为边界（末尾以发现序追加，`git rev-list --boundary` 前缀 `-`）；since/until 以 committer date 为键（0 为无界），仅过滤发射仍继续遍历父链，MaxCount 仅计非边界发射；日期序与 topo 序两条路径均以 `git rev-list` 为黄金对照 |
| native.ignore（.gitignore 引擎） | `dir.c`（last_matching_pattern / prep_exclude）+ `wildmatch.c` | 通配回溯的经典边界：星号吸收到**最后一个字符**后仍须允许重试终态（守卫写成 `< Length` 会把 `temp*` vs `temporary.txt` 判成不匹配，探针对比黄金抓到）；porcelain 输出是**分组序**——tracked 轴条目按路径排完再接 untracked 组，不是全局字母序（旧 fixture 路径恰好同序掩盖了归并实现，新 fixture 的 `.gitignore` < `tracked.log` 暴露）；父目录被忽略时负规则无法复活子路径是**遍历结构性规则**（引擎不管，扫描器剪枝即得）；`*`/`?` 不跨 `/`，`**` 只按整段消费；已支持 .git/info/exclude + `core.excludesFile` 全局排除（含 `~/` 展开） |
| native.cachetree + index（TREE 扩展） | `cache-tree.c: read_one/write_one` + `tree-walk.c` | 文档记忆 vs 实证字节：**根记录同样带名字段**（空名 = 裸 NUL），语法是 `<name> NUL <count> ' ' <count> LF [oid] children…`——凭"root 不带名"的印象写解析器直接撞 NUL，hexdump 一查即中；entry_count<0 哨兵表示失效缓存且不跟 oid；扩展块位于条目之后校验和之前，拼接后必须重算 SHA-1；构建器复用 tree 规范排序+序列化+GitHashObject 逐层哈希，黄金对照 `git write-tree`；字节级回环测试证明序列化与 git 完全一致；FPC 允许 record 内自引用动态数组（晚绑定指针），无需 PGitCacheTree 前向指针方案 |
| native.status（rename/copy 检测） | `diff_tform.c: git_diff_find_similar` + `hashsig.c` + `diffcore-rename.c` | oid 同值即 100 快路径免读 blob；否则 hashsig 行哈希（SMART 空白、ALLOW_SMALL_FILES、80 字节截断、min/max 堆、overlap 评分 `100*2*matches/(a+b)`）落分于 0..100；阈值 50 下的 deleted/added（仅 blob）贪心最高分先配，一次配对；status 的 rename 只看 HEAD→index 暂存轴（index→worktree 的删增是 `D`+`??`，git status 不跨轴配对——探针实证）；porcelain 分组序归并时 rename 条目以 dest 路径参与 tracked 轴排序；与 `git status --porcelain=v1 -M` 黄金对照，排序、相似度、source/dest、阈值皆实证 |
| native.commitgraph（commit-graph v1 读写+校验+缓存） | `commit_graph.c`（`git_commit_graph_file_parse` / `git_commit_graph_write` / `git_commit_graph_verify` / `git_commit_graph_entry_find`） | CGPH v1 头 + chunk TOC 绝对偏移 + SHA-1 尾校验；OIDF 256*4 fanout 单调、OIDL 单调、CDAT 36B/条、EDGE 溢出链（高位 `0x80000000` 为末标记）；generation 低 2 位为 commit_time 高位（`gen>>=2`）；extra edge 链跨条累加父链，octopus 3+ 父通过 EDGE 二级索引；fanout 二分 + commit-data 直读，零 inflate 命中时 revwalk 免 parse；写侧 `BuildGraphBytes` 按 OID 排序构建 fanout/OIDL/CDAT(+EDGE) 3 块 + 尾 SHA-1（`WriteAll` 聚合 `refs/heads+HEAD+tags` 起止经 `GitCollectCommits` 闭合），`Write*` 经 `WriteAtomic` 原子落盘 + 内存/文件双重 `Verify` 校验，`TryLoad` 经 `Stat.mtime+size` 缓存 `IMappedFile` 零堆复制 `MmapOpen`（`Cap=16` 8→16 半减多仓 thrash，`PByte` 零拷贝 via `io.mapped`，`bytes.ops` 单源，OS page-reclaimable，`inline` O(1) Seq touch + O(Cap) victim 扫描 trivial 16×UInt64 <30ns 无线性搬移/接口拷贝抖动，波动门禁见 CONTRACT.history.md §3），对齐 `git commit-graph write/verify` 实盘文件 |
| native.reflog | `reflog.c` / `refs.c`（`git_reflog_read` / `git_reference_create`） | `logs/<ref>` 文本，每行 `old(40) ' ' new(40) ' ' <Name> ' <' <Email> '>' ' ' <UnixTime> ' ' <TZ> #9 <Message> LF`；签名段复用 `GitParseSignature`，缺失文件回空数组（非错误），腐败行抛 `EGitError`；黄金对照 `git reflog --format=%H` 与 `git log -g --format` |
| native.stash | `stash.c`（`git_stash_list` / `git_stash_save` / `git_stash_apply/drop/clear` / `git_reflog` for `refs/stash`） | 复用 reflog 解析：`logs/refs/stash` 反序 `newest-first` 即 `stash@{0}` 语义；`GitStashPush` 原生入栈：index/working 树递归 `WriteTree`→`GitWriteCommit`（`[HEAD]`/`[HEAD,index]` 父链，`On <branch>: msg`）→`logs/refs/stash` append `old new sig TAB msg`→`refs/stash`→`checkout` 回 HEAD；`Apply` 为 `checkout` 目标树，`Drop/Clear` 精确重写 reflog 与 refs，`Pop=Apply+Drop`，对齐 `git stash push/pop/apply/drop/clear` 黄金（`list`/`rev-parse stash@{N}`/`status`/`show` 互通） |
| native.notes | `notes.c` / `notes.h`（`git_notes_*` / `refs/notes/commits`） | `refs/notes/*` 是 commit 其 tree 为 `target-hex→blob` 映射；写侧 flat 排序 `GitWriteTree`（`100644 <hex>`），读侧递归 `CollectNotesRecursive` 透明吃 `xx/yy` 两级 fanout（`aprefix+name` 去斜杠后 40-hex）；签名复用 config→HEAD committer→fallback，空树时移除 ref，对齐 `git notes add/show/list/remove` 黄金（双向互通） |
| native.branch | `refs.c` / `refs/heads.c`（`git_branch_*` / `git_reference_list`） | `refs/heads/*` 递归扫描 + `packed-refs` 前缀归并（loose 优先、字典序），`HEAD symref` 跟踪当前分支/游离态，创建写 loose 并保空目录、`delete` 同步清 `packed-refs`（含 peeled），`rename` 复用 create+HEAD 跟随+delete，对齐 `git branch --list/create/delete/move` 黄金（排序、嵌套 `a/b`、pack 后删除、当前分支保护、无效名拦截） |
| native.tag | `refs.c` / `tag.c`（`git_tag_*` / `git_reference_list`） | `refs/tags/*` 递归扫描 + `packed-refs ^` peeled 归并（loose 优先、字典序），轻量直接写 oid、附注经 `GitTagBuilder`/`GitWriteTag` 生成 tag 对象（自动探测 `targetKind`、签名取 config→fallback），`TryPeelTag` 递归剥离嵌套 tag，对齐 `git tag --list/create/delete` 黄金（轻量/附注互通、斜杠名、pack 后删除、重命名、非法名拦截） |
| native.log | `revwalk.c` / `commit.c` / `revision.c`（`git_log` / `git_revwalk`） | `HEAD/branch/tag/~` 经 `rev-parse` 解析后 `PeelToCommit`，`GitCollectCommits` date 序聚合 + `GitParseCommit` 首行消息、`ShortOid(7)`、`Author/Committer`，`oneline` 复用 `ShortOid+" "+Message`，对齐 `git log --oneline --no-decorate` 黄金（MaxCount、~ 语法、tag 剥离、body 截断） |
| native.describe | `describe.c` / `refs.c`（`git_describe`） | `GitTagList` 过滤（默认仅附注）+ `PeelToCommit` 起点，BFS 最短路径 `Head→parents`（`TGitOidSet` 去重、队列 `Dist+1`），首个命中标签即 `tag` 或 `tag-距离-gShort`，`--tags` 复用轻量，对齐 `git describe` / `git describe --tags` 黄金（`HEAD~`、`vX-距离-g`、轻量忽略） |
| native.diff | `diff.c` / `diff_tree.c`（`git_diff_tree_to_tree` / `diff --name-status`） | 递归扁平化（`$4000` 目录 + `aprefix/name`）+ 字典排序 + 双指针归并，peel `commit/tag→tree` 16 层，TypeChanged 以 `FileTypeCategory`（regular/exec/symlink/gitlink）判定，对齐 `git diff --name-status` 黄金（Added/Modified/Deleted/TypeChanged，零重命名，空树零值短路） |
| native.blame | `blame.c` / `blame_git.c`（`git_blame_file` / `blame --porcelain`） | 线性历史 `revwalk` + 树内 `FindBlobOid` + `SplitLines(CRLF)` + LCS Hirschberg `O(n*m)` vs 回退 `O(N log N+M log U)` 1M阈值（bench基线：1k×1k ~3ms Hirschberg精确LCS vs ~0.8ms哈希回退，3k×3k回退5×更快，避免`C*n*m`放大，LcsForwardReuse零拷贝swap消除`Move`双缓冲`O(m)`，复用`bytes.ops GrowArrayCapacity`单源，`not inline`守I-Cache） + head-vs-each最老匹配+blob-cache零重复LCS，对齐 `git blame --porcelain` 黄金（行号/短oid/author/time，空文件零行，缺失路径抛错） |
| native.mergebase | `merge_base.c` / `commit.c`（`git_merge_base` / `merge-base`） | A 祖先集 `TGitOidSet` 全量 + B BFS 最短命中，tag 剥离 16 层，`merge-base --all` 的单命中近似，多提交折叠，对齐 `git merge-base` 黄金（分支分叉/线性/相同提交） |
| native.show | `show.c` / `log.c` + `diff_tree.c`（`git show` / `log --oneline + diff`） | `RevParse→Peel` + `BuildLogEntry` + 首父树 `GitDiffTrees/NameStatus/Stat`，根空树零值，merge 首父近似，对齐 `git show --name-status` 黄金（根/普通/合并、tag 剥离） |
| native.shortlog | `shortlog.c` / `revision.c`（`git shortlog` / `shortlog -s -n`） | `RevParse→Peel` + `revwalk` 全量 + `Author Name+Email` 分组 + 计数降序/姓名升序，对齐 `git shortlog -s -n` 黄金（多作者/单作者/MaxCount） |
| native.catfile | `cat-file.c` / `object.c`（`git cat-file` / `cat-file -t/-s/-p`） | `TNativeRepository` 聚合读取（loose+pack），`PrettyTree` 经 `write.GitModeToString`，`type/size/pretty` 三重载，对齐 `git cat-file -t/-s/-p` 黄金（commit/blob/tree/tag/带剥离） |
| native.lsfiles | `ls-files.c` / `read-cache.c`（`git ls-files` / `ls-files --stage`） | `GitReadIndex` 直读（DIRC v2/v3/v4），`cached` 路径列表 + `stage` 详表 `mode oid stage<TAB>path`，排序与可执行位保留，对齐 `git ls-files` / `git ls-files --stage` 黄金（排序/可执行/嵌套目录） |
| native.cherrypick | `cherry-pick.c` / `sequencer.c` | 首父 diff 扁平应用 + 递归树构建 + `(cherry picked from commit …)` trailer + `checkout`，对齐 `git cherry-pick`（root 空树、Added/Modified/Deleted/TypeChanged、分支/游离 HEAD） |
| native.revert | `revert.c` / `sequencer.c` | 逆向首父 diff `Target→Parent` 扁平应用 + 递归建树 + `Revert "<subject>"` + `This reverts commit <oid>.` + `checkout`，对齐 `git revert`（逆向 Added/Modified/Deleted/TypeChanged、分支/游离 HEAD、root 空树） |
| native.archive | `archive.c` / `archive.h` | 树扁平化 → USTAR `tar`（512 字节头 + 内容 512 对齐 + `1024` 零块；`0644/0755/2` 符号链接，gitlink 跳过），对齐 `git archive --format=tar` |
| native.submodule | `submodule.c`（`git_submodule_*` / `submodule-config.c`） | `[submodule "name"] path/url/branch` INI 解析（Trim/引号转义/注释剥离），worktree `.gitmodules` 优先、HEAD 回退，`HEAD~` 等 rev 经 `rev-parse` 剥离，对齐 `git config -f .gitmodules --list` |
| native.mailmap | `mailmap.c` / `mailmap.h`（`git_mailmap_*`） | `.mailmap` 行解析（`[proper] [<proper>] [commit] [<commit>]`，`<>` 邮件、`#` 注释、大小写折叠），worktree `.mailmap` 优先、HEAD 回退，`HEAD~` 剥离，对齐 `git check-mailmap` |
| native.trailer | `trailer.c`（`git_trailer_*` / `interpret-trailers.c`） | `Key: Value` 尾块解析（末尾空行后连续 `:` 行，`Has/Find/Format/Append`，大小写折叠），对齐 `git interpret-trailers --parse/--trailer` |
| native.attributes | `attr.c`（`git_attr_*` / `attr.c`） | `.gitattributes` 行解析（`pattern attr`，`set/-unset/value`，`*`/`?`/`**`，last-match-wins），`HEAD` 回退，对齐 `git check-attr` |
| native.worktree | `worktree.c`（`git_worktree_list` / `refs/worktree`） | `worktrees/<id>/commondir+gitdir+HEAD` 布局，`commondir` 相对 `../..`、`gitdir` 绝对、`HEAD` 为 `ref:` 或 detached oid；`Add` 创建分支/游离并 `checkout` 物化，`Remove` 清理（含 `Force`）；黄金对照 `git worktree add/list/remove --porcelain`；`checkout` 对 `commondir` 透明（`EffectiveGitDir`） |
| native.config | `config.c`（`git_config_parse` / `config_file.c`） | INI 风格 `[section]`/`[section "subsection"]`，引号转义，大小写折叠，`--get/--get-all/--get-bool` 语义；黄金对照 `git config --list/--get/--get-all` |
| native.pktline | `transports/smart_pkt.c`（`git_pkt_parse_line` / `pkt-len`） | 4-hex 长度含头、`0000` flush / `0001` delim / 0004 禁空、65535 上限、hex 校验与截断检测；`Scan`/`Join` 流式；为 fetch 协议打底 |
| native.advertise | `transports/smart_protocol.c`（`ref discovery / ls-remote`） + `protocol-common.txt` | `oid SP ref [NUL caps] LF` 首行能力表、`flush` 终止、`delim` 兼容、`^{}` peeled 视普通 ref、合成与 `upload-pack --advertise-refs` 黄金对照 |
| native.negotiate | `transports/smart_pkt.c`（`ACK/NAK` + `want/have/done`） + `fetch-pack.c` | `want <oid> [caps] LF` 首 want 带 caps、`have <oid> LF`、`done LF` 均为 pkt-line，`ACK <oid> [continue/common/ready]` / `NAK` 解析，流式 `flush` 终止，合成与 libgit2 `git_pkt_buffer_wants/have/done` 语义一致 |
| native.sideband | `transports/smart_pkt.c`（`sideband_progress_pkt / sideband_error_pkt / data_pkt`） + `pack-protocol.txt` § side-band | `chr(1) pack` / `chr(2) progress` / `chr(3) error` 多路复用，`flush` 终止，`DataBytes` 二进制保 NUL 拼接、`Progress/Errors` 文本数组，`Join`/`Demux` 互逆 |
| native.indexer | `indexer.c`（`git_indexer_append/commit`） + `pack.c`（idx v2 布局） + `Documentation/technical/pack-format.txt` | `PACK` 头×2 + 对象数，逐条：varint 头（type+size）+ OFS 偏移 varint / REF 20B + zlib 流，CRC-32 覆盖 `header..zlib` 原字节，OFS/REF delta 以已解压前缀为基、SHA-1 求 oid，oid 排序+fanout 256 累积+BE32/64 偏移（`0x80000000` 大表）、pack/index 双 SHA-1，对齐 `git index-pack` / `git verify-pack` |
| native.clone | `clone.c`（`git_clone`） + `remote.c` + `transport_local.c` | `upload-pack --advertise-refs` 公告去重 want → `fetch` 整包 → `pack-<hash>.pack/.idx` 落盘（`GitPackIndexPath` 命名）+ `refs/*` 逐文件 + `HEAD symref`（`symref=HEAD:` caps）+ `config`（bare/remote），与 `git clone --bare` 黄金对照；`GitClone` 复用 `checkout` 完成 worktree 物化 |
| native.checkout | `checkout.c` + `unpack-trees.c`（`git_checkout_tree` / `read-tree -u`） | 任意 tree/commit/ref → worktree 递归物化（`0100644/0100755/0120000/040000/0160000`），类型翻转与孤儿裁剪（file↔dir↔symlink↔gitlink）、可执行位与 symlink 目标保留、v2 index 落盘，对齐 `git checkout` / `git read-tree --reset -u` 黄金 |
| native.push | `send-pack.c` / `push.c` + `transport/smart_pkt.c`（`receive-pack`） | `receive-pack --stateless-rpc` 无状态推送，`old new ref NUL caps` + flush + `pack-objects --revs --delta-base-offset` 打包，对齐 `git push` / `git send-pack`；`report-status` 解析 `unpack ok`/`ok`/`ng`，支持创建(零旧)/删除(零新)/多 ref、stale-old 拒绝，对齐 `git receive-pack` 黄金 |
| native.reset | `reset.c` + `checkout.c` + `refs.c`（`git reset --hard`） | 复用 `checkout` 的树物化 + 孤儿裁剪 + v2 index，剥离 tag 至提交后更新当前分支或游离 HEAD；支持 `oid`/`ref`/`HEAD~N` 等 rev（`git rev-parse` 回退），对齐 `git reset --hard` / `read-tree --reset -u` 黄金 |
| native.prune | `remote.c` + `refs.c`（`git remote prune` / `fetch --prune`） | `refs/heads/*→refs/remotes/<name>/*` 映射，对比 `ls-remote` 公告与本地 `refs/remotes` 树裁剪 stale 分支，嵌套分支 `a/b` 空目录回溯清理，`HEAD` symref 失效删除或重建，对齐 `git remote prune` 黄金 |
| native.clean | `clean.c` + `dir.c`（`git clean` / `gitignore`） | `git clean -f/-d/-x/-n`，复用 status 的 ignore 链与 index 已追踪集，排序后删除，对齐 `git clean` 黄金 |
| native.revparse | `revision.c` / `refs.c` + `sha1_name.c`（`git rev-parse`） | `HEAD`/`refs/*`/dwim + 40-hex + `~<n>`/`^<n>` 父链 + `^{commit|tree|blob|tag|}` 剥离，对齐 `git rev-parse --verify`，`reset --hard` 已切换为原生首选 |
| native.remote | `remote.c`（`git_remote_create` / `config` remote.*） | `[remote "<name>"]` 分组，`url`/`pushurl`/`fetch` 多值，首 `url` 快捷；黄金对照 `git remote -v` / `git remote get-url` / `git config --get-all` |

## 路线图切片 ↔ 参考入口

| 计划切片 | libgit2 入口 | 规模提示 |
|---|---|---|
| revwalk 增强 | `revision.c`（隐藏/边界、日期裁剪、--first-parent） | 已闭环（first-parent / hide+boundary / since-until 对齐 `git rev-list` 黄金） |
| RevWalk 性能化 | `commit_graph.c` | 已闭环（commit-graph v1 透明加速，命中零 inflate，图谱与对象层交叉黄金对照） |
| 网络（fetch/clone） | `transport/` 目录 + `indexer.c`（收包建 idx） | 已闭环 fetch（`upload-pack --stateless-rpc`）+ bare clone（`advertise→fetch→pack→refs`）+ worktree clone（复用 `checkout`） |
| 检出 | `checkout.c` + `unpack-trees.c` | 已闭环（任意 tree/commit/ref 递归物化，对齐 `git checkout` / `read-tree -u`） |
| 推送 | `send-pack.c` / `receive-pack` | 已闭环（`receive-pack --stateless-rpc` 无状态推送，对齐 `git push` 黄金；创建/快进/删除/多 ref + stale-old 拒绝） |
| 重置 | `reset.c` / `refs.c` | 已闭环（`--hard` 硬重置复用 `checkout`，对齐 `git reset --hard` 黄金；分支移动/游离 HEAD + `rev-parse` 原生链） |
| 裁剪 | `remote.c` / `refs.c` | 已闭环（`remote prune` 陈旧追踪裁剪，对齐 `git remote prune`/`fetch --prune` 黄金；嵌套分支与 HEAD symref） |
| 清理 | `clean.c` / `dir.c` | 已闭环（`git clean -f/-d/-x/-n` untracked 清理 + `core.excludesFile` 全局忽略，对齐 `git clean` 黄金） |
| 解析 | `revision.c` / `sha1_name.c` | 已闭环（`rev-parse` 修订语法 `~`/`^`/`^{}` 剥离，对齐 `git rev-parse --verify` 黄金；消除 `reset` 的 git 回退） |
| reflog | `reflog.c` | 已闭环（`logs/<ref>` 文本解析，对齐 `git reflog` 黄金） |
| stash | `stash.c` | 已闭环（列表基于 `logs/refs/stash` 反序 + 原生 `stash push/pop/apply/drop/clear`：index/working 树→commit→reflog→refs→检出/重写，对齐 `git stash push/pop/apply/drop/clear/list` / `rev-parse stash@{N}` / `status/show` 互通） |
| 笔记 | `notes.c` | 已闭环（`refs/notes/*` flat 写 + fanout 透明读，对齐 `git notes add/show/list/remove` 双向黄金） |
| 分支 | `refs.c` | 已闭环（`refs/heads/*` 列表/当前/创建/删除/重命名，双向黄金 `git branch --list/create/delete/move`，含 packed-refs、嵌套、当前分支保护） |
| 标签 | `tag.c` | 已闭环（`refs/tags/*` 列表/轻量/附注/删除/重命名，双向黄金 `git tag --list/create/delete`，含 packed-refs peeled、斜杠名、嵌套剥离） |
| 日志 | `revwalk.c` / `commit.c` | 已闭环（`HEAD/branch/tag/~` 经 `rev-parse` 剥离，`revwalk` date 序聚合 + 首行/`ShortOid`，双向黄金 `git log --oneline`，含 MaxCount、tag 剥离） |
| 描述 | `describe.c` | 已闭环（`tag` 最近距离 BFS 最短路径 `tag-距离-gShort`，双向黄金 `git describe` / `--tags`，含 `HEAD~`、轻量忽略） |
| 差异 | `diff.c` / `diff_tree.c` | 已闭环（递归扁平化+字典排序+归并，对齐 `git diff --name-status` 黄金；Added/Modified/Deleted/TypeChanged，零重命名，peel 16 层，空树短路） |
| 归因 | `blame.c` | 已闭环（线性历史 LCS + head-vs-each 最老匹配，对齐 `git blame --porcelain` 黄金；行号/短oid/author/time，空文件与缺失处理） |
| 合并基 | `merge_base.c` | 已闭环（A 祖先集 + B BFS 最短命中，多提交折叠，对齐 `git merge-base` 黄金；分支分叉/线性/相同） |
| 展示 | `show.c` | 已闭环（log 聚合 + 首父 diff + name-status/stat，根空树/首父，对齐 `git show --name-status` 黄金；标签剥离合并首父） |
| 简志 | `shortlog.c` | 已闭环（Author 分组 + 计数降序/姓名升序，对齐 `git shortlog -s -n` 黄金；多作者/MaxCount/标签剥离） |
| 检视 | `cat-file.c` | 已闭环（type/size/pretty 聚合读取，对齐 `git cat-file -t/-s/-p` 黄金；commit/blob/tree/tag/剥离） |
| 清单 | `ls-files.c` | 已闭环（cached 路径列表 + stage 详表，对齐 `git ls-files` / `git ls-files --stage` 黄金；排序/可执行/嵌套） |
| 拣选 | `cherry-pick.c` / `sequencer.c` | 已闭环（首父 diff 扁平应用 + 递归树构建 + `(cherry picked from commit …)` trailer + `checkout` 检出，对齐 `git cherry-pick` 黄金；root 空树、Added/Modified/Deleted/TypeChanged、分支/游离 HEAD、嵌套路径） |
| 还原 | `revert.c` / `sequencer.c` | 已闭环（逆向首父 diff `Target→Parent` 扁平应用 + 递归建树 + `Revert "<subject>"` + `This reverts commit <oid>.` + `checkout`，对齐 `git revert` 黄金；逆向 Added/Modified/Deleted/TypeChanged、分支/游离 HEAD、嵌套/类型翻转、root 空树） |
| 归档 | `archive.c` | 已闭环（树扁平化 → USTAR `tar` 512 字节头 + 512 对齐 + `1024` 零块，对齐 `git archive --format=tar` 黄金；`0644/0755` 与符号链接 `2`、gitlink 跳过、嵌套/可执行位、tag 剥离） |
| 子模块 | `submodule.c` | 已闭环（`.gitmodules` INI 解析 `path/url/branch`，worktree 优先、HEAD 回退，对齐 `git config -f .gitmodules --list` 黄金；引号转义/注释/大小写、HEAD~ 剥离） |
| 身份映射 | `mailmap.c` | 已闭环（`.mailmap` 行解析 `[proper] [<proper>] [commit] [<commit>]`，worktree 优先、HEAD 回退，对齐 `git check-mailmap` 黄金；大小写折叠、注释） |
| 尾注 | `trailer.c` | 已闭环（`Key: Value` 尾块解析，`Has/Find/Format/Append`，对齐 `git interpret-trailers --parse/--trailer` 黄金；大小写折叠、空行分隔） |
| 属性 | `attr.c` | 已闭环（`.gitattributes` 行解析，`set/-unset/value`，`*`/`?`/`**`，last-match-wins，对齐 `git check-attr` 黄金；`HEAD` 回退） |
| 束 | `bundle.c`（`git bundle` / `pack-objects`） | 已闭环（`# v2 git bundle` 头 + `-<oid> <title>` 前提 + `<oid> <ref>` + 空行 + `PACK` 流，经 `pack-objects --revs --delta-base-offset` 生成 pack，`SHA-1` 尾校验 + `GitBuildPackIndex` 深校验，`Unbundle` 落盘 `pack-<hash>.pack/.idx` 并写 `refs/*`；与 `git bundle create/verify/list-heads/fetch` 双向黄金，支持 `HEAD~`/`^`/`..` 前提语法） |
| 搜索 | `grep.c`（`git grep`） | 已闭环（`HEAD`/`ref` 经 `rev-parse` 16 层剥离至 `tree`，`$4000` 递归 + 二进制跳过 + `Pos` 固定串 + `-i` 大小写折叠，经 `path:lineNo` 排序，对齐 `git grep -n -F` 黄金） |
| 二分 | `bisect.c`（`git bisect`） | 已闭环（`good..bad` 经 `revwalk` topo 排除 + 回调二分，`log N` 步首坏定位，对齐 `git bisect` 线性史；非线性拓扑仅近似） |
| 工作树等 | `worktree.c` | 已闭环（`worktrees/<id>` 布局，`Add` 创建分支/游离并物化、`Remove` 清理，对齐 `git worktree add/list/remove --porcelain`；`checkout` 对 `commondir` 透明） |

## 反哺 nextpas.core 的通道

借鉴过程中若发现 core 缺底层能力，优先补 core 而非在 git.native 里堆 workaround：

1. **mmap（已闭环并消费）**：libgit2 用 `src/util/{unix,win32}/map.c` 映射 pack；
   core 已有对应物 `nextpas.core.io.mapped.MmapOpen`（IMappedFile.Data/Size）。
   TPackFile 已切换为 mmap 访问（test_git_native 12 测全绿）。
2. **FPC RTL 隔离（已闭环）**：git.native 全部单元零 FPC RTL 引用——
   异常用 `nextpas.core.exception.Exception`（Create/CreateFmt 同形）、
   文本转换用 `nextpas.core.text.conv`；未发现需要新底层原语的缺口。
3. **教训（写路径切片）**：git 模式常量是八进制语义，必须以八进制思维换算
   （目录 `040000₈=$4000`、gitlink `160000₈=$E000`）；十六进制直觉会造出
   自洽但错误的常量。`git mktree` 黄金对照是此类错误的强制检测手段，
   后续所有序列化切片都必须配真实 git 黄金对照。
