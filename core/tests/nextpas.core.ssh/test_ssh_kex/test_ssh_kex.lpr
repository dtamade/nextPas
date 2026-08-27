program test_ssh_kex;

{$I nextpas.core.settings.inc}

{ S3 gate：KEXINIT 协商、KDF 与 curve25519 交换。
 * 覆盖：载荷构造/解析往返、first-match 协商规则（含 AEAD 免 MAC 与 ctr 必配 MAC）、
 * RFC 4253 §7.2 KDF 扩展链独立重算对照、curve25519 客户端交换与
 * draft-ietf-curdle-ssh-curves §4 输入序的独立 H 重算。}

uses
  nextpas.core.system.sysutils,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.kex.curve25519,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.hash,
  nextpas.core.test;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

{ 重复填充单字节的确定性材料 }
function PatternBytes(APattern: Byte; ACount: Integer): TBytes;
var
  LHead: TBytes;
begin
  Result := nil;
  SetLength(Result, ACount);
  if ACount > 0 then
    FillChar(Result[0], SizeUInt(ACount), APattern);
end;

function PrefixBytes(const APrefix: array of Byte; const ATail: TBytes): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(APrefix) + Length(ATail));
  if Length(APrefix) > 0 then
    Move(APrefix[0], Result[0], Length(APrefix));
  if Length(ATail) > 0 then
    Move(ATail[0], Result[Length(APrefix)], Length(ATail));
end;

function ConcatAll(const AParts: array of TBytes): TBytes;
var
  I: Integer;
  LTot, LPos: SizeUInt;
begin
  Result := nil;
  LTot := 0;
  for I := 0 to High(AParts) do
    Inc(LTot, SizeUInt(Length(AParts[I])));
  SetLength(Result, LTot);
  LPos := 0;
  for I := 0 to High(AParts) do
    if Length(AParts[I]) > 0 then
    begin
      Move(AParts[I][0], Result[LPos], SizeUInt(Length(AParts[I])));
      Inc(LPos, SizeUInt(Length(AParts[I])));
    end;
end;

{ 独立构造 KEXINIT 载荷（不经 SshBuildKexInitPayload），用于解析器测试 }
function CraftKexInitPayload(const AKexAlgs: array of string): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(256);
  try
    LW.PutByte(SSH_MSG_KEXINIT);
    LW.PutRaw(HexToBytes('000102030405060708090a0b0c0d0e0f'));
    LW.PutNameList(AKexAlgs);
    LW.PutNameList(['ssh-ed25519']);
    LW.PutNameList(['aes256-gcm@openssh.com']);
    LW.PutNameList(['aes256-gcm@openssh.com']);
    LW.PutNameList([]);
    LW.PutNameList([]);
    LW.PutNameList(['none']);
    LW.PutNameList(['none']);
    LW.PutStringText('lang-c');
    LW.PutStringText('lang-s');
    LW.PutBoolean(False);
    LW.PutUInt32(0);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

{ mpint 编码（与 wire 层一致），供 H 独立重算使用 }
function MpIntEncode(const AMagnitude: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(80);
  try
    LW.PutMPInt(AMagnitude);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ssh kex');

  LSuite.Test('build then parse roundtrip', procedure
  var
    LPayload: TBytes;
    LPeer: TSshPeerKexInit;
  begin
    LPayload := SshBuildKexInitPayload(HexToBytes('00112233445566778899aabbccddeeff'));
    { 载荷以消息号开头，解析器输入含消息号 }
    LPeer := SshParseKexInit(LPayload);
    CheckEqual('curve25519-sha256', LPeer.KexAlgs[0]);
    CheckEqual('curve25519-sha256@libssh.org', LPeer.KexAlgs[1]);
    CheckEqual('ssh-ed25519', LPeer.HostKeyAlgs[0]);
    CheckEqual('ecdsa-sha2-nistp256', LPeer.HostKeyAlgs[1]);
    CheckEqual('rsa-sha2-512', LPeer.HostKeyAlgs[2]);
    CheckEqual('chacha20-poly1305@openssh.com', LPeer.EncCs[0]);
    CheckEqual('hmac-sha2-512-etm@openssh.com', LPeer.MacSc[0]);
    CheckEqual('none', LPeer.CompCs[0]);
  end);

  LSuite.Test('cookie length enforced', procedure
  var
    LRaised: Boolean;
  begin
    LRaised := False;
    try
      SshBuildKexInitPayload(HexToBytes('0001'));
    except
      on E: ESSHError do
      begin
        LRaised := True;
        CheckEqual(Ord(sekProtocol), Ord(E.Kind));
      end;
    end;
    CheckTrue(LRaised, 'expected cookie size rejection');
  end);

  LSuite.Test('parse rejects wrong message id and truncation', procedure
  var
    LRaised: Boolean;
  begin
    { 消息号不是 KEXINIT }
    LRaised := False;
    try
      SshParseKexInit(HexToBytes('01000000ff'));
    except
      on E: ESSHError do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'wrong msg id must raise');

    { 截断载荷 }
    LRaised := False;
    try
      SshParseKexInit(Copy(CraftKexInitPayload(['curve25519-sha256']), 0, 12));
    except
      on E: ESSHError do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'truncated kexinit must raise');
  end);

  LSuite.Test('negotiation picks client-first mutual algorithm', procedure
  var
    LPeer: TSshPeerKexInit;
    LNeg: TSshNegotiated;
  begin
    LPeer := SshParseKexInit(CraftKexInitPayload(
      ['diffie-hellman-group14-sha256', 'curve25519-sha256@libssh.org',
       'curve25519-sha256']));
    { 服务端顺序无关：取我方列表中第一个对方也有的 → curve25519-sha256 }
    LNeg := SshNegotiate(LPeer);
    CheckEqual('curve25519-sha256', LNeg.KexAlg);
    CheckEqual('ssh-ed25519', LNeg.HostKeyAlg);
    CheckEqual('aes256-gcm@openssh.com', LNeg.EncCs);
    { AEAD 双向 MAC 允许为空 }
    CheckEqual('', LNeg.MacCs);
    CheckEqual('', LNeg.MacSc);
    CheckEqual('none', LNeg.CompCs);
  end);

  LSuite.Test('ecdsa hostkey negotiation prefers ed25519 over ecdsa and rsa', procedure
  var
    LW: TsshWriter;
    LPeer: TSshPeerKexInit;
    LNeg: TSshNegotiated;
  begin
    LW := TsshWriter.Create(256);
    try
      LW.PutByte(SSH_MSG_KEXINIT);
      LW.PutRaw(HexToBytes('000102030405060708090a0b0c0d0e0f'));
      LW.PutNameList(['curve25519-sha256']);
      LW.PutNameList(['ecdsa-sha2-nistp256', 'rsa-sha2-512']);
      LW.PutNameList(['aes256-gcm@openssh.com']);
      LW.PutNameList(['aes256-gcm@openssh.com']);
      LW.PutNameList([]);
      LW.PutNameList([]);
      LW.PutNameList(['none']);
      LW.PutNameList(['none']);
      LW.PutStringText('');
      LW.PutStringText('');
      LW.PutBoolean(False);
      LW.PutUInt32(0);
      LPeer := SshParseKexInit(LW.ToBytes);
      LNeg := SshNegotiate(LPeer);
      CheckEqual('ecdsa-sha2-nistp256', LNeg.HostKeyAlg);
    finally
      LW.Free;
    end;
    { 当服务端同时提供 ed25519 与 ecdsa，客户端优先 ed25519 }
    LW := TsshWriter.Create(256);
    try
      LW.PutByte(SSH_MSG_KEXINIT);
      LW.PutRaw(HexToBytes('000102030405060708090a0b0c0d0e0f'));
      LW.PutNameList(['curve25519-sha256']);
      LW.PutNameList(['ecdsa-sha2-nistp256', 'ssh-ed25519', 'rsa-sha2-512']);
      LW.PutNameList(['aes256-gcm@openssh.com']);
      LW.PutNameList(['aes256-gcm@openssh.com']);
      LW.PutNameList([]);
      LW.PutNameList([]);
      LW.PutNameList(['none']);
      LW.PutNameList(['none']);
      LW.PutStringText('');
      LW.PutStringText('');
      LW.PutBoolean(False);
      LW.PutUInt32(0);
      LPeer := SshParseKexInit(LW.ToBytes);
      LNeg := SshNegotiate(LPeer);
      CheckEqual('ssh-ed25519', LNeg.HostKeyAlg);
    finally
      LW.Free;
    end;
  end);

  LSuite.Test('ctr cipher demands etm mac', procedure
  var
    LW: TsshWriter;
    LRaised: Boolean;
  begin
    LW := TsshWriter.Create(256);
    try
      LW.PutByte(SSH_MSG_KEXINIT);
      LW.PutRaw(HexToBytes('000102030405060708090a0b0c0d0e0f'));
      LW.PutNameList(['curve25519-sha256']);
      LW.PutNameList(['ssh-ed25519']);
      LW.PutNameList(['aes128-ctr']);
      LW.PutNameList(['aes128-ctr']);
      LW.PutNameList([]);   { 服务端不给 MAC }
      LW.PutNameList([]);
      LW.PutNameList(['none']);
      LW.PutNameList(['none']);
      LW.PutStringText('');
      LW.PutStringText('');
      LW.PutBoolean(False);
      LW.PutUInt32(0);
      LRaised := False;
      try
        SshNegotiate(SshParseKexInit(LW.ToBytes));
      except
        on E: ESSHError do
        begin
          LRaised := True;
          CheckEqual(Ord(sekNegotiation), Ord(E.Kind));
        end;
      end;
      CheckTrue(LRaised, 'ctr without mac must fail negotiation');
    finally
      LW.Free;
    end;
  end);

  LSuite.Test('no mutual kex raises sekNegotiation', procedure
  var
    LPeer: TSshPeerKexInit;
    LRaised: Boolean;
  begin
    LPeer := SshParseKexInit(CraftKexInitPayload(['diffie-hellman-group1-sha1']));
    LRaised := False;
    try
      SshNegotiate(LPeer);
    except
      on E: ESSHError do
      begin
        LRaised := True;
        CheckEqual(Ord(sekNegotiation), Ord(E.Kind));
      end;
    end;
    CheckTrue(LRaised, 'no overlap must raise');
  end);

  LSuite.Test('kdf matches independent RFC 4253 7.2 chain', procedure
  var
    LKmpint, LH, LSid, LGot, LExpect, LBlockA, LBlockB: TBytes;
  begin
    LKmpint := PrefixBytes([$00, $00, $01, $00], PatternBytes($AB, 32));
    LH := SHA256(HexToBytes('deadbeef'));
    LSid := SHA256(HexToBytes('cafe'));

    { 单块（32 字节内）}
    LGot := SshKdfSha256(LKmpint, LH, Ord('A'), LSid, 32);
    LExpect := SHA256(ConcatAll([LKmpint, LH, HexToBytes('41'), LSid]));
    CheckEqual(BytesToHex(LExpect), BytesToHex(LGot), 'single block');

    { 扩展链：>32 字节时接 HASH(K||H||prev) }
    LGot := SshKdfSha256(LKmpint, LH, Ord('B'), LSid, 64);
    LBlockA := SHA256(ConcatAll([LKmpint, LH, HexToBytes('42'), LSid]));
    LBlockB := SHA256(ConcatAll([LKmpint, LH, LBlockA]));
    CheckEqual(BytesToHex(ConcatAll([LBlockA, LBlockB])), BytesToHex(LGot), 'two blocks');

    { 非对齐截断 }
    LGot := SshKdfSha256(LKmpint, LH, Ord('C'), LSid, 40);
    LBlockA := SHA256(ConcatAll([LKmpint, LH, HexToBytes('43'), LSid]));
    LBlockB := SHA256(ConcatAll([LKmpint, LH, LBlockA]));
    CheckEqual(40, Length(LGot));
    CheckEqual(BytesToHex(Copy(ConcatAll([LBlockA, LBlockB]), 0, 40)), BytesToHex(LGot),
      'truncated chain');

    { ALen<=0 返回空 }
    CheckEqual(0, Length(SshKdfSha256(LKmpint, LH, 65, LSid, 0)));
  end);

  LSuite.Test('curve25519 client exchange against simulated server', procedure
  var
    LClient: TSshKexCurve25519;
    LSrvPriv, LSrvPub, LShared, LInit: TBytes;
    LXErr: AnsiString;
    LC, LS: string;
    LIc, LIs, LHostKeyBlob, LSigBlob, LReply: TBytes;
    LW: TsshWriter;
    LGot: TSshKexCurve25519Result;
    LHInput: TBytes;
    LRaised: Boolean;
  begin
    { 模拟服务端密钥 }
    GenerateX25519KeyPair(LSrvPriv, LSrvPub);

    LClient := TSshKexCurve25519.Create;
    try
      CheckEqual('curve25519-sha256', LClient.AlgorithmName);

      { INIT = msg(30) || string(client ephemeral) }
      LInit := LClient.BuildInitPayload;
      CheckEqual(Int64(1 + 4 + 32), Int64(Length(LInit)));

      { 服务端 REPLY：string(hostkey blob) || string(f) || string(sig) }
      LHostKeyBlob := PatternBytes($BE, 48);
      LSigBlob := PatternBytes($5A, 20);
      TryX25519ComputeSharedSecret(LSrvPriv,
        Copy(LInit, 5, 32), LShared, LXErr);
      CheckEqual(32, Length(LShared));

      LW := TsshWriter.Create(128);
      try
        LW.PutByte(SSH_MSG_KEX_ECDH_REPLY);
        LW.PutStringBytes(LHostKeyBlob);
        LW.PutStringBytes(LSrvPub);
        LW.PutStringBytes(LSigBlob);
        LReply := LW.ToBytes;
      finally
        LW.Free;
      end;

      LC := 'SSH-2.0-NextPas_Test';
      LS := 'SSH-2.0-OpenSSH_9.0';
      LIc := HexToBytes('1112131415');
      LIs := HexToBytes('2122232425');

      CheckTrue(LClient.ProcessReply(LReply, LC, LS, LIc, LIs,
        LGot.SharedSecret, LGot.ExchangeHashH, LGot.ServerHostKeyBlob,
        LGot.ServerSigBlob));
      { K 一致 }
      CheckEqual(BytesToHex(LShared), BytesToHex(LGot.SharedSecret), 'K');

      { H 契约 = 共享的 RFC 4253 §8 构造（与环回 mock 同源，防两端漂移）}
      LHInput := SshBuildCurve25519HashInput(LC, LS, LIc, LIs,
        LHostKeyBlob, Copy(LInit, 5, 32), LSrvPub, LShared);
      CheckEqual(BytesToHex(SHA256(LHInput)), BytesToHex(LGot.ExchangeHashH), 'H');

      CheckTrue(CompareMem(@LHostKeyBlob[0], @LGot.ServerHostKeyBlob[0],
        Length(LHostKeyBlob)), 'hostkey blob passthrough');
      CheckTrue(CompareMem(@LSigBlob[0], @LGot.ServerSigBlob[0],
        Length(LSigBlob)), 'sig blob passthrough');
    finally
      LClient.Free;
    end;

    { 错误路径：非 REPLY 载荷 }
    LRaised := False;
    try
      LClient := TSshKexCurve25519.Create;
      try
        LClient.ProcessReplyNamed(HexToBytes('63'), LC, LS, LIc, LIs);
      finally
        LClient.Free;
      end;
    except
      on E: ESSHError do
      begin
        LRaised := True;
        CheckEqual(Ord(sekProtocol), Ord(E.Kind));
      end;
    end;
    CheckTrue(LRaised, 'wrong reply msg must raise');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.ssh.kex');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
