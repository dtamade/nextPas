unit nextpas.core.mem.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.simd.bitops;

const
  MEM_CACHE_LINE_SIZE = 64;
  MEM_PAGE_SIZE = 4096;

  { Default alignment for pool/arena allocations.
    16 bytes matches SIMD-friendly alignment and covers both SSE (16-byte)
    and AVX (32-byte, when combined with AllocAligned) use cases. }
  DEFAULT_ALIGNMENT = 16;

  { Debug-mode poison pattern written to freed memory to detect use-after-free.
    0xDE is chosen because: (1) recognisable in hex dumps, (2) unlikely valid pointer,
    (3) non-zero so dereference traps. }
  MEM_POISON_FREED = $DE;

  { Debug-mode poison pattern written to newly allocated memory to detect
    uninitialized reads. 0xAB is chosen to be distinct from MEM_POISON_FREED
    and recognisable in hex dumps. }
  MEM_POISON_ALLOC = $AB;

type
  TAllocatorKind = (
    akDefault,
    akArena,
    akPool,
    akMimalloc
  );

{ Bit-manipulation utilities shared across mem subsystem. }

{** Return True if AValue is a positive power of two. }
function IsPowerOfTwo(const AValue: SizeUInt): Boolean; inline;

{** Return the smallest power of two >= AValue. Returns 1 for AValue <= 1. }
function NextPowerOfTwo(const AValue: SizeUInt): SizeUInt;

{** Round AValue up to the next multiple of AAlignment (must be power of two). }
function AlignUp(const AValue, AAlignment: SizeUInt): SizeUInt; inline;

{** Return AAlignment if it is a power of two and >= DEFAULT_ALIGNMENT,
    otherwise return DEFAULT_ALIGNMENT. }
function NormalizeAlignment(const AAlignment: SizeUInt): SizeUInt; inline;

{** Validate an alignment argument: must be non-zero, >= pointer size, and
    power of two. Returns True if valid. }
function ValidateAlignArg(const AAlignment: SizeUInt): Boolean; inline;

{** Fibonacci hash: multiply by 2^64/golden-ratio. Used for shard routing and
    open-addressing hash maps. }
function MulHash64(const AValue: QWord): QWord; inline;

{** Integer log2 (floor). Returns 0 for AValue = 0. }
function Log2UInt(const AValue: SizeUInt): SizeUInt;

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
    Exit(0); // 无法表示更大的 2 的幂，返回 0 表示溢出
  Result := 1;
  while Result < AValue do
    Result := Result shl 1;
end;

function AlignUp(const AValue, AAlignment: SizeUInt): SizeUInt;
var
  LPad: SizeUInt;
begin
  // AAlignment 必须是 2 的幂（调用方保证）
  // 用 (-AValue) and mask 计算补齐量
  LPad := (not AValue + 1) and (AAlignment - 1);
  // 溢出检查：AValue + LPad 不能回绕
  if AValue > High(SizeUInt) - LPad then
    Exit(0); // 溢出，返回 0 让调用方处理
  Result := AValue + LPad;
end;

function NormalizeAlignment(const AAlignment: SizeUInt): SizeUInt;
begin
  if (AAlignment >= DEFAULT_ALIGNMENT) and IsPowerOfTwo(AAlignment) then
    Result := AAlignment
  else
    Result := DEFAULT_ALIGNMENT;
end;

function ValidateAlignArg(const AAlignment: SizeUInt): Boolean;
begin
  Result := (AAlignment <> 0) and (AAlignment >= SizeOf(Pointer)) and IsPowerOfTwo(AAlignment);
end;

{$PUSH}{$Q-}
function MulHash64(const AValue: QWord): QWord;
begin
  Result := AValue * QWord(11400714819323198485);
end;
{$POP}

function Log2UInt(const AValue: SizeUInt): SizeUInt;
begin
  if AValue = 0 then
    Exit(0);
  { Delegate to bitops Bsr — native BSR/CLZ instruction, no loop. }
  if SizeOf(SizeUInt) = 8 then
    Result := SizeUInt(Bsr64(UInt64(AValue)))
  else
    Result := SizeUInt(Bsr32(UInt32(AValue)));
end;

end.
