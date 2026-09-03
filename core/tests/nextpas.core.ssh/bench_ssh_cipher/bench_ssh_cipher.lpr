program bench_ssh_cipher;
{$mode ObjFPC}{$H+}
{
  cipher protect/unprotect 吞吐基准（S4 门禁）。

  - 16KB 载荷包，三族算法：chacha20-poly1305 / aes256-gcm / aes128-ctr+etm。
  - 使用与 transport 完全相同的编解码器契约：
      发送方 Protect(padlen‖payload‖padding, seq)，接收方按
      BodyLengthFromHeader → TrailerSize → Unprotect(完整线上包) 还原。
  - 每个方向先做一次正确性往返（字节级比对），再由 nextpas.core.bench 统一测量。
  - 吞吐低于 FLOOR_MIBS 视为门禁失败（捕获灾难性回退）。

  计时保真：-O3 无 heaptrc（见 Makefile bench_common），泄漏由 Tier-1 覆盖。
  测量统一：nextpas.core.bench TBenchSuite + platform_monotonic_ns 纳秒级采样，
  避免 GetTickCount64 毫秒级失真（16KB×8192=128MiB 吞吐失真），契合 design-conventions §12。
  性能：门面薄转发 inline，Move 零拷贝经 bytes.ops 单源（FWriteBuf move 语义）；
  稳定性：接口引用计数 + try-finally 释放不丢，SecureZero 由 cipher 侧保证。
  业务以 CONTRACT §6 为准，缺能力先反哺 owner。
}
uses
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bytes.ops,
  nextpas.core.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.cipher;

const
  PAYLOAD_LEN = 16384;
  SEQ_BASE    = 1000;
  FLOOR_MIBS  = 50.0;              { 单方向门禁下限 }

type
  TBenchCase = record
    Name: string;
    Cipher: string;
    Mac: string;
  end;

const
  CASES: array[0..2] of TBenchCase = (
    (Name: 'chacha20-poly1305'; Cipher: 'chacha20-poly1305@openssh.com'; Mac: ''),
    (Name: 'aes256-gcm';        Cipher: 'aes256-gcm@openssh.com';        Mac: ''),
    (Name: 'aes128-ctr+etm';    Cipher: 'aes128-ctr';                    Mac: 'hmac-sha2-256-etm@openssh.com')
  );

{ --- helpers：pattern / body 构造，零拷贝 Move 单源于 bytes.ops --- }

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

{ 按 transport 的规则构造 body=[padlen][payload][padding]；外层 Move 单源复用 bytes.ops }
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

{ --- bench 全局状态：protect / unprotect 各一组 sender/receiver + body + seq --- }

var
  GProtectSnd: array[0..2] of ISshPacketSender;
  GProtectBody: array[0..2] of TBytes;
  GProtectSeq: array[0..2] of UInt32;
  GUnprotectSnd: array[0..2] of ISshPacketSender;
  GUnprotectRcv: array[0..2] of ISshPacketReceiver;
  GUnprotectBody: array[0..2] of TBytes;
  GUnprotectSeq: array[0..2] of UInt32;

procedure InitBenchState;
var
  I, LBlkLen: Integer;
  LKey, LIV, LMacKey, LPayload, LBody, LWire, LBack, LHdr: TBytes;
  LSnd: ISshPacketSender;
  LRcv: ISshPacketReceiver;
  LBodyLen: UInt32;
begin
  for I := Low(CASES) to High(CASES) do
  begin
    LKey := PatternFill(SshCipherKeySize(CASES[I].Cipher), 1);
    LIV := PatternFill(SshCipherIvSize(CASES[I].Cipher), 2);
    if SshCipherRequiresMac(CASES[I].Cipher) then
      LMacKey := PatternFill(SshMacKeySize(CASES[I].Mac), 3)
    else
      SetLength(LMacKey, 0);

    LSnd := CreateSshPacketSender(CASES[I].Cipher, CASES[I].Mac, LKey, LIV, LMacKey);
    LRcv := CreateSshPacketReceiver(CASES[I].Cipher, CASES[I].Mac, LKey, LIV, LMacKey);

    LPayload := PatternFill(PAYLOAD_LEN, 4);
    LBlkLen := LSnd.PaddingBlock;
    if LBlkLen < 8 then
      LBlkLen := 8;
    LBody := BuildBody(LPayload, LBlkLen);

    { 正确性往返：与 transport 完全相同校验 }
    LWire := LSnd.Protect(LBody, SEQ_BASE);
    SetLength(LHdr, 4);
    Move(LWire[0], LHdr[0], 4);
    LBodyLen := LRcv.BodyLengthFromHeader(SEQ_BASE, LHdr);
    if (LBodyLen < 1) or (UInt32(Length(LWire)) - 4 <> LRcv.TrailerSize(LBodyLen)) then
    begin
      Writeln('[bench] ', CASES[I].Name, ': FAIL body length mismatch');
      Halt(1);
    end;
    LBack := LRcv.Unprotect(SEQ_BASE, LWire);
    if (UInt32(Length(LBack)) <> LBodyLen) or (Byte(LBack[0]) <> Byte(Length(LBack) - 1 - PAYLOAD_LEN))
       or not SameBytes(Copy(LBack, 1, PAYLOAD_LEN), LPayload) then
    begin
      Writeln('[bench] ', CASES[I].Name, ': FAIL roundtrip mismatch');
      Halt(1);
    end;

    { protect 侧：复用同密钥的 sender + body，seq 从 SEQ_BASE 起 }
    GProtectSnd[I] := CreateSshPacketSender(CASES[I].Cipher, CASES[I].Mac, LKey, LIV, LMacKey);
    GProtectBody[I] := LBody;
    GProtectSeq[I] := SEQ_BASE;

    { unprotect 侧：独立 sender/receiver 对，seq 同步，GCM 内部计数与 chacha seq 均对齐 }
    GUnprotectSnd[I] := CreateSshPacketSender(CASES[I].Cipher, CASES[I].Mac, LKey, LIV, LMacKey);
    GUnprotectRcv[I] := CreateSshPacketReceiver(CASES[I].Cipher, CASES[I].Mac, LKey, LIV, LMacKey);
    GUnprotectBody[I] := LBody;
    GUnprotectSeq[I] := SEQ_BASE;
  end;
end;

{ --- 6 个单操作基准：框架自适应采样，ACtx.SetBytes 报告吞吐，BenchBlackBox 防消除 --- }

procedure BenchProtectChacha(const ACtx: IBenchContext);
var
  LWire: TBytes;
begin
  ACtx.SetBytes(PAYLOAD_LEN);
  LWire := GProtectSnd[0].Protect(GProtectBody[0], GProtectSeq[0]);
  Inc(GProtectSeq[0]);
  if Length(LWire) > 0 then
    BenchBlackBoxBytes(LWire[0], Length(LWire));
end;

procedure BenchUnprotectChacha(const ACtx: IBenchContext);
var
  LWire, LBack: TBytes;
  LSeq: UInt32;
begin
  ACtx.SetBytes(PAYLOAD_LEN);
  LSeq := GUnprotectSeq[0];
  Inc(GUnprotectSeq[0]);
  ACtx.StopTimer;
  LWire := GUnprotectSnd[0].Protect(GUnprotectBody[0], LSeq);
  ACtx.StartTimer;
  LBack := GUnprotectRcv[0].Unprotect(LSeq, LWire);
  if Length(LBack) > 0 then
    BenchBlackBoxBytes(LBack[0], Length(LBack));
end;

procedure BenchProtectAesGcm(const ACtx: IBenchContext);
var
  LWire: TBytes;
begin
  ACtx.SetBytes(PAYLOAD_LEN);
  LWire := GProtectSnd[1].Protect(GProtectBody[1], GProtectSeq[1]);
  Inc(GProtectSeq[1]);
  if Length(LWire) > 0 then
    BenchBlackBoxBytes(LWire[0], Length(LWire));
end;

procedure BenchUnprotectAesGcm(const ACtx: IBenchContext);
var
  LWire, LBack: TBytes;
  LSeq: UInt32;
begin
  ACtx.SetBytes(PAYLOAD_LEN);
  LSeq := GUnprotectSeq[1];
  Inc(GUnprotectSeq[1]);
  ACtx.StopTimer;
  LWire := GUnprotectSnd[1].Protect(GUnprotectBody[1], LSeq);
  ACtx.StartTimer;
  LBack := GUnprotectRcv[1].Unprotect(LSeq, LWire);
  if Length(LBack) > 0 then
    BenchBlackBoxBytes(LBack[0], Length(LBack));
end;

procedure BenchProtectAesCtrEtm(const ACtx: IBenchContext);
var
  LWire: TBytes;
begin
  ACtx.SetBytes(PAYLOAD_LEN);
  LWire := GProtectSnd[2].Protect(GProtectBody[2], GProtectSeq[2]);
  Inc(GProtectSeq[2]);
  if Length(LWire) > 0 then
    BenchBlackBoxBytes(LWire[0], Length(LWire));
end;

procedure BenchUnprotectAesCtrEtm(const ACtx: IBenchContext);
var
  LWire, LBack: TBytes;
  LSeq: UInt32;
begin
  ACtx.SetBytes(PAYLOAD_LEN);
  LSeq := GUnprotectSeq[2];
  Inc(GUnprotectSeq[2]);
  ACtx.StopTimer;
  LWire := GUnprotectSnd[2].Protect(GUnprotectBody[2], LSeq);
  ACtx.StartTimer;
  LBack := GUnprotectRcv[2].Unprotect(LSeq, LWire);
  if Length(LBack) > 0 then
    BenchBlackBoxBytes(LBack[0], Length(LBack));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
  I: Integer;
  LMib: Double;
  LFailed: Boolean;
begin
  try
    InitBenchState;
    Writeln('[bench] cipher protect/unprotect throughput, ', PAYLOAD_LEN, 'B payload (floor ', FLOOR_MIBS:0:1, ' MiB/s per direction) – nextpas.core.bench');
    LSuite := TBenchSuite.Create('ssh-cipher');
    LSuite.Add('chacha20-poly1305/protect', @BenchProtectChacha);
    LSuite.Add('chacha20-poly1305/unprotect', @BenchUnprotectChacha);
    LSuite.Add('aes256-gcm/protect', @BenchProtectAesGcm);
    LSuite.Add('aes256-gcm/unprotect', @BenchUnprotectAesGcm);
    LSuite.Add('aes128-ctr+etm/protect', @BenchProtectAesCtrEtm);
    LSuite.Add('aes128-ctr+etm/unprotect', @BenchUnprotectAesCtrEtm);
    LResults := LSuite.Run;
    Writeln(LResults.PrintToConsole);

    { 门禁：按 BytesPerOp*OpsPerSec 换算 MiB/s，低于 FLOOR 判失败 }
    LAll := LResults.GetAll;
    LFailed := False;
    for I := 0 to High(LAll) do
    begin
      if not LAll[I].Executed or LAll[I].Skipped then Continue;
      if (LAll[I].BytesPerOp > 0) and (LAll[I].NsPerOp > 0) then
        LMib := LAll[I].BytesPerOp * LAll[I].OpsPerSec / (1024 * 1024)
      else
        LMib := 0;
      if LMib < FLOOR_MIBS then
      begin
        Writeln('[bench] ', LAll[I].Name, ': FAIL below floor ', FLOOR_MIBS:0:1, ' MiB/s (', LMib:0:1, ')');
        LFailed := True;
      end;
    end;
    if LFailed then
      ExitCode := 1
    else
      Writeln('[bench] PASS (floor ', FLOOR_MIBS:0:1, ' MiB/s per direction)');
    if LFailed then
      Halt(1);
  except
    on E: Exception do
    begin
      Writeln('[bench] EXCEPTION: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
