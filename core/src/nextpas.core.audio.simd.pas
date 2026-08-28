unit nextpas.core.audio.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

function AudioUseNeon: Boolean; inline;
function AudioUseAVX2: Boolean; inline;
function AudioUseSSE2: Boolean; inline;
function AudioSimdBackendName: string; inline;

implementation

function AudioUseNeon: Boolean;
begin
{$ifdef cpuaarch64}
  Result := IsBackendDispatchable(sbNEON) or (GetActiveBackend = sbNEON);
  if not Result then
    Result := GetActiveBackend <> sbScalar;
{$else}
  Result := False;
{$endif}
end;

function AudioUseAVX2: Boolean;
begin
{$ifdef cpux86_64}
  Result := IsBackendDispatchable(sbAVX2) or (GetActiveBackend = sbAVX2);
  if not Result then
    Result := GetActiveBackend in [sbAVX2, sbAVX512];
{$else}
  Result := False;
{$endif}
end;

function AudioUseSSE2: Boolean;
begin
{$ifdef cpux86_64}
  Result := IsBackendDispatchable(sbSSE2) or (GetActiveBackend in [sbSSE2, sbSSE3, sbSSSE3, sbSSE41, sbSSE42, sbAVX2, sbAVX512]);
{$else}
  {$ifdef cpui386}
  Result := IsBackendDispatchable(sbSSE2);
  {$else}
  Result := False;
  {$endif}
{$endif}
end;

function AudioSimdBackendName: string;
var
  B: TSimdBackend;
begin
  B := GetActiveBackend;
  case B of
    sbScalar: Result := 'scalar';
    sbSSE2: Result := 'sse2';
    sbSSE3: Result := 'sse3';
    sbSSSE3: Result := 'ssse3';
    sbSSE41: Result := 'sse41';
    sbSSE42: Result := 'sse42';
    sbAVX2: Result := 'avx2';
    sbAVX512: Result := 'avx512';
    sbNEON: Result := 'neon';
    else Result := 'unknown';
  end;
end;

end.
