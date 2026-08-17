program test_dns_wire;
{**
 * wire 层黄金向量: 名称编码/解码、压缩指针、TXT 多字符串、MX 排序、
 * SOA 字段、AAAA 文本化、RCODE/TC、畸形拒绝(契约 INV-1/2/8/9)。
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.dns.base;

type
  TB = array of Byte;

{ ── 报文构造助手(测试专用) ─────────────────────────────────────── }

function S2B(const AStr: string): TB;
var
  I: Integer;
begin
  SetLength(Result, Length(AStr));
  for I := 1 to Length(AStr) do
    Result[I - 1] := Byte(AStr[I]);
end;

function Concat(const A, B: TB): TB;
var
  L0: Integer;
begin
  L0 := Length(A);
  SetLength(Result, L0 + Length(B));
  if L0 > 0 then
    Move(A[0], Result[0], L0);
  if Length(B) > 0 then
    Move(B[0], Result[L0], Length(B));
end;

function Hex8(const A: Byte): TB;
begin
  SetLength(Result, 1);
  Result[0] := A;
end;

function B16(const A: UInt16): TB;
begin
  SetLength(Result, 2);
  Result[0] := Byte(A shr 8);
  Result[1] := Byte(A and $FF);
end;

function B32(const A: UInt32): TB;
begin
  SetLength(Result, 4);
  Result[0] := Byte(A shr 24);
  Result[1] := Byte((A shr 16) and $FF);
  Result[2] := Byte((A shr 8) and $FF);
  Result[3] := Byte(A and $FF);
end;

{ 名称 → wire labels }
function WireName(const AName: string): TB;
var
  LP, LStart: Integer;
begin
  Result := nil;
  LP := 1;
  while LP <= Length(AName) do
  begin
    LStart := LP;
    while (LP <= Length(AName)) and (AName[LP] <> '.') do
      Inc(LP);
    Result := Concat(Result, Hex8(LP - LStart));
    Result := Concat(Result, S2B(Copy(AName, LStart, LP - LStart)));
    Inc(LP);
  end;
  Result := Concat(Result, Hex8(0));
end;

{ 压缩指针(2 字节) }
function WirePtr(const AOffset: UInt16): TB;
begin
  SetLength(Result, 2);
  Result[0] := Byte($C0 or (AOffset shr 8));
  Result[1] := Byte(AOffset and $FF);
end;

{ 应答头部 }
function RespHeader(const AID, AFlags: UInt16; const AQD, AAN: UInt16): TB;
begin
  Result := B16(AID);
  Result := Concat(Result, B16(AFlags));
  Result := Concat(Result, B16(AQD));
  Result := Concat(Result, B16(AAN));
  Result := Concat(Result, B16(0));
  Result := Concat(Result, B16(0));
end;

function RRWire(const AName: TB; const AType: UInt16; const ATTL: UInt32;
  const ARData: TB): TB;
begin
  Result := AName;
  Result := Concat(Result, B16(AType));
  Result := Concat(Result, B16(1));       { CLASS=IN }
  Result := Concat(Result, B32(ATTL));
  Result := Concat(Result, B16(Length(ARData)));
  Result := Concat(Result, ARData);
end;

function ToTBytes(const A: TB): TBytes;
begin
  Result := A;
end;

{ ── 用例 ────────────────────────────────────────────────────────── }

procedure TestEncodeBasic;
var
  Q: TBytes;
begin
  Check(DnsEncodeQuery('example.com', dqTXT, $1234, Q), 'encode ok');
  Check(Length(Q) = 12 + (1 + 7 + 1 + 3 + 1) + 4, 'length 29');
  Check(Q[0] = $12, 'id hi');
  Check(Q[1] = $34, 'id lo');
  Check((Q[2] = $01) and (Q[3] = $00), 'flags RD');
  Check((Q[4] = $00) and (Q[5] = $01), 'qdcount=1');
  { 名称区偏移 12 }
  Check(Q[12] = 7, 'label len 7');
  Check((Q[13] = Byte('e')) and (Q[14] = Byte('x')) and (Q[15] = Byte('a')),
    'label e x a');
  Check((Q[20] = 3) and (Q[21] = Byte('c')), 'label com');
  Check(Q[24] = 0, 'root');
  Check((Q[25] = $00) and (Q[26] = $10), 'type TXT');
  Check((Q[27] = $00) and (Q[28] = $01), 'class IN');
end;

procedure TestEncodeLower;
var
  Q: TBytes;
begin
  Check(DnsEncodeQuery('Example.COM', dqTXT, 1, Q), 'encode ok');
  Check((Q[13] = Byte('e')) and (Q[21] = Byte('c')), 'lowercased');
end;

procedure TestEncodeReject;
var
  Q: TBytes;
  LLong: string;
  I: Integer;
begin
  LLong := '';
  for I := 1 to 64 do
    LLong := LLong + 'a';
  Check(not DnsEncodeQuery(LLong + '.com', dqTXT, 1, Q), 'label>63 reject');
  LLong := '';
  for I := 1 to 200 do
    LLong := LLong + 'b.';
  LLong := LLong + 'com';
  Check(not DnsEncodeQuery(LLong, dqTXT, 1, Q), 'name>255 reject');
end;

procedure TestDecodeTxtAndMx;
var
  A, Q: TB;
  R: TDnsResponse;
begin
  { question: www.example.com TXT; answer1: TXT "v=spf1 -all" (name=ptr 12);
    answer2: example.com MX 10 mx.example.com }
  Q := RespHeader(1, $8180, 1, 2);
  Q := Concat(Q, WireName('www.example.com'));
  Q := Concat(Q, B16(16));          { qtype TXT }
  Q := Concat(Q, B16(1));           { qclass IN }
  A := RRWire(WirePtr(12), 16, 300,
    Concat(Hex8(11), S2B('v=spf1 -all')));
  A := Concat(A, RRWire(WireName('example.com'), 15, 300,
    Concat(B16(10), WireName('mx.example.com'))));
  Q := Concat(Q, A);
  Check(DnsParseResponse(ToTBytes(Q), R), 'parse ok');
  Check(R.ID = 1, 'id');
  Check(R.RCODE = 0, 'rcode 0');
  Check(Length(R.Answers) = 2, 'two answers');
  Check(R.Answers[0].RType = drtTXT, 'first txt');
  Check(R.Answers[0].TXT = 'v=spf1 -all', 'txt payload');
  Check(R.Answers[0].TTL = 300, 'txt ttl');
  Check(R.Answers[1].RType = drtMX, 'second mx');
  Check(R.Answers[1].MXPreference = 10, 'mx pref');
  Check(R.Answers[1].MXExchange = 'mx.example.com', 'mx exchange');
end;

procedure TestDecodeTxtMulti;
var
  A, Q: TB;
  R: TDnsResponse;
begin
  { TXT rdata: 'foo' + 'bar' → 'foobar' }
  Q := RespHeader(2, $8180, 0, 1);
  A := RRWire(WireName('x.example.com'), 16, 60,
    Concat(Hex8(3), Concat(S2B('foo'), Concat(Hex8(3), S2B('bar')))));
  Q := Concat(Q, A);
  Check(DnsParseResponse(ToTBytes(Q), R), 'parse ok');
  Check(Length(R.Answers) = 1, 'one answer');
  Check(R.Answers[0].TXT = 'foobar', 'multi string concat');
end;

procedure TestDecodeTxtEmpty;
var
  A, Q: TB;
  R: TDnsResponse;
begin
  Q := RespHeader(3, $8180, 0, 1);
  A := RRWire(WireName('e.example.com'), 16, 60, Hex8(0));
  Q := Concat(Q, A);
  Check(DnsParseResponse(ToTBytes(Q), R), 'empty txt ok');
  Check((Length(R.Answers) = 1) and (R.Answers[0].TXT = ''), 'empty txt');
end;

procedure TestDecodeAaaa;
var
  A, Q: TB;
  R: TDnsResponse;
begin
  Q := RespHeader(4, $8180, 0, 1);
  A := RRWire(WireName('v6.example.com'), 28, 60,
    TB.Create($20, $01, $0D, $B8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $01));
  Q := Concat(Q, A);
  Check(DnsParseResponse(ToTBytes(Q), R), 'parse v6');
  Check(R.Answers[0].AAAA = '2001:db8::1', 'aaaa compressed');
end;

procedure TestDecodeAaaaLoopback;
var
  A, Q: TB;
  R: TDnsResponse;
begin
  Q := RespHeader(11, $8180, 0, 1);
  A := RRWire(WireName('v6b.example.com'), 28, 60,
    TB.Create(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1));
  Q := Concat(Q, A);
  Check(DnsParseResponse(ToTBytes(Q), R), 'parse v6 loopback');
  Check(R.Answers[0].AAAA = '::1', 'aaaa ::1');
end;

procedure TestDecodeSoa;
var
  A, Q: TB;
  R: TDnsResponse;
begin
  Q := RespHeader(5, $8180, 0, 1);
  A := RRWire(WireName('example.com'), 6, 3600,
    Concat(WireName('ns1.example.com'),
      Concat(WireName('hostmaster.example.com'),
        Concat(B32(2026081701), Concat(B32(7200), Concat(B32(3600),
          Concat(B32(1209600), B32(300))))))));
  Q := Concat(Q, A);
  Check(DnsParseResponse(ToTBytes(Q), R), 'parse soa');
  Check(R.Answers[0].RType = drtSOA, 'soa type');
  Check(R.Answers[0].SOAMName = 'ns1.example.com', 'soa mname');
  Check(R.Answers[0].SOARName = 'hostmaster.example.com', 'soa rname');
  Check(R.Answers[0].SOASerial = 2026081701, 'soa serial');
end;

procedure TestDecodeCnameSkipUnknown;
var
  A, Q: TB;
  R: TDnsResponse;
begin
  Q := RespHeader(6, $8180, 0, 3);
  A := RRWire(WireName('alias.example.com'), 5, 60,
    WireName('target.example.com'));
  A := Concat(A, RRWire(WireName('zz.example.com'), 99, 60, Hex8(1)));
  A := Concat(A, RRWire(WireName('a.example.com'), 1, 60,
    TB.Create(93, 184, 216, 34)));
  Q := Concat(Q, A);
  Check(DnsParseResponse(ToTBytes(Q), R), 'parse ok');
  Check(Length(R.CNAMEs) = 1, 'cname captured');
  Check(R.CNAMEs[0] = 'target.example.com', 'cname value');
  Check(Length(R.Answers) = 1, 'unknown skipped, only A');
  Check(R.Answers[0].RType = drtA, 'a type');
  Check(R.Answers[0].A = $5DB8D822, 'a value network order');
end;

procedure TestDecodeRcodeTc;
var
  Q: TB;
  R: TDnsResponse;
begin
  { flags: QR=1 + TC 位 + RCODE=3(NXDOMAIN) }
  Q := RespHeader(7, $8003 or $0200, 0, 0);
  Check(DnsParseResponse(ToTBytes(Q), R), 'parse rc');
  Check(R.RCODE = 3, 'rcode 3');
  Check(R.Truncated, 'tc flag');
end;

procedure TestDecodeRejectShort;
var
  R: TDnsResponse;
begin
  Check(not DnsParseResponse(nil, R), 'empty reject');
  Check(not DnsParseResponse(ToTBytes(TB.Create(0, 1)), R), 'short reject');
end;

procedure TestDecodeRejectBadPtr;
var
  Q: TB;
  R: TDnsResponse;
begin
  { answer name 处指针指向自身(环): 深度限制拒绝 }
  Q := RespHeader(8, $8180, 0, 1);
  Q := Concat(Q, RRWire(WirePtr(12), 1, 60, TB.Create(1, 2, 3, 4)));
  Check(not DnsParseResponse(ToTBytes(Q), R), 'pointer loop reject');
end;

procedure TestDecodeRejectOverrun;
var
  Q: TB;
  R: TDnsResponse;
begin
  { rdata 长度超报文: 拒绝 }
  Q := RespHeader(9, $8180, 0, 1);
  Q := Concat(Q, RRWire(WireName('a.example.com'), 1, 60,
    TB.Create(1, 2, 3, 4)));
  SetLength(Q, Length(Q) - 2);   { 截断 rdata 尾部 → rdlen 越界 }
  Check(not DnsParseResponse(ToTBytes(Q), R), 'rdlen overrun reject');
end;

procedure TestDecodeRejectBadLabel;
var
  Q: TB;
  R: TDnsResponse;
begin
  { name: label len=64(非法) → 拒绝 }
  Q := RespHeader(10, $8180, 0, 1);
  Q := Concat(Q, Hex8(64));
  Q := Concat(Q, TB.Create(1, 2, 3, 4));
  Q := Concat(Q, B16(1));          { type A }
  Q := Concat(Q, B16(1));          { class }
  Q := Concat(Q, B32(60));
  Q := Concat(Q, B16(4));
  Q := Concat(Q, TB.Create(1, 2, 3, 4));
  Check(not DnsParseResponse(ToTBytes(Q), R), 'bad label reject');
end;

procedure TestWireTypeMapping;
begin
  Check(DnsQueryKindToWire(dqTXT) = 16, 'txt wire 16');
  Check(DnsQueryKindToWire(dqMX) = 15, 'mx wire 15');
  Check(DnsQueryKindToWire(dqSOA) = 6, 'soa wire 6');
  Check(DnsRecordTypeToWire(drtAAAA) = 28, 'aaaa wire 28');
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.dns.wire');
  T.Test('EncodeBasic', @TestEncodeBasic);
  T.Test('EncodeLower', @TestEncodeLower);
  T.Test('EncodeReject', @TestEncodeReject);
  T.Test('DecodeTxtAndMx', @TestDecodeTxtAndMx);
  T.Test('DecodeTxtMulti', @TestDecodeTxtMulti);
  T.Test('DecodeTxtEmpty', @TestDecodeTxtEmpty);
  T.Test('DecodeAaaa', @TestDecodeAaaa);
  T.Test('DecodeAaaaLoopback', @TestDecodeAaaaLoopback);
  T.Test('DecodeSoa', @TestDecodeSoa);
  T.Test('DecodeCnameSkipUnknown', @TestDecodeCnameSkipUnknown);
  T.Test('DecodeRcodeTc', @TestDecodeRcodeTc);
  T.Test('DecodeRejectShort', @TestDecodeRejectShort);
  T.Test('DecodeRejectBadPtr', @TestDecodeRejectBadPtr);
  T.Test('DecodeRejectOverrun', @TestDecodeRejectOverrun);
  T.Test('DecodeRejectBadLabel', @TestDecodeRejectBadLabel);
  T.Test('WireTypeMapping', @TestWireTypeMapping);
  if not T.Run then
    Halt(1);
end.