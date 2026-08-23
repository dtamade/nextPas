unit nextpas.core.net.intf;
{**
 * @desc 网络接口定义：ITcpStream、ITcpListener、IUdpSocket。
 *       ITcpStream 继承 IReadWriteCloser（Read + Write + Close），
 *       不支持 Seek/Size/Position（TCP 流无随机访问）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.time.deadline,
  nextpas.core.net.base;

type
  { Cooperative cancel for blocking stream IO. When set on ITcpStream, Read/Write
    raise ECancelledError if IsCanceled becomes true before the operation
    completes. Does not force-close the peer socket.
    Prefer INetCancelWaitable tokens (NewNetCancelToken): Linux/macOS/BSD wake
    blocked IO via poll+socketpair. Probe-only tokens fall back to short
    SO_*TIMEO slices (~10ms). }
  INetCancelToken = interface
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000007}']
    function IsCanceled: Boolean;
  end;

  { Optional cancel controller: mark canceled (and signal wake when waitable). }
  INetCancelController = interface(INetCancelToken)
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000008}']
    procedure Cancel;
  end;

  { Optional fast-wake side-channel. WakeHandle is a readable fd/socket that
    becomes ready when Cancel is called. 0 means unavailable (slice fallback). }
  INetCancelWaitable = interface
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000009}']
    function WakeHandle: PtrUInt;
    procedure DrainWake;
  end;

  { Runtime-facing socket seam for advanced server backends.
    Ordinary consumers can ignore it; evented runtimes may opt-in via Supports. }
  ITcpSocketRuntime = interface
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000004}']
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
  end;

  TTcpStreamIOResult = (
    tsiorOk,
    tsiorWouldBlock,
    tsiorClosed,
    tsiorTimeout
  );

  TTcpAcceptResult = (
    tarAccepted,
    tarWouldBlock,
    tarTimeout
  );

  ITcpStream = interface(IReadWriteCloser)
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000001}']
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    { Optional cancel token for mid-read / mid-write interrupt.
      Waitable tokens wake via poll; others use short SO_*TIMEO slices.
      Pass nil to clear. }
    procedure SetCancelToken(const AToken: INetCancelToken);
  end;

  ITcpListener = interface
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000002}']
    function Accept: ITcpStream;
    function LocalAddr: TNetAddress;
    procedure Close;
  end;

  ITcpStreamRuntime = interface(ITcpSocketRuntime)
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000005}']
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
  end;

  { 非破坏性对端存活探测（长前置 server 工作期间的客户端断连识别）。
    True = 存活或无法判定（保守）；False = 对端已确认关闭/重置。
    永不阻塞、永不消费数据。可选能力：经 Supports/QueryInterface 探测。 }
  ITcpPeerProbe = interface
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000007}']
    function PeerAlive: Boolean;
  end;

  ITcpListenerRuntime = interface(ITcpSocketRuntime)
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000006}']
    function TryAccept(out AConn: ITcpStream): TTcpAcceptResult;
  end;

  IUdpSocket = interface
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000003}']
    function SendTo(const ABuf; const ACount: SizeUInt;
      const AAddr: TNetAddress): SizeUInt;
    function RecvFrom(var ABuf; const ACount: SizeUInt;
      out AAddr: TNetAddress): SizeUInt;
    function LocalAddr: TNetAddress;
    procedure Close;
  end;

  { Runtime seam for async UDP. Sync consumers may ignore. }
  IUdpSocketRuntime = interface
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000011}']
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
  end;

implementation

end.
