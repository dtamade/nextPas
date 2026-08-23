unit nextpas.core.net.quic.params;

{**
 * nextpas.core.net.quic.params — QUIC transport parameters 编解码
 * （RFC 9000 §7.4 / §18）
 *
 * 线格式：序列表，每项 = varint(id) + varint(len) + value。
 * 解码校验：整缓冲必须恰好消费完（无尾垃圾）、同 id 重复即拒
 * （RFC：MUST NOT 发送重复项——收方视作连接错误，编解码层先行拦截）。
 *
 * 类型化便捷层覆盖常用数值型参数（varint 形态）；未知/未来扩展参数以
 * 原样 entry 保序透传（前向兼容）。
 *
 * @note Thread safety: 纯函数（记录值语义，无共享状态）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.net.quic.varint;

const
  { RFC 9000 §18.2 参数 id（HAPPY-EXTRA 扩展位后续追加） }
  cQuicParamOriginalDestinationConnectionId = $00;
  cQuicParamMaxIdleTimeout                  = $01;
  cQuicParamStatelessResetToken             = $02;
  cQuicParamMaxUdpPayloadSize               = $03;
  cQuicParamInitialMaxData                  = $04;
  cQuicParamInitialMaxStreamDataBidiLocal   = $05;
  cQuicParamInitialMaxStreamDataBidiRemote  = $06;
  cQuicParamInitialMaxStreamDataUni         = $07;
  cQuicParamInitialMaxStreamsBidi           = $08;
  cQuicParamInitialMaxStreamsUni            = $09;
  cQuicParamAckDelayExponent                = $0A;
  cQuicParamMaxAckDelay                     = $0B;
  cQuicParamDisableActiveMigration          = $0C;
  cQuicParamPreferredAddress                = $0D;
  cQuicParamActiveConnectionIdLimit         = $0E;
  cQuicParamInitialSourceConnectionId       = $0F;
  cQuicParamRetrySourceConnectionId         = $10;
  cQuicParamMaxDatagramFrameSize            = $20;  { RFC 9221 §3 }

type
  TQuicTransportParamEntry = record
    Id: UInt64;
    Value: TBytes;
  end;
  TQuicTransportParamArray = array of TQuicTransportParamEntry;

{** @desc 按 id 查找；未命中 -1 *}
function QuicParamFind(const AEntries: TQuicTransportParamArray;
  AId: UInt64): Integer;

{** @desc 追加字节值参数 *}
procedure QuicParamAddBytes(var AEntries: TQuicTransportParamArray;
  AId: UInt64; const AValue: TBytes);

{** @desc 追加空值参数（disable_active_migration 类） *}
procedure QuicParamAddEmpty(var AEntries: TQuicTransportParamArray;
  AId: UInt64);

{** @desc 追加 varint 数值参数；超 QUIC varint 值域返回 False 不写入 *}
function QuicParamAddVarint(var AEntries: TQuicTransportParamArray;
  AId: UInt64; AValue: UInt64): Boolean;

{** @desc 取 varint 数值参数；缺失或长度不符返回 False *}
function QuicParamGetVarint(const AEntries: TQuicTransportParamArray;
  AId: UInt64; out AValue: UInt64): Boolean;

{** @desc 序列表 -> 线格式（id/len/value 各为 varint） *}
function EncodeQuicTransportParams(
  const AEntries: TQuicTransportParamArray): TBytes;

{** @desc 线格式 -> 序列表；畸形/尾垃圾/重复 id 返回 False *}
function TryDecodeQuicTransportParams(const AData: TBytes;
  out AEntries: TQuicTransportParamArray): Boolean;

implementation

function QuicParamFind(const AEntries: TQuicTransportParamArray;
  AId: UInt64): Integer;
var
  LI: Integer;
begin
  for LI := 0 to Length(AEntries) - 1 do
    if AEntries[LI].Id = AId then
      Exit(LI);
  Result := -1;
end;

procedure QuicParamAddBytes(var AEntries: TQuicTransportParamArray;
  AId: UInt64; const AValue: TBytes);
var
  LN, LI: Integer;
begin
  LN := Length(AEntries);
  SetLength(AEntries, LN + 1);
  AEntries[LN].Id := AId;
  { 防御性拷贝：调用方后续改动原数组不得影响已登记 entry }
  SetLength(AEntries[LN].Value, Length(AValue));
  for LI := 0 to Length(AValue) - 1 do
    AEntries[LN].Value[LI] := AValue[LI];
end;

procedure QuicParamAddEmpty(var AEntries: TQuicTransportParamArray;
  AId: UInt64);
begin
  QuicParamAddBytes(AEntries, AId, nil);
end;

function QuicParamAddVarint(var AEntries: TQuicTransportParamArray;
  AId: UInt64; AValue: UInt64): Boolean;
begin
  Result := False;
  if QuicVarintEncodedLen(AValue) = 0 then
    Exit;   { 超 2^62-1 值域 }
  QuicParamAddBytes(AEntries, AId, QuicVarintEncode(AValue));
  Result := True;
end;

function QuicParamGetVarint(const AEntries: TQuicTransportParamArray;
  AId: UInt64; out AValue: UInt64): Boolean;
var
  LIdx, LConsumed: Integer;
begin
  Result := False;
  AValue := 0;
  LIdx := QuicParamFind(AEntries, AId);
  if LIdx < 0 then
    Exit;
  Result := QuicVarintDecode(AEntries[LIdx].Value, 0, AValue, LConsumed)
    and (LConsumed = Length(AEntries[LIdx].Value));
end;

function EncodeQuicTransportParams(
  const AEntries: TQuicTransportParamArray): TBytes;
var
  LI, LJ: Integer;
begin
  Result := nil;
  for LI := 0 to Length(AEntries) - 1 do
  begin
    QuicVarintAppend(Result, AEntries[LI].Id);
    QuicVarintAppend(Result, UInt64(Length(AEntries[LI].Value)));
    for LJ := 0 to Length(AEntries[LI].Value) - 1 do
      QuicBufAppendByte(Result, AEntries[LI].Value[LJ]);
  end;
end;

function TryDecodeQuicTransportParams(const AData: TBytes;
  out AEntries: TQuicTransportParamArray): Boolean;
var
  LOff, LConsumed, LLi: Integer;
  LId, LLen: UInt64;
  LEntry: TQuicTransportParamEntry;
begin
  Result := False;
  AEntries := nil;
  LOff := 0;
  while LOff < Length(AData) do
  begin
    if (not QuicVarintDecode(AData, LOff, LId, LConsumed)) then
      Exit;
    Inc(LOff, LConsumed);
    if not QuicVarintDecode(AData, LOff, LLen, LConsumed) then
      Exit;
    Inc(LOff, LConsumed);
    if LLen > UInt64(Length(AData) - LOff) then
      Exit;   { 值域越界 }
    LEntry.Id := LId;
    SetLength(LEntry.Value, Integer(LLen));
    for LLi := 0 to Integer(LLen) - 1 do
      LEntry.Value[LLi] := AData[LOff + LLi];
    Inc(LOff, Integer(LLen));
    if QuicParamFind(AEntries, LId) >= 0 then
      Exit;   { 同 id 重复：RFC 视作协议错误，解码层拦截 }
    SetLength(AEntries, Length(AEntries) + 1);
    AEntries[Length(AEntries) - 1] := LEntry;
  end;
  Result := True;
end;

end.
