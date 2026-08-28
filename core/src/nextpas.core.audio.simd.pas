unit nextpas.core.audio.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  TSimdCaps = record
    HasSSE2: Boolean;
    HasAVX2: Boolean;
    HasNEON: Boolean;
  end;

function AudioSimdCaps: TSimdCaps; inline;
procedure SimdAddF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
procedure SimdMulF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
function SimdPeakF32(const AData: PSingle; ACount: Integer): Single;
function SimdSumSquaresF32(const AData: PSingle; ACount: Integer): Double;

implementation

var
  GCaps: TSimdCaps;
  GInit: Boolean;

function AudioSimdCaps: TSimdCaps;
begin
  if not GInit then
  begin
    GCaps.HasSSE2 := True;
    GCaps.HasAVX2 := False;
    GCaps.HasNEON := False;
    GInit := True;
  end;
  Result := GCaps;
end;

procedure SimdAddF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
var I: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  for I := 0 to ACount - 1 do
    ADst[I] := ADst[I] + ASrc[I] * AGain;
end;

procedure SimdMulF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
var I: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  for I := 0 to ACount - 1 do
    ADst[I] := ASrc[I] * AGain;
end;

function SimdPeakF32(const AData: PSingle; ACount: Integer): Single;
var I: Integer; L, V: Single;
begin
  Result := 0;
  if (AData = nil) or (ACount <= 0) then Exit;
  for I := 0 to ACount - 1 do
  begin
    V := AData[I];
    if V < 0 then V := -V;
    L := V;
    if L > Result then Result := L;
  end;
end;

function SimdSumSquaresF32(const AData: PSingle; ACount: Integer): Double;
var I: Integer;
begin
  Result := 0;
  if (AData = nil) or (ACount <= 0) then Exit;
  for I := 0 to ACount - 1 do
    Result := Result + AData[I] * AData[I];
end;

end.
