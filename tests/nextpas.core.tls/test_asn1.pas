program test_asn1;

{$mode objfpc}{$H+}

{**
 * ASN.1 解析器测试
 *
 * 测试 nextpas.core.tls.asn1 模块功能
 *}

uses
  SysUtils, Classes,
  nextpas.core.tls.asn1;

var
  TotalTests, PassedTests, FailedTests: Integer;

procedure Check(const AName: string; ASuccess: Boolean; const ADetails: string = '');
begin
  Inc(TotalTests);
  Write('  ', AName, ': ');
  if ASuccess then
  begin
    Inc(PassedTests);
    WriteLn('PASS');
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('FAIL');
    if ADetails <> '' then
      WriteLn('    ', ADetails);
  end;
end;

// 测试 OID 编解码
procedure TestOID;
var
  OID: string;
  Data: TBytes;
begin
  WriteLn;
  WriteLn('=== OID 编解码测试 ===');

  // 测试常见 OID
  OID := '2.5.4.3';  // CN
  Data := EncodeOID(OID);
  Check('编码 2.5.4.3', Length(Data) > 0);
  Check('解码 2.5.4.3', ParseOID(Data) = OID, ParseOID(Data));

  OID := '1.2.840.113549.1.1.11';  // sha256WithRSA
  Data := EncodeOID(OID);
  Check('编码 sha256WithRSA OID', Length(Data) > 0);
  Check('解码 sha256WithRSA OID', ParseOID(Data) = OID, ParseOID(Data));

  // 测试 OID 名称查找
  Check('OID 转名称 (CN)', OIDToName('2.5.4.3') = 'CN');
  Check('OID 转名称 (sha256)', OIDToName('2.16.840.1.101.3.4.2.1') = 'sha256');
  Check('名称转 OID (CN)', NameToOID('CN') = '2.5.4.3');
end;

// 测试基本 DER 解析
procedure TestDERParsing;
var
  Data: TBytes;
  Reader: TASN1Reader;
  Node: TASN1Node;
begin
  WriteLn;
  WriteLn('=== DER 解析测试 ===');

  // 测试 NULL
  SetLength(Data, 2);
  Data[0] := $05;  // NULL tag
  Data[1] := $00;  // length 0
  Reader := TASN1Reader.Create(Data);
  try
    Node := Reader.Parse;
    try
      Check('解析 NULL 标签', Node.IsNull);
      Check('NULL 长度为 0', Node.ContentLength = 0);
    finally
      Node.Free;
    end;
  finally
    Reader.Free;
  end;

  // 测试 INTEGER
  SetLength(Data, 3);
  Data[0] := $02;  // INTEGER tag
  Data[1] := $01;  // length 1
  Data[2] := $42;  // value 66
  Reader := TASN1Reader.Create(Data);
  try
    Node := Reader.Parse;
    try
      Check('解析 INTEGER 标签', Node.IsInteger);
      Check('INTEGER 值正确', Node.AsInteger = 66, IntToStr(Node.AsInteger));
    finally
      Node.Free;
    end;
  finally
    Reader.Free;
  end;

  // 测试 BOOLEAN
  SetLength(Data, 3);
  Data[0] := $01;  // BOOLEAN tag
  Data[1] := $01;  // length 1
  Data[2] := $FF;  // TRUE
  Reader := TASN1Reader.Create(Data);
  try
    Node := Reader.Parse;
    try
      Check('解析 BOOLEAN 标签', Node.IsBoolean);
      Check('BOOLEAN TRUE 值正确', Node.AsBoolean = True);
    finally
      Node.Free;
    end;
  finally
    Reader.Free;
  end;

  // 测试 OID
  SetLength(Data, 5);
  Data[0] := $06;  // OID tag
  Data[1] := $03;  // length 3
  Data[2] := $55;  // 2.5
  Data[3] := $04;  // .4
  Data[4] := $03;  // .3 = 2.5.4.3 (CN)
  Reader := TASN1Reader.Create(Data);
  try
    Node := Reader.Parse;
    try
      Check('解析 OID 标签', Node.IsOID);
      Check('OID 值正确', Node.AsOID = '2.5.4.3', Node.AsOID);
    finally
      Node.Free;
    end;
  finally
    Reader.Free;
  end;
end;

// 测试 SEQUENCE 解析
procedure TestSequenceParsing;
var
  Data: TBytes;
  Reader: TASN1Reader;
  Node: TASN1Node;
begin
  WriteLn;
  WriteLn('=== SEQUENCE 解析测试 ===');

  // SEQUENCE { INTEGER 1, INTEGER 2 }
  SetLength(Data, 8);
  Data[0] := $30;  // SEQUENCE tag
  Data[1] := $06;  // length 6
  Data[2] := $02;  // INTEGER tag
  Data[3] := $01;  // length 1
  Data[4] := $01;  // value 1
  Data[5] := $02;  // INTEGER tag
  Data[6] := $01;  // length 1
  Data[7] := $02;  // value 2

  WriteLn('  创建 Reader...');
  Reader := TASN1Reader.Create(Data);
  try
    WriteLn('  开始解析...');
    Node := Reader.Parse;
    try
      WriteLn('  检查 SEQUENCE...');
      Check('解析 SEQUENCE', Node.IsSequence);
      WriteLn('  检查子节点数量...');
      Check('SEQUENCE 有 2 个子节点', Node.ChildCount = 2, IntToStr(Node.ChildCount));
      if Node.ChildCount >= 2 then
      begin
        WriteLn('  检查第一个子节点...');
        Check('第一个子节点是 INTEGER', Node.GetChild(0).IsInteger);
        Check('第一个值 = 1', Node.GetChild(0).AsInteger = 1);
        WriteLn('  检查第二个子节点...');
        Check('第二个子节点是 INTEGER', Node.GetChild(1).IsInteger);
        Check('第二个值 = 2', Node.GetChild(1).AsInteger = 2);
      end;
    finally
      WriteLn('  释放 Node...');
      Node.Free;
    end;
  finally
    WriteLn('  释放 Reader...');
    Reader.Free;
  end;
end;

// 测试字符串解析
procedure TestStringParsing;
var
  Data: TBytes;
  Reader: TASN1Reader;
  Node: TASN1Node;
  TestStr: string;
begin
  WriteLn;
  WriteLn('=== 字符串解析测试 ===');

  // UTF8String "Hello"
  TestStr := 'Hello';
  SetLength(Data, 2 + Length(TestStr));
  Data[0] := $0C;  // UTF8String tag
  Data[1] := Length(TestStr);
  Move(TestStr[1], Data[2], Length(TestStr));

  Reader := TASN1Reader.Create(Data);
  try
    Node := Reader.Parse;
    try
      Check('解析 UTF8String', Node.IsUTF8String);
      Check('UTF8String 值正确', Node.AsString = 'Hello', Node.AsString);
    finally
      Node.Free;
    end;
  finally
    Reader.Free;
  end;

  // PrintableString "Test"
  TestStr := 'Test';
  SetLength(Data, 2 + Length(TestStr));
  Data[0] := $13;  // PrintableString tag
  Data[1] := Length(TestStr);
  Move(TestStr[1], Data[2], Length(TestStr));

  Reader := TASN1Reader.Create(Data);
  try
    Node := Reader.Parse;
    try
      Check('解析 PrintableString', Node.IsPrintableString);
      Check('PrintableString 值正确', Node.AsString = 'Test', Node.AsString);
    finally
      Node.Free;
    end;
  finally
    Reader.Free;
  end;
end;

// 测试时间解析
procedure TestTimeParsing;
var
  Data: TBytes;
  Reader: TASN1Reader;
  Node: TASN1Node;
  TimeStr: string;
  ExpectedDate: TDateTime;
begin
  WriteLn;
  WriteLn('=== 时间解析测试 ===');

  // UTCTime 251225120000Z (2025-12-25 12:00:00)
  TimeStr := '251225120000Z';
  SetLength(Data, 2 + Length(TimeStr));
  Data[0] := $17;  // UTCTime tag
  Data[1] := Length(TimeStr);
  Move(TimeStr[1], Data[2], Length(TimeStr));

  Reader := TASN1Reader.Create(Data);
  try
    Node := Reader.Parse;
    try
      Check('解析 UTCTime', Node.IsUTCTime);
      ExpectedDate := EncodeDate(2025, 12, 25) + EncodeTime(12, 0, 0, 0);
      Check('UTCTime 值正确', Abs(Node.AsDateTime - ExpectedDate) < 1/86400,
            DateTimeToStr(Node.AsDateTime));
    finally
      Node.Free;
    end;
  finally
    Reader.Free;
  end;
end;

// 测试标签转字符串
procedure TestTagToString;
begin
  WriteLn;
  WriteLn('=== 标签名称测试 ===');

  Check('SEQUENCE 标签名', TagToString(ASN1_TAG_SEQUENCE) = 'SEQUENCE');
  Check('INTEGER 标签名', TagToString(ASN1_TAG_INTEGER) = 'INTEGER');
  Check('OID 标签名', TagToString(ASN1_TAG_OID) = 'OBJECT IDENTIFIER');
  Check('UTF8String 标签名', TagToString(ASN1_TAG_UTF8STRING) = 'UTF8String');
end;

// 测试 Dump 功能
procedure TestDump;
var
  Data: TBytes;
  Reader: TASN1Reader;
  Node: TASN1Node;
  DumpStr: string;
begin
  WriteLn;
  WriteLn('=== Dump 功能测试 ===');

  // SEQUENCE { OID 2.5.4.3, UTF8String "Test" }
  SetLength(Data, 14);
  Data[0] := $30;  // SEQUENCE
  Data[1] := $0C;  // length 12
  Data[2] := $06;  // OID
  Data[3] := $03;  // length 3
  Data[4] := $55;  // 2.5
  Data[5] := $04;  // .4
  Data[6] := $03;  // .3
  Data[7] := $0C;  // UTF8String
  Data[8] := $05;  // length 5
  Data[9] := Ord('T');
  Data[10] := Ord('e');
  Data[11] := Ord('s');
  Data[12] := Ord('t');
  Data[13] := 0;

  Reader := TASN1Reader.Create(Data);
  try
    Node := Reader.Parse;
    try
      DumpStr := Node.Dump;
      Check('Dump 不为空', Length(DumpStr) > 0);
      Check('Dump 包含 SEQUENCE', Pos('SEQUENCE', DumpStr) > 0);
      Check('Dump 包含 OID', Pos('2.5.4.3', DumpStr) > 0);
      WriteLn;
      WriteLn('Dump 输出:');
      WriteLn(DumpStr);
    finally
      Node.Free;
    end;
  finally
    Reader.Free;
  end;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;

  WriteLn('========================================');
  WriteLn('fafafa.ssl ASN.1 解析器测试');
  WriteLn('========================================');

  try
    TestOID;
    TestDERParsing;
    TestSequenceParsing;
    TestStringParsing;
    TestTimeParsing;
    TestTagToString;
    TestDump;

    WriteLn;
    WriteLn('========================================');
    WriteLn('测试结果');
    WriteLn('========================================');
    WriteLn('总测试数: ', TotalTests);
    WriteLn('通过: ', PassedTests);
    WriteLn('失败: ', FailedTests);
    if TotalTests > 0 then
      WriteLn('通过率: ', (PassedTests * 100) div TotalTests, '%');
    WriteLn('========================================');

    if FailedTests > 0 then
      Halt(1)
    else
      Halt(0);

  except
    on E: Exception do
    begin
      WriteLn('致命错误: ', E.Message);
      Halt(1);
    end;
  end;
end.
