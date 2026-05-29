unit nextpas.core.simd.public_smoke_support;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  nextpas.core.simd.base;

function GetExpectedPublicSmokeDefaultBackend: TSimdBackend;

implementation

uses
  nextpas.core.simd.dispatch;

function GetExpectedPublicSmokeDefaultBackend: TSimdBackend;
begin
  Result := GetBestDispatchableBackend;
end;

end.
