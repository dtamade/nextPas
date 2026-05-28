function GetSupportedBackendList: TSimdBackendArray;
var
  LBackend: TSimdBackend;
  LBackends: TSimdBackendArray;
  LCount: Integer;
begin
  SetLength(LBackends, Length(SIMD_BACKEND_PRIORITY_ORDER));
  LCount := 0;
  for LBackend in SIMD_BACKEND_PRIORITY_ORDER do
  begin
    if IsBackendSupportedOnCPU(LBackend) then
    begin
      LBackends[LCount] := LBackend;
      Inc(LCount);
    end;
  end;
  SetLength(LBackends, LCount);
  Result := LBackends;
end;

function GetSupportedBackends: TSimdBackendArray;
begin
  Result := GetSupportedBackendList;
end;

function GetAvailableBackends: TSimdBackendArray;
begin
  Result := GetSupportedBackendList;
end;

function GetBestSupportedBackend: TSimdBackend;
var
  LBackend: TSimdBackend;
begin
  for LBackend in SIMD_BACKEND_PRIORITY_ORDER do
    if IsBackendSupportedOnCPU(LBackend) then
      Exit(LBackend);

  Result := sbScalar;
end;

function GetBestBackendOnCPU: TSimdBackend;
begin
  Result := GetBestSupportedBackend;
end;

function GetBestBackend: TSimdBackend;
begin
  Result := GetBestSupportedBackend;
end;
