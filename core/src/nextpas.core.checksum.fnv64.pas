{**
 * nextpas.core.checksum.fnv64 - FNV-1a 64 位（IETF / Go hash/fnv）
 *
 * 偏移 $CBF29CE484222325、素数 $100000001B3。无 init/xorout 翻转：
 * 空输入即偏移值。
 * 标准向量："hello" → $A430D84680AABD0B；"a" → $AF63DC4C8601EC8C；
 * "foobar" → $85944171F73967E8；空 → $CBF29CE484222325。
 * 与 fnv32 同族的校验和形态（增量 + TBytes + 小写 hex 便捷封装）。
 * 反哺来源：c2pas888 项目指纹（project fingerprint）需 64 位 FNV hex，
 * core 侧仅有 32 位版本（c2pas888 架构重整反哺）。
 *}

unit nextpas.core.checksum.fnv64;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  FNV1A64_OFFSET = QWord($CBF29CE484222325);
  FNV1A64_PRIME  = QWord($100000001B3);

{** @desc 增量更新 FNV-1a 64（首次调用传 FNV1A64_OFFSET）
    @param AHash 当前累计值
    @param AData 数据指针（可空，ALen=0 时原样返回 AHash）
    @param ALen 数据长度（字节）
    @return 更新后的累计值（继续传给下一次调用；终值即校验值） *}
function Fnv1a64Update(AHash: QWord; const AData: Pointer;
  ALen: SizeUInt): QWord; inline;

{** @desc 一次性计算（无类型参数风格，同 Fnv1a32Of）
    @param ABuf 任意数据起始（ALen=0 时返回 FNV1A64_OFFSET，不读 ABuf） *}
function Fnv1a64Of(const ABuf; ALen: SizeUInt): QWord; inline;

{** @desc 一次性计算字节数组（nil/空 → FNV1A64_OFFSET） *}
function Fnv1a64OfBytes(const AData: TBytes): QWord; inline;

{** @desc 一次性计算并返回小写 16 位 hex（空输入 → 偏移值 hex）
    @param ABuf 任意数据起始
    @param ALen 数据长度（字节） *}
function Fnv1a64HexOf(const ABuf; ALen: SizeUInt): string;

{** @desc 字符串便捷封装：UTF-8 字节序列的 FNV-1a 64 小写 hex *}
function Fnv1a64HexStr(const S: string): string;

implementation

uses
  nextpas.core.text.conv;

function Fnv1a64Update(AHash: QWord; const AData: Pointer;
  ALen: SizeUInt): QWord; inline;
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
    AHash := (AHash xor QWord(P^)) * FNV1A64_PRIME; Inc(P);
    AHash := (AHash xor QWord(P^)) * FNV1A64_PRIME; Inc(P);
    AHash := (AHash xor QWord(P^)) * FNV1A64_PRIME; Inc(P);
    AHash := (AHash xor QWord(P^)) * FNV1A64_PRIME; Inc(P);
    AHash := (AHash xor QWord(P^)) * FNV1A64_PRIME; Inc(P);
    AHash := (AHash xor QWord(P^)) * FNV1A64_PRIME; Inc(P);
    AHash := (AHash xor QWord(P^)) * FNV1A64_PRIME; Inc(P);
    AHash := (AHash xor QWord(P^)) * FNV1A64_PRIME; Inc(P);
    Dec(ALen, 8);
  end;
  while ALen > 0 do
  begin
    AHash := (AHash xor QWord(P^)) * FNV1A64_PRIME;
    Inc(P);
    Dec(ALen);
  end;
  {$POP}
  Result := AHash;
end;

function Fnv1a64Of(const ABuf; ALen: SizeUInt): QWord; inline;
begin
  Result := Fnv1a64Update(FNV1A64_OFFSET, @ABuf, ALen);
end;

function Fnv1a64OfBytes(const AData: TBytes): QWord; inline;
begin
  Result := Fnv1a64Update(FNV1A64_OFFSET, PByte(AData),
    PtrUInt(Length(AData)));
end;

function Fnv1a64HexOf(const ABuf; ALen: SizeUInt): string;
begin
  Result := LowerCase(IntToHex(Fnv1a64Of(ABuf, ALen), 16));
end;

function Fnv1a64HexStr(const S: string): string;
begin
  if Length(S) = 0 then
    Result := LowerCase(IntToHex(FNV1A64_OFFSET, 16))
  else
    Result := LowerCase(IntToHex(Fnv1a64Of(S[1], Length(S)), 16));
end;

end.
