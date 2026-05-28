{$MODE OBJFPC}{$H+}
{$I nextpas.core.settings.inc}
// Convenience layer — functionality overlaps with nextpas.core.simd.arrays.
// Retained for benchmark compatibility; prefer arrays.pas for new code.

unit nextpas.core.simd.algorithms;

interface

type
  TSimdWidth = (
    swScalar,
    sw128,
    sw256,
    sw512
  );

  TSimdLaneInfo = record
    Width: TSimdWidth;
    F32Lanes: Integer;
    F64Lanes: Integer;
    Alignment: Integer;
  end;

function SimdGetBestLaneInfo: TSimdLaneInfo;

procedure SimdArrayAdd(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure SimdArrayMul(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure SimdArrayMulScalar(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
procedure SimdArrayAxpy(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);

function SimdReduceSum(aSrc: PSingle; aCount: SizeUInt): Single;
function SimdReduceDot(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
function SimdReduceMin(aSrc: PSingle; aCount: SizeUInt): Single;
function SimdReduceMax(aSrc: PSingle; aCount: SizeUInt): Single;

implementation

uses
  nextpas.core.simd.dispatch,
  nextpas.core.simd.direct;

function SimdGetBestLaneInfo: TSimdLaneInfo;
var
  LD: PSimdDispatchTable;
begin
  LD := GetDirectDispatchTable;
  if (LD <> nil) and Assigned(LD^.AddF32x8) then
  begin
    Result.Width := sw256;
    Result.F32Lanes := 8;
    Result.F64Lanes := 4;
    Result.Alignment := 32;
  end
  else if (LD <> nil) and Assigned(LD^.AddF32x4) then
  begin
    Result.Width := sw128;
    Result.F32Lanes := 4;
    Result.F64Lanes := 2;
    Result.Alignment := 16;
  end
  else
  begin
    Result.Width := swScalar;
    Result.F32Lanes := 1;
    Result.F64Lanes := 1;
    Result.Alignment := 4;
  end;
end;

procedure SimdArrayAdd(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var LD: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aDst = nil) or (aCount = 0) then Exit;
  LD := GetDirectDispatchTable;
  LD^.ArrayAddF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure SimdArrayMul(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var LD: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aDst = nil) or (aCount = 0) then Exit;
  LD := GetDirectDispatchTable;
  LD^.ArrayMulF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure SimdArrayMulScalar(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var LD: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aDst = nil) or (aCount = 0) then Exit;
  LD := GetDirectDispatchTable;
  LD^.ArrayMulScalarF32(aSrc, aDst, aCount, aScalar);
end;

procedure SimdArrayAxpy(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
var LD: PSimdDispatchTable;
begin
  if (aX = nil) or (aY = nil) or (aDst = nil) or (aCount = 0) then Exit;
  LD := GetDirectDispatchTable;
  LD^.ArrayAxpyF32(aAlpha, aX, aY, aDst, aCount);
end;

function SimdReduceSum(aSrc: PSingle; aCount: SizeUInt): Single;
var LD: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then begin Result := 0; Exit; end;
  LD := GetDirectDispatchTable;
  Result := LD^.ReduceSumF32(aSrc, aCount);
end;

function SimdReduceDot(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
var LD: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aCount = 0) then begin Result := 0; Exit; end;
  LD := GetDirectDispatchTable;
  Result := LD^.ReduceDotF32(aSrc1, aSrc2, aCount);
end;

function SimdReduceMin(aSrc: PSingle; aCount: SizeUInt): Single;
var LD: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then begin Result := 0; Exit; end;
  LD := GetDirectDispatchTable;
  Result := LD^.ReduceMinF32(aSrc, aCount);
end;

function SimdReduceMax(aSrc: PSingle; aCount: SizeUInt): Single;
var LD: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then begin Result := 0; Exit; end;
  LD := GetDirectDispatchTable;
  Result := LD^.ReduceMaxF32(aSrc, aCount);
end;

end.
