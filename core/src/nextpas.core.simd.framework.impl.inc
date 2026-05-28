function GetCPUInfo: TCPUInfo;
begin
  Result := nextpas.core.simd.cpuinfo.GetCPUInfo;
end;

function GetCurrentBackend: TSimdBackend;
begin
  Result := nextpas.core.simd.runtime.GetCurrentBackend;
end;

function GetCurrentBackendInfo: TSimdBackendInfo;
begin
  Result := nextpas.core.simd.runtime.GetCurrentBackendInfo;
end;

function GetCurrentRuntimeSnapshot: TSimdRuntimeSnapshot;
begin
  Result := nextpas.core.simd.runtime.GetCurrentRuntimeSnapshot;
end;

function GetCPUInformation: TCPUInfo;
begin
  Result := GetCPUInfo;
end;

function GetSupportedBackendList: TSimdBackendArray;
begin
  Result := nextpas.core.simd.cpuinfo.GetSupportedBackendList;
end;

function GetBestSupportedBackend: TSimdBackend;
begin
  Result := nextpas.core.simd.cpuinfo.GetBestSupportedBackend;
end;

function IsBackendRegisteredInBinary(aBackend: TSimdBackend): Boolean;
begin
  Result := nextpas.core.simd.runtime.IsBackendRegisteredInBinary(aBackend);
end;

function GetRegisteredBackendList: TSimdBackendArray;
begin
  Result := nextpas.core.simd.runtime.GetRegisteredBackendList;
end;

function GetDispatchableBackendList: TSimdBackendArray;
begin
  Result := nextpas.core.simd.runtime.GetDispatchableBackendList;
end;

function GetBestDispatchableBackend: TSimdBackend;
begin
  Result := nextpas.core.simd.runtime.GetBestDispatchableBackend;
end;

function GetAvailableBackendList: TSimdBackendArray;
begin
  Result := nextpas.core.simd.runtime.GetAvailableBackendList;
end;

function TrySetCurrentBackend(aBackend: TSimdBackend): Boolean;
begin
  Result := nextpas.core.simd.runtime.TrySetCurrentBackend(aBackend);
end;

procedure SetCurrentBackend(aBackend: TSimdBackend);
begin
  nextpas.core.simd.runtime.SetCurrentBackend(aBackend);
end;

procedure ResetCurrentBackendSelection;
begin
  nextpas.core.simd.runtime.ResetCurrentBackendSelection;
end;

function TryForceBackend(aBackend: TSimdBackend): Boolean;
begin
  Result := TrySetCurrentBackend(aBackend);
end;

procedure ForceBackend(aBackend: TSimdBackend);
begin
  SetCurrentBackend(aBackend);
end;

procedure ResetBackendSelection;
begin
  ResetCurrentBackendSelection;
end;

function AllocateAligned(size: NativeUInt; alignment: NativeUInt): Pointer;
begin
  Result := AlignedAlloc(size, alignment);
end;

procedure FreeAligned(ptr: Pointer);
begin
  AlignedFree(ptr);
end;

function IsPointerAligned(ptr: Pointer; alignment: NativeUInt): Boolean;
begin
  Result := nextpas.core.simd.memutils.IsAligned(ptr, alignment);
end;
