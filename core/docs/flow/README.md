# nextpas.core.flow

L1 通用流控窗口（`TFlowWindow`），从 `nextpas.core.ssh.window.TChannelWindow` 抽离。

## 定位
- L1 基础设施（仅依赖 `nextpas.core.base.SizeUInt`，零堆 `inline`，`bytes.ops` 单源外层 `Move`）。
- 供 `ssh.channel/channel.async/proxyjump.async/sftp.async` 单源复用，预留 `http.h2`/`quic` 复用（跨协议 ≥2 实证后正式宣称通用）。

## API

```pascal
uses nextpas.core.flow.window;

var W: TFlowWindow; Need: UInt32;
W.Init(2097152, PeerWindow, PeerMax);
W.SetPeer(PeerWindow, PeerMax);
if W.CanSend(N) then ...
NeedSlice := W.SliceSize(Want); // min(Want, PeerMax, PeerWindow)
W.DidSend(NeedSlice);
W.Consume(Incoming, NeedAdjust); // 半水位回补：OurWindow <= InitWindow div 2 时回补至 InitWindow
if W.ShouldReplenish then Need := W.ReplenishAmount;
```

## 不变量
- `FLOW_WINDOW_LOW_WATER_DIVISOR=2` 冻结，`OurWindow` 初值 `InitWindow`（ssh 侧 `SSH_DEFAULT_WINDOW_SIZE=$200000`），消费过半即 `WINDOW_ADJUST` 回补。
- `PeerWindow`/`PeerMaxPacket` 双重上限，`SliceSize` 零拷贝分片，`Consume/Grant` 纯算术无分配。

## 模块结构
```
nextpas.core.flow.window.base.pas ← 常量 `FLOW_WINDOW_LOW_WATER_DIVISOR`
nextpas.core.flow.window.pas      ← `TFlowWindow` record 全 `inline` 零堆实现
nextpas.core.flow.pas             ← 门面纯 re-export
nextpas.core.ssh.window.pas       ← ssh 兼容门面（`TChannelWindow = TFlowWindow` 零成本 alias，直连 `flow.window.base` 常量已收敛二跳间接，`bytes.ops` 单源）
```

## 性能
- 全 `inline` 薄转发，`record` 值语义，零堆分配，`bytes.ops` 单源（外层 `Move` 不自实现拷贝）。

## 依赖
- L1 仅 `nextpas.core.base`（`SizeUInt`），L2 `ssh` 经 `flow.window` 单向依赖，符合 `base←window←ssh`。

## 验证
- `grep -R TFlowWindow core/src/nextpas.core.flow*` 单源；`grep -R TChannelWindow core/src` 仅 `flow.window` 真源 + `ssh.window` 兼容门面 + 2 复用方 alias。
- `make hygiene` 零产物，`make -C core/tests/nextpas.core.ssh` 全门 `heaptrc 0`。

## 变更
- S15 P1-1：抽 `ssh.window` → `flow.window` L1，`ssh.window` 改薄门面兼容。
