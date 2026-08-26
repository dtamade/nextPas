program bench_tls13_record;
{$mode ObjFPC}{$H+}
{
  TLS 1.3 记录层 AEAD 吞吐基准 —— tlsfp 泵密码学路径保真测量。

  测什么（与 nextpas.core.net.async.tlsfp 数据相完全相同的调用链）：
  1. record：TTLS13RecordSealer/Opener 循环 —— 含 BuildNonce/AAD、
     TryTLS13AEADEncrypt/Decrypt 的 Split/Combine 分配拷贝、
     InnerPlaintext 编解码 —— 泵每条 16KiB 记录的真实成本。
  2. raw：PurePascalAESGCMEncrypt/Decrypt 单次大缓冲调用 ——
     密码学原语天花板（无每记录分配税）。

  两者差值 = 每记录分配/拷贝税，用于指导优化落点。

  先做一次正确性往返（字节级比对），再计时。吞吐低于 FLOOR 视为
  门禁失败（捕获灾难性回退）。

  注意：本程序用 -O3 且不启用 heaptrc（见 Makefile），
  分配器检测开销会严重扭曲吞吐数据。先例：bench_ssh_cipher。
}
uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.time,
  nextpas.core.crypto.aesni,
  nextpas.core.crypto.aesgcm,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.recordsealer;

const
  FRAGMENT_LEN = 16384;         { TLS 最大明文片 }
  RECORDS      = 4096;          { 64 MiB / 方向 }
  RAW_BUF_LEN  = 16 * 1024 * 1024;
  RAW_ITERS    = 4;             { 64 MiB / 方向 }

  { 门禁下限（MiB/s）：灾难性回退捕获，非精确定标。
    实测基线（2026-08-26，聚合 GHASH 落地后）：record ≈600-660、
    raw ≈660-800；下限取实测低值再留 ~35% 余量 }
  FLOOR_RECORD_MIBS = 400.0;
  FLOOR_RAW_MIBS    = 450.0;

var
  GSeed: QWord;

function NextByte: Byte;
begin
  { xorshift64 确定性填充 }
  GSeed := GSeed xor (GSeed shl 13);
  GSeed := GSeed xor (GSeed shr 7);
  GSeed := GSeed xor (GSeed shl 17);
  Result := Byte(GSeed);
end;

function PatternBuf(ALen: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, ALen);
  for I := 0 to ALen - 1 do
    Result[I] := NextByte;
end;

function SameBytes(const A, B: TBytes): Boolean;
begin
  Result := Length(A) = Length(B);
  if Result and (Length(A) > 0) then
    Result := CompareMem(@A[0], @B[0], Length(A));
end;

procedure Fail(const AMsg: string);
begin
  WriteLn('FAIL: ', AMsg);
  Halt(1);
end;

{ ---------- 记录层循环（泵保真路径） ---------- }

procedure BenchRecordLayer(out AMibEnc, AMibDec: Double);
var
  LKey, LIV, LFragment: TBytes;
  LSeal, LRTSeal: TTLS13RecordSealer;
  LOpener, LRTOpener: TTLS13RecordOpener;
  LWires: array of TBytes;
  LRec, LBack, LPayload: TBytes;
  LErr: string;
  LCt: Byte;
  I: Integer;
  LT0, LT1: QWord;
begin
  LKey := PatternBuf(16);
  LIV := PatternBuf(12);
  LFragment := PatternBuf(FRAGMENT_LEN);
  LErr := '';

  { 正确性往返（独立实例，不污染计时状态） }
  LRTSeal.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
  LRTOpener.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
  if not LRTSeal.Seal(LFragment, 23, LRec, LErr) then
    Fail('seal roundtrip');
  LPayload := Copy(LRec, 5, Length(LRec) - 5);
  if not LRTOpener.Open(LPayload, LBack, LCt, LErr) then
    Fail('open roundtrip: ' + LErr);
  if (LCt <> 23) or not SameBytes(LFragment, LBack) then
    Fail('roundtrip mismatch');

  { 预生成解密输入（不计入解密计时）：专用 sealer 从 seq0 起；
    Open 吃的是剥 5B 头后的载荷，与泵组帧后传给 Opener 的形态一致 }
  LSeal.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
  SetLength(LWires, RECORDS);
  for I := 0 to RECORDS - 1 do
  begin
    if not LSeal.Seal(LFragment, 23, LRec, LErr) then
      Fail('seal setup ' + IntToStr(I));
    LWires[I] := Copy(LRec, 5, Length(LRec) - 5);
  end;

  { 解密计时：全新 opener 与预生成序列严格对齐 }
  LOpener.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
  LT0 := GetTickCount64;
  for I := 0 to RECORDS - 1 do
  begin
    if not LOpener.Open(LWires[I], LBack, LCt, LErr) then
      Fail('bench open ' + IntToStr(I) + ': ' + LErr);
  end;
  LT1 := GetTickCount64;
  AMibDec := (Int64(RECORDS) * FRAGMENT_LEN / (1024 * 1024)) / ((LT1 - LT0) / 1000.0);

  { 加密计时（sealer 序列已推进，加密正确性与序列值无关） }
  LT0 := GetTickCount64;
  for I := 0 to RECORDS - 1 do
  begin
    if not LSeal.Seal(LFragment, 23, LRec, LErr) then
      Fail('bench seal');
  end;
  LT1 := GetTickCount64;
  AMibEnc := (Int64(RECORDS) * FRAGMENT_LEN / (1024 * 1024)) / ((LT1 - LT0) / 1000.0);

  { 密钥材料清零（纪律） }
  LSeal.Clear;
  LOpener.Clear;
  LRTSeal.Clear;
  LRTOpener.Clear;
end;

{ ---------- 裸大缓冲单发（密码学天花板） ---------- }

procedure BenchRaw(out AMibEnc, AMibDec: Double);
var
  LKey, LIV, LAad, LPlain, LCt, LTag, LBack: TBytes;
  I: Integer;
  LT0, LT1: QWord;
begin
  LKey := PatternBuf(16);
  LIV := PatternBuf(12);
  LAad := PatternBuf(5);
  LPlain := PatternBuf(RAW_BUF_LEN);

  if not PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAad, LCt, LTag) then
    Fail('raw encrypt');

  LT0 := GetTickCount64;
  for I := 1 to RAW_ITERS do
  begin
    if not PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAad, LCt, LTag) then
      Fail('raw bench encrypt');
  end;
  LT1 := GetTickCount64;
  AMibEnc := (Int64(RAW_ITERS) * RAW_BUF_LEN / (1024 * 1024)) / ((LT1 - LT0) / 1000.0);

  LT0 := GetTickCount64;
  for I := 1 to RAW_ITERS do
  begin
    if not PurePascalAESGCMDecrypt(LKey, LIV, LCt, LTag, LAad, LBack) then
      Fail('raw bench decrypt');
  end;
  LT1 := GetTickCount64;
  AMibDec := (Int64(RAW_ITERS) * RAW_BUF_LEN / (1024 * 1024)) / ((LT1 - LT0) / 1000.0);

  FillChar(LKey[0], Length(LKey), 0);
end;

var
  LRecEnc, LRecDec, LRawEnc, LRawDec: Double;
begin
  GSeed := QWord($9E3779B97F4A7C15);

  WriteLn('aesni available: ', Boolean(IsAESNIAvailable));
  WriteLn('fragment=', FRAGMENT_LEN, 'B records=', RECORDS,
    ' raw_buf=', RAW_BUF_LEN div (1024 * 1024), 'MiB x', RAW_ITERS);
  WriteLn('');

  BenchRecordLayer(LRecEnc, LRecDec);
  WriteLn(Format('record seal (aes128-gcm) : %8.1f MiB/s', [LRecEnc]));
  WriteLn(Format('record open (aes128-gcm) : %8.1f MiB/s', [LRecDec]));

  BenchRaw(LRawEnc, LRawDec);
  WriteLn(Format('raw encrypt (aes128-gcm) : %8.1f MiB/s', [LRawEnc]));
  WriteLn(Format('raw decrypt (aes128-gcm) : %8.1f MiB/s', [LRawDec]));

  WriteLn('');
  WriteLn(Format('per-record tax: enc %.0f%%  dec %.0f%%',
    [(1 - LRecEnc / LRawEnc) * 100, (1 - LRecDec / LRawDec) * 100]));

  if (LRecEnc < FLOOR_RECORD_MIBS) or (LRecDec < FLOOR_RECORD_MIBS) then
    Fail(Format('record throughput below floor %.1f MiB/s', [FLOOR_RECORD_MIBS]));
  if (LRawEnc < FLOOR_RAW_MIBS) or (LRawDec < FLOOR_RAW_MIBS) then
    Fail(Format('raw throughput below floor %.1f MiB/s', [FLOOR_RAW_MIBS]));

  WriteLn('PASS');
end.
