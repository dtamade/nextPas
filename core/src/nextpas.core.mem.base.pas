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

  TArenaMarker = SizeUInt deprecated 'use TArenaMark from arena.base';

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
  Result := 1;
  while Result < AValue do
    Result := Result shl 1;
end;

function AlignUp(const AValue, AAlignment: SizeUInt): SizeUInt;
begin
  Result := (AValue + AAlignment - 1) and not (AAlignment - 1);
end;

function NormalizeAlignment(const AAlignment: SizeUInt): SizeUInt;
begin
  if (AAlignment = 0) or (not IsPowerOfTwo(AAlignment)) then
    Result := DEFAULT_ALIGNMENT
  else
    Result := AAlignment;
end;

end.
