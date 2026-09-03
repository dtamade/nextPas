program bench_ssh_cipher;
{$mode ObjFPC}{$H+}
{
  cipher protect/unprotect 吞吐基准（S4 门禁）。

  - 16KB 载荷包，三族算法：chacha20-poly1305 / aes256-gcm / aes128-ctr+etm。
  - 使用与 transport 完全相同的编解码器契约：
      发送方 Protect(padlen‖payload‖padding, seq)，接收方按
      BodyLengthFromHeader → TrailerSize → Unprotect(完整线上包) 还原。
  - 每个方向先做一次正确性往返（字节级比对），再计时。
  - 吞吐低于 FLOOR_MIBS 视为门禁失败（捕获灾难性回退）。

  注意：本程序用 -O3 且不启用 heaptrc（见 Makefile bench_common），
  分配器检测开销会严重扭曲吞吐数据。
}
uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.time,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.cipher;

const
  PAYLOAD_LEN = 16384;
  PACKETS     = 8192;              { 128 MiB / 方向 }
  SEQ_BASE    = 1000;
  FLOOR_MIBS  = 50.0;              { 单方向门禁下限 }

type
  TBenchCase = record
    Name: string;       { 展示名 }
    Cipher: string;
    Mac: string;        { AEAD 为空串 }
  end;

const
  CASES: array[0..2] of TBenchCase = (
    (Name: 'chacha20-poly1305'; Cipher: 'chacha20-poly1305@openssh.com'; Mac: ''),
    (Name: 'aes256-gcm';        Cipher: 'aes256-gcm@openssh.com';        Mac: ''),
    (Name: 'aes128-ctr+etm';    Cipher: 'aes128-ctr';                    Mac: 'hmac-sha2-256-etm@openssh.com')
  );

function PatternFill(ALen, ASeed: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, ALen);
  for I := 0 to ALen - 1 do
    Result[I] := Byte((I * 181 + ASeed * 37 + 11) and $FF);
end;

function SameBytes(const A, B: TBytes): Boolean;
begin
  Result := (Length(A) = Length(B));
  if Result and (Length(A) > 0) then
    Result := CompareMem(@A[0], @B[0], Length(A));
end;

{ 按 transport 的规则构造 body=[padlen][payload][padding] }
function BuildBody(const APayload: TBytes; ABlock: Integer): TBytes;
var
  LPadLen: Integer;
begin
  LPadLen := 4;
  while ((4 + 1 + Length(APayload) + LPadLen) mod ABlock) <> 0 do
    Inc(LPadLen);
  SetLength(Result, 1 + Length(APayload) + LPadLen);
  Result[0] := Byte(LPadLen);
  if Length(APayload) > 0 then
    Move(APayload[0], Result[1], Length(APayload));
  FillChar(Result[1 + Length(APayload)], LPadLen, $5A);
end;

procedure RunCase(const AC: TBenchCase);
var
  LKey, LIV, LMacKey, LPayload, LBody, LWire, LBack, LHdr: TBytes;
  LWires: array of TBytes;
  LSnd, LSnd2: ISshPacketSender;
  LRcv, LRcv2: ISshPacketReceiver;
  I, LBlkLen: Integer;
  LBodyLen: UInt32;
  LT0, LT1: QWord;
  LSecP, LSecU: Double;
  LMibP, LMibU: Double;
begin
  LKey := PatternFill(SshCipherKeySize(AC.Cipher), 1);
  LIV := PatternFill(SshCipherIvSize(AC.Cipher), 2);
  if SshCipherRequiresMac(AC.Cipher) then
    LMacKey := PatternFill(SshMacKeySize(AC.Mac), 3)
  else
    SetLength(LMacKey, 0);

  LSnd := CreateSshPacketSender(AC.Cipher, AC.Mac, LKey, LIV, LMacKey);
  LRcv := CreateSshPacketReceiver(AC.Cipher, AC.Mac, LKey, LIV, LMacKey);

  LPayload := PatternFill(PAYLOAD_LEN, 4);
  LBlkLen := LSnd.PaddingBlock;
  if LBlkLen < 8 then
    LBlkLen := 8;
  LBody := BuildBody(LPayload, LBlkLen);

  { ---- 正确性往返 ---- }
  LWire := LSnd.Protect(LBody, SEQ_BASE);

  SetLength(LHdr, 4);
  Move(LWire[0], LHdr[0], 4);
  LBodyLen := LRcv.BodyLengthFromHeader(SEQ_BASE, LHdr);
  if (LBodyLen < 1) or (UInt32(Length(LWire)) - 4 <>
      LRcv.TrailerSize(LBodyLen)) then
  begin
    Writeln('[bench] ', AC.Name, ': FAIL body length mismatch');
    ExitCode := 1;
    Exit;
  end;

  LBack := LRcv.Unprotect(SEQ_BASE, LWire);
  if (UInt32(Length(LBack)) <> LBodyLen) or (Byte(LBack[0]) <> Byte(Length(LBack) - 1 - PAYLOAD_LEN))
     or not SameBytes(Copy(LBack, 1, PAYLOAD_LEN), LPayload) then
  begin
    Writeln('[bench] ', AC.Name, ': FAIL roundtrip mismatch');
    ExitCode := 1;
    Exit;
  end;

  { ---- 计时：protect ---- }
  LT0 := GetTickCount64;
  for I := 0 to PACKETS - 1 do
    LWire := LSnd.Protect(LBody, UInt32(SEQ_BASE + I));
  LT1 := GetTickCount64;
  LSecP := (LT1 - LT0) / 1000.0;

  { ---- 计时：unprotect ----
    GCM 的 IV 是内部包计数（RFC 5647，不绑定 seq），chacha 绑定 seq。
    用全新编解码器对按生产顺序生成并消费——即真实接收流量形态。}
  LSnd2 := CreateSshPacketSender(AC.Cipher, AC.Mac, LKey, LIV, LMacKey);
  LRcv2 := CreateSshPacketReceiver(AC.Cipher, AC.Mac, LKey, LIV, LMacKey);
  SetLength(LWires, PACKETS);
  for I := 0 to PACKETS - 1 do
    LWires[I] := LSnd2.Protect(LBody, UInt32(SEQ_BASE + I));
  LT0 := GetTickCount64;
  for I := 0 to PACKETS - 1 do
    LBack := LRcv2.Unprotect(UInt32(SEQ_BASE + I), LWires[I]);
  LT1 := GetTickCount64;
  LSecU := (LT1 - LT0) / 1000.0;

  LMibP := PACKETS * PAYLOAD_LEN / (1024 * 1024) / LSecP;
  LMibU := PACKETS * PAYLOAD_LEN / (1024 * 1024) / LSecU;

  Writeln(Format('[bench] %-22s pkt=%dB n=%d', [AC.Name, PAYLOAD_LEN, PACKETS]));
  Writeln(Format('  protect   %10.1f MiB/s   (%.2fs)', [LMibP, LSecP]));
  Writeln(Format('  unprotect %10.1f MiB/s   (%.2fs)', [LMibU, LSecU]));

  if (LMibP < FLOOR_MIBS) or (LMibU < FLOOR_MIBS) then
  begin
    Writeln('[bench] ', AC.Name, ': FAIL below floor ', FloatToStr(FLOOR_MIBS), ' MiB/s');
    ExitCode := 1;
  end;
end;

var
  I: Integer;
begin
  try
    Writeln('[bench] cipher protect/unprotect throughput, ',
      PACKETS * PAYLOAD_LEN div (1024 * 1024), ' MiB per direction');
    for I := Low(CASES) to High(CASES) do
      RunCase(CASES[I]);
    if ExitCode = 0 then
      Writeln('[bench] PASS (floor ', FloatToStr(FLOOR_MIBS), ' MiB/s per direction)')
    else
      Writeln('[bench] FAILED');
  except
    on E: Exception do
    begin
      Writeln('[bench] EXCEPTION: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
