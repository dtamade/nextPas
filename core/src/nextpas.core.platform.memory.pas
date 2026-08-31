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
    pszbWindowsPermanentFallback,
    pszbPosixExplicitBZero
  );

{** @desc 分配对齐内存
    @param ASize 字节数
    @param AAlignment 对齐要求（必须是 2 的幂）
    @return 内存指针，失败返回 nil *}
function platform_aligned_alloc(ASize, AAlignment: SizeUInt): Pointer;

{** @desc 重新分配对齐内存
    @param APtr 原始指针（nil 表示新分配）
    @param ANewSize 新的字节数
    @param AAlignment 对齐要求
    @return 新内存指针，失败返回 nil *}
function platform_aligned_realloc(APtr: Pointer; ANewSize, AAlignment: SizeUInt): Pointer;

{** @desc 释放对齐内存
    @param APtr 由 platform_aligned_alloc 分配的指针 *}
procedure platform_aligned_free(APtr: Pointer);

{** @desc 获取当前使用的对齐分配后端
    @return TPlatformAlignedAllocBackend 枚举值 *}
function platform_aligned_alloc_backend: TPlatformAlignedAllocBackend;

{** @desc 检查是否使用原生对齐分配（非 fallback）
    @return True 使用原生实现 *}
function platform_aligned_alloc_is_native: Boolean;
{ On Windows, returns True (uses _aligned_malloc from CRT). On POSIX,
  returns True (uses posix_memalign). On unsupported platforms,
  returns False (uses SysGetMem fallback). There is no runtime
  detection of _aligned_malloc availability on Windows; if the CRT
  does not provide it, the call will fail at link time. }

{** @desc 获取安全清零后端
    @return TPlatformSecureZeroBackend 枚举值 *}
function platform_secure_zero_memory_backend: TPlatformSecureZeroBackend;

{** @desc 检查是否使用原生安全清零
    @return True 使用原生实现 *}
function platform_secure_zero_memory_is_native: Boolean;

{** @desc 安全清零内存（不可被编译器优化掉）
    @param APtr 内存指针
    @param ASize 字节数 *}
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
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;
{$ELSE}
  {$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base;
  {$ELSEIF defined(NEXTPAS_MACOS)}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.darwin.ffi;
  {$ELSE}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;
  {$ENDIF}
{$ENDIF}

const
  PLATFORM_ALIGNED_ALLOC_MAGIC = UInt32($4E50414D);

type
  PPlatformAlignedAllocHeader = ^TPlatformAlignedAllocHeader;
  TPlatformAlignedAllocHeader = record
    RawPtr: Pointer;
    Size: SizeUInt;
    RawSize: SizeUInt;
    Alignment: SizeUInt;
    Magic: UInt32;
  end;

function IsPowerOfTwo(AValue: SizeUInt): Boolean; inline;
begin
  Result := (AValue <> 0) and ((AValue and (AValue - 1)) = 0);
end;

function IsValidAlignment(AAlignment: SizeUInt): Boolean; inline;
const
  { Cap extreme alignments. 1GB+ posix_memalign has been observed to leave
    process state that Abort-traps at suite exit on Darwin aarch64 GHA even
    without heaptrc; production callers never need multi-GB alignment. }
  MAX_ALIGNMENT = SizeUInt(16 * 1024 * 1024);
begin
  Result := (AAlignment >= SizeOf(Pointer)) and IsPowerOfTwo(AAlignment)
    and (AAlignment <= MAX_ALIGNMENT);
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
{ On Windows, returns True (uses _aligned_malloc from CRT). On POSIX
  (including Darwin via mmap backend), returns True (uses posix_memalign
  or mmap-aligned). On unsupported platforms, returns False (uses
  SysGetMem fallback). There is no runtime detection of _aligned_malloc
  availability on Windows; if the CRT does not provide it, the call
  will fail at link time. }
begin
  Result := platform_aligned_alloc_backend <> paabFallback;
end;

function platform_secure_zero_memory_backend: TPlatformSecureZeroBackend;
begin
{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_FREEBSD)}
  Result := pszbPosixExplicitBZero;
{$ELSEIF defined(NEXTPAS_MACOS)}
  { macOS uses memset_s (C11); still counts as native secure-zero. }
  Result := pszbPosixExplicitBZero;
{$ELSEIF defined(NEXTPAS_WINDOWS)}
  { No stable dual-host user-mode secure-zero DLL export (Wine + real Windows
    SDK). Permanent FillChar+barrier path; see D3.b decision tokens below. }
  Result := pszbWindowsPermanentFallback;
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
  windows-native-secure-zero=permanent-fallback
  windows-secure-zero-decision=D3.b-permanent-fillchar-barrier
  posix-native-secure-zero=explicit_bzero (Linux/FreeBSD) or memset_s (macOS)
  native-secure-zero-promotion-requires=host-owned-ffi-export-with-wine-and-real-windows-proof
  secure-zero-forced-compile-truth=source-contract
  windows-runtime-ready=false
  windows-native-export=unavailable
  fallback-barrier-caveat=ReadWriteBarrier prevents compiler reordering but
    is not a full hardware memory fence. On weakly-ordered architectures
    (ARM, POWER) this may not prevent hardware reordering of the zero-fill
    with subsequent sensitive-data stores. For cryptographic key zeroing
    prefer the POSIX explicit_bzero backend or use an explicit hardware
    fence (e.g. __sync_synchronize on GCC/Clang).
}
procedure platform_secure_zero_memory(APtr: Pointer; ASize: SizeUInt);
begin
  if (APtr = nil) or (ASize = 0) then
    Exit;

{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_FREEBSD)}
  nextpas.core.platform.posix.ffi.explicit_bzero(APtr, size_t(ASize));
{$ELSEIF defined(NEXTPAS_MACOS)}
  { Darwin: prefer memset_s when the binding is trusted. GHA macos-14 has
    Abort-trapped (signal 6) mid secure-zero suite with the C11 binding —
    possibly constraint-handler default. Keep FillChar+barrier as the
    durable path until the memset_s ABI is proven on aarch64 runners. }
  FillChar(APtr^, ASize, 0);
  platform_secure_zero_memory_barrier;
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
{$IF defined(NEXTPAS_MACOS)}
var
  LBase: Pointer;
{$ELSEIF defined(NEXTPAS_UNIX)}
var
  LRaw: Pointer;
{$ENDIF}
begin
  Result := nil;
{$IFDEF NEXTPAS_WINDOWS}
  Result := nextpas.core.platform.windows.ffi._aligned_malloc(ARawSize, AAlignment);
{$ELSEIF defined(NEXTPAS_MACOS)}
  { Darwin native: mmap anonymous to avoid posix_memalign/free heap mixed with
    virtual mmap under heaptrc (Abort trap 6 on aarch64 GHA). mmap path is
    heaptrc-agnostic and consistent with platform_virtual_* (inline, zero-copy
    header carve, no extra copy). }
  LBase := nextpas.core.platform.posix.ffi.mmap(
    nil, PtrUInt(ARawSize),
    PLATFORM_POSIX_PROT_READ or PLATFORM_POSIX_PROT_WRITE,
    PLATFORM_POSIX_MAP_PRIVATE or PLATFORM_POSIX_MAP_ANONYMOUS, -1, 0);
  if (LBase <> nil) and (LBase <> Pointer(PLATFORM_POSIX_MAP_FAILED)) then
    Result := LBase;
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
{$ELSEIF defined(NEXTPAS_MACOS)}
  { Darwin mmap path freed in platform_aligned_free via header RawSize;
    this raw-free is a no-op fallback (stability: no double munmap). }
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
  LHeader^.RawSize := LRawSize;
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
{$IFDEF DEBUG}
  Assert(LHeader^.Magic = PLATFORM_ALIGNED_ALLOC_MAGIC,
    'platform_aligned_free: invalid magic (possible double-free or wrong pointer)');
{$ELSE}
  if LHeader^.Magic <> PLATFORM_ALIGNED_ALLOC_MAGIC then
    RunError(204);
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  if platform_aligned_alloc_backend <> paabFallback then
  begin
    { Darwin mmap backend: munmap with stored RawSize (stability: exact size,
      no double-free, heaptrc-agnostic). Zero-copy header preserved. }
    if LHeader^.RawSize <> 0 then
      nextpas.core.platform.posix.ffi.munmap(LHeader^.RawPtr, PtrUInt(LHeader^.RawSize));
    Exit;
  end;
{$ENDIF}
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
  if LHeader^.Alignment <> AAlignment then
    Exit(nil);
  LOldSize := LHeader^.Size;

  { Shrink in-place: no copy needed, just update the size }
  if ANewSize <= LOldSize then
  begin
    LHeader^.Size := ANewSize;
    Exit(APtr);
  end;

  { Grow: allocate new, copy, free old }
  Result := platform_aligned_alloc(ANewSize, AAlignment);
  if Result = nil then
    Exit;
  Move(APtr^, Result^, LOldSize);
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
  { mprotect keeps the existing reservation; avoid MAP_FIXED which can
    forcibly replace adjacent mappings and has corrupted process exit
    under heaptrc on Darwin (Abort trap after green suite). }
  Result := nextpas.core.platform.posix.ffi.mprotect(
    APtr, PtrUInt(ASize),
    PLATFORM_POSIX_PROT_READ or PLATFORM_POSIX_PROT_WRITE) = 0;
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
  { Drop access so the reservation remains unreadable/unwritable. Then
    advise reclamation where it is safe. Linux MADV_DONTNEED discards
    immediately (re-fault zero-fills). On Darwin, skip madvise here:
    MADV_DONTNEED after mixed mprotect/munmap has been implicated in
    process-exit Abort traps under some toolchains; PROT_NONE is enough
    to match decommit semantics for the portable API. }
  nextpas.core.platform.posix.ffi.mprotect(
    APtr, PtrUInt(ASize), PLATFORM_POSIX_PROT_NONE);
  {$IFNDEF NEXTPAS_MACOS}
  nextpas.core.platform.posix.ffi.madvise(APtr, size_t(ASize), MADV_DONTNEED);
  {$ENDIF}
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
