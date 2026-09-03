program test_zip_aes;
{**
 * test_zip_aes — WinZip AE-2 加密条目六期测试门。
 *
 * 覆盖：
 * 1. 密钥派生与 HMAC 对照 python/pycryptodome 独立实现的固定向量；
 * 2. 三种强度 × store/deflate 的写读往返（内存 + 可定位流两条读路径）；
 * 3. 流式添加路径（AddEntryStream + Password）的封框一致性；
 * 4. fail-closed：错口令、密文/认证码/盐篡改、缺口令、遗留 ZipCrypto、
 *    非法版本/强度/厂商、method99 无标志；错口令与篡改报文一致（无 oracle）；
 * 5. AE-1 读路径（patch 版本位 + 还原真实 CRC，CRC 强制校验保留）；
 * 6. 空载荷与 CTR 块边界尺寸；目录条目不加密；
 * 7. python3 独立实现交叉验证（缺 python3 或 pycryptodome 时显式失败）。
 *}
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.compress.intf,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha256,
  nextpas.core.zip,
  nextpas.core.zip.base,
  nextpas.core.zip.aes, nextpas.core.base.utils, nextpas.core.text, nextpas.core.text.conv;

var
  T: TTestSuite;
  GPassword: string;

const
  C_LOCAL_SIG   = $04034B50;
  C_CENTRAL_SIG = $02014B50;

  { python 参考向量：PBKDF2-HMAC-SHA1('secret-pass', bytes(0..7), 1000, 38) }
  C_VEC_ENC  = 'd088018722acc3abc4427032baefd981';
  C_VEC_AUTH = '35d538df652bcea30dec06a38406d06804d198cc';
  C_VEC_PWV  = '8dfd';
  { 已知 HMAC-SHA1 向量前缀（key='key'） }
  C_VEC_HMAC = 'de7c9b85b8b78aa6bc8a';

  { python3 独立解密交叉验证：argv[1]=zip argv[2]=manifest argv[3]=口令。
    manifest 每行 "名字<TAB>sha256hex"；目录条目跳过；zipfile 不识别
    method 99，按 local header 定位取原始帧自行解密。 }
  C_PY_CHECK =
    'import sys, zipfile, hashlib, hmac, zlib'#10 +
    'from Cryptodome.Cipher import AES'#10 +
    'from Cryptodome.Util import Counter'#10 +
    'path, manifest_path, pw = (sys.argv[1], sys.argv[2],'#10 +
    '    sys.argv[3].encode())'#10 +
    'KEYLEN = {1:16, 2:24, 3:32}'#10 +
    'SALT = {1:8, 2:12, 3:16}'#10 +
    'def strength_of(info):'#10 +
    '    b = info.extra; i = 0'#10 +
    '    while i + 4 <= len(b):'#10 +
    '        eid = int.from_bytes(b[i:i+2], "little")'#10 +
    '        sz = int.from_bytes(b[i+2:i+4], "little")'#10 +
    '        if eid == 0x9901:'#10 +
    '            return b[i+8], int.from_bytes(b[i+9:i+11], "little")'#10 +
    '        i += 4 + sz'#10 +
    '    raise SystemExit("no aes extra for " + info.filename)'#10 +
    'z = zipfile.ZipFile(path)'#10 +
    'expect = {}'#10 +
    'for line in open(manifest_path):'#10 +
    '    name, dig = line.rstrip("\n").split("\t")'#10 +
    '    expect[name] = dig'#10 +
    'seen = set()'#10 +
    'for info in z.infolist():'#10 +
    '    name = info.filename'#10 +
    '    if name.endswith("/"): continue'#10 +
    '    s, method = strength_of(info)'#10 +
    '    fp = z.fp'#10 +
    '    fp.seek(info.header_offset)'#10 +
    '    hdr = fp.read(30)'#10 +
    '    nlen = int.from_bytes(hdr[26:28], "little")'#10 +
    '    elen = int.from_bytes(hdr[28:30], "little")'#10 +
    '    fp.seek(info.header_offset + 30 + nlen + elen)'#10 +
    '    blob = fp.read(info.compress_size)'#10 +
    '    salt = blob[:SALT[s]]; pwv = blob[SALT[s]:SALT[s]+2]'#10 +
    '    ct = blob[SALT[s]+2:-10]; mac = blob[-10:]'#10 +
    '    dk = hashlib.pbkdf2_hmac("sha1", pw, salt, 1000, KEYLEN[s] + 22)'#10 +
    '    assert pwv == dk[KEYLEN[s]+20:], "pwv " + name'#10 +
    '    calc = hmac.new(dk[KEYLEN[s]:KEYLEN[s]+20], pwv + ct,'#10 +
    '        hashlib.sha1).digest()[:10]'#10 +
    '    assert mac == calc, "mac " + name'#10 +
    '    ctr = Counter.new(128, initial_value=1, little_endian=True)'#10 +
    '    pt = AES.new(dk[:KEYLEN[s]], AES.MODE_CTR, counter=ctr).decrypt(ct)'#10 +
    '    if method == 8: pt = zlib.decompress(pt, -15)'#10 +
    '    assert hashlib.sha256(pt).hexdigest() == expect[name], "sha "+name'#10 +
    '    seen.add(name)'#10 +
    'assert seen == set(k for k in expect), "coverage"'#10 +
    'print("CROSSCHECK OK")'#10;

function HexOf(const AB: TBytes): string;
var
  I: Integer;
const
  HD = '0123456789abcdef';
begin
  Result := '';
  for I := 0 to Length(AB) - 1 do
    Result := Result + HD[(AB[I] shr 4) and 15 + 1] + HD[AB[I] and 15 + 1];
end;

function StrBytes(const AStr: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AStr));
  for I := 1 to Length(AStr) do
    Result[I - 1] := Ord(AStr[I]);
end;

function Sha256Hex(const AB: TBytes): string;
var
  LH: IHasher;
begin
  LH := NewSHA256;
  if Length(AB) > 0 then
    LH.Write(AB[0], SizeUInt(Length(AB)));
  Result := HexOf(LH.SumBytes);
end;

function PatternBytes(ALen: Integer; ASeed: Integer): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, ALen);
  for LI := 0 to ALen - 1 do
  begin
    ASeed := (ASeed * 1103515245 + 12345) and $7FFFFFFF;
    Result[LI] := Byte((ASeed shr 16) and $FF);
  end;
end;

function FindSig(const AB: TBytes; ASig: LongWord): Integer;
var
  LI: Integer;
begin
  Result := -1;
  for LI := 0 to Length(AB) - 4 do
    if (AB[LI] = Byte(ASig)) and (AB[LI + 1] = Byte(ASig shr 8)) and
       (AB[LI + 2] = Byte(ASig shr 16)) and
       (AB[LI + 3] = Byte(ASig shr 24)) then
      Exit(LI);
end;

{ 单条目加密归档：AStrength 1..3，ADeflate 选压缩，名字固定 x.txt }
function BuildOne(const AData: TBytes; ADeflate: Boolean; AStrength: Byte;
  const APassword: TBytes): TBytes;
var
  LW: IZipWriter;
  LOpts: TZipAddOptions;
begin
  LW := NewZipWriter;
  LOpts := DefaultZipAddOptions;
  LOpts.Password := APassword;
  LOpts.AesStrength := AStrength;
  if ADeflate then
    LOpts.Method := zmDeflate;
  LW.AddEntryWithOptions('x.txt', AData, LOpts);
  Result := LW.Finish;
end;

{ 第 AOccur 次出现的 WinZip AES extra 内容体偏移（local 在 central 前；
  匹配 id+size+vendor 完整签名，跳过 id+size 头指向 version 字段） }
function FindAesExtraBody(const AB: TBytes; AOccur: Integer): Integer;
var
  LI, LFound: Integer;
begin
  LFound := 0;
  for LI := 0 to Length(AB) - 11 do
    if (AB[LI] = $01) and (AB[LI + 1] = $99) and
       (AB[LI + 2] = C_WINZIP_AES_EXTRA_BODY) and (AB[LI + 3] = 0) and
       (AB[LI + 6] = Ord('A')) and (AB[LI + 7] = Ord('E')) then
    begin
      Inc(LFound);
      if LFound = AOccur then
        Exit(LI + 4);
    end;
  Result := -1;
end;

{ 泵干整个条目流到动态数组（EOF 即返回） }
procedure ReadAllToBytes(const AR: IDecompressReader; out ADst: TBytes);
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
begin
  SetLength(ADst, 0);
  repeat
    LN := AR.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    if LN > 0 then
    begin
      SetLength(ADst, Length(ADst) + SizeInt(LN));
      Move(LBuf[0], PByte(@ADst[Length(ADst) - SizeInt(LN)])^, LN);
    end;
  until LN = 0;
end;

procedure TestDeriveAndAuthVectors;
var
  LPw, LSalt: TBytes;
  LKeys: TWinZipAesKeys;
  LH: IHasher;
  LMsg: TBytes;
  LGot: Boolean;
begin
  LPw := StrBytes('secret-pass');
  SetLength(LSalt, 8);
  LSalt[0] := 0; LSalt[1] := 1; LSalt[2] := 2; LSalt[3] := 3;
  LSalt[4] := 4; LSalt[5] := 5; LSalt[6] := 6; LSalt[7] := 7;

  LKeys := DeriveWinZipAesKeys(LPw, LSalt, 1);
  Check(HexOf(LKeys.EncKey) = C_VEC_ENC, 'derived enc key vector');
  Check(HexOf(LKeys.AuthKey) = C_VEC_AUTH, 'derived auth key vector');
  Check(HexOf(LKeys.PwVerify) = C_VEC_PWV, 'derived pw verify vector');

  LH := NewWinZipAesAuth(StrBytes('key'));
  LMsg := StrBytes('The quick brown fox jumps over the lazy dog');
  LH.Write(LMsg[0], SizeUInt(Length(LMsg)));
  Check(Copy(HexOf(LH.SumBytes), 1, Length(C_VEC_HMAC)) = C_VEC_HMAC,
    'hmac-sha1 known vector');

  LGot := False;
  try
    WinZipAesKeyBytes(7);
  except
    on E: EArgumentError do LGot := True;
  end;
  Check(LGot, 'invalid strength code raises argument error');

  Check(WinZipAesEqualBytes(StrBytes('ab'), StrBytes('ab')), 'equal bytes');
  Check(not WinZipAesEqualBytes(StrBytes('ab'), StrBytes('ac')),
    'unequal bytes');
  Check(not WinZipAesEqualBytes(StrBytes('ab'), StrBytes('abc')),
    'length mismatch unequal');
end;

procedure TestRoundtripAllStrengths;
var
  LData, LArchive, LGot: TBytes;
  LStrength: Integer;
  LDeflate: Boolean;
  LR: IZipReader;
  LE: TZipEntryInfo;
  LOpts: TZipReadOptions;
  LRealMethod: Int64;
begin
  for LDeflate := False to True do
    for LStrength := 1 to 3 do
    begin
      LData := PatternBytes(5000 + LStrength * 111, LStrength);
      LArchive := BuildOne(LData, LDeflate, Byte(LStrength),
        StrBytes('round-trip-pw'));

      LOpts := DefaultZipReadOptions;
      LOpts.Password := StrBytes('round-trip-pw');
      LR := NewZipReaderWithOptions(LArchive, LOpts);

      CheckEqual(Int64(1), Int64(LR.EntryCount), 'entry count');
      LE := LR.Entry(0);
      Check(LE.IsEncrypted, 'entry flagged encrypted');
      CheckEqual(Int64(C_WINZIP_AES_VERSION_2), Int64(LE.AesVersion),
        'entry is AE-2');
      CheckEqual(Int64(LStrength), Int64(LE.AesStrengthCode),
        'strength code surfaced');
      if LDeflate then
        LRealMethod := C_ZIP_METHOD_DEFLATE
      else
        LRealMethod := C_ZIP_METHOD_STORE;
      CheckEqual(LRealMethod, Int64(LE.MethodCode), 'real method surfaced');
      CheckEqual(Int64(0), Int64(LE.Crc32), 'AE-2 crc field is zero');

      LGot := LR.ExtractToBytesByName('x.txt');
      CheckEqual(Int64(Length(LData)), Int64(Length(LGot)), 'extract size');
      Check(CompareMem(@LGot[0], @LData[0], Length(LData)), 'extract content');

      ReadAllToBytes(LR.OpenEntryByName('x.txt'), LGot);
      CheckEqual(Int64(Length(LData)), Int64(Length(LGot)), 'stream size');
      Check(CompareMem(@LGot[0], @LData[0], Length(LData)), 'stream content');
    end;
end;

procedure TestRoundtripViaSeekableSource;
var
  LData, LArchive, LGot: TBytes;
  LS: IStream;
  LR: IZipReader;
  LOpts: TZipReadOptions;
begin
  LData := PatternBytes(30000, 42);
  LArchive := BuildOne(LData, True, 3, StrBytes('seek-pw'));
  LS := CreateBytesStreamFrom(LArchive);
  LOpts := DefaultZipReadOptions;
  LOpts.Password := StrBytes('seek-pw');
  LR := NewZipReaderFromWithOptions(LS, LOpts);
  LGot := LR.ExtractToBytesByName('x.txt');
  Check(CompareMem(@LGot[0], @LData[0], Length(LData)),
    'seekable source decrypt parity');
  ReadAllToBytes(LR.OpenEntryByName('x.txt'), LGot);
  Check(CompareMem(@LGot[0], @LData[0], Length(LData)),
    'seekable source stream parity');
end;

procedure TestStreamAddEncrypted;
var
  LData, LArchive, LGot: TBytes;
  LW: IZipWriter;
  LOpts: TZipAddOptions;
  LROpts: TZipReadOptions;
  LSink: ICompressWriter;
  LR: IZipReader;
  LI, LChunk: Integer;
begin
  LData := PatternBytes(70000, 7);
  LW := NewZipWriter;
  LOpts := DefaultZipAddOptions;
  LOpts.Method := zmDeflate;
  LOpts.Password := StrBytes('stream-pw');
  LOpts.AesStrength := 3;
  LSink := LW.AddEntryStream('stream.bin', LOpts);
  LI := 0;
  while LI < Length(LData) do
  begin
    LChunk := Length(LData) - LI;
    if LChunk > 4096 then
      LChunk := 4096;
    if LSink.Write(PByte(@LData[LI])^, SizeUInt(LChunk)) <>
      SizeUInt(LChunk) then
      Check(False, 'stream sink short write');
    Inc(LI, LChunk);
  end;
  LSink.Close;
  LArchive := LW.Finish;

  LROpts := DefaultZipReadOptions;
  LROpts.Password := StrBytes('stream-pw');
  LR := NewZipReaderWithOptions(LArchive, LROpts);
  LGot := LR.ExtractToBytesByName('stream.bin');
  CheckEqual(Int64(Length(LData)), Int64(Length(LGot)), 'streamed size');
  Check(CompareMem(@LGot[0], @LData[0], Length(LData)), 'streamed content');
end;

procedure TestWrongPasswordFailsClosed;
var
  LArchive, LGot: TBytes;
  LOpts: TZipReadOptions;
  LR: IZipReader;
  LS: IDecompressReader;
  LGotErr: Boolean;
  LMsgWrongPw: string;
  LArchiveTampered: TBytes;
  LMsgTamper: string;
  LTamperOfs: Integer;

  function ExtractExpectFail(const AArchive: TBytes;
    const APwd: string; out AMsg: string): Boolean;
  var
    LO: TZipReadOptions;
    LRr: IZipReader;
  begin
    Result := False;
    AMsg := '';
    LO := DefaultZipReadOptions;
    LO.Password := StrBytes(APwd);
    LRr := NewZipReaderWithOptions(AArchive, LO);
    try
      LRr.ExtractToBytesByName('x.txt');
    except
      on E: EParseError do
      begin
        Result := True;
        AMsg := E.Message;
      end;
    end;
  end;

begin
  LArchive := BuildOne(PatternBytes(2000, 11), True, 2, StrBytes('right-pw'));

  LGotErr := ExtractExpectFail(LArchive, 'wrong-pw', LMsgWrongPw);
  Check(LGotErr, 'wrong password raises parse error');
  { 认证码篡改与错口令必须报同一条消息（不泄露失败点 oracle）。
    store 固定布局：payload 起点 = local(30)+name(5)+extra(11)；
    帧 = salt(12)+pwv(2)+ct(2000)+mac(10)，认证码在帧尾 }
  LArchiveTampered := BuildOne(PatternBytes(2000, 11), False, 2,
    StrBytes('right-pw'));
  LTamperOfs := FindSig(LArchiveTampered, C_LOCAL_SIG) + 30 + 5 + 11 +
    12 + 2 + 2000 + 10 - 1;
  LArchiveTampered[LTamperOfs] := LArchiveTampered[LTamperOfs] xor $01;
  LGotErr := ExtractExpectFail(LArchiveTampered, 'right-pw', LMsgTamper);
  Check(LGotErr, 'tampered auth code raises parse error');
  Check(LMsgWrongPw = LMsgTamper, 'uniform failure message');

  { 流式路径：错口令在 EOF 认证码比对处 fail-closed }
  LOpts := DefaultZipReadOptions;
  LOpts.Password := StrBytes('wrong-pw');
  LR := NewZipReaderWithOptions(
    BuildOne(PatternBytes(2000, 11), True, 2, StrBytes('right-pw')), LOpts);
  LGot := nil;
  LGotErr := False;
  try
    LS := LR.OpenEntryByName('x.txt');
    ReadAllToBytes(LS, LGot);
  except
    on E: EParseError do LGotErr := True;
  end;
  Check(LGotErr, 'stream wrong password fails at eof');
end;

procedure TestTamperDetection;
var
  LArchive: TBytes;
  LOpts: TZipReadOptions;
  LR: IZipReader;
  LGotErr: Boolean;
  LPayloadOfs: Integer;

  procedure ExpectAuthFail(const AArchive: TBytes);
  var
    LO: TZipReadOptions;
    LRr: IZipReader;
  begin
    LO := DefaultZipReadOptions;
    LO.Password := StrBytes('tamper-pw');
    try
      LRr := NewZipReaderWithOptions(AArchive, LO);
      LRr.ExtractToBytesByName('x.txt');
    except
      on E: EParseError do LGotErr := True;
    end;
  end;

begin
  { 单条目 store 强度 1：payload 起点 = 30 + nlen(5) + elen(11) = 46；
    帧 = salt(8)+pwv(2)+ct(100)+mac(10) }
  LArchive := BuildOne(PatternBytes(100, 21), False, 1, StrBytes('tamper-pw'));
  LPayloadOfs := FindSig(LArchive, C_LOCAL_SIG) + 30 + 5 + 11;
  Check(LPayloadOfs > 40, 'fixture layout located');

  { 密文单字节翻转 }
  LGotErr := False;
  LArchive[LPayloadOfs + 12] := LArchive[LPayloadOfs + 12] xor $01;
  ExpectAuthFail(LArchive);
  Check(LGotErr, 'ciphertext tamper detected');

  { 盐单字节翻转 → 派生密钥变化 → 口令校验值失配 }
  LGotErr := False;
  LArchive := BuildOne(PatternBytes(100, 21), False, 1, StrBytes('tamper-pw'));
  LArchive[LPayloadOfs] := LArchive[LPayloadOfs] xor $80;
  ExpectAuthFail(LArchive);
  Check(LGotErr, 'salt tamper detected');

  { 认证码区域翻转（帧尾 10 字节内） }
  LGotErr := False;
  LArchive := BuildOne(PatternBytes(100, 21), False, 1, StrBytes('tamper-pw'));
  LArchive[LPayloadOfs + 8 + 2 + 100 + 3] :=
    LArchive[LPayloadOfs + 8 + 2 + 100 + 3] xor $FF;
  ExpectAuthFail(LArchive);
  Check(LGotErr, 'auth code tamper detected');

  { 未篡改基线必须可解 }
  LOpts := DefaultZipReadOptions;
  LOpts.Password := StrBytes('tamper-pw');
  LR := NewZipReaderWithOptions(
    BuildOne(PatternBytes(100, 21), False, 1, StrBytes('tamper-pw')), LOpts);
  CheckEqual(Int64(100), Int64(Length(LR.ExtractToBytesByName('x.txt'))),
    'untampered baseline extracts');
end;

procedure TestMissingPassword;
var
  LArchive: TBytes;
  LR: IZipReader;
  LGotExtract, LGotOpen: Boolean;
begin
  LArchive := BuildOne(PatternBytes(500, 31), True, 3, StrBytes('secret'));

  LR := NewZipReader(LArchive);     { 构造成功：解析不需要口令 }
  LGotExtract := False;
  try
    LR.ExtractToBytesByName('x.txt');
  except
    on E: EInvalidOperationError do LGotExtract := True;
  end;
  Check(LGotExtract, 'extract without password raises invalid operation');

  LGotOpen := False;
  try
    LR.OpenEntryByName('x.txt');
  except
    on E: EInvalidOperationError do LGotOpen := True;
  end;
  Check(LGotOpen, 'open without password raises invalid operation');
end;

procedure TestLegacyZipCryptoRejected;
var
  LRaw: TBytes;
  LCDPos, LLhoPos: Integer;
  LR: IZipReader;
  LS: IStream;
  LOpts: TZipReadOptions;
  LGotMem, LGotSrc: Boolean;
begin
  { 明文归档 patch central+local 的加密位（无 0x9901）：遗留 ZipCrypto 形态 }
  LRaw := BuildOne(PatternBytes(50, 5), False, 0, nil);
  LLhoPos := FindSig(LRaw, C_LOCAL_SIG);
  LCDPos := FindSig(LRaw, C_CENTRAL_SIG);
  LRaw[LCDPos + 8] := LRaw[LCDPos + 8] or $01;
  LRaw[LLhoPos + 6] := LRaw[LLhoPos + 6] or $01;

  LGotMem := False;
  try
    LR := NewZipReader(LRaw);
    LR.ExtractToBytesByName('x.txt');
  except
    on E: ENotSupportedError do LGotMem := True;
  end;
  Check(LGotMem, 'legacy zipcrypto rejected by memory reader');

  LGotSrc := False;
  LS := CreateBytesStreamFrom(LRaw);
  try
    NewZipReaderFrom(LS).ExtractToBytesByName('x.txt');
  except
    on E: ENotSupportedError do LGotSrc := True;
  end;
  Check(LGotSrc, 'legacy zipcrypto rejected by source reader');

  { 正常明文不受影响（守卫只对 bit0 生效） }
  LOpts := DefaultZipReadOptions;
  LR := NewZipReaderWithOptions(
    BuildOne(PatternBytes(50, 5), False, 0, nil), LOpts);
  CheckEqual(Int64(50),
    Int64(Length(LR.ExtractToBytesByName('x.txt'))),
    'plain archive still reads');
end;

procedure TestBadAesExtraVariants;
var
  LBase, LRaw: TBytes;
  LB1, LB2: Integer;
  LGot: Boolean;

  procedure PatchBoth(AOfs1, AOfs2: Integer; AIdx: Integer; AVal: Byte);
  begin
    LRaw[AOfs1 + AIdx] := AVal;
    LRaw[AOfs2 + AIdx] := AVal;
  end;

  { 构造期即拒绝的变体统一走这里 }
  function ConstructRaises(AClass: ExceptClass): Boolean;
  var
    LO: TZipReadOptions;
  begin
    Result := False;
    LO := DefaultZipReadOptions;
    LO.Password := StrBytes('variants-pw');
    try
      NewZipReaderWithOptions(LRaw, LO).ExtractToBytesByName('x.txt');
    except
      on E: ENextPasError do
        if E.ClassType = AClass then
          Result := True;
    end;
  end;

begin
  LBase := BuildOne(PatternBytes(300, 77), True, 2, StrBytes('variants-pw'));

  { 版本位改 3 → 不支持的 AE 版本 }
  LRaw := Copy(LBase);
  LB1 := FindAesExtraBody(LRaw, 1);
  LB2 := FindAesExtraBody(LRaw, 2);
  Check((LB1 > 0) and (LB2 > LB1), 'both aes extra bodies located');
  PatchBoth(LB1, LB2, 0, 3);      { version lo 字节 }
  Check(ConstructRaises(ENotSupportedError), 'unknown AE version refused');

  { 强度码改 7 → 结构非法 }
  LRaw := Copy(LBase);
  LB1 := FindAesExtraBody(LRaw, 1);
  LB2 := FindAesExtraBody(LRaw, 2);
  PatchBoth(LB1, LB2, 4, 7);
  Check(ConstructRaises(EParseError), 'invalid strength refused');

  { 厂商标识改 'XY' → 结构非法 }
  LRaw := Copy(LBase);
  LB1 := FindAesExtraBody(LRaw, 1);
  LB2 := FindAesExtraBody(LRaw, 2);
  PatchBoth(LB1, LB2, 2, Ord('X'));
  PatchBoth(LB1, LB2, 3, Ord('Y'));
  Check(ConstructRaises(EParseError), 'unknown vendor refused');

  { central 加密位清零但 method=99 → 解析期拒绝 }
  LRaw := Copy(LBase);
  LB1 := FindSig(LRaw, C_CENTRAL_SIG);
  LRaw[LB1 + 8] := LRaw[LB1 + 8] and $FE;
  Check(ConstructRaises(EParseError), 'method99 without flag refused');
end;

procedure TestAE1ReadPath;
var
  LData, LRaw: TBytes;
  LCrc: LongWord;
  LB1, LB2, LLocal, LCentral: Integer;
  LOpts: TZipReadOptions;
  LR: IZipReader;
  LGot: TBytes;
  LGotErr: Boolean;
begin
  { AE-2 归档 patch 成 AE-1：版本字置 1，头部 CRC 还原真实值 }
  LData := PatternBytes(1234, 99);
  LRaw := BuildOne(LData, True, 2, StrBytes('ae1-pw'));
  LCrc := Crc32OfBytes(LData);

  LB1 := FindAesExtraBody(LRaw, 1);
  LB2 := FindAesExtraBody(LRaw, 2);
  LRaw[LB1] := 1;                 { version lo = AE-1 }
  LRaw[LB2] := 1;
  LLocal := FindSig(LRaw, C_LOCAL_SIG);
  LCentral := FindSig(LRaw, C_CENTRAL_SIG);
  LRaw[LLocal + 14] := Byte(LCrc);
  LRaw[LLocal + 15] := Byte(LCrc shr 8);
  LRaw[LLocal + 16] := Byte(LCrc shr 16);
  LRaw[LLocal + 17] := Byte(LCrc shr 24);
  LRaw[LCentral + 16] := Byte(LCrc);
  LRaw[LCentral + 17] := Byte(LCrc shr 8);
  LRaw[LCentral + 18] := Byte(LCrc shr 16);
  LRaw[LCentral + 19] := Byte(LCrc shr 24);

  LOpts := DefaultZipReadOptions;
  LOpts.Password := StrBytes('ae1-pw');
  LR := NewZipReaderWithOptions(LRaw, LOpts);
  CheckEqual(Int64(C_WINZIP_AES_VERSION_1), Int64(LR.Entry(0).AesVersion),
    'AE-1 version surfaced');
  LGot := LR.ExtractToBytesByName('x.txt');
  Check(CompareMem(@LGot[0], @LData[0], Length(LData)), 'AE-1 extracts');
  CheckEqual(Int64(LCrc), Int64(LR.Entry(0).Crc32), 'AE-1 real crc surfaced');

  { AE-1 保留 CRC 强制校验：CRC 改错 → 提取期 crc mismatch }
  LRaw[LCentral + 16] := Byte(LCrc xor $01);
  LGotErr := False;
  try
    LR := NewZipReaderWithOptions(LRaw, LOpts);
    LR.ExtractToBytesByName('x.txt');
  except
    on E: EIOError do LGotErr := True;
  end;
  Check(LGotErr, 'AE-1 keeps crc enforcement');
end;

procedure TestEmptyAndBlockBoundary;
const
  C_SIZES: array[0..5] of Integer = (0, 1, 15, 16, 17, 65536);
var
  LData, LGot: TBytes;
  LI, LSize: Integer;
  LOpts: TZipReadOptions;
  LR: IZipReader;
begin
  LOpts := DefaultZipReadOptions;
  LOpts.Password := StrBytes('edge-pw');
  for LI := Low(C_SIZES) to High(C_SIZES) do
  begin
    LSize := C_SIZES[LI];
    LData := PatternBytes(LSize, LSize + 1000);
    LR := NewZipReaderWithOptions(
      BuildOne(LData, False, 3, StrBytes('edge-pw')), LOpts);
    LGot := LR.ExtractToBytesByName('x.txt');
    CheckEqual(Int64(LSize), Int64(Length(LGot)), 'boundary size roundtrip');
    if LSize > 0 then
      Check(CompareMem(@LGot[0], @LData[0], Length(LData)),
        'boundary content roundtrip');
  end;
end;

procedure TestDirectoryNotEncrypted;
var
  LArchive, LGot: TBytes;
  LW: IZipWriter;
  LOpts: TZipAddOptions;
  LROpts: TZipReadOptions;
  LR: IZipReader;
begin
  LW := NewZipWriter;
  LW.AddDirectory('docs/');
  LOpts := DefaultZipAddOptions;
  LOpts.Method := zmDeflate;
  LOpts.Password := StrBytes('dir-pw');
  LOpts.AesStrength := 3;
  LW.AddEntryWithOptions('docs/a.txt', PatternBytes(300, 55), LOpts);
  LArchive := LW.Finish;

  LROpts := DefaultZipReadOptions;
  LROpts.Password := StrBytes('dir-pw');
  LR := NewZipReaderWithOptions(LArchive, LROpts);
  Check(LR.Entry(0).IsDirectory, 'directory entry present');
  Check(not LR.Entry(0).IsEncrypted, 'directory entry not encrypted');
  LGot := LR.ExtractToBytesByName('docs/a.txt');
  CheckEqual(Int64(300), Int64(Length(LGot)), 'file entry after dir');
end;

procedure TestPythonCrossCheck;
var
  LW: IZipWriter;
  LOpts: TZipAddOptions;
  LArchive: TBytes;
  LPy: string;
  LDir: string;
  LManifest: string;
  LOut: TProcessOutput;
const
  N_STORE_S3 = 'store-s3.bin';
  N_DEFL_S1  = 'defl-s1.bin';
  N_DEFL_S2  = 'defl-s2.bin';
  N_EMPTY_S3 = 'empty-s3.bin';
  N_BND_S1   = 'bound-s1.bin';

  procedure AddCase(const AName: string; const AData: TBytes;
    ADeflate: Boolean; AStrength: Byte);
  begin
    LOpts := DefaultZipAddOptions;
    LOpts.Password := StrBytes(GPassword);
    LOpts.AesStrength := AStrength;
    if ADeflate then
      LOpts.Method := zmDeflate;
    LW.AddEntryWithOptions(AName, AData, LOpts);
    LManifest := LManifest + AName + #9 + Sha256Hex(AData) + #10;
  end;

begin
  if not TryLookPath('python3', LPy) then
  begin
    Check(False, 'python3 unavailable for zip aes cross-validation');
    Exit;
  end;

  LW := NewZipWriter;
  LManifest := '';
  AddCase(N_STORE_S3, PatternBytes(4000, 1), False, 3);
  AddCase(N_DEFL_S1, PatternBytes(9000, 2), True, 1);
  AddCase(N_DEFL_S2, PatternBytes(20000, 3), True, 2);
  AddCase(N_EMPTY_S3, nil, False, 3);
  AddCase(N_BND_S1, PatternBytes(17, 4), True, 1);
  LArchive := LW.Finish;

  LDir := TempDir(GetTempDir, 'zipaestest');
  WriteFile(LDir + '/case.zip', LArchive);
  WriteFile(LDir + '/manifest.tsv', StrBytes(LManifest));

  LOut := Command(LPy).Arg('-c').Arg(C_PY_CHECK)
    .Arg(LDir + '/case.zip').Arg(LDir + '/manifest.tsv')
    .Arg(GPassword).Output;
  Check(ProcessSucceeded(LOut),
    'python cross-check exit ok: ' + Trim(LOut.StdErr));
  Check(Pos('CROSSCHECK OK', LOut.StdOut) > 0, 'python cross-check marker');
end;

begin
  GPassword := 'gate-password';
  T := TTestSuite.Create('nextpas.core.zip.aes');
  T.Test('Derive and auth vectors', @TestDeriveAndAuthVectors);
  T.Test('Roundtrip all strengths', @TestRoundtripAllStrengths);
  T.Test('Seekable source roundtrip', @TestRoundtripViaSeekableSource);
  T.Test('Stream add encrypted', @TestStreamAddEncrypted);
  T.Test('Wrong password fails closed', @TestWrongPasswordFailsClosed);
  T.Test('Tamper detection', @TestTamperDetection);
  T.Test('Missing password guard', @TestMissingPassword);
  T.Test('Legacy ZipCrypto rejected', @TestLegacyZipCryptoRejected);
  T.Test('Bad AES extra variants', @TestBadAesExtraVariants);
  T.Test('AE-1 read path', @TestAE1ReadPath);
  T.Test('Empty and block boundary', @TestEmptyAndBlockBoundary);
  T.Test('Directory not encrypted', @TestDirectoryNotEncrypted);
  T.Test('Python cross-check', @TestPythonCrossCheck);
  if not T.Run then Halt(1);
end.
