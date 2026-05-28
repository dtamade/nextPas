unit nextpas.core.simd.backend.priority;

{$mode objfpc}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.base;

type
  TSimdBackendPriorityOrder = array[0..9] of TSimdBackend;

const
  SIMD_BACKEND_PRIORITY_ORDER: TSimdBackendPriorityOrder = (
    sbAVX512,
    sbAVX2,
    sbSSE42,
    sbSSE41,
    sbSSSE3,
    sbSSE3,
    sbSSE2,
    sbNEON,
    sbRISCVV,
    sbScalar
  );

function GetSimdBackendPriorityValue(aBackend: TSimdBackend): Integer;

implementation

function GetSimdBackendPriorityValue(aBackend: TSimdBackend): Integer;
begin
  Result := 0;
  case aBackend of
    sbScalar: Result := 0;
    sbRISCVV: Result := 10;
    sbNEON: Result := 20;
    sbSSE2: Result := 30;
    sbSSE3: Result := 40;
    sbSSSE3: Result := 50;
    sbSSE41: Result := 60;
    sbSSE42: Result := 70;
    sbAVX2: Result := 80;
    sbAVX512: Result := 90;
  end;
end;

end.
