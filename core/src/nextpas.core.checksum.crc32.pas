{**
 * nextpas.core.checksum.crc32 - CRC-32（IEEE 802.3，PNG 兼容）
 *
 * 反射算法，多项式 0xEDB88320。对外语义为标准 CRC 值：
 * 初始 0、可按任意分段增量更新、结果即标准校验值（已做 init/xorout 位翻转）。
 * 标准向量："123456789" → $CBF43926。
 *
 * 实现：slice-by-8（8 表 × 8 字节/轮），纯 Pascal 无硬件依赖；
 * 短尾部与 ALen<8 回落逐字节查表。分段更新语义与逐字节实现完全一致。
 *}

unit nextpas.core.checksum.crc32;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  CRC32_POLY = $EDB88320;    { 反射多项式 }

{** @desc 增量更新 CRC（标准值语义）
    @param ACrc 当前累计值（首次调用传 0）
    @param AData 数据指针（可空，ALen=0 时原样返回 ACrc）
    @param ALen 数据长度
    @return 更新后的累计值（继续传给下一次调用），终值直接是标准 CRC-32 *}
function Crc32Update(ACrc: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;

{** @desc 一次性计算（无类型参数风格，同 hash 域 API）
    @param ABuf 任意数据起始（可空，ALen=0 时返回 0）*}
function Crc32Of(const ABuf; ALen: SizeUInt): LongWord;

{** @desc 一次性计算字节数组 *}
function Crc32OfBytes(const AData: TBytes): LongWord;

implementation

var
  { TAB[0] 为经典反射表；TAB[k] 由 TAB[k-1] 推导，见 BuildCrcTable }
  TAB: array[0..7, 0..255] of LongWord;

function Crc32Update(ACrc: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
var
  P: PByte;
  LX, LY: LongWord;
begin
  { 标准值语义 ↔ 内部状态: 内部以 0xFFFFFFFF 为初值, 终值取反 }
  ACrc := ACrc xor $FFFFFFFF;
  P := PByte(AData);
  { 显式 while 而非 for 0..ALen-1: ALen=0 时无符号下溢会退化为巨大循环 }
  while ALen >= 8 do
  begin
    { LE 四字节组装在 LE 目标上由编译器折叠为单次载入；保持可移植写法 }
    LX := (LongWord(P[0]) or (LongWord(P[1]) shl 8) or
           (LongWord(P[2]) shl 16) or (LongWord(P[3]) shl 24)) xor ACrc;
    LY := LongWord(P[4]) or (LongWord(P[5]) shl 8) or
          (LongWord(P[6]) shl 16) or (LongWord(P[7]) shl 24);
    ACrc := TAB[7][LX and $FF] xor TAB[6][(LX shr 8) and $FF] xor
            TAB[5][(LX shr 16) and $FF] xor TAB[4][LX shr 24] xor
            TAB[3][LY and $FF] xor TAB[2][(LY shr 8) and $FF] xor
            TAB[1][(LY shr 16) and $FF] xor TAB[0][LY shr 24];
    Inc(P, 8);
    Dec(ALen, 8);
  end;
  while ALen > 0 do
  begin
    ACrc := TAB[0][(ACrc xor P^) and $FF] xor (ACrc shr 8);
    Inc(P);
    Dec(ALen);
  end;
  Result := ACrc xor $FFFFFFFF;
end;

function Crc32Of(const ABuf; ALen: SizeUInt): LongWord;
begin
  Result := Crc32Update(0, @ABuf, ALen);
end;

function Crc32OfBytes(const AData: TBytes): LongWord;
begin
  Result := Crc32Update(0, PByte(AData), PtrUInt(Length(AData)));
end;

procedure BuildCrcTable;
var
  I, B, K: Integer;
  C: LongWord;
begin
  for I := 0 to 255 do
  begin
    C := LongWord(I);
    for B := 0 to 7 do
      if (C and 1) <> 0 then
        C := (C shr 1) xor CRC32_POLY
      else
        C := C shr 1;
    TAB[0][I] := C;
  end;
  for K := 1 to 7 do
    for I := 0 to 255 do
      TAB[K][I] := (TAB[K - 1][I] shr 8) xor TAB[0][TAB[K - 1][I] and $FF];
end;

initialization
  BuildCrcTable;

end.
