{**
 * nextpas.core.checksum.crc32 - CRC-32（IEEE 802.3，PNG 兼容）
 *
 * 反射算法，多项式 0xEDB88320。对外语义为标准 CRC 值：
 * 初始 0、可按任意分段增量更新、结果即标准校验值（已做 init/xorout 位翻转）。
 * 标准向量："123456789" → $CBF43926。
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
  CRC_TABLE: array[0..255] of LongWord;

function Crc32Update(ACrc: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
var
  P: PByte;
begin
  { 标准值语义 ↔ 内部状态: 内部以 0xFFFFFFFF 为初值, 终值取反 }
  ACrc := ACrc xor $FFFFFFFF;
  P := PByte(AData);
  { 显式 while 而非 for 0..ALen-1: ALen=0 时无符号下溢会退化为巨大循环 }
  while ALen > 0 do
  begin
    ACrc := CRC_TABLE[(ACrc xor P^) and $FF] xor (ACrc shr 8);
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
  I, B: Integer;
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
    CRC_TABLE[I] := C;
  end;
end;

initialization
  BuildCrcTable;

end.