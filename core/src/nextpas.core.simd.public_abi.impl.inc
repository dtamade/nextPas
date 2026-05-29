const
  NEXTPAS_SIMD_PUBLIC_ABI_VERSION_MAJOR: UInt16 = 1;
  NEXTPAS_SIMD_PUBLIC_ABI_VERSION_MINOR: UInt16 = 3;
  NEXTPAS_SIMD_PUBLIC_ABI_SIGNATURE_HI: UInt64 = QWord($73696D645055424C);
  NEXTPAS_SIMD_PUBLIC_ABI_SIGNATURE_LO: UInt64 = QWord($4142495441424C45);
  NEXTPAS_SIMD_PUBLIC_ABI_V2_VERSION_MAJOR: UInt16 = 2;
  NEXTPAS_SIMD_PUBLIC_ABI_V2_VERSION_MINOR: UInt16 = 0;
  NEXTPAS_SIMD_PUBLIC_ABI_V2_SIGNATURE_HI: UInt64 = QWord($73696D6450554232);
  NEXTPAS_SIMD_PUBLIC_ABI_V2_SIGNATURE_LO: UInt64 = QWord($4150495632544142);

type
  TSimdPublicMemEqualFunc = function(aA, aB: Pointer; aLen: SizeUInt): LongBool;
  TSimdPublicMemFindByteFunc = function(aP: Pointer; aLen: SizeUInt; aValue: Byte): PtrInt;
  TSimdPublicMemDiffRangeFunc = function(aA, aB: Pointer; aLen: SizeUInt;
    out aFirstDiff, aLastDiff: SizeUInt): Boolean;
  TSimdPublicSumBytesFunc = function(aP: Pointer; aLen: SizeUInt): UInt64;
  TSimdPublicCountByteFunc = function(aP: Pointer; aLen: SizeUInt; aValue: Byte): SizeUInt;
  TSimdPublicBitsetPopCountFunc = function(aP: Pointer; aByteLen: SizeUInt): SizeUInt;
  TSimdPublicUtf8ValidateFunc = function(aP: Pointer; aLen: SizeUInt): Boolean;
  TSimdPublicAsciiIEqualFunc = function(aA, aB: Pointer; aLen: SizeUInt): Boolean;
  TSimdPublicBytesIndexOfFunc = function(aHaystack: Pointer; aHaystackLen: SizeUInt;
    aNeedle: Pointer; aNeedleLen: SizeUInt): PtrInt;
  TSimdPublicMemCopyFunc = procedure(aSrc, aDst: Pointer; aLen: SizeUInt);
  TSimdPublicMemSetFunc = procedure(aDst: Pointer; aLen: SizeUInt; aValue: Byte);
  TSimdPublicAsciiCaseFunc = procedure(aP: Pointer; aLen: SizeUInt);
  TSimdPublicMemReverseFunc = procedure(aP: Pointer; aLen: SizeUInt);
  TSimdPublicMinMaxBytesFunc = procedure(aP: Pointer; aLen: SizeUInt; out aMinVal, aMaxVal: Byte);

  PSimdPublicApiBindingState = ^TSimdPublicApiBindingState;
  TSimdPublicApiBindingState = record
    NextOwned: PSimdPublicApiBindingState;
    // Metadata stays frozen with the published data-plane snapshot, while the ABI
    // entry points remain stable cdecl shims that lazily hop through the
    // latest published binding state.
    DataPlane: PSimdDataPlane;
    Api: TNextPasSimdPublicApi;
    ApiV2: TNextPasSimdPublicApiV2;
    SnapshotGeneration: UInt64;
    SnapshotFlags: TNextPasSimdPublicApiV2Flags;
    Dispatch: PSimdDispatchTable;
    MemEqualBound: TSimdPublicMemEqualFunc;
    MemFindByteBound: TSimdPublicMemFindByteFunc;
    MemDiffRangeBound: TSimdPublicMemDiffRangeFunc;
    SumBytesBound: TSimdPublicSumBytesFunc;
    CountByteBound: TSimdPublicCountByteFunc;
    BitsetPopCountBound: TSimdPublicBitsetPopCountFunc;
    Utf8ValidateBound: TSimdPublicUtf8ValidateFunc;
    AsciiIEqualBound: TSimdPublicAsciiIEqualFunc;
    BytesIndexOfBound: TSimdPublicBytesIndexOfFunc;
    MemCopyBound: TSimdPublicMemCopyFunc;
    MemSetBound: TSimdPublicMemSetFunc;
    ToLowerAsciiBound: TSimdPublicAsciiCaseFunc;
    ToUpperAsciiBound: TSimdPublicAsciiCaseFunc;
    MemReverseBound: TSimdPublicMemReverseFunc;
    MinMaxBytesBound: TSimdPublicMinMaxBytesFunc;
  end;

var
  g_SimdPublicApiStatePtr: Pointer = nil;
  // Public API tables may be cached by consumers after later control-plane
  // mutations, so published states stay process-owned until finalization.
  g_SimdPublicApiOwnedHead: PSimdPublicApiBindingState = nil;
  g_SimdPublicApiRebindLock: TRTLCriticalSection;
  g_SimdPublicApiSnapshotGeneration: UInt64 = 0;

function DefaultBackendName(const aBackend: TSimdBackend): AnsiString; inline;
begin
  Result := '';
  case aBackend of
    sbScalar: Result := 'Scalar';
    sbSSE2: Result := 'SSE2';
    sbSSE3: Result := 'SSE3';
    sbSSSE3: Result := 'SSSE3';
    sbSSE41: Result := 'SSE4.1';
    sbSSE42: Result := 'SSE4.2';
    sbAVX2: Result := 'AVX2';
    sbAVX512: Result := 'AVX-512';
    sbNEON: Result := 'NEON';
    sbRISCVV: Result := 'RISC-V V';
  end;
end;

function DefaultBackendDescription(const aBackend: TSimdBackend): AnsiString; inline;
begin
  Result := '';
  case aBackend of
    sbScalar: Result := 'Pure scalar reference implementation';
    sbSSE2: Result := 'x86-64 SSE2 SIMD implementation';
    sbSSE3: Result := 'x86-64 SSE3 SIMD implementation';
    sbSSSE3: Result := 'x86-64 SSSE3 SIMD implementation';
    sbSSE41: Result := 'x86-64 SSE4.1 SIMD implementation';
    sbSSE42: Result := 'x86-64 SSE4.2 SIMD implementation';
    sbAVX2: Result := 'x86-64 AVX2 SIMD implementation';
    sbAVX512: Result := 'x86-64 AVX-512 SIMD implementation';
    sbNEON: Result := 'ARM NEON 128-bit SIMD';
    sbRISCVV: Result := 'RISC-V Vector Extension (RVV)';
  end;
end;

function SimdCapabilitiesToAbiBits(const aCaps: TSimdCapabilities): UInt64;
var
  LCap: TSimdCapability;
begin
  Result := 0;
  for LCap := Low(TSimdCapability) to High(TSimdCapability) do
    if LCap in aCaps then
      Result := Result or (UInt64(1) shl Ord(LCap));
end;

function BuildSimdBackendAbiFlagsFromSnapshot(const aBackend: TSimdBackend;
  const aRegistered, aDispatchable, aActive: Boolean): TNextPasSimdAbiFlags;
begin
  Result := 0;
  if IsBackendAvailableOnCPU(aBackend) then
    Result := Result or FAF_SIMD_ABI_FLAG_SUPPORTED_ON_CPU;
  if aRegistered then
    Result := Result or FAF_SIMD_ABI_FLAG_REGISTERED;
  if aDispatchable then
    Result := Result or FAF_SIMD_ABI_FLAG_DISPATCHABLE;
  if aActive then
    Result := Result or FAF_SIMD_ABI_FLAG_ACTIVE;
  if aBackend = sbRISCVV then
    Result := Result or FAF_SIMD_ABI_FLAG_EXPERIMENTAL;
end;

function TryAbiBackendId(aBackendId: UInt32; out aBackend: TSimdBackend): Boolean; inline;
begin
  Result := aBackendId <= UInt32(Ord(High(TSimdBackend)));
  if Result then
    aBackend := TSimdBackend(aBackendId)
  else
    aBackend := sbScalar;
end;

function GetCurrentSimdPublicApiBindingState: PSimdPublicApiBindingState; inline;
begin
  Result := PSimdPublicApiBindingState(atomic_load(g_SimdPublicApiStatePtr, mo_acquire));
end;

procedure RebindSimdPublicApi; forward;

function GetLiveSimdPublicApiBindingState: PSimdPublicApiBindingState; inline;
var
  LCurrent: PSimdPublicApiBindingState;
  LTargetDataPlane: PSimdDataPlane;
begin
  LCurrent := GetCurrentSimdPublicApiBindingState;
  LTargetDataPlane := GetCurrentSimdDataPlane;
  if LTargetDataPlane = nil then
    Exit(LCurrent);
  if (LCurrent = nil) or
     (LCurrent^.DataPlane <> LTargetDataPlane) then
  begin
    RebindSimdPublicApi;
    Result := GetCurrentSimdPublicApiBindingState;
    if (Result = nil) and (LCurrent <> nil) then
      Result := LCurrent;
    Exit;
  end;
  Result := LCurrent;
end;

function CreateSimdPublicApiBindingState: PSimdPublicApiBindingState;
begin
  New(Result);
  FillChar(Result^, SizeOf(Result^), 0);
  Result^.NextOwned := g_SimdPublicApiOwnedHead;
  g_SimdPublicApiOwnedHead := Result;
end;

function FindOwnedSimdPublicApiBindingState(
  aDataPlane: PSimdDataPlane): PSimdPublicApiBindingState;
begin
  Result := g_SimdPublicApiOwnedHead;
  while Result <> nil do
  begin
    if Result^.DataPlane = aDataPlane then
      Exit;
    Result := Result^.NextOwned;
  end;
end;

procedure InitializeSimdPublicApiBinding;
begin
  InitCriticalSection(g_SimdPublicApiRebindLock);
end;

procedure FinalizeSimdPublicApiBinding;
var
  LState: PSimdPublicApiBindingState;
  LNext: PSimdPublicApiBindingState;
begin
  EnterCriticalSection(g_SimdPublicApiRebindLock);
  try
    atomic_store(g_SimdPublicApiStatePtr, nil, mo_release);
    LState := g_SimdPublicApiOwnedHead;
    g_SimdPublicApiOwnedHead := nil;
  finally
    LeaveCriticalSection(g_SimdPublicApiRebindLock);
  end;

  while LState <> nil do
  begin
    LNext := LState^.NextOwned;
    Dispose(LState);
    LState := LNext;
  end;

  DoneCriticalSection(g_SimdPublicApiRebindLock);
end;

function GetSimdPublicApiFallbackDataPlane(
  aState: PSimdPublicApiBindingState): PSimdDataPlane; inline;
begin
  if (aState <> nil) and (aState^.DataPlane <> nil) then
    Exit(aState^.DataPlane);
  Result := GetCurrentSimdDataPlane;
end;

function PublicAbiMemEqual(aA, aB: Pointer; aLen: SizeUInt): LongBool; cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.MemEqualBound) then
    Result := LState^.MemEqualBound(aA, aB, aLen)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      Result := TSimdPublicMemEqualFunc(LDataPlane^.MemEqualPtr)(aA, aB, aLen)
    else
      Result := False;
  end;
end;

function PublicAbiMemFindByte(aP: Pointer; aLen: SizeUInt; aValue: Byte): PtrInt; cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.MemFindByteBound) then
    Result := LState^.MemFindByteBound(aP, aLen, aValue)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      Result := TSimdPublicMemFindByteFunc(LDataPlane^.MemFindBytePtr)(aP, aLen, aValue)
    else
      Result := -1;
  end;
end;

function PublicAbiMemDiffRange(aA, aB: Pointer; aLen: SizeUInt;
  out aFirstDiff, aLastDiff: SizeUInt): LongBool; cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.MemDiffRangeBound) then
    Result := LState^.MemDiffRangeBound(aA, aB, aLen, aFirstDiff, aLastDiff)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      Result := TSimdPublicMemDiffRangeFunc(LDataPlane^.MemDiffRangePtr)(
        aA, aB, aLen, aFirstDiff, aLastDiff)
    else
    begin
      aFirstDiff := 0;
      aLastDiff := 0;
      Result := False;
    end;
  end;
end;

function PublicAbiSumBytes(aP: Pointer; aLen: SizeUInt): UInt64; cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.SumBytesBound) then
    Result := LState^.SumBytesBound(aP, aLen)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      Result := TSimdPublicSumBytesFunc(LDataPlane^.SumBytesPtr)(aP, aLen)
    else
      Result := 0;
  end;
end;

function PublicAbiCountByte(aP: Pointer; aLen: SizeUInt; aValue: Byte): SizeUInt; cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.CountByteBound) then
    Result := LState^.CountByteBound(aP, aLen, aValue)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      Result := TSimdPublicCountByteFunc(LDataPlane^.CountBytePtr)(aP, aLen, aValue)
    else
      Result := 0;
  end;
end;

function PublicAbiBitsetPopCount(aP: Pointer; aByteLen: SizeUInt): SizeUInt; cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.BitsetPopCountBound) then
    Result := LState^.BitsetPopCountBound(aP, aByteLen)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      Result := TSimdPublicBitsetPopCountFunc(LDataPlane^.BitsetPopCountPtr)(aP, aByteLen)
    else
      Result := 0;
  end;
end;

function PublicAbiUtf8Validate(aP: Pointer; aLen: SizeUInt): LongBool; cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.Utf8ValidateBound) then
    Result := LState^.Utf8ValidateBound(aP, aLen)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      Result := TSimdPublicUtf8ValidateFunc(LDataPlane^.Utf8ValidatePtr)(aP, aLen)
    else
      Result := False;
  end;
end;

function PublicAbiAsciiIEqual(aA, aB: Pointer; aLen: SizeUInt): LongBool; cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.AsciiIEqualBound) then
    Result := LState^.AsciiIEqualBound(aA, aB, aLen)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      Result := TSimdPublicAsciiIEqualFunc(LDataPlane^.AsciiIEqualPtr)(aA, aB, aLen)
    else
      Result := False;
  end;
end;

function PublicAbiBytesIndexOf(aHaystack: Pointer; aHaystackLen: SizeUInt;
  aNeedle: Pointer; aNeedleLen: SizeUInt): PtrInt; cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.BytesIndexOfBound) then
    Result := LState^.BytesIndexOfBound(aHaystack, aHaystackLen, aNeedle, aNeedleLen)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      Result := TSimdPublicBytesIndexOfFunc(LDataPlane^.BytesIndexOfPtr)(
        aHaystack, aHaystackLen, aNeedle, aNeedleLen)
    else
      Result := -1;
  end;
end;

procedure PublicAbiMemCopy(aSrc, aDst: Pointer; aLen: SizeUInt); cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.MemCopyBound) then
    LState^.MemCopyBound(aSrc, aDst, aLen)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      TSimdPublicMemCopyFunc(LDataPlane^.MemCopyPtr)(aSrc, aDst, aLen);
  end;
end;

procedure PublicAbiMemSet(aDst: Pointer; aLen: SizeUInt; aValue: Byte); cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.MemSetBound) then
    LState^.MemSetBound(aDst, aLen, aValue)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      TSimdPublicMemSetFunc(LDataPlane^.MemSetPtr)(aDst, aLen, aValue);
  end;
end;

procedure PublicAbiToLowerAscii(aP: Pointer; aLen: SizeUInt); cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.ToLowerAsciiBound) then
    LState^.ToLowerAsciiBound(aP, aLen)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      TSimdPublicAsciiCaseFunc(LDataPlane^.ToLowerAsciiPtr)(aP, aLen);
  end;
end;

procedure PublicAbiToUpperAscii(aP: Pointer; aLen: SizeUInt); cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.ToUpperAsciiBound) then
    LState^.ToUpperAsciiBound(aP, aLen)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      TSimdPublicAsciiCaseFunc(LDataPlane^.ToUpperAsciiPtr)(aP, aLen);
  end;
end;

procedure PublicAbiMemReverse(aP: Pointer; aLen: SizeUInt); cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.MemReverseBound) then
    LState^.MemReverseBound(aP, aLen)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      TSimdPublicMemReverseFunc(LDataPlane^.MemReversePtr)(aP, aLen);
  end;
end;

procedure PublicAbiMinMaxBytes(aP: Pointer; aLen: SizeUInt; out aMinVal, aMaxVal: Byte); cdecl;
var
  LState: PSimdPublicApiBindingState;
  LDataPlane: PSimdDataPlane;
begin
  LState := GetLiveSimdPublicApiBindingState;
  if (LState <> nil) and Assigned(LState^.MinMaxBytesBound) then
    LState^.MinMaxBytesBound(aP, aLen, aMinVal, aMaxVal)
  else
  begin
    LDataPlane := GetSimdPublicApiFallbackDataPlane(LState);
    if LDataPlane <> nil then
      TSimdPublicMinMaxBytesFunc(LDataPlane^.MinMaxBytesPtr)(aP, aLen, aMinVal, aMaxVal)
    else
    begin
      aMinVal := 0;
      aMaxVal := 0;
    end;
  end;
end;

procedure RebindSimdPublicApi;
var
  LDataPlane: PSimdDataPlane;
  LDispatch: PSimdDispatchTable;
  LCurrent: PSimdPublicApiBindingState;
  LState: PSimdPublicApiBindingState;
begin
  EnterCriticalSection(g_SimdPublicApiRebindLock);
  try
    LDataPlane := GetCurrentSimdDataPlane;
    if LDataPlane = nil then
      Exit;
    LDispatch := LDataPlane^.Dispatch;
    if LDispatch = nil then
      Exit;

    LCurrent := GetCurrentSimdPublicApiBindingState;
    if (LCurrent <> nil) and (LCurrent^.DataPlane = LDataPlane) then
      Exit;

    LState := FindOwnedSimdPublicApiBindingState(LDataPlane);
    if LState = nil then
      LState := CreateSimdPublicApiBindingState;

    if LState^.DataPlane <> LDataPlane then
    begin
      Inc(g_SimdPublicApiSnapshotGeneration);
      LState^.SnapshotGeneration := g_SimdPublicApiSnapshotGeneration;
      LState^.SnapshotFlags := FAF_SIMD_PUBLIC_API_V2_FLAG_SNAPSHOT_BOUND or
        FAF_SIMD_PUBLIC_API_V2_FLAG_COMPAT_V1;
    end;

    LState^.DataPlane := LDataPlane;
    LState^.Api.StructSize := SizeOf(LState^.Api);
    LState^.Dispatch := LDispatch;
    LState^.Api.AbiVersionMajor := NEXTPAS_SIMD_PUBLIC_ABI_VERSION_MAJOR;
    LState^.Api.AbiVersionMinor := NEXTPAS_SIMD_PUBLIC_ABI_VERSION_MINOR;
    LState^.Api.AbiSignatureHi := NEXTPAS_SIMD_PUBLIC_ABI_SIGNATURE_HI;
    LState^.Api.AbiSignatureLo := NEXTPAS_SIMD_PUBLIC_ABI_SIGNATURE_LO;
    LState^.Api.ActiveBackendId := UInt32(Ord(LDataPlane^.ActiveBackend));
    LState^.Api.ActiveFlags := BuildSimdBackendAbiFlagsFromSnapshot(
      LDataPlane^.ActiveBackend, True, LDataPlane^.ActiveDispatchable, True);
    LState^.MemEqualBound := TSimdPublicMemEqualFunc(LDataPlane^.MemEqualPtr);
    LState^.MemFindByteBound := TSimdPublicMemFindByteFunc(LDataPlane^.MemFindBytePtr);
    LState^.MemDiffRangeBound := TSimdPublicMemDiffRangeFunc(LDataPlane^.MemDiffRangePtr);
    LState^.SumBytesBound := TSimdPublicSumBytesFunc(LDataPlane^.SumBytesPtr);
    LState^.CountByteBound := TSimdPublicCountByteFunc(LDataPlane^.CountBytePtr);
    LState^.BitsetPopCountBound := TSimdPublicBitsetPopCountFunc(LDataPlane^.BitsetPopCountPtr);
    LState^.Utf8ValidateBound := TSimdPublicUtf8ValidateFunc(LDataPlane^.Utf8ValidatePtr);
    LState^.AsciiIEqualBound := TSimdPublicAsciiIEqualFunc(LDataPlane^.AsciiIEqualPtr);
    LState^.BytesIndexOfBound := TSimdPublicBytesIndexOfFunc(LDataPlane^.BytesIndexOfPtr);
    LState^.MemCopyBound := TSimdPublicMemCopyFunc(LDataPlane^.MemCopyPtr);
    LState^.MemSetBound := TSimdPublicMemSetFunc(LDataPlane^.MemSetPtr);
    LState^.ToLowerAsciiBound := TSimdPublicAsciiCaseFunc(LDataPlane^.ToLowerAsciiPtr);
    LState^.ToUpperAsciiBound := TSimdPublicAsciiCaseFunc(LDataPlane^.ToUpperAsciiPtr);
    LState^.MemReverseBound := TSimdPublicMemReverseFunc(LDataPlane^.MemReversePtr);
    LState^.MinMaxBytesBound := TSimdPublicMinMaxBytesFunc(LDataPlane^.MinMaxBytesPtr);
    LState^.Api.MemEqual := @PublicAbiMemEqual;
    LState^.Api.MemFindByte := @PublicAbiMemFindByte;
    LState^.Api.MemDiffRange := @PublicAbiMemDiffRange;
    LState^.Api.SumBytes := @PublicAbiSumBytes;
    LState^.Api.CountByte := @PublicAbiCountByte;
    LState^.Api.BitsetPopCount := @PublicAbiBitsetPopCount;
    LState^.Api.Utf8Validate := @PublicAbiUtf8Validate;
    LState^.Api.AsciiIEqual := @PublicAbiAsciiIEqual;
    LState^.Api.BytesIndexOf := @PublicAbiBytesIndexOf;
    LState^.Api.MemCopy := @PublicAbiMemCopy;
    LState^.Api.MemSet := @PublicAbiMemSet;
    LState^.Api.ToLowerAscii := @PublicAbiToLowerAscii;
    LState^.Api.ToUpperAscii := @PublicAbiToUpperAscii;
    LState^.Api.MemReverse := @PublicAbiMemReverse;
    LState^.Api.MinMaxBytes := @PublicAbiMinMaxBytes;
    LState^.ApiV2.StructSize := SizeOf(LState^.ApiV2);
    LState^.ApiV2.AbiVersionMajor := NEXTPAS_SIMD_PUBLIC_ABI_V2_VERSION_MAJOR;
    LState^.ApiV2.AbiVersionMinor := NEXTPAS_SIMD_PUBLIC_ABI_V2_VERSION_MINOR;
    LState^.ApiV2.AbiSignatureHi := NEXTPAS_SIMD_PUBLIC_ABI_V2_SIGNATURE_HI;
    LState^.ApiV2.AbiSignatureLo := NEXTPAS_SIMD_PUBLIC_ABI_V2_SIGNATURE_LO;
    LState^.ApiV2.ActiveBackendId := LState^.Api.ActiveBackendId;
    LState^.ApiV2.ActiveFlags := LState^.Api.ActiveFlags;
    LState^.ApiV2.SnapshotGeneration := LState^.SnapshotGeneration;
    LState^.ApiV2.SnapshotFlags := LState^.SnapshotFlags;
    LState^.ApiV2.Reserved0 := 0;
    LState^.ApiV2.MemEqual := @PublicAbiMemEqual;
    LState^.ApiV2.MemFindByte := @PublicAbiMemFindByte;
    LState^.ApiV2.MemDiffRange := @PublicAbiMemDiffRange;
    LState^.ApiV2.SumBytes := @PublicAbiSumBytes;
    LState^.ApiV2.CountByte := @PublicAbiCountByte;
    LState^.ApiV2.BitsetPopCount := @PublicAbiBitsetPopCount;
    LState^.ApiV2.Utf8Validate := @PublicAbiUtf8Validate;
    LState^.ApiV2.AsciiIEqual := @PublicAbiAsciiIEqual;
    LState^.ApiV2.BytesIndexOf := @PublicAbiBytesIndexOf;
    LState^.ApiV2.MemCopy := @PublicAbiMemCopy;
    LState^.ApiV2.MemSet := @PublicAbiMemSet;
    LState^.ApiV2.ToLowerAscii := @PublicAbiToLowerAscii;
    LState^.ApiV2.ToUpperAscii := @PublicAbiToUpperAscii;
    LState^.ApiV2.MemReverse := @PublicAbiMemReverse;
    LState^.ApiV2.MinMaxBytes := @PublicAbiMinMaxBytes;

    atomic_store(g_SimdPublicApiStatePtr, Pointer(LState), mo_release);
  finally
    LeaveCriticalSection(g_SimdPublicApiRebindLock);
  end;
end;

function GetSimdAbiVersionMajor: UInt16; cdecl;
begin
  Result := NEXTPAS_SIMD_PUBLIC_ABI_VERSION_MAJOR;
end;

function GetSimdAbiVersionMinor: UInt16; cdecl;
begin
  Result := NEXTPAS_SIMD_PUBLIC_ABI_VERSION_MINOR;
end;

procedure GetSimdAbiSignature(out aHi, aLo: UInt64); cdecl;
begin
  aHi := NEXTPAS_SIMD_PUBLIC_ABI_SIGNATURE_HI;
  aLo := NEXTPAS_SIMD_PUBLIC_ABI_SIGNATURE_LO;
end;

function TryGetSimdBackendPodInfo(aBackend: TSimdBackend; out aInfo: TNextPasSimdBackendPodInfo): Boolean; cdecl;
var
  LDispatchTable: TSimdDispatchTable;
  LCurrentDispatch: PSimdDispatchTable;
  LRegistered: Boolean;
  LDispatchable: Boolean;
  LActive: Boolean;

  procedure FillPodInfoFromDispatch(const aDispatch: PSimdDispatchTable; var aPodInfo: TNextPasSimdBackendPodInfo; out aIsDispatchable: Boolean);
  begin
    aPodInfo.CapabilityBits := SimdCapabilitiesToAbiBits(aDispatch^.BackendInfo.Capabilities);
    aIsDispatchable := aDispatch^.BackendInfo.Available and IsBackendAvailableOnCPU(aDispatch^.Backend);
    aPodInfo.Priority := aDispatch^.BackendInfo.Priority;
  end;
begin
  aInfo := Default(TNextPasSimdBackendPodInfo);
  aInfo.StructSize := SizeOf(aInfo);
  aInfo.BackendId := UInt32(Ord(aBackend));

  LCurrentDispatch := GetCurrentSimdDataPlaneDispatch;
  LActive := (LCurrentDispatch <> nil) and (LCurrentDispatch^.Backend = aBackend);

  if LActive then
  begin
    FillPodInfoFromDispatch(LCurrentDispatch, aInfo, LDispatchable);
    LRegistered := True;
  end
  else
  begin
    LRegistered := TryGetRegisteredBackendDispatchTable(aBackend, LDispatchTable);
    if LRegistered then
    begin
      FillPodInfoFromDispatch(@LDispatchTable, aInfo, LDispatchable);
    end
    else
    begin
      aInfo.CapabilityBits := 0;
      LDispatchable := False;
      aInfo.Priority := GetBackendInfo(aBackend).Priority;
    end;
  end;

  aInfo.Flags := BuildSimdBackendAbiFlagsFromSnapshot(aBackend, LRegistered, LDispatchable, LActive);
  Result := True;
end;

function GetSimdBackendNamePtr(aBackend: TSimdBackend): PAnsiChar; cdecl;
begin
  Result := GetBackendNameTextPtr(aBackend);
end;

function GetSimdBackendDescriptionPtr(aBackend: TSimdBackend): PAnsiChar; cdecl;
begin
  Result := GetBackendDescriptionTextPtr(aBackend);
end;

function GetSimdPublicApi: PNextPasSimdPublicApi; cdecl;
var
  LState: PSimdPublicApiBindingState;
begin
  LState := GetLiveSimdPublicApiBindingState;

  if LState = nil then
    Exit(nil);

  Result := @LState^.Api;
end;

function GetSimdPublicApiV2: PNextPasSimdPublicApiV2; cdecl;
var
  LState: PSimdPublicApiBindingState;
begin
  LState := GetLiveSimdPublicApiBindingState;

  if LState = nil then
    Exit(nil);

  Result := @LState^.ApiV2;
end;

function nextpas_simd_abi_version_major: UInt16; cdecl;
begin
  Result := GetSimdAbiVersionMajor;
end;

function nextpas_simd_abi_version_minor: UInt16; cdecl;
begin
  Result := GetSimdAbiVersionMinor;
end;

procedure nextpas_simd_abi_signature(out aHi, aLo: UInt64); cdecl;
begin
  GetSimdAbiSignature(aHi, aLo);
end;

function nextpas_simd_get_backend_pod_info(aBackendId: UInt32; out aInfo: TNextPasSimdBackendPodInfo): LongBool; cdecl;
var
  LBackend: TSimdBackend;
begin
  if not TryAbiBackendId(aBackendId, LBackend) then
  begin
    aInfo := Default(TNextPasSimdBackendPodInfo);
    Exit(False);
  end;
  Result := TryGetSimdBackendPodInfo(LBackend, aInfo);
end;

function nextpas_simd_backend_name(aBackendId: UInt32): PAnsiChar; cdecl;
var
  LBackend: TSimdBackend;
begin
  if not TryAbiBackendId(aBackendId, LBackend) then
    Exit(nil);
  Result := GetSimdBackendNamePtr(LBackend);
end;

function nextpas_simd_backend_description(aBackendId: UInt32): PAnsiChar; cdecl;
var
  LBackend: TSimdBackend;
begin
  if not TryAbiBackendId(aBackendId, LBackend) then
    Exit(nil);
  Result := GetSimdBackendDescriptionPtr(LBackend);
end;

function nextpas_simd_get_public_api: PNextPasSimdPublicApi; cdecl;
begin
  Result := GetSimdPublicApi;
end;

function nextpas_simd_get_public_api_v2: PNextPasSimdPublicApiV2; cdecl;
begin
  Result := GetSimdPublicApiV2;
end;
