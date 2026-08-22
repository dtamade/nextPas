unit nextpas.core.net.server.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.platform.io.base,
  nextpas.core.time.deadline;

type
  TTcpServerPollResult = (
    tsprWait,
    tsprDone
  );

  ITcpServerWork = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000005}']
    function Execute: TTcpServerConnOwnership;
  end;

  ITcpServerWorkCompletion = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000006}']
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  ITcpServerWorkerHandoff = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000007}']
    function Submit(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
    procedure Shutdown;
  end;

  ITcpServerSession = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000003}']
    function Run: TTcpServerConnOwnership;
  end;

  ITcpServerSessionContext = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000008}']
    function WorkerHandoff: ITcpServerWorkerHandoff;
    { 将已 hijack 的连接（HTTP 升级等）以 ANewSession 重新托管到本 poll target。
      迁移在 reactor 线程执行（经 completion 队列提交）：摘除当前会话的 poll
      注册（不关连接、不 RestoreBlocking），以 ANewSession 重挂（SetBlocking(False)
      + 新 poll 事件）。worker 线程可调；返回 False 表示不可迁移
      （未托管 / 已 detach / 已 drain）。成功后 ANewSession 及连接由 poll 容器接管。 }
    function HandoffHijackedConn(const AConn: ITcpStream;
      const ANewSession: ITcpServerSession): Boolean;
    { 将在途的 hijack 迁移提交到 reactor 线程执行（仅可由 poll 推进方 /
      reactor 线程调用，如 http 让位完成后）。返回 True 表示确有迁移被提交；
      无在途迁移（未登记或已提交）返回 False。 }
    function SubmitHijackMigration: Boolean;
  end;

  { worker 线程可用的异步 WS 帧提交：经 poll 容器 completion 队列在 reactor
    线程交付给目标会话（SendText 等仅限会话推进方调用的语义）。实现：
    TTcpServerPollSessionContext；由升级函数注入 TNetWsFrameSession。 }
  IWebSocketFrameWorkerPush = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000018}']
    procedure SubmitSendText(const AText: string);
    { 批量发文本帧：1 次 completion 入队 + 1 次唤醒承载整批，reactor 循环
      逐帧 SendText（数据写侧不可省，省的是控制面 N-1 次 completion 分配/
      MPSC 入队/FWake——订阅广播等大批量推送路径的吞吐关键）。 }
    procedure SubmitSendTexts(const ATexts: array of string);
    procedure SubmitSendBinary(const APayload: array of Byte);
    procedure SubmitSendClose(const ACode: UInt16; const AReason: string);
  end;

  { 阻塞 WebSocket 会话的 shutdown 通知句柄。实现：http.websocket 模块
    （每服务端会话一个，经 IWsServerShutdownRegistry 登记）。
    ShutdownAll 先 NotifyShutdown（waitable cancel token 唤醒阻塞在
    ReadMessage 的连接线程——mid-poll 设置读 deadline 无效，poll 在旧的
    无限超时上继续阻塞；close frame 1001 由会话收尾路径补发），
    再 WaitFinished 等待收尾；超时后 ForceClose 强关底层连接。 }
  IWsServerShutdownNotifier = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000013}']
    { 会话已收尾（连接线程侧调用，幂等）：从注册表摘除并释放底层引用，
      唤醒 WaitFinished 等待者。与 ShutdownAll 并发安全。 }
    procedure Detach;
    procedure NotifyShutdown;
    function WaitFinished(const ATimeoutNs: Int64): Boolean;
    procedure ForceClose;
  end;

  { 服务器级 WS shutdown 注册表（threaded 后端每服务器一个，经
    ITcpServerSessionContext 暴露给 http 层；阻塞升级路径登记会话）。
    Shutdown 时服务器对全部登记会话执行优雅收尾。 }
  IWsServerShutdownRegistry = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000014}']
    procedure RegisterShutdownNotifier(const ANotifier: IWsServerShutdownNotifier);
    procedure UnregisterShutdownNotifier(const ANotifier: IWsServerShutdownNotifier);
    procedure ShutdownAll(const ATimeoutNs: Int64);
  end;

  ITcpServerPollDrivenSession = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000010}']
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
  end;

  ITcpServerPollDrivenSessionWithDeadline = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000011}']
    function WakeDeadline: TDeadline;
  end;

  ITcpServerSessionFactory = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000004}']
    function NewSession(const AConn: ITcpStream): ITcpServerSession;
  end;

  ITcpServerSessionFactoryWithContext = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000009}']
    function NewSession(const AConn: ITcpStream;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
  end;

  ITcpServerHandler = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000001}']
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
  end;

  ITcpServer = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000002}']
    procedure ListenAndServe(const AAddr: string; const APort: UInt16;
      const AHandler: ITcpServerHandler);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

implementation

end.
