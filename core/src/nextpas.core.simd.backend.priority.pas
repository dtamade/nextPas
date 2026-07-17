unit nextpas.core.simd.backend.priority;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base;

type
  TSimdBackendPriorityOrder = array[0..9] of TSimdBackend;

const
  { Default backend priority order.
    Users can override this by defining SIMD_CUSTOM_BACKEND_PRIORITY
    and providing their own array. }
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

{ Get numeric priority value for a backend (higher = preferred) }
function GetSimdBackendPriorityValue(ABackend: TSimdBackend): Integer;

{ Get the preferred backend from available backends }
function GetPreferredBackend(const AAvailable: array of TSimdBackend): TSimdBackend;

{ Check if a backend is preferred over another }
function IsBackendPreferred(ABackend, AOther: TSimdBackend): Boolean;

implementation

function GetSimdBackendPriorityValue(ABackend: TSimdBackend): Integer;
begin
  Result := 0;
  case ABackend of
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
    sbLASX: Result := 25;    // LoongArch LASX 256-bit SIMD
    sbWASM: Result := 15;    // WebAssembly SIMD128
    sbVSX: Result := 25;     // POWER VSX
    sbMSA: Result := 15;     // MIPS MSA
  end;
end;

function GetPreferredBackend(const AAvailable: array of TSimdBackend): TSimdBackend;
var
  LBest, LCurrent: TSimdBackend;
  LBestPriority, LPriority: Integer;
  LIndex: Integer;
begin
  LBest := sbScalar;
  LBestPriority := -1;

  for LIndex := Low(AAvailable) to High(AAvailable) do
  begin
    LCurrent := AAvailable[LIndex];
    LPriority := GetSimdBackendPriorityValue(LCurrent);
    if LPriority > LBestPriority then
    begin
      LBest := LCurrent;
      LBestPriority := LPriority;
    end;
  end;

  Result := LBest;
end;

function IsBackendPreferred(ABackend, AOther: TSimdBackend): Boolean;
begin
  Result := GetSimdBackendPriorityValue(ABackend) > GetSimdBackendPriorityValue(AOther);
end;

end.
