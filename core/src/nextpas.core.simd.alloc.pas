unit nextpas.core.simd.alloc;


{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

type
  TSimdAlignment = (saAuto = 0, sa16 = 16, sa32 = 32, sa64 = 64);

function SimdAlloc(aSize: SizeUInt; aAlignment: TSimdAlignment = saAuto): Pointer;
procedure SimdFree(aPtr: Pointer);
function SimdRealloc(aPtr: Pointer; aNewSize: SizeUInt; aAlignment: TSimdAlignment = saAuto): Pointer;
function SimdAllocAlignment: NativeUInt;

implementation

uses
  nextpas.core.platform.memory,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

{
  SimdAlloc runtime truth:
  - Delegates storage ownership to nextpas.core.platform.memory.
  - SIMD does not declare raw Windows/POSIX allocator FFI.
  - Native/fallback backend truth is reported by platform_aligned_alloc_backend.
  - Wine or cross-compile evidence is forced-compile truth only until real
    Windows runtime evidence is captured.

  SimdAlloc native allocator behavior truth:
  - Aligned allocation owner: nextpas.core.platform.memory.
  - SIMD allocator state: consumes platform-owned aligned allocation seam.
  - SIMD raw host allocator state: no Windows/POSIX allocator FFI declarations.
  - Wine or cross-compile evidence is not real Windows runtime readiness.

  SimdAlloc platform-owned aligned allocation seam consumer contract:
  - Alignment values must be powers of two.
  - Allocation size calculation must be overflow-guarded before calling the lower seam.
  - Invalid alignment and overflow must fail closed with nil.
  - SimdFree(nil) must be a no-op.
  - SimdAlloc(0, *) must return nil.
  - SimdRealloc(nil, size, alignment) must behave like SimdAlloc.
  - SimdRealloc(ptr, 0, alignment) must free and return nil.
  - SimdRealloc must preserve the requested alignment.
  - SimdRealloc must preserve the overlapping prefix bytes.
  - Current fallback truth remains header-backed GetMem/FreeMem until the platform seam lands.
  - Native Windows/POSIX allocator runtime readiness requires platform-owned seam integration plus real runtime evidence.
}

function GetDefaultAlignment: NativeUInt; forward;

function TryResolveAlignment(aAlignment: TSimdAlignment; out aResolved: NativeUInt): Boolean;
begin
  case NativeUInt(aAlignment) of
    NativeUInt(saAuto): aResolved := GetDefaultAlignment;
    NativeUInt(sa16):   aResolved := 16;
    NativeUInt(sa32):   aResolved := 32;
    NativeUInt(sa64):   aResolved := 64;
    else
    begin
      aResolved := 0;
      Exit(False);
    end;
  end;
  Result := True;
end;

function GetDefaultAlignment: NativeUInt;
begin
  case GetActiveBackend of
    sbAVX512: Result := 64;
    sbAVX2:   Result := 32;
    else       Result := 16;
  end;
end;

function SimdAllocAlignment: NativeUInt;
begin
  Result := GetDefaultAlignment;
end;

function SimdAlloc(aSize: SizeUInt; aAlignment: TSimdAlignment = saAuto): Pointer;
var
  LAlign: NativeUInt;
begin
  if aSize = 0 then Exit(nil);

  if not TryResolveAlignment(aAlignment, LAlign) then
    Exit(nil);

  Result := platform_aligned_alloc(aSize, LAlign);
end;

procedure SimdFree(aPtr: Pointer);
begin
  platform_aligned_free(aPtr);
end;

function SimdRealloc(aPtr: Pointer; aNewSize: SizeUInt; aAlignment: TSimdAlignment = saAuto): Pointer;
var
  LAlign: NativeUInt;
begin
  if not TryResolveAlignment(aAlignment, LAlign) then
    Exit(nil);
  Result := platform_aligned_realloc(aPtr, aNewSize, LAlign);
end;

end.
