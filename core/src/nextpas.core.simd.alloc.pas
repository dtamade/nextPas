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
