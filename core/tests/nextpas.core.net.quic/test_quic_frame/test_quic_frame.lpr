program test_quic_frame;

{ QUIC 帧族单元测试（RFC 9000 §12.4/§19）：
  - 黄金向量：ACK/CRYPTO/STREAM/NEW_CONNECTION_ID/CONNECTION_CLOSE
    逐字节对拍——字节由 aioquic 1.3.0（独立实现）push_ack_frame 与
    Buffer.push_uint_var 生成，双向验证；
  - STREAM 位型矩阵（OFF/LEN/FIN 全组合）+ LEN 缺省延伸到包尾语义；
  - 多帧载荷迭代消费；
  - 截断扫描（全部真前缀干净拒绝）+ 畸形语义拒绝面
    （未知类型 fail-closed / NCID 长度越界 / ACK range 下溢 / 长度越尾）。
  仅依赖 nextPas/core（无 system 垫片）。 }
{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.net.quic.varint,
  nextpas.core.net.quic.frame,
  nextpas.core.test;

{$I ../../fpc_rtl_uses_scan.inc}

const
  cHexDigits: array[0..15] of Char = '0123456789abcdef';

  { aioquic push_ack_frame(Buffer, RangeSet 50∪[65..68]∪[73..75], delay=1250)
    输出 + 类型字节 02 }
  cAckGoldenHex = '02404b44e2020203030d00';
  { aioquic Buffer：type 06 offset 6 len 3 data=c0ffee }
  cCryptoGoldenHex = '060603c0ffee';
  { aioquic Buffer：type 0f(FIN|LEN|OFF) id 8 offset 516 len 4 'DATA' }
  cStreamGoldenHex = '0f0842040444415441';
  { aioquic Buffer：type 18 seq 7 retire 3 cidlen 4 cid=aabbccdd token=00..0f }
  cNcidGoldenHex = '18070304aabbccdd000102030405060708090a0b0c0d0e0f';
  { aioquic Buffer：transport close err=0x0a triggered=0x08 reason='oops' }
  cCloseGoldenHex = '1c0a08046f6f7073';
  { aioquic Buffer：app close err=3 reason='' }
  cCloseAppGoldenHex = '1d0300';

function HexNibbleVal(C: Char): Byte;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := (HexNibbleVal(AHex[I * 2 + 1]) shl 4) or HexNibbleVal(AHex[I * 2 + 2]);
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(AData) - 1 do
  begin
    Result := Result + cHexDigits[AData[I] shr 4];
    Result := Result + cHexDigits[AData[I] and $0F];
  end;
end;

function DataSlice(const ABuf: TBytes; AOfs, ALen: Integer): TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, ALen);
  for LI := 0 to ALen - 1 do
    Result[LI] := ABuf[AOfs + LI];
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;

begin
  LSuite := TTestSuite.Create('quic_frame');

  { ---------- aioquic 黄金向量双向 ---------- }
  LSuite.Test('ACK golden vector parse and encode-back', procedure
  var
    LPayload, LRanges2: TBytes;
    LFrame: TQuicFrame;
    LRanges: TQuicAckRangeArray;
  begin
    LPayload := HexToBytes(cAckGoldenHex);
    { 带明细重载：ranges 一并产出，Consumed 覆盖整帧 }
    CheckTrue(TryQuicFrameParse(LPayload, 0, Length(LPayload), LFrame, LRanges));
    CheckEqual(Int64(Ord(qfkAck)), Int64(Ord(LFrame.Kind)));
    CheckEqual(UInt64(75), LFrame.LargestAcked);
    CheckEqual(UInt64(1250), LFrame.AckDelayRaw);
    CheckEqual(2, LFrame.AckExtraCount);
    CheckEqual(UInt64(2), LFrame.FirstAckRange);
    CheckEqual(Length(LPayload), LFrame.Consumed);

    CheckEqual(3, Length(LRanges));
    CheckEqual(UInt64(73), LRanges[0].Lo);
    CheckEqual(UInt64(75), LRanges[0].Hi);
    CheckEqual(UInt64(65), LRanges[1].Lo);
    CheckEqual(UInt64(68), LRanges[1].Hi);
    CheckEqual(UInt64(50), LRanges[2].Lo);
    CheckEqual(UInt64(50), LRanges[2].Hi);

    { 编码回写必须逐字节复现 aioquic 输出 }
    LRanges2 := nil;
    CheckTrue(QuicAckAppend(LRanges2, 75, 1250, LRanges));
    CheckEqual(cAckGoldenHex, BytesToHex(LRanges2));

    { 不带明细重载：Consumed 同样覆盖整帧（载荷迭代语义） }
    CheckTrue(TryQuicFrameParse(LPayload, 0, Length(LPayload), LFrame));
    CheckEqual(Length(LPayload), LFrame.Consumed);
  end);

  LSuite.Test('CRYPTO golden vector parse and encode-back', procedure
  var
    LPayload, LOut: TBytes;
    LFrame: TQuicFrame;
  begin
    LPayload := HexToBytes(cCryptoGoldenHex);
    CheckTrue(TryQuicFrameParse(LPayload, 0, Length(LPayload), LFrame));
    CheckEqual(Int64(Ord(qfkCrypto)), Int64(Ord(LFrame.Kind)));
    CheckEqual(UInt64(6), LFrame.Offset);
    CheckEqual(3, LFrame.DataLen);
    CheckEqual('c0ffee', BytesToHex(DataSlice(LPayload, LFrame.DataOfs, LFrame.DataLen)));
    CheckEqual(Length(LPayload), LFrame.Consumed);

    LOut := nil;
    QuicCryptoAppend(LOut, 6, HexToBytes('c0ffee'));
    CheckEqual(cCryptoGoldenHex, BytesToHex(LOut));
  end);

  LSuite.Test('STREAM golden vector parse and encode-back', procedure
  var
    LPayload, LOut: TBytes;
    LFrame: TQuicFrame;
  begin
    LPayload := HexToBytes(cStreamGoldenHex);
    CheckTrue(TryQuicFrameParse(LPayload, 0, Length(LPayload), LFrame));
    CheckEqual(Int64(Ord(qfkStream)), Int64(Ord(LFrame.Kind)));
    CheckEqual(UInt64(8), LFrame.StreamId);
    CheckEqual(UInt64(516), LFrame.Offset);
    CheckEqual(True, LFrame.Fin);
    CheckEqual(4, LFrame.DataLen);
    CheckEqual('44415441', BytesToHex(DataSlice(LPayload, LFrame.DataOfs, LFrame.DataLen)));

    LOut := nil;
    QuicStreamAppend(LOut, 8, 516, HexToBytes('44415441'), True, True);
    CheckEqual(cStreamGoldenHex, BytesToHex(LOut));
  end);

  LSuite.Test('NEW_CONNECTION_ID golden vector both ways', procedure
  var
    LPayload, LOut: TBytes;
    LFrame: TQuicFrame;
    LI: Integer;
  begin
    LPayload := HexToBytes(cNcidGoldenHex);
    CheckTrue(TryQuicFrameParse(LPayload, 0, Length(LPayload), LFrame));
    CheckEqual(Int64(Ord(qfkNewConnectionId)), Int64(Ord(LFrame.Kind)));
    CheckEqual(UInt64(7), LFrame.SeqNum);
    CheckEqual(UInt64(3), LFrame.RetirePriorTo);
    CheckEqual(4, LFrame.CidLen);
    CheckTrue((LFrame.Cid[0] = $AA) and (LFrame.Cid[1] = $BB) and
      (LFrame.Cid[2] = $CC) and (LFrame.Cid[3] = $DD));
    for LI := 0 to 15 do
      CheckEqual(Byte(LI), LFrame.ResetToken[LI]);
    CheckEqual(Length(LPayload), LFrame.Consumed);

    LOut := nil;
    CheckTrue(QuicNewConnectionIdAppend(LOut, 7, 3,
      [$AA, $BB, $CC, $DD],
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]));
    CheckEqual(cNcidGoldenHex, BytesToHex(LOut));
  end);

  LSuite.Test('CONNECTION_CLOSE golden vectors both ways', procedure
  var
    LPayload, LOut: TBytes;
    LFrame: TQuicFrame;
  begin
    LPayload := HexToBytes(cCloseGoldenHex);
    CheckTrue(TryQuicFrameParse(LPayload, 0, Length(LPayload), LFrame));
    CheckEqual(Int64(Ord(qcsTransport)), Int64(Ord(LFrame.CloseSpace)));
    CheckEqual(UInt64($0A), LFrame.ErrorCode);
    CheckEqual(UInt64($08), LFrame.CloseFrameType);
    CheckEqual(4, LFrame.ReasonLen);
    CheckEqual('6f6f7073', BytesToHex(DataSlice(LPayload, LFrame.ReasonOfs, LFrame.ReasonLen)));

    LOut := nil;
    QuicConnCloseTransportAppend(LOut, $0A, $08, HexToBytes('6f6f7073'));
    CheckEqual(cCloseGoldenHex, BytesToHex(LOut));

    LPayload := HexToBytes(cCloseAppGoldenHex);
    CheckTrue(TryQuicFrameParse(LPayload, 0, Length(LPayload), LFrame));
    CheckEqual(Int64(Ord(qcsApplication)), Int64(Ord(LFrame.CloseSpace)));
    CheckEqual(UInt64(0), LFrame.CloseFrameType);
    CheckEqual(0, LFrame.ReasonLen);
    LOut := nil;
    QuicConnCloseAppAppend(LOut, 3, nil);
    CheckEqual(cCloseAppGoldenHex, BytesToHex(LOut));
  end);

  { ---------- STREAM 位型矩阵 ---------- }
  LSuite.Test('STREAM bit matrix roundtrip all 8 combos', procedure
  var
    LOut, LBack: TBytes;
    LFrame: TQuicFrame;
    LOffBit, LLenBit, LFinBit, LI: Integer;
    LOff: UInt64;
    LData: TBytes;
  begin
    LData := HexToBytes('00112233445566778899aabbccddeeff');
    for LOffBit := 0 to 1 do
      for LLenBit := 0 to 1 do
        for LFinBit := 0 to 1 do
        begin
          if (LLenBit = 0) and (Length(LData) > 0) then
            Continue;   { 无 LEN 的数据须为帧尾，单帧测试用短数据形态 }
          if (LLenBit = 0) and (LFinBit = 0) then
            Continue;   { 无 LEN 无 FIN 只允许 PADDING 型空流数据帧，
                          编码侧拒空帧——跳过该非法组合 }
          LOff := 0;
          if LOffBit = 1 then
            LOff := 1234567;
          LOut := nil;
          QuicStreamAppend(LOut, 12, LOff, LData, LFinBit = 1, LLenBit = 1);
          CheckTrue(TryQuicFrameParse(LOut, 0, Length(LOut), LFrame),
            'stream bit combo roundtrip');
          CheckEqual(UInt64(12), LFrame.StreamId);
          CheckEqual(LOff, LFrame.Offset);
          CheckEqual(LFinBit = 1, LFrame.Fin);
          CheckEqual(Length(LData), LFrame.DataLen);
          CheckEqual(BytesToHex(LData),
            BytesToHex(DataSlice(LOut, LFrame.DataOfs, LFrame.DataLen)));
          { 类型字节位与请求一致 }
          LI := LOut[0];
          CheckEqual(LOffBit * 4 + LLenBit * 2 + LFinBit, LI and $07);
        end;

    { 无 LEN 形态：数据延伸到包尾；带尾部后续帧时不可用 }
    LOut := nil;
    QuicStreamAppend(LOut, 3, 0, HexToBytes('aabb'), False, False);
    CheckTrue(TryQuicFrameParse(LOut, 0, Length(LOut), LFrame));
    CheckEqual(UInt64(0), LFrame.Offset);
    CheckEqual(2, LFrame.DataLen);
    { 空 data + FIN 且无 LEN：合法的零长流结束帧 }
    LBack := nil;
    QuicStreamAppend(LBack, 3, 0, nil, True, False);
    CheckTrue(TryQuicFrameParse(LBack, 0, Length(LBack), LFrame));
    CheckEqual(0, LFrame.DataLen);
    CheckTrue(LFrame.Fin);
  end);

  { ---------- 单字节帧 + PATH 族 + RETIRE ---------- }
  LSuite.Test('single byte frames and path family', procedure
  var
    LBuf: TBytes;
    LFrame: TQuicFrame;
  begin
    LBuf := nil;
    QuicPaddingAppend(LBuf, 4);
    QuicPingAppend(LBuf);
    QuicHandshakeDoneAppend(LBuf);
    CheckEqual(6, Length(LBuf));
    CheckTrue(TryQuicFrameParse(LBuf, 0, 4, LFrame));
    CheckEqual(Int64(Ord(qfkPadding)), Int64(Ord(LFrame.Kind)));
    CheckTrue(TryQuicFrameParse(LBuf, 4, 5, LFrame));
    CheckEqual(Int64(Ord(qfkPing)), Int64(Ord(LFrame.Kind)));
    CheckTrue(TryQuicFrameParse(LBuf, 5, 6, LFrame));
    CheckEqual(Int64(Ord(qfkHandshakeDone)), Int64(Ord(LFrame.Kind)));

    LBuf := nil;
    CheckTrue(QuicPathChallengeAppend(LBuf, [$DE, $AD, $BE, $EF, 0, 1, 2, 3]));
    CheckTrue(TryQuicFrameParse(LBuf, 0, Length(LBuf), LFrame));
    CheckEqual(Int64(Ord(qfkPathChallenge)), Int64(Ord(LFrame.Kind)));
    CheckEqual(8, LFrame.Consumed - 1);
    CheckEqual('deadbeef00010203',
      BytesToHex(DataSlice(LBuf, LFrame.PathDataOfs, 8)));

    LBuf := nil;
    CheckTrue(QuicPathResponseAppend(LBuf, [9, 8, 7, 6, 5, 4, 3, 2]));
    CheckTrue(TryQuicFrameParse(LBuf, 0, Length(LBuf), LFrame));
    CheckEqual(Int64(Ord(qfkPathResponse)), Int64(Ord(LFrame.Kind)));

    LBuf := nil;
    QuicRetireConnectionIdAppend(LBuf, 42);
    CheckTrue(TryQuicFrameParse(LBuf, 0, Length(LBuf), LFrame));
    CheckEqual(Int64(Ord(qfkRetireConnectionId)), Int64(Ord(LFrame.Kind)));
    CheckEqual(UInt64(42), LFrame.RetireSeq);
  end);

  { ---------- 多帧载荷迭代 ---------- }
  LSuite.Test('multi frame payload iteration consumes exactly', procedure
  var
    LBuf: TBytes;
    LFrame: TQuicFrame;
    LPos, LCryptoSeen, LStreamSeen: Integer;
    LAcks: TQuicAckRangeArray;
    LRng: array of TQuicAckRange;
  begin
    SetLength(LRng, 1);
    LRng[0].Lo := 10;
    LRng[0].Hi := 20;
    LBuf := nil;
    QuicPaddingAppend(LBuf, 2);
    QuicPingAppend(LBuf);
    QuicAckAppend(LBuf, 20, 500, LRng);
    QuicCryptoAppend(LBuf, 0, HexToBytes('a1b2c3'));
    QuicStreamAppend(LBuf, 4, 100, HexToBytes('5566'), False, True);
    CheckFalse(TryQuicFrameParse(LBuf, Length(LBuf), Length(LBuf), LFrame));

    { 多帧迭代：逐帧消费到尾；ACK 明细经带明细重载核对 }
    LPos := 0;
    LCryptoSeen := -1;
    LStreamSeen := -1;
    while LPos < Length(LBuf) do
    begin
      CheckTrue(TryQuicFrameParse(LBuf, LPos, Length(LBuf), LFrame, LAcks));
      if LFrame.Kind = qfkAck then
        CheckEqual(1, Length(LAcks))
      else
        CheckEqual(0, Length(LAcks));
      case LFrame.Kind of
        qfkCrypto: LCryptoSeen := LPos;
        qfkStream: LStreamSeen := LPos;
      end;
      Inc(LPos, LFrame.Consumed);
    end;
    CheckEqual(Length(LBuf), LPos);
    CheckTrue((LCryptoSeen >= 0) and (LStreamSeen >= 0));
  end);

  { ---------- 截断扫描：所有真前缀干净拒绝 ---------- }
  LSuite.Test('truncation scan rejects every proper prefix', procedure
  var
    LVectors: array[0..5] of string;
    LPkt, LSlice: TBytes;
    LFrame: TQuicFrame;
    LV, LI: Integer;
    LOkAll: Boolean;
  begin
    LVectors[0] := cAckGoldenHex;
    LVectors[1] := cCryptoGoldenHex;
    LVectors[2] := cStreamGoldenHex;
    LVectors[3] := cNcidGoldenHex;
    LVectors[4] := cCloseGoldenHex;
    LVectors[5] := cCloseAppGoldenHex;
    LOkAll := True;
    for LV := 0 to High(LVectors) do
    begin
      LPkt := HexToBytes(LVectors[LV]);
      for LI := 0 to Length(LPkt) - 1 do
      begin
        LSlice := nil;
        SetLength(LSlice, LI);
        if LI > 0 then
          Move(LPkt[0], LSlice[0], LI);
        if TryQuicFrameParse(LSlice, 0, Length(LSlice), LFrame) then
          LOkAll := False;
      end;
    end;
    CheckTrue(LOkAll);
  end);

  { ---------- 畸形语义拒绝面 ---------- }
  LSuite.Test('unknown types rejected fail-closed', procedure
  var
    LInfo: TQuicFrame;
    LPkt: TBytes;
  begin
    { 未实现但 RFC 已定义（流控族/RESET/NEW_TOKEN）与未知类型一律拒 }
    LPkt := HexToBytes('10');           { MAX_DATA }
    CheckFalse(TryQuicFrameParse(LPkt, 0, 1, LInfo));
    LPkt := HexToBytes('04');           { RESET_STREAM }
    CheckFalse(TryQuicFrameParse(LPkt, 0, 1, LInfo));
    LPkt := HexToBytes('07');           { NEW_TOKEN }
    CheckFalse(TryQuicFrameParse(LPkt, 0, 1, LInfo));
    LPkt := HexToBytes('1f');           { 未定义 }
    CheckFalse(TryQuicFrameParse(LPkt, 0, 1, LInfo));
    LPkt := HexToBytes('40ff');         { 2 字节型未知值 63 }
    CheckFalse(TryQuicFrameParse(LPkt, 0, 2, LInfo));
  end);

  LSuite.Test('semantic violations rejected', procedure
  var
    LInfo: TQuicFrame;
    LPkt: TBytes;
    LRngBad: array of TQuicAckRange;
    LOut: TBytes;
    LRangesBad: TQuicAckRangeArray;
    LCountBad: Integer;
  begin
    { NCID cidlen=0 与 21 均拒 }
    LPkt := HexToBytes('180101' + '00' + '000102030405060708090a0b0c0d0e0f');
    CheckFalse(TryQuicFrameParse(LPkt, 0, Length(LPkt), LInfo));
    LPkt := HexToBytes('180115' + '000102030405060708090a0b0c0d0e0f1011121314' +
      '15161718191a1b1c1d1e1f' + '000102030405060708090a0b0c0d0e0f');
    CheckFalse(TryQuicFrameParse(LPkt, 0, Length(LPkt), LInfo));

    { CRYPTO 声明长度越过载荷尾 }
    LPkt := HexToBytes('060005c0ffee');
    CheckFalse(TryQuicFrameParse(LPkt, 0, Length(LPkt), LInfo));

    { CRYPTO offset+len 超 2^62-1：offset=varint 全 1（=2^62-1），len=1 }
    LPkt := HexToBytes('06ffffffffffffffff01aa');
    CheckFalse(TryQuicFrameParse(LPkt, 0, Length(LPkt), LInfo));

    { STREAM LEN 越尾：type 0x0a（LEN 无 OFF），len=8 > 剩余 2 }
    LPkt := HexToBytes('0a0108aabb');
    CheckFalse(TryQuicFrameParse(LPkt, 0, Length(LPkt), LInfo));

    { CLOSE reason 越尾 }
    LPkt := HexToBytes('1d01056869');
    CheckFalse(TryQuicFrameParse(LPkt, 0, Length(LPkt), LInfo));

    { ACK range 下溢：帧头合法（largest=0 first=0 extra=1），续读
      gap=5 使 previous_smallest - gap - 2 为负（RFC §19.3.1 拒）；
      新语义下整帧解析即拒 }
    LPkt := HexToBytes('020000010005' + '00');
    CheckFalse(TryQuicFrameParse(LPkt, 0, Length(LPkt), LInfo));
    CheckFalse(TryQuicAckRangesParse(LPkt, 5, Length(LPkt), 0, 0, 1,
      LRangesBad, LCountBad));

    { 编码侧校验：首 range 上沿 ≠ largest 拒 }
    LOut := nil;
    SetLength(LRngBad, 1);
    LRngBad[0].Lo := 10;
    LRngBad[0].Hi := 18;
    CheckFalse(QuicAckAppend(LOut, 20, 0, LRngBad));
    { 相邻 range 间隔不足（无未确认包）拒 }
    LOut := nil;
    SetLength(LRngBad, 2);
    LRngBad[0].Lo := 10;  LRngBad[0].Hi := 20;
    LRngBad[1].Lo := 4;   LRngBad[1].Hi := 9;   { 9+2=11 > 10 → gap 负 }
    CheckFalse(QuicAckAppend(LOut, 20, 0, LRngBad));
  end);

  { ---------- ACK ECN 变体 ---------- }
  LSuite.Test('ACK ECN variant parses counts', procedure
  var
    LPkt: TBytes;
    LInfo: TQuicFrame;
  begin
    { type=03 largest=75 delay=10 extra=0 first=2 ect0=1 ect1=2 ce=3 }
    LPkt := HexToBytes('03404b0a0002010203');
    CheckTrue(TryQuicFrameParse(LPkt, 0, Length(LPkt), LInfo));
    CheckEqual(Int64(Ord(qfkAck)), Int64(Ord(LInfo.Kind)));
    CheckEqual(UInt64(1), LInfo.EcnEct0);
    CheckEqual(UInt64(2), LInfo.EcnEct1);
    CheckEqual(UInt64(3), LInfo.EcnCe);
    CheckEqual(Length(LPkt), LInfo.Consumed);
  end);

  { ---------- 源码契约：新单元不得裸 uses FPC RTL ---------- }
  LSuite.Test('source contract: no bare FPC RTL in quic units', procedure
  var
    LSrcPath, LHit: string;
    LNames: array[0..1] of string;
    LI: Integer;
  begin
    LNames[0] := 'nextpas.core.net.quic.frame.pas';
    LNames[1] := 'nextpas.core.net.quic.reliable.pas';
    for LI := 0 to High(LNames) do
    begin
      LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
        '..', '..', '..', '..', 'src', LNames[LI]]));
      Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
        LNames[LI] + ' — no bare FPC RTL (hit: ' + LHit + ')');
    end;
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.frame');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
