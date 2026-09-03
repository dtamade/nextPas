# nextpas.core.git — 传输契约（transport）

**模块路径**：`core/src/nextpas.core.git.native.{config,pktline,remote,advertise,negotiate,sideband,indexer,fetch,clone,checkout,push,reset,prune,clean,revparse}.pas` + `nextpas.core.git.native.transport.pas` 门面
**层级**：L2（L0-L1: base, bytes, text, fs, io, process；同层单向 `fs/compress/hash/checksum` 豁免）
**Owner**：git lane
**不变量域**：传输基座（config / pkt-line / remote / advertise / negotiate / sideband / indexer / fetch / clone / checkout / push / reset / prune / clean / revparse）

## 1. 范围与阈值
- 源聚合：15 单元 + 1 门面 shard（`native.transport`），单 shard 分片聚合，超阈再按能力/协议帧拆分；远期网络仍由 libgit2 后端承接，native 仅无状态抓/推。

## 2. 不变量
- Config：INI `[section]/[section "sub"]`，引号转义 `\" \\ \n \t \b`，大小写折叠，`--get/--get-all` 对齐 `git config --list`。
- Pkt-line：`0000` flush / `0001` delim / `XXXXpayload`（4-hex 长度含头，65535 上限，`0004` 空载禁止），`Scan/Join` 流式拼装。
- Remote/Advertise/Negotiate/Sideband：基于 `config` 的 `[remote "<name>"]` 多值，`oid SP ref [NUL caps] LF` 公告 + `want/have/done` 协商（首 want 能力表）+ `chr(1/2/3)+payload` 64k 复用分流，对齐 `git remote/fetch-pack/send-pack` 帧层；`stateless-rpc` 经 `upload-pack/receive-pack` 无状态往返。
- Indexer：`pack→idx v2`（OFS/REF delta、CRC-32、fanout 排序、pack/index SHA-1），对齐 `git index-pack`。
- Fetch/Clone/Push/Checkout/Reset/Prune/Clean/Revparse：`clone --bare` 公告+抓取+落盘+骨架，`clone` 另写 `refs/remotes/origin/*` + HEAD 检出 + v2 index；`push` 支持创建/快进/删除/多 ref 原子 + `report-status` 解析；`checkout` 任意 tree/commit/ref→worktree 物化（类型翻转/孤儿裁剪/可执行位/symlink/gitlink，v2 index）；`reset --hard` 复用 checkout；`prune` 陈旧远端追踪裁剪；`rev-parse` `HEAD/refs/*/~^/^{type}` 剥离 16 层。

## 3. 性能契约
- Pkt-line/negotiate/sideband 均为 `PByte+Len` 零拷贝视图，单次分配拼装；`indexer` 流式 OFS/REF 解析，单遍 `bytes.ops` 零重复分配。

## 4. 稳定性
- `pack→idx` 与 `WriteAtomic` 异常 `try..finally` 不留半索引；`fetch/push` 子进程 `TProcess` 句柄 `try..finally` 关闭；`checkout` 孤儿裁剪先收 `index` 再物化，异常不丢工作树一致性。

## 5. 与总约关系
- 本域权威：帧编解码/抓推/检出语义以本文件为准；跨域仍以总 CONTRACT 为准。
- 缺能力先反哺 owner：压缩/校验归 `compress/checksum`，传输仅编排。
