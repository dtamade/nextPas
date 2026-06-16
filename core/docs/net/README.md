# nextpas.core.net

Low-level TCP and UDP networking with DNS resolution.

For reusable TCP server runtime architecture, see
[docs/net/ARCHITECTURE.md](/home/dtamade/projects/nextPas/core/docs/net/ARCHITECTURE.md:1).

## API

```pascal
uses nextpas.core.net;
```

### TCP Server

```pascal
var Listener: ITcpListener;
Listener := TcpListen('0.0.0.0', 8080);
var Conn: ITcpStream;
Conn := Listener.Accept;
// Conn implements IStream (Read/Write/Close)
Conn.SetNoDelay(True);
Conn.SetKeepAlive(True);
Listener.Close;
```

### TCP Client

```pascal
var Conn: ITcpStream;
Conn := TcpConnect('example.com', 443);
Conn.Write(Buf, Len);
BytesRead := Conn.Read(Buf, BufSize);
Conn.Shutdown;
```

### UDP

```pascal
var Sock: IUdpSocket;
Sock := UdpBind('0.0.0.0', 9000);
Sock.SendTo(Buf, Len, DestAddr);
BytesRead := Sock.RecvFrom(Buf, BufSize, SenderAddr);
Sock.Close;
```

### DNS Resolution

```pascal
var Addr: TNetAddress;
Addr := Resolve('example.com');
// Addr.IP, Addr.Port, Addr.IsIPv6
```

## Interfaces

- `ITcpStream` — extends IStream with LocalAddr, RemoteAddr, Shutdown, SetNoDelay, SetKeepAlive, SetReadDeadline, SetWriteDeadline
- `ITcpListener` — Accept, LocalAddr, Close
- `IUdpSocket` — SendTo, RecvFrom, LocalAddr, Close
- `ITcpSocketRuntime` — optional advanced-runtime seam that exposes a native socket handle plus blocking/nonblocking control for server backends; ordinary application code usually does not need it
- `ITcpListenerRuntime` / `ITcpStreamRuntime` — optional runtime-only nonblocking I/O seam for future evented server backends; `TryAccept` / `TryRead` / `TryWrite` report would-block as a normal result instead of an exception

## TCP Server Foundation

Reusable server runtime ownership now lives in `nextpas.core.net.server`, not in
protocol modules such as HTTP.

### Truth Matrix

#### threaded runtime backend
- `tsbThreaded` is the default backend when no options override it
- Accept + blocking session execution on a per-connection worker thread
- Correctness baseline: all session/context/handoff semantics are proven through focused tests

#### linux runtime truth
- `tsbEpoll` is a shipped Linux-only phase-1 epoll backend
- Uses readiness-driven accept via `platform_poller_*` facade
- Accepted connections are handed to foundation workers for synchronous session execution
- `ITcpServerPollDrivenSession` is the per-connection evented driver seam: Linux `epoll` can drive sessions that opt into it, while blocking sessions fall back to worker execution
- Foundation-owned reactor self-wakeup, worker completion re-entry, and deadline wake are all landed
- `epoll` still has a later phase where real protocol sessions such as HTTP H1 migrate fully onto the poll-driven path backed by `TryRead/TryWrite`

#### macos/freebsd compile truth (kqueue source-landed)
- `tsbKqueue` exists in the backend enum (`TTcpServerBackend`)
- `nextpas.core.net.server.kqueue.pas` is a readiness-backed unit that calls `NewTcpReadinessServer`
- The kqueue backend is source-landed and compiles on macOS/FreeBSD hosts
- The host facade (`registertcpserverfactory(tsbKqueue, ...)`) is registered for non-Linux hosts
- `readiness-backed` — kqueue reuses the same `TTcpReadinessServer` readiness-family driver shape as epoll
- **not macos/freebsd runtime ready** — no runtime verification has been done on an actual macOS or FreeBSD host; compile-only confidence

#### Windows truth
- `tsbIocp` exists in the backend enum but `iocp is not registered` as a built-in server factory
- `nextpas.core.io.reactor.iocp.pas` is a compile-only stub — no functional IOCP server backend exists
- `nextpas.core.net.server.iocp.pas` does not yet exist as a source unit
- **not windows server runtime ready** — no Windows server runtime verification

The public goal is a stable, synchronous application-facing contract with
runtime/backend policy hidden underneath the foundation layer.

## TNetAddress

```pascal
TNetAddress.Create('192.168.1.1', 8080)
TNetAddress.Loopback(3000)
TNetAddress.Any(0)
TNetAddress.IPv6('::1', 8080)
```

## Cross-Platform

- `nextpas.core.net` socket APIs are the common cross-platform base.
- `nextpas.core.net.server` currently ships a threaded runtime backend and a
  Linux-only phase-1 `epoll` backend.
- macOS/FreeBSD: kqueue source-landed, readiness-backed, compile truth only — not macOS/FreeBSD runtime ready.
- Windows: tsbIocp enum exists but IOCP is not registered as a built-in server factory — not windows server runtime ready.
- IOCP is a completion/proactor family backend and must plug into a completion-aware foundation driver.

Deadline support via `nextpas.core.time.deadline.TDeadline`.
