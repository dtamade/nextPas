# nextpas.core.io.uring — io_uring 高层封装规划

> **目标：** FreePascal 领域首个生产级 io_uring 封装，对标 liburing/tokio-uring API 质量。

## 架构分层

```
L2: nextpas.core.io.reactor (future — 事件循环/回调分发)
L1: nextpas.core.io.uring   (本次 — Ring 对象 + prep helpers)
L0: nextpas.core.platform.linux.modern (已完成 — raw syscall)
```

## 模块结构

```
nextpas.core.io.uring.pas          ← TIoUring record + 核心 API
nextpas.core.io.uring.prep.pas     ← SQE prep helpers (PrepRead/Write/Accept/...)
```

## 核心 API 设计

```pascal
type
  TIoUring = record
  private
    FFd: Int32;
    FSqRing: TIoUringSqRing;
    FCqRing: TIoUringCqRing;
    FSqeArray: PIoUringSqe;
    FSqeCount: UInt32;
  public
    class function Create(AEntries: UInt32; AFlags: UInt32 = 0): TIoUring; static;
    procedure Close;
    function GetSqe: PIoUringSqe;
    function Submit: Int32;
    function SubmitAndWait(AWaitNr: UInt32): Int32;
    function PeekCqe(out ACqe: PIoUringCqe): Boolean;
    function WaitCqe(out ACqe: PIoUringCqe): Int32;
    procedure CqeSeen(ACqe: PIoUringCqe);
    function CqeReady: UInt32;
  end;

{ Prep helpers }
procedure IoUringPrepNop(ASqe: PIoUringSqe);
procedure IoUringPrepRead(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AOffset: Int64);
procedure IoUringPrepWrite(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AOffset: Int64);
procedure IoUringPrepReadv(ASqe: PIoUringSqe; AFd: Int32;
  AIovecs: Pointer; ANrVecs: UInt32; AOffset: Int64);
procedure IoUringPrepWritev(ASqe: PIoUringSqe; AFd: Int32;
  AIovecs: Pointer; ANrVecs: UInt32; AOffset: Int64);
procedure IoUringPrepAccept(ASqe: PIoUringSqe; AFd: Int32;
  AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32);
procedure IoUringPrepConnect(ASqe: PIoUringSqe; AFd: Int32;
  AAddr: Pointer; AAddrLen: UInt32);
procedure IoUringPrepClose(ASqe: PIoUringSqe; AFd: Int32);
procedure IoUringPrepFsync(ASqe: PIoUringSqe; AFd: Int32; AFlags: UInt32);
procedure IoUringPrepPollAdd(ASqe: PIoUringSqe; AFd: Int32; APollMask: UInt32);
procedure IoUringPrepSend(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AFlags: Int32);
procedure IoUringPrepRecv(ASqe: PIoUringSqe; AFd: Int32;
  ABuf: Pointer; ALen: UInt32; AFlags: Int32);
procedure IoUringPrepTimeout(ASqe: PIoUringSqe; ATs: Pointer; ACount: UInt32; AFlags: UInt32);
procedure IoUringPrepCancel(ASqe: PIoUringSqe; AUserData: UInt64; AFlags: Int32);
procedure IoUringPrepSplice(ASqe: PIoUringSqe; AFdIn: Int32; AOffIn: Int64;
  AFdOut: Int32; AOffOut: Int64; ALen: UInt32; AFlags: UInt32);

{ user_data helper }
procedure IoUringSqeSetData(ASqe: PIoUringSqe; AData: UInt64); inline;
function IoUringCqeGetData(ACqe: PIoUringCqe): UInt64; inline;
```

## 实施顺序

| Phase | 内容 |
|-------|------|
| P1 | TIoUring.Create/Close (mmap ring buffers) |
| P2 | GetSqe + Submit + WaitCqe + CqeSeen |
| P3 | Prep helpers (Nop/Read/Write) |
| P4 | 更多 prep helpers (Accept/Connect/Send/Recv/Close) |
| P5 | PeekCqe + SubmitAndWait + CqeReady |
| P6 | 测试: 文件 I/O round-trip, NOP 吞吐量 |
| P7 | 基准对比 liburing |

## 关键实现细节

- **mmap**: SQ ring + CQ ring + SQE array 三次 mmap
- **内存屏障**: `ReadBarrier` (acquire) / `WriteBarrier` (release) 用 inline asm
- **SQ tail 推进**: atomic store with release
- **CQ head 推进**: atomic store with release
- **错误处理**: syscall 返回 < 0 时返回 -errno
