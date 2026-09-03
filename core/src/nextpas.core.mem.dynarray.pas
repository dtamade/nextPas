unit nextpas.core.mem.dynarray;
{**
 * @desc FPC bootstrap TBytes dynarray introspection — L0 mem unified ability.
 *
 * Single owner of header layout + heap probe (via
 * nextpas.core.system.heap.NpSystemMemSize). Bytes.ops and other L1
 * consumers must NOT poke headers or call heap probe directly;
 * they delegate here (dual-compiler stub elegance, self-bootstrap debt
 * converged to mem).
 *
 * TBytes element size = 1, so capacity = usable bytes - header.
 * RefCnt/High layout matches FPC dynarray header (FPC bootstrap only);
 * nextPas runtime will replace capacity tracking (capacity==Length fallback
 * already portable).
 *
 * perf: inline thin forwards, zero-copy; no allocation, single MemSize probe.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{** Bootstrap capacity probe: heap block size - header; fallback Length. }
function DynArrayCapacity(const A: TBytes): SizeUInt; inline;

{** Bootstrap refcount probe: header RefCnt; nil → 0. }
function DynArrayRefCount(const A: TBytes): PtrInt; inline;

{** Bootstrap length poke: set header High := NewLen-1; nil+0 is no-op. }
procedure DynArraySetLength(var A: TBytes; const ANewLen: SizeUInt); inline;

{** TStringArray capacity probe: (heap block - header) div SizeOf(string); fallback Length. }
function DynArrayCapacityStr(const A: TStringArray): SizeUInt; inline;

{** TStringArray refcount probe: header RefCnt; nil → 0. }
function DynArrayRefCountStr(const A: TStringArray): PtrInt; inline;

{** TStringArray length poke: set header High := NewLen-1; nil+0 is no-op. }
procedure DynArraySetLengthStr(var A: TStringArray; const ANewLen: SizeUInt); inline;

{** Generic capacity probe: (heap block - header) div AElemSize; fallback ALen. }
function DynArrayCapacityElem(APtr: Pointer; ALen: SizeUInt; AElemSize: SizeUInt): SizeUInt; inline;
function DynArrayRefCountElem(APtr: Pointer): PtrInt; inline;
procedure DynArraySetLengthElem(APtr: Pointer; const ANewLen: SizeUInt); inline;

{** Generic capacity for any dynarray var (single source, no per-type wrapper). }
function DynArrayCapacityGeneric(var A; AElemSize: SizeUInt): SizeUInt; inline;

{** Generic length poke for any dynarray var (single source, no per-type wrapper). }
procedure DynArraySetLengthGeneric(var A; const ANewLen: SizeUInt); inline;

implementation

uses
  nextpas.core.system.heap;

type
  PDynArrayHeader = ^TDynArrayHeader;
  TDynArrayHeader = record
    RefCnt: PtrInt;
    High: PtrInt;
  end;

function DynArrayCapacity(const A: TBytes): SizeUInt; inline;
var
  LP: Pointer;
  LBlock: Pointer;
  LSize: SizeUInt;
begin
  Result := 0;
  LP := Pointer(A);
  if LP = nil then
    Exit(0);
  LBlock := PByte(LP) - SizeOf(TDynArrayHeader);
  LSize := NpSystemMemSize(LBlock);
  if LSize < SizeOf(TDynArrayHeader) then
    Exit(SizeUInt(Length(A)));
  Result := LSize - SizeOf(TDynArrayHeader);
end;

function DynArrayRefCount(const A: TBytes): PtrInt; inline;
var
  LP: Pointer;
begin
  LP := Pointer(A);
  if LP = nil then
    Exit(0);
  Result := PDynArrayHeader(PByte(LP) - SizeOf(TDynArrayHeader))^.RefCnt;
end;

procedure DynArraySetLength(var A: TBytes; const ANewLen: SizeUInt); inline;
begin
  if Pointer(A) = nil then
  begin
    if ANewLen <> 0 then
      raise EInvalidOperation.Create('DynArraySetLength: nil with non-zero len');
    Exit;
  end;
  PDynArrayHeader(PByte(Pointer(A)) - SizeOf(TDynArrayHeader))^.High := PtrInt(ANewLen) - 1;
end;

function DynArrayCapacityStr(const A: TStringArray): SizeUInt; inline;
var
  LP: Pointer;
  LBlock: Pointer;
  LSize: SizeUInt;
begin
  Result := 0;
  LP := Pointer(A);
  if LP = nil then
    Exit(0);
  LBlock := PByte(LP) - SizeOf(TDynArrayHeader);
  LSize := NpSystemMemSize(LBlock);
  if LSize < SizeOf(TDynArrayHeader) then
    Exit(SizeUInt(Length(A)));
  Result := (LSize - SizeOf(TDynArrayHeader)) div SizeOf(string);
end;

function DynArrayRefCountStr(const A: TStringArray): PtrInt; inline;
var
  LP: Pointer;
begin
  LP := Pointer(A);
  if LP = nil then
    Exit(0);
  Result := PDynArrayHeader(PByte(LP) - SizeOf(TDynArrayHeader))^.RefCnt;
end;

procedure DynArraySetLengthStr(var A: TStringArray; const ANewLen: SizeUInt); inline;
begin
  if Pointer(A) = nil then
  begin
    if ANewLen <> 0 then
      raise EInvalidOperation.Create('DynArraySetLengthStr: nil with non-zero len');
    Exit;
  end;
  PDynArrayHeader(PByte(Pointer(A)) - SizeOf(TDynArrayHeader))^.High := PtrInt(ANewLen) - 1;
end;

function DynArrayCapacityElem(APtr: Pointer; ALen: SizeUInt; AElemSize: SizeUInt): SizeUInt; inline;
var LBlock: Pointer; LSize: SizeUInt;
begin
  if APtr = nil then Exit(0);
  if AElemSize = 0 then Exit(ALen);
  LBlock := PByte(APtr) - SizeOf(TDynArrayHeader);
  LSize := NpSystemMemSize(LBlock);
  if LSize < SizeOf(TDynArrayHeader) then Exit(ALen);
  Result := (LSize - SizeOf(TDynArrayHeader)) div AElemSize;
end;

function DynArrayCapacityGeneric(var A; AElemSize: SizeUInt): SizeUInt; inline;
var LP: Pointer; LBlock: Pointer; LSize: SizeUInt;
begin
  LP := PPointer(@A)^;
  if LP = nil then Exit(0);
  if AElemSize = 0 then Exit(SizeUInt(PDynArrayHeader(PByte(LP) - SizeOf(TDynArrayHeader))^.High + 1));
  LBlock := PByte(LP) - SizeOf(TDynArrayHeader);
  LSize := NpSystemMemSize(LBlock);
  if LSize < SizeOf(TDynArrayHeader) then Exit(SizeUInt(PDynArrayHeader(PByte(LP) - SizeOf(TDynArrayHeader))^.High + 1));
  Result := (LSize - SizeOf(TDynArrayHeader)) div AElemSize;
end;

procedure DynArraySetLengthGeneric(var A; const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute A;
begin
  DynArraySetLength(LBytes, ANewLen);
end;

function DynArrayRefCountElem(APtr: Pointer): PtrInt; inline;
begin
  if APtr = nil then Exit(0);
  Result := PDynArrayHeader(PByte(APtr) - SizeOf(TDynArrayHeader))^.RefCnt;
end;

procedure DynArraySetLengthElem(APtr: Pointer; const ANewLen: SizeUInt); inline;
begin
  if APtr = nil then
  begin
    if ANewLen <> 0 then
      raise EInvalidOperation.Create('DynArraySetLengthElem: nil with non-zero len');
    Exit;
  end;
  PDynArrayHeader(PByte(APtr) - SizeOf(TDynArrayHeader))^.High := PtrInt(ANewLen) - 1;
end;

end.
