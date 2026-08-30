unit nextpas.core.ssh.window;

{** nextpas.core.ssh - 通道窗口可复用策略。
 *
 * 抽取 sync/async 通道中共用的窗口记账逻辑：
 *  - OurWindow: 我方授出的接收信用（初始窗口，消费过半回补）
 *  - PeerWindow: 对端授予的发送信用（OPEN_CONFIRMATION + WINDOW_ADJUST 累积）
 *  - 低水位回补、分片上限、信用入账/消费统一收口
 *  纯值语义 record，零堆分配，Inline 热路径。 *}

{$I nextpas.core.settings.inc}

interface

const
  SSH_WINDOW_LOW_WATER_DIVISOR = 2;

type
  TChannelWindow = record
  private
    FInitWindow: UInt32;
    FOurWindow: SizeUInt;
    FPeerWindow: SizeUInt;
    FPeerMaxPacket: UInt32;
  public
    procedure Init(AInitWindow, APeerWindow, APeerMaxPacket: UInt32);
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

implementation

procedure TChannelWindow.Init(AInitWindow, APeerWindow, APeerMaxPacket: UInt32);
begin
  FInitWindow := AInitWindow;
  FOurWindow := AInitWindow;
  FPeerWindow := APeerWindow;
  FPeerMaxPacket := APeerMaxPacket;
end;

function TChannelWindow.ShouldReplenish: Boolean;
begin
  Result := FOurWindow <= SizeUInt(FInitWindow) div SSH_WINDOW_LOW_WATER_DIVISOR;
end;

function TChannelWindow.ReplenishAmount: UInt32;
begin
  Result := UInt32(SizeUInt(FInitWindow) - FOurWindow);
end;

procedure TChannelWindow.Consume(ACount: SizeUInt; out ANeedAdjust: UInt32);
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

procedure TChannelWindow.Grant(ACount: UInt32);
begin
  Inc(FPeerWindow, SizeUInt(ACount));
end;

function TChannelWindow.CanSend(ACount: SizeUInt): Boolean;
begin
  Result := (FPeerWindow > 0) and (ACount <= FPeerWindow);
end;

function TChannelWindow.SliceSize(AWant: SizeUInt): SizeUInt;
begin
  Result := AWant;
  if Result > SizeUInt(FPeerMaxPacket) then Result := FPeerMaxPacket;
  if Result > FPeerWindow then Result := FPeerWindow;
end;

procedure TChannelWindow.DidSend(ACount: SizeUInt);
begin
  if ACount > FPeerWindow then FPeerWindow := 0
  else Dec(FPeerWindow, ACount);
end;

end.
