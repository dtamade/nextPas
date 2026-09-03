unit nextpas.core.collections.freelist;
{ freelist — bounded recycling via bytes.ops geometric + mem.dynarray Exactly-Once poke, amortized O(1) inline zero-copy, 4x half-shrink }
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.mem.dynarray;
const
  FREELIST_MIN_CAP = 64;
type
  // named dynamic array so routines can SetLength/probe capacity (open-array params allow neither)
  TFreelistU64s = array of UInt64;
function FreelistCapacityU64(const A: TFreelistU64s): SizeUInt; inline;
procedure FreelistEnsureU64(var A: TFreelistU64s; ANewLen: SizeUInt); inline;
procedure FreelistPushU64(var A: TFreelistU64s; AValue: UInt64); inline;
function FreelistPopU64(var A: TFreelistU64s; out AValue: UInt64): Boolean; inline;
procedure FreelistTryShrinkU64(var A: TFreelistU64s); inline;
// generic trivial-type freelist single source via bytes.ops + mem.dynarray poke, inline zero-copy
procedure FreelistEnsure(var A; AElemSize: SizeUInt; ANewLen: SizeUInt); inline;
function FreelistCapacity(var A; AElemSize: SizeUInt): SizeUInt; inline;
procedure FreelistTryShrink(var A; AElemSize: SizeUInt); inline;
implementation
type
  PDynArrayHeaderLocal = ^TDynArrayHeaderLocal;
  TDynArrayHeaderLocal = record RefCnt: PtrInt; High: PtrInt; end;
function FreelistCapacityU64(const A: TFreelistU64s): SizeUInt; inline;
begin
  Result := BytesDynCapacityElem(Pointer(A), SizeUInt(Length(A)), SizeOf(UInt64));
end;
procedure FreelistEnsureU64(var A: TFreelistU64s; ANewLen: SizeUInt); inline;
begin
  BytesDynEnsureLength(A, SizeOf(UInt64), ANewLen);
end;
procedure FreelistPushU64(var A: TFreelistU64s; AValue: UInt64); inline;
var LNeed: SizeUInt;
begin
  LNeed := SizeUInt(Length(A)) + 1;
  BytesDynEnsureLength(A, SizeOf(UInt64), LNeed);
  A[High(A)] := AValue;
end;
function FreelistPopU64(var A: TFreelistU64s; out AValue: UInt64): Boolean; inline;
begin
  if Length(A) = 0 then Exit(False);
  AValue := A[High(A)];
  SetLength(A, Length(A) - 1);
  Result := True;
end;
procedure FreelistTryShrinkU64(var A: TFreelistU64s); inline;
var LCap, LLen, LNewCap: SizeUInt;
begin
  LCap := FreelistCapacityU64(A);
  LLen := SizeUInt(Length(A));
  if LLen = 0 then
  begin
    if LCap > 0 then SetLength(A, 0);
    Exit;
  end;
  if (LCap > FREELIST_MIN_CAP) and (LLen * 4 < LCap) then
  begin
    LNewCap := LCap shr 1;
    if LNewCap < FREELIST_MIN_CAP then LNewCap := FREELIST_MIN_CAP;
    if LNewCap < LLen then LNewCap := LLen;
    if LNewCap < LCap then
    begin
      SetLength(A, Integer(LNewCap));
      if SizeUInt(Length(A)) <> LLen then
        DynArraySetLengthGeneric(A, LLen);
    end;
  end;
end;
procedure FreelistEnsure(var A; AElemSize: SizeUInt; ANewLen: SizeUInt); inline;
begin
  BytesDynEnsureLength(A, AElemSize, ANewLen);
end;
function FreelistCapacity(var A; AElemSize: SizeUInt): SizeUInt; inline;
begin
  Result := BytesDynCapacityGeneric(A, AElemSize);
end;
procedure FreelistTryShrink(var A; AElemSize: SizeUInt); inline;
var LCap, LLen, LNewCap: SizeUInt; LP: Pointer; LBytes: TBytes absolute A;
begin
  LCap := BytesDynCapacityGeneric(A, AElemSize);
  LP := PPointer(@A)^;
  if LP = nil then LLen := 0 else LLen := SizeUInt(PDynArrayHeaderLocal(PByte(LP) - SizeOf(TDynArrayHeaderLocal))^.High + 1);
  if LLen = 0 then
  begin
    if LCap > 0 then SetLength(LBytes, 0);
    Exit;
  end;
  if (LCap > FREELIST_MIN_CAP) and (LLen * 4 < LCap) then
  begin
    LNewCap := LCap shr 1;
    if LNewCap < FREELIST_MIN_CAP then LNewCap := FREELIST_MIN_CAP;
    if LNewCap < LLen then LNewCap := LLen;
    if LNewCap < LCap then
    begin
      SetLength(LBytes, LNewCap * AElemSize);
      if SizeUInt(PDynArrayHeaderLocal(PByte(PPointer(@A)^) - SizeOf(TDynArrayHeaderLocal))^.High + 1) <> LLen then
        DynArraySetLengthGeneric(A, LLen);
    end;
  end;
end;
end.
