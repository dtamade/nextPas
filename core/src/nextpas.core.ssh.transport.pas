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
    FReadAhead: TBytes;
    FReadAheadPos: SizeUInt;
    FReadBuf: TBytes;
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
  nextpas.core.exception,
  nextpas.core.base.utils,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.crypto.random,
  nextpas.core.ssh.net.ffi,
  nextpas.core.mem.secure;

// 单源：bytes.binary.WriteUInt32BE inline 零拷贝（单 Move，不手写移位），bytes.ops 单源外层 Move 复用
function UInt32Bytes(AValue: UInt32): TBytes; inline;
begin
  SetLength(Result, 4);
  WriteUInt32BE(PByte(@Result[0]), AValue);
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
  if Length(FReadAhead) > 0 then
    FillChar(FReadAhead[0], SizeUInt(Length(FReadAhead)), 0);
  SetLength(FReadAhead, 0);
  FReadAheadPos := 0;
  if Length(FReadBuf) > 0 then
    FillChar(FReadBuf[0], SizeUInt(Length(FReadBuf)), 0);
  SetLength(FReadBuf, 0);
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
  if Length(FReadAhead) > 0 then
    FillChar(FReadAhead[0], SizeUInt(Length(FReadAhead)), 0);
  SetLength(FReadAhead, 0);
  FReadAheadPos := 0;
  if Length(FReadBuf) > 0 then
    FillChar(FReadBuf[0], SizeUInt(Length(FReadBuf)), 0);
  SetLength(FReadBuf, 0);
end;

procedure TSshClientTransport.SetOverallDeadline(const ADeadline: TDeadline);
begin
  FOverallDeadline := ADeadline;
  ApplyDeadlineToStream;
end;

procedure TSshClientTransport.ApplyDeadlineToStream; inline;
begin
  // 单缝隙：经 ssh.net.ffi 薄转发，不直连 net.intf；inline 零拷贝，外层 try-finally 释放不丢
  SshSetReadDeadline(FIO, FOverallDeadline);
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
  LGot, LFromCache: SizeUInt;
begin
  ApplyDeadlineToStream;
  while ACount > 0 do
  begin
    if (not FOverallDeadline.IsInfinite) and FOverallDeadline.IsExpired then
      raise ESSHError.Create(sekTimeout, 'ssh transport: read deadline exceeded');
    // zero-copy drain read-ahead spillover from bulk ident read (single Move, no syscall)
    if FReadAheadPos < SizeUInt(Length(FReadAhead)) then
    begin
      LFromCache := SizeUInt(Length(FReadAhead)) - FReadAheadPos;
      if LFromCache > ACount then
        LFromCache := ACount;
      Move(FReadAhead[FReadAheadPos], ABuf[AOffset], LFromCache);
      Inc(FReadAheadPos, LFromCache);
      Inc(AOffset, LFromCache);
      Dec(ACount, LFromCache);
      if FReadAheadPos >= SizeUInt(Length(FReadAhead)) then
      begin
        SetLength(FReadAhead, 0);
        FReadAheadPos := 0;
      end;
      if ACount = 0 then
        Exit;
      if (not FOverallDeadline.IsInfinite) and FOverallDeadline.IsExpired and (ACount > 0) then
        raise ESSHError.Create(sekTimeout, 'ssh transport: read deadline exceeded');
      Continue;
    end;
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
  LTotal: SizeUInt;
  LChunk: array[0..255] of Byte;
  LGot: SizeUInt;
  LPos: SizeInt;
  LToCopy: SizeUInt;
  LHasLF: Boolean;
begin
  LB := nil;
  LTotal := 0;
  // bulk buffered line read - geometric BytesEnsureCapacity (bytes.ops single source, amortized O(1) vs +64 O(n²)), 256B chunk halves syscalls
  repeat
    if (not FOverallDeadline.IsInfinite) and FOverallDeadline.IsExpired then
      raise ESSHError.Create(sekTimeout, 'ssh transport: ident deadline exceeded');
    if FReadAheadPos < SizeUInt(Length(FReadAhead)) then
    begin
      LPos := SpanIndexOf(TByteSpan.Create(@FReadAhead[FReadAheadPos], SizeUInt(Length(FReadAhead)) - FReadAheadPos), 10);
      if LPos >= 0 then
      begin
        LToCopy := SizeUInt(LPos) + 1;
        LHasLF := True;
      end
      else
      begin
        LToCopy := SizeUInt(Length(FReadAhead)) - FReadAheadPos;
        LHasLF := False;
      end;
      if LTotal + LToCopy > SizeUInt(Length(LB)) then
        BytesEnsureCapacity(LB, LTotal + LToCopy);
      Move(FReadAhead[FReadAheadPos], LB[LTotal], LToCopy);
      Inc(LTotal, LToCopy);
      Inc(FReadAheadPos, LToCopy);
      if FReadAheadPos >= SizeUInt(Length(FReadAhead)) then
      begin
        SetLength(FReadAhead, 0);
        FReadAheadPos := 0;
      end;
      if LHasLF then
        Break;
      if LTotal > SizeUInt(SSH_IDENT_MAX_LINE) then
        raise ESSHError.Create(sekProtocol, 'ssh transport: ident banner too long');
      Continue;
    end;
    ApplyDeadlineToStream;
    LGot := FIO.Read(LChunk[0], SizeUInt(Length(LChunk)));
    if LGot = 0 then
      raise ESSHError.Create(sekIO, 'ssh transport: connection closed by peer');
    LPos := SpanIndexOf(TByteSpan.Create(@LChunk[0], LGot), 10);
    if LPos >= 0 then
    begin
      LToCopy := SizeUInt(LPos) + 1;
      LHasLF := True;
    end
    else
    begin
      LToCopy := LGot;
      LHasLF := False;
    end;
    if LTotal + LToCopy > SizeUInt(Length(LB)) then
      BytesEnsureCapacity(LB, LTotal + LToCopy);
    Move(LChunk[0], LB[LTotal], LToCopy);
    Inc(LTotal, LToCopy);
    if LTotal > SizeUInt(SSH_IDENT_MAX_LINE) then
      raise ESSHError.Create(sekProtocol, 'ssh transport: ident banner too long');
    if LHasLF then
    begin
      if SizeUInt(LPos) + 1 < LGot then
      begin
        SetLength(FReadAhead, LGot - SizeUInt(LPos) - 1);
        FReadAheadPos := 0;
        Move(LChunk[LPos + 1], FReadAhead[0], LGot - SizeUInt(LPos) - 1);
      end;
      Break;
    end;
  until False;
  while (LTotal > 0) and ((LB[LTotal - 1] = 13) or (LB[LTotal - 1] = 10)) do
    Dec(LTotal);
  SetLength(Result, LTotal);
  if LTotal > 0 then
    Move(LB[0], PByte(PChar(Result))^, LTotal);
  if Length(LB) > 0 then
    FillChar(LB[0], SizeUInt(Length(LB)), 0);
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
  LBodyLen: UInt32;
  LTrailerSize: SizeUInt;
  LTotal: SizeUInt;
begin
  if FState = tstClosed then
    raise ESSHError.Create(sekIO, 'ssh transport: closed');
  try
    // FReadBuf 复用零拷贝：头直接读入复用缓冲，无 LHeader/LPacket 双分配与 Move；bytes.ops 单源几何扩容
    BytesEnsureCapacity(FReadBuf, RECV_HEADER_SIZE);
    SetLength(FReadBuf, RECV_HEADER_SIZE);
    ReadFull(FReadBuf, 0, RECV_HEADER_SIZE);
    LBodyLen := FCore.BodyLengthFromHeader(FReadBuf);
  if SshTransportDump <> nil then
  begin
    SshTransportDump('rseq', UInt32Bytes(FCore.RecvSeq));
    SshTransportDump('rhdr', Copy(FReadBuf, 0, RECV_HEADER_SIZE));
    SshTransportDump('rlen', UInt32Bytes(LBodyLen));
  end;
  if (LBodyLen < 1) or (LBodyLen > SSH_MAX_RECEIVE_PACKET) then
    raise ESSHError.Create(sekProtocol,
      'ssh transport: unreasonable packet length ' + nextpas.core.text.conv.IntToStr(Int64(LBodyLen)));
    LTrailerSize := SizeUInt(FCore.TrailerSize(LBodyLen));
    LTotal := 4 + LTrailerSize;
    BytesEnsureCapacity(FReadBuf, LTotal);
    SetLength(FReadBuf, LTotal);
    if LTrailerSize > 0 then
      ReadFull(FReadBuf, 4, LTrailerSize);
    Result := FCore.DecodePacket(FReadBuf);
    if Length(FReadBuf) > 0 then
      FillChar(FReadBuf[0], SizeUInt(Length(FReadBuf)), 0);
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
