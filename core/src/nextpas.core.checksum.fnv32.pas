{**
 * nextpas.core.checksum.fnv32 - FNV-1a 32 位（IETF / Go hash/fnv）
 *
 * 偏移 0x811C9DC5、素数 0x01000193。无 init/xorout 翻转：空输入即偏移值。
 * 标准向量："hello" → $4F9F2CAB；空 → $811C9DC5。
 * 与 base.HashBytes 同算法；本单元是校验和形态（增量 + TBytes），
 * HashBytes 仍是散列表哈希入口。
 *}

unit nextpas.core.checksum.fnv32;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  FNV1A32_OFFSET = LongWord($811C9DC5);
  FNV1A32_PRIME  = LongWord($01000193);

{** @desc 增量更新 FNV-1a 32（首次调用传 FNV1A32_OFFSET）
    @param AHash 当前累计值
    @param AData 数据指针（可空，ALen=0 时原样返回 AHash）
    @param ALen 数据长度
    @return 更新后的累计值（继续传给下一次调用；终值即校验值） *}
function Fnv1a32Update(AHash: LongWord; const AData: Pointer;
  ALen: SizeUInt): LongWord; inline;

{** @desc 一次性计算（无类型参数风格，同 Crc32Of）
    @param ABuf 任意数据起始（ALen=0 时返回 FNV1A32_OFFSET，不读 ABuf） *}
function Fnv1a32Of(const ABuf; ALen: SizeUInt): LongWord; inline;

{** @desc 一次性计算字节数组（nil/空 → FNV1A32_OFFSET） *}
function Fnv1a32OfBytes(const AData: TBytes): LongWord; inline;

implementation

function Fnv1a32Update(AHash: LongWord; const AData: Pointer;
  ALen: SizeUInt): LongWord; inline;
var
  P: PByte;
begin
  P := PByte(AData);
  { zero-copy + batch 8: 显式 while 避免 for 下溢，8 字节批量展开降分支 }
  {$PUSH}
  {$R-}
  {$Q-}
  while ALen >= 8 do
  begin
    AHash := (AHash xor LongWord(P^)) * FNV1A32_PRIME; Inc(P);
    AHash := (AHash xor LongWord(P^)) * FNV1A32_PRIME; Inc(P);
    AHash := (AHash xor LongWord(P^)) * FNV1A32_PRIME; Inc(P);
    AHash := (AHash xor LongWord(P^)) * FNV1A32_PRIME; Inc(P);
    AHash := (AHash xor LongWord(P^)) * FNV1A32_PRIME; Inc(P);
    AHash := (AHash xor LongWord(P^)) * FNV1A32_PRIME; Inc(P);
    AHash := (AHash xor LongWord(P^)) * FNV1A32_PRIME; Inc(P);
    AHash := (AHash xor LongWord(P^)) * FNV1A32_PRIME; Inc(P);
    Dec(ALen, 8);
  end;
  while ALen > 0 do
  begin
    AHash := (AHash xor LongWord(P^)) * FNV1A32_PRIME;
    Inc(P);
    Dec(ALen);
  end;
  {$POP}
  Result := AHash;
end;

function Fnv1a32Of(const ABuf; ALen: SizeUInt): LongWord; inline;
begin
  Result := Fnv1a32Update(FNV1A32_OFFSET, @ABuf, ALen);
end;

function Fnv1a32OfBytes(const AData: TBytes): LongWord; inline;
begin
  Result := Fnv1a32Update(FNV1A32_OFFSET, PByte(AData),
    PtrUInt(Length(AData)));
end;

end.
