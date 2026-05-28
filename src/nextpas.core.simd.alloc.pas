unit nextpas.core.simd.alloc;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}

interface

type
  TSimdAlignment = (saAuto = 0, sa16 = 16, sa32 = 32, sa64 = 64);

function SimdAlloc(aSize: SizeUInt; aAlignment: TSimdAlignment = saAuto): Pointer;
procedure SimdFree(aPtr: Pointer);
function SimdRealloc(aPtr: Pointer; aNewSize: SizeUInt; aAlignment: TSimdAlignment = saAuto): Pointer;
function SimdAllocAlignment: NativeUInt;

implementation

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

type
  PAllocHeader = ^TAllocHeader;
  TAllocHeader = record
    OrigPtr: Pointer;
    Size: SizeUInt;
    Alignment: NativeUInt;
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
  LRawSize: SizeUInt;
  LRaw, LAligned: Pointer;
  LHeader: PAllocHeader;
begin
  if aSize = 0 then Exit(nil);

  if aAlignment = saAuto then
    LAlign := GetDefaultAlignment
  else
    LAlign := NativeUInt(aAlignment);

  LRawSize := aSize + LAlign + SizeOf(TAllocHeader);
  GetMem(LRaw, LRawSize);

  LAligned := Pointer((PtrUInt(LRaw) + SizeOf(TAllocHeader) + LAlign - 1) and not (PtrUInt(LAlign) - 1));

  LHeader := PAllocHeader(PtrUInt(LAligned) - SizeOf(TAllocHeader));
  LHeader^.OrigPtr := LRaw;
  LHeader^.Size := aSize;
  LHeader^.Alignment := LAlign;

  Result := LAligned;
end;

procedure SimdFree(aPtr: Pointer);
var
  LHeader: PAllocHeader;
begin
  if aPtr = nil then Exit;
  LHeader := PAllocHeader(PtrUInt(aPtr) - SizeOf(TAllocHeader));
  FreeMem(LHeader^.OrigPtr);
end;

function SimdRealloc(aPtr: Pointer; aNewSize: SizeUInt; aAlignment: TSimdAlignment = saAuto): Pointer;
var
  LHeader: PAllocHeader;
  LOldSize: SizeUInt;
begin
  if aPtr = nil then Exit(SimdAlloc(aNewSize, aAlignment));
  if aNewSize = 0 then begin SimdFree(aPtr); Exit(nil); end;

  LHeader := PAllocHeader(PtrUInt(aPtr) - SizeOf(TAllocHeader));
  LOldSize := LHeader^.Size;

  Result := SimdAlloc(aNewSize, aAlignment);
  if LOldSize < aNewSize then
    Move(aPtr^, Result^, LOldSize)
  else
    Move(aPtr^, Result^, aNewSize);
  SimdFree(aPtr);
end;

end.
