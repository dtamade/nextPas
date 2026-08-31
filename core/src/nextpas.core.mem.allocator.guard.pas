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

Author:    nextpas.core
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.allocator.guard;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

type
  {** Guard page allocator. Each allocation is surrounded by
      unmapped pages — any out-of-bounds access triggers SIGSEGV.

      @warning 性能极低（每次分配 3 个 mmap 系统调用），仅用于调试/安全测试。 }
  TGuardAllocator = class(TInterfacedObject, IAllocator)
  public
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;
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

function TGuardAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LCommittedSize, LTotalSize: SizeUInt;
  LBase: Pointer;
  LCommitBase: Pointer;
  LHdr: PGuardHeader;
begin
  Result := nil;
  if ASize = 0 then
    Exit;
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

function TGuardAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TGuardAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LHdr: PGuardHeader;
  LOldSize: SizeUInt;
  LCopySize: SizeUInt;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then
    Exit(GetMem(ASize));
  LHdr := PGuardHeader(PtrUInt(APtr) - HeaderSize);
  if LHdr^.Magic <> GUARD_MAGIC then
    raise EAllocError.Create(aeInvalidPointer,
      FormatAllocErrorMsg('TGuardAllocator', 'ReallocMem', 'invalid guard magic (wild pointer)'));
  LOldSize := LHdr^.UserSize;

  { Allocate new, copy, free old }
  Result := GetMem(ASize);
  if Result = nil then
    Exit;
  if LOldSize < ASize then
    LCopySize := LOldSize
  else
    LCopySize := ASize;
  if LCopySize > 0 then
    Move(APtr^, Result^, LCopySize);
  FreeMem(APtr);
end;

procedure TGuardAllocator.FreeMem(APtr: Pointer); inline;
var
  LHdr: PGuardHeader;
begin
  if APtr = nil then
    Exit;
  LHdr := PGuardHeader(PtrUInt(APtr) - HeaderSize);
  if LHdr^.Magic <> GUARD_MAGIC then
    raise EAllocError.Create(aeInvalidPointer,
      FormatAllocErrorMsg('TGuardAllocator', 'FreeMem', 'invalid guard magic (possible double free or wild pointer)'));
  LHdr^.Magic := 0;  { Clear magic to detect double free. }
  platform_virtual_release(LHdr^.Base, LHdr^.TotalSize);
end;

function TGuardAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
