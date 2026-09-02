unit nextpas.core.net.quic.pn;

{**
 * nextpas.core.net.quic.pn — QUIC 包号编解码（RFC 9000 §17.1 / 附录 A）
 *
 * 线上形态：包号取 1/2/3/4 字节大端截断（首字节低 2 位声明长度，
 * 由包头层编码）；编码长度按「未确认窗口 2 倍可表示」选择（附录 A.2
 * 伪代码直译）；解码按与 largest_pn 最近恢复（附录 A.3 伪代码直译）。
 *
 * @note Thread safety: 纯函数。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.binary;

{** @desc 无确认基线形态：num_unacked = pn + 1，返回字节数 1..4 *}
function QuicPnEncodedLen(APn: UInt64): Integer;

{** @desc 有确认形态：num_unacked = pn - largest_acked，返回字节数 1..4 *}
function QuicPnEncodedLenAfter(ALargestAcked, APn: UInt64): Integer;

{** @desc 低 ALen 字节（1..4）大端追加到 ABuf *}
procedure QuicPnAppend(var ABuf: TBytes; APn: UInt64; ALen: Integer);

{**
 * @desc 截断包号恢复全值（RFC 9000 附录 A.3 伪代码直译）
 *
 * @params
 *   ALargestPn    当前号空间已成功处理的最大包号
 *   ATruncatedPn  头内截断值
 *   APnBits       截断位数（8/16/24/32）
 *}
function QuicPnDecode(ALargestPn, ATruncatedPn: UInt64;
  APnBits: Integer): UInt64;

implementation

function BitLenOf(AValue: UInt64): Integer;
var
  LShift: Integer;
begin
  Result := 0;
  if AValue = 0 then
    Exit;
  { 二分定位最高位 }
  LShift := 32;
  while LShift > 0 do
  begin
    if (AValue shr LShift) <> 0 then
    begin
      Inc(Result, LShift);
      AValue := AValue shr LShift;
    end;
    LShift := LShift div 2;
  end;
  Inc(Result);   { 最高位序号 -> 位数 }
end;

function EncodedLenCore(ANumUnacked: UInt64): Integer;
var
  LMinBits: Integer;
begin
  if ANumUnacked < 1 then
    ANumUnacked := 1;
  LMinBits := BitLenOf(ANumUnacked) + 1;
  Result := (LMinBits + 7) div 8;
  if Result > 4 then
    Result := 4;
end;

function QuicPnEncodedLen(APn: UInt64): Integer;
begin
  if APn = High(UInt64) then
    Result := 4   { QUIC 值域内不会出现，防御钳制 }
  else
    Result := EncodedLenCore(APn + 1);
end;

function QuicPnEncodedLenAfter(ALargestAcked, APn: UInt64): Integer;
begin
  if APn <= ALargestAcked then
    Result := EncodedLenCore(1)
  else
    Result := EncodedLenCore(APn - ALargestAcked);
end;

procedure QuicPnAppend(var ABuf: TBytes; APn: UInt64; ALen: Integer);
var
  LN: Integer;
  LBytes: array[0..3] of Byte;
begin
  if (ALen < 1) or (ALen > 4) then
    Exit;
  LN := Length(ABuf);
  SetLength(ABuf, LN + ALen);
  case ALen of
    4:
      begin
        WriteUInt32BE(PByte(@ABuf[LN]), UInt32(APn));
      end;
    3:
      begin
        LBytes[0] := Byte(APn shr 16);
        LBytes[1] := Byte(APn shr 8);
        LBytes[2] := Byte(APn);
        Move(LBytes[0], ABuf[LN], 3);
      end;
    2:
      begin
        WriteUInt16BE(PByte(@ABuf[LN]), UInt16(APn));
      end;
    1:
      ABuf[LN] := Byte(APn);
  end;
end;

function QuicPnDecode(ALargestPn, ATruncatedPn: UInt64;
  APnBits: Integer): UInt64;
const
  cMaxPn = UInt64($3FFFFFFFFFFFFFFF);   { 2^62 - 1 }
var
  LExpected, LWin, LHwin, LMask, LCandidate: UInt64;
begin
  LWin := UInt64(1) shl APnBits;
  LHwin := LWin div 2;
  LMask := LWin - 1;
  LExpected := ALargestPn + 1;
  LCandidate := (LExpected and not LMask) or ATruncatedPn;
  { 伪代码的 underflow 保护：expected_pn - hwin 可能在无符号域回绕，
    以 Int64 中立比较（QUIC 包号 ≤ 2^62-1，Int64 足够） }
  if (Int64(LCandidate) <= Int64(LExpected) - Int64(LHwin)) and
     (LCandidate < cMaxPn - LWin) then
    Exit(LCandidate + LWin);
  if (Int64(LCandidate) > Int64(LExpected) + Int64(LHwin)) and
     (LCandidate >= LWin) then
    Exit(LCandidate - LWin);
  Result := LCandidate;
end;

end.
