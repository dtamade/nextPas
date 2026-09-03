unit nextpas.core.dns.base;
{**
 * @desc DNS 报文模型与编解码(wire 层)。
 *       只处理字节 ↔ 记录模型,不做网络 IO;查询/缓存见 nextpas.core.dns。
 *       契约 docs/dns/CONTRACT.md(INV-1/2/8/9)。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv;

type
  { 支持解析的记录类型(契约 §2) }
  TDnsRecordType = (drtA, drtAAAA, drtMX, drtTXT, drtNS, drtSOA);

  { 查询种类(与记录类型一一对应, 独立枚举以冻结查询面) }
  TDnsQueryKind = (dqA, dqAAAA, dqMX, dqTXT, dqNS, dqSOA);

  TDnsRecord = record
    Name: string;
    RType: TDnsRecordType;
    TTL: UInt32;
    A: UInt32;                          { drtA: 网络字节序 IPv4 }
    AAAA: string;                       { drtAAAA: RFC5952 文本 }
    MXPreference: UInt16;               { drtMX }
    MXExchange: string;                 { drtMX }
    TXT: string;                        { drtTXT: 多字符串按序拼接 }
    NSOwner: string;                    { drtNS }
    SOAMName: string;                   { drtSOA }
    SOARName: string;                   { drtSOA }
    SOASerial: UInt32;                  { drtSOA }
  end;

  TDnsResponse = record
    ID: UInt16;
    RCODE: Byte;
    Truncated: Boolean;
    Answers: array of TDnsRecord;
    CNAMEs: array of string;            { 应答中的 CNAME 别名链 }
  end;

const
  DNS_WIRE_T_A    = 1;
  DNS_WIRE_T_NS   = 2;
  DNS_WIRE_T_CNAME = 5;
  DNS_WIRE_T_SOA  = 6;
  DNS_WIRE_T_MX   = 15;
  DNS_WIRE_T_TXT  = 16;
  DNS_WIRE_T_AAAA = 28;
  DNS_WIRE_CLASS_IN = 1;
  DNS_MAX_NAME_BYTES = 255;
  DNS_MAX_LABEL_BYTES = 63;
  DNS_MAX_POINTER_DEPTH = 16;

{ 编码查询报文(header + 单 question); 失败返回 False(INV-1) }
function DnsEncodeQuery(const AName: string; const AKind: TDnsQueryKind;
  const AID: UInt16; out AQuery: TBytes): Boolean;

{ 解析应答报文; 畸形/截断/坏指针一律 False(INV-2/9) }
function DnsParseResponse(const AData: TBytes; out AResp: TDnsResponse): Boolean;

{ 类型 ↔ wire 映射(无效输入返回 0) }
function DnsRecordTypeToWire(const AType: TDnsRecordType): UInt16;
function DnsQueryKindToWire(const AKind: TDnsQueryKind): UInt16;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.bytes.builder,
  nextpas.core.mem.dynarray;

{ ── 字节序助手 ──────────────────────────────────────────────────── }

function ReadU16(const AData: TBytes; const APos: Integer): UInt16;
begin
  Result := (UInt16(AData[APos]) shl 8) or UInt16(AData[APos + 1]);
end;

function ReadU32(const AData: TBytes; const APos: Integer): UInt32;
begin
  Result := (UInt32(AData[APos]) shl 24) or (UInt32(AData[APos + 1]) shl 16)
    or (UInt32(AData[APos + 2]) shl 8) or UInt32(AData[APos + 3]);
end;

{ ── 名称编码/解码 ──────────────────────────────────────────────── }

{ 小写化(ASCII, 不依赖 SysUtils; core 源契约禁止 RTL 进 hot path) }
function LowerAscii(const AStr: string): string;
var
  I: Integer;
begin
  Result := AStr;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Inc(Result[I], 32);
end;

{ 编码: label ≤63, 全名 ≤255, 以 0 结尾; 返回总字节数或 False(INV-1) }
function EncodeNameInto(const AName: string; out ABytes: TBytes;
  out ATotal: Integer): Boolean;
var
  LP, LI, LStart, LLabelLen: Integer;
  LName: string;
begin
  Result := False;
  LName := LowerAscii(AName);
  SetLength(ABytes, DNS_MAX_NAME_BYTES + 1);
  ATotal := 0;
  LP := 1;
  while LP <= Length(LName) do
  begin
    LStart := LP;
    while (LP <= Length(LName)) and (LName[LP] <> '.') do
      Inc(LP);
    LLabelLen := LP - LStart;
    if (LLabelLen = 0) or (LLabelLen > DNS_MAX_LABEL_BYTES) then
      Exit;
    if ATotal + 1 + LLabelLen > DNS_MAX_NAME_BYTES then
      Exit;
    ABytes[ATotal] := Byte(LLabelLen);
    for LI := 0 to LLabelLen - 1 do
      ABytes[ATotal + 1 + LI] := Byte(LName[LStart + LI]);
    Inc(ATotal, 1 + LLabelLen);
    Inc(LP);   { 跳过 '.' }
  end;
  { 空名(''或 '.')= 根 }
  Inc(ATotal, 1);
  ABytes[ATotal - 1] := 0;
  SetLength(ABytes, ATotal);
  Result := True;
end;

{ 解码: 支持压缩指针; APos 前进到 name 区结束; 深度/越界防护见 INV-2 }
function DecodeNameAt(const AData: TBytes; const ALength: Integer;
  var APos: Integer; out AName: string): Boolean;
const
  MAX_LABEL = 63;
var
  LDepth, LPos, LJump, LLabelLen: Integer;
  LBuilder: IBytesBuilder;
begin
  Result := False;
  LDepth := 0;
  LPos := APos;
  LJump := -1;
  AName := '';
  // perf: IBytesBuilder geometric growth single source via bytes.ops.BytesGrowCapacity (BYTES_BUILDER_MIN_GROW 0→64→2×, amortized O(1)) replaces O(n²) AName+Chr reallocation; zero-copy single BytesCopy per label (inline single Move via bytes.ops), not inline per red-line 1/2 (Grow loop I-Cache); stability: interface refcount auto-free on early Exit/exception, no leak; single SpanToString ownership copy at success path
  LBuilder := nextpas.core.bytes.builder.CreateBytesBuilder(DNS_MAX_NAME_BYTES);
  while True do
  begin
    if (LPos < 0) or (LPos >= ALength) then
      Exit;
    LLabelLen := AData[LPos];
    if LLabelLen = 0 then
    begin
      Inc(LPos);
      if LJump < 0 then
        APos := LPos;
      AName := nextpas.core.bytes.ops.SpanToString(LBuilder.WrittenSpan);
      Result := True;
      Exit;
    end;
    if (LLabelLen and $C0) = $C0 then
    begin
      { 压缩指针: 目标偏移必须小于首指针位置(防环, INV-2) }
      if LPos + 1 >= ALength then
        Exit;
      Inc(LDepth);
      if LDepth > DNS_MAX_POINTER_DEPTH then
        Exit;
      if LJump < 0 then
      begin
        APos := LPos + 2;
        LJump := LPos + 2;
      end;
      LPos := (Integer(LLabelLen and $3F) shl 8) or AData[LPos + 1];
      if LPos >= LJump then
        Exit;
      Continue;
    end;
    if (LLabelLen > MAX_LABEL) or (LPos + 1 + LLabelLen > ALength) then
      Exit;
    if LBuilder.Length > 0 then
      LBuilder.AppendByte(Byte('.'));
    LBuilder.AppendBytes(@AData[LPos + 1], SizeUInt(LLabelLen));
    Inc(LPos, 1 + LLabelLen);
  end;
end;

{ ── 记录载荷解析 ────────────────────────────────────────────────── }

{ 16 字节 → RFC5952 文本(省略前导零, 压缩最长连续全零组 ≥2) }
function IPv6BytesToText(const AData: TBytes; const AStart: Integer): string;
var
  LGroups: array[0..7] of UInt16;
  LBestStart, LBestLen, LCurStart, LCurLen, LGI, LWI: Integer;
  LSeg: string;
begin
  for LGI := 0 to 7 do
    LGroups[LGI] := (UInt16(AData[AStart + LGI * 2]) shl 8)
      or UInt16(AData[AStart + LGI * 2 + 1]);
  LBestStart := -1;
  LBestLen := 0;
  LCurStart := -1;
  LCurLen := 0;
  for LGI := 0 to 7 do
  begin
    if LGroups[LGI] = 0 then
    begin
      if LCurStart < 0 then
        LCurStart := LGI;
      Inc(LCurLen);
    end
    else
    begin
      if (LCurLen >= 2) and (LCurLen > LBestLen) then
      begin
        LBestStart := LCurStart;
        LBestLen := LCurLen;
      end;
      LCurStart := -1;
      LCurLen := 0;
    end;
  end;
  if (LCurLen >= 2) and (LCurLen > LBestLen) then
  begin
    LBestStart := LCurStart;
    LBestLen := LCurLen;
  end;
  Result := '';
  LWI := 0;
  while LWI < 8 do
  begin
    if (LBestLen > 0) and (LWI = LBestStart) then
    begin
      if Length(Result) = 0 then
        Result := '::'
      else
        Result := Result + '::';
      Inc(LWI, LBestLen);
      Continue;
    end;
    LSeg := LowerAscii(IntToHex(LGroups[LWI], 1));
    while (Length(LSeg) > 1) and (LSeg[1] = '0') do
      Delete(LSeg, 1, 1);
    if Length(Result) = 0 then
      Result := LSeg
    else if Result[Length(Result)] = ':' then
      Result := Result + LSeg     { 压缩段刚结束, 已含 ':' }
    else
      Result := Result + ':' + LSeg;
    Inc(LWI);
  end;
end;

{ ── 公共编解码 ──────────────────────────────────────────────────── }

function DnsQueryKindToWire(const AKind: TDnsQueryKind): UInt16;
begin
  Result := 0;
  case AKind of
    dqA: Result := DNS_WIRE_T_A;
    dqAAAA: Result := DNS_WIRE_T_AAAA;
    dqMX: Result := DNS_WIRE_T_MX;
    dqTXT: Result := DNS_WIRE_T_TXT;
    dqNS: Result := DNS_WIRE_T_NS;
    dqSOA: Result := DNS_WIRE_T_SOA;
  end;
end;

function DnsRecordTypeToWire(const AType: TDnsRecordType): UInt16;
begin
  Result := 0;
  case AType of
    drtA: Result := DNS_WIRE_T_A;
    drtAAAA: Result := DNS_WIRE_T_AAAA;
    drtMX: Result := DNS_WIRE_T_MX;
    drtTXT: Result := DNS_WIRE_T_TXT;
    drtNS: Result := DNS_WIRE_T_NS;
    drtSOA: Result := DNS_WIRE_T_SOA;
  end;
end;

function DnsEncodeQuery(const AName: string; const AKind: TDnsQueryKind;
  const AID: UInt16; out AQuery: TBytes): Boolean;
var
  LNameBytes: TBytes;
  LNameLen: Integer;
  LWireType: UInt16;
begin
  Result := False;
  LWireType := DnsQueryKindToWire(AKind);
  if LWireType = 0 then
    Exit;
  if not EncodeNameInto(AName, LNameBytes, LNameLen) then
    Exit;
  SetLength(AQuery, 12 + LNameLen + 4);
  AQuery[0] := Byte(AID shr 8);
  AQuery[1] := Byte(AID and $FF);
  AQuery[2] := $01;      { RD=1 }
  AQuery[3] := $00;
  AQuery[4] := $00;      { QDCOUNT=1 }
  AQuery[5] := $01;
  AQuery[6] := $00;
  AQuery[7] := $00;
  AQuery[8] := $00;
  AQuery[9] := $00;
  AQuery[10] := $00;
  AQuery[11] := $00;
  Move(LNameBytes[0], AQuery[12], LNameLen);
  AQuery[12 + LNameLen] := Byte(LWireType shr 8);
  AQuery[13 + LNameLen] := Byte(LWireType and $FF);
  AQuery[14 + LNameLen] := $00;      { QCLASS=IN }
  AQuery[15 + LNameLen] := $01;
  Result := True;
end;

function DnsParseResponse(const AData: TBytes; out AResp: TDnsResponse): Boolean;
var
  LLength, LPos, LQDCount, LANCount, LI, LRRStart, LRDLength, LRType,
  LPtr: Integer;
  LName: string;
  LRec: TDnsRecord;
  LSkip: Boolean;
  LCNAMECount, LCNAMECap, LAnsCount, LAnsCap, LCap: Integer;
  LTxtBuilder: IBytesBuilder;
begin
  Result := False;
  LLength := Length(AData);
  if LLength < 12 then
    Exit;
  AResp.ID := ReadU16(AData, 0);
  AResp.RCODE := AData[3] and $0F;
  AResp.Truncated := (AData[2] and $02) <> 0;
  LQDCount := (Integer(AData[4]) shl 8) or AData[5];
  LANCount := (Integer(AData[6]) shl 8) or AData[7];
  AResp.Answers := nil;
  AResp.CNAMEs := nil;
  LCNAMECount := 0;
  LCNAMECap := 0;
  LAnsCount := 0;
  LAnsCap := 0;

  LPos := 12;
  { 跳过 question 区 }
  for LI := 1 to LQDCount do
  begin
    if not DecodeNameAt(AData, LLength, LPos, LName) then
      Exit;
    if LPos + 4 > LLength then
      Exit;
    Inc(LPos, 4);
  end;

  for LI := 1 to LANCount do
  begin
    if not DecodeNameAt(AData, LLength, LPos, LName) then
      Exit;
    if LPos + 10 > LLength then
      Exit;
    LRType := (Integer(AData[LPos]) shl 8) or AData[LPos + 1];
    LRDLength := (Integer(AData[LPos + 8]) shl 8) or AData[LPos + 9];
    LRRStart := LPos + 10;
    if LRRStart + LRDLength > LLength then
      Exit;
    LRec.Name := LName;
    LRec.TTL := ReadU32(AData, LPos + 4);
    LRec.A := 0;
    LRec.AAAA := '';
    LRec.MXPreference := 0;
    LRec.MXExchange := '';
    LRec.TXT := '';
    LRec.NSOwner := '';
    LRec.SOAMName := '';
    LRec.SOARName := '';
    LRec.SOASerial := 0;
    LSkip := False;
    case LRType of
      DNS_WIRE_T_A:
        begin
          if LRDLength <> 4 then
            Exit;
          LRec.RType := drtA;
          LRec.A := ReadU32(AData, LRRStart);
        end;
      DNS_WIRE_T_AAAA:
        begin
          if LRDLength <> 16 then
            Exit;
          LRec.RType := drtAAAA;
          LRec.AAAA := IPv6BytesToText(AData, LRRStart);
        end;
      DNS_WIRE_T_MX:
        begin
          if LRDLength < 3 then
            Exit;
          LRec.RType := drtMX;
          LRec.MXPreference := ReadU16(AData, LRRStart);
          LPtr := LRRStart + 2;
          if not DecodeNameAt(AData, LLength, LPtr, LRec.MXExchange) then
            Exit;
        end;
      DNS_WIRE_T_TXT:
        begin
          LRec.RType := drtTXT;
          LPtr := LRRStart;
          // perf: IBytesBuilder single source via bytes.ops.BytesGrowCapacity (BYTES_BUILDER_MIN_GROW 0→64→2×, amortized O(1)) replaces O(n²) LRec.TXT+Chr per char; zero-copy single BytesCopy per TXT chunk (inline Move via bytes.ops), not inline per red-line 1/2 (Grow loop I-Cache); single SpanToString ownership copy at end, interface refcount auto-free on Exit/no leak
          LTxtBuilder := nextpas.core.bytes.builder.CreateBytesBuilder(SizeUInt(LRDLength));
          while LPtr < LRRStart + LRDLength do
          begin
            if LPtr + 1 + AData[LPtr] > LRRStart + LRDLength then
              Exit;
            if AData[LPtr] > 0 then
              LTxtBuilder.AppendBytes(@AData[LPtr + 1], SizeUInt(AData[LPtr]));
            Inc(LPtr, 1 + AData[LPtr]);
          end;
          LRec.TXT := nextpas.core.bytes.ops.SpanToString(LTxtBuilder.WrittenSpan);
        end;
      DNS_WIRE_T_NS:
        begin
          LPtr := LRRStart;
          if not DecodeNameAt(AData, LLength, LPtr, LRec.NSOwner) then
            Exit;
          LRec.RType := drtNS;
        end;
      DNS_WIRE_T_SOA:
        begin
          LPtr := LRRStart;
          if not DecodeNameAt(AData, LLength, LPtr, LRec.SOAMName) then
            Exit;
          if not DecodeNameAt(AData, LLength, LPtr, LRec.SOARName) then
            Exit;
          if LPtr + 20 > LRRStart + LRDLength then
            Exit;
          LRec.SOASerial := ReadU32(AData, LPtr);
          LRec.RType := drtSOA;
        end;
      DNS_WIRE_T_CNAME:
        begin
          LPtr := LRRStart;
          if not DecodeNameAt(AData, LLength, LPtr, LName) then
            Exit;
          // perf: single source via bytes.ops.BytesGrowCapacityInt (BYTES_BUILDER_MIN_GROW 0→64→2×) geometric amortized O(1) — not inline per red-line 2 (loop I-Cache); zero-copy via DynArray poke (mem.dynarray) retains slab, single string assign
          LCap := nextpas.core.bytes.ops.BytesGrowCapacityInt(LCNAMECap, LCNAMECount + 1);
          if (nextpas.core.mem.dynarray.DynArrayCapacityStr(AResp.CNAMEs) < SizeUInt(LCap)) or (nextpas.core.mem.dynarray.DynArrayRefCountStr(AResp.CNAMEs) <> 1) then
          begin
            if LCap <> Length(AResp.CNAMEs) then
              SetLength(AResp.CNAMEs, LCap);
          end;
          if SizeUInt(Length(AResp.CNAMEs)) <> SizeUInt(LCNAMECount + 1) then
            nextpas.core.mem.dynarray.DynArraySetLengthStr(AResp.CNAMEs, SizeUInt(LCNAMECount + 1));
          LCNAMECap := LCap;
          AResp.CNAMEs[LCNAMECount] := LName;
          Inc(LCNAMECount);
          LSkip := True;
        end;
    else
      LSkip := True;   { 未知类型: 跳过 RDATA }
    end;
    if not LSkip then
    begin
      // perf: single source via bytes.ops.BytesGrowCapacityInt geometric amortized O(1) — not inline per red-line 2; zero-copy via single record assign (refcounted strings inside move once), capacity via LAnsCap single source
      if LAnsCount >= LAnsCap then
      begin
        LCap := nextpas.core.bytes.ops.BytesGrowCapacityInt(LAnsCap, LAnsCount + 1);
        SetLength(AResp.Answers, LCap);
        LAnsCap := LCap;
      end;
      AResp.Answers[LAnsCount] := LRec;
      Inc(LAnsCount);
    end;
    Inc(LPos, 10 + LRDLength);
  end;
  // stability: trim logical length; CNAMEs already poked to exact count with slab retained, Answers final shrink O(n) once retains amortized O(1) (no leak on early Exit — caller discards partial AResp)
  if Length(AResp.Answers) <> LAnsCount then
    SetLength(AResp.Answers, LAnsCount);
  Result := True;
end;

end.