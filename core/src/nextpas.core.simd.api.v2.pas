unit nextpas.core.simd.api.v2;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.simd;

function GetBoundPublicApiV2: PNextPasSimdPublicApiV2; inline;
function GetSnapshotGeneration: UInt64; inline;
function GetSnapshotFlags: TNextPasSimdPublicApiV2Flags; inline;
function SupportsDirectDataPlane: Boolean; inline;

function MemEqual(aA, aB: Pointer; aLen: SizeUInt): LongBool; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
function MemFindByte(aP: Pointer; aLen: SizeUInt; aValue: Byte): PtrInt; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
function MemDiffRange(aA, aB: Pointer; aLen: SizeUInt; out aFirstDiff, aLastDiff: SizeUInt): Boolean; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
procedure MemCopy(aSrc, aDst: Pointer; aLen: SizeUInt); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
procedure MemSet(aDst: Pointer; aLen: SizeUInt; aValue: Byte); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
procedure MemReverse(aP: Pointer; aLen: SizeUInt); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
function SumBytes(aP: Pointer; aLen: SizeUInt): UInt64; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
procedure MinMaxBytes(aP: Pointer; aLen: SizeUInt; out aMinVal, aMaxVal: Byte); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
function CountByte(aP: Pointer; aLen: SizeUInt; aValue: Byte): SizeUInt; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
function Utf8Validate(aP: Pointer; aLen: SizeUInt): Boolean; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
function AsciiIEqual(aA, aB: Pointer; aLen: SizeUInt): Boolean; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
procedure ToLowerAscii(aP: Pointer; aLen: SizeUInt); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
procedure ToUpperAscii(aP: Pointer; aLen: SizeUInt); {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
function BytesIndexOf(aHaystack: Pointer; aHaystackLen: SizeUInt; aNeedle: Pointer; aNeedleLen: SizeUInt): PtrInt; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}
function BitsetPopCount(aP: Pointer; aByteLen: SizeUInt): SizeUInt; {$IFDEF SIMD_AGGRESSIVE_INLINE}inline;{$ENDIF}

implementation

function RequireBoundApiV2: PNextPasSimdPublicApiV2; inline;
begin
  Result := GetSimdPublicApiV2;
  if Result = nil then
    raise Exception.Create('SIMD public API v2 snapshot is unavailable');
end;

function GetBoundPublicApiV2: PNextPasSimdPublicApiV2; inline;
begin
  Result := GetSimdPublicApiV2;
end;

function GetSnapshotGeneration: UInt64; inline;
var
  LApi: PNextPasSimdPublicApiV2;
begin
  LApi := GetBoundPublicApiV2;
  if LApi = nil then
    Exit(0);
  Result := LApi^.SnapshotGeneration;
end;

function GetSnapshotFlags: TNextPasSimdPublicApiV2Flags; inline;
var
  LApi: PNextPasSimdPublicApiV2;
begin
  LApi := GetBoundPublicApiV2;
  if LApi = nil then
    Exit(0);
  Result := LApi^.SnapshotFlags;
end;

function SupportsDirectDataPlane: Boolean; inline;
begin
  Result := (GetSnapshotFlags and FAF_SIMD_PUBLIC_API_V2_FLAG_DIRECT_DATA_PLANE) <> 0;
end;

function MemEqual(aA, aB: Pointer; aLen: SizeUInt): LongBool;
begin
  Result := RequireBoundApiV2^.MemEqual(aA, aB, aLen);
end;

function MemFindByte(aP: Pointer; aLen: SizeUInt; aValue: Byte): PtrInt;
begin
  Result := RequireBoundApiV2^.MemFindByte(aP, aLen, aValue);
end;

function MemDiffRange(aA, aB: Pointer; aLen: SizeUInt; out aFirstDiff, aLastDiff: SizeUInt): Boolean;
begin
  Result := RequireBoundApiV2^.MemDiffRange(aA, aB, aLen, aFirstDiff, aLastDiff);
end;

procedure MemCopy(aSrc, aDst: Pointer; aLen: SizeUInt);
begin
  RequireBoundApiV2^.MemCopy(aSrc, aDst, aLen);
end;

procedure MemSet(aDst: Pointer; aLen: SizeUInt; aValue: Byte);
begin
  RequireBoundApiV2^.MemSet(aDst, aLen, aValue);
end;

procedure MemReverse(aP: Pointer; aLen: SizeUInt);
begin
  RequireBoundApiV2^.MemReverse(aP, aLen);
end;

function SumBytes(aP: Pointer; aLen: SizeUInt): UInt64;
begin
  Result := RequireBoundApiV2^.SumBytes(aP, aLen);
end;

procedure MinMaxBytes(aP: Pointer; aLen: SizeUInt; out aMinVal, aMaxVal: Byte);
begin
  RequireBoundApiV2^.MinMaxBytes(aP, aLen, aMinVal, aMaxVal);
end;

function CountByte(aP: Pointer; aLen: SizeUInt; aValue: Byte): SizeUInt;
begin
  Result := RequireBoundApiV2^.CountByte(aP, aLen, aValue);
end;

function Utf8Validate(aP: Pointer; aLen: SizeUInt): Boolean;
begin
  Result := RequireBoundApiV2^.Utf8Validate(aP, aLen);
end;

function AsciiIEqual(aA, aB: Pointer; aLen: SizeUInt): Boolean;
begin
  Result := RequireBoundApiV2^.AsciiIEqual(aA, aB, aLen);
end;

procedure ToLowerAscii(aP: Pointer; aLen: SizeUInt);
begin
  RequireBoundApiV2^.ToLowerAscii(aP, aLen);
end;

procedure ToUpperAscii(aP: Pointer; aLen: SizeUInt);
begin
  RequireBoundApiV2^.ToUpperAscii(aP, aLen);
end;

function BytesIndexOf(aHaystack: Pointer; aHaystackLen: SizeUInt; aNeedle: Pointer; aNeedleLen: SizeUInt): PtrInt;
begin
  Result := RequireBoundApiV2^.BytesIndexOf(aHaystack, aHaystackLen, aNeedle, aNeedleLen);
end;

function BitsetPopCount(aP: Pointer; aByteLen: SizeUInt): SizeUInt;
begin
  Result := RequireBoundApiV2^.BitsetPopCount(aP, aByteLen);
end;

end.
