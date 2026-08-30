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
  nextpas.core.io.intf,
  nextpas.core.text.conv,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.compress,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.rekey;

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
    FSendSeq: UInt32;
    FRecvSeq: UInt32;
    FSender: ISshPacketSender;
    FReceiver: ISshPacketReceiver;
    FServerIdent: string;
    FMyKexInitPayload: TBytes;
    FCompressor: ISshCompressor;
    FDecompressor: ISshCompressor;
    FCompressEnabled: Boolean;
    FNegotiatedCompCs: string;
    FNegotiatedCompSc: string;
    FRekey: TSshRekeyPolicy;
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

    procedure Close;

    property State: TSshTransportState read FState;
    property ServerIdent: string read FServerIdent;
    property MyKexInitPayload: TBytes read FMyKexInitPayload;
  end;

implementation

uses
  nextpas.core.crypto.random;

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
  RECV_HEADER_SIZE = 4;

constructor TSshClientTransport.Create(const AIO: IReadWriteCloser);
begin
  inherited Create;
  FIO := AIO;
  FState := tstInit;
  { 未协商密钥前走 none 编解码器（明文帧），NEWKEYS 后由 ApplyNewKeys 切换 }
  FSender := CreateSshPacketSender('', '', nil, nil, nil);
  FReceiver := CreateSshPacketReceiver('', '', nil, nil, nil);
  FRekey.Init(SSH_REKEY_BYTES, SSH_REKEY_INTERVAL_MS);
end;

destructor TSshClientTransport.Destroy;
begin
  inherited Destroy;
end;

procedure TSshClientTransport.Close;
begin
  if FState <> tstClosed then
  begin
    FIO.Close;
    FState := tstClosed;
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
  while ACount > 0 do
  begin
    LGot := FIO.Read(ABuf[AOffset], ACount);
    if LGot = 0 then
      raise ESSHError.Create(sekIO, 'ssh transport: connection closed by peer');
    Inc(AOffset, LGot);
    Dec(ACount, LGot);
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
    { 按需扩容后逐字节读（ReadFull 不负责增长缓冲）}
    if SizeUInt(LTotal) >= SizeUInt(Length(LB)) then
      SetLength(LB, SizeUInt(Length(LB)) + 64);
    ReadFull(LB, LTotal, 1);
    LByte := LB[LTotal];
    Inc(LTotal);
    if LTotal > SSH_IDENT_MAX_LINE * 8 then
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
  FNegotiatedCompCs := ANeg.CompCs;
  FNegotiatedCompSc := ANeg.CompSc;
  FCompressEnabled := False;
  { immediate zlib activates now; delayed waits for EnableCompression }
  if (FNegotiatedCompCs = SSH_COMP_ZLIB) or (FNegotiatedCompSc = SSH_COMP_ZLIB) then
    EnableCompression
  else if (FNegotiatedCompCs = SSH_COMP_NONE) and (FNegotiatedCompSc = SSH_COMP_NONE) then
  begin
    FCompressor := nil;
    FDecompressor := nil;
  end;
end;

procedure TSshClientTransport.EnableCompression;
begin
  if FCompressEnabled then Exit;
  if (FNegotiatedCompCs = SSH_COMP_NONE) and (FNegotiatedCompSc = SSH_COMP_NONE) then Exit;
  if (FCompressor = nil) or (FDecompressor = nil) then
  begin
    FCompressor := CreateSshZlibCompressor;
    FDecompressor := FCompressor; // single object holds both streams
  end;
  FCompressEnabled := True;
end;

function TSshClientTransport.IsCompressionEnabled: Boolean;
begin
  Result := FCompressEnabled;
end;

procedure TSshClientTransport.ConfigureRekey(ABytes: UInt64; AIntervalMs: Integer);
begin
  FRekey.Init(ABytes, AIntervalMs);
end;

function TSshClientTransport.ShouldRekey: Boolean;
begin
  Result := FRekey.ShouldRekey(FState = tstEncrypted);
end;

procedure TSshClientTransport.ResetRekeyCounters;
begin
  FRekey.Reset;
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
  LPayloadLen, LPad, LBodyLen, LAad: SizeUInt;
  LBlock: Integer;
  LBody, LWire: TBytes;
  LOut: TBytes;
begin
  if FState = tstClosed then
    raise ESSHError.Create(sekIO, 'ssh transport: closed');
  if SshTransportDump <> nil then
    SshTransportDump('tx', APayload);
  LOut := APayload;
  if FCompressEnabled and (FCompressor <> nil) and (FNegotiatedCompCs <> SSH_COMP_NONE) then
    LOut := FCompressor.Compress(APayload);
  LPayloadLen := SizeUInt(Length(LOut));
  LBlock := FSender.PaddingBlock;
  { OpenSSH packet.c：AEAD/EtM 模式长度字段不进对齐区（len -= aadlen），
    接收端强制 packlen % blocksize = 0 }
  LAad := SizeUInt(FSender.AadLen);
  LPad := SizeUInt(LBlock) -
    ((SizeUInt(4 + 1) + LPayloadLen - LAad) mod SizeUInt(LBlock));
  if LPad < SSH_MIN_PADDING then
    Inc(LPad, SizeUInt(LBlock));
  LBodyLen := 1 + LPayloadLen + LPad;

  SetLength(LBody, LBodyLen);
  LBody[0] := Byte(LPad);
  if LPayloadLen > 0 then
    Move(LOut[0], LBody[1], LPayloadLen);
  if not SecureRandomBytes(@LBody[1 + LPayloadLen], Integer(LPad)) then
    FillChar(LBody[1 + LPayloadLen], LPad, $2A);

  LWire := FSender.Protect(LBody, FSendSeq);
  Inc(FSendSeq);  { uint32 自然回绕 }
  FRekey.Account(UInt64(Length(APayload)));
  SendRaw(LWire);
end;

function TSshClientTransport.ReadPacket: TBytes;
var
  LHeader, LTrailer, LPacket, LBody: TBytes;
  LBodyLen, LPadLen, LPayloadLen: UInt32;
begin
  if FState = tstClosed then
    raise ESSHError.Create(sekIO, 'ssh transport: closed');

  SetLength(LHeader, RECV_HEADER_SIZE);
  ReadFull(LHeader, 0, RECV_HEADER_SIZE);
  LBodyLen := FReceiver.BodyLengthFromHeader(FRecvSeq, LHeader);
  if SshTransportDump <> nil then
  begin
    SshTransportDump('rseq', UInt32Bytes(FRecvSeq));
    SshTransportDump('rhdr', LHeader);
    SshTransportDump('rlen', UInt32Bytes(LBodyLen));
  end;
  if (LBodyLen < 1) or (LBodyLen > SSH_MAX_RECEIVE_PACKET) then
    raise ESSHError.Create(sekProtocol,
      'ssh transport: unreasonable packet length ' + IntToStr(LBodyLen));

  SetLength(LTrailer, FReceiver.TrailerSize(LBodyLen));
  ReadFull(LTrailer, 0, SizeUInt(Length(LTrailer)));
  { 编解码器契约：Unprotect 接收完整线上包（含长度字段）}
  SetLength(LPacket, 4 + SizeUInt(Length(LTrailer)));
  Move(LHeader[0], LPacket[0], 4);
  Move(LTrailer[0], LPacket[4], SizeUInt(Length(LTrailer)));
  LBody := FReceiver.Unprotect(FRecvSeq, LPacket);
  Inc(FRecvSeq);

  LPadLen := LBody[0];
  if (LPadLen < SSH_MIN_PADDING) or (LPadLen >= LBodyLen) then
    raise ESSHError.Create(sekProtocol, 'ssh transport: bad padding length');
  LPayloadLen := LBodyLen - 1 - LPadLen;
  Result := Copy(LBody, 1, SizeInt(LPayloadLen));
  if FCompressEnabled and (FDecompressor <> nil) and (FNegotiatedCompSc <> SSH_COMP_NONE) then
    Result := FDecompressor.Decompress(Result);
  FRekey.Account(UInt64(Length(Result)));
  if SshTransportDump <> nil then
    SshTransportDump('rx', Result);
end;

procedure TSshClientTransport.ApplyNewKeys(const ANegotiated: TSshNegotiated;
  const AIvCs, AKeyCs, AMacCs, AIvSc, AKeySc, AMacSc: TBytes);
begin
  if FState <> tstKexExchange then
    raise ESSHError.Create(sekProtocol, 'ssh transport: NEWKEYS outside kex');
  FSender := CreateSshPacketSender(ANegotiated.EncCs, ANegotiated.MacCs,
    AKeyCs, AIvCs, AMacCs);
  FReceiver := CreateSshPacketReceiver(ANegotiated.EncSc, ANegotiated.MacSc,
    AKeySc, AIvSc, AMacSc);
  FState := tstEncrypted;
  ResetRekeyCounters;
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
