# nextpas.core.net

Low-level TCP and UDP networking with DNS resolution.

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

## TNetAddress

```pascal
TNetAddress.Create('192.168.1.1', 8080)
TNetAddress.Loopback(3000)
TNetAddress.Any(0)
TNetAddress.IPv6('::1', 8080)
```

## Cross-Platform

- Linux: epoll-based (via platform.net)
- Windows: IOCP (planned)
- macOS: kqueue (planned)

Deadline support via `nextpas.core.time.deadline.TDeadline`.
