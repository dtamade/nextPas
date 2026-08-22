program test_quic_varint;

{ QUIC varint（RFC 9000 §16）单元测试：
  规范四向量 + 值域边界 + 截断/越界拒绝 + 往返 + 追加助手。
  仅依赖 nextPas/core（无 system 垫片）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.net.quic.varint,
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

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('quic_varint');

  { RFC 9000 §16 四个规范向量 }
  LSuite.Test('RFC vectors encode exact bytes', procedure
  begin
    CheckEqual('19', BytesToHex(QuicVarintEncode(25)));
    CheckEqual('7bbd', BytesToHex(QuicVarintEncode(15293)));
    CheckEqual('9d7f3e7d', BytesToHex(QuicVarintEncode(494878333)));
    CheckEqual('c2197c5eff14d889', BytesToHex(QuicVarintEncode(UInt64(151288809941948553))));
  end);

  LSuite.Test('RFC vectors decode roundtrip', procedure
  var
    LV: UInt64;
    LC: Integer;
  begin
    CheckTrue(QuicVarintDecode(HexToBytes('19'), 0, LV, LC));
    CheckTrue((LV = 25) and (LC = 1));
    CheckTrue(QuicVarintDecode(HexToBytes('7bbd'), 0, LV, LC));
    CheckTrue((LV = 15293) and (LC = 2));
    CheckTrue(QuicVarintDecode(HexToBytes('9d7f3e7d'), 0, LV, LC));
    CheckTrue((LV = 494878333) and (LC = 4));
    CheckTrue(QuicVarintDecode(HexToBytes('c2197c5eff14d889'), 0, LV, LC));
    CheckTrue((LV = UInt64(151288809941948553)) and (LC = 8));
  end);

  { 值域边界：长度切换点两侧各一 }
  LSuite.Test('boundary lengths', procedure
  begin
    CheckEqual(1, QuicVarintEncodedLen(0));
    CheckEqual(1, QuicVarintEncodedLen(63));
    CheckEqual(2, QuicVarintEncodedLen(64));
    CheckEqual(2, QuicVarintEncodedLen(16383));
    CheckEqual(4, QuicVarintEncodedLen(16384));
    CheckEqual(4, QuicVarintEncodedLen($3FFFFFFF));
    CheckEqual(8, QuicVarintEncodedLen($40000000));
    CheckEqual(8, QuicVarintEncodedLen(cQuicVarintMaxValue));
    CheckEqual(0, QuicVarintEncodedLen(cQuicVarintMaxValue + 1));   { 超域 }
  end);

  LSuite.Test('boundary roundtrip', procedure
  const
    LB: array[0..5] of UInt64 = (0, 63, 64, 16383, 16384, cQuicVarintMaxValue);
  var
    LI: Integer;
    LBuf: TBytes;
    LV: UInt64;
    LC: Integer;
  begin
    for LI := Low(LB) to High(LB) do
    begin
      LBuf := QuicVarintEncode(LB[LI]);
      CheckEqual(QuicVarintEncodedLen(LB[LI]), Length(LBuf));
      CheckTrue(QuicVarintDecode(LBuf, 0, LV, LC));
      CheckEqual(LB[LI], LV);
      CheckEqual(Int64(Length(LBuf)), LC);
    end;
  end);

  { 超值域 Append 必须拒写且不动缓冲 }
  LSuite.Test('overflow append rejected without mutation', procedure
  var
    LBuf: TBytes;
  begin
    LBuf := HexToBytes('aabb');
    CheckFalse(QuicVarintAppend(LBuf, $4000000000000000));
    CheckEqual('aabb', BytesToHex(LBuf));
  end);

  { 截断解码：前缀声明长度 > 可用字节 -> False / consumed=0 }
  LSuite.Test('truncated decode rejected', procedure
  var
    LV: UInt64;
    LC: Integer;
  begin
    CheckFalse(QuicVarintDecode(nil, 0, LV, LC));
    CheckEqual(0, LC);
    CheckFalse(QuicVarintDecode(HexToBytes('40'), 0, LV, LC));      { 要 2B 给 1B }
    CheckFalse(QuicVarintDecode(HexToBytes('9d7f'), 0, LV, LC));    { 要 4B 给 2B }
    CheckFalse(QuicVarintDecode(HexToBytes('c2197c5eff14d8'), 0, LV, LC));
  end);

  { 中段偏移解码（包头里跳过前缀字段后读 varint 的实际形态） }
  LSuite.Test('decode at nonzero offset', procedure
  var
    LBuf: TBytes;
    LV: UInt64;
    LC: Integer;
  begin
    LBuf := HexToBytes('ff01' + '7bbd' + 'ee');
    CheckTrue(QuicVarintDecode(LBuf, 2, LV, LC));
    CheckTrue((LV = 15293) and (LC = 2));
  end);

  LSuite.Test('append byte helper', procedure
  var
    LBuf: TBytes;
  begin
    LBuf := nil;
    QuicBufAppendByte(LBuf, $DE);
    QuicBufAppendByte(LBuf, $AD);
    CheckEqual('dead', BytesToHex(LBuf));
  end);

  { 源码契约：本单元不得裸 uses FPC RTL }
  LSuite.Test('source contract: no bare FPC RTL', procedure
  var
    LSrcPath, LHit: string;
  begin
    LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
      '..', '..', '..', '..',
      'src', 'nextpas.core.net.quic.varint.pas']));
    Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
      'no bare FPC RTL in uses (hit: ' + LHit + ')');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.varint');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
