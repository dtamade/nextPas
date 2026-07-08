{ nextpas - nextPas memory management: size-class segregated allocator

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

{ Size-class segregated free-list allocator.
  16 size classes (8B–64KB). Small objects use per-class freelists;
  large objects delegate to inner allocator.
  Header stores class index for O(1) free routing. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.size_class;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

const
  SIZE_CLASS_COUNT = 16;

type
  TSizeClassStats = record
    ClassSizes: array[0..SIZE_CLASS_COUNT-1] of SizeUInt;
    ClassFreeCounts: array[0..SIZE_CLASS_COUNT-1] of UInt64;
    ClassAllocCounts: array[0..SIZE_CLASS_COUNT-1] of UInt64;
    LargeAllocCount: UInt64;
    LargeFreeCount: UInt64;
    TotalAlloc: UInt64;
    TotalFree: UInt64;
  end;

  TSizeClassAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FClassSizes: array[0..SIZE_CLASS_COUNT-1] of SizeUInt;
    FFreelists: array[0..SIZE_CLASS_COUNT-1] of Pointer;
    FFreeCounts: array[0..SIZE_CLASS_COUNT-1] of UInt64;
    FAllocCounts: array[0..SIZE_CLASS_COUNT-1] of UInt64;
    FLargeAllocCount: UInt64;
    FLargeFreeCount: UInt64;
    function FindClass(ASize: SizeUInt): Integer;
    procedure GrowClass(AClassIdx: Integer);
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    constructor Create(AInner: IAllocator);
    function GetStats: TSizeClassStats;
  end;

implementation

type
  PSizeClassHeader = ^TSizeClassHeader;
  TSizeClassHeader = record
    ClassIdx: Integer;
    _Pad: Integer;
    Next: Pointer;
  end;

const
  SIZE_CLASS_HEADER = SizeOf(TSizeClassHeader);
  GROW_COUNT = 64;

constructor TSizeClassAllocator.Create(AInner: IAllocator);
var
  I: Integer;
  LSize: SizeUInt;
begin
  inherited Create;
  FInner := AInner;
  LSize := 8;
  for I := 0 to SIZE_CLASS_COUNT - 1 do
  begin
    FClassSizes[I] := LSize;
    FFreelists[I] := nil;
    FFreeCounts[I] := 0;
    FAllocCounts[I] := 0;
    LSize := LSize * 2;
  end;
  FLargeAllocCount := 0;
  FLargeFreeCount := 0;
end;

function TSizeClassAllocator.FindClass(ASize: SizeUInt): Integer;
var
  I: Integer;
begin
  for I := 0 to SIZE_CLASS_COUNT - 1 do
    if ASize <= FClassSizes[I] then
      Exit(I);
  Result := -1;
end;

procedure TSizeClassAllocator.GrowClass(AClassIdx: Integer);
var
  LBlockSize: SizeUInt;
  LPool: PByte;
  LHeader: PSizeClassHeader;
  I: Integer;
begin
  LBlockSize := SIZE_CLASS_HEADER + FClassSizes[AClassIdx];
  LPool := PByte(FInner.GetMem(LBlockSize * GROW_COUNT));
  for I := 0 to GROW_COUNT - 1 do
  begin
    LHeader := PSizeClassHeader(LPool + I * LBlockSize);
    LHeader^.ClassIdx := AClassIdx;
    LHeader^.Next := FFreelists[AClassIdx];
    FFreelists[AClassIdx] := LHeader;
  end;
  Inc(FFreeCounts[AClassIdx], GROW_COUNT);
end;

function TSizeClassAllocator.DoGetMem(ASize: SizeUInt): Pointer;
var
  LClassIdx: Integer;
  LHeader: PSizeClassHeader;
begin
  if ASize = 0 then
    Exit(nil);

  LClassIdx := FindClass(ASize);
  if LClassIdx < 0 then
  begin
    Inc(FLargeAllocCount);
    Exit(FInner.GetMem(ASize));
  end;

  if FFreelists[LClassIdx] = nil then
    GrowClass(LClassIdx);

  LHeader := PSizeClassHeader(FFreelists[LClassIdx]);
  FFreelists[LClassIdx] := LHeader^.Next;
  Dec(FFreeCounts[LClassIdx]);
  Inc(FAllocCounts[LClassIdx]);

  Result := Pointer(PByte(LHeader) + SIZE_CLASS_HEADER);
end;

function TSizeClassAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DoGetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

procedure TSizeClassAllocator.DoFreeMem(APtr: Pointer);
var
  LHeader: PSizeClassHeader;
  LClassIdx: Integer;
begin
  if APtr = nil then
    Exit;

  LHeader := PSizeClassHeader(PByte(APtr) - SIZE_CLASS_HEADER);
  LClassIdx := LHeader^.ClassIdx;

  if (LClassIdx >= 0) and (LClassIdx < SIZE_CLASS_COUNT) then
  begin
    LHeader^.Next := FFreelists[LClassIdx];
    FFreelists[LClassIdx] := LHeader;
    Inc(FFreeCounts[LClassIdx]);
  end
  else
    Inc(FLargeFreeCount);
end;

function TSizeClassAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
var
  LOldSize, LCopySize: SizeUInt;
  LHeader: PSizeClassHeader;
  LClassIdx: Integer;
begin
  if ASize = 0 then
  begin
    DoFreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(DoGetMem(ASize));

  LHeader := PSizeClassHeader(PByte(APtr) - SIZE_CLASS_HEADER);
  LClassIdx := LHeader^.ClassIdx;
  if (LClassIdx >= 0) and (LClassIdx < SIZE_CLASS_COUNT) then
    LOldSize := FClassSizes[LClassIdx]
  else
    LOldSize := ASize; { unknown for large, just allocate new }

  if ASize <= LOldSize then
    Exit(APtr);

  Result := DoGetMem(ASize);
  if Result = nil then
    Exit(nil);
  LCopySize := LOldSize;
  Move(APtr^, Result^, LCopySize);
  DoFreeMem(APtr);
end;

function TSizeClassAllocator.GetStats: TSizeClassStats;
var
  I: Integer;
begin
  for I := 0 to SIZE_CLASS_COUNT - 1 do
  begin
    Result.ClassSizes[I] := FClassSizes[I];
    Result.ClassFreeCounts[I] := FFreeCounts[I];
    Result.ClassAllocCounts[I] := FAllocCounts[I];
  end;
  Result.LargeAllocCount := FLargeAllocCount;
  Result.LargeFreeCount := FLargeFreeCount;
  Result.TotalAlloc := 0;
  Result.TotalFree := 0;
  for I := 0 to SIZE_CLASS_COUNT - 1 do
  begin
    Inc(Result.TotalAlloc, FAllocCounts[I]);
    Inc(Result.TotalFree, FFreeCounts[I]);
  end;
  Inc(Result.TotalAlloc, FLargeAllocCount);
  Inc(Result.TotalFree, FLargeFreeCount);
end;

end.
