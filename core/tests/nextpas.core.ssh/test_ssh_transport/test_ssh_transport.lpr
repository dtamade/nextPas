program test_ssh_transport;

{$I nextpas.core.settings.inc}

{ S3 gate：版本交换与二进制包协议。
 * 使用内存双工管道：客户端 transport 与手写服务端字节级逻辑对接。
 * 覆盖：前置 banner 容忍、SSH 版本拒绝、未加密帧往返（双向）、
 * KEXINIT 载荷结构、坏 padding 拒绝、NEWKEYS 切换后 chacha 加密帧往返、
 * DISCONNECT 行为与关闭后 IO 错误。}

uses
  nextpas.core.system.sysutils,
  nextpas.core.io.intf,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.transport,
  nextpas.core.test;

type
  TMemPipeEnd = class(TInterfacedObject, IReadWriteCloser)
  private
    FPeer: TMemPipeEnd;
    FIncoming: TBytes;
    FReadPos: SizeUInt;
    FClosed: Boolean;
  public
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    procedure SetPeer(APeer: TMemPipeEnd);
    { 服务端视角：读取当前已到达的全部字节 }
    procedure Drain(out ADest: TBytes);
    { 非引用计数生命周期：由测试手工 Free，避免 transport 释放时提前析构 }
    function QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
    function _AddRef: LongInt; cdecl;
    function _Release: LongInt; cdecl;
    property Closed: Boolean read FClosed;
  end;

function TMemPipeEnd.QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TMemPipeEnd._AddRef: LongInt; cdecl;
begin
  Result := -1;
end;

function TMemPipeEnd._Release: LongInt; cdecl;
begin
  Result := -1;
end;

function TMemPipeEnd.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvail: SizeUInt;
begin
  if FClosed then
    Exit(0);
  LAvail := SizeUInt(Length(FIncoming)) - FReadPos;
  if LAvail > ACount then
    LAvail := ACount;
  if LAvail > 0 then
  begin
    Move(FIncoming[FReadPos], ABuf, LAvail);
    Inc(FReadPos, LAvail);
  end;
  Result := LAvail;
end;

function TMemPipeEnd.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LOld: SizeUInt;
begin
  if FClosed or (FPeer = nil) or FPeer.FClosed then
    Exit(0);
  LOld := SizeUInt(Length(FPeer.FIncoming));
  SetLength(FPeer.FIncoming, LOld + ACount);
  Move(ABuf, FPeer.FIncoming[LOld], ACount);
  Result := ACount;
end;

procedure TMemPipeEnd.Close;
begin
  FClosed := True;
end;

procedure TMemPipeEnd.SetPeer(APeer: TMemPipeEnd);
begin
  FPeer := APeer;
end;

procedure TMemPipeEnd.Drain(out ADest: TBytes);
var
  LRemain: SizeUInt;
begin
  LRemain := SizeUInt(Length(FIncoming)) - FReadPos;
  SetLength(ADest, LRemain);
  if LRemain > 0 then
  begin
    Move(FIncoming[FReadPos], ADest[0], LRemain);
    Inc(FReadPos, LRemain);
  end;
end;

procedure MakePipe(out AClientSide, AServerSide: TMemPipeEnd);
begin
  AClientSide := TMemPipeEnd.Create;
  AServerSide := TMemPipeEnd.Create;
  AClientSide.SetPeer(AServerSide);
  AServerSide.SetPeer(AClientSide);
end;

function StringToBytes(const AText: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PByte(PChar(AText))^, Result[0], SizeUInt(Length(AText)));
end;

function BytesToText(const AData: TBytes): string;
begin
  Result := '';
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], PByte(PChar(Result))^, SizeUInt(Length(AData)));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

function PatternBytes(APattern: Byte; ACount: Integer): TBytes;
begin
  Result := nil;
  SetLength(Result, ACount);
  if ACount > 0 then
    FillChar(Result[0], SizeUInt(ACount), APattern);
end;

{ 服务端按未加密帧发送载荷 }
procedure ServerSendPlainFrame(AEnd_: TMemPipeEnd; const APayload: TBytes);
var
  LW: TsshWriter;
  LPad, I: Integer;
begin
  LPad := 8 - ((4 + 1 + Length(APayload)) mod 8);
  if LPad < SSH_MIN_PADDING then
    Inc(LPad, 8);
  LW := TsshWriter.Create(64);
  try
    LW.PutUInt32(UInt32(1 + Length(APayload) + SizeUInt(LPad)));
    LW.PutByte(Byte(LPad));
    LW.PutRaw(APayload);
    for I := 1 to LPad do
      LW.PutByte($20);
    AEnd_.Write(LW.ToBytes[0], SizeUInt(LW.Count));
  finally
    LW.Free;
  end;
end;

{ 解析一帧未加密包 → 载荷 }
function ParsePlainFrame(const AWire: TBytes): TBytes;
var
  LLen, LPadLen: UInt32;
begin
  Result := nil;
  LLen := (UInt32(AWire[0]) shl 24) or (UInt32(AWire[1]) shl 16)
    or (UInt32(AWire[2]) shl 8) or UInt32(AWire[3]);
  LPadLen := AWire[4];
  SetLength(Result, LLen - 1 - LPadLen);
  if Length(Result) > 0 then
    Move(AWire[5], Result[0], Length(Result));
end;

{ 填充双向 chacha 协商结果 }
procedure FillChachaNegotiated(out ANeg: TSshNegotiated);
begin
  ANeg.KexAlg := 'curve25519-sha256';
  ANeg.HostKeyAlg := 'ssh-ed25519';
  ANeg.EncCs := 'chacha20-poly1305@openssh.com';
  ANeg.EncSc := 'chacha20-poly1305@openssh.com';
  ANeg.MacCs := '';
  ANeg.MacSc := '';
  ANeg.CompCs := 'none';
  ANeg.CompSc := 'none';
end;

{ 回归：OpenSSH 接收端强制 need(=packlen) % blocksize = 0。
  AEAD/EtM 的长度字段不进对齐区（len -= aadlen），packlen 本身必须整除块大小。}
procedure AssertAeadPacklenAligned(const ACipher, AMac: string;
  AKeyLen, AIvLen, ABlk: Integer);
const
  LENNS: array[0..7] of Integer = (1, 4, 12, 17, 23, 31, 48, 100);
var
  LClientEnd, LServerEnd: TMemPipeEnd;
  LTr: TSshClientTransport;
  LNeg: TSshNegotiated;
  LKeyC, LKeyS, LMacC, LIv, LIdent, LWireFrame, LPayload, LBody: TBytes;
  LSrvRecv: ISshPacketReceiver;
  LLn, LPackLen, LSeq: Integer;
begin
  MakePipe(LClientEnd, LServerEnd);
  LTr := TSshClientTransport.Create(LClientEnd);
  try
    LIdent := StringToBytes('SSH-2.0-Srv' + #13#10);
    LServerEnd.Write(LIdent[0], SizeUInt(Length(LIdent)));
    LTr.ExchangeVersions;
    LServerEnd.Drain(LIdent);

    FillChachaNegotiated(LNeg);
    LNeg.EncCs := ACipher;
    LNeg.EncSc := ACipher;
    LNeg.MacCs := AMac;
    LNeg.MacSc := AMac;
    LKeyC := PatternBytes($C1, AKeyLen);
    LKeyS := PatternBytes($D1, AKeyLen);
    if AMac <> '' then
      LMacC := PatternBytes($E1, SshMacKeySize(AMac));
    if AIvLen > 0 then
      LIv := PatternBytes($F1, AIvLen)
    else
      LIv := nil;
    LTr.ApplyNewKeys(LNeg,
      Copy(LIv, 0, AIvLen), Copy(LKeyC, 0, SshCipherKeySize(ACipher)),
      Copy(LMacC, 0, SshMacKeySize(AMac)),
      Copy(LIv, 0, AIvLen), Copy(LKeyS, 0, SshCipherKeySize(ACipher)),
      Copy(LMacC, 0, SshMacKeySize(AMac)));

    LSrvRecv := CreateSshPacketReceiver(ACipher, AMac,
      Copy(LKeyC, 0, SshCipherKeySize(ACipher)),
      Copy(LIv, 0, AIvLen), Copy(LMacC, 0, SshMacKeySize(AMac)));

    LSeq := 0;
    for LLn in LENNS do
    begin
      LPayload := PatternBytes(Byte(LLn), LLn);
      LTr.SendPacket(LPayload);
      LServerEnd.Drain(LWireFrame);
      LPackLen := Int64(LSrvRecv.BodyLengthFromHeader(
        UInt32(LSeq), Copy(LWireFrame, 0, 4)));
      CheckTrue((LPackLen mod ABlk) = 0,
        ACipher + ' packlen aligned to ' + IntToStr(ABlk) +
        ', payload len=' + IntToStr(LLn) +
        ', packlen=' + IntToStr(LPackLen));
      CheckTrue((SizeUInt(4) +
        SizeUInt(LSrvRecv.TrailerSize(LPackLen))) = SizeUInt(Length(LWireFrame)),
        ACipher + ' frame size consistent, payload len=' + IntToStr(LLn));
      LBody := LSrvRecv.Unprotect(UInt32(LSeq), LWireFrame);
      CheckTrue((Length(LBody) > SizeUInt(LLn)) and
        CompareMem(@LPayload[0], @LBody[1], LLn),
        ACipher + ' payload intact, len=' + IntToStr(LLn));
      Inc(LSeq);
    end;
  finally
    LTr.Free;
    LClientEnd.Free;
    LServerEnd.Free;
  end;
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ssh transport');

  LSuite.Test('version exchange tolerates pre-banner lines', procedure
  var
    LClientEnd, LServerEnd: TMemPipeEnd;
    LTr: TSshClientTransport;
    LJunk, LSeen: TBytes;
    LIdent: string;
  begin
    MakePipe(LClientEnd, LServerEnd);
    LTr := TSshClientTransport.Create(LClientEnd);
    try
      CheckEqual(Ord(tstInit), Ord(LTr.State));

      LJunk := StringToBytes('HTTP/1.1 400 Bad Request' + #13#10
        + 'Another-Line' + #13#10
        + 'SSH-2.0-OpenSSH_9.6' + #13#10);
      LServerEnd.Write(LJunk[0], SizeUInt(Length(LJunk)));

      LIdent := LTr.ExchangeVersions;
      CheckEqual('SSH-2.0-OpenSSH_9.6', LIdent);
      CheckEqual(Ord(tstKexExchange), Ord(LTr.State));

      SetLength(LSeen, Length(SSH_PROTOCOL_VERSION) + 2);
      CheckEqual(SizeUInt(Length(LSeen)),
        LServerEnd.Read(LSeen[0], SizeUInt(Length(LSeen))));
      CheckTrue(Copy(BytesToText(LSeen), 1, 4) = 'SSH-', 'client ident sent');
    finally
      LTr.Free;
      LClientEnd.Free;
      LServerEnd.Free;
    end;
  end);

  LSuite.Test('rejects non SSH-2.0 peer', procedure
  var
    LClientEnd, LServerEnd: TMemPipeEnd;
    LTr: TSshClientTransport;
    LJunk: TBytes;
    LRaised: Boolean;
  begin
    MakePipe(LClientEnd, LServerEnd);
    LTr := TSshClientTransport.Create(LClientEnd);
    try
      LJunk := StringToBytes('SSH-1.5-OldServer' + #13#10);
      LServerEnd.Write(LJunk[0], SizeUInt(Length(LJunk)));
      LRaised := False;
      try
        LTr.ExchangeVersions;
      except
        on E: ESSHError do
        begin
          LRaised := True;
          CheckEqual(Ord(sekUnsupported), Ord(E.Kind));
        end;
      end;
      CheckTrue(LRaised, 'ssh-1.5 peer must be rejected');
    finally
      LTr.Free;
      LClientEnd.Free;
      LServerEnd.Free;
    end;
  end);

  LSuite.Test('kexinit send produces parseable framed packet', procedure
  var
    LClientEnd, LServerEnd: TMemPipeEnd;
    LTr: TSshClientTransport;
    LMyPayload, LWire, LPayload: TBytes;
  begin
    MakePipe(LClientEnd, LServerEnd);
    LTr := TSshClientTransport.Create(LClientEnd);
    try
      LMyPayload := LTr.SendKexInit(StringToBytes('0123456789abcdef'));

      LServerEnd.Drain(LWire);
      CheckTrue(Length(LWire) > 4, 'frame arrived');
      CheckEqual(Int64(Length(LWire)) - 4,
        Int64((UInt32(LWire[0]) shl 24) or (UInt32(LWire[1]) shl 16)
          or (UInt32(LWire[2]) shl 8) or UInt32(LWire[3])));

      LPayload := ParsePlainFrame(LWire);
      CheckEqual(Int64(Length(LMyPayload)), Int64(Length(LPayload)));
      CheckEqual(Int64(SSH_MSG_KEXINIT), Int64(LPayload[0]));
      { 结构合法：解析器接受且算法表完整 }
      CheckEqual('curve25519-sha256', SshParseKexInit(LPayload).KexAlgs[0]);
    finally
      LTr.Free;
      LClientEnd.Free;
      LServerEnd.Free;
    end;
  end);

  LSuite.Test('plain frame read returns payload', procedure
  var
    LClientEnd, LServerEnd: TMemPipeEnd;
    LTr: TSshClientTransport;
    LPayload, LGot: TBytes;
  begin
    MakePipe(LClientEnd, LServerEnd);
    LTr := TSshClientTransport.Create(LClientEnd);
    try
      LPayload := StringToBytes(#63 + 'channel-open-ish');
      ServerSendPlainFrame(LServerEnd, LPayload);
      LGot := LTr.ReadPacket;
      CheckEqual(BytesToHex(LPayload), BytesToHex(LGot));

      { 第二包序列号推进 }
      ServerSendPlainFrame(LServerEnd, Copy(LPayload, 0, 3));
      LGot := LTr.ReadPacket;
      CheckEqual(Int64(3), Int64(Length(LGot)));
    finally
      LTr.Free;
      LClientEnd.Free;
      LServerEnd.Free;
    end;
  end);

  LSuite.Test('bad padding length rejected', procedure
  var
    LClientEnd, LServerEnd: TMemPipeEnd;
    LTr: TSshClientTransport;
    LW: TsshWriter;
    LRaised: Boolean;
  begin
    MakePipe(LClientEnd, LServerEnd);
    LTr := TSshClientTransport.Create(LClientEnd);
    try
      { padlen=2 < SSH_MIN_PADDING }
      LW := TsshWriter.Create(32);
      try
        LW.PutUInt32(1 + 4 + 2);
        LW.PutByte(2);
        LW.PutRaw(StringToBytes('abcd'));
        LW.PutRaw(PatternBytes($00, 2));
        LServerEnd.Write(LW.ToBytes[0], SizeUInt(LW.Count));
      finally
        LW.Free;
      end;
      LRaised := False;
      try
        LTr.ReadPacket;
      except
        on E: ESSHError do
        begin
          LRaised := True;
          CheckEqual(Ord(sekProtocol), Ord(E.Kind));
        end;
      end;
      CheckTrue(LRaised, 'bad padding must raise');
    finally
      LTr.Free;
      LClientEnd.Free;
      LServerEnd.Free;
    end;
  end);

  LSuite.Test('newkeys switches to chacha frames both directions', procedure
  var
    LClientEnd, LServerEnd: TMemPipeEnd;
    LTr: TSshClientTransport;
    LNeg: TSshNegotiated;
    LKeyC, LKeyS, LIdent: TBytes;
    LSrvRecv: ISshPacketReceiver;
    LSrvSender: ISshPacketSender;
    LPayload, LWireFrame, LBody, LBack: TBytes;
    LPad, I: Integer;
  begin
    MakePipe(LClientEnd, LServerEnd);
    LTr := TSshClientTransport.Create(LClientEnd);
    try
      { 状态机要求 NEWKEYS 发生在 kex 阶段 }
      LIdent := StringToBytes('SSH-2.0-Srv' + #13#10);
      LServerEnd.Write(LIdent[0], SizeUInt(Length(LIdent)));
      LTr.ExchangeVersions;
      { 客户端版本串已到达服务端末梢：丢弃，避免混入后续加密帧 }
      LServerEnd.Drain(LIdent);

      LKeyC := PatternBytes($C1, 64);
      LKeyS := PatternBytes($D1, 64);
      FillChachaNegotiated(LNeg);
      LTr.ApplyNewKeys(LNeg, nil, LKeyC, nil, nil, LKeyS, nil);
      CheckEqual(Ord(tstEncrypted), Ord(LTr.State));

      { 客户端 → 服务端：seq 0 加密帧，服务端用同钥接收器解出 }
      LSrvRecv := CreateSshPacketReceiver('chacha20-poly1305@openssh.com', '',
        LKeyC, nil, nil);
      LPayload := StringToBytes(#98 + 'encrypted-data');
      LTr.SendPacket(LPayload);
      LServerEnd.Drain(LWireFrame);
      LBody := LSrvRecv.Unprotect(0, LWireFrame);
      { body = [padlen][payload][padding] }
      CheckEqual(Int64(Length(LPayload)),
        Int64(Length(LBody) - 1 - Integer(LBody[0])));
      CheckTrue(CompareMem(@LPayload[0], @LBody[1], Length(LPayload)),
        'client->server encrypted payload');

      { 服务端 → 客户端：服务端加密器 seq 0，客户端 ReadPacket 还原 }
      LSrvSender := CreateSshPacketSender('chacha20-poly1305@openssh.com', '',
        LKeyS, nil, nil);
      LPad := 8 - ((4 + 1 + Length(LPayload)) mod 8);
      if LPad < SSH_MIN_PADDING then
        Inc(LPad, 8);
      LBody := nil;
      SetLength(LBody, 1 + Length(LPayload) + SizeUInt(LPad));
      LBody[0] := Byte(LPad);
      Move(LPayload[0], LBody[1], Length(LPayload));
      for I := 1 to LPad do
        LBody[1 + Length(LPayload) + I - 1] := $11;
      LWireFrame := LSrvSender.Protect(LBody, 0);
      LServerEnd.Write(LWireFrame[0], SizeUInt(Length(LWireFrame)));

      LBack := LTr.ReadPacket;
      CheckEqual(BytesToHex(LPayload), BytesToHex(LBack),
        'server->client encrypted roundtrip');
    finally
      LTr.Free;
      LClientEnd.Free;
      LServerEnd.Free;
    end;
  end);

  { 回归：OpenSSH 接收端强制 need(=packlen) % blocksize = 0。
    AEAD/EtM 的长度字段不进对齐区（len -= aadlen），packlen 本身必须整除块大小。 }
  LSuite.Test('aead send keeps packlen aligned (OpenSSH framing)', procedure
  begin
    AssertAeadPacklenAligned('chacha20-poly1305@openssh.com', '', 64, 0, 8);
    AssertAeadPacklenAligned('aes256-gcm@openssh.com', '', 32, 12, 16);
    AssertAeadPacklenAligned('aes256-ctr',
      'hmac-sha2-256-etm@openssh.com', 32, 16, 16);
  end);

  LSuite.Test('disconnect sends message then closes', procedure
  var
    LClientEnd, LServerEnd: TMemPipeEnd;
    LTr: TSshClientTransport;
    LWire, LPayload, LLeft: TBytes;
  begin
    MakePipe(LClientEnd, LServerEnd);
    LTr := TSshClientTransport.Create(LClientEnd);
    try
      LTr.Disconnect(UInt32(2),
        'bye');
      CheckEqual(Ord(tstClosed), Ord(LTr.State));

      LServerEnd.Drain(LWire);
      CheckTrue(Length(LWire) > 4, 'disconnect frame arrived');
      LPayload := ParsePlainFrame(LWire);
      CheckEqual(Int64(SSH_MSG_DISCONNECT), Int64(LPayload[0]));

      { 关闭后服务端不再收到新数据 }
      LServerEnd.Drain(LLeft);
      CheckEqual(Int64(0), Int64(Length(LLeft)));
    finally
      LTr.Free;
      LClientEnd.Free;
      LServerEnd.Free;
    end;
  end);

  LSuite.Test('read after close raises sekIO', procedure
  var
    LClientEnd, LServerEnd: TMemPipeEnd;
    LTr: TSshClientTransport;
    LRaised: Boolean;
  begin
    MakePipe(LClientEnd, LServerEnd);
    LTr := TSshClientTransport.Create(LClientEnd);
    try
      LTr.Close;
      CheckTrue(LClientEnd.Closed);
      LRaised := False;
      try
        LTr.ReadPacket;
      except
        on E: ESSHError do
        begin
          LRaised := True;
          CheckEqual(Ord(sekIO), Ord(E.Kind));
        end;
      end;
      CheckTrue(LRaised, 'read after close must raise');
    finally
      LTr.Free;
      LClientEnd.Free;
      LServerEnd.Free;
    end;
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.ssh.transport');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
