unit nextpas.core.platform.memory;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformAlignedAllocBackend = (
    paabFallback,
    paabWindowsCRT,
    paabPosix
  );

  TPlatformSecureZeroBackend = (
    pszbFallbackFillCharBarrier,
    pszbWindowsNativeDeferred,
    pszbPosixExplicitBZero
  );

function platform_aligned_alloc(ASize, AAlignment: SizeUInt): Pointer;
function platform_aligned_realloc(APtr: Pointer; ANewSize, AAlignment: SizeUInt): Pointer;
procedure platform_aligned_free(APtr: Pointer);
function platform_aligned_alloc_backend: TPlatformAlignedAllocBackend;
function platform_aligned_alloc_is_native: Boolean;
function platform_secure_zero_memory_backend: TPlatformSecureZeroBackend;
function platform_secure_zero_memory_is_native: Boolean;
procedure platform_secure_zero_memory(APtr: Pointer; ASize: SizeUInt);

{**
 * @desc Reserve virtual address space without committing physical pages
 *
 * @params
 *   ASize  Size of the virtual address space to reserve (must be page-aligned)
 *
 * @return Base address of reserved region, or nil on failure
 *}
function platform_virtual_reserve(ASize: SizeUInt): Pointer;

{**
 * @desc Commit physical pages within a previously reserved region
 *
 * @params
 *   APtr   Base address within a reserved region (must be page-aligned)
 *   ASize  Size of the region to commit (must be page-aligned)
 *
 * @return True if pages were successfully committed
 *}
function platform_virtual_commit(APtr: Pointer; ASize: SizeUInt): Boolean;

{**
 * @desc Decommit physical pages while keeping virtual address space reserved
 *
 * @params
 *   APtr   Base address within a committed region (must be page-aligned)
 *   ASize  Size of the region to decommit (must be page-aligned)
 *}
procedure platform_virtual_decommit(APtr: Pointer; ASize: SizeUInt);

{**
 * @desc Release a reserved virtual address region (decommits + unreserves)
 *
 * @params
 *   APtr   Base address returned by platform_virtual_reserve
 *   ASize  Size of the reserved region
 *}
procedure platform_virtual_release(APtr: Pointer; ASize: SizeUInt);

{**
 * @desc Advise the kernel to use Transparent Huge Pages for a region
 *
 * @params
 *   APtr   Base address of the region (must be page-aligned)
 *   ASize  Size of the region (must be huge-page-aligned, typically 2MB)
 *}
procedure platform_madvise_thp(APtr: Pointer; ASize: SizeUInt);

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

function platform_secure_zero_memory_backend: TPlatformSecureZeroBackend;
begin
{$IFDEF NEXTPAS_UNIX}
  Result := pszbPosixExplicitBZero;
{$ELSE}
  Result := pszbFallbackFillCharBarrier;
{$ENDIF}
end;

function platform_secure_zero_memory_is_native: Boolean;
begin
  Result := platform_secure_zero_memory_backend = pszbPosixExplicitBZero;
end;

procedure platform_secure_zero_memory_barrier; noinline;
begin
  ReadWriteBarrier;
end;

{
  secure-zero-backend=fallback-fillchar-readwritebarrier
  windows-native-secure-zero=deferred
  posix-native-secure-zero=explicit_bzero
  native-secure-zero-promotion-requires=host-owned-ffi-or-dynamic-loading-seam
  secure-zero-forced-compile-truth=source-contract
  windows-runtime-ready=false
}
procedure platform_secure_zero_memory(APtr: Pointer; ASize: SizeUInt);
begin
  if (APtr = nil) or (ASize = 0) then
    Exit;

{$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi.explicit_bzero(APtr, size_t(ASize));
{$ELSE}
  FillChar(APtr^, ASize, 0);
  platform_secure_zero_memory_barrier;
{$ENDIF}
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

{ platform_virtual_reserve - reserve virtual address space without committing }

function platform_virtual_reserve(ASize: SizeUInt): Pointer;
begin
  Result := nil;
  if ASize = 0 then
    Exit;
{$IFDEF NEXTPAS_WINDOWS}
  Result := nextpas.core.platform.windows.ffi.VirtualAlloc(
    nil, PtrUInt(ASize), WINDOWS_MEM_RESERVE, WINDOWS_PAGE_READWRITE);
{$ELSEIF defined(NEXTPAS_UNIX)}
  Result := nextpas.core.platform.posix.ffi.mmap(
    nil, PtrUInt(ASize),
    PLATFORM_POSIX_PROT_NONE,
    PLATFORM_POSIX_MAP_PRIVATE or PLATFORM_POSIX_MAP_ANONYMOUS or PLATFORM_POSIX_MAP_NORESERVE,
    -1, 0);
  if Result = Pointer(PLATFORM_POSIX_MAP_FAILED) then
    Result := nil;
{$ENDIF}
end;

{ platform_virtual_commit - commit physical pages in a reserved region }

function platform_virtual_commit(APtr: Pointer; ASize: SizeUInt): Boolean;
begin
  Result := False;
  if (APtr = nil) or (ASize = 0) then
    Exit;
{$IFDEF NEXTPAS_WINDOWS}
  Result := nextpas.core.platform.windows.ffi.VirtualAlloc(
    APtr, PtrUInt(ASize), WINDOWS_MEM_COMMIT, WINDOWS_PAGE_READWRITE) <> nil;
{$ELSEIF defined(NEXTPAS_UNIX)}
  { MAP_FIXED overwrites the existing mapping; pages become accessible }
  Result := nextpas.core.platform.posix.ffi.mmap(
    APtr, PtrUInt(ASize),
    PLATFORM_POSIX_PROT_READ or PLATFORM_POSIX_PROT_WRITE,
    PLATFORM_POSIX_MAP_PRIVATE or PLATFORM_POSIX_MAP_ANONYMOUS or PLATFORM_POSIX_MAP_FIXED,
    -1, 0) <> Pointer(PLATFORM_POSIX_MAP_FAILED);
{$ENDIF}
end;

{ platform_virtual_decommit - release physical pages, keep virtual reservation }

procedure platform_virtual_decommit(APtr: Pointer; ASize: SizeUInt);
begin
  if (APtr = nil) or (ASize = 0) then
    Exit;
{$IFDEF NEXTPAS_WINDOWS}
  nextpas.core.platform.windows.ffi.VirtualFree(APtr, PtrUInt(ASize), WINDOWS_MEM_DECOMMIT);
{$ELSEIF defined(NEXTPAS_UNIX)}
  { MADV_DONTNEED tells kernel pages can be reclaimed; address range stays mapped }
  nextpas.core.platform.posix.ffi.madvise(APtr, size_t(ASize), MADV_DONTNEED);
{$ENDIF}
end;

{ platform_virtual_release - release the entire virtual address reservation }

procedure platform_virtual_release(APtr: Pointer; ASize: SizeUInt);
begin
  if (APtr = nil) or (ASize = 0) then
    Exit;
{$IFDEF NEXTPAS_WINDOWS}
  { MEM_RELEASE frees the entire allocation; dwSize must be 0 }
  nextpas.core.platform.windows.ffi.VirtualFree(APtr, 0, WINDOWS_MEM_RELEASE);
{$ELSEIF defined(NEXTPAS_UNIX)}
  nextpas.core.platform.posix.ffi.munmap(APtr, PtrUInt(ASize));
{$ENDIF}
end;

{ platform_madvise_thp - advise kernel to use Transparent Huge Pages }

procedure platform_madvise_thp(APtr: Pointer; ASize: SizeUInt);
begin
  if (APtr = nil) or (ASize = 0) then
    Exit;
{$IFDEF NEXTPAS_LINUX}
  { best-effort; silently ignored if THP not available }
  nextpas.core.platform.posix.ffi.madvise(APtr, size_t(ASize), MADV_HUGEPAGE);
{$ENDIF}
end;

end.
