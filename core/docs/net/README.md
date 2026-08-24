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
{ Optional OS dial timeout (ms). 0 / two-arg form = unbounded connect. }
Conn := TcpConnect('example.com', 443, 5000);
Conn.Write(Buf, Len);
BytesRead := Conn.Read(Buf, BufSize);
Conn.Shutdown;
{ Optional mid-read/write cancel: SetCancelToken + INetCancelToken.
  Prefer NewNetCancelToken (waitable socketpair wake). Probe-only tokens
  use ~10ms SO_*TIMEO slices. Raises ECancelledError when canceled. }
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

### Host classification and pick

UDP/QUIC 等「字面量直发 / 域名走 DNS」分路用这些 helper，不要在业务里自写一套。

```pascal
if HostIsIpLiteral(Host) then
  Addr := TNetAddress.Create(StripHostBrackets(Host), Port)
else
  { AsyncResolve callback: }
  Addr := DnsResult.PreferredAddress(True).WithPort(Port); { IPv4 first }
```

- `StripHostBrackets('[::1]')` → `'::1'`
- `IsIPv4Literal` / `TryParseIPv4`：四段 0..255，拒绝 `1.2.3` / `256.1.1.1`
- `IsIPv6Literal`：剥括号后含冒号
- `TDnsResult.PreferredAddress(True)`：先 A，无 A 再退第一条
- `TNetAddress.WithPort`：拷贝后改端口，不改 IP/族

## Interfaces

- `ITcpStream` — extends IStream with LocalAddr, RemoteAddr, Shutdown, SetNoDelay, SetKeepAlive, SetReadDeadline, SetWriteDeadline, SetCancelToken
- `INetCancelToken` / `INetCancelController` / `INetCancelWaitable` — cooperative cancel; `NewNetCancelToken` for fast wake
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

#### macos/freebsd compile truth (kqueue source-landed; event-driven wiring)
- `tsbKqueue` exists in the backend enum (`TTcpServerBackend`) and is registered
  as a built-in factory on macOS/FreeBSD hosts
- `nextpas.core.net.server.kqueue.pas` is a B8 event-driven backend built on
  `io.reactor.kqueue` (was a readiness alias that forwarded to
  `NewTcpReadinessServer` before B8):
  - `AsyncAccept` drives the listener; each accepted connection is bridged to
    the readiness session contract via an `AsyncRecv(MSG_PEEK, 1)` completion
    (peek signals readability without consuming data), mirroring the Windows
    IOCP backend's zero-byte-recv shape
  - poll-driven sessions advance via `TryRead`/`TryWrite`; non-poll sessions
    fall back to worker handoff; writable waiters are re-advanced on a 1ms
    retry timer; read-deadline wakes cancel the parked peek via
    `TryCancelByContext`
  - the server loop blocks on the reactor's `PollWait` (added in B8) so an
    idle server does not spin
- compile-gate verified on the Linux host via `NEXTPAS_FORCE_HOST_DARWIN`
  (`tests/nextpas.core.net.server/test_net_server_kqueue_gate`); the kqueue
  branch is excluded from Linux builds — Linux can only attest code
  structure/API parity, not macOS/FreeBSD runtime behavior
- **not macos/freebsd runtime ready** — no runtime verification has been done
  on an actual macOS or FreeBSD host; runtime smoke is pending a real machine
  (B8 follow-up)

#### Windows truth
- `tsbIocp` exists in the backend enum and is registered as a built-in factory on Windows (`RegisterTcpServerFactory(tsbIocp, ...)`)
- `nextpas.core.net.server.iocp.pas` is the phase-1 iocp server unit: AcceptEx via `io.reactor.iocp` + foundation worker handoff for sync session/handler execution
- `nextpas.core.io.reactor.iocp.pas` is a full completion reactor (not a stub): AcceptEx/ConnectEx/WSASend/WSARecv etc.
- Evidence tier today: `wine-runtime-smoke` via `test_http_iocp_wine` (and reactor wine suite) — **not real-Windows host runtime ready**, **not windows scale-ready**
- **not windows server runtime ready** as a whole-host / production scale claim; phase-1 only proves accept path + worker handoff contract

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
- macOS/FreeBSD: kqueue event-driven backend source-landed (B8), compile truth only — not macOS/FreeBSD runtime ready.
- Windows: phase-1 iocp factory registered on Windows hosts; wine-runtime-smoke only — not windows server runtime ready, not windows scale-ready.
- IOCP is a completion/proactor family backend and must plug into a completion-aware foundation driver.

## Event-Driven WebSocket Frame Processing (B8)

`nextpas.core.net.server.ws` provides poll-ready WebSocket frame primitives
for evented backends (epoll/kqueue/iocp). It is the non-blocking counterpart
of the blocking `http.websocket` `IWebSocket`:

- `TNetWsFrameDecoder` (`nextpas.core.net.server.ws.frame`) — incremental
  decoder; feed poller-ready bytes with `Feed`, pull complete frames with
  `TryDecode` (`nwsDecodeNeedMore` = keep waiting for readable interest).
  Fragmentation is assembled internally exactly like the blocking
  `TWebSocketImpl.ReadFrame`: a final continuation is returned as one message
  with the starting data opcode. Server role requires masked client frames,
  client role requires unmasked server frames (RFC 6455 §5.3).
  Errors are terminal: protocol error / too-large stay sticky. Permessage-deflate
  (RSV1) is rejected in this slice — compression stays on the blocking path.
- `TNetWsFrameEncoder` — builds wire frames (unmasked for server role, masked
  client role), including `BuildCloseFrame` with close-code validation.
- `TNetWsFrameSession` (`nextpas.core.net.server.ws.session`) — plugs the codec
  into the poll-driven session contract (`PollEvents`/`Advance`/`WakeDeadline`):
  readable events are drained into the decoder, writable events flush a bounded
  outbound queue, idle timeouts are delivered via `nwsEventTimeout` + close 1001,
  queue overflow fails closed with `nwsEventOverflow`, and Ping is answered with
  Pong automatically. `SendXxx` must be called from the session's reactor-thread
  context (Advance or its callbacks); worker-side pushes should use worker
  handoff, whose completions are drained on the reactor thread.
  Server shutdown: the session implements `ITcpServerSessionShutdown`
  (`BeginShutdownClose` = close frame 1001 going away through the same
  guarded path as idle timeout / protocol error). The epoll readiness server
  calls it on every registered hook-capable target during its shutdown drain
  phase, keeps polling writable events until those sessions finish flushing
  (bounded by `TTcpServerOptions.ShutdownTimeoutNs`; `<= 0` waits without a
  deadline, matching the blocking path's `WaitFinished(0)` semantics), then
  force-closes any stragglers. Sessions that already completed the close
  handshake are not sent a second frame (`FCloseSent` guard).

```pascal
uses nextpas.core.net.server,
     nextpas.core.net.server.ws,
     nextpas.core.websocket.base,
     nextpas.core.time.base;

{ inside an ITcpServerHandler that also implements
  ITcpServerSessionFactoryWithContext.NewSession }
function MyHandler.NewSession(const AConn: ITcpStream;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  Result := TNetWsFrameSession.Create(AConn, FFrameSink,
    TNetWsFrameSessionOptions.Default
      .WithIdleTimeout(TDuration.FromMilliseconds(60000)));
end;

{ sink receives: nwsEventFrame (data messages / close), nwsEventTimeout,
  nwsEventOverflow, nwsEventClosed (always last) }
procedure MySink.OnSessionEvent(const AEvent: TNetWsSessionEvent;
  const AFrame: TNetWsFrame);
begin
  case AEvent of
    nwsEventFrame: if AFrame.Opcode = Byte(WS_OPCODE_TEXT) then ...;
  end;
end;
```

### Integration point with the existing HTTP WebSocket server

The HTTP upgrade handshake (`http.websocket.UpgradeWebSocket`) is still
blocking and hands a hijacked `ITcpStream` to a blocking `IWebSocket`
(frames on blocking `IReader`/`IWriter`, one worker per connection). The B8
plan for the gateway is to add a non-blocking upgrade variant that returns the
hijacked stream plus this frame session — after the handshake the connection
runs on the readiness reactor and no longer occupies a worker. That variant,
and a shared single codec inside `http.websocket` (the blocking parser's
validation helpers are currently private copies, mirrored here), are B8
follow-ups; this slice delivers and tests the frame layer.

### epoll handoff semantics (S1-1, corrected)

On Linux `tsbEpoll` the H1 HTTP transport's poll-owned path executes completed
requests **inline on the reactor thread** by default. `PreferPollWorkerHandoff`
defaults to `False`; it **must be explicitly enabled** to get per-request
worker-handoff isolation (legacy behavior; the Net README previously implied
handoff was the default). Correctness tests that assert handoff semantics set
`PreferPollWorkerHandoff := True`.

Deadline support via `nextpas.core.time.deadline.TDeadline`.

## Design Decisions

### ITcpStream implements IStream

`TTcpStream` implements `IStream` (which includes `Seek`, `GetSize`, `GetPosition`, `SetPosition`).
For TCP sockets, `Seek`/`SetPosition` raise `ENotSupportedError`, `GetSize` returns `-1`,
and `GetPosition` returns `0`. This is because a TCP socket is a stream of bytes with no
random access — but implementing `IStream` gives a unified API for `Read`/`Write`/`Close`.

### IPv4-only (current)

`TNetAddress` has full IPv6 support in its data model (`IPv6` constructor, `IsIPv6` flag),
but `NetTcpListen`, `NetTcpConnect`, and `NetUdpBind` currently hardcode `AF_INET` (IPv4).
IPv6 socket operations will be added when the platform layer gains dual-stack support.

### Exception semantics

- Deadline/timeout → `ETimeoutError`
- Network failures → `ENetworkError`
- Closed socket access → `ENetworkError` (blocking) or `tsiorClosed` (Try-variant)
- This dual-mode design lets callers choose: blocking APIs raise, non-blocking APIs report

### Socket address helpers

`platform_sockaddr_from_ipv4` and `platform_sockaddr_to_ipv4` in `nextpas.core.platform.socket`
provide the single source of truth for `TNetAddress` ↔ `sockaddr_in` conversion.
All net modules use these helpers to avoid code duplication.
