unit nextpas.core.net.quic.header;

{**
 * nextpas.core.net.quic.header — QUIC 包头结构（RFC 9000 §17）
 *
 * 职责：受保护形态下即可完成的头部窥视（长头：版本/类型/CID/token/
 * Length；短头：按调用方提供的本地 DCID 长度定位 PN 起点），
 * 以及发送侧的长头前缀构建助手。
 *
 * 边界约定：
 * - Version Negotiation / Retry 无 PN 字段：PnOffset = -1；
 * - 长头 Length 字段语义 = PN + payload + tag 总长（§17.2）；
 * - 受保护包的首字节 Reserved/PN-Length 位在去掩码前不可校验，
 *   本层不检查（protect 层去掩码后校验）。
 *
 * @note Thread safety: 纯函数。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.net.quic.varint;

const
  cQuicVersionV1        = UInt32($00000001);
  cQuicVersionVersionNegotiation = UInt32($00000000);

type
  TQuicLongType = (
    qltInitial   = $00,
    qltZeroRtt   = $01,
    qltHandshake = $02,
    qltRetry     = $03
  );

  TQuicHeaderPeek = record
    IsLong: Boolean;
    FirstByte: Byte;              { 线上原值（受保护形态） }
    Version: UInt32;              { 长头；短头无此字段恒 0 }
    PacketType: TQuicLongType;    { 仅长头有效 }
    DstCid: TBytes;
    SrcCid: TBytes;
    Token: TBytes;                { Initial / 0-RTT }
    Length: UInt64;               { 长头非 Retry/VN：PN+payload+tag }
    PnOffset: Integer;            { PN 字段起始；无 PN 形态 = -1 }
  end;

{**
 * @desc 窥视包头（受保护形态安全）。短头必须由调用方提供本地已知的
 *       目的 CID 长度（线上不携带该长度字段）。
 *       成功时 AInfo.PnOffset 有效（VN/Retry 为 -1）；
 *       缓冲不足/固定位非法/CID 或 varint 越界返回 False。
 *}
function TryPeekQuicHeader(const ABuf: TBytes; AShortDstCidLen: Integer;
  out AInfo: TQuicHeaderPeek): Boolean;

{** @desc 长头发送侧首字节组装（form|fixed|type|reserved|pnlen） *}
function QuicLongFirstByte(APacketType: TQuicLongType;
  AReservedBits, APnLenBits: Byte): Byte;

{**
 * @desc 追加长头公共前缀（首字节占位 $FF 由调用方回填、版本、DCID、
 *       SCID 与 token）；随后调用方依次追加 Length varint、PN、payload。
 *}
procedure QuicBeginLongHeader(var ABuf: TBytes; APacketType: TQuicLongType;
  AVersion: UInt32; const ADstCid, ASrcCid, AToken: TBytes);

implementation

function TryPeekQuicHeader(const ABuf: TBytes; AShortDstCidLen: Integer;
  out AInfo: TQuicHeaderPeek): Boolean;
var
  LOff, LConsumed: Integer;
  LDcidLen, LScidLen: Integer;
  LTokenLen, LBodyLen: UInt64;
begin
  AInfo := Default(TQuicHeaderPeek);
  Result := False;
  if Length(ABuf) < 1 then
    Exit;
  AInfo.FirstByte := ABuf[0];
  AInfo.PnOffset := -1;

  if (AInfo.FirstByte and $80) <> 0 then
  begin
    { ---- 长头 ---- }
    AInfo.IsLong := True;
    if Length(ABuf) < 5 then
      Exit;
    AInfo.Version := (UInt32(ABuf[1]) shl 24) or (UInt32(ABuf[2]) shl 16) or
      (UInt32(ABuf[3]) shl 8) or UInt32(ABuf[4]);
    LOff := 5;
    if AInfo.Version = cQuicVersionVersionNegotiation then
    begin
      { VN：仅解析双 CID，其余字段不存在 }
      if Length(ABuf) < LOff + 1 then
        Exit;
      LDcidLen := ABuf[LOff]; Inc(LOff);
      if Length(ABuf) < LOff + LDcidLen then
        Exit;
      SetLength(AInfo.DstCid, LDcidLen);
      for LConsumed := 0 to LDcidLen - 1 do
        AInfo.DstCid[LConsumed] := ABuf[LOff + LConsumed];
      Inc(LOff, LDcidLen);
      if Length(ABuf) < LOff + 1 then
        Exit;
      LScidLen := ABuf[LOff]; Inc(LOff);
      if Length(ABuf) < LOff + LScidLen then
        Exit;
      SetLength(AInfo.SrcCid, LScidLen);
      for LConsumed := 0 to LScidLen - 1 do
        AInfo.SrcCid[LConsumed] := ABuf[LOff + LConsumed];
      Result := True;
      Exit;
    end;
    case (AInfo.FirstByte shr 4) and $03 of
      0: AInfo.PacketType := qltInitial;
      1: AInfo.PacketType := qltZeroRtt;
      2: AInfo.PacketType := qltHandshake;
    else
      AInfo.PacketType := qltRetry;
    end;
    if Length(ABuf) < LOff + 1 then
      Exit;
    LDcidLen := ABuf[LOff]; Inc(LOff);
    if (LDcidLen > 160) or (Length(ABuf) < LOff + LDcidLen) then
      Exit;
    SetLength(AInfo.DstCid, LDcidLen);
    for LConsumed := 0 to LDcidLen - 1 do
      AInfo.DstCid[LConsumed] := ABuf[LOff + LConsumed];
    Inc(LOff, LDcidLen);
    if Length(ABuf) < LOff + 1 then
      Exit;
    LScidLen := ABuf[LOff]; Inc(LOff);
    if (LScidLen > 160) or (Length(ABuf) < LOff + LScidLen) then
      Exit;
    SetLength(AInfo.SrcCid, LScidLen);
    for LConsumed := 0 to LScidLen - 1 do
      AInfo.SrcCid[LConsumed] := ABuf[LOff + LConsumed];
    Inc(LOff, LScidLen);
    if AInfo.PacketType = qltRetry then
    begin
      Result := True;   { Retry：余下为 token+16B tag，无 PN }
      Exit;
    end;
    if (AInfo.PacketType = qltInitial) or (AInfo.PacketType = qltZeroRtt) then
    begin
      if not QuicVarintDecode(ABuf, LOff, LTokenLen, LConsumed) then
        Exit;
      Inc(LOff, LConsumed);
      if LTokenLen > UInt64(Length(ABuf) - LOff) then
        Exit;
      SetLength(AInfo.Token, Integer(LTokenLen));
      for LConsumed := 0 to Integer(LTokenLen) - 1 do
        AInfo.Token[LConsumed] := ABuf[LOff + LConsumed];
      Inc(LOff, Integer(LTokenLen));
    end;
    if not QuicVarintDecode(ABuf, LOff, LBodyLen, LConsumed) then
      Exit;
    Inc(LOff, LConsumed);
    AInfo.Length := LBodyLen;
    if UInt64(Length(ABuf)) < UInt64(LOff) + LBodyLen then
      Exit;   { 缓冲不足以容纳本包声明体 }
    AInfo.PnOffset := LOff;
    Result := True;
    Exit;
  end;

  { ---- 短头（1-RTT）：固定位必须为 1，否则既非 QUIC 也非合法 VN 响应流 ---- }
  if (AInfo.FirstByte and $40) = 0 then
    Exit;
  AInfo.IsLong := False;
  if AShortDstCidLen < 0 then
    Exit;
  LOff := 1 + AShortDstCidLen;
  if Length(ABuf) <= LOff then
    Exit;   { 至少要容得下 1B PN }
  AInfo.PnOffset := LOff;
  Result := True;
end;

function QuicLongFirstByte(APacketType: TQuicLongType;
  AReservedBits, APnLenBits: Byte): Byte;
begin
  Result := Byte($C0 or (Byte(Ord(APacketType)) shl 4) or
    ((AReservedBits and $03) shl 2) or (APnLenBits and $03));
end;

procedure QuicBeginLongHeader(var ABuf: TBytes; APacketType: TQuicLongType;
  AVersion: UInt32; const ADstCid, ASrcCid, AToken: TBytes);
var
  LI: Integer;
begin
  ABuf := nil;
  QuicBufAppendByte(ABuf, $FF);   { 首字节占位：调用方 protect 时回填 }
  QuicBufAppendByte(ABuf, Byte(AVersion shr 24));
  QuicBufAppendByte(ABuf, Byte(AVersion shr 16));
  QuicBufAppendByte(ABuf, Byte(AVersion shr 8));
  QuicBufAppendByte(ABuf, Byte(AVersion));
  QuicBufAppendByte(ABuf, Byte(Length(ADstCid)));
  for LI := 0 to Length(ADstCid) - 1 do
    QuicBufAppendByte(ABuf, ADstCid[LI]);
  QuicBufAppendByte(ABuf, Byte(Length(ASrcCid)));
  for LI := 0 to Length(ASrcCid) - 1 do
    QuicBufAppendByte(ABuf, ASrcCid[LI]);
  if (APacketType = qltInitial) or (APacketType = qltZeroRtt) then
  begin
    QuicVarintAppend(ABuf, UInt64(Length(AToken)));
    for LI := 0 to Length(AToken) - 1 do
      QuicBufAppendByte(ABuf, AToken[LI]);
  end;
end;

end.
