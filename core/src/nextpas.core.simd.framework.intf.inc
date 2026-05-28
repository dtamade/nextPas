// Canonical façade convenience wrapper for nextpas.core.simd.cpuinfo.GetCPUInfo.
function GetCPUInfo: TCPUInfo; inline;

// Canonical runtime/control-plane façade.
function GetCurrentRuntimeSnapshot: TSimdRuntimeSnapshot; inline;
function GetCurrentBackend: TSimdBackend; inline;
function GetCurrentBackendInfo: TSimdBackendInfo; inline;

// Compatibility façade alias for GetCPUInfo. Keep for compatibility only;
// new code and docs should use GetCPUInfo.
function GetCPUInformation: TCPUInfo; inline;

// Canonical CPU capability view.
function GetSupportedBackendList: TSimdBackendArray; inline;
function GetBestSupportedBackend: TSimdBackend; inline;

// Canonical runtime registration / dispatchability view.
function IsBackendRegisteredInBinary(ABackend: TSimdBackend): Boolean; inline;
function GetRegisteredBackendList: TSimdBackendArray; inline;
function GetDispatchableBackendList: TSimdBackendArray; inline;
function GetBestDispatchableBackend: TSimdBackend; inline;

// Compatibility alias for the dispatchable view. Keep for compatibility only;
// new code and docs should use GetDispatchableBackendList.
function GetAvailableBackendList: TSimdBackendArray; inline;

// Canonical runtime control-plane mutators.
function TrySetCurrentBackend(ABackend: TSimdBackend): Boolean; inline;
procedure SetCurrentBackend(ABackend: TSimdBackend); inline;
procedure ResetCurrentBackendSelection; inline;

// Legacy façade aliases kept for compatibility only; new code and docs should
// use the canonical runtime control-plane names above.
function TryForceBackend(ABackend: TSimdBackend): Boolean; inline;
procedure ForceBackend(ABackend: TSimdBackend); inline;
procedure ResetBackendSelection; inline;

// Memory helpers.
function AllocateAligned(size: NativeUInt; alignment: NativeUInt = 32): Pointer; inline;
procedure FreeAligned(ptr: Pointer); inline;
function IsPointerAligned(ptr: Pointer; alignment: NativeUInt = 32): Boolean; inline;
