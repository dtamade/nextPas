unit nextpas.core.net.server.ws;
{**
 * @desc 事件驱动 WebSocket 帧处理门面：帧编解码原语 + poll-driven 帧会话。
 *       面向事件驱动后端（epoll/kqueue/iocp readiness 路径）复用同一套
 *       RFC 6455 帧语义。详见单元头注释与 docs/net/README.md。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.server.ws.frame,
  nextpas.core.net.server.ws.session;

type
  TNetWsRole = nextpas.core.net.server.ws.frame.TNetWsRole;
  TNetWsFrame = nextpas.core.net.server.ws.frame.TNetWsFrame;
  TNetWsDecodeCode = nextpas.core.net.server.ws.frame.TNetWsDecodeCode;
  TNetWsEncodeCode = nextpas.core.net.server.ws.frame.TNetWsEncodeCode;
  TNetWsFrameDecoder = nextpas.core.net.server.ws.frame.TNetWsFrameDecoder;
  TNetWsFrameEncoder = nextpas.core.net.server.ws.frame.TNetWsFrameEncoder;

  TNetWsSessionEvent = nextpas.core.net.server.ws.session.TNetWsSessionEvent;
  IWebSocketFrameSink = nextpas.core.net.server.ws.session.IWebSocketFrameSink;
  IWebSocketFrameSession = nextpas.core.net.server.ws.session.IWebSocketFrameSession;
  TNetWsFrameSessionOptions = nextpas.core.net.server.ws.session.TNetWsFrameSessionOptions;
  TNetWsFrameSession = nextpas.core.net.server.ws.session.TNetWsFrameSession;

implementation

end.