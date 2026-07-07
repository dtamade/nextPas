{
# nextpas.core.mem.allocator.guard

## 摘要

Guard page allocator — 每次分配用未映射页包围，越界写入立即 SIGSEGV。

布局:
```
[PROT_NONE 4K][header + user data (committed)][PROT_NONE 4K]
              ^ user_ptr
```

适用场景: 调试/安全敏感环境，检测堆缓冲区溢出/下溢。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.guard;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.allocator.base;

type
  {** Guard page allocator. Each allocation is surrounded by
      unmapped pages — any out-of-bounds access triggers SIGSEGV.

      @warning 性能极低（每次分配 3 个 mmap 系统调用），仅用于调试/安全测试。 }
  TGuardAllocator = class(TAllocator)
  public
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
    function Traits: TAllocatorTraits; override;
  end;

implementation

uses
  nextpas.core.platform.memory,
  nextpas.core.mem.error;

const
  GUARD_PAGE_SIZE = MEM_PAGE_SIZE;  { 4K guard page }
  GUARD_MAGIC = $47554152;  { 'GUAR' — validates header integrity }

type
  { Stored just before the user pointer, within the committed region. }
  PGuardHeader = ^TGuardHeader;
  TGuardHeader = record
    Magic: UInt32;        { GUARD_MAGIC — detects invalid/double free }
    Base: Pointer;        { base of the full mmap reservation }
    TotalSize: SizeUInt;  { total reservation size (guard + committed + guard) }
    UserSize: SizeUInt;   { originally requested size }
  end;

function HeaderSize: SizeUInt; inline;
begin
  Result := SizeOf(TGuardHeader);
end;

{ Compute the full reservation layout:
    [guard_page][AlignUp(header + user_size, page_size)][guard_page] }
function CalcLayout(ASize: SizeUInt;
  out ACommittedSize: SizeUInt; out ATotalSize: SizeUInt): Boolean;
var
  LRaw: SizeUInt;
begin
  Result := False;
  { header + user data, rounded up to page boundary }
  LRaw := HeaderSize + ASize;
  if LRaw < ASize then
    Exit;
  ACommittedSize := AlignUp(LRaw, GUARD_PAGE_SIZE);
  if ACommittedSize < LRaw then
    Exit;
  ATotalSize := GUARD_PAGE_SIZE + ACommittedSize + GUARD_PAGE_SIZE;
  if ATotalSize < ACommittedSize then
    Exit;
  Result := True;
end;

{ --- TGuardAllocator --- }

function TGuardAllocator.DoGetMem(ASize: SizeUInt): Pointer;
var
  LCommittedSize, LTotalSize: SizeUInt;
  LBase: Pointer;
  LCommitBase: Pointer;
  LHdr: PGuardHeader;
begin
  Result := nil;
  if not CalcLayout(ASize, LCommittedSize, LTotalSize) then
    Exit;

  { Reserve the full region (guard + committed + guard) — all PROT_NONE }
  LBase := platform_virtual_reserve(LTotalSize);
  if LBase = nil then
    Exit;

  { Commit only the middle portion (make it read/write) }
  LCommitBase := Pointer(PtrUInt(LBase) + GUARD_PAGE_SIZE);
  if not platform_virtual_commit(LCommitBase, LCommittedSize) then
  begin
    platform_virtual_release(LBase, LTotalSize);
    Exit;
  end;

  { Write header at the start of committed region }
  LHdr := PGuardHeader(LCommitBase);
  LHdr^.Magic := GUARD_MAGIC;
  LHdr^.Base := LBase;
  LHdr^.TotalSize := LTotalSize;
  LHdr^.UserSize := ASize;

  { Return pointer past the header }
  Result := Pointer(PtrUInt(LCommitBase) + HeaderSize);
end;

function TGuardAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DoGetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TGuardAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
var
  LHdr: PGuardHeader;
  LOldSize: SizeUInt;
  LCopySize: SizeUInt;
begin
  if APtr = nil then
    Exit(DoGetMem(ASize));
  LHdr := PGuardHeader(PtrUInt(APtr) - HeaderSize);
  if LHdr^.Magic <> GUARD_MAGIC then
    raise EAllocError.Create(aeInvalidPointer,
      'TGuardAllocator.ReallocMem: invalid guard magic (wild pointer)');
  LOldSize := LHdr^.UserSize;

  { Allocate new, copy, free old }
  Result := DoGetMem(ASize);
  if Result = nil then
    Exit;
  if LOldSize < ASize then
    LCopySize := LOldSize
  else
    LCopySize := ASize;
  if LCopySize > 0 then
    Move(APtr^, Result^, LCopySize);
  DoFreeMem(APtr);
end;

procedure TGuardAllocator.DoFreeMem(APtr: Pointer);
var
  LHdr: PGuardHeader;
begin
  if APtr = nil then
    Exit;
  LHdr := PGuardHeader(PtrUInt(APtr) - HeaderSize);
  if LHdr^.Magic <> GUARD_MAGIC then
    raise EAllocError.Create(aeInvalidPointer,
      'TGuardAllocator.FreeMem: invalid guard magic (possible double free or wild pointer)');
  LHdr^.Magic := 0;  { Clear magic to detect double free. }
  platform_virtual_release(LHdr^.Base, LHdr^.TotalSize);
end;

function TGuardAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  Result.ThreadSafe := False;
end;

end.
