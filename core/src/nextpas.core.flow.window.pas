unit nextpas.core.flow.window;

{** nextpas.core.flow.window - 通用流控窗口（零堆窗口管理）。
 *
 *  从 `nextpas.core.ssh.window.TChannelWindow` 抽离的通用记录：
 *  - OurWindow: 本端授予接收信用（初始窗口，消费过半回补）
 *  - PeerWindow: 对端授予发送信用（WINDOW_ADJUST 累积）
 *  L1，仅依赖 `nextpas.core.base.SizeUInt`，纯值语义 `record`，零堆分配，
 *  热路径 `inline`，与 `bytes.ops` 单源（外层 Move 单源，不自实现拷贝）。
 *  供 `ssh.channel/channel.async/proxyjump.async` 与 `http.h2`/`quic` 复用。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.flow.window.base;

const
  FLOW_WINDOW_LOW_WATER_DIVISOR = nextpas.core.flow.window.base.FLOW_WINDOW_LOW_WATER_DIVISOR;

type
  TFlowWindow = record
  private
    FInitWindow: UInt32;
    FOurWindow: SizeUInt;
    FPeerWindow: SizeUInt;
    FPeerMaxPacket: UInt32;
  public
    procedure Init(AInitWindow, APeerWindow, APeerMaxPacket: UInt32); inline;
    procedure SetPeer(APeerWindow, APeerMaxPacket: UInt32); inline;
    function ShouldReplenish: Boolean; inline;
    function ReplenishAmount: UInt32; inline;
    procedure Consume(ACount: SizeUInt; out ANeedAdjust: UInt32); inline;
    procedure Grant(ACount: UInt32); inline;
    function CanSend(ACount: SizeUInt): Boolean; inline;
    function SliceSize(AWant: SizeUInt): SizeUInt; inline;
    procedure DidSend(ACount: SizeUInt); inline;
    property OurWindow: SizeUInt read FOurWindow;
    property PeerWindow: SizeUInt read FPeerWindow;
    property PeerMaxPacket: UInt32 read FPeerMaxPacket;
    property InitWindow: UInt32 read FInitWindow;
  end;

  { 兼容别名：ssh 侧历史名称，转发至通用窗口，零成本 alias }
  TChannelWindow = TFlowWindow;

implementation

procedure TFlowWindow.Init(AInitWindow, APeerWindow, APeerMaxPacket: UInt32); inline;
begin
  FInitWindow := AInitWindow;
  FOurWindow := AInitWindow;
  FPeerWindow := APeerWindow;
  FPeerMaxPacket := APeerMaxPacket;
end;

function TFlowWindow.ShouldReplenish: Boolean; inline;
begin
  Result := FOurWindow <= SizeUInt(FInitWindow) div FLOW_WINDOW_LOW_WATER_DIVISOR;
end;

function TFlowWindow.ReplenishAmount: UInt32; inline;
begin
  Result := UInt32(SizeUInt(FInitWindow) - FOurWindow);
end;

procedure TFlowWindow.Consume(ACount: SizeUInt; out ANeedAdjust: UInt32); inline;
var LGiveBack: SizeUInt;
begin
  ANeedAdjust := 0;
  if ACount > FOurWindow then
  begin
    LGiveBack := FOurWindow;
    FOurWindow := 0;
  end else
  begin
    Dec(FOurWindow, ACount);
    LGiveBack := 0;
  end;
  if ShouldReplenish then
  begin
    Inc(LGiveBack, SizeUInt(FInitWindow) - FOurWindow);
    FOurWindow := FInitWindow;
  end;
  if LGiveBack > 0 then ANeedAdjust := UInt32(LGiveBack);
end;

procedure TFlowWindow.SetPeer(APeerWindow, APeerMaxPacket: UInt32); inline;
begin
  FPeerWindow := APeerWindow;
  FPeerMaxPacket := APeerMaxPacket;
end;

procedure TFlowWindow.Grant(ACount: UInt32); inline;
begin
  Inc(FPeerWindow, SizeUInt(ACount));
end;

function TFlowWindow.CanSend(ACount: SizeUInt): Boolean; inline;
begin
  Result := (FPeerWindow > 0) and (ACount <= FPeerWindow);
end;

function TFlowWindow.SliceSize(AWant: SizeUInt): SizeUInt; inline;
begin
  Result := AWant;
  if Result > SizeUInt(FPeerMaxPacket) then Result := FPeerMaxPacket;
  if Result > FPeerWindow then Result := FPeerWindow;
end;

procedure TFlowWindow.DidSend(ACount: SizeUInt); inline;
begin
  if ACount > FPeerWindow then FPeerWindow := 0
  else Dec(FPeerWindow, ACount);
end;

end.
