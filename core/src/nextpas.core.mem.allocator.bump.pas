{ nextpas - nextPas memory management: bump/linear allocator

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

{ Bump/linear allocator — the fastest possible allocation strategy.
  Only increments a pointer. No free, no headers, no fragmentation.
  Reset reclaims everything at once. }

{$I nextpas.core.settings.inc}

unit nextpas.core.mem.allocator.bump;

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  TBumpStats = record
    TotalAllocated: UInt64;
    AllocCount: UInt64;
    CurrentUsed: SizeUInt;
    RegionSize: SizeUInt;
    RegionCount: Integer;
  end;

  TBumpAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FRegionSize: SizeUInt;
    FRegions: array of Pointer;
    FRegionCount: Integer;
    FCurrentRegion: Pointer;
    FCurrentOffset: SizeUInt;
    FCurrentCapacity: SizeUInt;
    FTotalAllocated: UInt64;
    FAllocCount: UInt64;
    procedure GrowRegion(ASize: SizeUInt);
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    constructor Create(AInner: IAllocator; ARegionSize: SizeUInt = 65536);
    destructor Destroy; override;
    procedure Reset;
    function GetStats: TBumpStats;
    function Traits: TAllocatorTraits; override;
    property RegionSize: SizeUInt read FRegionSize;
    property RegionCount: Integer read FRegionCount;
  end;

implementation

{ TBumpAllocator }

constructor TBumpAllocator.Create(AInner: IAllocator; ARegionSize: SizeUInt);
begin
  inherited Create;
  FInner := AInner;
  if ARegionSize < 4096 then
    FRegionSize := 4096
  else
    FRegionSize := ARegionSize;
  FRegionCount := 0;
  FCurrentRegion := nil;
  FCurrentOffset := 0;
  FCurrentCapacity := 0;
  FTotalAllocated := 0;
  FAllocCount := 0;
end;

destructor TBumpAllocator.Destroy;
var
  I: Integer;
begin
  for I := 0 to FRegionCount - 1 do
    FInner.FreeMem(FRegions[I]);
  FRegions := nil;
  FRegionCount := 0;
  FCurrentRegion := nil;
  inherited Destroy;
end;

procedure TBumpAllocator.GrowRegion(ASize: SizeUInt);
var
  LNewSize: SizeUInt;
begin
  LNewSize := FRegionSize;
  if ASize > LNewSize then
    LNewSize := ASize;

  if FRegionCount >= Length(FRegions) then
    SetLength(FRegions, FRegionCount + 8);

  FRegions[FRegionCount] := FInner.GetMem(LNewSize);
  Inc(FRegionCount);
  FCurrentRegion := FRegions[FRegionCount - 1];
  FCurrentOffset := 0;
  FCurrentCapacity := LNewSize;
end;

function TBumpAllocator.DoGetMem(ASize: SizeUInt): Pointer;
var
  LAligned: SizeUInt;
begin
  if ASize = 0 then
    Exit(nil);

  LAligned := (ASize + 15) and not SizeUInt(15);

  if FCurrentRegion = nil then
    GrowRegion(LAligned)
  else if FCurrentOffset + LAligned > FCurrentCapacity then
    GrowRegion(LAligned);

  Result := Pointer(PByte(FCurrentRegion) + FCurrentOffset);
  Inc(FCurrentOffset, LAligned);
  Inc(FTotalAllocated, ASize);
  Inc(FAllocCount);
end;

function TBumpAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DoGetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TBumpAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
var
  LCopySize: SizeUInt;
begin
  if ASize = 0 then
  begin
    DoFreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(DoGetMem(ASize));

  // Bump allocator does not track individual allocation sizes.
  // We cannot safely copy old data — just allocate new and let caller
  // handle data migration if needed. Mark SupportsRealloc := False
  // so callers know this path is unreliable.
  Result := DoGetMem(ASize);
end;

function TBumpAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  Result.SupportsRealloc := False;
end;

procedure TBumpAllocator.DoFreeMem(APtr: Pointer);
begin
  { bump allocator does not free individual allocations }
end;

procedure TBumpAllocator.Reset;
var
  I: Integer;
begin
  for I := 1 to FRegionCount - 1 do
    FInner.FreeMem(FRegions[I]);
  if FRegionCount > 0 then
  begin
    FCurrentRegion := FRegions[0];
    FCurrentOffset := 0;
    FRegionCount := 1;
  end
  else
  begin
    FCurrentRegion := nil;
    FCurrentOffset := 0;
    FCurrentCapacity := 0;
  end;
  FTotalAllocated := 0;
  FAllocCount := 0;
end;

function TBumpAllocator.GetStats: TBumpStats;
begin
  Result.TotalAllocated := FTotalAllocated;
  Result.AllocCount := FAllocCount;
  Result.CurrentUsed := FCurrentOffset;
  Result.RegionSize := FRegionSize;
  Result.RegionCount := FRegionCount;
end;

end.
