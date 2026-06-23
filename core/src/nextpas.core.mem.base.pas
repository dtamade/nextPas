unit nextpas.core.mem.base;

{$I nextpas.core.settings.inc}

interface

const
  MEM_DEFAULT_ALIGN = SizeOf(Pointer);
  MEM_CACHE_LINE_SIZE = 64;
  MEM_PAGE_SIZE = 4096;

  { Default alignment for pool/arena allocations.
    16 bytes matches SIMD-friendly alignment and covers both SSE (16-byte)
    and AVX (32-byte, when combined with AllocAligned) use cases. }
  DEFAULT_ALIGNMENT = 16;

type
  TAllocatorKind = (
    akDefault,
    akArena,
    akPool,
    akMimalloc
  );

  TArenaMarker = SizeUInt;

{ Bit-manipulation utilities shared across mem subsystem. }

{** Return True if AValue is a positive power of two. }
function IsPowerOfTwo(const AValue: SizeUInt): Boolean; inline;

{** Return the smallest power of two >= AValue. Returns 1 for AValue <= 1. }
function NextPowerOfTwo(const AValue: SizeUInt): SizeUInt; inline;

{** Round AValue up to the next multiple of AAlignment (must be power of two). }
function AlignUp(const AValue, AAlignment: SizeUInt): SizeUInt; inline;

{** Return AAlignment if it is a power of two and >= DEFAULT_ALIGNMENT,
    otherwise return DEFAULT_ALIGNMENT. }
function NormalizeAlignment(const AAlignment: SizeUInt): SizeUInt; inline;

implementation

function IsPowerOfTwo(const AValue: SizeUInt): Boolean;
begin
  Result := (AValue <> 0) and ((AValue and (AValue - 1)) = 0);
end;

function NextPowerOfTwo(const AValue: SizeUInt): SizeUInt;
begin
  if AValue <= 1 then
    Exit(1);
  if AValue > (SizeUInt(1) shl (SizeUInt(SizeOf(SizeUInt) * 8 - 1))) then
    Exit(AValue); // 无法表示更大的 2 的幂，返回原值 (CS-002)
  Result := 1;
  while Result < AValue do
    Result := Result shl 1;
end;

function AlignUp(const AValue, AAlignment: SizeUInt): SizeUInt;
var
  LPad: SizeUInt;
begin
  // AAlignment 必须是 2 的幂（调用方保证）
  // 用 (-AValue) and mask 计算补齐量，全程无溢出 (CS-003)
  LPad := (not AValue + 1) and (AAlignment - 1);
  Result := AValue + LPad;
end;

function NormalizeAlignment(const AAlignment: SizeUInt): SizeUInt;
begin
  if (AAlignment = 0) or (not IsPowerOfTwo(AAlignment)) then
    Result := DEFAULT_ALIGNMENT
  else
    Result := AAlignment;
end;

end.
