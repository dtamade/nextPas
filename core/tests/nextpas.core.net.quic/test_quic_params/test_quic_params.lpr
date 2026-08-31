program test_quic_params;

{ QUIC transport parameters 编解码单元测试（RFC 9000 §7.4/§18）：
  手工线格式核对 + 往返等值 + 重复 id / 尾垃圾 / 越界拒绝 +
  类型化 varint 层 + 防御性拷贝契约。
  仅依赖 nextPas/core（无 system 垫片）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.net.quic.varint,
  nextpas.core.net.quic.params,
  nextpas.core.test;

{$I ../../fpc_rtl_uses_scan.inc}

const
  cHexDigits: array[0..15] of Char = '0123456789abcdef';

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

function SliceBytes(const AData: TBytes; ACount: Integer): TBytes;
var
  I: Integer;
begin
  Result := nil;
  if ACount > Length(AData) then
    ACount := Length(AData);
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
    Result[I] := AData[I];
end;

function GrownByOne(const AData: TBytes; ATail: Byte): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AData) + 1);
  for I := 0 to Length(AData) - 1 do
    Result[I] := AData[I];
  Result[Length(AData)] := ATail;
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('quic_params');

  { 空参数集：编码空缓冲、解码合法零项 }
  LSuite.Test('empty parameter set roundtrip', procedure
  var
    LWire: TBytes;
    LOut: TQuicTransportParamArray;
  begin
    LWire := EncodeQuicTransportParams(nil);
    CheckEqual(0, Length(LWire));
    CheckTrue(TryDecodeQuicTransportParams(LWire, LOut));
    CheckEqual(0, Length(LOut));
  end);

  { 手工线格式：id=$01 max_idle_timeout varint(60000)=6a60 ->
    wire = 01 02 6a 60 }
  LSuite.Test('hand-checked wire format', procedure
  var
    LE: TQuicTransportParamArray;
    LWire: TBytes;
    LV: UInt64;
  begin
    CheckTrue(QuicParamAddVarint(LE, cQuicParamMaxIdleTimeout, 60000));
    LWire := EncodeQuicTransportParams(LE);
    { 60000 超出 2 字节 varint 上限 16383，正确形态为 4 字节 80 00 ea 60 }
    CheckEqual('0104' + '8000ea60', BytesToHex(LWire));
    CheckTrue(QuicParamGetVarint(LE, cQuicParamMaxIdleTimeout, LV));
    CheckEqual(UInt64(60000), LV);
  end);

  { 多类型条目往返：字节值 / 空值 / varint 值 / 未知 id 保序透传 }
  LSuite.Test('mixed entries roundtrip preserves order and values', procedure
  var
    LE, LDec: TQuicTransportParamArray;
    LWire: TBytes;
    LI: Integer;
    LV: UInt64;
  begin
    SetLength(LE, 4);
    LE[0].Id := cQuicParamOriginalDestinationConnectionId;
    LE[0].Value := HexToBytes('8394c8f03e515708');
    LE[1].Id := cQuicParamInitialMaxData;
    LE[1].Value := QuicVarintEncode(UInt64($100000000));   { 2^32 -> 8B varint }
    LE[2].Id := cQuicParamDisableActiveMigration;
    LE[2].Value := nil;                                    { 空值参数 }
    LE[3].Id := $63;                                       { 未知 id：透传 }
    LE[3].Value := HexToBytes('cafe');

    LWire := EncodeQuicTransportParams(LE);
    CheckTrue(TryDecodeQuicTransportParams(LWire, LDec));
    CheckEqual(Length(LE), Length(LDec));
    for LI := 0 to Length(LE) - 1 do
    begin
      CheckEqual(Int64(LE[LI].Id), Int64(LDec[LI].Id));
      CheckEqual(BytesToHex(LE[LI].Value), BytesToHex(LDec[LI].Value));
    end;
    { 类型化读取穿透往返结果 }
    CheckTrue(QuicParamGetVarint(LDec, cQuicParamInitialMaxData, LV));
    CheckEqual(UInt64($100000000), LV);
    CheckTrue(QuicParamFind(LDec, $63) = 3);
    CheckTrue(QuicParamFind(LDec, $99) < 0);
  end);

  { 重复 id：编码器是纯序列化器不拦；解码层按 RFC MUST NOT 拒收 }
  LSuite.Test('duplicate id rejected on decode', procedure
  var
    LE: TQuicTransportParamArray;
    LWire: TBytes;
    LDec: TQuicTransportParamArray;
  begin
    QuicParamAddEmpty(LE, $01);
    QuicParamAddEmpty(LE, $01);
    LWire := EncodeQuicTransportParams(LE);
    CheckTrue(Length(LWire) > 0);
    CheckFalse(TryDecodeQuicTransportParams(LWire, LDec));
  end);

  LSuite.Test('trailing garbage rejected', procedure
  var
    LWire, LBad: TBytes;
    LDec: TQuicTransportParamArray;
    LE: TQuicTransportParamArray;
  begin
    QuicParamAddEmpty(LE, $01);
    LWire := EncodeQuicTransportParams(LE);
    LBad := GrownByOne(LWire, $FF);
    CheckFalse(TryDecodeQuicTransportParams(LBad, LDec));
  end);

  LSuite.Test('truncated value rejected', procedure
  var
    LE, LDec: TQuicTransportParamArray;
    LWire, LBad: TBytes;
  begin
    SetLength(LE, 1);
    LE[0].Id := $00;
    LE[0].Value := HexToBytes('8394c8f03e515708');
    LWire := EncodeQuicTransportParams(LE);
    LBad := SliceBytes(LWire, Length(LWire) - 3);   { 截掉值尾 3B }
    CheckFalse(TryDecodeQuicTransportParams(LBad, LDec));
    { len 本身截断：只有 id 一个字节 }
    LBad := SliceBytes(LWire, 1);
    CheckFalse(TryDecodeQuicTransportParams(LBad, LDec));
  end);

  { 类型化层边界：Get 对非整长 varint 值返回 False；Add 超 2^62 拒写 }
  LSuite.Test('typed varint layer edge cases', procedure
  var
    LE: TQuicTransportParamArray;
    LV: UInt64;
  begin
    CheckFalse(QuicParamGetVarint(nil, cQuicParamAckDelayExponent, LV));

    SetLength(LE, 1);
    LE[0].Id := cQuicParamAckDelayExponent;
    LE[0].Value := HexToBytes('deadbeef');   { 3B 非法 varint 整长形态 }
    CheckFalse(QuicParamGetVarint(LE, cQuicParamAckDelayExponent, LV));

    QuicParamAddVarint(LE, cQuicParamActiveConnectionIdLimit, 2);
    CheckTrue(QuicParamGetVarint(LE, cQuicParamActiveConnectionIdLimit, LV));
    CheckEqual(UInt64(2), LV);
    CheckFalse(QuicParamAddVarint(LE, $55, cQuicVarintMaxValue + 1));
    CheckTrue(QuicParamFind(LE, $55) < 0);   { 拒写不得留半条目 }
  end);

  { AddBytes 防御性拷贝：登记后改源数组不影响 entry }
  LSuite.Test('add bytes defensive copy', procedure
  var
    LE: TQuicTransportParamArray;
    LVal: TBytes;
  begin
    LVal := HexToBytes('aabbcc');
    QuicParamAddBytes(LE, $77, LVal);
    LVal[0] := $FF;
    CheckEqual('aabbcc', BytesToHex(LE[0].Value));
    CheckEqual('ffbbcc', BytesToHex(LVal));
  end);

  { 大端序 varint 数值参数手工样例：initial_max_streams_bidi=256 -> 4100 }
  LSuite.Test('varint big-endian wire shape', procedure
  var
    LE: TQuicTransportParamArray;
    LWire: TBytes;
  begin
    CheckTrue(QuicParamAddVarint(LE, cQuicParamInitialMaxStreamsBidi, 256));
    LWire := EncodeQuicTransportParams(LE);
    CheckEqual('08' + '02' + '4100', BytesToHex(LWire));
  end);

  { 源码契约：本单元不得裸 uses FPC RTL }
  LSuite.Test('source contract: no bare FPC RTL', procedure
  var
    LSrcPath, LHit: string;
  begin
    LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
      '..', '..', '..', '..',
      'src', 'nextpas.core.net.quic.params.pas']));
    Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
      'no bare FPC RTL in uses (hit: ' + LHit + ')');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.params');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
