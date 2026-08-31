unit nextpas.core.ssh.transport;

{** nextpas.core.ssh - 版本交换与二进制包协议（RFC 4253 §4-§6）。
 *
 * 职责：
 *  - 协议版本串交换（容忍服务方前置文本行）
 *  - 包帧：padding 对齐、序列号维护、长度字段读写
 *  - 编解码器切换（NEWKEYS 之后）
 *
 * IO 缝隙为 io.intf.IReadWriteCloser：net.ITcpStream 与测试内存管道都满足。
 * 所有阻塞读在连接关闭时抛 sekIO。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.time.deadline,
  nextpas.core.time.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.transport.core,
  nextpas.core.ssh.kex;

type
  { 诊断钩子：非 nil 时逐包回调明文载荷（ATag='tx'/'rx'；互操作排障用，
    库内默认 nil 零开销）}
  TSshTransportDumpProc = procedure(const ATag: string; const APkt: TBytes);

var
  SshTransportDump: TSshTransportDumpProc = nil;

type
  TSshTransportState = (
    tstInit,            { 未开始 }
    tstVersionExchange, { 版本串交换中 }
    tstKexExchange,     { 密钥交换中（未加密帧）}
    tstEncrypted,       { 已切换到加密帧 }
    tstClosed
  );

  { 客户端方向传输层 }
  TSshClientTransport = class
  private
    FIO: IReadWriteCloser;
    FState: TSshTransportState;
    FOverallDeadline: TDeadline;
    FCore: TSshTransportCore;
    FServerIdent: string;
    FMyKexInitPayload: TBytes;
    procedure ApplyDeadlineToStream;
    procedure CheckRekeyOrDisconnect;
    procedure SendRaw(const ABytes: TBytes);
    procedure ReadFull(var ABuf: TBytes; AOffset, ACount: SizeUInt);
    function ReadLineRaw: string;
  public
    constructor Create(const AIO: IReadWriteCloser);
    destructor Destroy; override;

    { 发送我方版本串，读服务方版本串（不含行终止符）。
      要求服务方为 SSH-2.x，否则 sekUnsupported。}
    function ExchangeVersions: string;

    { 构造发送 KEXINIT；返回我方完整载荷（供 H 计算保留）。}
    function SendKexInit(const ACookie: TBytes): TBytes;
    function SendKexInitEx(const ACookie: TBytes; ACompress: Boolean): TBytes;

    { 协商后记录压缩算法，由 ApplyNewKeys/EnableDelayedCompression 按时机激活 }
    procedure SetNegotiatedCompression(const ANeg: TSshNegotiated);
    procedure EnableCompression;
    function IsCompressionEnabled: Boolean;
    { Rekey / KeepAlive（S24）}
    procedure ConfigureRekey(ABytes: UInt64; AIntervalMs: Integer);
    function ShouldRekey: Boolean;
    procedure SendIgnore(const AData: TBytes); overload;
    procedure SendIgnore; overload;
    procedure ResetRekeyCounters;

    { 帧化发送一条消息载荷（含消息号字节）}
    procedure SendPacket(const APayload: TBytes);

    { 阻塞读取下一条消息，返回载荷（含消息号字节）}
    function ReadPacket: TBytes;

    { NEWKEYS 之后切换双向编解码器 }
    procedure ApplyNewKeys(const ANegotiated: TSshNegotiated;
      const AIvCs, AKeyCs, AMacCs, AIvSc, AKeySc, AMacSc: TBytes);

    { 发送 DISCONNECT 并关闭底层流 }
    procedure Disconnect(AReason: UInt32; const ADesc: string);
    procedure SetOverallDeadline(const ADeadline: TDeadline);
    procedure Close;

    property State: TSshTransportState read FState;
    property ServerIdent: string read FServerIdent;
    property MyKexInitPayload: TBytes read FMyKexInitPayload;
  end;

implementation

uses
  nextpas.core.crypto.random,
  nextpas.core.net.intf,
  nextpas.core.mem.secure;

function UInt32Bytes(AValue: UInt32): TBytes;
begin
  SetLength(Result, 4);
  Result[0] := Byte(AValue shr 24);
  Result[1] := Byte(AValue shr 16);
  Result[2] := Byte(AValue shr 8);
  Result[3] := Byte(AValue);
end;

const
  DISCONNECT_PROTOCOL_VERSION = 2;
  DISCONNECT_CONNECTION_LOST = 10;
  DISCONNECT_KEY_EXCHANGE_FAILED = 3;
  DISCONNECT_MAC_ERROR = 5;
  SSH_SEQ_REKEY_THRESHOLD = UInt32($FFFFFF00);
  RECV_HEADER_SIZE = 4;

constructor TSshClientTransport.Create(const AIO: IReadWriteCloser);
begin
  inherited Create;
  FIO := AIO;
  FState := tstInit;
  FCore := TSshTransportCore.Create;
  FOverallDeadline := TDeadline.Infinite;
end;

destructor TSshClientTransport.Destroy;
begin
  try Close; except end;
  FCore.Free;
  inherited Destroy;
end;

procedure TSshClientTransport.Close;
begin
  if FState <> tstClosed then
  begin
    try if FIO <> nil then FIO.Close; except end;
    FState := tstClosed;
  end;
end;

procedure TSshClientTransport.SetOverallDeadline(const ADeadline: TDeadline);
begin
  FOverallDeadline := ADeadline;
  ApplyDeadlineToStream;
end;

procedure TSshClientTransport.ApplyDeadlineToStream;
var LStream: ITcpStream;
begin
  if Supports(FIO, ITcpStream, LStream) then
  begin
    if not FOverallDeadline.IsInfinite then
      LStream.SetReadDeadline(FOverallDeadline)
    else
      LStream.SetReadDeadline(TDeadline.Infinite);
  end;
end;

procedure TSshClientTransport.CheckRekeyOrDisconnect;
begin
  if (FState = tstEncrypted) and ((FCore.SendSeq >= SSH_SEQ_REKEY_THRESHOLD) or (FCore.RecvSeq >= SSH_SEQ_REKEY_THRESHOLD)) then
  begin
    try Disconnect(DISCONNECT_KEY_EXCHANGE_FAILED, 'ssh transport: sequence exhausted, rekey required'); except end;
    raise ESSHError.Create(sekDisconnect, 'ssh transport: rekey required (seq exhausted)');
  end;
end;

procedure TSshClientTransport.SendRaw(const ABytes: TBytes);
var
  LWritten: SizeUInt;
begin
  if Length(ABytes) > 0 then
  begin
    LWritten := FIO.Write(ABytes[0], SizeUInt(Length(ABytes)));
    if LWritten <> SizeUInt(Length(ABytes)) then
      raise ESSHError.Create(sekIO, 'ssh transport: short write');
  end;
end;

procedure TSshClientTransport.ReadFull(var ABuf: TBytes; AOffset, ACount: SizeUInt);
var
  LGot: SizeUInt;
begin
  ApplyDeadlineToStream;
  while ACount > 0 do
  begin
    if (not FOverallDeadline.IsInfinite) and FOverallDeadline.IsExpired then
      raise ESSHError.Create(sekTimeout, 'ssh transport: read deadline exceeded');
    LGot := FIO.Read(ABuf[AOffset], ACount);
    if LGot = 0 then
      raise ESSHError.Create(sekIO, 'ssh transport: connection closed by peer');
    Inc(AOffset, LGot);
    Dec(ACount, LGot);
    if (not FOverallDeadline.IsInfinite) and FOverallDeadline.IsExpired and (ACount > 0) then
      raise ESSHError.Create(sekTimeout, 'ssh transport: read deadline exceeded');
  end;
end;

function TSshClientTransport.ReadLineRaw: string;
var
  LB: TBytes;
  LTotal: Integer;
  LByte: Byte;
begin
  SetLength(LB, 0);
  LTotal := 0;
  repeat
    if (not FOverallDeadline.IsInfinite) and FOverallDeadline.IsExpired then
      raise ESSHError.Create(sekTimeout, 'ssh transport: ident deadline exceeded');
    { 按需扩容后逐字节读（ReadFull 不负责增长缓冲）}
    if SizeUInt(LTotal) >= SizeUInt(Length(LB)) then
      SetLength(LB, SizeUInt(Length(LB)) + 64);
    ReadFull(LB, LTotal, 1);
    LByte := LB[LTotal];
    Inc(LTotal);
    if LTotal > SSH_IDENT_MAX_LINE then
      raise ESSHError.Create(sekProtocol, 'ssh transport: ident banner too long');
  until LByte = 10;  { LF }
  { 去 CR 与 LF }
  while (LTotal > 0) and ((LB[LTotal - 1] = 13) or (LB[LTotal - 1] = 10)) do
    Dec(LTotal);
  SetLength(Result, LTotal);
  if LTotal > 0 then
    Move(LB[0], PByte(PChar(Result))^, SizeUInt(LTotal));
end;

function TSshClientTransport.ExchangeVersions: string;
var
  LIdent: TBytes;
  LLines: Integer;
begin
  if FState <> tstInit then
    raise ESSHError.Create(sekProtocol, 'ssh transport: versions already exchanged');

  SetLength(LIdent, Length(SSH_PROTOCOL_VERSION) + 2);
  Move(PByte(PChar(SSH_PROTOCOL_VERSION))^, LIdent[0], SizeUInt(Length(SSH_PROTOCOL_VERSION)));
  LIdent[Length(SSH_PROTOCOL_VERSION)] := 13;
  LIdent[Length(SSH_PROTOCOL_VERSION) + 1] := 10;
  SendRaw(LIdent);

  FState := tstVersionExchange;

  LLines := 0;
  repeat
    Result := ReadLineRaw;
    Inc(LLines);
    if LLines > 32 then
      raise ESSHError.Create(sekProtocol, 'ssh transport: too many pre-ident lines');
  until Copy(Result, 1, 4) = 'SSH-';

  if (Copy(Result, 1, 7) <> 'SSH-2.0') and (Copy(Result, 1, 8) <> 'SSH-1.99') then
    raise ESSHError.Create(sekUnsupported,
      'ssh transport: peer is not SSH-2.0 ("' + Result + '")');
  FServerIdent := Result;
  FState := tstKexExchange;
end;

function TSshClientTransport.SendKexInit(const ACookie: TBytes): TBytes;
begin
  Result := SendKexInitEx(ACookie, False);
end;

function TSshClientTransport.SendKexInitEx(const ACookie: TBytes; ACompress: Boolean): TBytes;
begin
  FMyKexInitPayload := SshBuildKexInitPayloadEx(ACookie, ACompress);
  SendPacket(FMyKexInitPayload);
  Result := FMyKexInitPayload;
end;

procedure TSshClientTransport.SetNegotiatedCompression(const ANeg: TSshNegotiated);
begin
  FCore.SetNegotiatedCompression(ANeg);
end;

procedure TSshClientTransport.EnableCompression;
begin
  FCore.EnableCompression;
end;

function TSshClientTransport.IsCompressionEnabled: Boolean;
begin
  Result := FCore.IsCompressionEnabled;
end;

procedure TSshClientTransport.ConfigureRekey(ABytes: UInt64; AIntervalMs: Integer);
begin
  FCore.ConfigureRekey(ABytes, AIntervalMs);
end;

function TSshClientTransport.ShouldRekey: Boolean;
begin
  Result := FCore.ShouldRekey(FState = tstEncrypted);
end;

procedure TSshClientTransport.ResetRekeyCounters;
begin
  FCore.ResetRekeyCounters;
end;

procedure TSshClientTransport.SendIgnore(const AData: TBytes);
var LW: TsshWriter;
begin
  LW := TsshWriter.Create(1 + 4 + Length(AData));
  try
    LW.PutByte(SSH_MSG_IGNORE);
    LW.PutStringBytes(AData);
    SendPacket(LW.ToBytes);
  finally LW.Free; end;
end;

procedure TSshClientTransport.SendIgnore;
begin
  SendIgnore(nil);
end;

procedure TSshClientTransport.SendPacket(const APayload: TBytes);
var
  LWire: TBytes;
begin
  if FState = tstClosed then
    raise ESSHError.Create(sekIO, 'ssh transport: closed');
  CheckRekeyOrDisconnect;
  if (FState = tstEncrypted) and (FCore.SendSeq >= SSH_SEQ_REKEY_THRESHOLD) then
  begin
    try Disconnect(DISCONNECT_KEY_EXCHANGE_FAILED, 'ssh transport: send seq exhausted'); except end;
    raise ESSHError.Create(sekDisconnect, 'ssh transport: rekey required (seq)');
  end;
  if SshTransportDump <> nil then
    SshTransportDump('tx', APayload);
  if FCore.SendSeq >= SSH_SEQ_REKEY_THRESHOLD then
  begin
    try Disconnect(DISCONNECT_KEY_EXCHANGE_FAILED, 'ssh transport: seq threshold reached'); except end;
    raise ESSHError.Create(sekDisconnect, 'ssh transport: seq threshold');
  end;
  LWire := FCore.EncodePacket(APayload);
  SendRaw(LWire);
end;

function TSshClientTransport.ReadPacket: TBytes;
var
  LHeader, LTrailer, LPacket: TBytes;
  LBodyLen: UInt32;
begin
  if FState = tstClosed then
    raise ESSHError.Create(sekIO, 'ssh transport: closed');
  try
    SetLength(LHeader, RECV_HEADER_SIZE);
    ReadFull(LHeader, 0, RECV_HEADER_SIZE);
    LBodyLen := FCore.BodyLengthFromHeader(LHeader);
  if SshTransportDump <> nil then
  begin
    SshTransportDump('rseq', UInt32Bytes(FCore.RecvSeq));
    SshTransportDump('rhdr', LHeader);
    SshTransportDump('rlen', UInt32Bytes(LBodyLen));
  end;
  if (LBodyLen < 1) or (LBodyLen > SSH_MAX_RECEIVE_PACKET) then
    raise ESSHError.Create(sekProtocol,
      'ssh transport: unreasonable packet length ' + IntToStr(LBodyLen));

    SetLength(LTrailer, FCore.TrailerSize(LBodyLen));
    ReadFull(LTrailer, 0, SizeUInt(Length(LTrailer)));
    SetLength(LPacket, 4 + SizeUInt(Length(LTrailer)));
    Move(LHeader[0], LPacket[0], 4);
    if Length(LTrailer) > 0 then
      Move(LTrailer[0], LPacket[4], SizeUInt(Length(LTrailer)));
    Result := FCore.DecodePacket(LPacket);
  except
    on E: ESSHError do
    begin
      if E.Kind = sekCrypto then
        try Disconnect(DISCONNECT_MAC_ERROR, E.Message); except end
      else
        try Disconnect(DISCONNECT_CONNECTION_LOST, E.Message); except end;
      FState := tstClosed;
      raise;
    end;
    on E: Exception do
    begin
      try Disconnect(DISCONNECT_CONNECTION_LOST, E.Message); except end;
      FState := tstClosed;
      raise ESSHError.Create(sekIO, E.Message);
    end;
  end;
  if FCore.RecvSeq >= SSH_SEQ_REKEY_THRESHOLD then
  begin
    try Disconnect(DISCONNECT_KEY_EXCHANGE_FAILED, 'ssh transport: recv seq exhausted'); except end;
  end;
  if SshTransportDump <> nil then
    SshTransportDump('rx', Result);
end;

procedure TSshClientTransport.ApplyNewKeys(const ANegotiated: TSshNegotiated;
  const AIvCs, AKeyCs, AMacCs, AIvSc, AKeySc, AMacSc: TBytes);
begin
  if FState <> tstKexExchange then
    raise ESSHError.Create(sekProtocol, 'ssh transport: NEWKEYS outside kex');
  FCore.ApplyNewKeys(ANegotiated, AIvCs, AKeyCs, AMacCs, AIvSc, AKeySc, AMacSc);
  FState := tstEncrypted;
end;

procedure TSshClientTransport.Disconnect(AReason: UInt32; const ADesc: string);
var
  LW: TsshWriter;
begin
  if FState in [tstClosed] then
    Exit;
  try
    LW := TsshWriter.Create(64);
    try
      LW.PutByte(SSH_MSG_DISCONNECT);
      LW.PutUInt32(AReason);
      LW.PutStringText(ADesc);
      LW.PutStringText('');
      SendPacket(LW.ToBytes);
    finally
      LW.Free;
    end;
  except
    { 对端可能已断开；关闭动作不受影响 }
  end;
  Close;
end;

end.
