{ nextpas - nextPas memory management: aligned allocator

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

{ Aligned allocator — guarantees all allocations meet a specified alignment.
  Stores original pointer before aligned pointer for correct free. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.aligned;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  ALIGNED_DEFAULT_ALIGNMENT = 64;
  ALIGNED_HEADER_SIZE = SizeOf(Pointer) + SizeOf(SizeUInt); { raw ptr + requested size }

type
  TAlignedStats = record
    AllocCount: UInt64;
    FreeCount: UInt64;
    ActiveAllocs: UInt64;
    Alignment: SizeUInt;
  end;

  TAlignedAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FAlignment: SizeUInt;
    FAllocCount: UInt64;
    FFreeCount: UInt64;
    FActiveAllocs: UInt64;
  public
    constructor Create(AInner: IAllocator;
      AAlignment: SizeUInt = ALIGNED_DEFAULT_ALIGNMENT);
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function GetStats: TAlignedStats;
    property Alignment: SizeUInt read FAlignment;
    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error;

function AlignUp(APtr: Pointer; AAlign: SizeUInt): Pointer;
var
  LAddr: SizeUInt;
begin
  LAddr := SizeUInt(APtr);
  LAddr := (LAddr + AAlign - 1) and not (AAlign - 1);
  Result := Pointer(LAddr);
end;

{ TAlignedAllocator }

constructor TAlignedAllocator.Create(AInner: IAllocator; AAlignment: SizeUInt);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TAlignedAllocator.Create: AInner cannot be nil');
  FInner := AInner;
  { Validate: alignment must be power of 2 and >= SizeOf(Pointer) }
  if AAlignment < SizeOf(Pointer) then
    FAlignment := SizeOf(Pointer)
  else if (AAlignment and (AAlignment - 1)) <> 0 then
    raise EAllocError.Create(aeInvalidLayout, 'TAlignedAllocator.Create: alignment must be power of 2')
  else
    FAlignment := AAlignment;
  FAllocCount := 0;
  FFreeCount := 0;
  FActiveAllocs := 0;
end;

function TAlignedAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LRaw: Pointer;
  LAligned: Pointer;
  LHdrPtr: PByte;
  LExtra: SizeUInt;
begin
  if ASize = 0 then
    Exit(nil);

  { Allocate extra space for alignment + header }
  LExtra := FAlignment + ALIGNED_HEADER_SIZE;
  if ASize + LExtra < ASize then { overflow check }
    Exit(nil);
  LRaw := FInner.GetMem(ASize + LExtra);
  if LRaw = nil then
    Exit(nil);

  { Reserve space for header }
  LAligned := AlignUp(Pointer(PByte(LRaw) + ALIGNED_HEADER_SIZE), FAlignment);

  { Store raw pointer and requested size before aligned pointer }
  LHdrPtr := PByte(LAligned) - ALIGNED_HEADER_SIZE;
  PPointer(LHdrPtr)^ := LRaw;
  PSizeUInt(LHdrPtr + SizeOf(Pointer))^ := ASize;

  Inc(FAllocCount);
  Inc(FActiveAllocs);
  Result := LAligned;
end;

function TAlignedAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

procedure TAlignedAllocator.FreeMem(APtr: Pointer); inline;
var
  LRaw: Pointer;
begin
  if APtr = nil then
    Exit;
  LRaw := (PPointer(PByte(APtr) - ALIGNED_HEADER_SIZE))^;
  FInner.FreeMem(LRaw);
  Inc(FFreeCount);
  Dec(FActiveAllocs);
end;

function TAlignedAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LOldSize, LCopySize: SizeUInt;
  LHdrPtr: PByte;
begin
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(GetMem(ASize));

  LHdrPtr := PByte(APtr) - ALIGNED_HEADER_SIZE;
  LOldSize := PSizeUInt(LHdrPtr + SizeOf(Pointer))^;

  Result := GetMem(ASize);
  if Result = nil then
    Exit(nil);
  LCopySize := LOldSize;
  if LCopySize > ASize then
    LCopySize := ASize;
  Move(APtr^, Result^, LCopySize);
  FreeMem(APtr);
end;

function TAlignedAllocator.GetStats: TAlignedStats;
begin
  Result.AllocCount := FAllocCount;
  Result.FreeCount := FFreeCount;
  Result.ActiveAllocs := FActiveAllocs;
  Result.Alignment := FAlignment;
end;

function TAlignedAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
