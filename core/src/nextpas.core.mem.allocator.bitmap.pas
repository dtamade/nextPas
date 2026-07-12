{ nextpas - nextPas memory management: bitmap allocator

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

{ Bitmap allocator — uses a bitmap to track fixed-size slot allocation.
  O(n) scan for free bits, but minimal memory overhead (1 bit per slot).
  Ideal for embedded scenarios or fixed slot management. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.bitmap;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  TBitmapStats = record
    SlotSize: SizeUInt;
    SlotCount: SizeUInt;
    UsedSlots: SizeUInt;
    FreeSlots: SizeUInt;
    AllocCount: UInt64;
    FreeCount: UInt64;
  end;

  TBitmapAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FSlotSize: SizeUInt;
    FSlotCount: SizeUInt;
    FBitmap: array of UInt32;
    FData: PByte;
    FUsedSlots: SizeUInt;
    FAllocCount: UInt64;
    FFreeCount: UInt64;
    function FindFreeBit: Integer;
    procedure SetBit(AIdx: Integer);
    procedure ClearBit(AIdx: Integer);
    function IsBitSet(AIdx: Integer): Boolean;
  public
    constructor Create(AInner: IAllocator; ASlotSize: SizeUInt;
      ASlotCount: SizeUInt = 1024);
    destructor Destroy; override;
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;
    function GetStats: TBitmapStats;
    property SlotSize: SizeUInt read FSlotSize;
    property SlotCount: SizeUInt read FSlotCount;
    property UsedSlots: SizeUInt read FUsedSlots;
  end;

implementation

uses
  nextpas.core.mem.error;

const
  BITS_PER_UINT32 = 32;

{ TBitmapAllocator }

constructor TBitmapAllocator.Create(AInner: IAllocator; ASlotSize: SizeUInt;
  ASlotCount: SizeUInt);
var
  LBitmapWords: SizeUInt;
  LTotalSize: SizeUInt;
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TBitmapAllocator.Create: AInner cannot be nil');
  FInner := AInner;
  if ASlotSize < 8 then
    FSlotSize := 8
  else
    FSlotSize := ASlotSize;
  if ASlotCount < 32 then
    FSlotCount := 32
  else
    FSlotCount := ASlotCount;

  { Overflow guard: FSlotSize * FSlotCount must not wrap }
  LTotalSize := FSlotSize * FSlotCount;
  if (FSlotCount > 0) and (LTotalSize div FSlotCount <> FSlotSize) then
    raise EAllocError.Create(aeOutOfMemory, 'TBitmapAllocator.Create: size overflow');

  LBitmapWords := (FSlotCount + BITS_PER_UINT32 - 1) div BITS_PER_UINT32;
  SetLength(FBitmap, LBitmapWords);
  FillChar(FBitmap[0], LBitmapWords * SizeOf(UInt32), 0);

  FData := PByte(FInner.GetMem(LTotalSize));
  if FData = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TBitmapAllocator.Create: backing allocation failed');
  FUsedSlots := 0;
  FAllocCount := 0;
  FFreeCount := 0;
end;

destructor TBitmapAllocator.Destroy;
begin
  if FData <> nil then
    FInner.FreeMem(FData);
  FBitmap := nil;
  FInner := nil;
  inherited Destroy;
end;

function TBitmapAllocator.FindFreeBit: Integer;
var
  I, J: Integer;
  LWord: UInt32;
begin
  for I := 0 to High(FBitmap) do
  begin
    if FBitmap[I] <> $FFFFFFFF then
    begin
      LWord := not FBitmap[I];
      for J := 0 to BITS_PER_UINT32 - 1 do
      begin
        if (LWord and (1 shl J)) <> 0 then
        begin
          Result := I * BITS_PER_UINT32 + J;
          if Result < Integer(FSlotCount) then
            Exit;
        end;
      end;
    end;
  end;
  Result := -1;
end;

procedure TBitmapAllocator.SetBit(AIdx: Integer);
begin
  FBitmap[AIdx div BITS_PER_UINT32] :=
    FBitmap[AIdx div BITS_PER_UINT32] or (1 shl (AIdx mod BITS_PER_UINT32));
end;

procedure TBitmapAllocator.ClearBit(AIdx: Integer);
begin
  FBitmap[AIdx div BITS_PER_UINT32] :=
    FBitmap[AIdx div BITS_PER_UINT32] and not (1 shl (AIdx mod BITS_PER_UINT32));
end;

function TBitmapAllocator.IsBitSet(AIdx: Integer): Boolean;
begin
  Result := (FBitmap[AIdx div BITS_PER_UINT32] and
    (1 shl (AIdx mod BITS_PER_UINT32))) <> 0;
end;

function TBitmapAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LIdx: Integer;
begin
  if (ASize = 0) or (ASize > FSlotSize) then
    Exit(nil);

  LIdx := FindFreeBit;
  if LIdx < 0 then
    Exit(nil);

  SetBit(LIdx);
  Inc(FUsedSlots);
  Inc(FAllocCount);
  Result := Pointer(FData + LIdx * FSlotSize);
end;

function TBitmapAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

procedure TBitmapAllocator.FreeMem(APtr: Pointer); inline;
var
  LOffset: SizeUInt;
  LIdx: Integer;
begin
  if APtr = nil then
    Exit;

  LOffset := SizeUInt(PByte(APtr) - FData);
  LIdx := Integer(LOffset div FSlotSize);

  if (LIdx < 0) or (LIdx >= Integer(FSlotCount)) then
    Exit;
  if not IsBitSet(LIdx) then
    Exit;

  ClearBit(LIdx);
  Dec(FUsedSlots);
  Inc(FFreeCount);
end;

function TBitmapAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
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
  if ASize <= FSlotSize then
    Exit(APtr);

  Result := GetMem(ASize);
  if Result = nil then
    Exit(nil);
  LCopySize := FSlotSize;
  Move(APtr^, Result^, LCopySize);
  FreeMem(APtr);
end;

function TBitmapAllocator.GetStats: TBitmapStats;
begin
  Result.SlotSize := FSlotSize;
  Result.SlotCount := FSlotCount;
  Result.UsedSlots := FUsedSlots;
  Result.FreeSlots := FSlotCount - FUsedSlots;
  Result.AllocCount := FAllocCount;
  Result.FreeCount := FFreeCount;
end;

function TBitmapAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
