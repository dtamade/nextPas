unit nextpas.core.ssh.sftp.wire;

{** nextpas.core.ssh.sftp.wire - 通道线材（CHANNEL_DATA ↔ SFTP 包流重组器）。
 *
 * 单职责：把 TSshChannel 的流式 DATA 切为 4B 长度前缀 SFTP 包流。
 * 性能：委托 bytes.framing.TWireBuffer 单源（BytesEnsureCapacity 几何 + FOff 零拷贝 + 32KB/8KB 懒压实），inline 热路径，复用 bytes.ops Move 单源，不自实现 Move。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.sftp.base,
  nextpas.core.ssh.sftp.intf,
  nextpas.core.ssh.channel;

type
  TSshChannelWire = class(TInterfacedObject, ISftpWire)
  private
    FChan: TSshChannel;
    FWire: nextpas.core.bytes.framing.TWireBuffer;
  public
    constructor Create(AChannel: TSshChannel);
    destructor Destroy; override;
    procedure Send(const APacket: TBytes);
    function Recv(ATimeoutMs: Integer): TBytes;
  end;

implementation

uses
  nextpas.core.bytes.framing,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer;

constructor TSshChannelWire.Create(AChannel: TSshChannel);
begin
  inherited Create;
  FChan := AChannel;
  FWire.Clear;
end;

destructor TSshChannelWire.Destroy;
begin
  { 通道所有权在 TSshFileSystem：线材仅引用；FWire 为 record 值语义无堆泄漏 }
  inherited Destroy;
end;

procedure TSshChannelWire.Send(const APacket: TBytes);
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(4 + Length(APacket));
  try
    LW.PutUInt32(UInt32(Length(APacket)));
    LW.PutRaw(APacket);
    FChan.SendData(LW.ToBytes);
  finally
    LW.Free;
  end;
end;

function TSshChannelWire.Recv(ATimeoutMs: Integer): TBytes;
var
  LChunk: TBytes;
  LExt: Boolean;
  LLen: UInt32;
begin
  while not FWire.HasHeader do
  begin
    if not FChan.PumpData(LChunk, LExt) then
      raise ESSHError.Create(sekIO, 'sftp: channel closed by peer');
    if Length(LChunk) > 0 then
      FWire.Append(LChunk);
  end;
  if not FWire.TryPeekFrameLength(LLen, SFTP_MAX_PACKET_SIZE) then
    raise ESSHError.Create(sekProtocol,
      'sftp: unreasonable packet length');
  while not FWire.HasCompleteFrame(SFTP_MAX_PACKET_SIZE) do
  begin
    if not FChan.PumpData(LChunk, LExt) then
      raise ESSHError.Create(sekIO, 'sftp: channel closed mid-packet');
    if Length(LChunk) > 0 then
      FWire.Append(LChunk);
    if (FWire.BufferedLen >= 4) and (not FWire.TryPeekFrameLength(LLen, SFTP_MAX_PACKET_SIZE)) then
      raise ESSHError.Create(sekProtocol, 'sftp: unreasonable packet length');
  end;
  if not FWire.TryTakeFrame(Result, SFTP_MAX_PACKET_SIZE) then
    raise ESSHError.Create(sekProtocol, 'sftp: incomplete packet');
end;

end.
