program test_geoip;

{ IP→国家查询表：加载（文件/内存）容错 + 二分查询 + IPv4 解析。
  构造小表（4 段，含段间空洞）覆盖：首/尾/段内/段外/未知/边界。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.bytes,
  nextpas.core.fs,
  nextpas.core.geoip,
  nextpas.core.test;

var
  T: TTestSuite;

const
  { 测试表（严格递增、无重叠、含空洞，按 FromIp 升序）:
    8.8.8.0    - 8.8.8.255    US（数值最小，首条）
    10.0.0.0   - 10.0.0.255   T1
    127.0.0.0  - 127.255.255.255 XX
    192.168.0.0- 192.168.255.255 T2（末条） }
  C_TEST_RECORDS = 4;

function BuildTestData: TBytes;
var
  LData: TBytes;
  LP: PByte;
begin
  SetLength(LData, 12 + C_TEST_RECORDS * 10);
  LP := @LData[0];
  LP[0] := Ord('P'); LP[1] := Ord('P'); LP[2] := Ord('G');
  LP[3] := Ord('I'); LP[4] := Ord('P');
  LP[5] := 1;                          { version }
  LP[6] := 0; LP[7] := 0;              { reserved }
  WriteUInt32BE(LP + 8, C_TEST_RECORDS);
  LP := LP + 12;
  { 8.8.8.0/24 → US（首条，按 FromIp 数值最小） }
  WriteUInt32BE(LP, $08080800); WriteUInt32BE(LP + 4, $080808FF);
  LP[8] := Ord('U'); LP[9] := Ord('S'); LP := LP + 10;
  { 10.0.0.0/24 → T1 }
  WriteUInt32BE(LP, $0A000000); WriteUInt32BE(LP + 4, $0A0000FF);
  LP[8] := Ord('T'); LP[9] := Ord('1'); LP := LP + 10;
  { 127.0.0.0/8 → XX }
  WriteUInt32BE(LP, $7F000000); WriteUInt32BE(LP + 4, $7FFFFFFF);
  LP[8] := Ord('X'); LP[9] := Ord('X'); LP := LP + 10;
  { 192.168.0.0/16 → T2（末条） }
  WriteUInt32BE(LP, $C0A80000); WriteUInt32BE(LP + 4, $C0A8FFFF);
  LP[8] := Ord('T'); LP[9] := Ord('2');
  Result := LData;
end;

var
  GTable: IGeoIpTable;

{ === 二分查询：整数 IP === }

procedure TestLookupFirstEntryStart;
begin
  CheckEqual('T1', GTable.Lookup($0A000000), '10.0.0.0 段首');
end;

procedure TestLookupFirstEntryEnd;
begin
  CheckEqual('T1', GTable.Lookup($0A0000FF), '10.0.0.255 段尾');
end;

procedure TestLookupLoopback;
begin
  CheckEqual('XX', GTable.Lookup($7F000001), '127.0.0.1');
end;

procedure TestLookupMiddleEntry;
begin
  CheckEqual('T2', GTable.Lookup($C0A80101), '192.168.1.1');
end;

procedure TestLookupLastEntry;
begin
  CheckEqual('US', GTable.Lookup($08080808), '8.8.8.8 末条');
end;

procedure TestLookupBeforeAll;
begin
  CheckEqual('', GTable.Lookup($09090909), '9.9.9.9（首条之前）未知');
end;

procedure TestLookupBetweenHole;
begin
  CheckEqual('', GTable.Lookup($0A000100), '10.0.1.0（段间空洞）未知');
end;

procedure TestLookupAfterAll;
begin
  CheckEqual('', GTable.Lookup($08080900), '8.8.9.0（末条之后）未知');
end;

procedure TestLookupUnassignedSpace;
begin
  CheckEqual('', GTable.Lookup($0B000001), '11.0.0.1（大空洞）未知');
end;

{ === IPv4 文本解析 === }

procedure TestLookupIpPlain;
begin
  CheckEqual('XX', GTable.LookupIp('127.0.0.1'), '文本 127.0.0.1');
end;

procedure TestLookupIpTrim;
begin
  CheckEqual('US', GTable.LookupIp('  8.8.8.8  '), '宽容首尾空白');
end;

procedure TestLookupIpTabTrim;
begin
  CheckEqual('T1', GTable.LookupIp(#9 + '10.0.0.1' + #9), '宽容 Tab 空白');
end;

procedure TestLookupIpOctetOverflow;
begin
  CheckEqual('', GTable.LookupIp('256.1.1.1'), '越界 256');
end;

procedure TestLookupIpTooFewSegs;
begin
  CheckEqual('', GTable.LookupIp('1.2.3'), '段数不足');
end;

procedure TestLookupIpTooManySegs;
begin
  CheckEqual('', GTable.LookupIp('1.2.3.4.5'), '段数多余（残留）');
end;

procedure TestLookupIpGarbage;
begin
  CheckEqual('', GTable.LookupIp('abc'), '非数字');
end;

procedure TestLookupIpEmpty;
begin
  CheckEqual('', GTable.LookupIp(''), '空串');
end;

procedure TestLookupIpNegative;
begin
  CheckEqual('', GTable.LookupIp('-1.2.3.4'), '负号拒绝');
end;

{ === 表元信息 === }

procedure TestCount;
begin
  CheckEqual(C_TEST_RECORDS, GTable.Count, '条数');
end;

{ === 内存构造容错 === }

procedure TestBuildEmpty;
var
  LTable: IGeoIpTable;
begin
  Check(not TryBuildGeoIpTable(nil, LTable), '空数据拒绝');
end;

procedure TestBuildBadMagic;
var
  LData: TBytes;
  LTable: IGeoIpTable;
begin
  LData := BuildTestData;
  LData[0] := Ord('X');
  Check(not TryBuildGeoIpTable(LData, LTable), '坏魔数拒绝');
end;

procedure TestBuildTruncated;
var
  LData: TBytes;
  LTable: IGeoIpTable;
begin
  LData := BuildTestData;
  SetLength(LData, Length(LData) - 3);
  Check(not TryBuildGeoIpTable(LData, LTable), '截断（长度不匹配）拒绝');
end;

procedure TestBuildOverlap;
var
  LData: TBytes;
  LTable: IGeoIpTable;
begin
  LData := BuildTestData;
  { 把第二条 from 改成 ≤ 前条 to（8.8.8.255）→ 重叠，二分前提被破坏 }
  WriteUInt32BE(@LData[12 + 10], $08080880);
  Check(not TryBuildGeoIpTable(LData, LTable), '重叠段拒绝');
end;

procedure TestBuildEmptyTable;
var
  LData: TBytes;
  LTable: IGeoIpTable;
begin
  { 合法空表：header 12 字节 + count=0（无记录段）。Count=0 下界曾致
    UInt32 循环上界 0-1 下溢 42 亿次越界（feedback_core：空表 hang/AV）。 }
  SetLength(LData, 12);
  LData[0] := Ord('P'); LData[1] := Ord('P'); LData[2] := Ord('G');
  LData[3] := Ord('I'); LData[4] := Ord('P');
  LData[5] := 1;
  LData[6] := 0; LData[7] := 0;
  WriteUInt32BE(@LData[8], 0);
  Check(TryBuildGeoIpTable(LData, LTable), '合法空表应构造成功');
  CheckEqual(0, LTable.Count, '空表条数');
  CheckEqual('', LTable.LookupIp('127.0.0.1'), '空表查询全空');
end;

{ === 文件加载 === }

procedure TestLoadMissingFile;
var
  LTable: IGeoIpTable;
begin
  Check(not TryLoadGeoIpTable('geoip_does_not_exist.dat', LTable), '缺文件返回 False');
end;

procedure TestLoadFromFile;
var
  LTable: IGeoIpTable;
  LPath: string;
begin
  LPath := 'geoip_test.dat';
  nextpas.core.fs.WriteFile(LPath, BuildTestData);
  Check(TryLoadGeoIpTable(LPath, LTable), '合法文件加载成功');
  CheckEqual('XX', LTable.LookupIp('127.0.0.1'), '文件加载后查询');
  nextpas.core.fs.DeleteFile(LPath);
end;

begin
  T := TTestSuite.Create('geoip');
  GTable := nil;
  Check(TryBuildGeoIpTable(BuildTestData, GTable), '测试表构造');
  T.Test('lookup 首条段首', @TestLookupFirstEntryStart);
  T.Test('lookup 首条段尾', @TestLookupFirstEntryEnd);
  T.Test('lookup 回环', @TestLookupLoopback);
  T.Test('lookup 中段', @TestLookupMiddleEntry);
  T.Test('lookup 末条', @TestLookupLastEntry);
  T.Test('lookup 首条之前未知', @TestLookupBeforeAll);
  T.Test('lookup 段间空洞未知', @TestLookupBetweenHole);
  T.Test('lookup 末条之后未知', @TestLookupAfterAll);
  T.Test('lookup 大空洞未知', @TestLookupUnassignedSpace);
  T.Test('ip 文本普通', @TestLookupIpPlain);
  T.Test('ip 文本首尾空白', @TestLookupIpTrim);
  T.Test('ip 文本 Tab 空白', @TestLookupIpTabTrim);
  T.Test('ip 文本越界拒绝', @TestLookupIpOctetOverflow);
  T.Test('ip 文本段不足拒绝', @TestLookupIpTooFewSegs);
  T.Test('ip 文本段多余拒绝', @TestLookupIpTooManySegs);
  T.Test('ip 文本非数字拒绝', @TestLookupIpGarbage);
  T.Test('ip 文本空串拒绝', @TestLookupIpEmpty);
  T.Test('ip 文本负号拒绝', @TestLookupIpNegative);
  T.Test('表条数', @TestCount);
  T.Test('构造空数据拒绝', @TestBuildEmpty);
  T.Test('构造坏魔数拒绝', @TestBuildBadMagic);
  T.Test('构造截断拒绝', @TestBuildTruncated);
  T.Test('构造重叠拒绝', @TestBuildOverlap);
  T.Test('构造合法空表', @TestBuildEmptyTable);
  T.Test('加载缺文件拒绝', @TestLoadMissingFile);
  T.Test('加载文件成功', @TestLoadFromFile);
  if not T.Run then
    Halt(1);
  GTable := nil;   { 主动释放全局表，heaptrc 基线 0（与既有测试对齐） }
end.
