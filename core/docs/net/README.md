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

Current truth:

- `nextpas.core.net` provides socket/listener primitives.
- `nextpas.core.net.server` provides the reusable TCP server runtime seam.
- `ITcpSocketRuntime` now exposes the native-handle / blocking-control prerequisite seam that future evented backends can consume without relying on concrete `TTcpStream` / `TTcpListener` casts.
- `ITcpListenerRuntime.TryAccept` plus `ITcpStreamRuntime.TryRead/TryWrite`
  are already landed as the narrow nonblocking runtime I/O seam.
- Current shipped backends are `threaded` plus a Linux-only phase-1 `epoll`
  backend that uses readiness-driven accept and then hands accepted connections
  to foundation workers.
- Planned next backends are `kqueue` and `IOCP`, and Linux `epoll` still has a
  later phase where runtime directly drives per-connection state with
  `TryRead/TryWrite`.

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
- Planned cross-platform evented backends remain `kqueue` on macOS / FreeBSD
  and `IOCP` on Windows.

Deadline support via `nextpas.core.time.deadline.TDeadline`.
