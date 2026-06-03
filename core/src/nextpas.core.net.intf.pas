unit nextpas.core.net.intf;
{**
 * @desc 网络接口定义：ITcpStream、ITcpListener、IUdpSocket。
 *       ITcpStream 继承 IStream，支持 deadline 超时控制。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.time.deadline,
  nextpas.core.net.base;

type
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
    tsiorClosed
  );

  TTcpAcceptResult = (
    tarAccepted,
    tarWouldBlock
  );

  ITcpStream = interface(IStream)
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000001}']
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
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

implementation

end.
