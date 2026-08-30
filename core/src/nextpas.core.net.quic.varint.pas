unit nextpas.core.net.quic.varint;

{**
 * nextpas.core.net.quic.varint — QUIC 变长整数（RFC 9000 §16）
 *
 * 编码：首字节高 2 位为长度前缀（00/01/10/11 -> 1/2/4/8 字节），
 * 值域 0..2^62-1。与 protobuf LEB128（continuation-bit，见
 * nextpas.core.encoding.varint）不同构，勿混用。
 *
 * @note Thread safety: 纯函数。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops;

const
  { 值域上界：2^62 - 1（首两位前缀占用） }
  cQuicVarintMaxValue = UInt64($3FFFFFFFFFFFFFFF);

{** @desc 按值量级返回编码字节数（1/2/4/8）；超值域返回 0 *}
function QuicVarintEncodedLen(AValue: UInt64): Integer;

{** @desc 编码并追加到 ABuf 尾部；超值域返回 False 不写任何字节 *}
function QuicVarintAppend(var ABuf: TBytes; AValue: UInt64): Boolean;

{** @desc 编码为独立缓冲 *}
function QuicVarintEncode(AValue: UInt64): TBytes;

{** @desc 追加单字节到 ABuf 尾部（包/参数序列化共用） *}
procedure QuicBufAppendByte(var ABuf: TBytes; AValue: Byte); inline;

{**
 * @desc 从 ABuf[AOffset] 解码
 *
 * @params
 *   ABuf       输入缓冲
 *   AOffset    起始偏移（0-based）
 *   AValue     输出值
 *   AConsumed  输出消耗字节数（1/2/4/8）
 *
 * @return 缓冲不足返回 False（AConsumed=0）；前缀声明长度越界同理
 *}
function QuicVarintDecode(const ABuf: TBytes; AOffset: Integer;
  out AValue: UInt64; out AConsumed: Integer): Boolean;

implementation

function QuicVarintEncodedLen(AValue: UInt64): Integer;
begin
  if AValue <= $3F then
    Result := 1
  else if AValue <= $3FFF then
    Result := 2
  else if AValue <= $3FFFFFFF then
    Result := 4
  else if AValue <= cQuicVarintMaxValue then
    Result := 8
  else
    Result := 0;
end;

function QuicVarintAppend(var ABuf: TBytes; AValue: UInt64): Boolean;
var
  LLen, LBase, LI: Integer;
begin
  LLen := QuicVarintEncodedLen(AValue);
  if LLen = 0 then
    Exit(False);
  LBase := Length(ABuf);
  SetLength(ABuf, LBase + LLen);
  { 大端写入；首字节高 2 位 = 长度前缀 }
  case LLen of
    1: ABuf[LBase] := Byte(AValue);
    2: ABuf[LBase] := Byte($40 or ((AValue shr 8) and $3F));
    4: ABuf[LBase] := Byte($80 or ((AValue shr 24) and $3F));
    8: ABuf[LBase] := Byte($C0 or ((AValue shr 56) and $3F));
  end;
  for LI := 1 to LLen - 1 do
    ABuf[LBase + LI] := Byte(AValue shr (8 * (LLen - 1 - LI)));
  Result := True;
end;

function QuicVarintEncode(AValue: UInt64): TBytes;
var
  LDummy: Boolean;
begin
  Result := nil;
  LDummy := QuicVarintAppend(Result, AValue);
  Assert(LDummy);
end;

procedure QuicBufAppendByte(var ABuf: TBytes; AValue: Byte); inline;
begin
  BytesAppendByte(ABuf, AValue);
end;

function QuicVarintDecode(const ABuf: TBytes; AOffset: Integer;
  out AValue: UInt64; out AConsumed: Integer): Boolean;
var
  LAvail, LI, LLen: Integer;
  LPrefix: Byte;
begin
  Result := False;
  AValue := 0;
  AConsumed := 0;
  if AOffset < 0 then
    Exit;
  LAvail := Length(ABuf) - AOffset;
  if LAvail < 1 then
    Exit;
  LPrefix := ABuf[AOffset] and $C0;
  case LPrefix of
    $00: LLen := 1;
    $40: LLen := 2;
    $80: LLen := 4;
  else
    LLen := 8;
  end;
  if LAvail < LLen then
    Exit;   { 缓冲不足：调用方续读后重试 }
  AValue := ABuf[AOffset] and ($FF shr 2);
  for LI := 1 to LLen - 1 do
    AValue := (AValue shl 8) or ABuf[AOffset + LI];
  AConsumed := LLen;
  Result := True;
end;

end.
