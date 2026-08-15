program test_net_server_kqueue_gate;

{$I nextpas.core.settings.inc}

{ 编译门禁（B8）：在 NEXTPAS_FORCE_HOST_DARWIN 下证明
  1) net/server kqueue 后端的事件驱动接线（NewTcpKqueueServer →
     io.reactor.kqueue 的 AsyncAccept / AsyncRecv(MSG_PEEK) / PollWait）
     可编译；
  2) 事件驱动 WS 帧层（ws.frame / ws.session / ws 门面）在 kqueue
     平台同样可编译（同一抽象跨后端复用）。
  -Cn 不链接，故不运行；Linux 上 kqueue 分支不参与编译，仅静态/编译验证。
  macOS/FreeBSD runtime smoke 待真机（B8 后续）。 }

uses
  nextpas.core.io.base,
  nextpas.core.io.reactor.kqueue,
  nextpas.core.net.server,
  nextpas.core.net.server.kqueue,
  nextpas.core.net.server.ws,
  nextpas.core.net.server.ws.frame,
  nextpas.core.net.server.ws.session,
  nextpas.core.time.base,
  nextpas.core.websocket.base;

var
  GServer: ITcpServer;
  GReactor: TKqueueReactor;
  GDecoder: TNetWsFrameDecoder;
  GFrame: TNetWsFrame;
  GOpts: TNetWsFrameSessionOptions;

procedure TouchKqueueEventDrivenWiring;
begin
  { 事件驱动接线工厂：编译期校验 kqueue 分支接线存在 }
  GServer := NewTcpKqueueServer(TTcpServerOptions.Default);
  if GServer = nil then
    Halt(2);
  { reactor 层新 API：超时等待（kqueue 后端主循环依赖 PollWait） }
  GReactor := TKqueueReactor.Create;
  if GReactor.PollWait(-1) < 0 then
    Halt(3);
  GReactor.Close;
  { 事件驱动 WS 帧层：跨 kqueue 平台复用 }
  GDecoder := TNetWsFrameDecoder.Create(False, 4096, 8192);
  if GDecoder.TryDecode(GFrame) <> nwsDecodeNeedMore then
    Halt(4);
  GOpts := TNetWsFrameSessionOptions.Default.WithIdleTimeout(
    TDuration.FromMilliseconds(150));
  if GOpts.IdleTimeout.AsNanoseconds <= 0 then
    Halt(5);
end;

begin
  TouchKqueueEventDrivenWiring;
end.