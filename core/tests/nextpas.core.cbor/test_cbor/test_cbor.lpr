program test_cbor;

{ RFC 8949 Appendix A 向量 + 确定性子集边界 + builder 往返 +
  恶性输入全拒（indefinite/tag/保留 ai/截断/谎报长度/残留字节/超深）。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.cbor,
  nextpas.core.test;

var
  T: TTestSuite;

function HexToBytes(const AHex: string): TBytes;
const
  DIGITS = '0123456789abcdef';
var
  LI: Integer;
  LHi, LLo: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for LI := 0 to Length(AHex) div 2 - 1 do
  begin
    LHi := Pos(LowerCase(AHex[LI * 2 + 1]), DIGITS) - 1;
    LLo := Pos(LowerCase(AHex[LI * 2 + 2]), DIGITS) - 1;
    Result[LI] := Byte(LHi * 16 + LLo);
  end;
end;

function BytesToHex(const AData: TBytes): string;
const
  DIGITS = '0123456789abcdef';
var
  LI: Integer;
begin
  Result := '';
  for LI := 0 to High(AData) do
    Result := Result + DIGITS[AData[LI] shr 4 + 1] + DIGITS[AData[LI] and $F + 1];
end;

{ ===== 整数（major 0/1）===== }

procedure TestUintAppendixA;
var
  LD: ICborDocument;
begin
  LD := CborParse(HexToBytes('00'));
  Check(not LD.HasError, 'uint 0 parses');
  CheckEqual(Int64(0), LD.Root.AsInt);

  LD := CborParse(HexToBytes('01'));
  Check((not LD.HasError) and (LD.Root.AsInt = 1), 'uint 1');

  LD := CborParse(HexToBytes('0a'));
  Check((not LD.HasError) and (LD.Root.AsInt = 10), 'uint 10 single byte');

  LD := CborParse(HexToBytes('17'));
  Check((not LD.HasError) and (LD.Root.AsInt = 23), 'uint 23 boundary inline');

  LD := CborParse(HexToBytes('1818'));
  Check((not LD.HasError) and (LD.Root.AsInt = 24), 'uint 24 first u8');

  LD := CborParse(HexToBytes('1864'));
  Check((not LD.HasError) and (LD.Root.AsInt = 100), 'uint 100');

  LD := CborParse(HexToBytes('1903e8'));
  Check((not LD.HasError) and (LD.Root.AsInt = 1000), 'uint 1000 u16');

  LD := CborParse(HexToBytes('1a000f4240'));
  Check((not LD.HasError) and (LD.Root.AsInt = 1000000), 'uint 1e6 u32');

  LD := CborParse(HexToBytes('1b000000e8d4a51000'));
  Check((not LD.HasError) and (LD.Root.AsInt = 1000000000000), 'uint 1e12 u64');

  { 子集边界：> High(Int64) 拒绝（RFC 全域 uint64 有意收窄）}
  LD := CborParse(HexToBytes('1bffffffffffffffff'));
  Check(LD.HasError, 'uint max-int64-exceeding rejected');
end;

procedure TestNegIntAppendixA;
var
  LD: ICborDocument;
begin
  LD := CborParse(HexToBytes('20'));
  Check((not LD.HasError) and (LD.Root.Kind = cbkNegInt) and
    (LD.Root.AsInt = -1), 'negint -1');

  LD := CborParse(HexToBytes('29'));
  Check((not LD.HasError) and (LD.Root.AsInt = -10), 'negint -10');

  LD := CborParse(HexToBytes('3863'));
  Check((not LD.HasError) and (LD.Root.AsInt = -100), 'negint -100');

  LD := CborParse(HexToBytes('3903e7'));
  Check((not LD.HasError) and (LD.Root.AsInt = -1000), 'negint -1000');
end;

{ ===== 字节串 / 文本串 ===== }

procedure TestBytesAndText;
var
  LD: ICborDocument;
  LB: TBytes;
begin
  LD := CborParse(HexToBytes('40'));
  Check((not LD.HasError) and LD.Root.IsBytes and (Length(LD.Root.AsBytes) = 0),
    'bytes empty');

  LD := CborParse(HexToBytes('4401020304'));
  LB := LD.Root.AsBytes;
  Check((Length(LB) = 4) and (LB[0] = $01) and (LB[3] = $04),
    'bytes 01020304 roundtrip content');

  LD := CborParse(HexToBytes('60'));
  Check((not LD.HasError) and LD.Root.IsText and LD.Root.AsStr.IsEmpty,
    'text empty');

  LD := CborParse(HexToBytes('6449455446'));
  Check((not LD.HasError) and (LD.Root.AsStrStr = 'IETF'), 'text IETF');

  LD := CborParse(HexToBytes('62225c'));
  Check((not LD.HasError) and (LD.Root.AsStrStr = '"\'), 'text quote backslash');

  LD := CborParse(HexToBytes('62c3bc'));
  Check((not LD.HasError) and (LD.Root.AsStr.Len = 2), 'text U+00FC two bytes');

  LD := CborParse(HexToBytes('63e6b0b4'));
  Check((not LD.HasError) and (LD.Root.AsStr.Len = 3), 'text U+6C34 three bytes');

  LD := CborParse(HexToBytes('64f0908591'));
  Check((not LD.HasError) and (LD.Root.AsStr.Len = 4), 'text U+10151 four bytes');
end;

{ ===== 容器（major 4/5）===== }

procedure TestContainers;
var
  LD: ICborDocument;
begin
  LD := CborParse(HexToBytes('80'));
  Check((not LD.HasError) and LD.Root.IsArray and (LD.Root.ChildCount = 0),
    'array empty');

  LD := CborParse(HexToBytes('83010203'));
  Check((not LD.HasError) and (LD.Root.ChildCount = 3) and
    (LD.Root.ChildAt(0).AsInt = 1) and (LD.Root.ChildAt(2).AsInt = 3),
    'array 1,2,3');

  LD := CborParse(HexToBytes('8301820203820405'));
  Check((not LD.HasError) and (LD.Root.ChildAt(1).IsArray) and
    (LD.Root.ChildAt(1).ChildAt(1).AsInt = 3), 'array nested');

  LD := CborParse(HexToBytes('a0'));
  Check((not LD.HasError) and LD.Root.IsMap and (LD.Root.PairCount = 0),
    'map empty');

  LD := CborParse(HexToBytes('a201020304'));
  Check((not LD.HasError) and (LD.Root.PairCount = 2) and
    (LD.Root.GetInt(1).AsInt = 2) and (LD.Root.GetInt(3).AsInt = 4),
    'map int keys 1:2,3:4');

  LD := CborParse(HexToBytes('a26161016162820203'));
  Check((not LD.HasError) and (LD.Root.Get('a').AsInt = 1) and
    (LD.Root.Get('b').IsArray) and (LD.Root.Get('b').ChildAt(1).AsInt = 3),
    'map text keys with array value');
end;

{ ===== major 7：bool/null/浮点 ===== }

procedure TestSimpleAndFloats;
var
  LD: ICborDocument;
begin
  LD := CborParse(HexToBytes('f5'));
  Check((not LD.HasError) and LD.Root.IsBool and LD.Root.AsBool, 'true');

  LD := CborParse(HexToBytes('f4'));
  Check((not LD.HasError) and LD.Root.IsBool and (not LD.Root.AsBool), 'false');

  LD := CborParse(HexToBytes('f6'));
  Check((not LD.HasError) and LD.Root.IsNull, 'null');

  LD := CborParse(HexToBytes('f7'));
  Check((not LD.HasError) and LD.Root.IsNull, 'undefined collapses to null kind');

  { half 1.5 = f93e00；half -4.0 = f9c400 }
  LD := CborParse(HexToBytes('f93e00'));
  Check((not LD.HasError) and LD.Root.IsReal, 'half float kind');
  Check(Abs(LD.Root.AsReal - 1.5) < 1e-10, 'half 1.5 value');

  LD := CborParse(HexToBytes('f9c400'));
  Check(Abs(LD.Root.AsReal - (-4.0)) < 1e-10, 'half -4.0 value');

  { half ±Inf：f97c00 / f9fc00 }
  LD := CborParse(HexToBytes('f97c00'));
  Check(LD.Root.AsReal > 1e308, 'half +inf');

  { single 100000.0 = fa47c35000 }
  LD := CborParse(HexToBytes('fa47c35000'));
  Check(Abs(LD.Root.AsReal - 100000.0) < 1e-6, 'single 100000.0');

  { double 1.5 = fb3ff8000000000000 }
  LD := CborParse(HexToBytes('fb3ff8000000000000'));
  Check(Abs(LD.Root.AsReal - 1.5) < 1e-10, 'double 1.5');
end;

{ ===== fail-closed 恶性输入全拒 ===== }

procedure TestRejectsMalformed;
var
  LD: ICborDocument;
  LDeep: string;
  LI: Integer;
begin
  { indefinite 系列（ai=31）全拒 }
  Check(CborParse(HexToBytes('9f01ff')).HasError, 'indefinite array rejected');
  Check(CborParse(HexToBytes('7f6161ff')).HasError, 'indefinite text rejected');
  Check(CborParse(HexToBytes('5f4102ff')).HasError, 'indefinite bytes rejected');
  LD := CborParse(HexToBytes('bf0000ff'));
  Check(LD.HasError, 'indefinite map rejected');

  { tag（major 6）拒绝 }
  Check(CborParse(HexToBytes('c000')).HasError, 'tag epoch rejected');

  { 保留 additional info（28..30）拒绝 }
  Check(CborParse(HexToBytes('1c')).HasError, 'reserved ai 28 rejected');
  Check(CborParse(HexToBytes('1d')).HasError, 'reserved ai 29 rejected');
  Check(CborParse(HexToBytes('1e')).HasError, 'reserved ai 30 rejected');

  { 截断 }
  Check(CborParse(HexToBytes('18')).HasError, 'u8 argument truncated');
  Check(CborParse(HexToBytes('1901')).HasError, 'u16 argument truncated');
  Check(CborParse(nil).HasError, 'nil input rejected');

  { 谎报长度 }
  Check(CborParse(HexToBytes('4301')).HasError, 'bytes length exceeds input');
  Check(CborParse(HexToBytes('6261')).HasError, 'text length exceeds input');

  { 根后残留字节 }
  Check(CborParse(HexToBytes('0000')).HasError, 'trailing bytes rejected');

  { 未支持简单值（ai 16）}
  Check(CborParse(HexToBytes('f0')).HasError, 'unassigned simple value rejected');

  { 深度上限：33 层嵌套数组 }
  LDeep := '';
  for LI := 0 to 32 do
    LDeep := LDeep + '81';
  LDeep := LDeep + '00';
  Check(CborParse(HexToBytes(LDeep)).HasError, 'depth limit rejected');
end;

{ ===== builder：确定性编码与往返 ===== }

procedure TestBuilderAppendixA;
var
  LB: ICborBuilder;
begin
  LB := CborBuilder;
  LB.Uint(0);   CheckEqual('00', BytesToHex(LB.ToBytes));
  LB := CborBuilder; LB.Uint(10);
  CheckEqual('0a', BytesToHex(LB.ToBytes), 'enc uint 10');
  LB := CborBuilder; LB.Uint(25);
  CheckEqual('1819', BytesToHex(LB.ToBytes), 'enc uint 25');
  LB := CborBuilder; LB.Uint(1000);
  CheckEqual('1903e8', BytesToHex(LB.ToBytes), 'enc uint 1000');
  LB := CborBuilder; LB.NegInt(-10);
  CheckEqual('29', BytesToHex(LB.ToBytes), 'enc negint -10');
  LB := CborBuilder; LB.Text('IETF');
  CheckEqual('6449455446', BytesToHex(LB.ToBytes), 'enc text IETF');
  LB := CborBuilder; LB.Bytes(HexToBytes('01020304'));
  CheckEqual('4401020304', BytesToHex(LB.ToBytes), 'enc bytes');
  LB := CborBuilder; LB.BeginArray(3); LB.Int(1); LB.Int(2); LB.Int(3);
  CheckEqual('83010203', BytesToHex(LB.ToBytes), 'enc array 1,2,3');
  LB := CborBuilder; LB.BeginMap(2);
  LB.Text('a'); LB.Int(1); LB.Text('b'); LB.BeginArray(2); LB.Int(2); LB.Int(3);
  CheckEqual('a26161016162820203', BytesToHex(LB.ToBytes), 'enc map a/b');
  LB := CborBuilder; LB.Float(1.5);
  CheckEqual('fb3ff8000000000000', BytesToHex(LB.ToBytes), 'enc double 1.5');
end;

procedure TestBuilderWebauthnShape;
var
  LB: ICborBuilder;
  LD: ICborDocument;
  LX, LY: TBytes;
begin
  (* COSE 公钥形（EC2/P-256）：1:kty=2, 3:alg=-7, -1:crv=1, -2:x, -3:y *)
  LX := HexToBytes('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');
  LY := HexToBytes('ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100');
  LB := CborBuilder;
  LB.BeginMap(5);
  LB.Int(1);  LB.Uint(2);
  LB.Int(3);  LB.NegInt(-7);
  LB.Int(-1); LB.Uint(1);
  LB.Int(-2); LB.Bytes(LX);
  LB.Int(-3); LB.Bytes(LY);
  LD := CborParse(LB.ToBytes);
  Check((not LD.HasError) and LD.Root.IsMap, 'cose key parses');
  CheckEqual(Int64(2), LD.Root.GetInt(1).AsInt, 'cose kty');
  CheckEqual(Int64(-7), LD.Root.GetInt(3).AsInt, 'cose alg');
  CheckEqual(Int64(1), LD.Root.GetInt(-1).AsInt, 'cose crv');
  Check(BytesToHex(LD.Root.GetInt(-2).AsBytes) =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff',
    'cose x coordinate');
  Check(BytesToHex(LD.Root.GetInt(-3).AsBytes) =
    'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100',
    'cose y coordinate');

  (* attestationObject 形：fmt=none, attStmt 空表, authData 字节串 *)
  LB := CborBuilder;
  LB.BeginMap(3);
  LB.Text('fmt');     LB.Text('none');
  LB.Text('attStmt'); LB.BeginMap(0);
  LB.Text('authData');LB.Bytes(HexToBytes('deadbeef'));
  LD := CborParse(LB.ToBytes);
  Check((not LD.HasError) and (LD.Root.Get('fmt').AsStrStr = 'none') and
    (LD.Root.Get('attStmt').PairCount = 0) and
    (Length(LD.Root.Get('authData').AsBytes) = 4),
    'attestation object shape roundtrip');
end;

{ ===== 前缀解析（混合格式容器：authData 内嵌 COSE 公钥等）===== }

procedure TestPrefixParse;
var
  LBuf: TBytes;
  LR: TCborPrefixResult;
begin
  { item + 尾随垃圾：只消费 item 本身 }
  LBuf := HexToBytes('80ffff');
  LR := CborParsePrefix(LBuf, 0);
  Check((not LR.Doc.HasError) and (LR.Consumed = 1) and LR.Doc.Root.IsArray,
    'prefix array with junk tail');

  { map + 尾随字节：内容可访问且消费长度精确（a1=map1, 键00 值01） }
  LBuf := HexToBytes('a10001beef');
  LR := CborParsePrefix(LBuf, 0);
  Check((not LR.Doc.HasError) and (LR.Consumed = 3)
    and (LR.Doc.Root.PairCount = 1) and (LR.Doc.Root.GetInt(0).AsInt = 1),
    'prefix map consumed length exact');

  { 中段偏移起解析 }
  LBuf := HexToBytes('000102');
  LR := CborParsePrefix(LBuf, 2);
  Check((not LR.Doc.HasError) and (LR.Consumed = 1)
    and (LR.Doc.Root.AsInt = 2),
    'prefix from mid offset');

  { 截断 item：HasError 且 Consumed=0 }
  LBuf := HexToBytes('82');
  LR := CborParsePrefix(LBuf, 0);
  Check(LR.Doc.HasError and (LR.Consumed = 0), 'prefix truncated rejected');

  { 越界偏移：显式报错不崩 }
  LBuf := HexToBytes('00');
  LR := CborParsePrefix(LBuf, 5);
  Check(LR.Doc.HasError and (LR.Consumed = 0), 'prefix offset beyond input');

  { 恶性输入在偏移处：保留错误语义 }
  LBuf := HexToBytes('00ff');
  LR := CborParsePrefix(LBuf, 1);
  Check(LR.Doc.HasError and (LR.Consumed = 0), 'prefix malformed at offset');
end;

procedure TestValueAccessorsEdgeCases;
var
  LD: ICborDocument;
  LMissing: TCborValue;
begin
  LD := CborParse(HexToBytes('a1616101'));
  LMissing := LD.Root.Get('zzz');
  Check(not LMissing.IsValid, 'missing key invalid');
  Check(LD.Root.Get('a').AsInt = 1, 'text key hit');
  Check(not LD.Root.GetInt(9).IsValid, 'missing int key invalid');
  Check(not LD.Root.ChildAt(99).IsValid, 'child out of bounds invalid');

  LD := CborParse(HexToBytes('a10107'));
  Check((not LD.HasError) and (LD.Root.GetInt(1).AsInt = 7),
    'int key hit still works');
end;

begin
  T := TTestSuite.Create('cbor');
  T.Test('uint appendix-a', @TestUintAppendixA);
  T.Test('negint appendix-a', @TestNegIntAppendixA);
  T.Test('bytes and text', @TestBytesAndText);
  T.Test('containers', @TestContainers);
  T.Test('simple and floats', @TestSimpleAndFloats);
  T.Test('reject malformed', @TestRejectsMalformed);
  T.Test('builder appendix-a', @TestBuilderAppendixA);
  T.Test('builder webauthn shape', @TestBuilderWebauthnShape);
  T.Test('value accessor edges', @TestValueAccessorsEdgeCases);
  T.Test('prefix parse', @TestPrefixParse);
  if not T.Run then Halt(1);
end.
