{ nextpas - nextPas memory management: aligned pool with metadata

  Copyright (c) 2026 the nextPas contributors

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.
}

{ Aligned pool allocator with metadata headers.
  Supports custom alignment. Headers store magic + size + sequence for
  double-free detection. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.pool2;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base;

const
  POOL2_MAGIC = $A5C0FFEE;
  POOL2_DEFAULT_ALIGNMENT = 16;

type
  TPool2Stats = record
    BlockSize: SizeUInt;
    Alignment: SizeUInt;
    TotalBlocks: UInt64;
    FreeBlocks: UInt64;
    AllocCount: UInt64;
    FreeCount: UInt64;
    DoubleFreeDetected: UInt64;
  end;

  TPool2Allocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FBlockSize: SizeUInt;
    FAlignment: SizeUInt;
    FAlignedBlockSize: SizeUInt;
    FCapacity: SizeUInt;
    FFreeList: Pointer;
    FFreeCount: UInt64;
    FTotalBlocks: UInt64;
    FAllocCount: UInt64;
    FFreeCountTotal: UInt64;
    FDoubleFreeCount: UInt64;
    FSequence: UInt32;
    FPools: array of Pointer;
    FPoolCount: Integer;
    procedure AllocatePool;
  public
    constructor Create(AInner: IAllocator; ABlockSize: SizeUInt;
      AAlignment: SizeUInt = POOL2_DEFAULT_ALIGNMENT;
      ACapacity: SizeUInt = 256);
    destructor Destroy; override;
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;
    function GetStats: TPool2Stats;
    property BlockSize: SizeUInt read FBlockSize;
    property Alignment: SizeUInt read FAlignment;
  end;

implementation

type
  PPool2Header = ^TPool2Header;
  TPool2Header = record
    Magic: UInt32;
    Sequence: UInt32;
    BlockSize: SizeUInt;
    Next: Pointer;
    { Padding to ensure HEADER_SIZE is 64 bytes (multiple of maximum alignment).
      This guarantees that PByte(LHeader) + HEADER_SIZE is aligned when
      LHeader itself is aligned. }
    Padding: array[0..39] of Byte;
  end;

const
  HEADER_SIZE = SizeOf(TPool2Header);

function AlignUp(AValue: SizeUInt; AAlign: SizeUInt): SizeUInt;
begin
  Result := (AValue + AAlign - 1) and not (AAlign - 1);
end;

{ TPool2Allocator }

constructor TPool2Allocator.Create(AInner: IAllocator; ABlockSize: SizeUInt;
  AAlignment: SizeUInt; ACapacity: SizeUInt);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TPool2Allocator.Create: AInner cannot be nil');
  FInner := AInner;
  FBlockSize := ABlockSize;
  if AAlignment < 4 then
    FAlignment := 4
  else if not IsPowerOfTwo(AAlignment) then
    raise EAllocError.Create(aeInvalidLayout, 'TPool2Allocator.Create: AAlignment must be power of two')
  else
    FAlignment := AAlignment;
  FAlignedBlockSize := AlignUp(HEADER_SIZE + ABlockSize, FAlignment);
  if FAlignedBlockSize < HEADER_SIZE + ABlockSize then
    raise EAllocError.Create(aeOutOfMemory, 'TPool2Allocator.Create: block size overflow');
  if ACapacity < 16 then
    FCapacity := 16
  else
    FCapacity := ACapacity;
  if FAlignedBlockSize > 0 then
  begin
    if FAlignedBlockSize > High(SizeUInt) div FCapacity then
      raise EAllocError.Create(aeOutOfMemory, 'TPool2Allocator.Create: pool size overflow');
  end;
  FFreeList := nil;
  FFreeCount := 0;
  FTotalBlocks := 0;
  FAllocCount := 0;
  FFreeCountTotal := 0;
  FDoubleFreeCount := 0;
  FSequence := 1;
  FPools := nil;
  FPoolCount := 0;
  AllocatePool;
end;

destructor TPool2Allocator.Destroy;
var
  I: Integer;
begin
  for I := 0 to FPoolCount - 1 do
    FInner.FreeMem(FPools[I]);
  FPools := nil;
  FPoolCount := 0;
  inherited Destroy;
end;

procedure TPool2Allocator.AllocatePool;
var
  LPoolSize: SizeUInt;
  LRawPool, LPool: PByte;
  LHeader: PPool2Header;
  I: SizeUInt;
  LOffset: SizeUInt;
begin
  { Over-allocate to guarantee alignment of returned pointers }
  LPoolSize := FAlignedBlockSize * FCapacity + FAlignment;
  LRawPool := PByte(FInner.GetMem(LPoolSize));
  if LRawPool = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TPool2Allocator.AllocatePool: allocation failed');

  { Track raw pointer for freeing }
  if FPoolCount >= Length(FPools) then
    SetLength(FPools, FPoolCount + 8);
  FPools[FPoolCount] := LRawPool;
  Inc(FPoolCount);

  { Align the pool base to FAlignment }
  LOffset := FAlignment - (SizeUInt(LRawPool) mod FAlignment);
  if LOffset = FAlignment then
    LOffset := 0;
  LPool := LRawPool + LOffset;

  for I := 0 to FCapacity - 1 do
  begin
    LHeader := PPool2Header(LPool + I * FAlignedBlockSize);
    LHeader^.Magic := POOL2_MAGIC;
    LHeader^.Sequence := 0;
    LHeader^.BlockSize := FBlockSize;
    LHeader^.Next := FFreeList;
    FFreeList := LHeader;
  end;

  Inc(FTotalBlocks, FCapacity);
  Inc(FFreeCount, FCapacity);
end;

function TPool2Allocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LHeader: PPool2Header;
begin
  if ASize = 0 then
    Exit(nil);
  if ASize > FBlockSize then
    Exit(nil);

  if FFreeList = nil then
  begin
    AllocatePool;
    if FFreeList = nil then
      Exit(nil);
  end;

  LHeader := PPool2Header(FFreeList);
  FFreeList := LHeader^.Next;
  Dec(FFreeCount);
  Inc(FAllocCount);

  LHeader^.Sequence := FSequence;
  Inc(FSequence);

  Result := Pointer(PByte(LHeader) + HEADER_SIZE);
end;

function TPool2Allocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

procedure TPool2Allocator.FreeMem(APtr: Pointer); inline;
var
  LHeader: PPool2Header;
begin
  if APtr = nil then
    Exit;

  LHeader := PPool2Header(PByte(APtr) - HEADER_SIZE);
  if LHeader^.Magic <> POOL2_MAGIC then
    Exit;

  if LHeader^.Sequence = 0 then
  begin
    Inc(FDoubleFreeCount);
    Exit;
  end;

  LHeader^.Sequence := 0;
  LHeader^.Next := FFreeList;
  FFreeList := LHeader;
  Inc(FFreeCount);
  Inc(FFreeCountTotal);
end;

function TPool2Allocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LCopySize: SizeUInt;
begin
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize <= FBlockSize then
    Exit(APtr);

  Result := GetMem(ASize);
  if Result = nil then
    Exit(nil);
  LCopySize := FBlockSize;
  if LCopySize > ASize then
    LCopySize := ASize;
  Move(APtr^, Result^, LCopySize);
  FreeMem(APtr);
end;

function TPool2Allocator.GetStats: TPool2Stats;
begin
  Result.BlockSize := FBlockSize;
  Result.Alignment := FAlignment;
  Result.TotalBlocks := FTotalBlocks;
  Result.FreeBlocks := FFreeCount;
  Result.AllocCount := FAllocCount;
  Result.FreeCount := FFreeCountTotal;
  Result.DoubleFreeDetected := FDoubleFreeCount;
end;

function TPool2Allocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
