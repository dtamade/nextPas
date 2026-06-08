unit nextpas.core.platform.memory;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformAlignedAllocBackend = (
    paabFallback,
    paabWindowsCRT,
    paabPosix
  );

function platform_aligned_alloc(ASize, AAlignment: SizeUInt): Pointer;
function platform_aligned_realloc(APtr: Pointer; ANewSize, AAlignment: SizeUInt): Pointer;
procedure platform_aligned_free(APtr: Pointer);
function platform_aligned_alloc_backend: TPlatformAlignedAllocBackend;
function platform_aligned_alloc_is_native: Boolean;
procedure platform_secure_zero_memory(APtr: Pointer; ASize: SizeUInt);

implementation

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.ffi;
{$ELSEIF defined(NEXTPAS_UNIX)}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;
{$ENDIF}

const
  PLATFORM_ALIGNED_ALLOC_MAGIC = UInt32($4E50414D);

type
  PPlatformAlignedAllocHeader = ^TPlatformAlignedAllocHeader;
  TPlatformAlignedAllocHeader = record
    RawPtr: Pointer;
    Size: SizeUInt;
    Alignment: SizeUInt;
    Magic: UInt32;
  end;

function IsPowerOfTwo(AValue: SizeUInt): Boolean; inline;
begin
  Result := (AValue <> 0) and ((AValue and (AValue - 1)) = 0);
end;

function IsValidAlignment(AAlignment: SizeUInt): Boolean; inline;
begin
  Result := (AAlignment >= SizeOf(Pointer)) and IsPowerOfTwo(AAlignment);
end;

function TryAddSizeUInt(ALeft, ARight: SizeUInt; out ASum: SizeUInt): Boolean; inline;
begin
  if ALeft > High(SizeUInt) - ARight then
  begin
    ASum := 0;
    Exit(False);
  end;
  ASum := ALeft + ARight;
  Result := True;
end;

function TryBuildRawSize(ASize, AAlignment: SizeUInt; out ARawSize: SizeUInt): Boolean;
var
  LPadding: SizeUInt;
begin
  LPadding := AAlignment - 1;
  if not TryAddSizeUInt(ASize, LPadding, ARawSize) then
    Exit(False);
  Result := TryAddSizeUInt(ARawSize, SizeOf(TPlatformAlignedAllocHeader), ARawSize);
end;

function AlignPtr(APtr: Pointer; AAlignment: SizeUInt): Pointer; inline;
var
  LAddr: PtrUInt;
begin
  LAddr := PtrUInt(APtr);
  Result := Pointer((LAddr + PtrUInt(AAlignment - 1)) and not PtrUInt(AAlignment - 1));
end;

function HeaderOf(APtr: Pointer): PPlatformAlignedAllocHeader; inline;
begin
  Result := PPlatformAlignedAllocHeader(PtrUInt(APtr) - SizeOf(TPlatformAlignedAllocHeader));
end;

function platform_aligned_alloc_backend: TPlatformAlignedAllocBackend;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := paabWindowsCRT;
{$ELSEIF defined(NEXTPAS_UNIX)}
  Result := paabPosix;
{$ELSE}
  Result := paabFallback;
{$ENDIF}
end;

function platform_aligned_alloc_is_native: Boolean;
begin
  Result := platform_aligned_alloc_backend <> paabFallback;
end;

procedure platform_secure_zero_memory_barrier; noinline;
begin
  ReadWriteBarrier;
end;

procedure platform_secure_zero_memory(APtr: Pointer; ASize: SizeUInt);
begin
  if (APtr = nil) or (ASize = 0) then
    Exit;

  FillChar(APtr^, ASize, 0);
  platform_secure_zero_memory_barrier;
end;

function platform_fallback_aligned_raw_alloc(ARawSize: SizeUInt): Pointer;
begin
  Result := SysGetMem(ARawSize);
end;

procedure platform_fallback_aligned_raw_free(APtr: Pointer);
begin
  SysFreeMem(APtr);
end;

function platform_native_aligned_raw_alloc(ARawSize, AAlignment: SizeUInt): Pointer;
{$IF defined(NEXTPAS_UNIX)}
var
  LRaw: Pointer;
{$ENDIF}
begin
  Result := nil;
{$IFDEF NEXTPAS_WINDOWS}
  Result := nextpas.core.platform.windows.ffi._aligned_malloc(ARawSize, AAlignment);
{$ELSEIF defined(NEXTPAS_UNIX)}
  LRaw := nil;
  if nextpas.core.platform.posix.ffi.posix_memalign(@LRaw, size_t(AAlignment), size_t(ARawSize)) = 0 then
    Result := LRaw;
{$ELSE}
  Result := platform_fallback_aligned_raw_alloc(ARawSize);
{$ENDIF}
end;

procedure platform_native_aligned_raw_free(APtr: Pointer);
begin
  if APtr = nil then
    Exit;
{$IFDEF NEXTPAS_WINDOWS}
  nextpas.core.platform.windows.ffi._aligned_free(APtr);
{$ELSEIF defined(NEXTPAS_UNIX)}
  nextpas.core.platform.posix.ffi.free(APtr);
{$ELSE}
  platform_fallback_aligned_raw_free(APtr);
{$ENDIF}
end;

function platform_aligned_raw_alloc(ARawSize, AAlignment: SizeUInt): Pointer;
begin
  if platform_aligned_alloc_is_native then
    Result := platform_native_aligned_raw_alloc(ARawSize, AAlignment)
  else
    Result := platform_fallback_aligned_raw_alloc(ARawSize);
end;

procedure platform_aligned_raw_free(APtr: Pointer);
begin
  if platform_aligned_alloc_is_native then
    platform_native_aligned_raw_free(APtr)
  else
    platform_fallback_aligned_raw_free(APtr);
end;

function platform_aligned_alloc(ASize, AAlignment: SizeUInt): Pointer;
var
  LRawSize: SizeUInt;
  LRaw: Pointer;
  LAligned: Pointer;
  LHeader: PPlatformAlignedAllocHeader;
begin
  Result := nil;
  if ASize = 0 then
    Exit;
  if not IsValidAlignment(AAlignment) then
    Exit;
  if not TryBuildRawSize(ASize, AAlignment, LRawSize) then
    Exit;

  LRaw := platform_aligned_raw_alloc(LRawSize, AAlignment);
  if LRaw = nil then
    Exit;

  LAligned := AlignPtr(Pointer(PtrUInt(LRaw) + SizeOf(TPlatformAlignedAllocHeader)), AAlignment);
  LHeader := HeaderOf(LAligned);
  LHeader^.RawPtr := LRaw;
  LHeader^.Size := ASize;
  LHeader^.Alignment := AAlignment;
  LHeader^.Magic := PLATFORM_ALIGNED_ALLOC_MAGIC;
  Result := LAligned;
end;

procedure platform_aligned_free(APtr: Pointer);
var
  LHeader: PPlatformAlignedAllocHeader;
begin
  if APtr = nil then
    Exit;

  LHeader := HeaderOf(APtr);
  if LHeader^.Magic <> PLATFORM_ALIGNED_ALLOC_MAGIC then
    Exit;
  platform_aligned_raw_free(LHeader^.RawPtr);
end;

function platform_aligned_realloc(APtr: Pointer; ANewSize, AAlignment: SizeUInt): Pointer;
var
  LHeader: PPlatformAlignedAllocHeader;
  LOldSize: SizeUInt;
begin
  if APtr = nil then
    Exit(platform_aligned_alloc(ANewSize, AAlignment));
  if ANewSize = 0 then
  begin
    platform_aligned_free(APtr);
    Exit(nil);
  end;
  if not IsValidAlignment(AAlignment) then
    Exit(nil);

  LHeader := HeaderOf(APtr);
  if LHeader^.Magic <> PLATFORM_ALIGNED_ALLOC_MAGIC then
    Exit(nil);
  LOldSize := LHeader^.Size;

  Result := platform_aligned_alloc(ANewSize, AAlignment);
  if Result = nil then
    Exit;

  if LOldSize < ANewSize then
    Move(APtr^, Result^, LOldSize)
  else
    Move(APtr^, Result^, ANewSize);
  platform_aligned_free(APtr);
end;

end.
