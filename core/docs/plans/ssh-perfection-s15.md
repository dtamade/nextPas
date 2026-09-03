# SSH S15 六维匠心 — RTL反哺 + 新模块萃取 + 单源收口

> 约束：不准直连 FPC RTL（SysUtils/Classes/BaseUnix/Unix/Windows），必须经 nextpas.core；缺能力反哺 owner；L0-L3 单向依赖，四件套 base←intf←impl←facade，bytes.ops 单源，inline零拷贝，hygiene 零产物

## DAG（拓扑分层）

### L0  platform / text 基础
- **P0-1** `platform.numa/io.uring 反哺` — `numa.linux:25 BaseUnix/Linux` → `platform.posix.ffi`，`numa.windows:25 Windows` → `platform.windows.ffi`，`io.uring:100 BaseUnix` → `platform.uring.ffi`。验证：grep 0 hits SysUtils/BaseUnix，`make hygiene` pass
- **P0-2** `text.wildmatch` 新模块 — 抽 `ssh.hostkey:90 SshWildMatch` (`*?` 双指针) 为 `nextpas.core.text.wildmatch` (L0，仅 base/System)，`hostkey` 改依赖。四件套 + `units/<target>/` stub 空。复用：http route / fs glob

### L1  通用能力
- **P1-1** `flow.window` (C1) — 抽 `ssh.window.TChannelWindow` 为 `nextpas.core.flow.window` (L1，仅 base.SizeUInt)，零堆 inline `Init/Consume/Grant/SliceSize/CanSend/DidSend`，半水位回补。 `ssh.channel/channel.async/proxyjump.async` + `http.h2`/`quic` 复用。验证：`grep TChannelWindow` 仅 flow.window + 2 复用方
- **P1-2** `bytes.framing` (C5) — 抽 `sftp.wire 4B 前缀流` 为 `nextpas.core.bytes.framing.TWireBuffer` (L1，bytes.ops/bytes.binary)，`BytesEnsureCapacity` 几何 + `FOff` 零拷贝 + 32KB/8KB 懒压实。复用：net.quic / db.redis
- **P1-3** `args/text.conv 单源` — `args:571 ParamStr/ParamCount` → `os.env/platform.args`；12 处裸 `IntToStr` → `text.conv.IntToStr` (`buffer:284/channel:173/sftp.wire:180/hostkey:468/compress:164` 等)。验证：grep IntToStr 0 hits 裸

### L2  领域能力
- **P2-1** `crypto.rsa` (C4) — 晋升 `ssh.rsa` 为 `nextpas.core.crypto.rsa` (L2，crypto.bigint/hash)，`ssh.rsa` 改 facade，`tls.x509verify/dkim` 复用 `DIGEST_INFO_*`。消裸 `SysUtils`（`aesctr:19 Exception.Create` → `ECryptoError`）
- **P2-2** `net.rekey/keepalive` (C2) — 抽 `ssh.rekey/keepalive(.scheduler)` 为 `nextpas.core.net.maintenance` (L1 策略 + L2 调度)，`TInstant` 单调时钟，消 sync/async 漂移。复用：tls/quic key phase, http PING
- **P2-3** `compress 单源` — `ssh.compress:143 LCap*2` → `BytesEnsureCapacity` 单源（BYTES_BUILDER_MIN_GROW=64, 2x），`Decompress` 初始 `LInLen*3` → `CompressInitialInflateCapacity shl2` 单源
- **P2-4** `buffer/cipher/transport 单源` — `buffer.ToBytes` Move → `SpanCopySlice`，`cipher 6 薄转发` 补 inline，`transport.ReadLineRaw` 256B 几何缓冲

### L3  业务切换
- **P3-1** `ssh 切换新 flow/wire` — `ssh.channel/sftp.wire` 改依赖 `flow.window/bytes.framing`，删 12 手写 Move/Copy，hygiene 0 产物，HEAPTRC_GATE=1 全门
- **P3-2** `knownhosts 回归` — `knownhosts` 薄别名删，`hostkey` 归一，`bench` 等 7 门 `HEAPTRC_GATE=0` 移除（bench 2 门保留）

## 门禁
- `scripts/build-hygiene-check.sh` pass，`git diff --check` 0，`make -C core test` 143 gates / `ssh 17 gates` HEAPTRC 1，proxyjump 5/5 深挖（TMemPipe/_AddRef 悬垂）
- 双编译器：FPC 编譯 `nextpas.core` 通过，`units/<target>/` stub 仅桥名

## 执行
- worktree `.worktrees/ssh`，`nextpas-core-advance` 拓扑并行，每项独立验收
