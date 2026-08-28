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
var I, N4: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // 4-wide unroll — compiler vectorizes to SSE2/AVX on -O2, zero call overhead
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    ADst[I] := ADst[I] + ASrc[I] * AGain;
    ADst[I+1] := ADst[I+1] + ASrc[I+1] * AGain;
    ADst[I+2] := ADst[I+2] + ASrc[I+2] * AGain;
    ADst[I+3] := ADst[I+3] + ASrc[I+3] * AGain;
    Inc(I, 4);
  end;
  while I < ACount do
  begin
    ADst[I] := ADst[I] + ASrc[I] * AGain;
    Inc(I);
  end;
end;

procedure SimdMulF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
var I, N4: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    ADst[I] := ASrc[I] * AGain;
    ADst[I+1] := ASrc[I+1] * AGain;
    ADst[I+2] := ASrc[I+2] * AGain;
    ADst[I+3] := ASrc[I+3] * AGain;
    Inc(I, 4);
  end;
  while I < ACount do
  begin
    ADst[I] := ASrc[I] * AGain;
    Inc(I);
  end;
end;

function SimdPeakF32(const AData: PSingle; ACount: Integer): Single;
var I, N4: Integer; V0, V1, V2, V3, M: Single;
begin
  Result := 0;
  if (AData = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
  M := 0;
  I := 0;
  while I < N4 do
  begin
    V0 := AData[I]; if V0 < 0 then V0 := -V0; if V0 > M then M := V0;
    V1 := AData[I+1]; if V1 < 0 then V1 := -V1; if V1 > M then M := V1;
    V2 := AData[I+2]; if V2 < 0 then V2 := -V2; if V2 > M then M := V2;
    V3 := AData[I+3]; if V3 < 0 then V3 := -V3; if V3 > M then M := V3;
    Inc(I, 4);
  end;
  Result := M;
  while I < ACount do
  begin
    V0 := AData[I]; if V0 < 0 then V0 := -V0; if V0 > Result then Result := V0;
    Inc(I);
  end;
  if M > Result then Result := M;
end;

function SimdSumSquaresF32(const AData: PSingle; ACount: Integer): Double;
var I, N4: Integer; S: Double;
begin
  Result := 0;
  if (AData = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
  S := 0;
  I := 0;
  while I < N4 do
  begin
    S := S + AData[I]*AData[I] + AData[I+1]*AData[I+1] + AData[I+2]*AData[I+2] + AData[I+3]*AData[I+3];
    Inc(I, 4);
  end;
  Result := S;
  I := N4;
  while I < ACount do
  begin
    Result := Result + AData[I] * AData[I];
    Inc(I);
  end;
end;

end.
