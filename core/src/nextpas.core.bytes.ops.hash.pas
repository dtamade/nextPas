unit nextpas.core.bytes.ops.hash;

{$I nextpas.core.settings.inc}
{ R9-02 hermetic：settings.inc 已保障 inline 语义（-O2→INLINE ON），FPC 3.3.1 下无 BEGIN 误报 }

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops.capacity;

{ Hash 阈值/幂二单源 — 0.5 负载与幂二校验 bytes.ops 单源，window.hash/cow 复用 inline 零拷贝 }
const
  BYTES_HASH_LOAD_DENOM = 2;

function BytesHashNeedsGrow(ACount, ACap: Integer): Boolean; inline;
function BytesIsPowerOfTwo(ACap: Integer): Boolean; inline;
function BytesCeilPow2(ACap: Integer): Integer; inline;
function BytesAlignCapacity(ACap: Integer): Integer; inline;

implementation

function BytesIsPowerOfTwo(ACap: Integer): Boolean; inline;
begin
  Result := (ACap > 0) and ((ACap and (ACap - 1)) = 0);
end;

function BytesCeilPow2(ACap: Integer): Integer; inline;
var
  L: Integer;
begin
  if ACap <= 1 then Exit(1);
  if BytesIsPowerOfTwo(ACap) then Exit(ACap);
  L := ACap - 1;
  L := L or (L shr 1);
  L := L or (L shr 2);
  L := L or (L shr 4);
  L := L or (L shr 8);
  L := L or (L shr 16);
  Result := L + 1;
  if Result <= 0 then Result := ACap;
end;

function BytesHashNeedsGrow(ACount, ACap: Integer): Boolean; inline;
begin
  if ACap <= 0 then Exit(True);
  if not BytesIsPowerOfTwo(ACap) then Exit(True);
  Result := (ACount + 1) * BYTES_HASH_LOAD_DENOM > ACap;
end;

function BytesAlignCapacity(ACap: Integer): Integer; inline;
var
  LCeil: Integer;
begin
  // 单源幂二对齐：BytesCeilPow2 位运算单步 + BytesGrowCapacity(0)=32 兜底 + 1M 上限，inline 零拷贝 O(1)，window.hash 单源复用零重复
  // 性能：inline O(1) 零拷贝，单源 via capacity.BytesGrowCapacity(0) inline 零额外调用
  if BytesIsPowerOfTwo(ACap) then Exit(ACap);
  LCeil := BytesCeilPow2(ACap);
  if LCeil < BytesGrowCapacity(0) then
    LCeil := BytesGrowCapacity(0);
  if (LCeil <= 0) or (LCeil > 1 shl 20) then
    LCeil := ACap;
  if LCeil < ACap then LCeil := ACap;
  Result := LCeil;
end;

end.
